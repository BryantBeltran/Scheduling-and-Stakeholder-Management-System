// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  final _eventService = EventService();
  final _permissionService = PermissionService();
  final _searchController = TextEditingController();
  EventStatus? _filterStatus;
  List<EventModel> _filteredEvents = [];
  String _sortBy = 'date'; // 'date', 'title', 'priority', 'status'
  bool _sortAscending = true;
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _eventService.initializeEventStream();
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _updateConnectivity(results);
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen(_updateConnectivity);
  }

  void _updateConnectivity(List<ConnectivityResult> results) {
    final offline = results.every((r) => r == ConnectivityResult.none);
    if (mounted && offline != _isOffline) {
      setState(() => _isOffline = offline);
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<EventModel> _filterEvents(List<EventModel> events) {
    var filteredEvents = events;

    // Apply status filter
    if (_filterStatus != null) {
      filteredEvents = filteredEvents.where((e) => e.effectiveStatus == _filterStatus).toList();
    }

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filteredEvents = filteredEvents.where((e) {
        return e.title.toLowerCase().contains(query) ||
            (e.description?.toLowerCase().contains(query) ?? false) ||
            e.location.name.toLowerCase().contains(query);
      }).toList();
    }

    // Apply sorting
    filteredEvents = _sortEvents(filteredEvents);

    return filteredEvents;
  }

  List<EventModel> _sortEvents(List<EventModel> events) {
    final sorted = List<EventModel>.from(events);
    
    switch (_sortBy) {
      case 'date':
        sorted.sort((a, b) => _sortAscending
            ? a.startTime.compareTo(b.startTime)
            : b.startTime.compareTo(a.startTime));
        break;
      case 'title':
        sorted.sort((a, b) => _sortAscending
            ? a.title.toLowerCase().compareTo(b.title.toLowerCase())
            : b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case 'priority':
        sorted.sort((a, b) {
          final priorityOrder = {
            EventPriority.urgent: 0,
            EventPriority.high: 1,
            EventPriority.medium: 2,
            EventPriority.low: 3,
          };
          final aOrder = priorityOrder[a.priority]!;
          final bOrder = priorityOrder[b.priority]!;
          return _sortAscending ? aOrder.compareTo(bOrder) : bOrder.compareTo(aOrder);
        });
        break;
      case 'status':
        sorted.sort((a, b) {
          final statusOrder = {
            EventStatus.inProgress: 0,
            EventStatus.scheduled: 1,
            EventStatus.draft: 2,
            EventStatus.completed: 3,
            EventStatus.cancelled: 4,
          };
          final aOrder = statusOrder[a.effectiveStatus]!;
          final bOrder = statusOrder[b.effectiveStatus]!;
          return _sortAscending ? aOrder.compareTo(bOrder) : bOrder.compareTo(aOrder);
        });
        break;
    }
    
    return sorted;
  }

  Future<void> _exportFilteredEventsAsCsv() async {
    if (_filteredEvents.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No events to export')),
        );
      }
      return;
    }

    try {
      final rows = <List<String>>[
        ['Title', 'Date', 'Start Time', 'End Time', 'Status', 'Priority', 'Location'],
        ..._filteredEvents.map((e) {
          final date = '${e.startTime.year}-${e.startTime.month.toString().padLeft(2, '0')}-${e.startTime.day.toString().padLeft(2, '0')}';
          String fmtTime(DateTime t) {
            final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
            final m = t.minute.toString().padLeft(2, '0');
            final p = t.hour >= 12 ? 'PM' : 'AM';
            return '$h:$m $p';
          }
          return [
            e.title,
            date,
            fmtTime(e.startTime),
            fmtTime(e.endTime),
            e.effectiveStatus.name,
            e.priority.name,
            e.location.isVirtual
                ? (e.location.virtualLink ?? 'Virtual')
                : e.location.name,
          ];
        }),
      ];

      final csvData = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/ssms_events_export.csv');
      await file.writeAsString(csvData);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)]),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  // Delete event with validation
  Future<void> _deleteEvent(String eventId) async {
    // Find the event to validate
    try {
      final event = await _eventService.getEventById(eventId);
      if (event != null) {
        final deleteValidation = EventValidators.canDeleteEvent(event);
        if (!deleteValidation.isValid) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(deleteValidation.errorMessage!),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }
    } catch (_) {
      // If we can't fetch the event, proceed with delete dialog anyway
    }

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text('Are you sure you want to delete this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _eventService.deleteEvent(eventId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting event: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Events',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export CSV',
            onPressed: _exportFilteredEventsAsCsv,
          ),
        ],
      ),
      body: Column(
        children: [
          // Offline banner
          if (_isOffline)
            Material(
              color: Colors.orange.shade800,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You\'re offline — showing cached events',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search Events...',
                hintStyle: TextStyle(color: Theme.of(context).hintColor),
                prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Inline status filter chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip(null, 'All'),
                ...EventStatus.values.map((s) => _buildFilterChip(s, _statusLabel(s))),
              ],
            ),
          ),

          // Events list (includes sort row + results count inside StreamBuilder)
          Expanded(
            child: StreamBuilder<List<EventModel>>(
              stream: _eventService.eventsStream,
              initialData: _eventService.cachedEvents,
              builder: (context, snapshot) {
                // Only show spinner if we have never received any data at all.
                // initialData provides cachedEvents, so once the stream has
                // emitted at least once, snapshot.data will be non-null.
                if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                final events = snapshot.data ?? [];
                _filteredEvents = _filterEvents(events);

                return Column(
                  children: [
                    // Sort button + results count
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          OutlinedButton(
                            onPressed: _showSortDialog,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_getSortLabel()),
                                const SizedBox(width: 4),
                                Icon(
                                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_filteredEvents.length} results',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_filteredEvents.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_busy, size: 64, color: Theme.of(context).hintColor),
                              const SizedBox(height: 16),
                              Text(
                                'No events found',
                                style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredEvents.length,
                          itemBuilder: (context, index) {
                    final event = _filteredEvents[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _permissionService.canDeleteEvent
                          ? Dismissible(
                              key: Key(event.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.error,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
                              ),
                              confirmDismiss: (direction) async {
                                _deleteEvent(event.id);
                                return false;
                              },
                              child: _EventListItem(
                                event: event,
                                onDelete: () => _deleteEvent(event.id),
                              ),
                            )
                          : _EventListItem(event: event, onDelete: null),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    ),
        ],
      ),
      floatingActionButton: _permissionService.canCreateEvent
          ? Container(
              margin: const EdgeInsets.only(bottom: 16, right: 16),
              child: FloatingActionButton.extended(
                onPressed: () {
                  Navigator.of(context).pushNamed('/event/create');
                },
                backgroundColor: Theme.of(context).colorScheme.onSurface,
                icon: Icon(Icons.add, color: Theme.of(context).colorScheme.surface),
                label: Text(
                  'New Event',
                  style: TextStyle(color: Theme.of(context).colorScheme.surface),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildFilterChip(EventStatus? status, String label) {
    final isSelected = _filterStatus == status;
    final chipColor = _filterChipColor(status);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _filterStatus = status),
        selectedColor: chipColor,
        checkmarkColor: Theme.of(context).colorScheme.onPrimary,
        labelStyle: TextStyle(
          color: isSelected
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        side: isSelected
            ? BorderSide.none
            : BorderSide(
                color: Theme.of(context).colorScheme.outline,
                width: 1,
              ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Color _filterChipColor(EventStatus? status) {
    switch (status) {
      case EventStatus.draft: return Colors.grey;
      case EventStatus.scheduled: return Colors.blue;
      case EventStatus.inProgress: return Colors.orange;
      case EventStatus.completed: return Colors.green;
      case EventStatus.cancelled: return Colors.red;
      default: return Theme.of(context).colorScheme.primary;
    }
  }

  String _statusLabel(EventStatus status) {
    switch (status) {
      case EventStatus.draft: return 'Draft';
      case EventStatus.scheduled: return 'Scheduled';
      case EventStatus.inProgress: return 'In Progress';
      case EventStatus.completed: return 'Completed';
      case EventStatus.cancelled: return 'Cancelled';
    }
  }

  void _showSortDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sort Events',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Sort by',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSortOption('date', 'Date', Icons.calendar_today, setModalState),
                  _buildSortOption('title', 'Title', Icons.sort_by_alpha, setModalState),
                  _buildSortOption('priority', 'Priority', Icons.flag, setModalState),
                  _buildSortOption('status', 'Status', Icons.info_outline, setModalState),
                  const SizedBox(height: 16),
                  Text(
                    'Order',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildOrderButton(true, setModalState),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildOrderButton(false, setModalState),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSortOption(String value, String label, IconData icon, StateSetter setModalState) {
    final isSelected = _sortBy == value;
    return InkWell(
      onTap: () {
        setModalState(() {});
        setState(() => _sortBy = value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Theme.of(context).dividerColor,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? Colors.blue : Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blue : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check, size: 20, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderButton(bool ascending, StateSetter setModalState) {
    final isSelected = _sortAscending == ascending;
    return InkWell(
      onTap: () {
        setModalState(() {});
        setState(() => _sortAscending = ascending);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Theme.of(context).dividerColor,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              ascending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 18,
              color: isSelected ? Colors.blue : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              ascending ? 'Ascending' : 'Descending',
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blue : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSortLabel() {
    switch (_sortBy) {
      case 'date':
        return 'Date';
      case 'title':
        return 'Title';
      case 'priority':
        return 'Priority';
      case 'status':
        return 'Status';
      default:
        return 'Sort';
    }
  }
}

class _EventListItem extends StatelessWidget {
  final EventModel event;
  final VoidCallback? onDelete;

  const _EventListItem({required this.event, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final duration = event.endTime.difference(event.startTime).inDays;
    final isUrgent = event.priority == EventPriority.urgent;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).pushNamed('/event/details', arguments: event.id);
        },
        onLongPress: () {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (ctx) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.visibility),
                    title: const Text('View Details'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).pushNamed('/event/details', arguments: event.id);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('Edit Event'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).pushNamed('/event/edit', arguments: event);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Delete Event', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(ctx);
                      onDelete?.call();
                    },
                  ),
                ],
              ),
            ),
          );
        },
        child: Row(
          children: [
            Container(
              width: 4,
              height: 100,
              decoration: BoxDecoration(
                color: _getPriorityColor(event.priority),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${event.title} ${duration > 0 ? "${duration}d" : ""}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event.location.isVirtual ? 'Virtual Meeting' : 'Physical Meeting',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (isUrgent) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Urgent',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            () {
                              final s = event.startTime;
                              final sh = s.hour == 0 ? 12 : (s.hour > 12 ? s.hour - 12 : s.hour);
                              final sm = s.minute.toString().padLeft(2, '0');
                              final sp = s.hour >= 12 ? 'PM' : 'AM';
                              final e = event.endTime;
                              final eh = e.hour == 0 ? 12 : (e.hour > 12 ? e.hour - 12 : e.hour);
                              final em = e.minute.toString().padLeft(2, '0');
                              final ep = e.hour >= 12 ? 'PM' : 'AM';
                              return '$sh:$sm $sp - $eh:$em $ep';
                            }(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.location_on, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.location.isVirtual
                                ? (event.location.virtualLink ?? 'Virtual')
                                : event.location.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Centered chevron arrow
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(EventPriority priority) {
    switch (priority) {
      case EventPriority.low:
        return Colors.green;
      case EventPriority.medium:
        return Colors.orange;
      case EventPriority.high:
        return Colors.red;
      case EventPriority.urgent:
        return Colors.purple;
    }
  }

}
