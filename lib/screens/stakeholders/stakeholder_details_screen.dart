import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class StakeholderDetailsScreen extends StatefulWidget {
  final String stakeholderId;

  const StakeholderDetailsScreen({
    super.key,
    required this.stakeholderId,
  });

  @override
  State<StakeholderDetailsScreen> createState() => _StakeholderDetailsScreenState();
}

class _StakeholderDetailsScreenState extends State<StakeholderDetailsScreen> {
  final _stakeholderService = StakeholderService();
  final _inviteService = InviteService();
  final _permissionService = PermissionService();
  
  bool _isInviting = false;
  StakeholderModel? _stakeholder;

  @override
  void initState() {
    super.initState();
    _loadStakeholder();
  }

  void _loadStakeholder() {
    setState(() {
      _stakeholder = _stakeholderService.stakeholders
          .firstWhere((s) => s.id == widget.stakeholderId);
    });
  }

  Future<void> _sendInvite() async {
    final stakeholder = _stakeholder;
    if (stakeholder == null) return;

    // Show role selection dialog
    final selectedRole = await _showRoleSelectionDialog();
    if (selectedRole == null) return;

    setState(() => _isInviting = true);

    try {
      final result = await _inviteService.inviteStakeholder(
        stakeholderId: stakeholder.id,
        defaultRole: selectedRole,
      );

      if (!mounted) return;

      if (result.success) {
        // Show success with invite link
        _showInviteSuccessDialog(result.inviteToken!, result.email!);
        
        // Update local state
        setState(() {
          _stakeholder = stakeholder.copyWith(
            inviteStatus: InviteStatus.pending,
            invitedAt: DateTime.now(),
          );
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send invite: ${result.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isInviting = false);
      }
    }
  }

  Future<String?> _showRoleSelectionDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose the role this stakeholder will have when they create their account:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            _RoleOption(
              role: 'viewer',
              title: 'Viewer',
              description: 'Read-only access to assigned events',
              onTap: () => Navigator.pop(context, 'viewer'),
            ),
            _RoleOption(
              role: 'member',
              title: 'Member',
              description: 'Can view and participate in events',
              onTap: () => Navigator.pop(context, 'member'),
            ),
            if (_permissionService.isSuperAdmin) ...[
              _RoleOption(
                role: 'manager',
                title: 'Manager',
                description: 'Can manage events and stakeholders',
                onTap: () => Navigator.pop(context, 'manager'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showInviteSuccessDialog(String token, String email) {
    final inviteLink = _inviteService.generateInviteLink(token);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600]),
            const SizedBox(width: 8),
            const Text('Invite Sent!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('An invitation has been prepared for:'),
            const SizedBox(height: 8),
            Text(
              email,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Share this link with them:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      inviteLink,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: inviteLink));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Link copied to clipboard!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'The invite expires in 7 days.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stakeholder = _stakeholder;
    
    if (stakeholder == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Stakeholder Details')),
        body: const Center(child: Text('Stakeholder not found')),
      );
    }

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
                    backgroundColor: _getTypeColor(stakeholder.type).withValues(alpha: 0.2),
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

          // Account Status & Invite Card
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Account Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      _InviteStatusChip(status: stakeholder.inviteStatus),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  if (stakeholder.hasAccount) ...[
                    // Has linked account
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.verified_user, color: Colors.green[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Account Linked',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                                Text(
                                  'This stakeholder has access to the app',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (stakeholder.inviteStatus == InviteStatus.pending) ...[
                    // Invite pending
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.schedule, color: Colors.orange[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Invite Pending',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[700],
                                  ),
                                ),
                                if (stakeholder.invitedAt != null)
                                  Text(
                                    'Sent ${_formatDate(stakeholder.invitedAt!)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _isInviting ? null : _sendInvite,
                            child: const Text('Resend'),
                          ),
                        ],
                      ),
                    ),
                  ] else if (_permissionService.canInviteStakeholder) ...[
                    // Can send invite
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_add, color: Colors.blue[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'No Account',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                                Text(
                                  'Invite to create an account and access events',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isInviting ? null : _sendInvite,
                        icon: _isInviting 
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                        label: Text(_isInviting ? 'Sending...' : 'Send Invite'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5B7C99),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // No permission to invite
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_off, color: Colors.grey[600]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No account linked',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      return 'today';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
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

class _RoleOption extends StatelessWidget {
  final String role;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _RoleOption({
    required this.role,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
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

class _InviteStatusChip extends StatelessWidget {
  final InviteStatus status;

  const _InviteStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _getStatusText(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _getTextColor(),
        ),
      ),
    );
  }

  String _getStatusText() {
    switch (status) {
      case InviteStatus.notInvited:
        return 'Not Invited';
      case InviteStatus.pending:
        return 'Invite Pending';
      case InviteStatus.accepted:
        return 'Has Account';
      case InviteStatus.expired:
        return 'Invite Expired';
    }
  }

  Color _getStatusColor() {
    switch (status) {
      case InviteStatus.notInvited:
        return Colors.grey[200]!;
      case InviteStatus.pending:
        return Colors.orange[100]!;
      case InviteStatus.accepted:
        return Colors.green[100]!;
      case InviteStatus.expired:
        return Colors.red[100]!;
    }
  }

  Color _getTextColor() {
    switch (status) {
      case InviteStatus.notInvited:
        return Colors.grey[700]!;
      case InviteStatus.pending:
        return Colors.orange[800]!;
      case InviteStatus.accepted:
        return Colors.green[800]!;
      case InviteStatus.expired:
        return Colors.red[800]!;
    }
  }
}
