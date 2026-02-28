/// Notification types matching Cloud Functions output
enum NotificationType {
  welcome,
  eventAssignment,
  eventReminder,
  eventUpdate,
  inviteAccepted,
  general,
}

/// Parse notification type from Firestore string
NotificationType parseNotificationType(String? type) {
  switch (type) {
    case 'welcome':
      return NotificationType.welcome;
    case 'event_assignment':
      return NotificationType.eventAssignment;
    case 'event_reminder':
      return NotificationType.eventReminder;
    case 'event_update':
      return NotificationType.eventUpdate;
    case 'invite_accepted':
      return NotificationType.inviteAccepted;
    default:
      return NotificationType.general;
  }
}

class Notification {
  final String id;
  final String title;
  final String body;
  final String userId;
  final DateTime createdAt;
  bool isRead;

  /// Type of notification (event_assignment, welcome, etc.)
  final NotificationType type;

  /// Related event ID for event-based notifications (tap to navigate)
  final String? eventId;

  /// Additional data payload
  final Map<String, dynamic>? data;

  Notification({
    required this.id,
    required this.title,
    required this.body,
    required this.userId,
    required this.createdAt,
    this.isRead = false,
    this.type = NotificationType.general,
    this.eventId,
    this.data,
  });

  factory Notification.fromMap(Map<String, dynamic> map) {
    return Notification(
      id: map['id'],
      title: map['title'],
      body: map['body'],
      userId: map['userId'],
      createdAt: DateTime.parse(map['createdAt']),
      isRead: map['isRead'] ?? false,
      type: parseNotificationType(map['type'] as String?),
      eventId: map['eventId'] as String?,
      data: map['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'type': type.name,
      'eventId': eventId,
      'data': data,
    };
  }

  /// Whether this notification can navigate to an event
  bool get hasLinkedEvent => eventId != null && eventId!.isNotEmpty;
}
