import 'package:flutter/material.dart';
import '../../models/notification_model.dart' as app;
import '../../services/services.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

// Filter options for the notifications list
enum _NotifFilter { all, events, reminders, invites, general }

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _notificationService = NotificationService();
  _NotifFilter _activeFilter = _NotifFilter.all;

  List<app.Notification> _applyFilter(List<app.Notification> all) {
    switch (_activeFilter) {
      case _NotifFilter.all:
        return all;
      case _NotifFilter.events:
        return all
            .where((n) =>
                n.type == app.NotificationType.eventAssignment ||
                n.type == app.NotificationType.eventUpdate)
            .toList();
      case _NotifFilter.reminders:
        return all.where((n) => n.type == app.NotificationType.eventReminder).toList();
      case _NotifFilter.invites:
        return all
            .where((n) =>
                n.type == app.NotificationType.inviteAccepted ||
                n.type == app.NotificationType.welcome)
            .toList();
      case _NotifFilter.general:
        return all.where((n) => n.type == app.NotificationType.general).toList();
    }
  }

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
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Notification settings',
            onPressed: () =>
                Navigator.of(context).pushNamed('/notification-preferences'),
          ),
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
      body: Column(
        children: [
          // Type filter chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _activeFilter == _NotifFilter.all,
                  onTap: () => setState(() => _activeFilter = _NotifFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Events',
                  selected: _activeFilter == _NotifFilter.events,
                  onTap: () => setState(() => _activeFilter = _NotifFilter.events),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Reminders',
                  selected: _activeFilter == _NotifFilter.reminders,
                  onTap: () => setState(() => _activeFilter = _NotifFilter.reminders),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Invites',
                  selected: _activeFilter == _NotifFilter.invites,
                  onTap: () => setState(() => _activeFilter = _NotifFilter.invites),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'General',
                  selected: _activeFilter == _NotifFilter.general,
                  onTap: () => setState(() => _activeFilter = _NotifFilter.general),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Notification list
          Expanded(
            child: StreamBuilder<List<app.Notification>>(
              stream: _notificationService.notificationsStream,
              initialData: _notificationService.notifications,
              builder: (context, snapshot) {
                final filtered = _applyFilter(snapshot.data ?? []);

                if (filtered.isEmpty) {
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
                  itemCount: filtered.length + (_notificationService.hasMore ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    // Load More button at the end
                    if (index == filtered.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: _notificationService.isLoadingMore
                              ? const CircularProgressIndicator()
                              : OutlinedButton(
                                  onPressed: () => _notificationService.loadMore(),
                                  child: const Text('Load More'),
                                ),
                        ),
                      );
                    }

                    final notification = filtered[index];
                    return _NotificationTile(
                      notification: notification,
                      onTap: () {
                        if (!notification.isRead) {
                          _notificationService.markAsRead(notification.id);
                        }
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
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.black : Colors.grey[300]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
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
