import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/user_metadata_service.dart';
import 'VerifyEmailScreen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();

  String? _emailError;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String _passwordStrength = '';
  double _strengthValue = 0;
  Color _strengthColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus) {
        _validateEmail(_emailController.text);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  bool _validateEmail(String value) {
    final email = value.trim();
    String? error;

    if (email.isEmpty) {
      error = 'Please enter your email';
    } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      error = 'Please enter a valid email address';
    }

    if (mounted) {
      setState(() => _emailError = error);
    }

    return error == null;
  }

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
  }

  Future<String> _loadDefaultProfilePicture() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('profpic')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return '';
      return (snapshot.docs.first.data()['default_pic'] ?? '').toString().trim();
    } catch (error) {
      debugPrint('Unable to load the default profile picture: $error');
      return '';
    }
  }

  Future<void> signUpUser() async {
    FocusScope.of(context).unfocus();

    final fullName = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (fullName.isEmpty) {
      _showMessage('Please enter your full name.');
      return;
    }

    if (!_validateEmail(email)) return;

    if (password.length < 6) {
      _showMessage('Password must be at least 6 characters.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'null-user',
          message: 'The account was created without a user record.',
        );
      }

      final defaultProfilePicUrl = await _loadDefaultProfilePicture();

      // Store Tremsol account defaults plus the complete signup app/device,
      // locale, IP-location, and notification metadata snapshot.
      await UserMetadataService.instance.syncCurrentUser(
        fullName: fullName,
        username: email.split('@').first,
        profilePic: defaultProfilePicUrl,
        captureSignupSnapshot: true,
        awaitNetworkMetadata: true,
      );

      await user.sendEmailVerification();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pendingEmailVerification', true);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
      );
    } on FirebaseAuthException catch (error) {
      String errorMessage;

      switch (error.code) {
        case 'email-already-in-use':
          errorMessage =
              'An account with this email already exists. Try logging in instead.';
          break;
        case 'invalid-email':
          errorMessage =
              'The email address you entered is not valid. Please check and try again.';
          break;
        case 'weak-password':
          errorMessage =
              'Your password is too weak. Please choose a stronger one.';
          break;
        case 'operation-not-allowed':
          errorMessage =
              'Email/password accounts are not enabled. Contact support.';
          break;
        case 'network-request-failed':
          errorMessage =
              'Network error. Please check your connection and try again.';
          break;
        case 'too-many-requests':
          errorMessage =
              'Too many attempts. Please wait briefly and try again.';
          break;
        default:
          errorMessage = 'Sign up failed. Please try again.';
      }

      _showMessage(errorMessage);
    } catch (error, stackTrace) {
      debugPrint('Non-auth error during sign up: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _checkPasswordStrength(String password) {
    String strength;
    double value;
    Color color;

    if (password.isEmpty) {
      strength = '';
      value = 0;
      color = Colors.grey;
    } else if (password.length < 6) {
      strength = 'Too short';
      value = 0.2;
      color = Colors.red;
    } else if (password.length < 8) {
      strength = 'Weak';
      value = 0.4;
      color = Colors.orange;
    } else if (!RegExp(r'(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])')
        .hasMatch(password)) {
      strength = 'Medium';
      value = 0.7;
      color = Colors.yellow[800]!;
    } else {
      strength = 'Strong';
      value = 1.0;
      color = Colors.green;
    }

    setState(() {
      _passwordStrength = strength;
      _strengthValue = value;
      _strengthColor = color;
    });
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
              const SizedBox(height: 40),
              Image.asset(
                'assets/logo.jpg',
                height: 80,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 100),
              const Text(
                'Create your account',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Fill in the details below',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                enabled: !_isLoading,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.person),
                  hintText: 'Full Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                enabled: !_isLoading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                onChanged: (_) {
                  if (_emailError != null) {
                    _validateEmail(_emailController.text);
                  }
                },
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
              TextField(
                controller: _passwordController,
                enabled: !_isLoading,
                obscureText: !_isPasswordVisible,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onChanged: _checkPasswordStrength,
                onSubmitted: (_) => _isLoading ? null : signUpUser(),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: _isLoading
                        ? null
                        : () {
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
                    const Text(
                      'Strength: ',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : signUpUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF002A5C),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Sign Up',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? '),
                  GestureDetector(
                    onTap: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text(
                      'Sign In',
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
