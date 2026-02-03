// ==============================================================================
// EVENT VALIDATORS
// ==============================================================================
// Centralized validation logic for event forms and data.
// Provides reusable validators for title, description, dates, times, and more.
// ==============================================================================

import '../models/models.dart';

/// Result of a validation check
class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ValidationResult.success()
      : isValid = true,
        errorMessage = null;

  const ValidationResult.error(this.errorMessage) : isValid = false;

  @override
  String toString() => isValid ? 'Valid' : 'Invalid: $errorMessage';
}

/// Comprehensive validators for event data
class EventValidators {
  EventValidators._();

  // ============================================================================
  // Title Validation
  // ============================================================================

  /// Validates event title
  /// - Required field
  /// - Minimum 3 characters
  /// - Maximum 100 characters
  /// - No special characters at start
  static ValidationResult validateTitle(String? title) {
    if (title == null || title.trim().isEmpty) {
      return const ValidationResult.error('Event title is required');
    }

    final trimmed = title.trim();

    if (trimmed.length < 3) {
      return const ValidationResult.error(
        'Title must be at least 3 characters',
      );
    }

    if (trimmed.length > 100) {
      return const ValidationResult.error(
        'Title must be less than 100 characters',
      );
    }

    // Check for special characters at the start
    if (RegExp(r'^[^a-zA-Z0-9]').hasMatch(trimmed)) {
      return const ValidationResult.error(
        'Title must start with a letter or number',
      );
    }

    return const ValidationResult.success();
  }

  /// Form field validator for title
  static String? titleValidator(String? value) {
    final result = validateTitle(value);
    return result.errorMessage;
  }

  // ============================================================================
  // Description Validation
  // ============================================================================

  /// Validates event description
  /// - Optional field
  /// - Maximum 500 characters if provided
  static ValidationResult validateDescription(String? description) {
    if (description == null || description.trim().isEmpty) {
      return const ValidationResult.success(); // Optional field
    }

    if (description.trim().length > 500) {
      return const ValidationResult.error(
        'Description must be less than 500 characters',
      );
    }

    return const ValidationResult.success();
  }

  /// Form field validator for description
  static String? descriptionValidator(String? value) {
    final result = validateDescription(value);
    return result.errorMessage;
  }

  // ============================================================================
  // Location Validation
  // ============================================================================

  /// Validates location name
  /// - Required field
  /// - Minimum 2 characters
  /// - Maximum 200 characters
  static ValidationResult validateLocationName(String? locationName) {
    if (locationName == null || locationName.trim().isEmpty) {
      return const ValidationResult.error('Location is required');
    }

    final trimmed = locationName.trim();

    if (trimmed.length < 2) {
      return const ValidationResult.error(
        'Location must be at least 2 characters',
      );
    }

    if (trimmed.length > 200) {
      return const ValidationResult.error(
        'Location must be less than 200 characters',
      );
    }

    return const ValidationResult.success();
  }

  /// Form field validator for location
  static String? locationValidator(String? value) {
    final result = validateLocationName(value);
    return result.errorMessage;
  }

  /// Validates virtual meeting link
  /// - Optional unless location is virtual
  /// - Must be valid URL if provided
  static ValidationResult validateVirtualLink(String? link, {bool isVirtual = false}) {
    if (link == null || link.trim().isEmpty) {
      if (isVirtual) {
        return const ValidationResult.success(); // Optional even for virtual
      }
      return const ValidationResult.success();
    }

    final trimmed = link.trim();

    // Check if it's a valid URL
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return const ValidationResult.error(
        'Please enter a valid URL (starting with http:// or https://)',
      );
    }

    if (trimmed.length > 500) {
      return const ValidationResult.error(
        'Link must be less than 500 characters',
      );
    }

    return const ValidationResult.success();
  }

  /// Form field validator for virtual link
  static String? virtualLinkValidator(String? value) {
    final result = validateVirtualLink(value);
    return result.errorMessage;
  }

  // ============================================================================
  // Date & Time Validation
  // ============================================================================

  /// Validates event start date
  /// - Required field
  /// - Cannot be more than 1 year in the past
  /// - Cannot be more than 2 years in the future
  static ValidationResult validateStartDate(DateTime? startDate) {
    if (startDate == null) {
      return const ValidationResult.error('Start date is required');
    }

    final now = DateTime.now();
    final oneYearAgo = now.subtract(const Duration(days: 365));
    final twoYearsFromNow = now.add(const Duration(days: 730));

    if (startDate.isBefore(oneYearAgo)) {
      return const ValidationResult.error(
        'Start date cannot be more than 1 year in the past',
      );
    }

    if (startDate.isAfter(twoYearsFromNow)) {
      return const ValidationResult.error(
        'Start date cannot be more than 2 years in the future',
      );
    }

    return const ValidationResult.success();
  }

  /// Validates event end date relative to start date
  /// - Required field
  /// - Must be on or after start date
  static ValidationResult validateEndDate(DateTime? endDate, DateTime? startDate) {
    if (endDate == null) {
      return const ValidationResult.error('End date is required');
    }

    if (startDate != null && endDate.isBefore(startDate)) {
      return const ValidationResult.error(
        'End date cannot be before start date',
      );
    }

    return const ValidationResult.success();
  }

  /// Validates complete event time range
  /// - Start must be before end
  /// - Event must be at least 5 minutes
  /// - Event cannot exceed 30 days
  static ValidationResult validateTimeRange(
    DateTime? startDateTime,
    DateTime? endDateTime,
  ) {
    if (startDateTime == null) {
      return const ValidationResult.error('Start time is required');
    }

    if (endDateTime == null) {
      return const ValidationResult.error('End time is required');
    }

    if (endDateTime.isBefore(startDateTime)) {
      return const ValidationResult.error(
        'End time must be after start time',
      );
    }

    if (endDateTime.isAtSameMomentAs(startDateTime)) {
      return const ValidationResult.error(
        'End time must be different from start time',
      );
    }

    final duration = endDateTime.difference(startDateTime);

    if (duration.inMinutes < 5) {
      return const ValidationResult.error(
        'Event must be at least 5 minutes long',
      );
    }

    if (duration.inDays > 30) {
      return const ValidationResult.error(
        'Event cannot be longer than 30 days',
      );
    }

    return const ValidationResult.success();
  }

  // ============================================================================
  // Stakeholder Validation
  // ============================================================================

  /// Validates stakeholder list
  /// - Optional field
  /// - Maximum 100 stakeholders
  /// - No duplicate IDs
  static ValidationResult validateStakeholders(List<String>? stakeholderIds) {
    if (stakeholderIds == null || stakeholderIds.isEmpty) {
      return const ValidationResult.success(); // Optional
    }

    if (stakeholderIds.length > 100) {
      return const ValidationResult.error(
        'Cannot have more than 100 stakeholders',
      );
    }

    // Check for duplicates
    final uniqueIds = stakeholderIds.toSet();
    if (uniqueIds.length != stakeholderIds.length) {
      return const ValidationResult.error(
        'Duplicate stakeholders are not allowed',
      );
    }

    return const ValidationResult.success();
  }

  // ============================================================================
  // Complete Event Validation
  // ============================================================================

  /// Validates an entire event model
  /// Returns a list of all validation errors
  static List<String> validateEvent(EventModel event) {
    final errors = <String>[];

    // Title
    final titleResult = validateTitle(event.title);
    if (!titleResult.isValid) {
      errors.add(titleResult.errorMessage!);
    }

    // Description
    final descResult = validateDescription(event.description);
    if (!descResult.isValid) {
      errors.add(descResult.errorMessage!);
    }

    // Location
    final locationResult = validateLocationName(event.location.name);
    if (!locationResult.isValid) {
      errors.add(locationResult.errorMessage!);
    }

    // Virtual link if applicable
    if (event.location.isVirtual) {
      final linkResult = validateVirtualLink(
        event.location.virtualLink,
        isVirtual: true,
      );
      if (!linkResult.isValid) {
        errors.add(linkResult.errorMessage!);
      }
    }

    // Time range
    final timeResult = validateTimeRange(event.startTime, event.endTime);
    if (!timeResult.isValid) {
      errors.add(timeResult.errorMessage!);
    }

    // Stakeholders
    final stakeholderResult = validateStakeholders(event.stakeholderIds);
    if (!stakeholderResult.isValid) {
      errors.add(stakeholderResult.errorMessage!);
    }

    return errors;
  }

  /// Checks if an event is valid
  static bool isValidEvent(EventModel event) {
    return validateEvent(event).isEmpty;
  }

  // ============================================================================
  // Business Rule Validation
  // ============================================================================

  /// Checks if event can be edited based on its status
  static ValidationResult canEditEvent(EventModel event) {
    if (event.status == EventStatus.completed) {
      return const ValidationResult.error(
        'Completed events cannot be edited',
      );
    }

    if (event.status == EventStatus.cancelled) {
      return const ValidationResult.error(
        'Cancelled events cannot be edited',
      );
    }

    return const ValidationResult.success();
  }

  /// Checks if event status can be changed to target status
  static ValidationResult canChangeStatus(
    EventStatus currentStatus,
    EventStatus targetStatus,
  ) {
    // Allow any status change for now
    // Add business rules as needed
    
    // Example: Cannot go from completed back to draft
    if (currentStatus == EventStatus.completed && 
        targetStatus == EventStatus.draft) {
      return const ValidationResult.error(
        'Cannot change completed event back to draft',
      );
    }

    // Cannot go from cancelled to in progress
    if (currentStatus == EventStatus.cancelled && 
        targetStatus == EventStatus.inProgress) {
      return const ValidationResult.error(
        'Cannot start a cancelled event',
      );
    }

    return const ValidationResult.success();
  }

  /// Checks if event can be deleted
  static ValidationResult canDeleteEvent(EventModel event) {
    if (event.status == EventStatus.inProgress) {
      return const ValidationResult.error(
        'Cannot delete an event that is in progress',
      );
    }

    return const ValidationResult.success();
  }

  // ============================================================================
  // Helper: Combine DateTime and TimeOfDay
  // ============================================================================

  /// Combines a date and time into a single DateTime
  static DateTime combineDateTime(DateTime date, int hour, int minute) {
    return DateTime(date.year, date.month, date.day, hour, minute);
  }
}
