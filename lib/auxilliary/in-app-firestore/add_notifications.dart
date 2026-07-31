import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddNotificationScreen extends StatelessWidget {
  const AddNotificationScreen({super.key});

  // Function to add a sample notification with notificationId
  Future<void> addSampleNotification() async {
    try {
      final notificationsCollection =
          FirebaseFirestore.instance.collection('notifications');

      // Add the document to Firestore and get the document reference
      final docRef = await notificationsCollection.add({
        "title": "New feature alert!",
  "message": "We’ve launched dark mode!",
  "timestamp": "...",
  "readBy": [],
  "receiverIds": null
      });

      // Update the document with its ID as the notificationId field
      await docRef.update({
        'notificationId': docRef.id,
      });

      print('Sample notification added successfully with ID: ${docRef.id}');
    } catch (e) {
      print('Error adding sample notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Notification'),
        backgroundColor: const Color(0xFF002A5C),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await addSampleNotification();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sample notification added successfully!'),
              ),
            );
          },
          child: const Text('Add Sample Notification'),
        ),
      ),
    );
  }
}


/*
 "title": "Order Confirmed",
  "message": "Your order #789 has been received.",
  "timestamp": "...",
  "readBy": [],
  "receiverIds": ["uid_ABC123"]


*/