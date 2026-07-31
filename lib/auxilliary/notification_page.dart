import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final List<Map<String, String>> _notifications = [];

  @override
  void initState() {
    super.initState();

    // Listen for notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      setState(() {
        _notifications.add({
          'title': message.notification?.title ?? 'No Title',
          'body': message.notification?.body ?? 'No Body',
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: ListView.builder(
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(_notifications[index]['title']!),
            subtitle: Text(_notifications[index]['body']!),
          );
        },
      ),
    );
  }
}
