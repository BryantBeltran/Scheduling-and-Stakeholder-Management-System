import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class StakeholderDetailsScreen extends StatelessWidget {
  final String stakeholderId;

  const StakeholderDetailsScreen({
    super.key,
    required this.stakeholderId,
  });

  @override
  Widget build(BuildContext context) {
    final stakeholderService = StakeholderService();
    final stakeholder = stakeholderService.stakeholders
        .firstWhere((s) => s.id == stakeholderId);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Stakeholder Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Navigate to edit screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit coming soon!')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: _getTypeColor(stakeholder.type).withOpacity(0.2),
                    child: Text(
                      stakeholder.name[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: _getTypeColor(stakeholder.type),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    stakeholder.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (stakeholder.title != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      stakeholder.title!,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                  if (stakeholder.organization != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      stakeholder.organization!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _TypeChip(type: stakeholder.type),
                      const SizedBox(width: 8),
                      _StatusChip(status: stakeholder.participationStatus),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Contact Information Card
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
                    'Contact Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: Icons.email,
                    label: 'Email',
                    value: stakeholder.email,
                  ),
                  if (stakeholder.phone != null) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.phone,
                      label: 'Phone',
                      value: stakeholder.phone!,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Event Information Card
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
                    'Event Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: Icons.badge,
                    label: 'Role',
                    value: stakeholder.relationshipType.name.toUpperCase(),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.event,
                    label: 'Events',
                    value: '${stakeholder.eventIds.length} event(s)',
                  ),
                ],
              ),
            ),
          ),

          if (stakeholder.notes != null && stakeholder.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
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
                      'Notes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      stakeholder.notes!,
                      style: TextStyle(
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getTypeColor(StakeholderType type) {
    switch (type) {
      case StakeholderType.internal:
        return Colors.blue;
      case StakeholderType.external:
        return Colors.green;
      case StakeholderType.client:
        return Colors.purple;
      case StakeholderType.vendor:
        return Colors.orange;
      case StakeholderType.partner:
        return Colors.teal;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final StakeholderType type;

  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        type.name.toUpperCase(),
        style: const TextStyle(fontSize: 11),
      ),
      backgroundColor: _getTypeColor(),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }

  Color _getTypeColor() {
    switch (type) {
      case StakeholderType.internal:
        return Colors.blue[100]!;
      case StakeholderType.external:
        return Colors.green[100]!;
      case StakeholderType.client:
        return Colors.purple[100]!;
      case StakeholderType.vendor:
        return Colors.orange[100]!;
      case StakeholderType.partner:
        return Colors.teal[100]!;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final ParticipationStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        status.name.toUpperCase(),
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
      case ParticipationStatus.accepted:
        return Colors.green[100]!;
      case ParticipationStatus.declined:
        return Colors.red[100]!;
      case ParticipationStatus.tentative:
        return Colors.orange[100]!;
      case ParticipationStatus.pending:
        return Colors.blue[100]!;
      case ParticipationStatus.noResponse:
        return Colors.grey[300]!;
    }
  }
}
