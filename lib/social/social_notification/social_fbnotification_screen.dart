import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'social_fbnotification_model.dart';
import 'social_fbnotification_details.dart';
import 'social_fbnotification_service.dart';

class SFBNotificationsScreen extends StatefulWidget {
  const SFBNotificationsScreen({super.key});

  @override
  State<SFBNotificationsScreen> createState() => _SFBNotificationsScreenState();
}

class _SFBNotificationsScreenState extends State<SFBNotificationsScreen> {
  final SFBNotificationService notificationService = SFBNotificationService();
  late String userId;

  @override
  void initState() {
    super.initState();
    final FirebaseAuth auth = FirebaseAuth.instance;
    final User? currentUser = auth.currentUser;

    if (currentUser != null) {
      userId = currentUser.uid;
    } else {
      userId = '';
    }
  }

  int _getUnreadCount(List<SNotificationModel> notifications) {
    return notifications
        .where((notification) => !notification.readBy.contains(userId))
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF002A5C),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          userId.isNotEmpty
              ? StreamBuilder<List<SNotificationModel>>(
                  stream: notificationService.getNotifications(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData ||
                        snapshot.connectionState == ConnectionState.waiting) {
                      return IconButton(
                        icon: const Icon(Icons.notifications),
                        onPressed: () {},
                      );
                    }

                    final unreadCount = _getUnreadCount(snapshot.data!);

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications),
                          onPressed: () {},
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: 5,
                            top: 2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              child: Text(
                                unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                )
              : Container(),
        ],
      ),
      body: userId.isEmpty
          ? const Center(child: Text('No user is signed in.'))
          : StreamBuilder<List<SNotificationModel>>(
              stream: notificationService.getNotifications(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No notifications'));
                }

                final notifications = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    final isRead = notification.readBy.contains(userId);

                    return Card(
                      elevation: isRead ? 2 : 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: isRead
                          ? Colors.grey[100]
                          : const Color(0xFFE3F2FD), // Light blue for unread
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        title: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                isRead ? FontWeight.normal : FontWeight.bold,
                            color: isRead ? Colors.grey[800] : Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          notification.message,
                          style: const TextStyle(fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Icon(
                          isRead ? Icons.check_circle : Icons.circle,
                          color: isRead ? Colors.green : Colors.blue,
                          size: 20,
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SNotificationDetailsPage(
                                notification: notification,
                              ),
                            ),
                          );

                          if (!isRead) {
                            notificationService.markAsRead(
                                notification.id, userId);
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
