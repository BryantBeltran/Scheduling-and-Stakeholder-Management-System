// Permission service for permissions-based access control
// Provides methods to check user permissions throughout the app
// All access control is based on the permissions array, not roles

import '../models/models.dart';
import 'auth_service.dart';

/// Service for managing and checking user permissions
/// 
/// Access control is fully based on permissions array:
/// - Specific permissions: createEvent, editEvent, viewStakeholder, etc.
/// - Super permissions: admin (full CRUD), root (everything)
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  final AuthService _authService = AuthService();

  /// Get the current user
  UserModel? get currentUser => _authService.currentUser;

  /// Check if current user has a specific permission
  bool hasPermission(Permission permission) {
    final user = currentUser;
    if (user == null) return false;
    return user.hasPermission(permission);
  }

  /// Check if current user has any of the specified permissions
  bool hasAnyPermission(List<Permission> permissions) {
    final user = currentUser;
    if (user == null) return false;
    return permissions.any((p) => user.hasPermission(p));
  }

  /// Check if current user has all of the specified permissions
  bool hasAllPermissions(List<Permission> permissions) {
    final user = currentUser;
    if (user == null) return false;
    return permissions.every((p) => user.hasPermission(p));
  }

  // ============================================================
  // SUPER PERMISSION CHECKS
  // ============================================================

  /// Check if user has admin permission (full CRUD access)
  bool get hasAdminPermission => hasPermission(Permission.admin);

  /// Check if user has root permission (system-level access)
  bool get hasRootPermission => hasPermission(Permission.root);

  /// Check if user is a super admin (admin or root permission)
  bool get isSuperAdmin => hasAdminPermission || hasRootPermission;

  /// Check if user has manager-level access (admin, root, or manageUsers)
  bool get hasManagerAccess => 
      isSuperAdmin || 
      hasPermission(Permission.manageUsers);

  // ============================================================
  // EVENT PERMISSIONS (CRUD)
  // ============================================================
  
  /// Create events: createEvent OR admin/root
  bool get canCreateEvent =>
      hasPermission(Permission.createEvent) ||
      isSuperAdmin;

  /// Edit events: editEvent OR admin/root
  bool get canEditEvent =>
      hasPermission(Permission.editEvent) ||
      isSuperAdmin;

  /// Delete events: deleteEvent OR admin/root
  bool get canDeleteEvent =>
      hasPermission(Permission.deleteEvent) ||
      isSuperAdmin;

  /// View events: viewEvent OR admin/root
  bool get canViewEvent =>
      hasPermission(Permission.viewEvent) ||
      isSuperAdmin;

  // ============================================================
  // STAKEHOLDER PERMISSIONS (CRUD)
  // ============================================================

  /// Create stakeholders: createStakeholder OR admin/root
  bool get canCreateStakeholder =>
      hasPermission(Permission.createStakeholder) ||
      isSuperAdmin;

  /// Edit stakeholders: editStakeholder OR admin/root
  bool get canEditStakeholder =>
      hasPermission(Permission.editStakeholder) ||
      isSuperAdmin;

  /// Delete stakeholders: deleteStakeholder OR admin/root
  bool get canDeleteStakeholder =>
      hasPermission(Permission.deleteStakeholder) ||
      isSuperAdmin;

  /// View stakeholders: viewStakeholder OR admin/root
  bool get canViewStakeholder =>
      hasPermission(Permission.viewStakeholder) ||
      isSuperAdmin;

  /// Assign stakeholders: assignStakeholder OR admin/root
  bool get canAssignStakeholder =>
      hasPermission(Permission.assignStakeholder) ||
      isSuperAdmin;
  
  /// Invite stakeholders: inviteStakeholder OR admin/root
  bool get canInviteStakeholder =>
      hasPermission(Permission.inviteStakeholder) ||
      isSuperAdmin;

  // ============================================================
  // ADMIN PERMISSIONS
  // ============================================================
  
  /// Manage users: manageUsers OR admin/root
  bool get canManageUsers => 
      hasPermission(Permission.manageUsers) ||
      isSuperAdmin;

  /// View reports: viewReports OR admin/root
  bool get canViewReports => 
      hasPermission(Permission.viewReports) ||
      isSuperAdmin;

  /// Edit settings: editSettings OR root only
  bool get canEditSettings => 
      hasPermission(Permission.editSettings) ||
      hasRootPermission;

  // ============================================================
  // SPECIFIC RESOURCE CHECKS
  // ============================================================

  /// Check if user can edit a specific event
  /// User can edit if they have editEvent permission OR are the owner
  bool canEditSpecificEvent(EventModel event) {
    final user = currentUser;
    if (user == null) return false;
    
    // Super admins can edit any event
    if (isSuperAdmin) return true;
    
    // Users with editEvent permission can edit any event
    if (hasPermission(Permission.editEvent)) return true;
    
    // Event owners can edit their own events if they have createEvent permission
    if (event.ownerId == user.id && hasPermission(Permission.createEvent)) {
      return true;
    }
    
    return false;
  }

  /// Check if user can delete a specific event
  bool canDeleteSpecificEvent(EventModel event) {
    final user = currentUser;
    if (user == null) return false;
    
    // Only users with deleteEvent permission or super admins can delete
    return canDeleteEvent;
  }

  // ============================================================
  // DISPLAY HELPERS
  // ============================================================

  /// Get display name based on user's highest permission level
  static String getDisplayRole(List<Permission> permissions) {
    if (permissions.contains(Permission.root)) {
      return 'Root';
    } else if (permissions.contains(Permission.admin)) {
      return 'Admin';
    } else if (permissions.contains(Permission.manageUsers)) {
      return 'Manager';
    } else if (permissions.any((p) => [
      Permission.createEvent,
      Permission.editEvent,
      Permission.deleteEvent,
      Permission.createStakeholder,
      Permission.editStakeholder,
      Permission.deleteStakeholder,
    ].contains(p))) {
      return 'Member';
    } else if (permissions.any((p) => [
      Permission.viewEvent,
      Permission.viewStakeholder,
    ].contains(p))) {
      return 'Viewer';
    }
    return 'User';
  }

  /// Get a human-readable role name (legacy support)
  static String getRoleName(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.manager:
        return 'Manager';
      case UserRole.member:
        return 'Member';
      case UserRole.viewer:
        return 'Viewer';
    }
  }

  /// Get a description for a role
  static String getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Full access to all features and settings';
      case UserRole.manager:
        return 'Can manage events, stakeholders, and view reports';
      case UserRole.member:
        return 'Can create and edit events, view stakeholders';
      case UserRole.viewer:
        return 'Read-only access to events and stakeholders';
    }
  }

  /// Get a human-readable permission name
  static String getPermissionName(Permission permission) {
    switch (permission) {
      case Permission.createEvent:
        return 'Create Events';
      case Permission.editEvent:
        return 'Edit Events';
      case Permission.deleteEvent:
        return 'Delete Events';
      case Permission.viewEvent:
        return 'View Events';
      case Permission.createStakeholder:
        return 'Create Stakeholders';
      case Permission.editStakeholder:
        return 'Edit Stakeholders';
      case Permission.deleteStakeholder:
        return 'Delete Stakeholders';
      case Permission.viewStakeholder:
        return 'View Stakeholders';
      case Permission.assignStakeholder:
        return 'Assign Stakeholders';
      case Permission.inviteStakeholder:
        return 'Invite Stakeholders';
      case Permission.manageUsers:
        return 'Manage Users';
      case Permission.viewReports:
        return 'View Reports';
      case Permission.editSettings:
        return 'Edit Settings';
      case Permission.admin:
        return 'Administrator Access';
      case Permission.root:
        return 'Root Access';
    }
  }
}
