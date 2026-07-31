import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String title;
  final String message;
  final String imageUrl;
  final DateTime timestamp;

  NotificationModel({
    required this.title,
    required this.message,
    required this.imageUrl,
    required this.timestamp,
  });

  factory NotificationModel.fromFirestore(Map<String, dynamic> data) {
    return NotificationModel(
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      imageUrl: data['image_url'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }
}
