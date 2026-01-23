// ==============================================================================
// STAKEHOLDER SERVICE
// ==============================================================================
// Source: Implementation pattern based on:
// - Repository pattern for data management
// - CRM service architecture patterns
// - Contact management best practices
//
// Implementation Details:
// - Firestore integration for persistent storage
// - Multiple filtering options (by type, status, event association)
// - Search functionality across name, email, and organization
// - Event assignment/removal methods for relationship management
//
// Reference: https://firebase.google.com/docs/firestore/quickstart
// ==============================================================================

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

/// Firebase Firestore stakeholder service
class StakeholderService {
  static final StakeholderService _instance = StakeholderService._internal();
  factory StakeholderService() => _instance;
  StakeholderService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'stakeholders';

  /// Stream of all stakeholders with real-time updates
  Stream<List<StakeholderModel>> get stakeholdersStream {
    return _firestore
        .collection(_collection)
        .orderBy('name', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StakeholderModel.fromJson({
                  'id': doc.id,
                  ...doc.data(),
                }))
            .toList());
  }

  /// Get all stakeholders (one-time fetch)
  Future<List<StakeholderModel>> get stakeholders async {
    final snapshot = await _firestore.collection(_collection).get();
    return snapshot.docs
        .map((doc) => StakeholderModel.fromJson({
              'id': doc.id,
              ...doc.data(),
            }))
        .toList();
  }

  /// Get stakeholder by ID
  Future<StakeholderModel?> getStakeholderById(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (!doc.exists) return null;
    return StakeholderModel.fromJson({
      'id': doc.id,
      ...doc.data()!,
    });
  }

  /// Get stakeholders by event ID
  Stream<List<StakeholderModel>> getStakeholdersByEventIdStream(String eventId) {
    return _firestore
        .collection(_collection)
        .where('eventIds', arrayContains: eventId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StakeholderModel.fromJson({
                  'id': doc.id,
                  ...doc.data(),
                }))
            .toList());
  }

  /// Get stakeholders by event ID (one-time fetch)
  Future<List<StakeholderModel>> getStakeholdersByEventId(String eventId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('eventIds', arrayContains: eventId)
        .get();

    return snapshot.docs
        .map((doc) => StakeholderModel.fromJson({
              'id': doc.id,
              ...doc.data(),
            }))
        .toList();
  }

  /// Get stakeholders by type
  Stream<List<StakeholderModel>> getStakeholdersByTypeStream(StakeholderType type) {
    return _firestore
        .collection(_collection)
        .where('type', isEqualTo: type.toString().split('.').last)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StakeholderModel.fromJson({
                  'id': doc.id,
                  ...doc.data(),
                }))
            .toList());
  }

  /// Get stakeholders by type (one-time fetch)
  Future<List<StakeholderModel>> getStakeholdersByType(StakeholderType type) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('type', isEqualTo: type.toString().split('.').last)
        .get();

    return snapshot.docs
        .map((doc) => StakeholderModel.fromJson({
              'id': doc.id,
              ...doc.data(),
            }))
        .toList();
  }

  /// Get stakeholders by participation status
  Future<List<StakeholderModel>> getStakeholdersByStatus(ParticipationStatus status) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('participationStatus', isEqualTo: status.toString().split('.').last)
        .get();

    return snapshot.docs
        .map((doc) => StakeholderModel.fromJson({
              'id': doc.id,
              ...doc.data(),
            }))
        .toList();
  }

  /// Create a new stakeholder
  Future<StakeholderModel> createStakeholder(StakeholderModel stakeholder) async {
    final docRef = _firestore.collection(_collection).doc();
    
    final newStakeholder = stakeholder.copyWith(
      id: docRef.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await docRef.set(newStakeholder.toJson());
    return newStakeholder;
  }

  /// Update an existing stakeholder
  Future<StakeholderModel> updateStakeholder(StakeholderModel stakeholder) async {
    final updatedStakeholder = stakeholder.copyWith(updatedAt: DateTime.now());
    
    await _firestore.collection(_collection).doc(stakeholder.id).update(updatedStakeholder.toJson());
    
    return updatedStakeholder;
  }

  /// Delete a stakeholder
  Future<void> deleteStakeholder(String stakeholderId) async {
    await _firestore.collection(_collection).doc(stakeholderId).delete();
  }

  /// Update participation status
  Future<StakeholderModel> updateParticipationStatus(
    String stakeholderId,
    ParticipationStatus status,
  ) async {
    final stakeholder = await getStakeholderById(stakeholderId);
    if (stakeholder == null) throw Exception('Stakeholder not found');

    return updateStakeholder(stakeholder.copyWith(participationStatus: status));
  }

  /// Assign stakeholder to event
  Future<StakeholderModel> assignToEvent(String stakeholderId, String eventId) async {
    final stakeholder = await getStakeholderById(stakeholderId);
    if (stakeholder == null) throw Exception('Stakeholder not found');

    if (stakeholder.eventIds.contains(eventId)) {
      return stakeholder;
    }

    return updateStakeholder(stakeholder.copyWith(
      eventIds: [...stakeholder.eventIds, eventId],
    ));
  }

  /// Remove stakeholder from event
  Future<StakeholderModel> removeFromEvent(String stakeholderId, String eventId) async {
    final stakeholder = await getStakeholderById(stakeholderId);
    if (stakeholder == null) throw Exception('Stakeholder not found');

    return updateStakeholder(stakeholder.copyWith(
      eventIds: stakeholder.eventIds.where((id) => id != eventId).toList(),
    ));
  }

  /// Search stakeholders
  Future<List<StakeholderModel>> searchStakeholders(String query) async {
    // Note: Firestore doesn't support full-text search natively
    // For production, consider using Algolia or ElasticSearch
    final snapshot = await _firestore.collection(_collection).get();
    
    final lowercaseQuery = query.toLowerCase();
    return snapshot.docs
        .map((doc) => StakeholderModel.fromJson({
              'id': doc.id,
              ...doc.data(),
            }))
        .where((stakeholder) =>
            stakeholder.name.toLowerCase().contains(lowercaseQuery) ||
            stakeholder.email.toLowerCase().contains(lowercaseQuery) ||
            (stakeholder.organization?.toLowerCase().contains(lowercaseQuery) ?? false))
        .toList();
  }
}
