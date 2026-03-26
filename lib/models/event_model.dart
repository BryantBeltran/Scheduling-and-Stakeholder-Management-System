// ==============================================================================
// EVENT MODEL
// ==============================================================================
// Source: Custom implementation inspired by:
// - Google Calendar API event schema
// - Microsoft Graph Calendar Events structure
// - iCalendar (RFC 5545) event properties
//
// Implementation Details:
// - Support for both physical and virtual locations
// - Priority-based event categorization
// - Status tracking through event lifecycle
// - Computed properties (isActive, isPast, isUpcoming) for UI logic
// - Recurrence support (placeholder for future iCal integration)
//
// Changes from standard patterns:
// - Created custom EventLocation class for flexible location handling
// - Added priority enum (Low, Medium, High, Urgent) for task management
// - Included metadata field for extensibility without schema changes
// - Added duration getter for time calculations
// ==============================================================================

/// Event status
enum EventStatus {
  draft,
  scheduled,
  inProgress,
  completed,
  cancelled,
}

/// Event priority
enum EventPriority {
  low,
  medium,
  high,
  urgent,
}

/// Location information for an event (physical or virtual).
///
/// Supports both physical locations with addresses/coordinates and
/// virtual locations with meeting links.
///
/// Example:
/// ```dart
/// // Physical location
/// final office = EventLocation(
///   name: 'Conference Room A',
///   address: '123 Main St, Floor 2',
///   latitude: 40.7128,
///   longitude: -74.0060,
/// );
///
/// // Virtual location
/// final online = EventLocation(
///   name: 'Zoom Meeting',
///   isVirtual: true,
///   virtualLink: 'https://zoom.us/j/123456789',
/// );
/// ```
class EventLocation {
  /// Display name of the location
  final String name;
  
  /// Physical address (null for virtual locations)
  final String? address;
  
  /// Latitude coordinate for map display
  final double? latitude;
  
  /// Longitude coordinate for map display
  final double? longitude;
  
  /// Whether this is a virtual/online location
  final bool isVirtual;
  
  /// Meeting link for virtual locations (Zoom, Teams, etc.)
  final String? virtualLink;

  const EventLocation({
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.isVirtual = false,
    this.virtualLink,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'isVirtual': isVirtual,
      'virtualLink': virtualLink,
    };
  }

  factory EventLocation.fromJson(Map<String, dynamic> json) {
    return EventLocation(
      name: json['name'] as String? ?? '',
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isVirtual: json['isVirtual'] as bool? ?? false,
      virtualLink: json['virtualLink'] as String?,
    );
  }
}

/// Event model representing scheduled events in the system.
///
/// Events can be meetings, appointments, or any time-based activity.
/// Includes support for physical/virtual locations, priority levels,
/// and stakeholder assignments.
///
/// Example:
/// ```dart
/// final event = EventModel(
///   id: 'evt_123',
///   title: 'Team Meeting',
///   startTime: DateTime(2026, 1, 15, 10, 0),
///   endTime: DateTime(2026, 1, 15, 11, 0),
///   location: EventLocation(name: 'Room A'),
///   ownerId: 'user_123',
///   status: EventStatus.scheduled,
///   priority: EventPriority.medium,
///   stakeholderIds: ['sh_1', 'sh_2'],
///   createdAt: DateTime.now(),
///   updatedAt: DateTime.now(),
/// );
/// ```
class EventModel {
  /// Unique identifier for the event
  final String id;
  
  /// Event title/name
  final String title;
  
  /// Detailed description of the event (optional)
  final String? description;
  
  /// When the event starts
  final DateTime startTime;
  
  /// When the event ends
  final DateTime endTime;
  
  /// Where the event takes place (physical or virtual)
  final EventLocation location;
  
  /// User ID of the event creator/owner
  final String ownerId;
  
  /// Display name of the event owner (for UI convenience)
  final String? ownerName;

  /// Optional manager the owner has delegated this event to.
  /// When set, this user also has edit/delete rights on the event.
  final String? managerId;
  
  /// Current status of the event
  final EventStatus status;
  
  /// Priority level for task management
  final EventPriority priority;
  
  /// List of stakeholder IDs assigned to this event
  final List<String> stakeholderIds;
  
  /// When the event was created
  final DateTime createdAt;
  
  /// When the event was last modified
  final DateTime updatedAt;
  
  /// iCalendar recurrence rule (e.g., "FREQ=WEEKLY;BYDAY=MO,WE,FR")
  final String? recurrenceRule;
  
  /// Additional metadata for extensibility
  final Map<String, dynamic>? metadata;

  const EventModel({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.ownerId,
    this.ownerName,
    this.managerId,
    required this.status,
    required this.priority,
    required this.stakeholderIds,
    required this.createdAt,
    required this.updatedAt,
    this.recurrenceRule,
    this.metadata,
  });

  /// Returns `true` if the event is currently happening (now is between start and end).
  ///
  /// Example:
  /// ```dart
  /// if (event.isActive) {
  ///   print('Event in progress!');
  /// }
  /// ```
  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startTime.toLocal()) && now.isBefore(endTime.toLocal());
  }

  /// Returns `true` if the event has already ended.
  ///
  /// Useful for filtering completed/past events.
  bool get isPast => DateTime.now().isAfter(endTime.toLocal());

  /// Returns `true` if the event hasn't started yet.
  ///
  /// Useful for displaying upcoming events on dashboard.
  bool get isUpcoming => DateTime.now().isBefore(startTime.toLocal());

  /// Returns the effective status based on the device clock.
  ///
  /// If the Firestore status is still "scheduled" but the start time has
  /// passed, this returns [EventStatus.inProgress]. Similarly, if the status
  /// is "scheduled" or "inProgress" but the end time has passed, this returns
  /// [EventStatus.completed]. For all other statuses (draft, cancelled, or
  /// already correct) the stored status is returned as-is.
  EventStatus get effectiveStatus {
    final now = DateTime.now();
    final localStart = startTime.toLocal();
    final localEnd = endTime.toLocal();
    // Auto-transition: ended events become completed
    if ((status == EventStatus.scheduled || status == EventStatus.inProgress) && now.isAfter(localEnd)) {
      return EventStatus.completed;
    }
    // Auto-transition: scheduled events that have started become inProgress
    if (status == EventStatus.scheduled && now.isAfter(localStart) && now.isBefore(localEnd)) {
      return EventStatus.inProgress;
    }
    // Correct stale inProgress: if event hasn't started yet, show as scheduled
    if (status == EventStatus.inProgress && now.isBefore(localStart)) {
      return EventStatus.scheduled;
    }
    return status;
  }

  /// Returns the duration of the event.
  ///
  /// Calculated as the difference between end time and start time.
  /// Example:
  /// ```dart
  /// print('Duration: ${event.duration.inHours} hours');
  /// ```
  Duration get duration => endTime.difference(startTime);

  /// Create a copy with updated fields
  EventModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    EventLocation? location,
    String? ownerId,
    String? ownerName,
    String? managerId,
    EventStatus? status,
    EventPriority? priority,
    List<String>? stakeholderIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? recurrenceRule,
    Map<String, dynamic>? metadata,
  }) {
    return EventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      managerId: managerId ?? this.managerId,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      stakeholderIds: stakeholderIds ?? this.stakeholderIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to JSON map for Firestore/Cloud Function.
  /// `id` is intentionally excluded — it is the Firestore document key,
  /// not a stored field.
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'startTime': startTime.toUtc().toIso8601String(),
      'endTime': endTime.toUtc().toIso8601String(),
      'location': location.toJson(),
      'ownerId': ownerId,
      'ownerName': ownerName,
      'managerId': managerId,
      'status': status.name,
      'priority': priority.name,
      'stakeholderIds': stakeholderIds,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'recurrenceRule': recurrenceRule,
      'metadata': metadata,
    };
  }

  /// Create from JSON map (Firestore document data).
  /// Caller must inject `data['id'] = doc.id` before calling this.
  factory EventModel.fromJson(Map<String, dynamic> json) {
    final endTimeRaw = json['endTime'] as String?;
    final startTimeRaw = json['startTime'] as String?;
    final now = DateTime.now();

    return EventModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      startTime: startTimeRaw != null ? DateTime.parse(startTimeRaw) : now,
      endTime: endTimeRaw != null
          ? DateTime.parse(endTimeRaw)
          : (startTimeRaw != null ? DateTime.parse(startTimeRaw).add(const Duration(hours: 1)) : now.add(const Duration(hours: 1))),
      location: json['location'] != null
          ? EventLocation.fromJson(json['location'] as Map<String, dynamic>)
          : const EventLocation(name: ''),
      ownerId: json['ownerId'] as String? ?? '',
      ownerName: json['ownerName'] as String?,
      managerId: json['managerId'] as String?,
      status: EventStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => EventStatus.draft,
      ),
      priority: EventPriority.values.firstWhere(
        (p) => p.name == json['priority'],
        orElse: () => EventPriority.medium,
      ),
      stakeholderIds: json['stakeholderIds'] != null
          ? List<String>.from(json['stakeholderIds'] as List<dynamic>)
          : [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String).toLocal()
          : now,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String).toLocal()
          : now,
      recurrenceRule: json['recurrenceRule'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'EventModel(id: $id, title: $title, startTime: $startTime, status: $status)';
  }
}
