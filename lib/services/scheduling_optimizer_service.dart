// ==============================================================================
// SCHEDULING OPTIMIZER SERVICE — Greedy Graph Coloring
// ==============================================================================

import '../models/models.dart';
import 'conflict_detection_service.dart';

/// A slot/resource assignment for a single event.
class SlotAssignment {
  /// The event being assigned.
  final EventModel event;

  /// The zero-based slot index (the "color").
  final int slot;

  const SlotAssignment({required this.event, required this.slot});

  @override
  String toString() => 'SlotAssignment(${event.title} → slot $slot)';
}

/// Result of optimizing a set of events into slots.
class OptimizationResult {
  /// Per-event slot assignments.
  final List<SlotAssignment> assignments;

  /// The minimum number of slots needed (= chromatic number of the
  /// interval graph, which equals the maximum clique size).
  final int slotsRequired;

  /// Events grouped by slot index.
  final Map<int, List<EventModel>> slotGroups;

  const OptimizationResult({
    required this.assignments,
    required this.slotsRequired,
    required this.slotGroups,
  });

  @override
  String toString() =>
      'OptimizationResult(slots=$slotsRequired, events=${assignments.length})';
}

/// Assigns events to the minimum number of non-conflicting slots
/// using greedy graph coloring over the interval-overlap graph.
class SchedulingOptimizerService {
  static final SchedulingOptimizerService _instance =
      SchedulingOptimizerService._internal();
  factory SchedulingOptimizerService() => _instance;
  SchedulingOptimizerService._internal();

  final ConflictDetectionService _conflictService = ConflictDetectionService();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Assign each event in [events] to the lowest available slot such that
  /// no two overlapping events share a slot.
  ///
  /// Returns an [OptimizationResult] containing the assignments, the total
  /// number of slots required, and events grouped by slot.
  OptimizationResult optimizeSlots(List<EventModel> events) {
    if (events.isEmpty) {
      return const OptimizationResult(
        assignments: [],
        slotsRequired: 0,
        slotGroups: {},
      );
    }

    // 1. Build adjacency list (conflict graph)
    final adjacency = <String, Set<String>>{};
    for (final e in events) {
      adjacency[e.id] = {};
    }
    for (var i = 0; i < events.length; i++) {
      for (var j = i + 1; j < events.length; j++) {
        if (_conflictService.hasConflict(events[i], events[j])) {
          adjacency[events[i].id]!.add(events[j].id);
          adjacency[events[j].id]!.add(events[i].id);
        }
      }
    }

    // 2. Welsh-Powell ordering: sort by descending degree
    final sorted = List<EventModel>.from(events)
      ..sort((a, b) =>
          (adjacency[b.id]?.length ?? 0).compareTo(adjacency[a.id]?.length ?? 0));

    // 3. Greedy coloring
    final colorMap = <String, int>{};
    for (final event in sorted) {
      // Collect colors used by neighbors
      final neighborColors = adjacency[event.id]!
          .where((nId) => colorMap.containsKey(nId))
          .map((nId) => colorMap[nId]!)
          .toSet();

      // Assign smallest available color
      var color = 0;
      while (neighborColors.contains(color)) {
        color++;
      }
      colorMap[event.id] = color;
    }

    // 4. Build result
    final assignments = <SlotAssignment>[];
    final slotGroups = <int, List<EventModel>>{};
    for (final event in events) {
      final slot = colorMap[event.id]!;
      assignments.add(SlotAssignment(event: event, slot: slot));
      slotGroups.putIfAbsent(slot, () => []).add(event);
    }

    return OptimizationResult(
      assignments: assignments,
      slotsRequired: slotGroups.length,
      slotGroups: slotGroups,
    );
  }

  /// Optimize slots scoped to a specific location.
  ///
  /// Only events at [locationName] are considered; the rest are ignored.
  /// Useful for room-specific scheduling (e.g., "how many sub-slots does
  /// Conference Room A need?").
  OptimizationResult optimizeSlotsForLocation(
    List<EventModel> events,
    String locationName,
  ) {
    final filtered =
        events.where((e) => e.location.name == locationName).toList();
    return optimizeSlots(filtered);
  }

  /// Suggest the best slot for a [proposedEvent] given [existingEvents].
  ///
  /// Returns the lowest slot index that has no conflicts with events
  /// already assigned to that slot.
  int suggestSlot(EventModel proposedEvent, List<EventModel> existingEvents) {
    final allEvents = [...existingEvents, proposedEvent];
    final result = optimizeSlots(allEvents);
    return result.assignments
        .firstWhere((a) => a.event.id == proposedEvent.id)
        .slot;
  }
}
