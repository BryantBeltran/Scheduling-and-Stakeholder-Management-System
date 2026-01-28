// ==============================================================================
// USER MODEL
// ==============================================================================
// Source: Custom implementation based on:
// - Flutter/Dart best practices for data modeling
// - Role-Based Access Control (RBAC) patterns
// - Firebase Authentication user schema conventions
//
// Implementation Details:
// - Enum-based roles and permissions for type safety
// - Immutable model with copyWith pattern
// - JSON serialization for API/database communication
// - Permission checking methods for authorization
//
// Changes from standard patterns:
// - Added explicit Permission enum instead of string-based permissions
// - Implemented getDefaultPermissions() factory for role initialization
// - Added hasPermission() helper method for easy authorization checks
// ==============================================================================

/// User roles in the system
enum UserRole {
  admin,
  manager,
  member,
  viewer,
}

/// User permissions
enum Permission {
  // Event permissions
  createEvent,
  editEvent,
  deleteEvent,
  viewEvent,
  
  // Stakeholder permissions
  createStakeholder,
  editStakeholder,
  deleteStakeholder,
  viewStakeholder,
  assignStakeholder,
  
  // Admin permissions
  manageUsers,
  viewReports,
  editSettings,
}

/// User model representing authenticated users in the system.
///
/// This model contains all user-related information including authentication
/// details, role-based permissions, and account status.
///
/// Example:
/// ```dart
/// final user = UserModel(
///   id: 'user_123',
///   email: 'john@example.com',
///   displayName: 'John Doe',
///   role: UserRole.manager,
///   permissions: UserModel.getDefaultPermissions(UserRole.manager),
///   createdAt: DateTime.now(),
/// );
/// ```
class UserModel {
  /// Unique identifier for the user
  final String id;
  
  /// User's email address (used for authentication)
  final String email;
  
  /// Display name shown in the UI
  final String displayName;
  
  /// Optional URL to user's profile photo
  final String? photoUrl;
  
  /// User's role in the system (determines base permissions)
  final UserRole role;
  
  /// List of permissions granted to this user
  final List<Permission> permissions;
  
  /// Timestamp when the user account was created
  final DateTime createdAt;
  
  /// Timestamp of the user's last login (null if never logged in)
  final DateTime? lastLoginAt;
  
  /// Whether the user account is active (inactive users cannot log in)
  final bool isActive;

  const UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.role,
    required this.permissions,
    required this.createdAt,
    this.lastLoginAt,
    this.isActive = true,
  });

  /// Returns the default set of permissions for a given role.
  ///
  /// This factory method maps roles to their standard permission sets:
  /// - Admin: All permissions
  /// - Manager: Event and stakeholder management + reports
  /// - Member: Basic event and stakeholder operations
  /// - Viewer: No permissions (read-only access)
  ///
  /// Example:
  /// ```dart
  /// final managerPerms = UserModel.getDefaultPermissions(UserRole.manager);
  /// print(managerPerms); // [createEvent, editEvent, deleteEvent, ...]
  /// ```
  static List<Permission> getDefaultPermissions(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Permission.values.toList();
      case UserRole.manager:
        return [
          Permission.createEvent,
          Permission.editEvent,
          Permission.deleteEvent,
          Permission.viewEvent,
          Permission.createStakeholder,
          Permission.editStakeholder,
          Permission.deleteStakeholder,
          Permission.viewStakeholder,
          Permission.assignStakeholder,
          Permission.viewReports,
        ];
      case UserRole.member:
        return [
          Permission.createEvent,
          Permission.editEvent,
          Permission.viewEvent,
          Permission.viewStakeholder,
          Permission.assignStakeholder,
        ];
      case UserRole.viewer:
        return [
          Permission.viewEvent,
          Permission.viewStakeholder,
        ];
    }
  }

  /// Checks if this user has a specific permission.
  ///
  /// Returns `true` if the permission is in the user's permission list,
  /// `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// if (user.hasPermission(Permission.deleteEvent)) {
  ///   // Show delete button
  /// }
  /// ```
  bool hasPermission(Permission permission) {
    return permissions.contains(permission);
  }

  /// Creates a copy of this user with the specified fields replaced.
  ///
  /// All parameters are optional. Fields not provided will retain their
  /// original values from this instance.
  ///
  /// Example:
  /// ```dart
  /// final updatedUser = user.copyWith(
  ///   displayName: 'New Name',
  ///   photoUrl: 'https://example.com/photo.jpg',
  /// );
  /// ```
  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    UserRole? role,
    List<Permission>? permissions,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isActive,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Converts this user model to a JSON map.
  ///
  /// Useful for serialization to database or API transmission.
  /// Enums are converted to their string names.
  ///
  /// Example:
  /// ```dart
  /// final json = user.toJson();
  /// // {"id": "user_123", "email": "john@example.com", ...}
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'role': role.name,
      'permissions': permissions.map((p) => p.name).toList(),
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'isActive': isActive,
    };
  }

  /// Create from JSON map
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String?,
      role: UserRole.values.firstWhere((r) => r.name == json['role']),
      permissions: (json['permissions'] as List<dynamic>)
          .map((p) => Permission.values.firstWhere((perm) => perm.name == p))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, displayName: $displayName, role: $role)';
  }
}
