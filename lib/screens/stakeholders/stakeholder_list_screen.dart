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

      // Apply search filter (on already filtered list if type filter is active)
      if (_searchController.text.isNotEmpty) {
        final query = _searchController.text.toLowerCase();
        stakeholders = stakeholders.where((s) {
          return s.name.toLowerCase().contains(query) ||
              s.email.toLowerCase().contains(query) ||
              (s.organization?.toLowerCase().contains(query) ?? false);
        }).toList();
      }

      _filteredStakeholders = stakeholders;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Stakeholders',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
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
                          _searchController.clear();
                          _filterStakeholders();
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
              onChanged: (_) => _filterStakeholders(),
            ),
          ),

          // Filter and Sort buttons with results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: _showFilterDialog,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('Filter'),
                      SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down, size: 18),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () {
                    // TODO: Implement sort
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sort coming soon!')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('Sort'),
                      SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down, size: 18),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '${_filteredStakeholders.length} results',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),

          // Active filter chip
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
              // Avatar with purple background
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.purple[100],
                child: Icon(
                  Icons.person,
                  color: Colors.purple[700],
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        stakeholder.type.name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
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
