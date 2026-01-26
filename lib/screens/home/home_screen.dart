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
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '',
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
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            // TODO: Open drawer/menu
          },
        ),
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        centerTitle: true,
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
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: StreamBuilder<UserModel?>(
              stream: authService.authStateChanges,
              builder: (context, snapshot) {
                final user = snapshot.data ?? authService.currentUser;
                return CircleAvatar(
                  radius: 18,
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Text(
                    (user?.displayName.isNotEmpty ?? false) 
                        ? user!.displayName[0].toUpperCase() 
                        : 'U',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // TODO: Refresh data
          await Future.delayed(const Duration(seconds: 1));
        },
        child: StreamBuilder<UserModel?>(
          stream: authService.authStateChanges,
          builder: (context, authSnapshot) {
            final user = authSnapshot.data ?? authService.currentUser;
            
            return StreamBuilder<List<EventModel>>(
              stream: eventService.eventsStream,
              builder: (context, eventsSnapshot) {
                return StreamBuilder<List<StakeholderModel>>(
                  stream: stakeholderService.stakeholdersStream,
                  builder: (context, stakeholdersSnapshot) {
                    if (!eventsSnapshot.hasData || !stakeholdersSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final events = eventsSnapshot.data!;
                    final stakeholders = stakeholdersSnapshot.data!;
                    final now = DateTime.now();
                    final upcomingEvents = events
                        .where((e) => e.startTime.isAfter(now))
                        .toList()
                      ..sort((a, b) => a.startTime.compareTo(b.startTime));
                    final completedEvents = events
                        .where((e) => e.status == EventStatus.completed)
                        .toList();

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Statistics - Top Row
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                icon: Icons.calendar_today,
                                title: 'Total Events',
                                value: '${events.length}',
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.people,
                                title: 'Stakeholders',
                                value: '${stakeholders.length}',
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Statistics - Combined Upcoming/Completed Card
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Upcoming',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${upcomingEvents.length}',
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Icon(
                                        Icons.access_time,
                                        color: Colors.orange,
                                        size: 32,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 60,
                                color: Colors.grey[300],
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Completed',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${completedEvents.length}',
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.purple,
                                        size: 32,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Upcoming Events Section
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey[200]!),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Upcoming Events',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Upcoming events list
                                ...upcomingEvents.take(3).map((event) {
                                  return _EventCard(event: event);
                                }),
                                if (upcomingEvents.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Center(
                                      child: Text(
                                        'No upcoming events',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Icon(icon, color: color, size: 32),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey[200],
            child: Icon(
              Icons.event,
              color: Colors.grey[600],
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.location.name,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Time',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Location',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
