// ==============================================================================
// ROLE ASSIGNMENT DIALOG
// ==============================================================================
// Dialog for changing user roles and permissions.
// Shows role options with permission details.
// ==============================================================================

import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';

/// Dialog for assigning roles and permissions to users
class RoleAssignmentDialog extends StatefulWidget {
  final UserModel user;

  const RoleAssignmentDialog({super.key, required this.user});

  @override
  State<RoleAssignmentDialog> createState() => _RoleAssignmentDialogState();
}

class _RoleAssignmentDialogState extends State<RoleAssignmentDialog> {
  late UserRole _selectedRole;
  late List<Permission> _selectedPermissions;
  bool _useCustomPermissions = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.user.role;
    _selectedPermissions = List.from(widget.user.permissions);
    
    // Check if user has custom permissions (different from default for their role)
    final defaultPermissions = UserModel.getDefaultPermissions(widget.user.role);
    _useCustomPermissions = !_arePermissionsEqual(
      widget.user.permissions,
      defaultPermissions,
    );
  }

  bool _arePermissionsEqual(List<Permission> a, List<Permission> b) {
    if (a.length != b.length) return false;
    final setA = a.toSet();
    final setB = b.toSet();
    return setA.containsAll(setB) && setB.containsAll(setA);
  }

  void _onRoleChanged(UserRole? role) {
    if (role == null) return;
    setState(() {
      _selectedRole = role;
      if (!_useCustomPermissions) {
        _selectedPermissions = UserModel.getDefaultPermissions(role);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getRoleColor(_selectedRole).withOpacity(0.2),
                    child: Text(
                      widget.user.displayName.isNotEmpty
                          ? widget.user.displayName[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getRoleColor(_selectedRole),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          widget.user.email,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Role Selection
                    const Text(
                      'Select Role',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...UserRole.values.map((role) => _buildRoleOption(role)),
                    
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Custom Permissions Toggle
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Custom Permissions',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Override default role permissions',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _useCustomPermissions,
                          onChanged: (value) {
                            setState(() {
                              _useCustomPermissions = value;
                              if (!value) {
                                _selectedPermissions = UserModel.getDefaultPermissions(_selectedRole);
                              }
                            });
                          },
                        ),
                      ],
                    ),

                    // Permission list (only shown when custom permissions enabled)
                    if (_useCustomPermissions) ...[
                      const SizedBox(height: 16),
                      _buildPermissionSection(
                        'Event Permissions',
                        [
                          Permission.viewEvent,
                          Permission.createEvent,
                          Permission.editEvent,
                          Permission.deleteEvent,
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildPermissionSection(
                        'Stakeholder Permissions',
                        [
                          Permission.viewStakeholder,
                          Permission.createStakeholder,
                          Permission.editStakeholder,
                          Permission.deleteStakeholder,
                          Permission.assignStakeholder,
                          Permission.inviteStakeholder,
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildPermissionSection(
                        'Admin Permissions',
                        [
                          Permission.viewReports,
                          Permission.manageUsers,
                          Permission.editSettings,
                          Permission.admin,
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Default permissions for ${PermissionService.getRoleName(_selectedRole)}:',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: UserModel.getDefaultPermissions(_selectedRole)
                                  .map((p) => Chip(
                                        label: Text(
                                          PermissionService.getPermissionName(p),
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                        backgroundColor: Colors.grey[100],
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, {
                          'role': _selectedRole,
                          'permissions': _selectedPermissions,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleOption(UserRole role) {
    final isSelected = _selectedRole == role;
    
    return InkWell(
      onTap: () => _onRoleChanged(role),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? _getRoleColor(role) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
          color: isSelected ? _getRoleColor(role).withOpacity(0.05) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _getRoleColor(role) : Colors.grey[400]!,
                  width: 2,
                ),
                color: isSelected ? _getRoleColor(role) : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        PermissionService.getRoleName(role),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? _getRoleColor(role) : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _getRoleColor(role),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    PermissionService.getRoleDescription(role),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionSection(String title, List<Permission> permissions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: permissions.map((permission) {
            final isEnabled = _selectedPermissions.contains(permission);
            return FilterChip(
              label: Text(
                PermissionService.getPermissionName(permission),
                style: TextStyle(
                  fontSize: 12,
                  color: isEnabled ? Colors.white : Colors.grey[700],
                ),
              ),
              selected: isEnabled,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedPermissions.add(permission);
                  } else {
                    _selectedPermissions.remove(permission);
                  }
                });
              },
              selectedColor: Colors.blue,
              checkmarkColor: Colors.white,
              backgroundColor: Colors.grey[100],
            );
          }).toList(),
        ),
      ],
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
