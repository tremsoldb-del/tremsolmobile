import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../currency/currencycon.dart';
import '../homescreen.dart';
import 'forgot_password.dart';
import 'google_signin.dart';
import 'post_login_bootstrap.dart';
import 'signup_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> signInUser() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Refresh current app/device information and fill every missing field
      // before any Tremsol screen reads the user document.
      await postLoginBootstrap();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isSignedIn', true);

      final isFirstAccess = prefs.getBool('isFirstAccess') ?? true;
      if (isFirstAccess) {
        await prefs.setBool('isFirstAccess', false);
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => isFirstAccess
              ? const CurrencyConverterScreen()
              : const HomeScreen(),
        ),
      );
    } on FirebaseAuthException catch (error) {
      String errorMessage;
      switch (error.code) {
        case 'invalid-email':
          errorMessage = 'Invalid email format. Please check your email.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled. Contact support.';
          break;
        case 'user-not-found':
          errorMessage = 'No account found with this email.';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          errorMessage = 'Incorrect email or password. Please try again.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many failed attempts. Try again later.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Check your connection.';
          break;
        default:
          errorMessage = 'Sign-in failed. Please try again.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (error, stackTrace) {
      debugPrint('Email sign-in error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An unexpected error occurred.')),
        );
      }
    }
  }

  static Future<void> signInWithFacebook(BuildContext context) async {
    BuildContext? dialogContext;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          dialogContext = ctx;
          return const Center(child: CircularProgressIndicator());
        },
      );

      final loginResult = await FacebookAuth.instance.login();
      if (loginResult.status != LoginStatus.success ||
          loginResult.accessToken == null) {
        if (dialogContext != null && dialogContext!.mounted) {
          Navigator.pop(dialogContext!);
        }

        if (context.mounted && loginResult.status != LoginStatus.cancelled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                loginResult.message ?? 'Facebook sign-in was not completed.',
              ),
            ),
          );
        }
        return;
      }

      final credential = FacebookAuthProvider.credential(
        loginResult.accessToken!.tokenString,
      );
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'null-user',
          message: 'Facebook sign-in returned no Firebase user.',
        );
      }

      await postLoginBootstrap(
        fullName: user.displayName,
        username: user.displayName,
        profilePic: user.photoURL,
        captureSignupSnapshot:
            userCredential.additionalUserInfo?.isNewUser ?? false,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isSignedIn', true);
      final isFirstAccess = prefs.getBool('isFirstAccess') ?? true;
      if (isFirstAccess) {
        await prefs.setBool('isFirstAccess', false);
      }

      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.pop(dialogContext!);
      }
      if (!context.mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => isFirstAccess
              ? const CurrencyConverterScreen()
              : const HomeScreen(),
        ),
      );
    } catch (error, stackTrace) {
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.pop(dialogContext!);
      }
      debugPrint('Facebook sign-in error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Facebook sign-in failed. Please try again.'),
          ),
        );
      }
    }
  }

  String generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String sha256ofString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  Future<void> signInWithApple() async {
    try {
      final rawNonce = generateNonce();
      final nonce = sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      final user = userCredential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'null-user',
          message: 'Apple sign-in returned no Firebase user.',
        );
      }

      // Apple normally supplies the name only on the first authorization, so
      // pass it immediately and let the bootstrap preserve it thereafter.
      final appleName =
          '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
              .trim();
      final resolvedName = appleName.isNotEmpty ? appleName : user.displayName;

      await postLoginBootstrap(
        fullName: resolvedName,
        username: resolvedName,
        profilePic: user.photoURL,
        captureSignupSnapshot:
            userCredential.additionalUserInfo?.isNewUser ?? false,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isSignedIn', true);
      final isFirstAccess = prefs.getBool('isFirstAccess') ?? true;
      if (isFirstAccess) {
        await prefs.setBool('isFirstAccess', false);
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => isFirstAccess
              ? const CurrencyConverterScreen()
              : const HomeScreen(),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Apple Sign-In Error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Apple Sign-In failed. Please try again.'),
          ),
        );
      }
    }
  }

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
