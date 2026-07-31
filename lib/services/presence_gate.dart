import 'package:flutter/material.dart';
import 'package:tremsolapp/services/presence_service.dart.dart';


class PresenceGate extends StatefulWidget {
  final String uid;
  final Widget child;
  const PresenceGate({super.key, required this.uid, required this.child});

  @override
  State<PresenceGate> createState() => _PresenceGateState();
}

class _PresenceGateState extends State<PresenceGate> {
  FirestorePresence? _presence;

  @override
  void initState() {
    super.initState();
    _presence = FirestorePresence(widget.uid)..start();
  }

  @override
  void didUpdateWidget(covariant PresenceGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _presence?.disposeService();
      _presence = FirestorePresence(widget.uid)..start();
    }
  }

  @override
  void dispose() {
    _presence?.disposeService();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
