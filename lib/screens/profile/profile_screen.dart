import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import 'profile_edit_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
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
                        color: const Color(0xFF5B7C99),
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
                                  color: Colors.white,
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
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Role badge - now shows actual role with permission-based override
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        color: _getRoleColor(user?.role, user?.permissions),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        _getRoleDisplayName(user?.role, user?.permissions),
                        style: const TextStyle(
                          color: Colors.black,
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
              Divider(height: 1, color: Colors.grey[300]),
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
              Divider(height: 1, color: Colors.grey[300]),
              _ProfileMenuItem(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
              Divider(height: 1, color: Colors.grey[300]),
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
                    Divider(height: 1, color: Colors.grey[300]),
                    _ProfileMenuItem(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'User Management',
                      onTap: () {
                        Navigator.of(context).pushNamed('/admin/users');
                      },
                    ),
                  ],
                ),
              
              Divider(height: 1, color: Colors.grey[300]),
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
                      // Pop all routes and go back to root (AuthWrapper will handle showing login)
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

  Color _getRoleColor(UserRole? role, List<Permission>? permissions) {
    // Use permissions-based color
    if (permissions != null) {
      if (permissions.contains(Permission.root)) {
        return const Color(0xFFFFD700); // Gold for root
      }
      if (permissions.contains(Permission.admin)) {
        return const Color(0xFFFFCDD2); // Light red for admin
      }
      if (permissions.contains(Permission.manageUsers)) {
        return const Color(0xFFBBDEFB); // Light blue for manager-level
      }
      if (permissions.any((p) => [
        Permission.createEvent,
        Permission.editEvent,
        Permission.createStakeholder,
        Permission.editStakeholder,
      ].contains(p))) {
        return const Color(0xFF80CBC4); // Teal for member-level
      }
    }
    return const Color(0xFFE0E0E0); // Grey for viewer
  }

  String _getRoleDisplayName(UserRole? role, List<Permission>? permissions) {
    // Use permissions-based display role
    if (permissions != null) {
      return PermissionService.getDisplayRole(permissions);
    }
    return 'User';
  }

  bool _canManageUsers(UserModel user) {
    return user.permissions.contains(Permission.admin) ||
           user.permissions.contains(Permission.root) ||
           user.permissions.contains(Permission.manageUsers);
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red : Colors.black87;
    
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
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
          ],
        ),
      ),
    );
  }
}
