import 'dart:async';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

/// Firestore-only presence:
/// - sets isActive=true on resume/open, false on pause/close
/// - updates lastOnline every [beat] (TTL window is [ttl])
class FirestorePresence with WidgetsBindingObserver {
  FirestorePresence(this.uid);

  final String uid;
  final _fs = FirebaseFirestore.instance;

  Timer? _hb;
  static const Duration ttl = Duration(seconds: 60);   // consider “online” if seen in last 60s
  static const Duration beat = Duration(seconds: 30);  // heartbeat cadence

  DocumentReference<Map<String, dynamic>> get _userRef =>
      _fs.collection('users').doc(uid);

  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);
    if (FirebaseAuth.instance.currentUser?.uid != uid) return;
    await _goOnline();
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _hb?.cancel();
    _hb = Timer.periodic(beat, (_) {
      _userRef.set({
        'lastOnline': FieldValue.serverTimestamp(),
        'platform': Platform.operatingSystem,
      }, SetOptions(merge: true));
    });
  }

  Future<void> _goOnline() async {
    await _userRef.set({
      'isActive': true,
      'lastOnline': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _goOffline() async {
    await _userRef.set({
      'isActive': false,
      'lastOnline': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _goOnline();
      _startHeartbeat();
    } else if (state == AppLifecycleState.paused ||
               state == AppLifecycleState.inactive ||
               state == AppLifecycleState.detached) {
      _hb?.cancel();
      _goOffline();
    }
  }

  Future<void> disposeService() async {
    WidgetsBinding.instance.removeObserver(this);
    _hb?.cancel();
  }

  /// Helper: use in UI if you want TTL-based online check.
  static bool isOnline(Timestamp? lastOnline) {
    if (lastOnline == null) return false;
    return DateTime.now().difference(lastOnline.toDate()) < ttl;
  }
}
