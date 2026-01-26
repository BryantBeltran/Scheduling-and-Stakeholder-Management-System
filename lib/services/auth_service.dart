// ==============================================================================
// AUTHENTICATION SERVICE
// ==============================================================================
// Source: Implementation pattern based on:
// - Firebase Authentication service architecture
// - Flutter authentication best practices
// - Singleton pattern for service management
//
// Implementation Details:
// - Firebase Authentication for production
// - Mock authentication for development/testing
// - StreamController for reactive auth state changes
// - Singleton pattern ensures single auth instance across app
// - Email/password validation before authentication
//
// Changes from standard patterns:
// - Dual mode: Firebase in production, mock in development
// - Custom AuthException class wraps Firebase errors
// - Stream-based auth state management for reactive UI updates
// ==============================================================================

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import '../models/models.dart';

/// Authentication service with Firebase integration
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal() {
    // Initialize auth state listener
    if (kReleaseMode) {
      // Production: Use Firebase Auth
      _initializeFirebaseAuth();
    } else {
      // Development: Use mock auth
      _authStateController.add(null);
    }
  }

  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;
  UserModel? _currentUser;
  final _authStateController = StreamController<UserModel?>.broadcast();
  StreamSubscription<firebase_auth.User?>? _firebaseAuthSub;

  void _initializeFirebaseAuth() {
    // Listen to Firebase auth state changes
    _firebaseAuthSub = _firebaseAuth.authStateChanges().listen((firebase_auth.User? firebaseUser) {
      if (firebaseUser != null) {
        _currentUser = _convertFirebaseUser(firebaseUser);
      } else {
        _currentUser = null;
      }
      _authStateController.add(_currentUser);
    });
  }

  /// Convert Firebase User to our UserModel
  UserModel _convertFirebaseUser(firebase_auth.User firebaseUser) {
    return UserModel(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? 'User',
      photoUrl: firebaseUser.photoURL,
      role: UserRole.member, // Default role, should be fetched from Firestore
      permissions: UserModel.getDefaultPermissions(UserRole.member),
      createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
      lastLoginAt: firebaseUser.metadata.lastSignInTime ?? DateTime.now(),
    );
  }

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
    // Validate input
    if (email.isEmpty || password.isEmpty) {
      throw AuthException('Email and password are required');
    }

    if (password.length < 6) {
      throw AuthException('Password must be at least 6 characters');
    }

    if (kReleaseMode) {
      // Production: Use Firebase Authentication
      try {
        final credential = await _firebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        if (credential.user == null) {
          throw AuthException('Authentication failed');
        }
        
        _currentUser = _convertFirebaseUser(credential.user!);
        return _currentUser!;
      } on firebase_auth.FirebaseAuthException catch (e) {
        throw AuthException(_getErrorMessage(e.code));
      } catch (e) {
        throw AuthException('An unexpected error occurred');
      }
    } else {
      // Development: Use mock authentication
      await Future.delayed(const Duration(seconds: 1));
      
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
  }

  /// Sign up with email and password
  Future<UserModel> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
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

    if (kReleaseMode) {
      // Production: Use Firebase Authentication
      try {
        final credential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        if (credential.user == null) {
          throw AuthException('Account creation failed');
        }
        
        // Update display name
        await credential.user!.updateDisplayName(displayName);
        await credential.user!.reload();
        
        final updatedUser = _firebaseAuth.currentUser;
        if (updatedUser == null) {
          throw AuthException('Failed to get user after creation');
        }
        
        _currentUser = _convertFirebaseUser(updatedUser);
        return _currentUser!;
      } on firebase_auth.FirebaseAuthException catch (e) {
        throw AuthException(_getErrorMessage(e.code));
      } catch (e) {
        throw AuthException('An unexpected error occurred');
      }
    } else {
      // Development: Use mock authentication
      await Future.delayed(const Duration(seconds: 1));

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
  }

  /// Sign out current user
  Future<void> signOut() async {
    if (kReleaseMode) {
      // Production: Sign out from Firebase
      await _firebaseAuth.signOut();
    } else {
      // Development: Mock sign out
      await Future.delayed(const Duration(milliseconds: 500));
      _currentUser = null;
      _authStateController.add(null);
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    if (email.isEmpty || !email.contains('@')) {
      throw AuthException('Please enter a valid email');
    }
    
    if (kReleaseMode) {
      // Production: Send Firebase password reset email
      try {
        await _firebaseAuth.sendPasswordResetEmail(email: email);
      } on firebase_auth.FirebaseAuthException catch (e) {
        throw AuthException(_getErrorMessage(e.code));
      } catch (e) {
        throw AuthException('Failed to send reset email');
      }
    } else {
      // Development: Mock password reset
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  /// Update user profile
  Future<UserModel> updateProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    if (_currentUser == null) {
      throw AuthException('User not authenticated');
    }

    if (kReleaseMode) {
      // Production: Update Firebase user profile
      try {
        final firebaseUser = _firebaseAuth.currentUser;
        if (firebaseUser == null) {
          throw AuthException('User not authenticated');
        }
        
        if (displayName != null) {
          await firebaseUser.updateDisplayName(displayName);
        }
        if (photoUrl != null) {
          await firebaseUser.updatePhotoURL(photoUrl);
        }
        
        await firebaseUser.reload();
        final updatedUser = _firebaseAuth.currentUser;
        if (updatedUser == null) {
          throw AuthException('Failed to get updated user');
        }
        
        _currentUser = _convertFirebaseUser(updatedUser);
        _authStateController.add(_currentUser);
        return _currentUser!;
      } on firebase_auth.FirebaseAuthException catch (e) {
        throw AuthException(_getErrorMessage(e.code));
      } catch (e) {
        throw AuthException('Failed to update profile');
      }
    } else {
      // Development: Mock update
      await Future.delayed(const Duration(milliseconds: 500));

      _currentUser = _currentUser!.copyWith(
        displayName: displayName ?? _currentUser!.displayName,
        photoUrl: photoUrl ?? _currentUser!.photoUrl,
      );

      _authStateController.add(_currentUser);
      return _currentUser!;
    }
  }

  /// Get user-friendly error messages from Firebase error codes
  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Please enter a valid email';
      case 'weak-password':
        return 'Password is too weak';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'user-disabled':
        return 'This account has been disabled';
      default:
        return 'Authentication failed. Please try again';
    }
  }

  /// Dispose resources
  void dispose() {
    _firebaseAuthSub?.cancel();
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
