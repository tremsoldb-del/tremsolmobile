import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'homescreen.dart';
import 'auth/signin_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _logoUrl; // will come from Firestore

  @override
  void initState() {
    super.initState();
    _loadLogoFromFirestore();
    _startTimer();
  }

  Future<void> _loadLogoFromFirestore() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('logo')
          .get();

      final data = doc.data();
      if (data != null && data['logo_url'] is String) {
        setState(() {
          _logoUrl = data['logo_url'] as String;
        });
      }
    } catch (e) {
      debugPrint('Error loading logo from Firestore: $e');
      // silently fall back to local asset
    }
  }

  void _startTimer() async {
    final prefs = await SharedPreferences.getInstance();
    final isSignedIn = prefs.getBool('isSignedIn') ?? false;

    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              isSignedIn ? const HomeScreen() : const SignInScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // make logo size relative to screen (square)
    final logoSize = size.width * 0.60; // 45% of screen width (tweak as you like)

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          width: logoSize,
          height: logoSize,
          child: _logoUrl == null
              // Fallback to local asset while loading or on error
              ? Image.asset(
                  'assets/logo.jpg',
                  fit: BoxFit.contain,
                )
              : Image.network(
                  _logoUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/logo.jpg',
                    fit: BoxFit.contain,
                  ),
                ),
        ),
      ),
    );
  }
}
