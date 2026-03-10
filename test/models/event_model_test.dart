import 'package:flutter_test/flutter_test.dart';
import 'package:scheduling_and_stakeholder_management_system/models/event_model.dart';

void main() {
  group('EventLocation', () {
    test('fromJson handles all fields', () {
      final json = {
        'name': 'Office',
        'address': '123 Main St',
        'latitude': 40.7128,
        'longitude': -74.006,
        'isVirtual': false,
        'virtualLink': null,
      };

      final loc = EventLocation.fromJson(json);
      expect(loc.name, 'Office');
      expect(loc.address, '123 Main St');
      expect(loc.latitude, 40.7128);
      expect(loc.longitude, -74.006);
      expect(loc.isVirtual, false);
      expect(loc.virtualLink, isNull);
    });

    test('fromJson handles null name gracefully', () {
      final loc = EventLocation.fromJson({'name': null});
      expect(loc.name, '');
    });

    test('fromJson handles missing fields', () {
      final loc = EventLocation.fromJson(<String, dynamic>{});
      expect(loc.name, '');
      expect(loc.address, isNull);
      expect(loc.latitude, isNull);
      expect(loc.longitude, isNull);
      expect(loc.isVirtual, false);
    });

    test('fromJson handles integer latitude/longitude', () {
      final loc = EventLocation.fromJson({
        'name': 'Place',
        'latitude': 40,
        'longitude': -74,
      });
      expect(loc.latitude, 40.0);
      expect(loc.longitude, -74.0);
    });

    test('toJson round-trips correctly', () {
      const loc = EventLocation(
        name: 'Zoom',
        isVirtual: true,
        virtualLink: 'https://zoom.us/123',
      );
      final json = loc.toJson();
      final restored = EventLocation.fromJson(json);
      expect(restored.name, 'Zoom');
      expect(restored.isVirtual, true);
      expect(restored.virtualLink, 'https://zoom.us/123');
    });
  });

  group('EventModel.fromJson', () {
    Map<String, dynamic> validJson() => {
          'id': 'evt_1',
          'title': 'Team Meeting',
          'description': 'Weekly sync',
          'startTime': '2026-03-10T10:00:00.000',
          'endTime': '2026-03-10T11:00:00.000',
          'location': {
            'name': 'Room A',
            'address': null,
            'latitude': null,
            'longitude': null,
            'isVirtual': false,
            'virtualLink': null,
          },
          'ownerId': 'user_1',
          'ownerName': 'Alice',
          'status': 'scheduled',
          'priority': 'high',
          'stakeholderIds': ['sh_1', 'sh_2'],
          'createdAt': '2026-03-01T08:00:00.000',
          'updatedAt': '2026-03-05T12:00:00.000',
          'recurrenceRule': null,
          'metadata': null,
        };

    test('parses valid JSON correctly', () {
      final event = EventModel.fromJson(validJson());
      expect(event.id, 'evt_1');
      expect(event.title, 'Team Meeting');
      expect(event.description, 'Weekly sync');
      expect(event.startTime, DateTime(2026, 3, 10, 10));
      expect(event.endTime, DateTime(2026, 3, 10, 11));
      expect(event.location.name, 'Room A');
      expect(event.ownerId, 'user_1');
      expect(event.ownerName, 'Alice');
      expect(event.status, EventStatus.scheduled);
      expect(event.priority, EventPriority.high);
      expect(event.stakeholderIds, ['sh_1', 'sh_2']);
    });

    test('handles null id', () {
      final json = validJson()..remove('id');
      final event = EventModel.fromJson(json);
      expect(event.id, '');
    });

    test('handles null endTime by defaulting to startTime + 1 hour', () {
      final json = validJson()..['endTime'] = null;
      final event = EventModel.fromJson(json);
      expect(event.endTime, event.startTime.add(const Duration(hours: 1)));
    });

    test('handles null location by creating empty location', () {
      final json = validJson()..['location'] = null;
      final event = EventModel.fromJson(json);
      expect(event.location.name, '');
    });

    test('handles missing stakeholderIds', () {
      final json = validJson()..remove('stakeholderIds');
      final event = EventModel.fromJson(json);
      expect(event.stakeholderIds, isEmpty);
    });

    test('handles unknown status with fallback to draft', () {
      final json = validJson()..['status'] = 'unknown_status';
      final event = EventModel.fromJson(json);
      expect(event.status, EventStatus.draft);
    });

    test('handles unknown priority with fallback to medium', () {
      final json = validJson()..['priority'] = 'extreme';
      final event = EventModel.fromJson(json);
      expect(event.priority, EventPriority.medium);
    });

    test('handles null createdAt and updatedAt', () {
      final json = validJson()
        ..['createdAt'] = null
        ..['updatedAt'] = null;
      final event = EventModel.fromJson(json);
      // Should not throw — defaults to DateTime.now()
      expect(event.createdAt, isA<DateTime>());
      expect(event.updatedAt, isA<DateTime>());
    });

    test('handles null title', () {
      final json = validJson()..['title'] = null;
      final event = EventModel.fromJson(json);
      expect(event.title, '');
    });
  });

  group('EventModel.toJson', () {
    test('does not include id field', () {
      final event = EventModel(
        id: 'evt_1',
        title: 'Test',
        startTime: DateTime(2026, 1, 1, 10),
        endTime: DateTime(2026, 1, 1, 11),
        location: const EventLocation(name: 'Room'),
        ownerId: 'user_1',
        status: EventStatus.draft,
        priority: EventPriority.medium,
        stakeholderIds: const [],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final json = event.toJson();
      expect(json.containsKey('id'), isFalse);
      expect(json['title'], 'Test');
      expect(json['ownerId'], 'user_1');
    });
  });

  group('EventModel computed properties', () {
    test('duration is correct', () {
      final event = EventModel(
        id: '1',
        title: 'Test',
        startTime: DateTime(2026, 1, 1, 10),
        endTime: DateTime(2026, 1, 1, 12, 30),
        location: const EventLocation(name: ''),
        ownerId: 'u1',
        status: EventStatus.scheduled,
        priority: EventPriority.low,
        stakeholderIds: const [],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(event.duration, const Duration(hours: 2, minutes: 30));
    });

    test('isPast returns true for past events', () {
      final event = EventModel(
        id: '1',
        title: 'Past',
        startTime: DateTime(2020, 1, 1),
        endTime: DateTime(2020, 1, 1, 1),
        location: const EventLocation(name: ''),
        ownerId: 'u1',
        status: EventStatus.completed,
        priority: EventPriority.low,
        stakeholderIds: const [],
        createdAt: DateTime(2020),
        updatedAt: DateTime(2020),
      );
      expect(event.isPast, isTrue);
      expect(event.isUpcoming, isFalse);
    });

    test('copyWith creates a modified copy', () {
      final event = EventModel(
        id: '1',
        title: 'Original',
        startTime: DateTime(2026, 1, 1, 10),
        endTime: DateTime(2026, 1, 1, 11),
        location: const EventLocation(name: ''),
        ownerId: 'u1',
        status: EventStatus.draft,
        priority: EventPriority.low,
        stakeholderIds: const [],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final copy = event.copyWith(title: 'Modified', status: EventStatus.scheduled);
      expect(copy.title, 'Modified');
      expect(copy.status, EventStatus.scheduled);
      expect(copy.id, '1'); // unchanged
      expect(copy.ownerId, 'u1'); // unchanged
    });
  });
}
