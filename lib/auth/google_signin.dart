import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../currency/currencycon.dart';
import '../homescreen.dart';
import 'post_login_bootstrap.dart';

class GoogleSignInProvider extends ChangeNotifier {
  final GoogleSignIn googleSignIn = GoogleSignIn();

  GoogleSignInAccount? _user;
  GoogleSignInAccount get user => _user!;

  Future<void> googleLogin(BuildContext context) async {
    BuildContext? dialogContext;

    try {
      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          dialogContext = ctx;
          return const Center(child: CircularProgressIndicator());
        },
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        if (dialogContext != null && dialogContext!.mounted) {
          Navigator.pop(dialogContext!);
        }
        return;
      }

      _user = googleUser;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw FirebaseAuthException(
          code: 'null-user',
          message: 'Google sign-in returned no Firebase user.',
        );
      }

      // Creates a complete record for new Google users and backfills only
      // missing data for returning users. Existing order/COD values are kept.
      await postLoginBootstrap(
        fullName: firebaseUser.displayName ?? googleUser.displayName,
        username: googleUser.displayName,
        profilePic: firebaseUser.photoURL ?? googleUser.photoUrl,
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

      notifyListeners();
    } catch (error, stackTrace) {
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.pop(dialogContext!);
      }

      debugPrint('Google Login Error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Google sign-in failed. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
    }
  }

  Future<void> logout() async {
    await googleSignIn.disconnect();
    await FirebaseAuth.instance.signOut();
  }
}
