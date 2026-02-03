// ==============================================================================
// PROTECTED ROUTE WIDGET
// ==============================================================================
// Widget wrapper that checks user permissions before rendering content.
// Redirects unauthorized users or shows access denied message.
// ==============================================================================

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';

/// A widget that protects its child based on user authentication and permissions
class ProtectedRoute extends StatelessWidget {
  /// The widget to display if the user has access
  final Widget child;

  /// Required permission to view this route
  final Permission? requiredPermission;

  /// List of required permissions (user must have ALL of them)
  final List<Permission>? requiredPermissions;

  /// List of permissions (user must have ANY one of them)
  final List<Permission>? anyOfPermissions;

  /// Required minimum role level
  final UserRole? minimumRole;

  /// Custom access check function
  final bool Function(UserModel user)? customAccessCheck;

  /// Widget to show when access is denied (defaults to AccessDeniedView)
  final Widget? accessDeniedWidget;

  /// Widget to show while checking authentication (defaults to loading indicator)
  final Widget? loadingWidget;

  /// Route to redirect to when not authenticated
  final String? redirectRoute;

  /// Whether to show access denied or redirect
  final bool showAccessDenied;

  /// Callback when access is denied
  final VoidCallback? onAccessDenied;

  const ProtectedRoute({
    super.key,
    required this.child,
    this.requiredPermission,
    this.requiredPermissions,
    this.anyOfPermissions,
    this.minimumRole,
    this.customAccessCheck,
    this.accessDeniedWidget,
    this.loadingWidget,
    this.redirectRoute,
    this.showAccessDenied = true,
    this.onAccessDenied,
  });

  /// Creates a protected route requiring admin access
  factory ProtectedRoute.admin({
    Key? key,
    required Widget child,
    Widget? accessDeniedWidget,
    String? redirectRoute,
  }) {
    return ProtectedRoute(
      key: key,
      requiredPermission: Permission.admin,
      accessDeniedWidget: accessDeniedWidget,
      redirectRoute: redirectRoute,
      child: child,
    );
  }

  /// Creates a protected route requiring user management access
  factory ProtectedRoute.userManagement({
    Key? key,
    required Widget child,
    Widget? accessDeniedWidget,
  }) {
    return ProtectedRoute(
      key: key,
      requiredPermission: Permission.manageUsers,
      accessDeniedWidget: accessDeniedWidget,
      child: child,
    );
  }

  /// Creates a protected route requiring manager or higher role
  factory ProtectedRoute.managerOrHigher({
    Key? key,
    required Widget child,
    Widget? accessDeniedWidget,
  }) {
    return ProtectedRoute(
      key: key,
      minimumRole: UserRole.manager,
      accessDeniedWidget: accessDeniedWidget,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    
    return StreamBuilder<UserModel?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Still loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingWidget ?? const _LoadingView();
        }

        // Not authenticated
        final user = snapshot.data;
        if (user == null) {
          if (redirectRoute != null) {
            // Schedule redirect after build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacementNamed(redirectRoute!);
            });
            return loadingWidget ?? const _LoadingView();
          }
          return accessDeniedWidget ?? const AccessDeniedView(
            title: 'Authentication Required',
            message: 'Please log in to access this page.',
            showLoginButton: true,
          );
        }

        // Check access
        final hasAccess = _checkAccess(user);
        
        if (!hasAccess) {
          onAccessDenied?.call();
          
          if (!showAccessDenied && redirectRoute != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacementNamed(redirectRoute!);
            });
            return loadingWidget ?? const _LoadingView();
          }
          
          return accessDeniedWidget ?? AccessDeniedView(
            title: 'Access Denied',
            message: _getAccessDeniedMessage(),
            userRole: user.role,
          );
        }

        return child;
      },
    );
  }

  bool _checkAccess(UserModel user) {
    // Check single required permission
    if (requiredPermission != null) {
      if (!user.hasPermission(requiredPermission!)) {
        return false;
      }
    }

    // Check all required permissions
    if (requiredPermissions != null && requiredPermissions!.isNotEmpty) {
      if (!requiredPermissions!.every((p) => user.hasPermission(p))) {
        return false;
      }
    }

    // Check any of permissions
    if (anyOfPermissions != null && anyOfPermissions!.isNotEmpty) {
      if (!anyOfPermissions!.any((p) => user.hasPermission(p))) {
        return false;
      }
    }

    // Check minimum role
    if (minimumRole != null) {
      if (!_hasMinimumRole(user.role, minimumRole!)) {
        return false;
      }
    }

    // Check custom access function
    if (customAccessCheck != null) {
      if (!customAccessCheck!(user)) {
        return false;
      }
    }

    return true;
  }

  bool _hasMinimumRole(UserRole userRole, UserRole requiredRole) {
    const roleHierarchy = {
      UserRole.admin: 4,
      UserRole.manager: 3,
      UserRole.member: 2,
      UserRole.viewer: 1,
    };

    final userLevel = roleHierarchy[userRole] ?? 0;
    final requiredLevel = roleHierarchy[requiredRole] ?? 0;

    return userLevel >= requiredLevel;
  }

  String _getAccessDeniedMessage() {
    if (requiredPermission != null) {
      return 'You need the "${PermissionService.getPermissionName(requiredPermission!)}" permission to access this page.';
    }
    if (minimumRole != null) {
      return 'You need to be a ${PermissionService.getRoleName(minimumRole!)} or higher to access this page.';
    }
    return 'You do not have permission to access this page.';
  }
}

/// Simple loading view shown while checking authentication
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// Access denied view with customizable message
class AccessDeniedView extends StatelessWidget {
  final String title;
  final String message;
  final UserRole? userRole;
  final bool showLoginButton;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const AccessDeniedView({
    super.key,
    this.title = 'Access Denied',
    this.message = 'You do not have permission to access this page.',
    this.userRole,
    this.showLoginButton = false,
    this.showBackButton = true,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  showLoginButton ? Icons.lock_outline : Icons.block,
                  size: 64,
                  color: Colors.red[400],
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Message
              Text(
                message,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),

              // Current role indicator
              if (userRole != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Your role: ${PermissionService.getRoleName(userRole!)}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Action buttons
              if (showLoginButton)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/login');
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Go to Login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),

              if (showBackButton) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onBackPressed ?? () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        Navigator.of(context).pushReplacementNamed('/home');
                      }
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Help text
              TextButton.icon(
                onPressed: () {
                  _showHelpDialog(context);
                },
                icon: const Icon(Icons.help_outline, size: 18),
                label: const Text('Need help?'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Need Access?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'If you believe you should have access to this page, please contact your administrator.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Role Hierarchy:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildRoleInfo(UserRole.admin, 'Full system access'),
            _buildRoleInfo(UserRole.manager, 'Manage events & stakeholders'),
            _buildRoleInfo(UserRole.member, 'Create & edit own content'),
            _buildRoleInfo(UserRole.viewer, 'View only access'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleInfo(UserRole role, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _getRoleColor(role),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${PermissionService.getRoleName(role)}: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
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

/// Permission gate that shows/hides content based on permissions
/// Use this for inline permission checks within a page
class PermissionGate extends StatelessWidget {
  final Widget child;
  final Permission? permission;
  final List<Permission>? permissions;
  final List<Permission>? anyOf;
  final UserRole? minimumRole;
  final Widget? fallback;
  final bool showFallback;

  const PermissionGate({
    super.key,
    required this.child,
    this.permission,
    this.permissions,
    this.anyOf,
    this.minimumRole,
    this.fallback,
    this.showFallback = false,
  });

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    
    return StreamBuilder<UserModel?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        final user = snapshot.data;
        
        if (user == null) {
          return showFallback ? (fallback ?? const SizedBox.shrink()) : const SizedBox.shrink();
        }

        final hasAccess = _checkAccess(user);
        
        if (!hasAccess) {
          return showFallback ? (fallback ?? const SizedBox.shrink()) : const SizedBox.shrink();
        }

        return child;
      },
    );
  }

  bool _checkAccess(UserModel user) {
    if (permission != null) {
      if (!user.hasPermission(permission!)) {
        return false;
      }
    }

    if (permissions != null && permissions!.isNotEmpty) {
      if (!permissions!.every((p) => user.hasPermission(p))) {
        return false;
      }
    }

    if (anyOf != null && anyOf!.isNotEmpty) {
      if (!anyOf!.any((p) => user.hasPermission(p))) {
        return false;
      }
    }

    if (minimumRole != null) {
      const roleHierarchy = {
        UserRole.admin: 4,
        UserRole.manager: 3,
        UserRole.member: 2,
        UserRole.viewer: 1,
      };
      final userLevel = roleHierarchy[user.role] ?? 0;
      final requiredLevel = roleHierarchy[minimumRole!] ?? 0;
      if (userLevel < requiredLevel) {
        return false;
      }
    }

    return true;
  }
}
