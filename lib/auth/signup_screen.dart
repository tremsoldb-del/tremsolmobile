import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tremsolapp/auth/VerifyEmailScreen.dart';



class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  //final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

//added 1 5 2025
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();
  String? _emailError;

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus) {
        _validateEmail(_emailController.text);
      }
    });
  }

  void _validateEmail(String value) {
    if (value.isEmpty) {
      setState(() => _emailError = 'Please enter your email');
    } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      setState(() => _emailError = 'Please enter a valid email address');
    } else {
      setState(() => _emailError = null);
    }
  }

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _emailController.dispose();
    super.dispose();
  }

//added 1 5 2025
  void signUpUser() async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      // Step 1: Create user with email and password
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Step 2: Get default profile picture URL from 'profpic' collection
      DocumentSnapshot profPicSnapshot = await FirebaseFirestore.instance
          .collection('profpic')
          .limit(1)
          .get()
          .then((snap) => snap.docs.first);

      String defaultProfilePicUrl = '';
      try {
        final qs = await FirebaseFirestore.instance
            .collection('profpic')
            .limit(1)
            .get();
        if (qs.docs.isNotEmpty) {
          final data = qs.docs.first.data();
          defaultProfilePicUrl = (data['default_pic'] ?? '').toString();
        }
      } catch (_) {
        defaultProfilePicUrl = '';
      }

      // Step 3: Save user details to Firestore with the fetched profile picture
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'fullname': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        //'password': _passwordController.text.trim(),
        'uid': userCredential.user!.uid,
        'isWebuser': false,
        'timestamp': Timestamp.now(),
        'role': 1,
        'profilepic': defaultProfilePicUrl,
        "country": "",
        "isActive": true,
        "lastOnline": Timestamp.now(),
        //added 28 09 2025
        'ordersCount': 0,
        'firstOrderAt': null,
        'lastOrderAt': null,
        'codFailureCount': 0,
        'codSuspended': false,
        'codPhoneVerified': false,
        'codVerifiedPhone': '',
        'createdAt': Timestamp.now(),
        'region': ''
      });

//added 02 10 2025
// Step 4: Save FCM token to Firestore
final fcmToken = await FirebaseMessaging.instance.getToken();
if (fcmToken != null) {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(userCredential.user!.uid)
      .update({'fcmToken': fcmToken});
}


      // Dismiss the loading indicator
      Navigator.of(context).pop();

      // Navigate to the home screen
      //replaced 1 05 2024

      // Send email verification
      await userCredential.user!.sendEmailVerification();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pendingEmailVerification', true);

// Navigate to the email verification screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const VerifyEmailScreen()),
      );
    } catch (e) {
      // Dismiss the loading indicator
      Navigator.of(context).pop();

      String errorMessage = "Something went wrong. Please try again.";

      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'email-already-in-use':
            errorMessage =
                "An account with this email already exists. Try logging in instead.";
            break;
          case 'invalid-email':
            errorMessage =
                "The email address you entered is not valid. Please check and try again.";
            break;
          case 'weak-password':
            errorMessage =
                "Your password is too weak. Please choose a stronger one.";
            break;
          case 'operation-not-allowed':
            errorMessage =
                "Email/password accounts are not enabled. Contact support.";
            break;
          default:
            // errorMessage = "Error: ${e.message}";
            errorMessage = "Oops! Something went wrong. Please try again later";
            break;
        }
      } else {
        debugPrint("Non-auth error during sign up: $e");
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
      ));
    }
  }

  bool _isPasswordVisible = false;
  String _passwordStrength = "";
  double _strengthValue = 0;
  Color _strengthColor = Colors.grey;

  void _checkPasswordStrength(String password) {
    String strength;
    double value;
    Color color;

    if (password.isEmpty) {
      strength = "";
      value = 0;
      color = Colors.grey;
    } else if (password.length < 6) {
      strength = "Too short";
      value = 0.2;
      color = Colors.red;
    } else if (password.length < 8) {
      strength = "Weak";
      value = 0.4;
      color = Colors.orange;
    } else if (!RegExp(r'(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])')
        .hasMatch(password)) {
      strength = "Medium";
      value = 0.7;
      color = Colors.yellow[800]!;
    } else {
      strength = "Strong";
      value = 1.0;
      color = Colors.green;
    }

    setState(() {
      _passwordStrength = strength;
      _strengthValue = value;
      _strengthColor = color;
    });
  }

  //==================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40), // Spacing at the top
              // Logo
              Image.asset(
                'assets/logo.jpg', // Path to the logo file in the assets folder
                height: 80, // Adjust the height of the logo
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 100), // Spacing after the logo
              const Text(
                "Create your account",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Fill in the details below",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              // Full Name TextField
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.person),
                  hintText: 'Full Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Email TextField
              TextField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.email),
                  hintText: 'Email',
                  errorText: _emailError,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              const SizedBox(height: 16),

// Inside the build method
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                onChanged: _checkPasswordStrength,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                  hintText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              if (_passwordStrength.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text("Strength: ",
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      _passwordStrength,
                      style: TextStyle(
                        color: _strengthColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: _strengthValue,
                  color: _strengthColor,
                  backgroundColor: Colors.grey[300],
                  minHeight: 6,
                ),
              ],
              const SizedBox(height: 24),
              // const SizedBox(height: 16),
              // Sign Up Button
              SizedBox(
                width: double.infinity, // Full width like the TextField
                child: ElevatedButton(
                  onPressed: signUpUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF002A5C),
                    minimumSize:
                        const Size.fromHeight(48), // Standard button height
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "Sign Up",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Already have an account Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account? "),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(
                          context); // Navigate back to the Sign In screen
                    },
                    child: const Text(
                      "Sign In",
                      style: TextStyle(
                        color: Color.fromRGBO(234, 73, 42, 1.0),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
