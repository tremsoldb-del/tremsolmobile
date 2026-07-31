import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tremsolapp/auth/auth_gate.dart';
import 'package:tremsolapp/auth/signin_screen.dart';



class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});
  @override
  _VerifyEmailScreenState createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool isEmailVerified = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    checkEmailVerified();
  }

  Future<void> checkEmailVerified() async {
    setState(() => isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Session expired or signed out
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInScreen()),
        (route) => false,
      );
      return;
    }

    await user.reload();
    final refreshed = FirebaseAuth.instance.currentUser;
    final verified = refreshed?.emailVerified ?? false;

    setState(() {
      isEmailVerified = verified;
      isLoading = false;
    });

    if (verified) {
      // ✅ Clear the pending flag so AuthGate won't send you back here again
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pendingEmailVerification');

      if (!mounted) return;
      // ✅ Go through AuthGate so it can run your post-login bootstrap & routing
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    }
  }

  Future<void> resendVerificationEmail() async {
    try {
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) throw Exception('No current user');
      await u.sendEmailVerification();

      // ✅ Keep the pending flag set while waiting for verification
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pendingEmailVerification', true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Verification email sent again. Please check your inbox."),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error sending verification email. Try again later."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify Your Email")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.email, size: 80, color: Color(0xFF00195E)),
                  const SizedBox(height: 20),
                  const Text(
                    "A verification email has been sent to your email address.\nPlease verify to continue.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: resendVerificationEmail,
                    icon: const Icon(Icons.refresh, color: Color.fromRGBO(234, 73, 42, 1.0)),
                    label: const Text(
                      "Resend Email",
                      style: TextStyle(color: Color.fromRGBO(234, 73, 42, 1.0)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: checkEmailVerified,
                    icon: const Icon(Icons.check_circle, color: Color.fromRGBO(234, 73, 42, 1.0)),
                    label: const Text(
                      "I have verified",
                      style: TextStyle(color: Color.fromRGBO(234, 73, 42, 1.0)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
