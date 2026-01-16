// ==============================================================================
// EVENT SERVICE
// ==============================================================================
// Source: Implementation pattern based on:
// - Repository pattern for data access
// - CRUD operations best practices
// - Firebase Firestore service architecture
//
// Implementation Details:
// - In-memory list storage with StreamController for reactive updates
// - Comprehensive CRUD operations (Create, Read, Update, Delete)
// - Multiple filtering methods (by date, status, search query)
// - Sample data initialization for development/testing
//
// Changes from standard patterns:
// - Mock implementation with in-memory storage (replace with Firestore/API)
// - Added utility methods: getUpcomingEvents, getEventsForDate, searchEvents
// - Stakeholder assignment methods integrated into event service
// - Broadcast stream for multiple listeners across the app
//
// TODO for Production:
// - Replace in-memory storage with Firestore or REST API
// - Implement proper error handling and network checks
// - Add pagination for large event lists
// - Implement caching strategy for offline support
// ==============================================================================

import 'dart:async';
import '../models/models.dart';

/// Mock event service for development
/// Replace with actual backend/Firebase in production
class EventService {
  static final EventService _instance = EventService._internal();
  factory EventService() => _instance;
  EventService._internal();

  final List<EventModel> _events = [];
  final _eventsController = StreamController<List<EventModel>>.broadcast();

  /// Stream of events that emits whenever the event list changes.
  ///
  /// Listen to this stream for real-time updates to the event list.
  ///
  /// Example:
  /// ```dart
  /// eventService.eventsStream.listen((events) {
  ///   print('Total events: ${events.length}');
  /// });
  /// ```
  Stream<List<EventModel>> get eventsStream => _eventsController.stream;

  /// Returns an unmodifiable list of all events.
  ///
  /// This prevents accidental modification of the internal event list.
  List<EventModel> get events => List.unmodifiable(_events);

  /// Initialize with sample data
  void initializeSampleData() {
    if (_events.isNotEmpty) return;

    final now = DateTime.now();
    _events.addAll([
      EventModel(
        id: 'event_1',
        title: 'Team Standup Meeting',
        description: 'Daily standup meeting with the development team',
        startTime: now.add(const Duration(hours: 1)),
        endTime: now.add(const Duration(hours: 2)),
        location: const EventLocation(
          name: 'Conference Room A',
          address: '123 Main St, Floor 2',
        ),
        ownerId: 'user_1',
        ownerName: 'John Doe',
        status: EventStatus.scheduled,
        priority: EventPriority.medium,
        stakeholderIds: ['stakeholder_1', 'stakeholder_2'],
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now,
      ),
      EventModel(
        id: 'event_2',
        title: 'Client Presentation',
        description: 'Quarterly review presentation for stakeholders',
        startTime: now.add(const Duration(days: 1, hours: 10)),
        endTime: now.add(const Duration(days: 1, hours: 12)),
        location: const EventLocation(
          name: 'Virtual Meeting',
          isVirtual: true,
          virtualLink: 'https://meet.example.com/abc123',
        ),
        ownerId: 'user_1',
        ownerName: 'John Doe',
        status: EventStatus.scheduled,
        priority: EventPriority.high,
        stakeholderIds: ['stakeholder_3', 'stakeholder_4'],
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now,
      ),
      EventModel(
        id: 'event_3',
        title: 'Project Planning Session',
        description: 'Sprint planning for the upcoming quarter',
        startTime: now.add(const Duration(days: 3, hours: 9)),
        endTime: now.add(const Duration(days: 3, hours: 11)),
        location: const EventLocation(
          name: 'Main Boardroom',
          address: '123 Main St, Floor 5',
        ),
        ownerId: 'user_2',
        ownerName: 'Jane Smith',
        status: EventStatus.draft,
        priority: EventPriority.urgent,
        stakeholderIds: ['stakeholder_1', 'stakeholder_2', 'stakeholder_3'],
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now,
      ),
    ]);

    _eventsController.add(_events);
  }

  /// Get event by ID
  EventModel? getEventById(String id) {
    try {
      return _events.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Returns all events that occur on the specified date.
  ///
  /// Matches events where the start time is on the same year, month, and day.
  /// Time of day is ignored in the comparison.
  ///
  /// Example:
  /// ```dart
  /// final todayEvents = eventService.getEventsForDate(DateTime.now());
  /// print('Events today: ${todayEvents.length}');
  /// ```
  List<EventModel> getEventsForDate(DateTime date) {
    return _events.where((event) {
      return event.startTime.year == date.year &&
          event.startTime.month == date.month &&
          event.startTime.day == date.day;
    }).toList();
  }

  /// Get upcoming events
  List<EventModel> getUpcomingEvents({int limit = 10}) {
    final now = DateTime.now();
    final upcoming = _events
        .where((e) => e.startTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return upcoming.take(limit).toList();
  }

  /// Get events by status
  List<EventModel> getEventsByStatus(EventStatus status) {
    return _events.where((e) => e.status == status).toList();
  }

  /// Create a new event
  Future<EventModel> createEvent(EventModel event) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final newEvent = event.copyWith(
      id: 'event_${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _events.add(newEvent);
    _eventsController.add(_events);
    return newEvent;
  }

  /// Update an existing event
  Future<EventModel> updateEvent(EventModel event) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final index = _events.indexWhere((e) => e.id == event.id);
    if (index == -1) {
      throw Exception('Event not found');
    }

    final updatedEvent = event.copyWith(updatedAt: DateTime.now());
    _events[index] = updatedEvent;
    _eventsController.add(_events);
    return updatedEvent;
  }

  /// Delete an event
  Future<void> deleteEvent(String eventId) async {
    await Future.delayed(const Duration(milliseconds: 500));

    _events.removeWhere((e) => e.id == eventId);
    _eventsController.add(_events);
  }

  /// Add stakeholder to event
  Future<EventModel> addStakeholderToEvent(String eventId, String stakeholderId) async {
    final event = getEventById(eventId);
    if (event == null) throw Exception('Event not found');

    if (event.stakeholderIds.contains(stakeholderId)) {
      return event;
    }

    final updatedEvent = event.copyWith(
      stakeholderIds: [...event.stakeholderIds, stakeholderId],
      updatedAt: DateTime.now(),
    );

    return updateEvent(updatedEvent);
  }

  /// Remove stakeholder from event
  Future<EventModel> removeStakeholderFromEvent(String eventId, String stakeholderId) async {
    final event = getEventById(eventId);
    if (event == null) throw Exception('Event not found');

    final updatedEvent = event.copyWith(
      stakeholderIds: event.stakeholderIds.where((id) => id != stakeholderId).toList(),
      updatedAt: DateTime.now(),
    );

    return updateEvent(updatedEvent);
  }

  /// Search events
  List<EventModel> searchEvents(String query) {
    final lowercaseQuery = query.toLowerCase();
    return _events.where((event) {
      return event.title.toLowerCase().contains(lowercaseQuery) ||
          (event.description?.toLowerCase().contains(lowercaseQuery) ?? false) ||
          event.location.name.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  /// Dispose resources
  void dispose() {
    _eventsController.close();
  }
}
