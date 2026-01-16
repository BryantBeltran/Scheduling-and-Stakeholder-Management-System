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
  List<StakeholderModel> _filteredStakeholders = [];
  StakeholderType? _filterType;

  @override
  void initState() {
    super.initState();
    _filteredStakeholders = _stakeholderService.stakeholders;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterStakeholders() {
    setState(() {
      var stakeholders = _stakeholderService.stakeholders;

      // Apply type filter
      if (_filterType != null) {
        stakeholders = stakeholders.where((s) => s.type == _filterType).toList();
      }

      // Apply search filter
      if (_searchController.text.isNotEmpty) {
        stakeholders = _stakeholderService.searchStakeholders(_searchController.text);
      }

      _filteredStakeholders = stakeholders;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stakeholders'),
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
                hintText: 'Search stakeholders...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterStakeholders();
                        },
                      )
                    : null,
              ),
              onChanged: (_) => _filterStakeholders(),
            ),
          ),

          // Filter chip
          if (_filterType != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text('Type: ${_filterType!.name}'),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () {
                    setState(() => _filterType = null);
                    _filterStakeholders();
                  },
                ),
              ),
            ),

          // Stakeholders list
          Expanded(
            child: _filteredStakeholders.isEmpty
                ? Center(
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
                  )
                : ListView.builder(
                    itemCount: _filteredStakeholders.length,
                    itemBuilder: (context, index) {
                      final stakeholder = _filteredStakeholders[index];
                      return _StakeholderListItem(stakeholder: stakeholder);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).pushNamed('/stakeholder/create');
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add Stakeholder'),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filter Stakeholders'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('All Types'),
                leading: Radio<StakeholderType?>(
                  value: null,
                  groupValue: _filterType,
                  onChanged: (value) {
                    setState(() => _filterType = value);
                    _filterStakeholders();
                    Navigator.pop(context);
                  },
                ),
              ),
              ...StakeholderType.values.map((type) {
                return ListTile(
                  title: Text(type.name),
                  leading: Radio<StakeholderType?>(
                    value: type,
                    groupValue: _filterType,
                    onChanged: (value) {
                      setState(() => _filterType = value);
                      _filterStakeholders();
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

class _StakeholderListItem extends StatelessWidget {
  final StakeholderModel stakeholder;

  const _StakeholderListItem({required this.stakeholder});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getTypeColor(stakeholder.type),
          child: Text(
            stakeholder.name[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          stakeholder.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (stakeholder.organization != null)
              Text(
                stakeholder.organization!,
                style: const TextStyle(fontSize: 13),
              ),
            Text(
              stakeholder.email,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _TypeChip(type: stakeholder.type),
                const SizedBox(width: 8),
                _StatusChip(status: stakeholder.participationStatus),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).pushNamed('/stakeholder/details', arguments: stakeholder.id);
        },
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
