import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../currency/currencycon.dart';
import '../homescreen.dart'; // Adjust the import path to your actual HomeScreen file.

class GoogleSignInProvider extends ChangeNotifier {
  final googleSignIn = GoogleSignIn();

  GoogleSignInAccount? _user;
  GoogleSignInAccount get user => _user!;

  Future googleLogin(BuildContext context) async {
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
        if (dialogContext != null && context.mounted) {
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
      final uid = userCredential.user?.uid;
      final displayName = userCredential.user?.displayName;
      final email = userCredential.user?.email;
      final photoURL = userCredential.user?.photoURL;

      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          
          'fullname': displayName,
          'email': email,
          'profilepic': photoURL,
          'uid': uid,
          'isWebuser': false,
          'timestamp': Timestamp.now(),
          'role': 1,
          //added 29 09 2025
          'platform': 'web',
           'createdAt': Timestamp.now(),

          //newly added
          "country": "",
          "isActive": true,
          "lastOnline": Timestamp.now(),
           // NEW fields
          'ordersCount': 0,
          'firstOrderAt': null,
          'lastOrderAt': null,
        'codFailureCount': 0,
        'codSuspended': false,
        'codPhoneVerified': false,
        'codVerifiedPhone': '',
  
          'region': '',
          'shippingaddress': '',
          'fcmToken': '',
        });
      }

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

      final isFirstAccess = prefs.getBool('isFirstAccess') ?? true;

      if (dialogContext != null && context.mounted) {
        Navigator.pop(dialogContext!);
      }

      if (!context.mounted) return;

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

      notifyListeners();
    } catch (e, stack) {
      if (dialogContext != null && context.mounted) {
        Navigator.pop(dialogContext!);
      }

      debugPrint('Google Login Error: $e');
      debugPrint('Stack trace: $stack');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Sign-In Failed"),
            content: Text("Google sign-in failed. Error: $e"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    }
  }

  Future logout() async {
    await googleSignIn.disconnect();
    FirebaseAuth.instance.signOut();
  }
}
