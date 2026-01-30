import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/models.dart';
import '../../services/services.dart';

/// Dashboard screen for stakeholder users to view their assigned events
class StakeholderDashboardScreen extends StatefulWidget {
  const StakeholderDashboardScreen({super.key});

  @override
  State<StakeholderDashboardScreen> createState() => _StakeholderDashboardScreenState();
}

class _StakeholderDashboardScreenState extends State<StakeholderDashboardScreen> {
  final _authService = AuthService();
  final _firestore = FirebaseFirestore.instance;
  
  List<EventModel> _assignedEvents = [];
  StakeholderModel? _stakeholderProfile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStakeholderData();
  }

  Future<void> _loadStakeholderData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Not logged in';
          _isLoading = false;
        });
        return;
      }

      // Find stakeholder linked to this user
      final stakeholderQuery = await _firestore
          .collection('stakeholders')
          .where('linkedUserId', isEqualTo: user.id)
          .limit(1)
          .get();

      if (stakeholderQuery.docs.isEmpty) {
        // Also check by email
        final emailQuery = await _firestore
            .collection('stakeholders')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();

        if (emailQuery.docs.isEmpty) {
          setState(() {
            _error = 'No stakeholder profile found';
            _isLoading = false;
          });
          return;
        }

        final stakeholderData = emailQuery.docs.first.data();
        stakeholderData['id'] = emailQuery.docs.first.id;
        _stakeholderProfile = StakeholderModel.fromJson(stakeholderData);
      } else {
        final stakeholderData = stakeholderQuery.docs.first.data();
        stakeholderData['id'] = stakeholderQuery.docs.first.id;
        _stakeholderProfile = StakeholderModel.fromJson(stakeholderData);
      }

      // Load events this stakeholder is assigned to
      if (_stakeholderProfile!.eventIds.isNotEmpty) {
        final eventsQuery = await _firestore
            .collection('events')
            .where(FieldPath.documentId, whereIn: _stakeholderProfile!.eventIds)
            .get();

        _assignedEvents = eventsQuery.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return EventModel.fromJson(data);
        }).toList();

        // Sort by start time
        _assignedEvents.sort((a, b) => a.startTime.compareTo(b.startTime));
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Events',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStakeholderData,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadStakeholderData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStakeholderData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stakeholder Profile Card
          if (_stakeholderProfile != null) _buildProfileCard(),
          const SizedBox(height: 24),

          // Events Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Assigned Events',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_assignedEvents.length} event(s)',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_assignedEvents.isEmpty)
            _buildEmptyEventsCard()
          else
            ..._buildEventsList(),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final stakeholder = _stakeholderProfile!;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFF5B7C99).withValues(alpha: 0.2),
              child: Text(
                stakeholder.name[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5B7C99),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stakeholder.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (stakeholder.organization != null)
                    Text(
                      stakeholder.organization!,
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getRelationshipColor(stakeholder.relationshipType),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      stakeholder.relationshipType.name.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyEventsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.event_available,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Events Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You haven\'t been assigned to any events yet.\nCheck back later!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildEventsList() {
    final now = DateTime.now();
    final upcomingEvents = _assignedEvents.where((e) => e.startTime.isAfter(now)).toList();
    final pastEvents = _assignedEvents.where((e) => e.startTime.isBefore(now)).toList();

    return [
      if (upcomingEvents.isNotEmpty) ...[
        _buildSectionHeader('Upcoming', Icons.upcoming, Colors.blue),
        ...upcomingEvents.map((e) => _buildEventCard(e, isUpcoming: true)),
        const SizedBox(height: 16),
      ],
      if (pastEvents.isNotEmpty) ...[
        _buildSectionHeader('Past', Icons.history, Colors.grey),
        ...pastEvents.map((e) => _buildEventCard(e, isUpcoming: false)),
      ],
    ];
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(EventModel event, {required bool isUpcoming}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isUpcoming ? const Color(0xFF5B7C99).withValues(alpha: 0.3) : Colors.grey[200]!,
        ),
      ),
      child: InkWell(
        onTap: () => _showEventDetails(event),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isUpcoming ? Colors.black : Colors.grey[600],
                      ),
                    ),
                  ),
                  _buildStatusBadge(event.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDateTime(event.startTime),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              if (event.location.name.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        event.location.name,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (event.description != null && event.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  event.description!,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(EventStatus status) {
    Color bgColor;
    Color textColor;
    String text;

    switch (status) {
      case EventStatus.scheduled:
        bgColor = Colors.blue[100]!;
        textColor = Colors.blue[800]!;
        text = 'Scheduled';
        break;
      case EventStatus.inProgress:
        bgColor = Colors.green[100]!;
        textColor = Colors.green[800]!;
        text = 'In Progress';
        break;
      case EventStatus.completed:
        bgColor = Colors.grey[200]!;
        textColor = Colors.grey[700]!;
        text = 'Completed';
        break;
      case EventStatus.cancelled:
        bgColor = Colors.red[100]!;
        textColor = Colors.red[800]!;
        text = 'Cancelled';
        break;
      case EventStatus.draft:
        bgColor = Colors.orange[100]!;
        textColor = Colors.orange[800]!;
        text = 'Draft';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  void _showEventDetails(EventModel event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title and status
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildStatusBadge(event.status),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Priority
                  Row(
                    children: [
                      Icon(Icons.flag, size: 18, color: _getPriorityColor(event.priority)),
                      const SizedBox(width: 8),
                      Text(
                        '${event.priority.name.toUpperCase()} Priority',
                        style: TextStyle(
                          color: _getPriorityColor(event.priority),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Date & Time
                  _buildDetailRow(
                    Icons.calendar_today,
                    'Date & Time',
                    '${_formatDateTime(event.startTime)} - ${_formatTime(event.endTime)}',
                  ),
                  const SizedBox(height: 12),

                  // Location
                  if (event.location.name.isNotEmpty)
                    _buildDetailRow(
                      Icons.location_on,
                      'Location',
                      event.location.name,
                    ),
                  const SizedBox(height: 12),

                  // Organizer
                  if (event.ownerName != null && event.ownerName!.isNotEmpty)
                    _buildDetailRow(
                      Icons.person,
                      'Organizer',
                      event.ownerName!,
                    ),
                  const SizedBox(height: 16),

                  // Description
                  if (event.description != null && event.description!.isNotEmpty) ...[
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event.description!,
                      style: TextStyle(
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '${months[date.month - 1]} ${date.day}, ${date.year} at $hour:$minute $period';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  Color _getRelationshipColor(RelationshipType type) {
    switch (type) {
      case RelationshipType.organizer:
        return Colors.purple[100]!;
      case RelationshipType.presenter:
        return Colors.blue[100]!;
      case RelationshipType.attendee:
        return Colors.green[100]!;
      case RelationshipType.sponsor:
        return Colors.amber[100]!;
      case RelationshipType.guest:
        return Colors.teal[100]!;
      case RelationshipType.support:
        return Colors.orange[100]!;
    }
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
        return Colors.red[900]!;
    }
  }
}
