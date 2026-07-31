import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:rxdart/rxdart.dart'; // Import rxdart
import 'package:tremsolapp/homescreen.dart';

import 'offline_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late StreamSubscription _subscription;
  bool isOffline = false;

  @override
  void initState() {
    super.initState();

    // Debounce the connectivity stream to avoid too many updates
    _subscription = Connectivity().onConnectivityChanged
        .debounceTime(const Duration(milliseconds: 500)) // Adding debounce
        .listen((result) async {
      // Create an instance of InternetConnectionChecker using the named constructor
      final InternetConnectionChecker connectionChecker = InternetConnectionChecker.createInstance();

      bool hasInternet = await connectionChecker.hasConnection;

      if (!hasInternet) {
        if (!isOffline) {
          setState(() => isOffline = true);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const OfflineScreen()),
          );
        }
      } else {
        if (isOffline) {
          setState(() => isOffline = false);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen(); // Main screen by default
  }
}
