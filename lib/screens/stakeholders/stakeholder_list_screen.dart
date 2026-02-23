// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import 'stakeholder_create_screen.dart';

class StakeholderListScreen extends StatefulWidget {
  const StakeholderListScreen({super.key});

  @override
  State<StakeholderListScreen> createState() => _StakeholderListScreenState();
}

enum _SortOption { nameAZ, nameZA, type, status, dateNewest }

class _StakeholderListScreenState extends State<StakeholderListScreen> {
  final _stakeholderService = StakeholderService();
  final _permissionService = PermissionService();
  final _searchController = TextEditingController();
  List<StakeholderModel> _allStakeholders = [];
  List<StakeholderModel> _filteredStakeholders = [];
  StakeholderType? _filterType;
  _SortOption _sortOption = _SortOption.nameAZ;
  bool _isLoading = true;

  /// Check if user can create stakeholders (based on permissions)
  bool get _canCreateStakeholder {
    return _permissionService.canCreateStakeholder;
  }

  @override
  void initState() {
    super.initState();
    _loadStakeholders();
  }

  Future<void> _loadStakeholders() async {
    setState(() => _isLoading = true);
    try {
      final stakeholders = await _stakeholderService.getAllStakeholders();
      setState(() {
        _allStakeholders = stakeholders;
        _filteredStakeholders = stakeholders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stakeholders: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterStakeholders() {
    setState(() {
      var stakeholders = List<StakeholderModel>.from(_allStakeholders);

      // Apply type filter
      if (_filterType != null) {
        stakeholders = stakeholders.where((s) => s.type == _filterType).toList();
      }

      // Apply search filter
      if (_searchController.text.isNotEmpty) {
        final query = _searchController.text.toLowerCase();
        stakeholders = stakeholders.where((s) {
          return s.name.toLowerCase().contains(query) ||
              s.email.toLowerCase().contains(query) ||
              (s.organization?.toLowerCase().contains(query) ?? false);
        }).toList();
      }

      // Apply sort
      switch (_sortOption) {
        case _SortOption.nameAZ:
          stakeholders.sort((a, b) => a.name.compareTo(b.name));
        case _SortOption.nameZA:
          stakeholders.sort((a, b) => b.name.compareTo(a.name));
        case _SortOption.type:
          stakeholders.sort((a, b) => a.type.name.compareTo(b.type.name));
        case _SortOption.status:
          stakeholders.sort(
              (a, b) => a.participationStatus.name.compareTo(b.participationStatus.name));
        case _SortOption.dateNewest:
          stakeholders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      _filteredStakeholders = stakeholders;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Stakeholders',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
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
                  onPressed: _showSortDialog,
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredStakeholders.isEmpty
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
      floatingActionButton: _canCreateStakeholder
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (context) => const StakeholderCreateScreen(),
                  ),
                );
                if (result == true) {
                  // Refresh the list after creating a stakeholder
                  await _loadStakeholders();
                  _filterStakeholders();
                }
              },
              backgroundColor: Colors.black,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
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
              RadioListTile<StakeholderType?>(
                title: const Text('All Types'),
                value: null,
                groupValue: _filterType,
                onChanged: (value) {
                  setState(() => _filterType = value);
                  _filterStakeholders();
                  Navigator.pop(context);
                },
              ),
              ...StakeholderType.values.map((type) {
                return RadioListTile<StakeholderType?>(
                  title: Text(type.name),
                  value: type,
                  groupValue: _filterType,
                  onChanged: (value) {
                    setState(() => _filterType = value);
                    _filterStakeholders();
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

  void _showSortDialog() {
    final options = <({_SortOption option, String label})>[
      (option: _SortOption.nameAZ, label: 'Name A → Z'),
      (option: _SortOption.nameZA, label: 'Name Z → A'),
      (option: _SortOption.type, label: 'Type'),
      (option: _SortOption.status, label: 'Participation Status'),
      (option: _SortOption.dateNewest, label: 'Date Added (Newest)'),
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort Stakeholders'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((entry) {
            return RadioListTile<_SortOption>(
              title: Text(entry.label),
              value: entry.option,
              groupValue: _sortOption,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _sortOption = value);
                  _filterStakeholders();
                }
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
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
}
