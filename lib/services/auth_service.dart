// ==============================================================================
// AUTHENTICATION SERVICE
// ==============================================================================
// Source: Implementation pattern based on:
// - Firebase Authentication service architecture
// - Flutter authentication best practices
// - Singleton pattern for service management
//
// Implementation Details:
// - Mock authentication for development/testing (replace with Firebase in prod)
// - StreamController for reactive auth state changes
// - Singleton pattern ensures single auth instance across app
// - Email/password validation before authentication
//
// Changes from standard patterns:
// - Mock implementation returns immediate success for development
// - Custom AuthException class instead of FirebaseAuthException
// - Stream-based auth state management for reactive UI updates
// - Auto-generates user IDs using timestamps (replace with server-side in prod)
//
// TODO for Production:
// - Replace mock auth with Firebase Authentication
// - Implement proper error handling with Firebase error codes
// - Add OAuth providers (Google, Apple, Microsoft)
// - Implement secure token storage
// ==============================================================================

import 'dart:async';
import '../models/models.dart';

/// Mock authentication service for development
/// Replace with Firebase Auth or other auth provider in production
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal() {
    // Emit initial null state so StreamBuilder doesn't stay in waiting state
    _authStateController.add(null);
  }

  UserModel? _currentUser;
  final _authStateController = StreamController<UserModel?>.broadcast();

  /// Stream of authentication state changes.
  ///
  /// Listen to this stream to react to login/logout events.
  /// Emits `UserModel` when logged in, `null` when logged out.
  ///
  /// Example:
  /// ```dart
  /// authService.authStateChanges.listen((user) {
  ///   if (user != null) {
  ///     print('Logged in as ${user.email}');
  ///   } else {
  ///     print('Logged out');
  ///   }
  /// });
  /// ```
  Stream<UserModel?> get authStateChanges => _authStateController.stream;

  /// Returns the currently authenticated user, or `null` if not logged in.
  ///
  /// Use this to access user information throughout the app.
  UserModel? get currentUser => _currentUser;

  /// Returns `true` if a user is currently authenticated.
  ///
  /// Shorthand for `currentUser != null`.
  bool get isAuthenticated => _currentUser != null;

  /// Authenticates a user with email and password.
  ///
  /// Returns a [UserModel] on successful authentication.
  /// Throws [AuthException] if authentication fails.
  ///
  /// Validates:
  /// - Email and password are not empty
  /// - Password is at least 6 characters
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final user = await authService.signInWithEmailAndPassword(
  ///     email: 'user@example.com',
  ///     password: 'password123',
  ///   );
  ///   print('Welcome ${user.displayName}!');
  /// } on AuthException catch (e) {
  ///   print('Login failed: ${e.message}');
  /// }
  /// ```
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Mock authentication - replace with actual auth logic
    if (email.isEmpty || password.isEmpty) {
      throw AuthException('Email and password are required');
    }

    if (password.length < 6) {
      throw AuthException('Password must be at least 6 characters');
    }

    // Create mock user
    _currentUser = UserModel(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      displayName: email.split('@').first,
      role: UserRole.member,
      permissions: UserModel.getDefaultPermissions(UserRole.member),
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );

    _authStateController.add(_currentUser);
    return _currentUser!;
  }

  /// Sign up with email and password
  Future<UserModel> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Validate input
    if (email.isEmpty || password.isEmpty || displayName.isEmpty) {
      throw AuthException('All fields are required');
    }

    if (!email.contains('@')) {
      throw AuthException('Please enter a valid email');
    }

    if (password.length < 6) {
      throw AuthException('Password must be at least 6 characters');
    }

    // Create new user
    _currentUser = UserModel(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      displayName: displayName,
      role: UserRole.member,
      permissions: UserModel.getDefaultPermissions(UserRole.member),
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );

    _authStateController.add(_currentUser);
    return _currentUser!;
  }

  /// Sign out current user
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = null;
    _authStateController.add(null);
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    await Future.delayed(const Duration(seconds: 1));
    if (email.isEmpty || !email.contains('@')) {
      throw AuthException('Please enter a valid email');
    }
    // In production, send password reset email
  }

  /// Update user profile
  Future<UserModel> updateProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    if (_currentUser == null) {
      throw AuthException('User not authenticated');
    }

    await Future.delayed(const Duration(milliseconds: 500));

    _currentUser = _currentUser!.copyWith(
      displayName: displayName ?? _currentUser!.displayName,
      photoUrl: photoUrl ?? _currentUser!.photoUrl,
    );

    _authStateController.add(_currentUser);
    return _currentUser!;
  }

  /// Dispose resources
  void dispose() {
    _authStateController.close();
  }
}

/// Custom auth exception
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
