import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/widgets.dart';
import 'stakeholder_picker_widget.dart';

/// Screen for creating new events
class EventCreateScreen extends StatefulWidget {
  const EventCreateScreen({super.key});

  @override
  State<EventCreateScreen> createState() => _EventCreateScreenState();
}

class _EventCreateScreenState extends State<EventCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _virtualLinkController = TextEditingController();
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  DateTime? _selectedEndDate;
  TimeOfDay? _selectedEndTime;
  EventStatus _selectedStatus = EventStatus.scheduled;
  final EventPriority _selectedPriority = EventPriority.medium;
  List<String> _selectedStakeholderIds = [];
  Map<String, StakeholderModel> _stakeholderCache = {};
  bool _isVirtualLocation = false;
  String? _selectedManagerId;
  List<UserModel> _managers = [];
  
  bool _isLoading = false;
  final _eventService = EventService();
  final _authService = AuthService();
  final _stakeholderService = StakeholderService();
  final _userService = UserService();

  @override
  void initState() {
    super.initState();
    _loadStakeholders();
    _loadManagers();
  }

  Future<void> _loadStakeholders() async {
    final stakeholders = await _stakeholderService.getAllStakeholders();
    setState(() {
      _stakeholderCache = {for (var s in stakeholders) s.id: s};
    });
  }

  Future<void> _loadManagers() async {
    final currentUser = _authService.currentUser;
    final all = await _userService.getAllUsers();
    setState(() {
      // Show managers and admins — exclude the current user (they are already the owner)
      _managers = all
          .where((u) =>
              u.id != currentUser?.id &&
              u.isActive &&
              (u.role == UserRole.manager || u.role == UserRole.admin) &&
              u.permissions.contains(Permission.editEvent))
          .toList();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _virtualLinkController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date')),
      );
      return;
    }
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time')),
      );
      return;
    }

    // Combine date and time
    final startDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    
    // Use selected end date/time or default to 1 hour after start
    DateTime endDateTime;
    if (_selectedEndDate != null && _selectedEndTime != null) {
      endDateTime = DateTime(
        _selectedEndDate!.year,
        _selectedEndDate!.month,
        _selectedEndDate!.day,
        _selectedEndTime!.hour,
        _selectedEndTime!.minute,
      );
    } else {
      endDateTime = startDateTime.add(const Duration(hours: 1));
    }

    // Validate time range using EventValidators
    final timeValidation = EventValidators.validateTimeRange(startDateTime, endDateTime);
    if (!timeValidation.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(timeValidation.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate stakeholders
    final stakeholderValidation = EventValidators.validateStakeholders(_selectedStakeholderIds);
    if (!stakeholderValidation.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(stakeholderValidation.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {

      // Get current user
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final event = EventModel(
        id: '', // Will be generated by service
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        startTime: startDateTime,
        endTime: endDateTime,
        location: EventLocation(
          name: _isVirtualLocation 
              ? _locationController.text.trim() 
              : _locationController.text.trim(),
          address: !_isVirtualLocation ? _locationController.text.trim() : null,
          isVirtual: _isVirtualLocation,
          virtualLink: _isVirtualLocation ? _virtualLinkController.text.trim() : null,
        ),
        ownerId: currentUser.id,
        ownerName: currentUser.displayName,
        managerId: _selectedManagerId,
        status: _selectedStatus,
        priority: _selectedPriority,
        stakeholderIds: _selectedStakeholderIds,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _eventService.createEvent(event);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created successfully')),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating event: $e')),
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Add Event',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
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
                    Text(
                      'Event Title',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: 'Enter event title.',
                        hintStyle: TextStyle(color: Theme.of(context).hintColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      validator: EventValidators.titleValidator,
                    ),
                    const SizedBox(height: 24),
                    // Event Type
                    Text(
                      'Event Type',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        hintText: 'Select event type.',
                        hintStyle: TextStyle(color: Theme.of(context).hintColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        suffixIcon: Icon(Icons.keyboard_arrow_down, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      items: ['Meeting', 'Conference', 'Workshop', 'Other'].map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (value) {
                        // Handle event type selection
                      },
                    ),
                    const SizedBox(height: 24),
                    // Event Description
                    Text(
                      'Event Description',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        hintText: 'Write your event description.',
                        hintStyle: TextStyle(color: Theme.of(context).hintColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      maxLines: 4,
                      validator: EventValidators.descriptionValidator,
                    ),
                    const SizedBox(height: 24),
                    // Event Timing
                    Text(
                      'Event Timing',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Start Date
                    Text(
                      'Start Date',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).colorScheme.surface,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            const SizedBox(width: 12),
                            Text(
                              _selectedDate != null
                                  ? '${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.year}'
                                  : 'MM/DD/YYYY',
                              style: TextStyle(
                                color: _selectedDate != null ? Theme.of(context).colorScheme.onSurface : Theme.of(context).hintColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Start Time
                    Text(
                      'Start Time',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _selectTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).colorScheme.surface,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            const SizedBox(width: 12),
                            Text(
                              _selectedTime != null
                                  ? '${_selectedTime!.hour > 12 ? _selectedTime!.hour - 12 : (_selectedTime!.hour == 0 ? 12 : _selectedTime!.hour)}:${_selectedTime!.minute.toString().padLeft(2, '0')} ${_selectedTime!.hour >= 12 ? 'PM' : 'AM'}'
                                  : '12:00 AM',
                              style: TextStyle(
                                color: _selectedTime != null ? Theme.of(context).colorScheme.onSurface : Theme.of(context).hintColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // End Date
                    Text(
                      'End Date',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedEndDate ?? _selectedDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() {
                            _selectedEndDate = date;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).colorScheme.surface,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            const SizedBox(width: 12),
                            Text(
                              _selectedEndDate != null
                                  ? '${_selectedEndDate!.month.toString().padLeft(2, '0')}/${_selectedEndDate!.day.toString().padLeft(2, '0')}/${_selectedEndDate!.year}'
                                  : 'MM/DD/YYYY',
                              style: TextStyle(
                                color: _selectedEndDate != null ? Theme.of(context).colorScheme.onSurface : Theme.of(context).hintColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // End Time
                    Text(
                      'End Time',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _selectedEndTime ?? _selectedTime ?? TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() {
                            _selectedEndTime = time;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).colorScheme.surface,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            const SizedBox(width: 12),
                            Text(
                              _selectedEndTime != null
                                  ? '${_selectedEndTime!.hour > 12 ? _selectedEndTime!.hour - 12 : (_selectedEndTime!.hour == 0 ? 12 : _selectedEndTime!.hour)}:${_selectedEndTime!.minute.toString().padLeft(2, '0')} ${_selectedEndTime!.hour >= 12 ? 'PM' : 'AM'}'
                                  : '12:00 AM',
                              style: TextStyle(
                                color: _selectedEndTime != null ? Theme.of(context).colorScheme.onSurface : Theme.of(context).hintColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Assigned Manager (optional)
                    Text(
                      'Assign to Manager',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Optionally delegate management rights to a manager',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      initialValue: _selectedManagerId,
                      decoration: InputDecoration(
                        hintText: 'None (only you can edit)',
                        hintStyle: TextStyle(color: Theme.of(context).hintColor),
                        prefixIcon: Icon(Icons.manage_accounts,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('None'),
                        ),
                        ..._managers.map((u) => DropdownMenuItem<String?>(
                              value: u.id,
                              child: Text(u.displayName),
                            )),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedManagerId = value),
                    ),
                    const SizedBox(height: 24),
                    // Stakeholders
                    Text(
                      'Stakeholders',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final selectedIds = await showStakeholderPicker(
                          context: context,
                          selectedStakeholderIds: _selectedStakeholderIds,
                        );
                        if (selectedIds != null) {
                          setState(() {
                            _selectedStakeholderIds = selectedIds;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).colorScheme.surface,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.people, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedStakeholderIds.isEmpty
                                    ? 'Add stakeholders (optional)'
                                    : '${_selectedStakeholderIds.length} stakeholder(s) selected',
                                style: TextStyle(
                                  color: _selectedStakeholderIds.isEmpty
                                      ? Theme.of(context).hintColor
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios, size: 16, color: Theme.of(context).hintColor),
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
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Location Section
                    Text(
                      'Location',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Virtual/In-Person Toggle
                    Row(
                      children: [
                        Expanded(
                          child: _buildLocationTypeButton(
                            'In-Person',
                            Icons.location_on,
                            !_isVirtualLocation,
                            () => setState(() => _isVirtualLocation = false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildLocationTypeButton(
                            'Virtual',
                            Icons.videocam,
                            _isVirtualLocation,
                            () => setState(() => _isVirtualLocation = true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Location Name/Address - Use autocomplete for physical, regular text for virtual
                    if (_isVirtualLocation)
                      TextFormField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          hintText: 'Meeting name (e.g., Zoom Call)',
                          hintStyle: TextStyle(color: Theme.of(context).hintColor),
                          prefixIcon: Icon(Icons.videocam, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Theme.of(context).dividerColor),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a meeting name';
                          }
                          return null;
                        },
                      )
                    else
                      LocationAutocompleteField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          hintText: 'Search for a location',
                          hintStyle: TextStyle(color: Theme.of(context).hintColor),
                          prefixIcon: Icon(Icons.location_on, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Theme.of(context).dividerColor),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPlaceSelected: (details) {
                          _locationController.text = details.formattedAddress;
                        },
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
                        decoration: InputDecoration(
                          hintText: 'Meeting link (e.g., Zoom, Teams)',
                          hintStyle: TextStyle(color: Theme.of(context).hintColor),
                          prefixIcon: Icon(Icons.link, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Theme.of(context).dividerColor),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    
                    const SizedBox(height: 24),
                    // Publish Status
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _selectedStatus == EventStatus.scheduled
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: _selectedStatus == EventStatus.scheduled
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.08)
                            : Theme.of(context).colorScheme.surface,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _selectedStatus == EventStatus.scheduled
                                ? Icons.check_circle
                                : Icons.edit_note,
                            color: _selectedStatus == EventStatus.scheduled
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedStatus == EventStatus.scheduled
                                      ? 'Publish as Scheduled'
                                      : 'Save as Draft',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: _selectedStatus ==
                                            EventStatus.scheduled
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedStatus == EventStatus.scheduled
                                      ? 'Reminders will be sent to stakeholders'
                                      : 'Only visible to you until published',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _selectedStatus == EventStatus.scheduled,
                            onChanged: (val) => setState(() {
                              _selectedStatus = val
                                  ? EventStatus.scheduled
                                  : EventStatus.draft;
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Done Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createEvent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.onSurface,
                          foregroundColor: Theme.of(context).colorScheme.surface,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
            color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
              : Theme.of(context).colorScheme.surface,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
