import 'package:flutter/material.dart';
import 'package:tremsolapp/new_notifications/notification_service_new.dart';


class NotifactionHomePage extends StatelessWidget {
  const NotifactionHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Notifications'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            showNotification();
          },
          child: const Text('Show Notification'),
        ),
      ),
    );
  }
}
