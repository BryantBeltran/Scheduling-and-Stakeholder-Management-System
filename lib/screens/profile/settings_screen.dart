import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../config/app_config.dart';
import '../../services/services.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Notification settings
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _eventReminders = true;
  bool _stakeholderUpdates = true;
  
  // Privacy settings
  bool _profileVisibility = true;
  bool _showOnlineStatus = true;
  
  // Appearance
  String _theme = 'System';
  String _language = 'English';

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = AuthService().currentUser;
    if (user == null || !AppConfig.instance.useFirebase) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .get();
      final settings = doc.data()?['settings'] as Map<String, dynamic>? ?? {};

      setState(() {
        _emailNotifications = settings['emailNotifications'] as bool? ?? true;
        _pushNotifications = settings['pushNotifications'] as bool? ?? true;
        _eventReminders = settings['eventReminders'] as bool? ?? true;
        _stakeholderUpdates = settings['stakeholderUpdates'] as bool? ?? true;
        _profileVisibility = settings['profileVisibility'] as bool? ?? true;
        _showOnlineStatus = settings['showOnlineStatus'] as bool? ?? true;
        _theme = settings['theme'] as String? ?? 'System';
        _language = settings['language'] as String? ?? 'English';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    final user = AuthService().currentUser;
    if (user == null || !AppConfig.instance.useFirebase) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .update({
        'settings': {
          'emailNotifications': _emailNotifications,
          'pushNotifications': _pushNotifications,
          'eventReminders': _eventReminders,
          'stakeholderUpdates': _stakeholderUpdates,
          'profileVisibility': _profileVisibility,
          'showOnlineStatus': _showOnlineStatus,
          'theme': _theme,
          'language': _language,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save settings'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateSetting(VoidCallback update) {
    setState(update);
    _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Settings',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        children: [
          // Notifications Section
          _SectionHeader(title: 'Notifications'),
          _SwitchTile(
            title: 'Email Notifications',
            subtitle: 'Receive notifications via email',
            value: _emailNotifications,
            onChanged: (value) {
              _updateSetting(() => _emailNotifications = value);
            },
          ),
          _SwitchTile(
            title: 'Push Notifications',
            subtitle: 'Receive push notifications on your device',
            value: _pushNotifications,
            onChanged: (value) {
              _updateSetting(() => _pushNotifications = value);
            },
          ),
          _SwitchTile(
            title: 'Event Reminders',
            subtitle: 'Get reminded about upcoming events',
            value: _eventReminders,
            onChanged: (value) {
              _updateSetting(() => _eventReminders = value);
            },
          ),
          _SwitchTile(
            title: 'Stakeholder Updates',
            subtitle: 'Notifications when stakeholders are added',
            value: _stakeholderUpdates,
            onChanged: (value) {
              _updateSetting(() => _stakeholderUpdates = value);
            },
          ),
          const Divider(height: 1, thickness: 1),

          // Privacy & Security Section
          _SectionHeader(title: 'Privacy & Security'),
          _SwitchTile(
            title: 'Profile Visibility',
            subtitle: 'Allow others to see your profile',
            value: _profileVisibility,
            onChanged: (value) {
              _updateSetting(() => _profileVisibility = value);
            },
          ),
          _SwitchTile(
            title: 'Show Online Status',
            subtitle: 'Let others know when you\'re online',
            value: _showOnlineStatus,
            onChanged: (value) {
              _updateSetting(() => _showOnlineStatus = value);
            },
          ),
          _SettingsTile(
            icon: Icons.lock_outline,
            title: 'Change Password',
            onTap: () {
              _showChangePasswordDialog();
            },
          ),
          _SettingsTile(
            icon: Icons.shield_outlined,
            title: 'Two-Factor Authentication',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Coming Soon',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Two-factor authentication coming soon!'),
                ),
              );
            },
          ),
          const Divider(height: 1, thickness: 1),

          // Appearance Section
          _SectionHeader(title: 'Appearance'),
          _SelectionTile(
            icon: Icons.palette_outlined,
            title: 'Theme',
            value: _theme,
            options: ['Light', 'Dark', 'System'],
            onChanged: (value) {
              _updateSetting(() => _theme = value);
            },
          ),
          _SelectionTile(
            icon: Icons.language_outlined,
            title: 'Language',
            value: _language,
            options: ['English', 'Spanish', 'French', 'German', 'Chinese'],
            onChanged: (value) {
              _updateSetting(() => _language = value);
            },
          ),
          const Divider(height: 1, thickness: 1),

          // Data & Storage Section
          _SectionHeader(title: 'Data & Storage'),
          _SettingsTile(
            icon: Icons.download_outlined,
            title: 'Download My Data',
            subtitle: 'Export your data in JSON format',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data export feature coming soon!'),
                ),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.delete_outline,
            title: 'Clear Cache',
            subtitle: 'Free up storage space',
            onTap: () {
              _showClearCacheDialog();
            },
          ),
          const Divider(height: 1, thickness: 1),

          // Account Section
          _SectionHeader(title: 'Account'),
          _SettingsTile(
            icon: Icons.person_remove_outlined,
            title: 'Deactivate Account',
            onTap: () {
              _showDeactivateAccountDialog();
            },
          ),
          _SettingsTile(
            icon: Icons.warning_outlined,
            title: 'Delete Account',
            isDestructive: true,
            onTap: () {
              _showDeleteAccountDialog();
            },
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    String? errorMessage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    errorMessage!,
                    style: TextStyle(color: Colors.red[700], fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: currentPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final currentPw = currentPasswordController.text;
                final newPw = newPasswordController.text;
                final confirmPw = confirmPasswordController.text;

                if (currentPw.isEmpty || newPw.isEmpty || confirmPw.isEmpty) {
                  setDialogState(() => errorMessage = 'All fields are required');
                  return;
                }
                if (newPw.length < 6) {
                  setDialogState(() => errorMessage = 'New password must be at least 6 characters');
                  return;
                }
                if (newPw != confirmPw) {
                  setDialogState(() => errorMessage = 'Passwords do not match');
                  return;
                }

                try {
                  if (AppConfig.instance.useFirebase) {
                    final user = firebase_auth.FirebaseAuth.instance.currentUser;
                    if (user == null || user.email == null) {
                      setDialogState(() => errorMessage = 'Not authenticated');
                      return;
                    }

                    // Re-authenticate with current password
                    final credential = firebase_auth.EmailAuthProvider.credential(
                      email: user.email!,
                      password: currentPw,
                    );
                    await user.reauthenticateWithCredential(credential);

                    // Update to new password
                    await user.updatePassword(newPw);
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Password changed successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  final msg = e.toString();
                  if (msg.contains('wrong-password') || msg.contains('invalid-credential')) {
                    setDialogState(() => errorMessage = 'Current password is incorrect');
                  } else if (msg.contains('requires-recent-login')) {
                    setDialogState(() => errorMessage = 'Please sign out and sign back in first');
                  } else {
                    setDialogState(() => errorMessage = 'Failed to change password');
                  }
                }
              },
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('This will clear all cached data. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache cleared successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showDeactivateAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Account'),
        content: const Text(
          'Your account will be temporarily deactivated. You can reactivate it by logging in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deactivation coming soon!'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This action is permanent and cannot be undone. All your data will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deletion coming soon!'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
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
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool isDestructive;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.trailing,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red : Colors.black87;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: color,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else
              Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }
}

class _SelectionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _SelectionTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select $title',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...options.map((option) => ListTile(
                    title: Text(option),
                    trailing: option == value
                        ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                        : null,
                    onTap: () {
                      onChanged(option);
                      Navigator.pop(context);
                    },
                  )),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: Colors.black87, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Colors.black87,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
