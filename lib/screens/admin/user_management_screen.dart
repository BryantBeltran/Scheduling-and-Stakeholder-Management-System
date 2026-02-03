// ==============================================================================
// USER MANAGEMENT SCREEN
// ==============================================================================
// Admin screen for managing users, roles, and permissions.
// Only accessible to users with admin or manageUsers permission.
// ==============================================================================

import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import 'role_assignment_dialog.dart';

/// Screen for managing users (Admin only)
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _userService = UserService();
  final _permissionService = PermissionService();
  final _searchController = TextEditingController();
  
  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;
  String? _errorMessage;
  UserRole? _filterRole;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _checkPermissions() {
    if (!_permissionService.canManageUsers) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You do not have permission to manage users'),
            backgroundColor: Colors.red,
          ),
        );
      });
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await _userService.getAllUsers();
      setState(() {
        _users = users;
        _filteredUsers = _applyFilters(users);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading users: $e';
        _isLoading = false;
      });
    }
  }

  List<UserModel> _applyFilters(List<UserModel> users) {
    var filtered = users;

    // Apply role filter
    if (_filterRole != null) {
      filtered = filtered.where((u) => u.role == _filterRole).toList();
    }

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((u) {
        return u.displayName.toLowerCase().contains(query) ||
            u.email.toLowerCase().contains(query);
      }).toList();
    }

    // Sort by role (admins first) then by name
    filtered.sort((a, b) {
      final roleCompare = _getRoleOrder(a.role).compareTo(_getRoleOrder(b.role));
      if (roleCompare != 0) return roleCompare;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    return filtered;
  }

  int _getRoleOrder(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 0;
      case UserRole.manager:
        return 1;
      case UserRole.member:
        return 2;
      case UserRole.viewer:
        return 3;
    }
  }

  Future<void> _changeUserRole(UserModel user) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => RoleAssignmentDialog(user: user),
    );

    if (result != null && mounted) {
      try {
        final newRole = result['role'] as UserRole;
        final newPermissions = result['permissions'] as List<Permission>;
        
        final updatedUser = user.copyWith(
          role: newRole,
          permissions: newPermissions,
        );
        
        await _userService.updateUser(updatedUser);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated ${user.displayName}\'s role to ${PermissionService.getRoleName(newRole)}'),
            backgroundColor: Colors.green,
          ),
        );
        
        _loadUsers();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleUserStatus(UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.isActive ? 'Deactivate User' : 'Activate User'),
        content: Text(
          user.isActive
              ? 'Are you sure you want to deactivate ${user.displayName}? They will not be able to log in.'
              : 'Are you sure you want to activate ${user.displayName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: user.isActive ? Colors.red : Colors.green,
            ),
            child: Text(user.isActive ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final updatedUser = user.copyWith(isActive: !user.isActive);
        await _userService.updateUser(updatedUser);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              user.isActive
                  ? '${user.displayName} has been deactivated'
                  : '${user.displayName} has been activated',
            ),
            backgroundColor: Colors.green,
          ),
        );
        
        _loadUsers();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating user status: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
          'User Management',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter bar
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _filteredUsers = _applyFilters(_users);
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (_) {
                    setState(() {
                      _filteredUsers = _applyFilters(_users);
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(null, 'All'),
                      const SizedBox(width: 8),
                      ...UserRole.values.map((role) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildFilterChip(
                            role,
                            PermissionService.getRoleName(role),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Stats row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${_filteredUsers.length} user${_filteredUsers.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                _buildRoleCount(UserRole.admin, 'Admins'),
                const SizedBox(width: 16),
                _buildRoleCount(UserRole.manager, 'Managers'),
                const SizedBox(width: 16),
                _buildRoleCount(UserRole.member, 'Members'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // User list
          Expanded(
            child: _buildUserList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(UserRole? role, String label) {
    final isSelected = _filterRole == role;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterRole = selected ? role : null;
          _filteredUsers = _applyFilters(_users);
        });
      },
      selectedColor: Colors.blue.withOpacity(0.2),
      checkmarkColor: Colors.blue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildRoleCount(UserRole role, String label) {
    final count = _users.where((u) => u.role == role).length;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _getRoleColor(role),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$count $label',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildUserList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUsers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty || _filterRole != null
                  ? 'No users match your filters'
                  : 'No users found',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredUsers.length,
        itemBuilder: (context, index) {
          final user = _filteredUsers[index];
          return _UserListItem(
            user: user,
            onRoleChange: () => _changeUserRole(user),
            onStatusToggle: () => _toggleUserStatus(user),
          );
        },
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.purple;
      case UserRole.manager:
        return Colors.blue;
      case UserRole.member:
        return Colors.green;
      case UserRole.viewer:
        return Colors.grey;
    }
  }
}

class _UserListItem extends StatelessWidget {
  final UserModel user;
  final VoidCallback onRoleChange;
  final VoidCallback onStatusToggle;

  const _UserListItem({
    required this.user,
    required this.onRoleChange,
    required this.onStatusToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _getDisplayColor(user.role, user.permissions).withOpacity(0.2),
                shape: BoxShape.circle,
                image: user.photoUrl != null
                    ? DecorationImage(
                        image: NetworkImage(user.photoUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: user.photoUrl == null
                  ? Center(
                      child: Text(
                        user.displayName.isNotEmpty
                            ? user.displayName[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _getDisplayColor(user.role, user.permissions),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: user.isActive ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                      if (!user.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Inactive',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildRoleBadge(user.role, user.permissions),
                      if (user.stakeholderId != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.link, size: 12, color: Colors.teal),
                              SizedBox(width: 4),
                              Text(
                                'Stakeholder',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.teal,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey[600]),
              onSelected: (value) {
                switch (value) {
                  case 'role':
                    onRoleChange();
                    break;
                  case 'status':
                    onStatusToggle();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'role',
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings, size: 20),
                      SizedBox(width: 8),
                      Text('Change Role'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'status',
                  child: Row(
                    children: [
                      Icon(
                        user.isActive ? Icons.block : Icons.check_circle,
                        size: 20,
                        color: user.isActive ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(user.isActive ? 'Deactivate' : 'Activate'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(UserRole role, List<Permission> permissions) {
    // Check permissions first for display
    String displayName;
    Color badgeColor;
    Color textColor;
    
    if (permissions.contains(Permission.root)) {
      displayName = 'Root';
      badgeColor = const Color(0xFFFFD700); // Gold
      textColor = const Color(0xFF8B6914); // Dark gold for text
    } else if (permissions.contains(Permission.admin)) {
      displayName = 'Admin';
      badgeColor = Colors.purple;
      textColor = Colors.purple;
    } else {
      displayName = PermissionService.getRoleName(role);
      badgeColor = _getRoleColor(role);
      textColor = _getRoleColor(role);
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayName,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  /// Get display color based on permissions first, then role
  Color _getDisplayColor(UserRole role, List<Permission> permissions) {
    if (permissions.contains(Permission.root)) {
      return const Color(0xFFFFD700); // Gold for root
    } else if (permissions.contains(Permission.admin)) {
      return Colors.purple; // Purple for admin
    }
    return _getRoleColor(role);
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.purple;
      case UserRole.manager:
        return Colors.blue;
      case UserRole.member:
        return Colors.green;
      case UserRole.viewer:
        return Colors.grey;
    }
  }
}
