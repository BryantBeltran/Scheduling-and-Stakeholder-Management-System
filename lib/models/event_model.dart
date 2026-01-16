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
      name: json['name'] as String,
      address: json['address'] as String?,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
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
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  /// Returns `true` if the event has already ended.
  ///
  /// Useful for filtering completed/past events.
  bool get isPast => DateTime.now().isAfter(endTime);

  /// Returns `true` if the event hasn't started yet.
  ///
  /// Useful for displaying upcoming events on dashboard.
  bool get isUpcoming => DateTime.now().isBefore(startTime);

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
      status: status ?? this.status,
      priority: priority ?? this.priority,
      stakeholderIds: stakeholderIds ?? this.stakeholderIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'location': location.toJson(),
      'ownerId': ownerId,
      'ownerName': ownerName,
      'status': status.name,
      'priority': priority.name,
      'stakeholderIds': stakeholderIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'recurrenceRule': recurrenceRule,
      'metadata': metadata,
    };
  }

  /// Create from JSON map
  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      location: EventLocation.fromJson(json['location'] as Map<String, dynamic>),
      ownerId: json['ownerId'] as String,
      ownerName: json['ownerName'] as String?,
      status: EventStatus.values.firstWhere((s) => s.name == json['status']),
      priority: EventPriority.values.firstWhere((p) => p.name == json['priority']),
      stakeholderIds: List<String>.from(json['stakeholderIds'] as List<dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      recurrenceRule: json['recurrenceRule'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'EventModel(id: $id, title: $title, startTime: $startTime, status: $status)';
  }
}
