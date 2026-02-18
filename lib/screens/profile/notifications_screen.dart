import 'package:flutter/material.dart';
import '../../models/notification_model.dart' as app;
import '../../services/services.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          StreamBuilder<int>(
            stream: _notificationService.unreadCountStream,
            initialData: _notificationService.unreadCount,
            builder: (context, snapshot) {
              final unread = snapshot.data ?? 0;
              if (unread == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => _notificationService.markAllAsRead(),
                child: const Text('Mark all read'),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<app.Notification>>(
        stream: _notificationService.notificationsStream,
        initialData: _notificationService.notifications,
        builder: (context, snapshot) {
          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ll see updates about events and stakeholders here.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationTile(
                notification: notification,
                onTap: () {
                  if (!notification.isRead) {
                    _notificationService.markAsRead(notification.id);
                  }
                  // Navigate to event if notification has a linked event
                  if (notification.hasLinkedEvent) {
                    Navigator.of(context).pushNamed(
                      '/event/details',
                      arguments: notification.eventId,
                    );
                  }
                },
                onDismissed: () {
                  _notificationService.deleteNotification(notification.id);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final app.Notification notification;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: notification.isRead ? Colors.white : Colors.blue.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Unread indicator
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 6, right: 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: notification.isRead
                      ? Colors.transparent
                      : Theme.of(context).primaryColor,
                ),
              ),
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getNotificationIcon(notification.title),
                  size: 20,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: notification.isRead
                            ? FontWeight.w400
                            : FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(notification.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              // Show chevron for event-linked notifications
              if (notification.hasLinkedEvent)
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey[400],
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String title) {
    // Also check notification type for better icon mapping
    final type = notification.type;
    switch (type) {
      case app.NotificationType.welcome:
        return Icons.celebration;
      case app.NotificationType.eventAssignment:
        return Icons.event_available;
      case app.NotificationType.eventReminder:
        return Icons.alarm;
      case app.NotificationType.eventUpdate:
        return Icons.update;
      case app.NotificationType.inviteAccepted:
        return Icons.how_to_reg;
      case app.NotificationType.general:
        // Fall through to title-based matching
        break;
    }

    final lower = title.toLowerCase();
    if (lower.contains('welcome')) return Icons.celebration;
    if (lower.contains('event')) return Icons.event;
    if (lower.contains('stakeholder')) return Icons.people;
    if (lower.contains('invite')) return Icons.mail;
    if (lower.contains('update')) return Icons.update;
    return Icons.notifications;
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
  }
}
