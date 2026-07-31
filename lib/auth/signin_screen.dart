import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tremsolapp/auth/post_login_bootstrap.dart';

import '../homescreen.dart';
import 'forgot_password.dart';
import 'google_signin.dart';
import 'signup_screen.dart';
import '../currency/currencycon.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Save FCM token to Firestore
  Future<void> saveFcmToken(String userId) async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    String? token = await messaging.getToken();

    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'fcmToken': token,
    });
    }

  void signInUser() async {
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Ensure required data exists before any screen reads it
      await postLoginBootstrap();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isSignedIn', true);

      // Handle first access once here
      bool isFirstAccess = prefs.getBool('isFirstAccess') ?? true;
      if (isFirstAccess) {
        await prefs.setBool('isFirstAccess', false);
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              isFirstAccess ? const CurrencyConverterScreen() : const HomeScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'invalid-email':
          errorMessage = "Invalid email format. Please check your email.";
          break;
        case 'user-disabled':
          errorMessage = "This account has been disabled. Contact support.";
          break;
        case 'user-not-found':
          errorMessage = "No account found with this email.";
          break;
        case 'wrong-password':
          errorMessage = "Incorrect password. Please try again.";
          break;
        case 'too-many-requests':
          errorMessage = "Too many failed attempts. Try again later.";
          break;
        case 'network-request-failed':
          errorMessage = "Network error. Check your connection.";
          break;
        default:
          errorMessage = "Sign-in failed. Please try again.";
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("An unexpected error occurred.")),
        );
      }
    }
  }

  static Future<void> signInWithFacebook(BuildContext context) async {
    try {
      // Show progress indicator while signing in
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      // Trigger the Facebook sign-in flow
      final LoginResult loginResult = await FacebookAuth.instance.login();

      if (loginResult.status == LoginStatus.success) {
        // Extract the access token
        // Create a credential from the access token
        final OAuthCredential facebookAuthCredential =
            FacebookAuthProvider.credential(
                loginResult.accessToken!.tokenString);

        // Sign in with the credential
        UserCredential userCredential = await FirebaseAuth.instance
            .signInWithCredential(facebookAuthCredential);

        // Extract user info
        String? username = userCredential.user?.displayName;
        String? email = userCredential.user?.email;
        String? photoURL = userCredential.user?.photoURL;
        String? uid = userCredential.user?.uid; // User UID

        // Check if user already exists in Firestore
        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();

        if (!userDoc.exists) {
          // Save user data to Firestore (first-time login only)
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'username': username,
            'email': email,
            'profilepic': photoURL,
            'uid': uid, // Save UID in Firestore
            //newly added
            "country": "",
            "isActive": true,
            "lastOnline": Timestamp.now(),
          });
        }

        // Save sign-in state
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isSignedIn', true);

        // Check if it's the user's first access
        bool isFirstAccess = prefs.getBool('isFirstAccess') ?? true;

        Navigator.pop(context); // Close the progress indicator dialog

        if (isFirstAccess) {
          await prefs.setBool('isFirstAccess', false);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CurrencyConverterScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } else {
        Navigator.pop(context); // Close the progress indicator dialog
        // Handle unsuccessful login
        debugPrint('Facebook Login Failed: ${loginResult.message}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Facebook Login Failed: ${loginResult.message}'),
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close the progress indicator dialog
      // Handle exceptions
      debugPrint('Error during Facebook Login: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during Facebook Login: $e')),
      );
    }
  }

//16 04 2025
  String generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> signInWithApple() async {
    try {
      final rawNonce = generateNonce();
      final nonce = sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,

        accessToken: appleCredential.authorizationCode, //new line added
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      final user = userCredential.user;
      if (user == null) {
        throw FirebaseAuthException(
            code: 'null-user', message: 'No user from Apple credential');
      }

      // Ensure user doc, lastOnline, token, etc.
      await postLoginBootstrap();

      // Seed/merge profile fields if first-time Apple login
      final uid = user.uid;
      final name =
          "${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}"
              .trim();
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fullname': name.isNotEmpty ? name : (user.displayName ?? 'Apple User'),
        'email': user.email ?? appleCredential.email,
        'profilepic': user.photoURL,
        'isWebuser': false,
        'isActive': true,
        'role': 1,
        'platform': 'web',
        'createdAt': Timestamp.now(),
        'timestamp': Timestamp.now(),
        'lastOnline':Timestamp.now(),
        // NEW
        'ordersCount': 0,
        'firstOrderAt': null,
        'lastOrderAt': null,
        'codFailureCount': 0,
        'codSuspended': false,
        'codPhoneVerified': false,
        'codVerifiedPhone': '',
        'country': '',
        'region': '',
        'shippingaddress': '',
        'fcmToken': '',
      }, SetOptions(merge: true));

//added 02 10 2025
// Step 4: Save FCM token to Firestore
final fcmToken = await FirebaseMessaging.instance.getToken();
if (fcmToken != null) {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(userCredential.user!.uid)
      .update({'fcmToken': fcmToken});
}


      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isSignedIn', true);

      bool isFirstAccess = prefs.getBool('isFirstAccess') ?? true;
      if (isFirstAccess) {
        await prefs.setBool('isFirstAccess', false);
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              isFirstAccess ? const CurrencyConverterScreen() : const HomeScreen(),
        ),
      );
    } catch (e) {
      debugPrint("Apple Sign-In Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Apple Sign-In failed. Please try again.')),
        );
      }
    }
  }

//16 04 2025

//added 08 -12 - 2024
  bool _isObscured = true;

//added 16 - 03 - 2025

  void continueAsGuest() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Check if a guest UID already exists
    String? guestUid = prefs.getString('guestUid');

    // Save sign-in state
    await prefs.setBool('isSignedIn', true);

    // Navigate to the home screen or another relevant page
    Navigator.pushReplacement(
      context,
      // MaterialPageRoute(builder: (context) => const HomeScreen()),
      MaterialPageRoute(builder: (context) => const CurrencyConverterScreen()),
    );
  }

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
              const SizedBox(height: 40), // Add spacing at the top
              // Add logo at the top
              Image.asset(
                'assets/logo.jpg', // Path to the logo file in the assets folder
                height: 80, // Adjust the height of the logo
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 100), // Spacing after the logo
              const Text(
                "Login to your account",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Or use e-mail address",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              // Social media sign-in buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final provider = Provider.of<GoogleSignInProvider>(
                          context,
                          listen: false);

                      await provider.googleLogin(context);

//                       try

//                        {
//                         await provider.googleLogin(context);
//                       }

//                       catch (e) {
//                       if (context.mounted) {
//   ScaffoldMessenger.of(context).showSnackBar(
//     const SnackBar(
//       content: Text('Google sign-in failed. Please try again.'),
//     ),
//   );
// }

//                       }
                    },
                    child: Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.5),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/google_icon.png', // Replace with your Google icon asset
                          height: 30,
                          width: 30,
                        ),
                      ),
                    ),
                  ),
                  /* const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      // Call the Facebook sign-in method
                      //commented 15 04 2025
                     // signInWithFacebook(context);
                    }, // Facebook sign-in function
                    child: Container(
                           height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.5),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/facebook_icon.png', // Replace with your Facebook icon asset
                        height: 40,
                      ),
                    ),
                  ),*/
                  const SizedBox(width: 16),
                  if (Platform.isIOS)
                    GestureDetector(
                      onTap: signInWithApple,
                      child: Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5),
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/apple_icon.png',
                          height: 30,
                          width: 30,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Email TextField
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.email),
                  hintText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Password TextField
              TextField(
                controller: _passwordController,
                obscureText: _isObscured,
                cursorColor: Colors.black,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isObscured ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _isObscured = !_isObscured;
                      });
                    },
                  ),
                  hintText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Remember me and Forgot password row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Guest Sign In Button
                      TextButton(
                        onPressed: continueAsGuest,
                        child: const Text("Continue as Guest",
                            style: TextStyle(
                                //fontSize: 16,
                                color: Colors.blue)),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ForgotPassword()),
                      );
                    }, // Forgot password function
                    child: const Text(
                      "Forgot password?",
                      style: TextStyle(color: Color.fromRGBO(234, 73, 42, 1.0)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Login Button
              SizedBox(
                width: double.infinity, // Full width like the TextField
                child: ElevatedButton(
                  onPressed: signInUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF002A5C),
                    minimumSize:
                        const Size.fromHeight(48), // Standard button height
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "Sign In",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Sign Up Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? "),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignUpScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      "Sign Up",
                      style: TextStyle(color: Color.fromRGBO(234, 73, 42, 1.0)),
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
