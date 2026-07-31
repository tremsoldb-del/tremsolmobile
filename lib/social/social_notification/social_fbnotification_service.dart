import 'package:cloud_firestore/cloud_firestore.dart';
import 'social_fbnotification_model.dart';

class SFBNotificationService {
  Stream<List<SNotificationModel>> getNotifications() {
    return FirebaseFirestore.instance
        .collection('snotifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return SNotificationModel.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }

  Future<void> markAsRead(String notificationId, String userId) async {
    await FirebaseFirestore.instance
        .collection('snotifications')
        .doc(notificationId)
        .update({
      'readBy': FieldValue.arrayUnion([userId]) // Add userId to readBy array
    });
  }
}
