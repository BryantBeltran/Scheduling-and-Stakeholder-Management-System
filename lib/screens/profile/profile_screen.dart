import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../theme/app_theme.dart';
import 'profile_edit_screen.dart';
import 'settings_screen.dart';
import 'notifications_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final notificationService = NotificationService();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<UserModel?>(
        stream: authService.authStateChanges,
        initialData: authService.currentUser,
        builder: (context, snapshot) {
          final user = snapshot.data;
          
          return ListView(
            children: [
              // Profile header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                child: Column(
                  children: [
                    // Larger circular avatar with photo support
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.avatarBackground,
                        image: (user?.photoUrl != null && user!.photoUrl!.isNotEmpty)
                            ? DecorationImage(
                                image: NetworkImage(user.photoUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: (user?.photoUrl == null || user!.photoUrl!.isEmpty)
                          ? Center(
                              child: Text(
                                (user?.displayName.isNotEmpty ?? false) 
                                    ? user!.displayName[0].toUpperCase() 
                                    : 'U',
                                style: const TextStyle(
                                  fontSize: 48,
                                  color: Colors.white, // always white on avatarBackground
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    // Username
                    Text(
                      user?.displayName ?? 'Username',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Role badge - now shows actual role with permission-based override
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        color: _getRoleColor(context, user?.role, user?.permissions),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        _getRoleDisplayName(user?.role, user?.permissions),
                        style: TextStyle(
                          color: AppTheme.roleOnColor(context),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 1),

              // Menu items
              _ProfileMenuItem(
                icon: Icons.person_outline,
                title: 'Edit Profile',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ProfileEditScreen(),
                    ),
                  );
                },
              ),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              _ProfileMenuItem(
                icon: Icons.settings_outlined,
                title: 'Settings',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              _ProfileMenuItem(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                trailing: StreamBuilder<int>(
                  stream: notificationService.unreadCountStream,
                  initialData: notificationService.unreadCount,
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    if (count == 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  );
                },
              ),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              _ProfileMenuItem(
                icon: Icons.shield_outlined,
                title: 'Privacy & Security',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Privacy settings coming soon!')),
                  );
                },
              ),
              
              // User Management - Only visible to admins
              if (user != null && _canManageUsers(user))
                Column(
                  children: [
                    Divider(height: 1, color: Theme.of(context).dividerColor),
                    _ProfileMenuItem(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'User Management',
                      onTap: () {
                        Navigator.of(context).pushNamed('/admin/users');
                      },
                    ),
                    Divider(height: 1, color: Theme.of(context).dividerColor),
                    _ProfileMenuItem(
                      icon: Icons.history,
                      title: 'Audit Log',
                      onTap: () {
                        Navigator.of(context).pushNamed('/admin/audit-log');
                      },
                    ),
                  ],
                ),
              
              Divider(height: 1, color: Theme.of(context).dividerColor),
              _ProfileMenuItem(
                icon: Icons.info_outline,
                title: 'About',
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Scheduling & Stakeholder Management',
                    applicationVersion: '1.0.0',
                    applicationIcon: const Icon(Icons.schedule, size: 48),
                  );
                },
              ),

              Divider(height: 1, thickness: 1),

              // Sign out button
              _ProfileMenuItem(
                icon: Icons.exit_to_app,
                title: 'Sign Out',
                isDestructive: true,
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Sign Out'),
                      content: const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && context.mounted) {
                    await authService.signOut();
                    if (context.mounted) {
                      // Navigate to login and clear all routes
                      // AuthWrapper will handle showing login in staging/prod
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/login',
                        (route) => false,
                      );
                    }
                  }
                },
              ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Color _getRoleColor(BuildContext context, UserRole? role, List<Permission>? permissions) {
    // Prefer explicit role for color
    if (permissions != null) {
      if (permissions.contains(Permission.root)) return AppTheme.roleRootColor(context);
      if (permissions.contains(Permission.admin)) return AppTheme.roleAdminColor(context);
    }
    if (role != null) {
      switch (role) {
        case UserRole.admin:
          return AppTheme.roleAdminColor(context);
        case UserRole.manager:
          return AppTheme.roleManagerColor(context);
        case UserRole.member:
          return AppTheme.roleMemberColor(context);
        case UserRole.viewer:
          return AppTheme.roleViewerColor(context);
      }
    }
    return AppTheme.roleViewerColor(context);
  }

  String _getRoleDisplayName(UserRole? role, List<Permission>? permissions) {
    if (permissions != null) {
      return PermissionService.getDisplayRole(permissions, role);
    }
    return 'User';
  }

  bool _canManageUsers(UserModel user) {
    return user.permissions.contains(Permission.admin) ||
           user.permissions.contains(Permission.root);
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;
  final Widget? trailing;

  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red : Theme.of(context).colorScheme.onSurface;
    
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: color,
                ),
              ),
            ),
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: 8),
            ],
            Icon(Icons.chevron_right, color: Theme.of(context).hintColor, size: 24),
          ],
        ),
      ),
    );
  }
}
