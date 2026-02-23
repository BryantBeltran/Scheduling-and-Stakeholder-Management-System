import 'package:flutter/material.dart';
import '../../services/services.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  final _pushService = PushNotificationService();
  final _authService = AuthService();

  bool _pushEnabled = true;
  bool _emailEnabled = true;
  int _defaultReminderMinutes = 30;
  bool _isLoading = true;
  bool _isSaving = false;

  static const _reminderOptions = <({int minutes, String label})>[
    (minutes: 15, label: '15 minutes before'),
    (minutes: 30, label: '30 minutes before'),
    (minutes: 60, label: '1 hour before'),
    (minutes: 1440, label: '24 hours before'),
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final userId = _authService.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final prefs = await _pushService.getNotificationPreferences(userId);
      setState(() {
        _pushEnabled = prefs['pushEnabled'] as bool? ?? true;
        _emailEnabled = prefs['emailEnabled'] as bool? ?? true;
        _defaultReminderMinutes = prefs['defaultReminderMinutes'] as int? ?? 30;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreferences() async {
    final userId = _authService.currentUser?.id;
    if (userId == null) return;

    setState(() => _isSaving = true);
    try {
      await _pushService.updateNotificationPreferences(
        userId: userId,
        pushEnabled: _pushEnabled,
        emailEnabled: _emailEnabled,
        defaultReminderMinutes: _defaultReminderMinutes,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferences saved')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save preferences: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notification Preferences',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Push notifications section
                _SectionHeader(title: 'Push Notifications'),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[200]!),
                  ),
                  child: SwitchListTile(
                    title: const Text('Push notifications'),
                    subtitle: const Text('Receive alerts on your device'),
                    value: _pushEnabled,
                    onChanged: (v) => setState(() => _pushEnabled = v),
                  ),
                ),
                const SizedBox(height: 16),

                // Email notifications section
                _SectionHeader(title: 'Email Notifications'),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[200]!),
                  ),
                  child: SwitchListTile(
                    title: const Text('Email notifications'),
                    subtitle: const Text('Receive updates by email'),
                    value: _emailEnabled,
                    onChanged: (v) => setState(() => _emailEnabled = v),
                  ),
                ),
                const SizedBox(height: 16),

                // Default reminder time section
                _SectionHeader(title: 'Event Reminders'),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                        child: Text(
                          'Default reminder time',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                      RadioGroup<int>(
                        groupValue: _defaultReminderMinutes,
                        onChanged: (v) {
                          if (v != null) setState(() => _defaultReminderMinutes = v);
                        },
                        child: Column(
                          children: _reminderOptions.map((opt) {
                            return RadioListTile<int>(
                              title: Text(opt.label),
                              value: opt.minutes,
                              dense: true,
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _savePreferences,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save Preferences',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: Colors.black54,
        ),
      ),
    );
  }
}
