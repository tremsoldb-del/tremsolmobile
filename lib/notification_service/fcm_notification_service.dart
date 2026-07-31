import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> saveTokenToFirestore() async {
  final user = FirebaseAuth.instance.currentUser;
  final fcmToken = await FirebaseMessaging.instance.getToken();

  if (user != null && fcmToken != null) {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'fcmToken': fcmToken});
  }
}
