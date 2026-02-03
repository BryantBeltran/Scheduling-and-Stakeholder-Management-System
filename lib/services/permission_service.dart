// Permission service for role-based access control
// Provides methods to check user permissions throughout the app

import '../models/models.dart';
import 'auth_service.dart';

/// Service for managing and checking user permissions
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

  /// Check if user has a specific role
  bool hasRole(UserRole role) {
    final user = currentUser;
    if (user == null) return false;
    return user.role == role;
  }

  /// Check if user has at least the specified role level
  /// Role hierarchy: admin > manager > member > viewer
  bool hasMinimumRole(UserRole minimumRole) {
    final user = currentUser;
    if (user == null) return false;
    
    const roleHierarchy = {
      UserRole.admin: 4,
      UserRole.manager: 3,
      UserRole.member: 2,
      UserRole.viewer: 1,
    };
    
    final userLevel = roleHierarchy[user.role] ?? 0;
    final requiredLevel = roleHierarchy[minimumRole] ?? 0;
    
    return userLevel >= requiredLevel;
  }

  /// Check if current user is an admin
  bool get isAdmin => hasRole(UserRole.admin);

  /// Check if current user is a manager or above
  bool get isManagerOrAbove => hasMinimumRole(UserRole.manager);

  /// Check if current user is a member or above
  bool get isMemberOrAbove => hasMinimumRole(UserRole.member);

  // ============================================================
  // EVENT PERMISSIONS
  // Role-based: Manager+ has full access, Member/Viewer view only
  // Permission override: Specific permissions grant access
  // ============================================================
  
  /// Create events: Manager+ OR explicit createEvent permission
  bool get canCreateEvent =>
      isManagerOrAbove ||
      hasPermission(Permission.createEvent) ||
      hasPermission(Permission.admin) ||
      hasPermission(Permission.root);

  /// Edit events: Manager+ OR explicit editEvent permission
  bool get canEditEvent =>
      isManagerOrAbove ||
      hasPermission(Permission.editEvent) ||
      hasPermission(Permission.admin) ||
      hasPermission(Permission.root);

  /// Delete events: Manager+ OR explicit deleteEvent permission
  bool get canDeleteEvent =>
      isManagerOrAbove ||
      hasPermission(Permission.deleteEvent) ||
      hasPermission(Permission.admin) ||
      hasPermission(Permission.root);

  /// View events: All roles (Member+)
  bool get canViewEvent =>
      isMemberOrAbove ||
      hasPermission(Permission.viewEvent) ||
      hasPermission(Permission.admin) ||
      hasPermission(Permission.root);

  // ============================================================
  // STAKEHOLDER PERMISSIONS
  // Role-based: Manager+ has full access, Member/Viewer view only
  // Permission override: Specific permissions grant access
  // ============================================================

  /// Create stakeholders: Manager+ OR explicit permission
  bool get canCreateStakeholder =>
      isManagerOrAbove ||
      hasPermission(Permission.createStakeholder) ||
      hasPermission(Permission.admin) ||
      hasPermission(Permission.root);

  /// Edit stakeholders: Manager+ OR explicit permission
  bool get canEditStakeholder =>
      isManagerOrAbove ||
      hasPermission(Permission.editStakeholder) ||
      hasPermission(Permission.admin) ||
      hasPermission(Permission.root);

  /// Delete stakeholders: Manager+ only (no Member override)
  bool get canDeleteStakeholder =>
      isManagerOrAbove ||
      hasPermission(Permission.deleteStakeholder) ||
      hasPermission(Permission.admin) ||
      hasPermission(Permission.root);

  /// View stakeholders: All roles (Member+)
  bool get canViewStakeholder =>
      isMemberOrAbove ||
      hasPermission(Permission.viewStakeholder) ||
      hasPermission(Permission.admin) ||
      hasPermission(Permission.root);

  /// Assign stakeholders: Manager+ OR explicit permission
  bool get canAssignStakeholder =>
      isManagerOrAbove ||
      hasPermission(Permission.assignStakeholder) ||
      hasPermission(Permission.admin) ||
      hasPermission(Permission.root);
  
  /// Invite stakeholders: Manager+ OR explicit permission
  bool get canInviteStakeholder =>
      isManagerOrAbove ||
      hasPermission(Permission.inviteStakeholder) ||
      hasPermission(Permission.admin) ||
      hasPermission(Permission.root);

  // ============================================================
  // ADMIN PERMISSIONS
  // ============================================================
  
  bool get canManageUsers => 
      hasPermission(Permission.manageUsers) ||
      hasPermission(Permission.admin) ||
      hasPermission(Permission.root);

  bool get canViewReports => 
      isManagerOrAbove ||
      hasPermission(Permission.viewReports) ||
      hasPermission(Permission.admin) ||
      hasPermission(Permission.root);

  bool get canEditSettings => 
      hasPermission(Permission.editSettings) ||
      hasPermission(Permission.admin) ||
      hasPermission(Permission.root);

  /// Check if user has admin permission
  bool get hasAdminPermission => hasPermission(Permission.admin);

  /// Check if user has root permission
  bool get hasRootPermission => hasPermission(Permission.root);

  /// Check if user is a super admin (admin or root)
  bool get isSuperAdmin => hasAdminPermission || hasRootPermission;

  /// Check if user can edit a specific event
  /// User can edit if they have editEvent permission and either:
  /// - They are the event owner
  /// - They are an admin or manager
  bool canEditSpecificEvent(EventModel event) {
    final user = currentUser;
    if (user == null) return false;
    
    if (!canEditEvent) return false;
    
    // Admins and managers can edit any event
    if (isManagerOrAbove) return true;
    
    // Members can only edit their own events
    return event.ownerId == user.id;
  }

  /// Check if user can delete a specific event
  bool canDeleteSpecificEvent(EventModel event) {
    final user = currentUser;
    if (user == null) return false;
    
    if (!canDeleteEvent) return false;
    
    // Only admins and managers can delete events
    return isManagerOrAbove;
  }

  /// Get a human-readable role name
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
