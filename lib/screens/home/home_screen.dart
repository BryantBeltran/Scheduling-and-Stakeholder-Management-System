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
import '../stakeholders/stakeholder_dashboard_screen.dart';
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
  final _permissionService = PermissionService();

  @override
  void initState() {
    super.initState();
    // Initialize event stream from Firestore or mock data
    _eventService.initializeEventStream();
    // Initialize stakeholder data (dev: mock, prod: Firestore)
    _stakeholderService.initializeSampleData();
  }

  /// Check if user can access the Stakeholders tab
  /// All authenticated users (Member+) can view stakeholders
  bool get _canAccessStakeholders {
    return _permissionService.canViewStakeholder;
  }

  final List<Widget> _screens = const [
    DashboardScreen(),
    EventListScreen(),
    StakeholderListScreen(),
    ProfileScreen(),
  ];

  void _onNavTap(int index) {
    // Check permission for Stakeholders tab (index 2)
    if (index == 2 && !_canAccessStakeholders) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to view stakeholders'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  List<EventModel> _events = [];
  List<StakeholderModel> _stakeholders = [];
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final eventService = EventService();
      final stakeholderService = StakeholderService();
      
      // Fetch events from Firestore or mock data
      _events = await eventService.getAllEvents();
      
      // Get stakeholders from Firestore or mock data
      _stakeholders = await stakeholderService.getAllStakeholders();
    } catch (e) {
      debugPrint('Error loading data: $e');
      // Initialize with empty lists on error
      _events = [];
      _stakeholders = [];
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
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
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
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
            padding: const EdgeInsets.only(right: 12.0),
            child: StreamBuilder<UserModel?>(
              stream: authService.authStateChanges,
              builder: (context, snapshot) {
                final user = snapshot.data ?? authService.currentUser;
                return CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey[300],
                  child: Text(
                    (user?.displayName.isNotEmpty ?? false) 
                        ? user!.displayName[0].toUpperCase() 
                        : 'U',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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
          await _loadData();
        },
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : StreamBuilder<UserModel?>(
          stream: authService.authStateChanges,
          builder: (context, authSnapshot) {
            final now = DateTime.now();
            final upcomingEvents = _events
                .where((e) => e.startTime.isAfter(now))
                .toList()
              ..sort((a, b) => a.startTime.compareTo(b.startTime));
            final completedEvents = _events
                .where((e) => e.status == EventStatus.completed)
                .toList();

            return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Statistics - Combined Total Events/Stakeholders Card
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
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Total Events',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '${_events.length}',
                                            style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Icon(
                                        Icons.calendar_today,
                                        color: Colors.blue,
                                        size: 36,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 80,
                                color: Colors.grey[300],
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Stakeholders',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '${_stakeholders.length}',
                                            style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Icon(
                                        Icons.people,
                                        color: Colors.green,
                                        size: 36,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
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
                                  padding: const EdgeInsets.all(20),
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
                                          const SizedBox(height: 8),
                                          Text(
                                            '${upcomingEvents.length}',
                                            style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Icon(
                                        Icons.access_time,
                                        color: Colors.orange,
                                        size: 36,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 80,
                                color: Colors.grey[300],
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
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
                                          const SizedBox(height: 8),
                                          Text(
                                            '${completedEvents.length}',
                                            style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.purple,
                                        size: 36,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Stakeholder Dashboard Card (shows if user is a stakeholder)
                        if (authSnapshot.data?.isStakeholder == true)
                          _buildStakeholderDashboardCard(context),
                        if (authSnapshot.data?.isStakeholder == true)
                          const SizedBox(height: 20),
                        
                        // Upcoming Events Section
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                                child: const Text(
                                  'Upcoming Events',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // Scrollable event list
                              SizedBox(
                                height: upcomingEvents.isEmpty ? 100 : 300,
                                child: upcomingEvents.isEmpty
                                    ? Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: Text(
                                            'No upcoming events',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                        itemCount: upcomingEvents.length,
                                        separatorBuilder: (context, index) => const SizedBox(height: 16),
                                        itemBuilder: (context, index) {
                                          return _EventCard(event: upcomingEvents[index]);
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
          },
        ),
      ),
    );
  }

  Widget _buildStakeholderDashboardCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFF5B7C99).withValues(alpha: 0.3)),
      ),
      color: const Color(0xFF5B7C99).withValues(alpha: 0.05),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const StakeholderDashboardScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B7C99).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.event_available,
                  color: Color(0xFF5B7C99),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Assigned Events',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'View events you\'re assigned to as a stakeholder',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF5B7C99),
              ),
            ],
          ),
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
    return InkWell(
      onTap: () {
        Navigator.of(context).pushNamed('/event/details', arguments: event.id);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Column
            Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: _getPriorityColor(event.priority).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getMonthAbbr(event.startTime.month),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _getPriorityColor(event.priority),
                    ),
                  ),
                  Text(
                    '${event.startTime.day}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _getPriorityColor(event.priority),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Event Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildStatusBadge(event.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimeRange(event.startTime, event.endTime),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        event.location.isVirtual ? Icons.videocam : Icons.location_on,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location.name,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (event.stakeholderIds.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.people, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${event.stakeholderIds.length} stakeholder${event.stakeholderIds.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(EventStatus status) {
    Color color;
    String label;
    
    switch (status) {
      case EventStatus.draft:
        color = Colors.grey;
        label = 'Draft';
        break;
      case EventStatus.scheduled:
        color = Colors.blue;
        label = 'Scheduled';
        break;
      case EventStatus.inProgress:
        color = Colors.orange;
        label = 'Active';
        break;
      case EventStatus.completed:
        color = Colors.green;
        label = 'Done';
        break;
      case EventStatus.cancelled:
        color = Colors.red;
        label = 'Cancelled';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
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

  String _getMonthAbbr(int month) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
                    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return months[month - 1];
  }

  String _formatTimeRange(DateTime start, DateTime end) {
    final startHour = start.hour > 12 ? start.hour - 12 : (start.hour == 0 ? 12 : start.hour);
    final startMin = start.minute.toString().padLeft(2, '0');
    final startPeriod = start.hour >= 12 ? 'PM' : 'AM';
    
    final endHour = end.hour > 12 ? end.hour - 12 : (end.hour == 0 ? 12 : end.hour);
    final endMin = end.minute.toString().padLeft(2, '0');
    final endPeriod = end.hour >= 12 ? 'PM' : 'AM';
    
    return '$startHour:$startMin $startPeriod - $endHour:$endMin $endPeriod';
  }
}
