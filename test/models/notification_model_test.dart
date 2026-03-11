import 'package:flutter_test/flutter_test.dart';
import 'package:scheduling_and_stakeholder_management_system/models/notification_model.dart';

void main() {
  group('parseNotificationType', () {
    test('parses known types correctly', () {
      expect(parseNotificationType('welcome'), NotificationType.welcome);
      expect(parseNotificationType('event_assignment'), NotificationType.eventAssignment);
      expect(parseNotificationType('event_reminder'), NotificationType.eventReminder);
      expect(parseNotificationType('event_update'), NotificationType.eventUpdate);
      expect(parseNotificationType('invite_accepted'), NotificationType.inviteAccepted);
    });

    test('returns general for null', () {
      expect(parseNotificationType(null), NotificationType.general);
    });

    test('returns general for unknown type', () {
      expect(parseNotificationType('unknown'), NotificationType.general);
    });
  });

  group('Notification', () {
    test('fromMap creates notification correctly', () {
      final map = {
        'id': 'n1',
        'title': 'Test',
        'body': 'Body text',
        'userId': 'u1',
        'createdAt': '2026-03-01T10:00:00.000',
        'isRead': true,
        'type': 'event_assignment',
        'eventId': 'evt_1',
        'data': {'key': 'value'},
      };

      final n = Notification.fromMap(map);
      expect(n.id, 'n1');
      expect(n.title, 'Test');
      expect(n.body, 'Body text');
      expect(n.userId, 'u1');
      expect(n.isRead, true);
      expect(n.type, NotificationType.eventAssignment);
      expect(n.eventId, 'evt_1');
      expect(n.hasLinkedEvent, true);
    });

    test('fromMap defaults isRead to false', () {
      final map = {
        'id': 'n1',
        'title': 'T',
        'body': 'B',
        'userId': 'u1',
        'createdAt': '2026-01-01T00:00:00.000',
      };
      final n = Notification.fromMap(map);
      expect(n.isRead, false);
    });

    test('hasLinkedEvent returns false when eventId is null', () {
      final n = Notification(
        id: 'n1',
        title: 'T',
        body: 'B',
        userId: 'u1',
        createdAt: DateTime(2026),
      );
      expect(n.hasLinkedEvent, false);
    });

    test('hasLinkedEvent returns false when eventId is empty', () {
      final n = Notification(
        id: 'n1',
        title: 'T',
        body: 'B',
        userId: 'u1',
        createdAt: DateTime(2026),
        eventId: '',
      );
      expect(n.hasLinkedEvent, false);
    });

    test('toMap round-trips correctly', () {
      final n = Notification(
        id: 'n1',
        title: 'Title',
        body: 'Body',
        userId: 'u1',
        createdAt: DateTime(2026, 3, 1, 10),
        isRead: true,
        type: NotificationType.eventReminder,
        eventId: 'evt_1',
      );
      final map = n.toMap();
      final restored = Notification.fromMap(map);
      expect(restored.id, n.id);
      expect(restored.title, n.title);
      expect(restored.isRead, n.isRead);
      expect(restored.type, n.type);
      expect(restored.eventId, n.eventId);
    });
  });
}
