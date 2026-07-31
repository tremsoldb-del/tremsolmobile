import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationsTestPage extends StatelessWidget {
  const NotificationsTestPage({super.key});

  // Function to add a notification to Firestore
  Future<void> addNotification() async {
    try {
      // Firestore reference
      final notificationsCollection =
          FirebaseFirestore.instance.collection('notifications');

      // Add a new document with sample data
      await notificationsCollection.add({
        'userId': 'user123', // Replace with dynamic userId as needed
        'title': 'Welcome Notification',
        'message': 'This is a sample notification message.',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      print('Notification added successfully!');
    } catch (e) {
      print('Error adding notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Notification'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await addNotification();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notification added successfully!'),
              ),
            );
          },
          child: const Text('Add Notification'),
        ),
      ),
    );
  }
}
