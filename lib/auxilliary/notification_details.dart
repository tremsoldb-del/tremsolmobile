import 'package:flutter/material.dart';
import 'dart:convert';

class NotificationDetailsPage extends StatelessWidget {
  final String payload;

  const NotificationDetailsPage({super.key, required this.payload});

  @override
  Widget build(BuildContext context) {
    // Parse the stringified map from payload
    Map<String, dynamic> notificationData = {};
    try {
      notificationData = jsonDecode(payload);
    } catch (e) {
      // If parsing fails, fallback to displaying raw payload
      notificationData['Raw Payload'] = payload;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notification Details',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF002A5C), // Navy blue
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: notificationData.isNotEmpty
            ? ListView.builder(
                itemCount: notificationData.length,
                itemBuilder: (context, index) {
                  String key = notificationData.keys.elementAt(index);
                  String value =
                      notificationData.values.elementAt(index).toString();
                  return ListTile(
                    title: Text(
                      key,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      value,
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                },
              )
            : const Center(
                child: Text(
                  'No details available',
                  style: TextStyle(fontSize: 16),
                ),
              ),
      ),
    );
  }
}
