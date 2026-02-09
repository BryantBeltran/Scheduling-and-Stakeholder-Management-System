// ==============================================================================
// EVENT EDIT SCREEN
// ==============================================================================
// Provides full editing capabilities for existing events.
// Includes comprehensive validation and stakeholder management.
// ==============================================================================

import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/widgets.dart';
import 'stakeholder_picker_widget.dart';

/// Screen for editing existing events
class EventEditScreen extends StatefulWidget {
  final EventModel event;

  const EventEditScreen({super.key, required this.event});

  @override
  State<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends State<EventEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _virtualLinkController;

  late DateTime _selectedStartDate;
  late TimeOfDay _selectedStartTime;
  late DateTime _selectedEndDate;
  late TimeOfDay _selectedEndTime;
  late EventStatus _selectedStatus;
  late EventPriority _selectedPriority;
  late List<String> _selectedStakeholderIds;
  late bool _isVirtualLocation;
  String? _selectedEventType;

  bool _isLoading = false;
  bool _hasChanges = false;
  Map<String, StakeholderModel> _stakeholderCache = {};
  final _eventService = EventService();
  final _stakeholderService = StakeholderService();

  final List<String> _eventTypes = ['Meeting', 'Conference', 'Workshop', 'Presentation', 'Review', 'Other'];

  @override
  void initState() {
    super.initState();
    _initializeFields();
    _loadStakeholders();
  }

  Future<void> _loadStakeholders() async {
    final stakeholders = await _stakeholderService.getAllStakeholders();
    if (mounted) {
      setState(() {
        _stakeholderCache = {for (var s in stakeholders) s.id: s};
      });
    }
  }

  void _initializeFields() {
    _titleController = TextEditingController(text: widget.event.title);
    _descriptionController = TextEditingController(text: widget.event.description ?? '');
    _isVirtualLocation = widget.event.location.isVirtual;
    _locationController = TextEditingController(
      text: _isVirtualLocation 
          ? widget.event.location.name 
          : (widget.event.location.address ?? widget.event.location.name)
    );
    _virtualLinkController = TextEditingController(text: widget.event.location.virtualLink ?? '');

    _selectedStartDate = widget.event.startTime;
    _selectedStartTime = TimeOfDay.fromDateTime(widget.event.startTime);
    _selectedEndDate = widget.event.endTime;
    _selectedEndTime = TimeOfDay.fromDateTime(widget.event.endTime);
    _selectedStatus = widget.event.status;
    _selectedPriority = widget.event.priority;
    _selectedStakeholderIds = List.from(widget.event.stakeholderIds);

    // Add listeners to track changes
    _titleController.addListener(_markChanged);
    _descriptionController.addListener(_markChanged);
    _locationController.addListener(_markChanged);
    _virtualLinkController.addListener(_markChanged);
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _virtualLinkController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedStartDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date != null) {
      setState(() {
        _selectedStartDate = date;
        // If end date is before start date, update it
        if (_selectedEndDate.isBefore(date)) {
          _selectedEndDate = date;
        }
        _hasChanges = true;
      });
    }
  }

  Future<void> _selectStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedStartTime,
    );
    if (time != null) {
      setState(() {
        _selectedStartTime = time;
        _hasChanges = true;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedEndDate.isAfter(_selectedStartDate)
          ? _selectedEndDate
          : _selectedStartDate,
      firstDate: _selectedStartDate,
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date != null) {
      setState(() {
        _selectedEndDate = date;
        _hasChanges = true;
      });
    }
  }

  Future<void> _selectEndTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedEndTime,
    );
    if (time != null) {
      setState(() {
        _selectedEndTime = time;
        _hasChanges = true;
      });
    }
  }

  DateTime _combineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String? _validateEventTimes() {
    final start = _combineDateTime(_selectedStartDate, _selectedStartTime);
    final end = _combineDateTime(_selectedEndDate, _selectedEndTime);

    if (end.isBefore(start)) {
      return 'End time must be after start time';
    }
    if (end.difference(start).inMinutes < 5) {
      return 'Event must be at least 5 minutes long';
    }
    if (end.difference(start).inDays > 30) {
      return 'Event cannot be longer than 30 days';
    }
    return null;
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    final timeError = _validateEventTimes();
    if (timeError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(timeError), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final startDateTime = _combineDateTime(_selectedStartDate, _selectedStartTime);
      final endDateTime = _combineDateTime(_selectedEndDate, _selectedEndTime);

      final updatedEvent = widget.event.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        startTime: startDateTime,
        endTime: endDateTime,
        location: EventLocation(
          name: _isVirtualLocation 
              ? _locationController.text.trim() 
              : 'In-Person Location',
          address: !_isVirtualLocation ? _locationController.text.trim() : null,
          isVirtual: _isVirtualLocation,
          virtualLink: _isVirtualLocation ? _virtualLinkController.text.trim() : null,
        ),
        status: _selectedStatus,
        priority: _selectedPriority,
        stakeholderIds: _selectedStakeholderIds,
        updatedAt: DateTime.now(),
      );

      await _eventService.updateEvent(updatedEvent);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event updated successfully')),
        );
        Navigator.of(context).pop(updatedEvent);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating event: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (await _onWillPop()) {
                if (mounted) Navigator.of(context).pop();
              }
            },
          ),
          title: const Text(
            'Edit Event',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          actions: [
            TextButton(
              onPressed: _isLoading ? null : _saveEvent,
              child: Text(
                'Save',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _hasChanges ? Colors.blue : Colors.grey,
                ),
              ),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Event Title
                      _buildSectionLabel('Event Title'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleController,
                        decoration: _buildInputDecoration('Enter event title'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a title';
                          }
                          if (value.trim().length < 3) {
                            return 'Title must be at least 3 characters';
                          }
                          if (value.trim().length > 100) {
                            return 'Title must be less than 100 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Event Type
                      _buildSectionLabel('Event Type'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedEventType,
                        decoration: _buildInputDecoration('Select event type'),
                        items: _eventTypes.map((type) {
                          return DropdownMenuItem(value: type, child: Text(type));
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedEventType = value;
                            _hasChanges = true;
                          });
                        },
                      ),
                      const SizedBox(height: 24),

                      // Status & Priority Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionLabel('Status'),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<EventStatus>(
                                  initialValue: _selectedStatus,
                                  decoration: _buildInputDecoration('Status'),
                                  items: EventStatus.values.map((status) {
                                    return DropdownMenuItem(
                                      value: status,
                                      child: Text(_getStatusLabel(status)),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedStatus = value!;
                                      _hasChanges = true;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionLabel('Priority'),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<EventPriority>(
                                  initialValue: _selectedPriority,
                                  decoration: _buildInputDecoration('Priority'),
                                  items: EventPriority.values.map((priority) {
                                    return DropdownMenuItem(
                                      value: priority,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: _getPriorityColor(priority),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(priority.name.toUpperCase()),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedPriority = value!;
                                      _hasChanges = true;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Description
                      _buildSectionLabel('Description'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: _buildInputDecoration('Write your event description'),
                        maxLines: 4,
                        maxLength: 500,
                        validator: (value) {
                          if (value != null && value.length > 500) {
                            return 'Description must be less than 500 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Event Timing
                      _buildSectionLabel('Event Timing'),
                      const SizedBox(height: 12),

                      // Start Date & Time Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Start Date',
                                  style: TextStyle(fontSize: 12, color: Colors.black87),
                                ),
                                const SizedBox(height: 8),
                                _buildDatePicker(_selectedStartDate, _selectStartDate),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Start Time',
                                  style: TextStyle(fontSize: 12, color: Colors.black87),
                                ),
                                const SizedBox(height: 8),
                                _buildTimePicker(_selectedStartTime, _selectStartTime),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // End Date & Time Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'End Date',
                                  style: TextStyle(fontSize: 12, color: Colors.black87),
                                ),
                                const SizedBox(height: 8),
                                _buildDatePicker(_selectedEndDate, _selectEndDate),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'End Time',
                                  style: TextStyle(fontSize: 12, color: Colors.black87),
                                ),
                                const SizedBox(height: 8),
                                _buildTimePicker(_selectedEndTime, _selectEndTime),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Stakeholders
                      _buildSectionLabel('Stakeholders'),
                      const SizedBox(height: 8),
                      _buildStakeholderPicker(),
                      const SizedBox(height: 24),

                      // Location Section
                      _buildSectionLabel('Location'),
                      const SizedBox(height: 8),

                      // Virtual/In-Person Toggle
                      Row(
                        children: [
                          Expanded(
                            child: _buildLocationTypeButton(
                              'In-Person',
                              Icons.location_on,
                              !_isVirtualLocation,
                              () => setState(() {
                                _isVirtualLocation = false;
                                _hasChanges = true;
                              }),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildLocationTypeButton(
                              'Virtual',
                              Icons.videocam,
                              _isVirtualLocation,
                              () => setState(() {
                                _isVirtualLocation = true;
                                _hasChanges = true;
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Location Name - Use autocomplete for physical, regular text for virtual
                      if (_isVirtualLocation)
                        TextFormField(
                          controller: _locationController,
                          decoration: _buildInputDecoration(
                            'Meeting name (e.g., Zoom Call)',
                            prefixIcon: Icons.videocam,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a location';
                            }
                            return null;
                          },
                        )
                      else
                        LocationAutocompleteField(
                          controller: _locationController,
                          decoration: _buildInputDecoration(
                            'Search for a location',
                            prefixIcon: Icons.location_on,
                          ),
                          onPlaceSelected: (details) {
                            _locationController.text = details.formattedAddress;
                            _hasChanges = true;
                          },
                          onChanged: (_) => _markChanged(),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a location';
                            }
                            return null;
                          },
                        ),

                      // Virtual Link (only if virtual)
                      if (_isVirtualLocation) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _virtualLinkController,
                          decoration: _buildInputDecoration(
                            'Meeting link (e.g., Zoom, Teams)',
                            prefixIcon: Icons.link,
                          ),
                          keyboardType: TextInputType.url,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a meeting link';
                            }
                            final uri = Uri.tryParse(value.trim());
                            if (uri == null || !uri.hasScheme) {
                              return 'Please enter a valid URL';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 32),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveEvent,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, {IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400]),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.grey[600]) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildDatePicker(DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(TimeOfDay time, VoidCallback onTap) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              '$hour:$minute $period',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStakeholderPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () async {
            final selectedIds = await showStakeholderPicker(
              context: context,
              selectedStakeholderIds: _selectedStakeholderIds,
            );
            if (selectedIds != null) {
              setState(() {
                _selectedStakeholderIds = selectedIds;
                _hasChanges = true;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Icon(Icons.people, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedStakeholderIds.isEmpty
                        ? 'Add stakeholders (optional)'
                        : '${_selectedStakeholderIds.length} stakeholder(s) selected',
                    style: TextStyle(
                      color: _selectedStakeholderIds.isEmpty
                          ? Colors.grey[400]
                          : Colors.black87,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
        if (_selectedStakeholderIds.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedStakeholderIds.map((id) {
              final stakeholder = _stakeholderCache[id];
              return Chip(
                label: Text(stakeholder?.name ?? 'Unknown'),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () {
                  setState(() {
                    _selectedStakeholderIds.remove(id);
                    _hasChanges = true;
                  });
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationTypeButton(
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.blue : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blue : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusLabel(EventStatus status) {
    switch (status) {
      case EventStatus.draft:
        return 'Draft';
      case EventStatus.scheduled:
        return 'Scheduled';
      case EventStatus.inProgress:
        return 'In Progress';
      case EventStatus.completed:
        return 'Completed';
      case EventStatus.cancelled:
        return 'Cancelled';
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
        return Colors.purple;
    }
  }
}
