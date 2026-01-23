// ==============================================================================
// AUTHENTICATION SERVICE
// ==============================================================================
// Source: Implementation pattern based on:
// - Firebase Authentication service architecture
// - Flutter authentication best practices
// - Singleton pattern for service management
//
// Implementation Details:
// - Firebase Authentication integration
// - StreamController for reactive auth state changes
// - Singleton pattern ensures single auth instance across app
// - Email/password validation before authentication
//
// Reference: https://firebase.google.com/docs/auth/flutter/start
// ==============================================================================

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

/// Firebase Authentication service
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  UserModel? _currentUser;
  StreamSubscription<User?>? _authStateSubscription;

  /// Stream of authentication state changes.
  ///
  /// Listen to this stream to react to login/logout events.
  /// Emits `UserModel` when logged in, `null` when logged out.
  Stream<UserModel?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((User? firebaseUser) async {
      if (firebaseUser == null) {
        _currentUser = null;
        return null;
      }
      
      // Fetch user data from Firestore
      final userDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
      
      if (userDoc.exists) {
        _currentUser = UserModel.fromJson({
          'id': firebaseUser.uid,
          ...userDoc.data()!,
        });
      } else {
        // Create user document if it doesn't exist
        _currentUser = UserModel(
          id: firebaseUser.uid,
          email: firebaseUser.email!,
          displayName: firebaseUser.displayName ?? firebaseUser.email!.split('@').first,
          role: UserRole.member,
          permissions: UserModel.getDefaultPermissions(UserRole.member),
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );
        
        await _firestore.collection('users').doc(firebaseUser.uid).set(_currentUser!.toJson());
      }
      
      return _currentUser;
    });
  }

  /// Returns the currently authenticated user, or `null` if not logged in.
  UserModel? get currentUser => _currentUser;

  /// Returns `true` if a user is currently authenticated.
  bool get isAuthenticated => _currentUser != null;

  /// Authenticates a user with email and password.
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        throw AuthException('Email and password are required');
      }

      if (password.length < 6) {
        throw AuthException('Password must be at least 6 characters');
      }

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update last login time
      await _firestore.collection('users').doc(userCredential.user!.uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      // Fetch user data
      final userDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
      _currentUser = UserModel.fromJson({
        'id': userCredential.user!.uid,
        ...userDoc.data()!,
      });

      return _currentUser!;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_getAuthErrorMessage(e.code));
    }
  }

  /// Sign up with email and password
  Future<UserModel> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      if (email.isEmpty || password.isEmpty || displayName.isEmpty) {
        throw AuthException('All fields are required');
      }

      if (!email.contains('@')) {
        throw AuthException('Please enter a valid email');
      }

      if (password.length < 6) {
        throw AuthException('Password must be at least 6 characters');
      }

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await userCredential.user!.updateDisplayName(displayName);

      // Create user document in Firestore
      _currentUser = UserModel(
        id: userCredential.user!.uid,
        email: email,
        displayName: displayName,
        role: UserRole.member,
        permissions: UserModel.getDefaultPermissions(UserRole.member),
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(userCredential.user!.uid).set(_currentUser!.toJson());

      return _currentUser!;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_getAuthErrorMessage(e.code));
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser = null;
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      if (email.isEmpty || !email.contains('@')) {
        throw AuthException('Please enter a valid email');
      }
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_getAuthErrorMessage(e.code));
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

    final updates = <String, dynamic>{};
    if (displayName != null) updates['displayName'] = displayName;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;

    await _firestore.collection('users').doc(_currentUser!.id).update(updates);

    if (displayName != null) {
      await _auth.currentUser!.updateDisplayName(displayName);
    }
    if (photoUrl != null) {
      await _auth.currentUser!.updatePhotoURL(photoUrl);
    }

    _currentUser = _currentUser!.copyWith(
      displayName: displayName ?? _currentUser!.displayName,
      photoUrl: photoUrl ?? _currentUser!.photoUrl,
    );

    return _currentUser!;
  }

  /// Get user-friendly error message
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'weak-password':
        return 'Password is too weak';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later';
      default:
        return 'Authentication failed. Please try again';
    }
  }

  /// Dispose resources
  void dispose() {
    _authStateSubscription?.cancel();
  }
}

/// Custom auth exception
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
