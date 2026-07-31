// lib/auth/post_login_bootstrap.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> postLoginBootstrap() async {
  final u = FirebaseAuth.instance.currentUser;
  if (u == null) return;

  // Ensure user doc exists and is minimally populated
  final ref = FirebaseFirestore.instance.collection('users').doc(u.uid);
  final snap = await ref.get();
  if (!snap.exists) {
    await ref.set({
      'uid': u.uid,
      'email': u.email,
      'fullname': u.displayName ?? '',
      'isWebuser': false,
      'role': 1,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'lastOnline': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  } else {
    // Update lastOnline on sign-in
    await ref.set({
      'lastOnline': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Optional: store FCM token (safe to ignore errors)
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await ref.set({'fcmToken': token}, SetOptions(merge: true));
    }
  } catch (_) {}
}
