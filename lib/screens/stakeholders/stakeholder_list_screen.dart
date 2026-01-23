import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class StakeholderListScreen extends StatefulWidget {
  const StakeholderListScreen({super.key});

  @override
  State<StakeholderListScreen> createState() => _StakeholderListScreenState();
}

class _StakeholderListScreenState extends State<StakeholderListScreen> {
  final _stakeholderService = StakeholderService();
  final _searchController = TextEditingController();
  StakeholderType? _filterType;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<StakeholderModel> _filterStakeholders(List<StakeholderModel> stakeholders) {
    var filtered = stakeholders;

    // Apply type filter
    if (_filterType != null) {
      filtered = filtered.where((s) => s.type == _filterType).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((s) =>
        s.name.toLowerCase().contains(query) ||
        s.email.toLowerCase().contains(query) ||
        (s.organization?.toLowerCase().contains(query) ?? false)
      ).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stakeholders'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar with modern styling
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search Stakeholders',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),

          // Filter and Sort buttons with results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: StreamBuilder<List<StakeholderModel>>(
              stream: _stakeholderService.stakeholdersStream,
              builder: (context, snapshot) {
                final count = snapshot.hasData ? _filterStakeholders(snapshot.data!).length : 0;
                return Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _showFilterDialog,
                      icon: const Icon(Icons.filter_list, size: 18),
                      label: const Text('Filter'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Implement sort
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sort coming soon!')),
                        );
                      },
                      icon: const Icon(Icons.sort, size: 18),
                      label: const Text('Sort'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$count results',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          
          const SizedBox(height: 8),

          // Active filter chip
          if (_filterType != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text('Type: ${_filterType!.name}'),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () {
                    setState(() => _filterType = null);
                  },
                ),
              ),
            ),

          // Stakeholders list with StreamBuilder
          Expanded(
            child: StreamBuilder<List<StakeholderModel>>(
              stream: _stakeholderService.stakeholdersStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No stakeholders found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final filteredStakeholders = _filterStakeholders(snapshot.data!);

                if (filteredStakeholders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No matching stakeholders',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredStakeholders.length,
                  itemBuilder: (context, index) {
                    final stakeholder = filteredStakeholders[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _StakeholderCard(stakeholder: stakeholder),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pushNamed('/stakeholder/create');
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filter by Type'),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FilterOption(
                title: 'All Types',
                value: null,
                groupValue: _filterType,
                onChanged: (value) {
                  setState(() => _filterType = value);
                  Navigator.pop(context);
                },
              ),
              const Divider(height: 1),
              ...StakeholderType.values.map((type) {
                return _FilterOption(
                  title: type.name.replaceFirst(type.name[0], type.name[0].toUpperCase()),
                  value: type,
                  groupValue: _filterType,
                  onChanged: (value) {
                    setState(() => _filterType = value);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _FilterOption extends StatelessWidget {
  final String title;
  final StakeholderType? value;
  final StakeholderType? groupValue;
  final ValueChanged<StakeholderType?> onChanged;

  const _FilterOption({
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<StakeholderType?>(
      title: Text(title),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
}

class _StakeholderCard extends StatelessWidget {
  final StakeholderModel stakeholder;

  const _StakeholderCard({required this.stakeholder});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).pushNamed('/stakeholder/details', arguments: stakeholder.id);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar with colored background
              CircleAvatar(
                radius: 28,
                backgroundColor: _getTypeColor(stakeholder.type).withOpacity(0.15),
                child: Icon(
                  Icons.person,
                  color: _getTypeColor(stakeholder.type),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Info section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stakeholder.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (stakeholder.organization != null)
                      Text(
                        stakeholder.organization!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getTypeColor(stakeholder.type).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _getTypeColor(stakeholder.type).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            stakeholder.type.name,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _getTypeColor(stakeholder.type),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Chevron icon
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
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

class _TypeChip extends StatelessWidget {
  final StakeholderType type;

  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        type.name,
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
      case ParticipationStatus.pending:
        return Colors.grey[300]!;
      case ParticipationStatus.accepted:
        return Colors.green[100]!;
      case ParticipationStatus.declined:
        return Colors.red[100]!;
      case ParticipationStatus.tentative:
        return Colors.yellow[100]!;
      case ParticipationStatus.noResponse:
        return Colors.grey[200]!;
    }
  }
}
