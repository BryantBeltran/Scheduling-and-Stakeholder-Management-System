// ==============================================================================
// INVITE SERVICE
// ==============================================================================
// Handles stakeholder invitation operations through Firebase Cloud Functions.
// Provides methods to send invites and validate invite tokens.
// ==============================================================================

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Response from invite operations
class InviteResult {
  final bool success;
  final String? inviteToken;
  final String? email;
  final String? error;

  InviteResult({
    required this.success,
    this.inviteToken,
    this.email,
    this.error,
  });
}

/// Response from token validation
class TokenValidationResult {
  final bool valid;
  final String? reason;
  final String? stakeholderId;
  final String? email;
  final String? defaultRole;

  TokenValidationResult({
    required this.valid,
    this.reason,
    this.stakeholderId,
    this.email,
    this.defaultRole,
  });
}

/// Service for managing stakeholder invitations
class InviteService {
  static final InviteService _instance = InviteService._internal();
  factory InviteService() => _instance;
  InviteService._internal();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Send an invitation to a stakeholder
  /// 
  /// [stakeholderId] - The ID of the stakeholder to invite
  /// [defaultRole] - The role to assign when they create an account (default: 'member')
  /// 
  /// Returns [InviteResult] with success status and invite token
  Future<InviteResult> inviteStakeholder({
    required String stakeholderId,
    String defaultRole = 'member',
  }) async {
    try {
      final callable = _functions.httpsCallable('inviteStakeholder');
      final result = await callable.call<Map<String, dynamic>>({
        'stakeholderId': stakeholderId,
        'defaultRole': defaultRole,
      });

      final data = result.data;
      return InviteResult(
        success: data['success'] == true,
        inviteToken: data['inviteToken'] as String?,
        email: data['email'] as String?,
      );
    } catch (e) {
      debugPrint('Error inviting stakeholder: $e');
      return InviteResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Validate an invite token
  /// 
  /// [token] - The invite token to validate
  /// 
  /// Returns [TokenValidationResult] with validity status and stakeholder info
  Future<TokenValidationResult> validateInviteToken(String token) async {
    try {
      final callable = _functions.httpsCallable('validateInviteToken');
      final result = await callable.call<Map<String, dynamic>>({
        'token': token,
      });

      final data = result.data;
      return TokenValidationResult(
        valid: data['valid'] == true,
        reason: data['reason'] as String?,
        stakeholderId: data['stakeholderId'] as String?,
        email: data['email'] as String?,
        defaultRole: data['defaultRole'] as String?,
      );
    } catch (e) {
      debugPrint('Error validating invite token: $e');
      return TokenValidationResult(
        valid: false,
        reason: 'unavailable',
      );
    }
  }

  /// Link a user account to a stakeholder after signup with invite token
  /// 
  /// [userId] - The ID of the newly created user
  /// [token] - The invite token used during signup
  /// 
  /// Returns true if linking was successful
  Future<bool> linkUserToStakeholder({
    required String userId,
    required String token,
  }) async {
    try {
      final callable = _functions.httpsCallable('linkUserToStakeholder');
      final result = await callable.call<Map<String, dynamic>>({
        'userId': userId,
        'token': token,
      });

      final data = result.data;
      return data['success'] == true;
    } catch (e) {
      debugPrint('Error linking user to stakeholder: $e');
      return false;
    }
  }

  /// Generate a shareable invite link
  /// 
  /// [inviteToken] - The invite token to include in the link
  /// [baseUrl] - The base URL of your app (default: app deep link)
  /// 
  /// Returns a formatted invite URL
  String generateInviteLink(String inviteToken, {String? baseUrl}) {
    // This would be your app's deep link or web URL
    final base = baseUrl ?? 'https://ssms.app/invite';
    return '$base?token=$inviteToken';
  }

  /// Resend an invitation to a stakeholder
  /// 
  /// Generates a fresh token and sends a new email.
  /// [stakeholderId] - The ID of the stakeholder to re-invite
  /// 
  /// Returns [InviteResult] with success status and new invite token
  Future<InviteResult> resendInvite({
    required String stakeholderId,
  }) async {
    try {
      final callable = _functions.httpsCallable('resendInvite');
      final result = await callable.call<Map<String, dynamic>>({
        'stakeholderId': stakeholderId,
      });

      final data = result.data;
      return InviteResult(
        success: data['success'] == true,
        inviteToken: data['inviteToken'] as String?,
        email: data['email'] as String?,
      );
    } catch (e) {
      debugPrint('Error resending invite: $e');
      return InviteResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Notify the backend that onboarding is complete
  /// so it can send a branded welcome email.
  Future<void> notifyOnboardingComplete() async {
    try {
      final callable = _functions
          .httpsCallable('onOnboardingComplete');
      await callable.call<Map<String, dynamic>>({});
    } catch (e) {
      // Non-critical — log and move on
      debugPrint('Welcome email trigger failed: $e');
    }
  }
}
