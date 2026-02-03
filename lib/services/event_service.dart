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
// - Comprehensive CRUD operations (Create, Read, Update, Delete)
// - Multiple filtering methods (by date, status, search query)
// - Real-time data synchronization with Firestore streams
//
// Reference: https://firebase.google.com/docs/firestore/quickstart
// ==============================================================================

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

/// Firebase Firestore event service
class EventService {
  static final EventService _instance = EventService._internal();
  factory EventService() => _instance;
  EventService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'events';

  /// Stream of all events with real-time updates
  Stream<List<EventModel>> get eventsStream {
    return _firestore
        .collection(_collection)
        .orderBy('startTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EventModel.fromJson({
                  'id': doc.id,
                  ...doc.data(),
                }))
            .toList());
  }

  /// Get all events (one-time fetch)
  Future<List<EventModel>> get events async {
    final snapshot = await _firestore.collection(_collection).get();
    return snapshot.docs
        .map((doc) => EventModel.fromJson({
              'id': doc.id,
              ...doc.data(),
            }))
        .toList();
  }

  /// Get event by ID
  Future<EventModel?> getEventById(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (!doc.exists) return null;
    return EventModel.fromJson({
      'id': doc.id,
      ...doc.data()!,
    });
  }

  /// Get events for a specific date
  Future<List<EventModel>> getEventsForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection(_collection)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    return snapshot.docs
        .map((doc) => EventModel.fromJson({
              'id': doc.id,
              ...doc.data(),
            }))
        .toList();
  }

  /// Get upcoming events
  Stream<List<EventModel>> getUpcomingEventsStream({int limit = 10}) {
    return _firestore
        .collection(_collection)
        .where('startTime', isGreaterThan: Timestamp.now())
        .orderBy('startTime', descending: false)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EventModel.fromJson({
                  'id': doc.id,
                  ...doc.data(),
                }))
            .toList());
  }

  /// Get upcoming events (one-time fetch)
  Future<List<EventModel>> getUpcomingEvents({int limit = 10}) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('startTime', isGreaterThan: Timestamp.now())
        .orderBy('startTime', descending: false)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => EventModel.fromJson({
              'id': doc.id,
              ...doc.data(),
            }))
        .toList();
  }

  /// Get events by status
  Stream<List<EventModel>> getEventsByStatusStream(EventStatus status) {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: status.toString().split('.').last)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EventModel.fromJson({
                  'id': doc.id,
                  ...doc.data(),
                }))
            .toList());
  }

  /// Get events by status (one-time fetch)
  Future<List<EventModel>> getEventsByStatus(EventStatus status) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('status', isEqualTo: status.toString().split('.').last)
        .get();

    return snapshot.docs
        .map((doc) => EventModel.fromJson({
              'id': doc.id,
              ...doc.data(),
            }))
        .toList();
  }

  /// Create a new event
  Future<EventModel> createEvent(EventModel event) async {
    final docRef = _firestore.collection(_collection).doc();
    
    final newEvent = event.copyWith(
      id: docRef.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await docRef.set(newEvent.toJson());
    return newEvent;
  }

  /// Update an existing event
  Future<EventModel> updateEvent(EventModel event) async {
    final updatedEvent = event.copyWith(updatedAt: DateTime.now());
    
    await _firestore.collection(_collection).doc(event.id).update(updatedEvent.toJson());
    
    return updatedEvent;
  }

  /// Delete an event
  Future<void> deleteEvent(String eventId) async {
    await _firestore.collection(_collection).doc(eventId).delete();
  }

  /// Add stakeholder to event
  Future<EventModel> addStakeholderToEvent(String eventId, String stakeholderId) async {
    final event = await getEventById(eventId);
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
    final event = await getEventById(eventId);
    if (event == null) throw Exception('Event not found');

    final updatedEvent = event.copyWith(
      stakeholderIds: event.stakeholderIds.where((id) => id != stakeholderId).toList(),
      updatedAt: DateTime.now(),
    );

    return updateEvent(updatedEvent);
  }

  /// Search events
  Future<List<EventModel>> searchEvents(String query) async {
    // Note: Firestore doesn't support full-text search natively
    // For production, consider using Algolia or ElasticSearch
    final snapshot = await _firestore.collection(_collection).get();
    
    final lowercaseQuery = query.toLowerCase();
    return snapshot.docs
        .map((doc) => EventModel.fromJson({
              'id': doc.id,
              ...doc.data(),
            }))
        .where((event) =>
            event.title.toLowerCase().contains(lowercaseQuery) ||
            (event.description?.toLowerCase().contains(lowercaseQuery) ?? false) ||
            event.location.name.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  /// Get events for current user
  Stream<List<EventModel>> getUserEventsStream(String userId) {
    return _firestore
        .collection(_collection)
        .where('ownerId', isEqualTo: userId)
        .orderBy('startTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EventModel.fromJson({
                  'id': doc.id,
                  ...doc.data(),
                }))
            .toList());
  }
}
