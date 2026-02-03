import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';

/// Widget for selecting stakeholders to add to an event
class StakeholderPickerWidget extends StatefulWidget {
  final List<String> selectedStakeholderIds;
  final Function(List<String>) onSelectionChanged;

  const StakeholderPickerWidget({
    super.key,
    required this.selectedStakeholderIds,
    required this.onSelectionChanged,
  });

  @override
  State<StakeholderPickerWidget> createState() => _StakeholderPickerWidgetState();
}

class _StakeholderPickerWidgetState extends State<StakeholderPickerWidget> {
  final _stakeholderService = StakeholderService();
  List<StakeholderModel> _stakeholders = [];
  List<String> _selectedIds = [];
  final _searchController = TextEditingController();
  List<StakeholderModel> _filteredStakeholders = [];

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.selectedStakeholderIds);
    _loadStakeholders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStakeholders() async {
    try {
      final stakeholders = await _stakeholderService.getAllStakeholders();
      setState(() {
        _stakeholders = stakeholders;
        _filteredStakeholders = stakeholders;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stakeholders: $e')),
        );
      }
    }
  }

  void _filterStakeholders(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredStakeholders = _stakeholders;
      } else {
        final lowercaseQuery = query.toLowerCase();
        _filteredStakeholders = _stakeholders.where((stakeholder) {
          return stakeholder.name.toLowerCase().contains(lowercaseQuery) ||
              stakeholder.email.toLowerCase().contains(lowercaseQuery) ||
              (stakeholder.organization?.toLowerCase().contains(lowercaseQuery) ?? false);
        }).toList();
      }
    });
  }

  void _toggleSelection(String stakeholderId) {
    setState(() {
      if (_selectedIds.contains(stakeholderId)) {
        _selectedIds.remove(stakeholderId);
      } else {
        _selectedIds.add(stakeholderId);
      }
      widget.onSelectionChanged(_selectedIds);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Stakeholders',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_selectedIds.length} stakeholder(s) selected',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),

        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        _filterStakeholders('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            onChanged: _filterStakeholders,
          ),
        ),

        const SizedBox(height: 16),

        // Stakeholder list
        Flexible(
          child: _filteredStakeholders.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _searchController.text.isEmpty
                          ? 'No stakeholders available'
                          : 'No stakeholders found',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filteredStakeholders.length,
                  itemBuilder: (context, index) {
                    final stakeholder = _filteredStakeholders[index];
                    final isSelected = _selectedIds.contains(stakeholder.id);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (_) => _toggleSelection(stakeholder.id),
                      title: Text(
                        stakeholder.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stakeholder.email),
                          if (stakeholder.organization != null)
                            Text(
                              '${stakeholder.organization}${stakeholder.title != null ? " • ${stakeholder.title}" : ""}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                      secondary: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        child: Text(
                          stakeholder.name[0].toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.trailing,
                    );
                  },
                ),
        ),

        // Action buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_selectedIds),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Show stakeholder picker dialog
Future<List<String>?> showStakeholderPicker({
  required BuildContext context,
  required List<String> selectedStakeholderIds,
}) async {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return StakeholderPickerWidget(
            selectedStakeholderIds: selectedStakeholderIds,
            onSelectionChanged: (ids) {
              // This callback is used for real-time updates within the widget
            },
          );
        },
      );
    },
  );
}
