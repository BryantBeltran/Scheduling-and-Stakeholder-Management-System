// ==============================================================================
// STAKEHOLDER SERVICE
// ==============================================================================
// Source: Implementation pattern based on:
// - Repository pattern for data management
// - CRM service architecture patterns
// - Contact management best practices
//
// Implementation Details:
// - In-memory stakeholder storage with reactive updates
// - Multiple filtering options (by type, status, event association)
// - Search functionality across name, email, and organization
// - Event assignment/removal methods for relationship management
//
// Changes from standard patterns:
// - Combined stakeholder and participant management in one service
// - Added participation status update methods
// - Event assignment methods for many-to-many relationships
// - Sample data includes diverse stakeholder types for testing
//
// TODO for Production:
// - Replace in-memory storage with Firestore or REST API
// - Implement contact import from device contacts
// - Add duplicate detection and merge functionality
// - Implement relationship history tracking
// ==============================================================================

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/models.dart';
import 'mock_data_service.dart';

/// Stakeholder service with Firebase and mock data support
class StakeholderService {
  static final StakeholderService _instance = StakeholderService._internal();
  factory StakeholderService() => _instance;
  StakeholderService._internal();

  final List<StakeholderModel> _stakeholders = [];
  final _stakeholdersController = StreamController<List<StakeholderModel>>.broadcast();

  // Lazy Firestore instance
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  CollectionReference get _stakeholdersCollection => _firestore.collection('stakeholders');

  /// Stream of stakeholders
  Stream<List<StakeholderModel>> get stakeholdersStream => _stakeholdersController.stream;

  /// Get all stakeholders
  List<StakeholderModel> get stakeholders => List.unmodifiable(_stakeholders);

  /// Get all stakeholders (async version for consistency with Firebase)
  Future<List<StakeholderModel>> getAllStakeholders() async {
    if (AppConfig.instance.useFirebase) {
      // Production: Fetch from Firestore
      try {
        final snapshot = await _stakeholdersCollection.get();
        
        return snapshot.docs.map((doc) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return StakeholderModel.fromJson(data);
          } catch (e) {
            debugPrint('[StakeholderService] Error parsing stakeholder ${doc.id}: $e');
            return null;
          }
        }).whereType<StakeholderModel>().toList();
      } catch (e) {
        debugPrint('[StakeholderService] Error fetching stakeholders: $e');
        return [];
      }
    } else {
      // Development: Use mock data
      if (AppConfig.isInitialized && AppConfig.instance.useMockData) {
        return MockDataService.getMockStakeholders();
      }
      return List.unmodifiable(_stakeholders);
    }
  }

  /// Initialize with sample data (only in dev mode)
  void initializeSampleData() {
    if (_stakeholders.isNotEmpty) return;

    // Only use mock data in development mode
    if (AppConfig.isInitialized && AppConfig.instance.useMockData) {
      _stakeholders.addAll(MockDataService.getMockStakeholders());
      _stakeholdersController.add(_stakeholders);
    }
    // Production mode: Data comes from Firestore, no sample data added
  }

  /// Get stakeholder by ID (async version for Firestore)
  Future<StakeholderModel?> getStakeholderById(String id) async {
    if (AppConfig.instance.useFirebase) {
      // Production: Fetch from Firestore
      try {
        final doc = await _stakeholdersCollection.doc(id).get();
        if (!doc.exists) return null;
        
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return StakeholderModel.fromJson(data);
      } catch (e) {
        debugPrint('[StakeholderService] Error fetching stakeholder $id: $e');
        return null;
      }
    } else {
      // Development: Use in-memory list
      try {
        return _stakeholders.firstWhere((s) => s.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  /// Returns all stakeholders assigned to a specific event.
  ///
  /// Filters stakeholders where their `eventIds` list contains the given event ID.
  ///
  /// Example:
  /// ```dart
  /// final attendees = stakeholderService.getStakeholdersByEventId('evt_123');
  /// print('${attendees.length} people assigned to this event');
  /// ```
  List<StakeholderModel> getStakeholdersByEventId(String eventId) {
    return _stakeholders.where((s) => s.eventIds.contains(eventId)).toList();
  }

  /// Get stakeholders by type
  List<StakeholderModel> getStakeholdersByType(StakeholderType type) {
    return _stakeholders.where((s) => s.type == type).toList();
  }

  /// Get stakeholders by participation status
  List<StakeholderModel> getStakeholdersByStatus(ParticipationStatus status) {
    return _stakeholders.where((s) => s.participationStatus == status).toList();
  }

  /// Create a new stakeholder
  Future<StakeholderModel> createStakeholder(StakeholderModel stakeholder) async {
    if (AppConfig.instance.useFirebase) {
      // Production: Save to Firestore
      try {
        // Duplicate email check
        final existing = await _stakeholdersCollection
            .where('email', isEqualTo: stakeholder.email)
            .limit(1)
            .get();
        if (existing.docs.isNotEmpty) {
          throw Exception('A stakeholder with this email already exists.');
        }

        final now = DateTime.now();
        final stakeholderData = stakeholder.toJson();
        stakeholderData.remove('id'); // Let Firestore generate the ID
        stakeholderData['createdAt'] = FieldValue.serverTimestamp();
        stakeholderData['updatedAt'] = FieldValue.serverTimestamp();

        final docRef = await _stakeholdersCollection.add(stakeholderData);

        debugPrint('[StakeholderService] Created stakeholder: ${docRef.id}');

        final newStakeholder = stakeholder.copyWith(
          id: docRef.id,
          createdAt: now,
          updatedAt: now,
        );

        return newStakeholder;
      } catch (e) {
        debugPrint('[StakeholderService] Error creating stakeholder: $e');
        rethrow;
      }
    } else {
      // Development: Mock data
      await Future.delayed(const Duration(milliseconds: 500));

      final newStakeholder = stakeholder.copyWith(
        id: 'stakeholder_${DateTime.now().millisecondsSinceEpoch}',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      _stakeholders.add(newStakeholder);
      _stakeholdersController.add(_stakeholders);
      return newStakeholder;
    }
  }

  /// Update an existing stakeholder
  Future<StakeholderModel> updateStakeholder(StakeholderModel stakeholder) async {
    if (AppConfig.instance.useFirebase) {
      // Production: Update in Firestore
      try {
        final stakeholderData = stakeholder.toJson();
        stakeholderData['updatedAt'] = FieldValue.serverTimestamp();

        await _stakeholdersCollection.doc(stakeholder.id).update(stakeholderData);
        
        debugPrint('[StakeholderService] Updated stakeholder: ${stakeholder.id}');
        
        return stakeholder.copyWith(updatedAt: DateTime.now());
      } catch (e) {
        debugPrint('[StakeholderService] Error updating stakeholder: $e');
        rethrow;
      }
    } else {
      // Development: Mock data
      await Future.delayed(const Duration(milliseconds: 500));

      final index = _stakeholders.indexWhere((s) => s.id == stakeholder.id);
      if (index == -1) {
        throw Exception('Stakeholder not found');
      }

      final updatedStakeholder = stakeholder.copyWith(updatedAt: DateTime.now());
      _stakeholders[index] = updatedStakeholder;
      _stakeholdersController.add(_stakeholders);
      return updatedStakeholder;
    }
  }

  /// Delete a stakeholder
  Future<void> deleteStakeholder(String stakeholderId) async {
    if (AppConfig.instance.useFirebase) {
      // Production: Delete from Firestore
      try {
        await _stakeholdersCollection.doc(stakeholderId).delete();
        debugPrint('[StakeholderService] Deleted stakeholder: $stakeholderId');
      } catch (e) {
        debugPrint('[StakeholderService] Error deleting stakeholder: $e');
        rethrow;
      }
    } else {
      // Development: Mock data
      await Future.delayed(const Duration(milliseconds: 500));

      _stakeholders.removeWhere((s) => s.id == stakeholderId);
      _stakeholdersController.add(_stakeholders);
    }
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

  /// Assigns a stakeholder to an event.
  ///
  /// Performs a three-way write:
  /// 1. Adds eventId to stakeholder.eventIds
  /// 2. Adds stakeholderId to event.stakeholderIds
  /// 3. Creates/updates eventStakeholders junction document
  Future<StakeholderModel> assignToEvent(String stakeholderId, String eventId) async {
    final stakeholder = await getStakeholderById(stakeholderId);
    if (stakeholder == null) throw Exception('Stakeholder not found');

    if (stakeholder.eventIds.contains(eventId)) {
      return stakeholder;
    }

    if (AppConfig.instance.useFirebase) {
      try {
        final batch = _firestore.batch();

        // 1. Update stakeholder.eventIds
        batch.update(
          _stakeholdersCollection.doc(stakeholderId),
          {
            'eventIds': FieldValue.arrayUnion([eventId]),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        // 2. Update event.stakeholderIds
        batch.update(
          _firestore.collection('events').doc(eventId),
          {'stakeholderIds': FieldValue.arrayUnion([stakeholderId])},
        );

        // 3. Write junction document
        final junctionId = '${eventId}_$stakeholderId';
        batch.set(
          _firestore.collection('eventStakeholders').doc(junctionId),
          {
            'eventId': eventId,
            'stakeholderId': stakeholderId,
            'assignedAt': FieldValue.serverTimestamp(),
          },
        );

        await batch.commit();

        debugPrint('[StakeholderService] Assigned $stakeholderId to event $eventId');

        return stakeholder.copyWith(
          eventIds: [...stakeholder.eventIds, eventId],
          updatedAt: DateTime.now(),
        );
      } catch (e) {
        debugPrint('[StakeholderService] Error assigning stakeholder to event: $e');
        rethrow;
      }
    } else {
      return updateStakeholder(stakeholder.copyWith(
        eventIds: [...stakeholder.eventIds, eventId],
      ));
    }
  }

  /// Remove stakeholder from event.
  ///
  /// Reverses the three-way write performed by [assignToEvent].
  Future<StakeholderModel> removeFromEvent(String stakeholderId, String eventId) async {
    final stakeholder = await getStakeholderById(stakeholderId);
    if (stakeholder == null) throw Exception('Stakeholder not found');

    if (AppConfig.instance.useFirebase) {
      try {
        final batch = _firestore.batch();

        // 1. Remove eventId from stakeholder.eventIds
        batch.update(
          _stakeholdersCollection.doc(stakeholderId),
          {
            'eventIds': FieldValue.arrayRemove([eventId]),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        // 2. Remove stakeholderId from event.stakeholderIds
        batch.update(
          _firestore.collection('events').doc(eventId),
          {'stakeholderIds': FieldValue.arrayRemove([stakeholderId])},
        );

        // 3. Delete junction document
        final junctionId = '${eventId}_$stakeholderId';
        batch.delete(
          _firestore.collection('eventStakeholders').doc(junctionId),
        );

        await batch.commit();

        debugPrint('[StakeholderService] Removed $stakeholderId from event $eventId');

        return stakeholder.copyWith(
          eventIds: stakeholder.eventIds.where((id) => id != eventId).toList(),
          updatedAt: DateTime.now(),
        );
      } catch (e) {
        debugPrint('[StakeholderService] Error removing stakeholder from event: $e');
        rethrow;
      }
    } else {
      return updateStakeholder(stakeholder.copyWith(
        eventIds: stakeholder.eventIds.where((id) => id != eventId).toList(),
      ));
    }
  }

  /// Search stakeholders
  List<StakeholderModel> searchStakeholders(String query) {
    final lowercaseQuery = query.toLowerCase();
    return _stakeholders.where((stakeholder) {
      return stakeholder.name.toLowerCase().contains(lowercaseQuery) ||
          stakeholder.email.toLowerCase().contains(lowercaseQuery) ||
          (stakeholder.organization?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();
  }

  /// Dispose resources
  void dispose() {
    _stakeholdersController.close();
  }
}
