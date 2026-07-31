import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/VerifyEmailScreen.dart';
import '../auth/signin_screen.dart';
import '../currency/currencycon.dart';
import '../internet_connect/app_shell.dart';
import '../services/presence_gate.dart';
import 'post_login_bootstrap.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  // factor out the “after-auth” bootstrap so we can reuse it below
  Widget _buildBootstrap(User user) {
    return FutureBuilder<bool>(
      future: () async {
        await postLoginBootstrap();
        final prefs = await SharedPreferences.getInstance();
        final isFirst = prefs.getBool('isFirstAccess') ?? true;
        if (isFirst) await prefs.setBool('isFirstAccess', false);
        return isFirst;
      }(),
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (s.hasError) {
          return const Scaffold(
            body: Center(child: Text('Couldn’t finish sign-in. Tap to retry.')),
          );
        }
        final isFirst = s.data ?? false;
        return PresenceGate(
          uid: user.uid,
          child: isFirst ? const CurrencyConverterScreen() : const AppShell(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snap.data;
        if (user == null) return const SignInScreen();

        final usesEmailPassword = user.providerData.any((p) => p.providerId == 'password');

        if (!usesEmailPassword) {
          // Google/Apple/etc — no email verification gate
          return _buildBootstrap(user);
        }

        // Email/password: only gate if *pending* verification is set
        return FutureBuilder<bool>(
          future: () async {
            await user.reload(); // refresh emailVerified
            final refreshed = FirebaseAuth.instance.currentUser!;
            final prefs = await SharedPreferences.getInstance();
            final pending = prefs.getBool('pendingEmailVerification') ?? false;
            return pending && !refreshed.emailVerified;
          }(),
          builder: (context, f) {
            if (f.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (f.data == true) {
              return const VerifyEmailScreen();
            }
            return _buildBootstrap(user);
          },
        );
      },
    );
  }
}
