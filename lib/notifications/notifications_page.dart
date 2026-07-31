import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_model.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data!.docs.map((doc) {
            return NotificationModel.fromFirestore(
                doc.data() as Map<String, dynamic>);
          }).toList();

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return ListTile(
                leading: notification.imageUrl.isNotEmpty
                    ? Image.network(notification.imageUrl,
                        width: 50, height: 50)
                    : null,
                title: Text(notification.title),
                subtitle: Text(notification.message),
                onTap: () {
                  // Handle click, e.g., navigate to a deals page
                },
              );
            },
          );
        },
      ),
    );
  }
}
