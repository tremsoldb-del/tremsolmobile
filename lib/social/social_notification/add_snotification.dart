import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class CreateSNotificationsPage extends StatelessWidget {
  const CreateSNotificationsPage({super.key});

  Future<void> createSNotifications() async {
    final firestore = FirebaseFirestore.instance;
    final notifications = [
      {
        'title': 'Movie Night',
        'message': 'Catch the latest blockbuster at your nearest cinema! 🎬',
        'category': 'Movies',
      },
      {
        'title': 'Fashion Alert',
        'message': 'New arrivals are here! Shop the latest trends today. 👗',
        'category': 'Fashion',
      },
      {
        'title': 'Job Opportunity',
        'message': 'Apply now for exciting roles in your field! 💼',
        'category': 'Jobs',
      },
      {
        'title': 'Game On!',
        'message': 'Join the ultimate gaming experience this weekend! 🎮',
        'category': 'Games',
      },
      {
        'title': 'Cinema Specials',
        'message': 'Discounts on movie tickets this Friday! 🎥',
        'category': 'Movies',
      },
      {
        'title': 'Style Upgrade',
        'message': 'Accessorize your outfit with our new collection! 👜',
        'category': 'Fashion',
      },
      {
        'title': 'Career Fair',
        'message': 'Meet top recruiters and land your dream job! 🏢',
        'category': 'Jobs',
      },
      {
        'title': 'Gaming League',
        'message': 'Compete with the best gamers in the city! 🕹️',
        'category': 'Games',
      },
      {
        'title': 'Classic Movies',
        'message': 'Relive timeless classics on the big screen! 🎭',
        'category': 'Movies',
      },
      {
        'title': 'Fashion Week',
        'message': 'Get inspired by runway looks and exclusive deals. ✨',
        'category': 'Fashion',
      },
    ];

    final batch = firestore.batch();
    const uuid = Uuid();

    for (var notification in notifications) {
      final docRef = firestore.collection('snotifications').doc();
      batch.set(docRef, {
        'isRead': false,
        'message': notification['message'],
        'notificationId': uuid.v4(),
        'readBy': [],
        'timestamp': FieldValue.serverTimestamp(),
        'title': notification['title'],
        'category': notification['category'],
      });
    }

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Notifications'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await createSNotifications();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('10 Notifications Created!')),
            );
          },
          child: const Text('Create Notifications'),
        ),
      ),
    );
  }
}
