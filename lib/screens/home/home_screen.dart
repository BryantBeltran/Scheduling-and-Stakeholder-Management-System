// ==============================================================================
// HOME SCREEN & DASHBOARD
// ==============================================================================
// Source: UI patterns inspired by:
// - Google Calendar mobile app dashboard
// - Microsoft Teams home screen
// - Todoist app dashboard layout
// - Material Design bottom navigation patterns
//
// Implementation Details:
// - Bottom navigation with 4 main sections
// - Dashboard with statistics cards and upcoming events
// - Welcome card with user avatar
// - Quick action FAB for event creation
// - Pull-to-refresh support
//
// Dashboard Components:
// - Statistics cards: Total events, stakeholders, upcoming, completed
// - Upcoming events list with preview of next 3 events
// - Color-coded priority and status indicators
// - Formatted date/time display with "Today"/"Tomorrow" labels
//
// Changes from standard patterns:
// - Statistics displayed as grid of cards instead of list
// - Custom color scheme for different priorities and statuses
// - Integrated navigation state management within home screen
//
// Reference:
// - Bottom Navigation: https://m3.material.io/components/navigation-bar
// - Dashboard patterns: https://material.io/design/layout/understanding-layout.html
// ==============================================================================

import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../events/event_list_screen.dart';
import '../stakeholders/stakeholder_list_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _eventService = EventService();
  final _stakeholderService = StakeholderService();

  @override
  void initState() {
    super.initState();
    // Initialize sample data
    _eventService.initializeSampleData();
    _stakeholderService.initializeSampleData();
  }

  final List<Widget> _screens = const [
    DashboardScreen(),
    EventListScreen(),
    StakeholderListScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Stakeholders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final eventService = EventService();
    final stakeholderService = StakeholderService();
    final authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Show notifications
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications coming soon!')),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // TODO: Refresh data
          await Future.delayed(const Duration(seconds: 1));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Welcome card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Theme.of(context).primaryColor,
                          child: Text(
                            authService.currentUser?.displayName[0].toUpperCase() ?? 'U',
                            style: const TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back,',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                authService.currentUser?.displayName ?? 'User',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Statistics
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.event,
                    title: 'Total Events',
                    value: '${eventService.events.length}',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.people,
                    title: 'Stakeholders',
                    value: '${stakeholderService.stakeholders.length}',
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.schedule,
                    title: 'Upcoming',
                    value: '${eventService.getUpcomingEvents().length}',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.check_circle,
                    title: 'Completed',
                    value: '${eventService.getEventsByStatus(EventStatus.completed).length}',
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Upcoming Events Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Upcoming Events',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to events tab
                    // Note: In production, use proper state management (Provider, Riverpod, etc.)
                    // to control navigation between tabs
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Upcoming events list
            ...eventService.getUpcomingEvents(limit: 3).map((event) {
              return _EventCard(event: event);
            }),

            if (eventService.getUpcomingEvents().isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No upcoming events',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pushNamed('/event/create');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventModel event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getPriorityColor(event.priority),
          child: Icon(
            _getStatusIcon(event.status),
            color: Colors.white,
            size: 20,
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
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    event.location.name,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(event.startTime),
                  style: const TextStyle(fontSize: 12),
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

  IconData _getStatusIcon(EventStatus status) {
    switch (status) {
      case EventStatus.draft:
        return Icons.edit;
      case EventStatus.scheduled:
        return Icons.schedule;
      case EventStatus.inProgress:
        return Icons.play_arrow;
      case EventStatus.completed:
        return Icons.check;
      case EventStatus.cancelled:
        return Icons.cancel;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final eventDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String dateStr;
    if (eventDate == today) {
      dateStr = 'Today';
    } else if (eventDate == tomorrow) {
      dateStr = 'Tomorrow';
    } else {
      dateStr = '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }

    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$dateStr at $hour:$minute $period';
  }
}
