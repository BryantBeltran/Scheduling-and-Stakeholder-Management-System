// ==============================================================================
// STAKEHOLDER MODEL
// ==============================================================================
// Source: Custom implementation based on:
// - CRM (Customer Relationship Management) data models
// - RSVP/Invitation response patterns
// - Microsoft Graph attendee and contact schemas
//
// Implementation Details:
// - Multiple categorization: Type, Relationship, and Participation Status
// - Support for internal and external stakeholders
// - Many-to-many relationship with events through eventIds array
// - EventStakeholder junction model for relationship metadata
//
// Changes from standard patterns:
// - Combined stakeholder types with participation tracking in one model
// - Added RelationshipType enum for role-specific assignments
// - Included organization and title fields for professional context
// - Created separate EventStakeholder model for assignment details
// - Added displayNameWithOrg getter for flexible UI rendering
// ==============================================================================

/// Participation status for stakeholders
enum ParticipationStatus {
  pending,
  accepted,
  declined,
  tentative,
  noResponse,
}

/// Stakeholder type
enum StakeholderType {
  internal,
  external,
  client,
  vendor,
  partner,
}

/// Relationship type with the organization/event
enum RelationshipType {
  organizer,
  presenter,
  attendee,
  sponsor,
  guest,
  support,
}

/// Invitation status for stakeholder account creation
enum InviteStatus {
  notInvited,
  pending,
  accepted,
  expired,
}

/// Stakeholder model representing people involved in events.
///
/// Stakeholders can be internal team members, external clients, vendors,
/// or partners. Each stakeholder can be assigned to multiple events with
/// specific roles and participation status.
///
/// Example:
/// ```dart
/// final stakeholder = StakeholderModel(
///   id: 'sh_123',
///   name: 'Jane Smith',
///   email: 'jane@example.com',
///   organization: 'Acme Corp',
///   title: 'Project Manager',
///   type: StakeholderType.client,
///   relationshipType: RelationshipType.organizer,
///   participationStatus: ParticipationStatus.accepted,
///   eventIds: ['evt_1', 'evt_2'],
///   createdAt: DateTime.now(),
///   updatedAt: DateTime.now(),
/// );
/// ```
class StakeholderModel {
  /// Unique identifier for the stakeholder
  final String id;
  
  /// Full name of the stakeholder
  final String name;
  
  /// Email address for contact and invitations
  final String email;
  
  /// Phone number (optional)
  final String? phone;
  
  /// Company or organization name
  final String? organization;
  
  /// Job title or role
  final String? title;
  
  /// Category of stakeholder (internal, external, client, etc.)
  final StakeholderType type;
  
  /// Default relationship role for event assignments
  final RelationshipType relationshipType;
  
  /// Current participation status across events
  final ParticipationStatus participationStatus;
  
  /// Additional notes about the stakeholder
  final String? notes;
  
  /// List of event IDs this stakeholder is assigned to
  final List<String> eventIds;
  
  /// When the stakeholder record was created
  final DateTime createdAt;
  
  /// When the stakeholder record was last updated
  final DateTime updatedAt;
  
  /// Whether this stakeholder is active in the system
  final bool isActive;
  
  /// ID of linked user account (null if not registered)
  final String? linkedUserId;
  
  /// Invitation status for account creation
  final InviteStatus inviteStatus;
  
  /// When the invitation was sent (null if not invited)
  final DateTime? invitedAt;
  
  /// Invitation token for signup link (null if not invited or already used)
  final String? inviteToken;
  
  /// Additional metadata for extensibility
  final Map<String, dynamic>? metadata;

  const StakeholderModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.organization,
    this.title,
    required this.type,
    required this.relationshipType,
    required this.participationStatus,
    this.notes,
    required this.eventIds,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.linkedUserId,
    this.inviteStatus = InviteStatus.notInvited,
    this.invitedAt,
    this.inviteToken,
    this.metadata,
  });
  
  /// Returns true if this stakeholder has a linked user account
  bool get hasAccount => linkedUserId != null;
  
  /// Returns true if invitation is pending
  bool get isInvitePending => inviteStatus == InviteStatus.pending;

  /// Returns `true` if the stakeholder has accepted event invitations.
  ///
  /// Useful for filtering confirmed attendees.
  bool get hasConfirmedEvents => participationStatus == ParticipationStatus.accepted;

  /// Returns the name with organization in parentheses.
  ///
  /// Format: "Name (Organization)" or just "Name" if no organization.
  /// Example: "Jane Smith (Acme Corp)"
  String get displayNameWithOrg {
    if (organization != null && organization!.isNotEmpty) {
      return '$name ($organization)';
    }
    return name;
  }

  /// Create a copy with updated fields
  StakeholderModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? organization,
    String? title,
    StakeholderType? type,
    RelationshipType? relationshipType,
    ParticipationStatus? participationStatus,
    String? notes,
    List<String>? eventIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? linkedUserId,
    InviteStatus? inviteStatus,
    DateTime? invitedAt,
    String? inviteToken,
    Map<String, dynamic>? metadata,
  }) {
    return StakeholderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      organization: organization ?? this.organization,
      title: title ?? this.title,
      type: type ?? this.type,
      relationshipType: relationshipType ?? this.relationshipType,
      participationStatus: participationStatus ?? this.participationStatus,
      notes: notes ?? this.notes,
      eventIds: eventIds ?? this.eventIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      linkedUserId: linkedUserId ?? this.linkedUserId,
      inviteStatus: inviteStatus ?? this.inviteStatus,
      invitedAt: invitedAt ?? this.invitedAt,
      inviteToken: inviteToken ?? this.inviteToken,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'organization': organization,
      'title': title,
      'type': type.name,
      'relationshipType': relationshipType.name,
      'participationStatus': participationStatus.name,
      'notes': notes,
      'eventIds': eventIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
      'linkedUserId': linkedUserId,
      'inviteStatus': inviteStatus.name,
      'invitedAt': invitedAt?.toIso8601String(),
      'inviteToken': inviteToken,
      'metadata': metadata,
    };
  }

  /// Create from JSON map
  factory StakeholderModel.fromJson(Map<String, dynamic> json) {
    return StakeholderModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      organization: json['organization'] as String?,
      title: json['title'] as String?,
      type: StakeholderType.values.firstWhere((t) => t.name == json['type']),
      relationshipType: RelationshipType.values.firstWhere((r) => r.name == json['relationshipType']),
      participationStatus: ParticipationStatus.values.firstWhere((p) => p.name == json['participationStatus']),
      notes: json['notes'] as String?,
      eventIds: List<String>.from(json['eventIds'] as List<dynamic>),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      isActive: json['isActive'] as bool? ?? true,
      linkedUserId: json['linkedUserId'] as String?,
      inviteStatus: json['inviteStatus'] != null 
          ? InviteStatus.values.firstWhere((s) => s.name == json['inviteStatus'])
          : InviteStatus.notInvited,
      invitedAt: json['invitedAt'] != null ? _parseDateTime(json['invitedAt']) : null,
      inviteToken: json['inviteToken'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Helper method to parse DateTime from either String or Firestore Timestamp
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) {
      return DateTime.now();
    } else if (value is DateTime) {
      return value;
    } else if (value is String) {
      return DateTime.parse(value);
    } else {
      // Handle Firestore Timestamp
      try {
        return (value as dynamic).toDate();
      } catch (e) {
        return DateTime.now();
      }
    }
  }

  @override
  String toString() {
    return 'StakeholderModel(id: $id, name: $name, email: $email, type: $type)';
  }
}

/// Junction model representing the relationship between an event and stakeholder.
///
/// This model captures the many-to-many relationship details including
/// the specific role and participation status for each assignment.
///
/// Example:
/// ```dart
/// final assignment = EventStakeholder(
///   eventId: 'evt_123',
///   stakeholderId: 'sh_456',
///   role: RelationshipType.presenter,
///   status: ParticipationStatus.accepted,
///   assignedAt: DateTime.now(),
///   respondedAt: DateTime.now(),
///   responseNote: 'Looking forward to it!',
/// );
/// ```
class EventStakeholder {
  /// ID of the event in this relationship
  final String eventId;
  
  /// ID of the stakeholder in this relationship
  final String stakeholderId;
  
  /// Role of the stakeholder in this specific event
  final RelationshipType role;
  
  /// Participation status for this event
  final ParticipationStatus status;
  
  /// When the stakeholder was assigned to this event
  final DateTime assignedAt;
  
  /// When the stakeholder responded to the invitation
  final DateTime? respondedAt;
  
  /// Optional note from the stakeholder's response
  final String? responseNote;

  const EventStakeholder({
    required this.eventId,
    required this.stakeholderId,
    required this.role,
    required this.status,
    required this.assignedAt,
    this.respondedAt,
    this.responseNote,
  });

  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId,
      'stakeholderId': stakeholderId,
      'role': role.name,
      'status': status.name,
      'assignedAt': assignedAt.toIso8601String(),
      'respondedAt': respondedAt?.toIso8601String(),
      'responseNote': responseNote,
    };
  }

  factory EventStakeholder.fromJson(Map<String, dynamic> json) {
    return EventStakeholder(
      eventId: json['eventId'] as String,
      stakeholderId: json['stakeholderId'] as String,
      role: RelationshipType.values.firstWhere((r) => r.name == json['role']),
      status: ParticipationStatus.values.firstWhere((s) => s.name == json['status']),
      assignedAt: DateTime.parse(json['assignedAt'] as String),
      respondedAt: json['respondedAt'] != null
          ? DateTime.parse(json['respondedAt'] as String)
          : null,
      responseNote: json['responseNote'] as String?,
    );
  }
}
