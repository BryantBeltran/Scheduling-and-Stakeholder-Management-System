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
import '../config/app_config.dart';
import '../models/models.dart';
import 'mock_data_service.dart';

/// Mock stakeholder service for development
/// Replace with actual backend/Firebase in production
class StakeholderService {
  static final StakeholderService _instance = StakeholderService._internal();
  factory StakeholderService() => _instance;
  StakeholderService._internal();

  final List<StakeholderModel> _stakeholders = [];
  final _stakeholdersController = StreamController<List<StakeholderModel>>.broadcast();

  /// Stream of stakeholders
  Stream<List<StakeholderModel>> get stakeholdersStream => _stakeholdersController.stream;

  /// Get all stakeholders
  List<StakeholderModel> get stakeholders => List.unmodifiable(_stakeholders);

  /// Get all stakeholders (async version for consistency with Firebase)
  Future<List<StakeholderModel>> getAllStakeholders() async {
    // Use mock data in development
    if (AppConfig.isInitialized && AppConfig.instance.useMockData) {
      return MockDataService.getMockStakeholders();
    }
    // In a real Firebase implementation, this would fetch from Firestore
    // For now, return the in-memory list
    return List.unmodifiable(_stakeholders);
  }

  /// Initialize with sample data (only in dev mode)
  void initializeSampleData() {
    if (_stakeholders.isNotEmpty) return;

    // Only use mock data in development mode
    if (AppConfig.isInitialized && AppConfig.instance.useMockData) {
      _stakeholders.addAll(MockDataService.getMockStakeholders());
      _stakeholdersController.add(_stakeholders);
      return;
    }

    // Production mode: Don't add any sample data
    // Data should come from Firestore
    return;

    // Legacy sample data for non-flavored builds (commented out for production)
    final now = DateTime.now();
    _stakeholders.addAll([
      StakeholderModel(
        id: 'stakeholder_1',
        name: 'Alice Johnson',
        email: 'alice.johnson@example.com',
        phone: '+1-555-0101',
        organization: 'Tech Corp',
        title: 'Project Manager',
        type: StakeholderType.internal,
        relationshipType: RelationshipType.organizer,
        participationStatus: ParticipationStatus.accepted,
        eventIds: ['event_1', 'event_3'],
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now,
      ),
      StakeholderModel(
        id: 'stakeholder_2',
        name: 'Bob Smith',
        email: 'bob.smith@example.com',
        phone: '+1-555-0102',
        organization: 'Tech Corp',
        title: 'Senior Developer',
        type: StakeholderType.internal,
        relationshipType: RelationshipType.attendee,
        participationStatus: ParticipationStatus.accepted,
        eventIds: ['event_1', 'event_3'],
        createdAt: now.subtract(const Duration(days: 25)),
        updatedAt: now,
      ),
      StakeholderModel(
        id: 'stakeholder_3',
        name: 'Carol Williams',
        email: 'carol@clientcorp.com',
        phone: '+1-555-0103',
        organization: 'Client Corp',
        title: 'CEO',
        type: StakeholderType.client,
        relationshipType: RelationshipType.guest,
        participationStatus: ParticipationStatus.pending,
        eventIds: ['event_2', 'event_3'],
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now,
      ),
      StakeholderModel(
        id: 'stakeholder_4',
        name: 'David Brown',
        email: 'david@partnerfirm.com',
        phone: '+1-555-0104',
        organization: 'Partner Firm',
        title: 'Business Analyst',
        type: StakeholderType.partner,
        relationshipType: RelationshipType.presenter,
        participationStatus: ParticipationStatus.accepted,
        eventIds: ['event_2'],
        createdAt: now.subtract(const Duration(days: 15)),
        updatedAt: now,
      ),
      StakeholderModel(
        id: 'stakeholder_5',
        name: 'Eva Martinez',
        email: 'eva@vendorco.com',
        phone: '+1-555-0105',
        organization: 'Vendor Co',
        title: 'Sales Manager',
        type: StakeholderType.vendor,
        relationshipType: RelationshipType.sponsor,
        participationStatus: ParticipationStatus.tentative,
        notes: 'May need to reschedule due to travel conflicts',
        eventIds: [],
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now,
      ),
    ]);

    _stakeholdersController.add(_stakeholders);
  }

  /// Get stakeholder by ID
  StakeholderModel? getStakeholderById(String id) {
    try {
      return _stakeholders.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
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

  /// Update an existing stakeholder
  Future<StakeholderModel> updateStakeholder(StakeholderModel stakeholder) async {
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

  /// Delete a stakeholder
  Future<void> deleteStakeholder(String stakeholderId) async {
    await Future.delayed(const Duration(milliseconds: 500));

    _stakeholders.removeWhere((s) => s.id == stakeholderId);
    _stakeholdersController.add(_stakeholders);
  }

  /// Update participation status
  Future<StakeholderModel> updateParticipationStatus(
    String stakeholderId,
    ParticipationStatus status,
  ) async {
    final stakeholder = getStakeholderById(stakeholderId);
    if (stakeholder == null) throw Exception('Stakeholder not found');

    return updateStakeholder(stakeholder.copyWith(participationStatus: status));
  }

  /// Assigns a stakeholder to an event.
  ///
  /// Adds the event ID to the stakeholder's `eventIds` list if not already present.
  /// Returns the updated stakeholder model.
  ///
  /// Throws an exception if the stakeholder is not found.
  ///
  /// Example:
  /// ```dart
  /// await stakeholderService.assignToEvent('sh_123', 'evt_456');
  /// print('Stakeholder assigned to event');
  /// ```
  Future<StakeholderModel> assignToEvent(String stakeholderId, String eventId) async {
    final stakeholder = getStakeholderById(stakeholderId);
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
    final stakeholder = getStakeholderById(stakeholderId);
    if (stakeholder == null) throw Exception('Stakeholder not found');

    return updateStakeholder(stakeholder.copyWith(
      eventIds: stakeholder.eventIds.where((id) => id != eventId).toList(),
    ));
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
