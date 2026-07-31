import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'fbnotification_model.dart';
import 'fbnotification_service.dart';
import 'fbnotification_details.dart';

class FBNotificationsScreen extends StatefulWidget {
  const FBNotificationsScreen({super.key});

  @override
  State<FBNotificationsScreen> createState() => _FBNotificationsScreenState();
}

class _FBNotificationsScreenState extends State<FBNotificationsScreen> {
  final FBNotificationService notificationService = FBNotificationService();
  late String userId;
  Set<String> selectedIds = {}; // IDs of selected notifications

  @override
  void initState() {
    super.initState();
    final FirebaseAuth auth = FirebaseAuth.instance;
    final User? currentUser = auth.currentUser;
    userId = currentUser?.uid ?? '';
  }

  void toggleSelection(String notificationId) {
    setState(() {
      if (selectedIds.contains(notificationId)) {
        selectedIds.remove(notificationId);
      } else {
        selectedIds.add(notificationId);
      }
    });
  }

  Future<void> deleteSelected() async {
    if (selectedIds.isEmpty) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Notification(s)?"),
        content: const Text("Are you sure you want to delete selected notification(s)?"),
        actions: [
          TextButton(child: const Text("Cancel"), onPressed: () => Navigator.pop(context, false)),
          ElevatedButton(child: const Text("Delete"), onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (shouldDelete == true) {
      await notificationService.softDeleteNotifications(selectedIds.toList(), userId);
      setState(() {
        selectedIds.clear();
      });
    }
  }

  int _getUnreadCount(List<NotificationModel> notifications) {
    return notifications
        .where((n) =>
            (n.receiverIds == null || n.receiverIds!.contains(userId)) &&
            !n.readBy.contains(userId) &&
            !n.deletedBy.contains(userId))
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          selectedIds.isEmpty ? 'Notifications' : '${selectedIds.length} Selected',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF002A5C),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: deleteSelected,
            ),
          StreamBuilder<List<NotificationModel>>(
            stream: notificationService.getNotifications(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || userId.isEmpty) {
                return const SizedBox();
              }

              final notifications = snapshot.data!;
              final unreadCount = _getUnreadCount(notifications);

              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(icon: const Icon(Icons.notifications), onPressed: () {}),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
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
          ),
        ],
      ),
      body: userId.isEmpty
          ? const Center(child: Text('Please sign in to view this page'))
          : StreamBuilder<List<NotificationModel>>(
              stream: notificationService.getNotifications(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData) {
                  return const Center(child: Text('No notifications'));
                }

                final notifications = snapshot.data!
                    .where((n) => !n.deletedBy.contains(userId))
                    .toList();

                if (notifications.isEmpty) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.notifications_off, size: 80, color: Colors.grey.shade400),
        const SizedBox(height: 20),
        const Text(
          'No notifications yet',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'You’ll see updates and alerts here when they arrive.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}


                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    final isRead = notification.readBy.contains(userId);
                    final isSelected = selectedIds.contains(notification.id);

                    return GestureDetector(
                      onLongPress: () => toggleSelection(notification.id),
                      child: Card(
                        elevation: isRead ? 2 : 5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: isSelected
                            ? Colors.blue[100]
                            : isRead
                                ? Colors.grey[100]
                                : const Color(0xFFE3F2FD),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          leading: selectedIds.isNotEmpty
                              ? Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => toggleSelection(notification.id),
                                )
                              : null,
                          title: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
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
                            if (selectedIds.isNotEmpty) {
                              toggleSelection(notification.id);
                              return;
                            }

                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NotificationDetailsPage(
                                  notification: notification,
                                ),
                              ),
                            );

                            if (!isRead) {
                              notificationService.markAsRead(notification.id, userId);
                            }
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
