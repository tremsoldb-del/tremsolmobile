import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class New_NotificationScreen extends StatefulWidget {
  const New_NotificationScreen({super.key});

  @override
  _New_NotificationScreenState createState() => _New_NotificationScreenState();
}

class _New_NotificationScreenState extends State< New_NotificationScreen> {
  final NotificationService _notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Local Notifications on iOS")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _notificationService.showNotification(
                title: "Hello!",
                body: "This is a test notification.",
              ),
              child: const Text("Show Notification"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _notificationService.scheduleNotification(
                title: "Reminder!",
                body: "This notification was scheduled.",
                seconds: 5,
              ),
              child: const Text("Schedule Notification (5s)"),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

 


final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestSoundPermission: true,
    requestBadgePermission: true,
    requestAlertPermission: true,
  );

  const InitializationSettings initializationSettings =
      InitializationSettings(iOS: initializationSettingsIOS);

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      print("Notification clicked: ${response.payload}");
    },
  );

  // Request permission explicitly
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
}


  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        'channel_id',
        'General Notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      details,
    );
  }
Future<void> scheduleNotification({
  required String title,
  required String body,
  required int seconds,
}) async {
  final tz.TZDateTime scheduledTime =
      tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));

await _flutterLocalNotificationsPlugin.zonedSchedule(
  0, // Notification ID
  title,
  body,
  scheduledTime,
  const NotificationDetails(
    android: AndroidNotificationDetails(
      'channel_id', // Unique ID for Android notifications
      'Scheduled Notifications',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  ),
  androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
  matchDateTimeComponents: DateTimeComponents.time, // Optional
);

}

}
