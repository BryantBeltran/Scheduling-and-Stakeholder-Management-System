// ==============================================================================
// USER SERVICE - Firestore User Management
// ==============================================================================
// Manages user data in Firestore, syncing with Firebase Authentication
//
// Implementation Details:
// - Saves user profiles to Firestore 'users' collection
// - Updates user data on sign-in/sign-up
// - Tracks last login timestamp
// - Manages user roles and permissions
// ==============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/models.dart';

/// Service for managing user data in Firestore
class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  // Lazy Firestore instance
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// Save or update user data in Firestore
  /// Called after successful authentication
  Future<void> saveUser(UserModel user) async {
    if (!AppConfig.instance.useFirebase) {
      debugPrint('[Dev] Mock save user: ${user.email}');
      return;
    }

    try {
      final userRef = _firestore.collection('users').doc(user.id);
      
      // Check if user exists
      final docSnapshot = await userRef.get();
      
      if (docSnapshot.exists) {
        // User exists - update last login and other fields that might have changed
        await userRef.update({
          'displayName': user.displayName,
          'photoUrl': user.photoUrl,
          'lastLoginAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('Updated existing user: ${user.email}');
      } else {
        // New user - create document with all fields
        await userRef.set({
          'id': user.id,
          'email': user.email,
          'displayName': user.displayName,
          'photoUrl': user.photoUrl,
          'role': user.role.toString().split('.').last,
          'permissions': user.permissions.map((p) => p.toString().split('.').last).toList(),
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('Created new user: ${user.email}');
      }
    } catch (e) {
      debugPrint('Error saving user to Firestore: $e');
      rethrow;
    }
  }

  /// Get user data from Firestore
  Future<UserModel?> getUser(String userId) async {
    if (!AppConfig.instance.useFirebase) {
      debugPrint('[Dev] Mock get user: $userId');
      return null;
    }

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      
      if (!doc.exists) {
        return null;
      }

      final data = doc.data()!;
      return UserModel(
        id: data['id'] as String,
        email: data['email'] as String,
        displayName: data['displayName'] as String? ?? 'User',
        photoUrl: data['photoUrl'] as String?,
        role: _parseUserRole(data['role'] as String?),
        permissions: _parsePermissions(data['permissions'] as List?),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error getting user from Firestore: $e');
      return null;
    }
  }

  /// Update user profile
  Future<void> updateUser(UserModel user) async {
    if (!AppConfig.instance.useFirebase) {
      debugPrint('[Dev] Mock update user: ${user.email}');
      return;
    }

    try {
      await _firestore.collection('users').doc(user.id).update({
        'displayName': user.displayName,
        'photoUrl': user.photoUrl,
        'role': user.role.toString().split('.').last,
        'permissions': user.permissions.map((p) => p.toString().split('.').last).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Updated user profile: ${user.email}');
    } catch (e) {
      debugPrint('Error updating user: $e');
      rethrow;
    }
  }

  /// Parse user role from string
  UserRole _parseUserRole(String? roleString) {
    switch (roleString) {
      case 'admin':
        return UserRole.admin;
      case 'manager':
        return UserRole.manager;
      case 'member':
        return UserRole.member;
      case 'viewer':
        return UserRole.viewer;
      default:
        return UserRole.member;
    }
  }

  /// Parse permissions from Firestore list of strings
  List<Permission> _parsePermissions(List? permissionStrings) {
    if (permissionStrings == null) return [];
    
    return permissionStrings
        .map((perm) => _parsePermission(perm as String))
        .whereType<Permission>()
        .toList();
  }

  /// Parse single permission from string
  Permission? _parsePermission(String permString) {
    switch (permString) {
      // Event permissions
      case 'createEvent':
        return Permission.createEvent;
      case 'editEvent':
        return Permission.editEvent;
      case 'deleteEvent':
        return Permission.deleteEvent;
      case 'viewEvent':
        return Permission.viewEvent;
      // Stakeholder permissions
      case 'createStakeholder':
        return Permission.createStakeholder;
      case 'editStakeholder':
        return Permission.editStakeholder;
      case 'deleteStakeholder':
        return Permission.deleteStakeholder;
      case 'viewStakeholder':
        return Permission.viewStakeholder;
      case 'assignStakeholder':
        return Permission.assignStakeholder;
      // Admin permissions
      case 'manageUsers':
        return Permission.manageUsers;
      case 'viewReports':
        return Permission.viewReports;
      case 'editSettings':
        return Permission.editSettings;
      default:
        return null;
    }
  }
}
