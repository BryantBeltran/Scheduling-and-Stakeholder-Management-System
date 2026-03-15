import 'dart:async';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _eventService = EventService();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<EventModel> _allEvents = [];
  StreamSubscription<List<EventModel>>? _eventSub;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _eventService.initializeEventStream();
    _eventSub = _eventService.eventsStream.listen((events) {
      if (mounted) setState(() => _allEvents = events);
    });
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final events = await _eventService.getAllEvents();
      if (mounted) setState(() => _allEvents = events);
    } catch (_) {}
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  List<EventModel> _getEventsForDay(DateTime day) {
    return _allEvents.where((event) {
      final eventDay = DateTime(
        event.startTime.year,
        event.startTime.month,
        event.startTime.day,
      );
      final target = DateTime(day.year, day.month, day.day);
      return eventDay == target;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvents = _selectedDay != null
        ? _getEventsForDay(_selectedDay!)
        : <EventModel>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Calendar',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TableCalendar<EventModel>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getEventsForDay,
            startingDayOfWeek: StartingDayOfWeek.sunday,
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(fontSize: 12),
              weekendStyle: TextStyle(fontSize: 12),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              markerDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              markerSize: 6,
              markersMaxCount: 3,
              todayDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            availableCalendarFormats: const {
              CalendarFormat.month: 'Month',
              CalendarFormat.twoWeeks: '2 Weeks',
              CalendarFormat.week: 'Week',
            },
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              titleTextStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              formatButtonDecoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outline),
                borderRadius: BorderRadius.circular(20),
              ),
              formatButtonTextStyle: const TextStyle(fontSize: 12),
              formatButtonPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 5,
              ),
              leftChevronMargin: EdgeInsets.zero,
              rightChevronMargin: EdgeInsets.zero,
              leftChevronPadding: const EdgeInsets.symmetric(horizontal: 8),
              rightChevronPadding: const EdgeInsets.symmetric(horizontal: 8),
              headerMargin: const EdgeInsets.only(bottom: 8),
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
          ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  _selectedDay != null
                      ? _formatDate(_selectedDay!)
                      : 'Select a date',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${selectedEvents.length} event${selectedEvents.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: selectedEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, size: 48,
                            color: Theme.of(context).hintColor),
                        const SizedBox(height: 12),
                        Text(
                          'No events on this day',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: selectedEvents.length,
                    itemBuilder: (context, index) {
                      final event = selectedEvents[index];
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: Theme.of(context).dividerColor),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 4,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _getPriorityColor(event.priority),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          title: Text(
                            event.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${_formatTime(event.startTime)} - ${_formatTime(event.endTime)}',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          trailing: _buildStatusChip(event.status),
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              '/event/details',
                              arguments: event.id,
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
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

  Widget _buildStatusChip(EventStatus status) {
    Color color;
    String label;
    switch (status) {
      case EventStatus.draft:
        color = Colors.grey;
        label = 'Draft';
      case EventStatus.scheduled:
        color = Colors.blue;
        label = 'Scheduled';
      case EventStatus.inProgress:
        color = Colors.orange;
        label = 'Active';
      case EventStatus.completed:
        color = Colors.green;
        label = 'Done';
      case EventStatus.cancelled:
        color = Colors.red;
        label = 'Cancelled';
    }
    return Chip(
      label: Text(label, style: TextStyle(fontSize: 11, color: color)),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide.none,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
