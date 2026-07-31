import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SNotificationModel {
  final String id;

  final String title;
  final String message;
  final DateTime timestamp;
  final List<String> readBy; // List of user IDs who have read the notification

  SNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.readBy,
  });

  // Getter to check if the current user has read the notification
  bool get isRead {
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    return readBy.contains(currentUserId);
  }

  // Factory method to create an instance from Firestore data
  factory SNotificationModel.fromFirestore(
      Map<String, dynamic> data, String id) {
    return SNotificationModel(
      id: id,

      title: data['title'] ?? '',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      readBy:
          List<String>.from(data['readBy'] ?? []), // Extract the readBy array
    );
  }

  // Method to convert an instance to a Firestore-compatible map
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'readBy': readBy,
    };
  }
}
