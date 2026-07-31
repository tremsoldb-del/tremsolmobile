import 'package:cloud_firestore/cloud_firestore.dart';
import 'fbnotification_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FBNotificationService {
Stream<List<NotificationModel>> getNotifications() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    // Return an empty stream if no user is signed in
    return Stream.value([]);
  }

  final String currentUserId = user.uid;

  return FirebaseFirestore.instance
      .collection('notifications')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) => NotificationModel.fromFirestore(doc.data(), doc.id))
        .where((notification) =>
            (notification.receiverIds == null || notification.receiverIds!.contains(currentUserId)) &&
            !notification.deletedBy.contains(currentUserId))
        .toList();
  });
}



  Future<void> markAsRead(String notificationId, String userId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .update({
      'readBy': FieldValue.arrayUnion([userId]) // Add userId to readBy array
    });
  }

 Future<void> softDeleteNotification(String notificationId, String userId) async {
  await FirebaseFirestore.instance
      .collection('notifications')
      .doc(notificationId)
      .update({
    'deletedBy': FieldValue.arrayUnion([userId])
  });
}

Future<void> softDeleteNotifications(List<String> ids, String userId) async {
  final batch = FirebaseFirestore.instance.batch();
  for (String id in ids) {
    final docRef = FirebaseFirestore.instance.collection('notifications').doc(id);
    batch.update(docRef, {
      'deletedBy': FieldValue.arrayUnion([userId])
    });
  }
  await batch.commit();
}
 // ✅ NEW: Delete a single notification
  Future<void> deleteNotification(String id) async {
    await FirebaseFirestore.instance.collection('notifications').doc(id).delete();
  }

  // ✅ NEW: Delete multiple notifications (batch)
  Future<void> deleteMultipleNotifications(List<String> ids) async {
    final batch = FirebaseFirestore.instance.batch();
    for (String id in ids) {
      final docRef = FirebaseFirestore.instance.collection('notifications').doc(id);
      batch.delete(docRef);
    }
    await batch.commit();
  }
}
