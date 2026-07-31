import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final List<String> readBy;
  final List<String>? receiverIds; // NEW FIELD
  final List<String> deletedBy;


  NotificationModel({
  required this.id,
  required this.title,
  required this.message,
  required this.timestamp,
  required this.readBy,
  required this.deletedBy, // Add this
  this.receiverIds,
});


  bool get isRead {
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    return readBy.contains(currentUserId);
  }

  factory NotificationModel.fromFirestore(Map<String, dynamic> data, String id) {
  return NotificationModel(
    id: id,
    title: data['title'] ?? '',
    message: data['message'] ?? '',
    timestamp: (data['timestamp'] as Timestamp).toDate(),
    readBy: List<String>.from(data['readBy'] ?? []),
    deletedBy: List<String>.from(data['deletedBy'] ?? []), // Add this
    receiverIds: data['receiverIds'] != null
        ? List<String>.from(data['receiverIds'])
        : null,
  );
}


Map<String, dynamic> toFirestore() {
  return {
    'title': title,
    'message': message,
    'timestamp': Timestamp.fromDate(timestamp),
    'readBy': readBy,
    'deletedBy': deletedBy, // Add this
    if (receiverIds != null) 'receiverIds': receiverIds,
  };
}

}
