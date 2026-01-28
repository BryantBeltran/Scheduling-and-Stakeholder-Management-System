// ==============================================================================
// EVENT SERVICE
// ==============================================================================
// Source: Implementation pattern based on:
// - Repository pattern for data access
// - CRUD operations best practices
// - Firebase Firestore service architecture
//
// Implementation Details:
// - Firestore integration for persistent storage
// - User-based event filtering and ownership
// - Comprehensive CRUD operations (Create, Read, Update, Delete)
// - Multiple filtering methods (by date, status, search query)
// - Real-time event updates via Firestore snapshots
//
// Changes from standard patterns:
// - Events stored per user with ownerId field
// - Security rules enforce user ownership for delete operations
// - Added utility methods: getUpcomingEvents, getEventsForDate, searchEvents
// - Stakeholder assignment methods integrated into event service
// - Broadcast stream for multiple listeners across the app
// ==============================================================================

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/models.dart';
import 'auth_service.dart';
import 'mock_data_service.dart';

/// Event service with Firestore integration
class EventService {
  static final EventService _instance = EventService._internal();
  factory EventService() => _instance;
  EventService._internal();

  final AuthService _authService = AuthService();
  final _eventsController = StreamController<List<EventModel>>.broadcast();
  StreamSubscription<QuerySnapshot>? _eventsSubscription;

  // Lazy Firestore instance - only accessed when useFirebase is true
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// Collection reference for events
  CollectionReference get _eventsCollection => _firestore.collection('events');

  /// Stream of events that emits whenever the event list changes.
  ///
  /// Listen to this stream for real-time updates to the event list.
  /// Only returns events owned by the current user.
  ///
  /// Example:
  /// ```dart
  /// eventService.eventsStream.listen((events) {
  ///   debugPrint('Total events: ${events.length}');
  /// });
  /// ```
  Stream<List<EventModel>> get eventsStream => _eventsController.stream;

  /// Initialize event stream for the current user
  void initializeEventStream() {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      _eventsController.add([]);
      return;
    }

    if (AppConfig.isInitialized && AppConfig.instance.useMockData) {
      // Development: Use mock data
      final mockEvents = MockDataService.getMockEvents(currentUser.id);
      _eventsController.add(mockEvents);
      return;
    }

    // Production: Listen to Firestore changes for user's events
    _eventsSubscription?.cancel();
    _eventsSubscription = _eventsCollection
        .where('ownerId', isEqualTo: currentUser.id)
        .snapshots()
        .listen((snapshot) {
      final events = snapshot.docs
          .map((doc) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return EventModel.fromJson(data);
            } catch (e) {
              debugPrint('Error parsing event ${doc.id}: $e');
              return null;
            }
          })
          .whereType<EventModel>()
          .toList();
      _eventsController.add(events);
    });
  }

  /// Get all events for the current user
  Future<List<EventModel>> getAllEvents() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    if (AppConfig.isInitialized && AppConfig.instance.useMockData) {
      // Development: Return mock data
      return MockDataService.getMockEvents(currentUser.id);
    }

    // Production: Fetch from Firestore
    final snapshot = await _eventsCollection
        .where('ownerId', isEqualTo: currentUser.id)
        .get();

    return snapshot.docs
        .map((doc) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return EventModel.fromJson(data);
          } catch (e) {
            debugPrint('Error parsing event ${doc.id}: $e');
            return null;
          }
        })
        .whereType<EventModel>()
        .toList();
  }

  /// Get event by ID
  Future<EventModel?> getEventById(String id) async {
    try {
      final doc = await _eventsCollection.doc(id).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return EventModel.fromJson(data);
    } catch (e) {
      debugPrint('Error getting event $id: $e');
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
  /// final todayEvents = await eventService.getEventsForDate(DateTime.now());
  /// debugPrint('Events today: ${todayEvents.length}');
  /// ```
  Future<List<EventModel>> getEventsForDate(DateTime date) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final snapshot = await _eventsCollection
        .where('ownerId', isEqualTo: currentUser.id)
        .where('startTime', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
        .where('startTime', isLessThanOrEqualTo: endOfDay.toIso8601String())
        .get();

    return snapshot.docs
        .map((doc) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return EventModel.fromJson(data);
          } catch (e) {
            debugPrint('Error parsing event ${doc.id}: $e');
            return null;
          }
        })
        .whereType<EventModel>()
        .toList();
  }

  /// Get upcoming events
  Future<List<EventModel>> getUpcomingEvents({int limit = 10}) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final now = DateTime.now();
    final snapshot = await _eventsCollection
        .where('ownerId', isEqualTo: currentUser.id)
        .where('startTime', isGreaterThan: now.toIso8601String())
        .orderBy('startTime')
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return EventModel.fromJson(data);
          } catch (e) {
            debugPrint('Error parsing event ${doc.id}: $e');
            return null;
          }
        })
        .whereType<EventModel>()
        .toList();
  }

  /// Get events by status
  Future<List<EventModel>> getEventsByStatus(EventStatus status) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final snapshot = await _eventsCollection
        .where('ownerId', isEqualTo: currentUser.id)
        .where('status', isEqualTo: status.name)
        .get();

    return snapshot.docs
        .map((doc) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return EventModel.fromJson(data);
          } catch (e) {
            debugPrint('Error parsing event ${doc.id}: $e');
            return null;
          }
        })
        .whereType<EventModel>()
        .toList();
  }

  /// Create a new event
  Future<EventModel> createEvent(EventModel event) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final now = DateTime.now();
    final newEvent = event.copyWith(
      ownerId: currentUser.id,
      ownerName: currentUser.displayName,
      createdAt: now,
      updatedAt: now,
    );

    final docRef = await _eventsCollection.add(newEvent.toJson());
    return newEvent.copyWith(id: docRef.id);
  }

  /// Update an existing event
  Future<EventModel> updateEvent(EventModel event) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    // Verify ownership
    final existingEvent = await getEventById(event.id);
    if (existingEvent == null) {
      throw Exception('Event not found');
    }
    if (existingEvent.ownerId != currentUser.id) {
      throw Exception('You do not have permission to update this event');
    }

    final updatedEvent = event.copyWith(updatedAt: DateTime.now());
    await _eventsCollection.doc(event.id).update(updatedEvent.toJson());
    return updatedEvent;
  }

  /// Delete an event
  /// Only the owner can delete their events
  Future<void> deleteEvent(String eventId) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    // Verify ownership
    final event = await getEventById(eventId);
    if (event == null) {
      throw Exception('Event not found');
    }
    if (event.ownerId != currentUser.id) {
      throw Exception('You do not have permission to delete this event');
    }

    await _eventsCollection.doc(eventId).delete();
    
    // Also delete associated event-stakeholder relationships
    final eventStakeholders = await _firestore
        .collection('eventStakeholders')
        .where('eventId', isEqualTo: eventId)
        .get();
    
    for (final doc in eventStakeholders.docs) {
      await doc.reference.delete();
    }
  }

  /// Add stakeholder to event
  Future<EventModel> addStakeholderToEvent(String eventId, String stakeholderId) async {
    final event = await getEventById(eventId);
    if (event == null) throw Exception('Event not found');

    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }
    if (event.ownerId != currentUser.id) {
      throw Exception('You do not have permission to modify this event');
    }

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
    final event = await getEventById(eventId);
    if (event == null) throw Exception('Event not found');

    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }
    if (event.ownerId != currentUser.id) {
      throw Exception('You do not have permission to modify this event');
    }

    final updatedEvent = event.copyWith(
      stakeholderIds: event.stakeholderIds.where((id) => id != stakeholderId).toList(),
      updatedAt: DateTime.now(),
    );

    return updateEvent(updatedEvent);
  }

  /// Search events
  Future<List<EventModel>> searchEvents(String query) async {
    // Note: Firestore doesn't support full-text search natively
    // This implementation fetches all events and filters locally
    // For production, consider using Algolia or ElasticSearch
    final events = await getAllEvents();
    final lowercaseQuery = query.toLowerCase();
    
    return events.where((event) {
      return event.title.toLowerCase().contains(lowercaseQuery) ||
          (event.description?.toLowerCase().contains(lowercaseQuery) ?? false) ||
          event.location.name.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  /// Dispose resources
  void dispose() {
    _eventsSubscription?.cancel();
    _eventsController.close();
  }
}
