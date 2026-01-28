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

  // Event permissions
  bool get canCreateEvent => hasPermission(Permission.createEvent);
  bool get canEditEvent => hasPermission(Permission.editEvent);
  bool get canDeleteEvent => hasPermission(Permission.deleteEvent);
  bool get canViewEvent => hasPermission(Permission.viewEvent);

  // Stakeholder permissions
  bool get canCreateStakeholder => hasPermission(Permission.createStakeholder);
  bool get canEditStakeholder => hasPermission(Permission.editStakeholder);
  bool get canDeleteStakeholder => hasPermission(Permission.deleteStakeholder);
  bool get canViewStakeholder => hasPermission(Permission.viewStakeholder);
  bool get canAssignStakeholder => hasPermission(Permission.assignStakeholder);

  // Admin permissions
  bool get canManageUsers => hasPermission(Permission.manageUsers);
  bool get canViewReports => hasPermission(Permission.viewReports);
  bool get canEditSettings => hasPermission(Permission.editSettings);

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
      case Permission.manageUsers:
        return 'Manage Users';
      case Permission.viewReports:
        return 'View Reports';
      case Permission.editSettings:
        return 'Edit Settings';
    }
  }
}
