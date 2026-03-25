// ==============================================================================
// CONFLICT DETECTION SERVICE — Allen's Interval Algebra
// ==============================================================================

import '../models/models.dart';

/// The 13 Allen interval relations.
enum IntervalRelation {
  /// A ends before B starts (gap between them)
  before,

  /// B ends before A starts
  after,

  /// A.end == B.start (no gap, no overlap)
  meets,

  /// B.end == A.start
  metBy,

  /// A starts before B, they share some time, A ends before B
  overlaps,

  /// B starts before A, they share some time, B ends before A
  overlappedBy,

  /// A and B start at the same time, A ends first
  starts,

  /// A and B start at the same time, B ends first
  startedBy,

  /// A is entirely within B (starts after, ends before)
  during,

  /// B is entirely within A
  contains,

  /// A and B end at the same time, A starts after B
  finishes,

  /// A and B end at the same time, A starts before B
  finishedBy,

  /// Identical start and end times
  equals,
}

/// Result of comparing two events.
class ConflictResult {
  final EventModel eventA;
  final EventModel eventB;
  final IntervalRelation relation;

  const ConflictResult({
    required this.eventA,
    required this.eventB,
    required this.relation,
  });

  /// True when the two events share overlapping time (a scheduling conflict).
  bool get isConflict => !_nonConflicting.contains(relation);

  static const _nonConflicting = {
    IntervalRelation.before,
    IntervalRelation.after,
    IntervalRelation.meets,
    IntervalRelation.metBy,
  };

  @override
  String toString() =>
      'ConflictResult(${eventA.title} ${relation.name} ${eventB.title}, conflict=$isConflict)';
}

/// Detects scheduling conflicts using Allen's Interval Algebra.
class ConflictDetectionService {
  static final ConflictDetectionService _instance =
      ConflictDetectionService._internal();
  factory ConflictDetectionService() => _instance;
  ConflictDetectionService._internal();

  // ---------------------------------------------------------------------------
  // Core: classify the Allen relation between two intervals
  // ---------------------------------------------------------------------------

  /// Determine the Allen relation of event A's interval to event B's interval.
  IntervalRelation classify(EventModel a, EventModel b) {
    final aStart = a.startTime;
    final aEnd = a.endTime;
    final bStart = b.startTime;
    final bEnd = b.endTime;

    if (aEnd.isBefore(bStart)) return IntervalRelation.before;
    if (bEnd.isBefore(aStart)) return IntervalRelation.after;

    if (aEnd.isAtSameMomentAs(bStart)) return IntervalRelation.meets;
    if (bEnd.isAtSameMomentAs(aStart)) return IntervalRelation.metBy;

    if (aStart.isAtSameMomentAs(bStart) && aEnd.isAtSameMomentAs(bEnd)) {
      return IntervalRelation.equals;
    }

    if (aStart.isAtSameMomentAs(bStart)) {
      return aEnd.isBefore(bEnd)
          ? IntervalRelation.starts
          : IntervalRelation.startedBy;
    }

    if (aEnd.isAtSameMomentAs(bEnd)) {
      return aStart.isAfter(bStart)
          ? IntervalRelation.finishes
          : IntervalRelation.finishedBy;
    }

    if (aStart.isBefore(bStart) && aEnd.isAfter(bEnd)) {
      return IntervalRelation.contains;
    }
    if (aStart.isAfter(bStart) && aEnd.isBefore(bEnd)) {
      return IntervalRelation.during;
    }

    if (aStart.isBefore(bStart)) return IntervalRelation.overlaps;
    return IntervalRelation.overlappedBy;
  }

  // ---------------------------------------------------------------------------
  // Convenience helpers
  // ---------------------------------------------------------------------------

  /// Returns true if [a] and [b] have a time-overlap conflict.
  bool hasConflict(EventModel a, EventModel b) {
    final relation = classify(a, b);
    return ConflictResult(eventA: a, eventB: b, relation: relation).isConflict;
  }

  /// Find every pair-wise conflict in [events].
  ///
  /// Returns a list of [ConflictResult] for each conflicting pair (no
  /// duplicates — if (A,B) is returned, (B,A) is not).
  List<ConflictResult> findAllConflicts(List<EventModel> events) {
    final conflicts = <ConflictResult>[];
    for (var i = 0; i < events.length; i++) {
      for (var j = i + 1; j < events.length; j++) {
        final relation = classify(events[i], events[j]);
        final result = ConflictResult(
          eventA: events[i],
          eventB: events[j],
          relation: relation,
        );
        if (result.isConflict) {
          conflicts.add(result);
        }
      }
    }
    return conflicts;
  }

  /// Find all existing events that conflict with a [proposedEvent].
  ///
  /// Useful for warning users before they save a new/updated event.
  List<ConflictResult> findConflictsWith(
    EventModel proposedEvent,
    List<EventModel> existingEvents,
  ) {
    return existingEvents
        .where((e) => e.id != proposedEvent.id)
        .map((e) {
          final relation = classify(proposedEvent, e);
          return ConflictResult(
            eventA: proposedEvent,
            eventB: e,
            relation: relation,
          );
        })
        .where((r) => r.isConflict)
        .toList();
  }

  /// Filter [events] to only those occurring at the same [location].
  ///
  /// Location-scoped conflict detection: two events in different rooms
  /// don't conflict even if their times overlap.
  List<ConflictResult> findLocationConflicts(List<EventModel> events) {
    final conflicts = <ConflictResult>[];
    for (var i = 0; i < events.length; i++) {
      for (var j = i + 1; j < events.length; j++) {
        if (events[i].location.name != events[j].location.name) continue;
        final relation = classify(events[i], events[j]);
        final result = ConflictResult(
          eventA: events[i],
          eventB: events[j],
          relation: relation,
        );
        if (result.isConflict) {
          conflicts.add(result);
        }
      }
    }
    return conflicts;
  }
}
