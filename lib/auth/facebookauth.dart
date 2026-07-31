// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

// import '../homescreen.dart';

// class AuthService {
//   static Future<void> signInWithFacebook(BuildContext context) async {
//     try {
//       // Trigger the sign-in flow
//       final LoginResult loginResult = await FacebookAuth.instance.login();

//       if (loginResult.status == LoginStatus.success) {
//         // Extract the access token
//         // Create a credential from the access token
//         final OAuthCredential facebookAuthCredential =
//             FacebookAuthProvider.credential(
//                 loginResult.accessToken!.tokenString);

//         // Sign in with the credential
//         UserCredential userCredential = await FirebaseAuth.instance
//             .signInWithCredential(facebookAuthCredential);

//         // Log additional user info if needed
//         debugPrint('Username: ${userCredential.additionalUserInfo?.username}');
//         debugPrint('Email: ${userCredential.user?.email}');
//         debugPrint('Photo URL: ${userCredential.user?.photoURL}');

//         // Navigate to the HomeScreen
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (context) => HomeScreen()),
//         );
//       } else {
//         // Handle unsuccessful login (e.g., cancel or error)
//         debugPrint('Facebook Login Failed: ${loginResult.message}');
//       }
//     } catch (e) {
//       // Handle exceptions
//       debugPrint('Error during Facebook Login: $e');
//     }
//   }
// }
