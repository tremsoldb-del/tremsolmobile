// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'notification_details.dart';

// class NotificationService {
//   static final _firebaseMessaging = FirebaseMessaging.instance;
//   static final _localNotifications = FlutterLocalNotificationsPlugin();

//   static void initialize(BuildContext context) async {
//     // Request permissions
//     NotificationSettings settings = await _firebaseMessaging.requestPermission(
//       alert: true,
//       badge: true,
//       sound: true,
//     );

//     if (settings.authorizationStatus == AuthorizationStatus.authorized) {
//       print('User granted permission');
//     } else {
//       print('User declined or has not accepted permission');
//     }

//     // Define notification actions
//     const AndroidInitializationSettings androidInitSettings =
//         AndroidInitializationSettings('@mipmap/ic_launcher');

//     final InitializationSettings initSettings =
//         InitializationSettings(android: androidInitSettings);

//     // Initialize local notifications with a callback for notification taps
//     await _localNotifications.initialize(
//       initSettings,
//       onDidReceiveNotificationResponse: (NotificationResponse response) {
//         if (response.payload != null) {
//           // Handle notification tap
//           Navigator.of(context).push(MaterialPageRoute(
//             builder: (context) =>
//                 NotificationDetailsPage(payload: response.payload!),
//           ));
//         }
//       },
//     );

//     // Handle foreground messages
//     FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//       if (message.notification != null) {
//         showLocalNotification(message);
//       }
//     });

//     // Handle background/terminated state messages when tapped
//     FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
//       // Pass the entire `data` map as a string payload for navigation
//       if (message.data.isNotEmpty) {
//         Navigator.of(context).push(MaterialPageRoute(
//           builder: (context) => NotificationDetailsPage(
//             payload: jsonEncode(message.data),
//           ),
//         ));
//       }
//     });
//   }

//   static Future<void> showLocalNotification(RemoteMessage message) async {
//     const AndroidNotificationDetails androidDetails =
//         AndroidNotificationDetails(
//       'channel_id',
//       'channel_name',
//       channelDescription: 'channel_description',
//       importance: Importance.max,
//       priority: Priority.high,
//     );

//     const NotificationDetails notificationDetails =
//         NotificationDetails(android: androidDetails);

//     // Pass the `data` payload if available
//     await _localNotifications.show(
//       message.notification.hashCode,
//       message.notification?.title,
//       message.notification?.body,
//       notificationDetails,
//       payload: message.data.isNotEmpty
//           ? jsonEncode(message.data)
//           : 'Default payload',
//     );
//   }
// }
