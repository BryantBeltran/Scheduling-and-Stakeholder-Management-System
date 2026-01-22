import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  final _eventService = EventService();
  final _searchController = TextEditingController();
  List<EventModel> _filteredEvents = [];
  EventStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _filteredEvents = _eventService.events;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterEvents() {
    setState(() {
      var events = _eventService.events;

      // Apply status filter
      if (_filterStatus != null) {
        events = events.where((e) => e.status == _filterStatus).toList();
      }

      // Apply search filter
      if (_searchController.text.isNotEmpty) {
        final query = _searchController.text.toLowerCase();
        events = events.where((e) {
          return e.title.toLowerCase().contains(query) ||
              (e.description?.toLowerCase().contains(query) ?? false);
        }).toList();
      }

      _filteredEvents = events;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search events...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterEvents();
                        },
                      )
                    : null,
              ),
              onChanged: (_) => _filterEvents(),
            ),
          ),

          // Filter chip
          if (_filterStatus != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text('Status: ${_filterStatus!.name}'),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () {
                    setState(() => _filterStatus = null);
                    _filterEvents();
                  },
                ),
              ),
            ),

          // Events list
          Expanded(
            child: _filteredEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No events found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredEvents.length,
                    itemBuilder: (context, index) {
                      final event = _filteredEvents[index];
                      return _EventListItem(event: event);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).pushNamed('/event/create');
        },
        icon: const Icon(Icons.add),
        label: const Text('New Event'),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filter Events'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('All Events'),
                leading: Radio<EventStatus?>(
                  value: null,
                  groupValue: _filterStatus,
                  onChanged: (value) {
                    setState(() => _filterStatus = value);
                    _filterEvents();
                    Navigator.pop(context);
                  },
                ),
              ),
              ...EventStatus.values.map((status) {
                return ListTile(
                  title: Text(status.name),
                  leading: Radio<EventStatus?>(
                    value: status,
                    groupValue: _filterStatus,
                    onChanged: (value) {
                      setState(() => _filterStatus = value);
                      _filterEvents();
                      Navigator.pop(context);
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _EventListItem extends StatelessWidget {
  final EventModel event;

  const _EventListItem({required this.event});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 4,
          decoration: BoxDecoration(
            color: _getPriorityColor(event.priority),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Text(
          event.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                _StatusChip(status: event.status),
                const SizedBox(width: 8),
                _PriorityChip(priority: event.priority),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _formatDate(event.startTime),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    event.location.name,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).pushNamed('/event/details', arguments: event.id);
        },
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

  String _formatDate(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day}/${dateTime.year} ${_formatTime(dateTime)}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}

class _StatusChip extends StatelessWidget {
  final EventStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        status.name,
        style: const TextStyle(fontSize: 11),
      ),
      backgroundColor: _getStatusColor(),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }

  Color _getStatusColor() {
    switch (status) {
      case EventStatus.draft:
        return Colors.grey[300]!;
      case EventStatus.scheduled:
        return Colors.blue[100]!;
      case EventStatus.inProgress:
        return Colors.green[100]!;
      case EventStatus.completed:
        return Colors.purple[100]!;
      case EventStatus.cancelled:
        return Colors.red[100]!;
    }
  }
}

class _PriorityChip extends StatelessWidget {
  final EventPriority priority;

  const _PriorityChip({required this.priority});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        priority.name,
        style: const TextStyle(fontSize: 11),
      ),
      backgroundColor: _getPriorityColor(),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }

  Color _getPriorityColor() {
    switch (priority) {
      case EventPriority.low:
        return Colors.green[100]!;
      case EventPriority.medium:
        return Colors.orange[100]!;
      case EventPriority.high:
        return Colors.red[100]!;
      case EventPriority.urgent:
        return Colors.purple[100]!;
    }
  }
}
