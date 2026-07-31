
// File: lib/services/order_service.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../COD/success_screen.dart';

/// A service that handles moving cart items into orders,
/// sending emails, notifications, and SMS.
class OrderService {
  /// Moves cart items to an order, sends confirmation, and navigates.
  static Future<String?> moveCartItemsToOrders({
    required BuildContext context,
    required String paymentMethod,
    required String orderNotes,
    required String shippingAddress,
    required double totalAmount,
    required double shippingFee,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;
    final userEmail = user?.email;
    if (userId == null || userEmail == null) return null;

    // Fetch cart items
    final cartItemsSnap = await FirebaseFirestore.instance
        .collection('cartitems')
        .where('userId', isEqualTo: userId)
        .get();
    if (cartItemsSnap.docs.isEmpty) return null;
    final items = cartItemsSnap.docs.map((d) => d.data()).toList();

    // Create order
    final orderRef = await FirebaseFirestore.instance
        .collection('ordersitems')
        .add({
      'userId': userId,
      'paymentMethod': paymentMethod,
      'items': items,
      'status': 'Processing',
      'totalAmount': totalAmount,
      'shippingFee': shippingFee,
      'orderNotes': orderNotes,
      'shippingAddress': shippingAddress,
      'timestamp': Timestamp.now(),
    });
    final orderId = orderRef.id;
    await orderRef.update({'orderId': orderId});

    // Clear cart
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in cartItemsSnap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    // Fetch user's name
    String userName = 'Customer';
    final uDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (uDoc.exists && uDoc.data()!.containsKey('username')) {
      userName = uDoc['username'];
    }

    // Send confirmation email
    await _sendEmailFromFirestore(orderNumber: orderId, userName: userName);

    // Send Firestore notification
    final settingsDoc = await FirebaseFirestore.instance
        .collection('settings')
        .doc('doc5')
        .get();
    String title = 'Order Successful';
    String msg = 'Your order with ID $orderId has been placed.';
    if (settingsDoc.exists) {
      final d = settingsDoc.data()!;
      title = d['title'] ?? title;
      msg = (d['message'] ?? msg)
          .replaceAll('{orderId}', orderId)
          .replaceAll('{username}', userName);
    }
    // Generate a new notification document and use its ID as notificationId
    final notificationRef = FirebaseFirestore.instance.collection('notifications').doc();
    await notificationRef.set({
      'notificationId': notificationRef.id,
      'title': title,
      'message': msg,
      'readBy': [],
      'timestamp': Timestamp.now(),
      'receiverIds': [userId],
    });


    //commented to save SMS credit
    /*
    // Send SMS via Arkesel
    String phone = uDoc.data()?['phone'] ?? '';
    if (phone.isNotEmpty) {
      final smsDoc = await FirebaseFirestore.instance.collection('settings').doc('doc2').get();
      final template = smsDoc.data()?['message'] ?? 'Your order {orderId} has been placed.';
      final smsBody = template.replaceAll('{orderId}', orderId);
      await http.post(
        Uri.parse('https://sendordersms-j2ojxidybq-uc.a.run.app'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNumber': phone, 'message': smsBody}),
      );
    }*/

    // Navigate
    if (paymentMethod == 'COD') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => CODOrderScreen(orderId: orderId)),
      );
    }

     else if (paymentMethod == 'Paystack') {
      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(builder: (_) => CODOrderScreen(orderId: orderId)),
      // );
    }
    return orderId;
  }

  // Internal: send email using SMTP settings from Firestore
  static Future<void> _sendEmailFromFirestore({
    required String orderNumber,
    required String userName,
  }) async {
    final doc = await FirebaseFirestore.instance.collection('settings').doc('doc3').get();
    if (!doc.exists) return;
    final d = doc.data()!;
    final smtpServer = SmtpServer(
      'smtp.gmail.com', port: 465, username: d['email'], password: d['pass'], ssl: true);
    final recipient = FirebaseAuth.instance.currentUser?.email ?? '';
    final subject = '${d['subject'] ?? 'Order Confirmation - #'}$orderNumber';
    final body = (d['body'] ?? '')
        .replaceAll('{username}', userName)
        .replaceAll('{orderid}', orderNumber)
        .replaceAll('{appname}', d['appname'] ?? 'App');
    final message = Message()
      ..from = Address(d['email'], d['appname'] ?? 'App')
      ..recipients.add(recipient)
      ..subject = subject
      ..html = body;
    await send(message, smtpServer);
  }
}

