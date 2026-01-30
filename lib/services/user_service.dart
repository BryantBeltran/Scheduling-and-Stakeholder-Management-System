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
      
      // Check if user exists and has data
      final docSnapshot = await userRef.get();
      final hasData = docSnapshot.exists && docSnapshot.data() != null && docSnapshot.data()!.isNotEmpty;
      
      if (hasData) {
        // User exists with data - update last login and other fields that might have changed
        await userRef.update({
          'displayName': user.displayName,
          'photoUrl': user.photoUrl,
          'lastLoginAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('Updated existing user: ${user.email}');
      } else {
        // New user or empty document - create/overwrite with all fields
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
          'isActive': true,
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
        stakeholderId: data['stakeholderId'] as String?,
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
        'stakeholderId': user.stakeholderId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Updated user profile: ${user.email}');
    } catch (e) {
      debugPrint('Error updating user: $e');
      rethrow;
    }
  }

  /// Check if a stakeholder exists with the given email and link them to the user
  Future<String?> linkStakeholderByEmail(String userId, String email) async {
    if (!AppConfig.instance.useFirebase) {
      debugPrint('[Dev] Mock link stakeholder by email: $email');
      return null;
    }

    try {
      // Find stakeholder with matching email
      final querySnapshot = await _firestore
          .collection('stakeholders')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        debugPrint('No stakeholder found with email: $email');
        return null;
      }

      final stakeholderDoc = querySnapshot.docs.first;
      final stakeholderId = stakeholderDoc.id;

      // Update both documents in a batch
      final batch = _firestore.batch();
      
      // Update user with stakeholderId
      batch.update(_firestore.collection('users').doc(userId), {
        'stakeholderId': stakeholderId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update stakeholder with linkedUserId and invite status
      batch.update(_firestore.collection('stakeholders').doc(stakeholderId), {
        'linkedUserId': userId,
        'inviteStatus': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      debugPrint('Linked user $userId to stakeholder $stakeholderId');
      return stakeholderId;
    } catch (e) {
      debugPrint('Error linking stakeholder: $e');
      return null;
    }
  }

  /// Get stakeholder ID for a user by checking their email
  Future<String?> findStakeholderByEmail(String email) async {
    if (!AppConfig.instance.useFirebase) {
      return null;
    }

    try {
      final querySnapshot = await _firestore
          .collection('stakeholders')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      return querySnapshot.docs.first.id;
    } catch (e) {
      debugPrint('Error finding stakeholder: $e');
      return null;
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
      case 'inviteStakeholder':
        return Permission.inviteStakeholder;
      // Admin permissions
      case 'manageUsers':
        return Permission.manageUsers;
      case 'viewReports':
        return Permission.viewReports;
      case 'editSettings':
        return Permission.editSettings;
      // Super admin permissions
      case 'admin':
        return Permission.admin;
      case 'root':
        return Permission.root;
      default:
        return null;
    }
  }
}
