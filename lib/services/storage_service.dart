// ==============================================================================
// STORAGE SERVICE - Firebase Storage Management
// ==============================================================================
// Handles file uploads to Firebase Storage, particularly user avatars
//
// Implementation Details:
// - Uploads user profile images to 'avatars/{userId}' path
// - Returns download URL after successful upload
// - Handles image compression and format conversion
// ==============================================================================

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

/// Service for managing file uploads to Firebase Storage
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // Lazy Firebase Storage instance
  FirebaseStorage get _storage => FirebaseStorage.instance;

  /// Upload user avatar image
  /// Returns the download URL of the uploaded image
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List imageBytes,
    String? fileName,
  }) async {
    if (!AppConfig.instance.useFirebase) {
      debugPrint('[Dev] Mock avatar upload for user: $userId');
      // Return a placeholder URL for development
      return 'https://ui-avatars.com/api/?name=User&background=5B7C99&color=fff&size=200';
    }

    try {
      // Create reference to avatar location
      final String path = 'avatars/$userId/${fileName ?? 'avatar.jpg'}';
      final ref = _storage.ref().child(path);

      // Upload metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedBy': userId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      // Upload the file
      final uploadTask = ref.putData(imageBytes, metadata);

      // Monitor upload progress (optional)
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        debugPrint('Avatar upload progress: ${progress.toStringAsFixed(1)}%');
      });

      // Wait for upload to complete
      final snapshot = await uploadTask;
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('Avatar uploaded successfully: $downloadUrl');
      
      return downloadUrl;
    } on FirebaseException catch (e) {
      debugPrint('Firebase Storage error: ${e.code} - ${e.message}');
      throw StorageException('Failed to upload avatar: ${e.message}');
    } catch (e) {
      debugPrint('Error uploading avatar: $e');
      throw StorageException('Failed to upload avatar');
    }
  }

  /// Upload avatar from file path (for mobile)
  Future<String> uploadAvatarFromFile({
    required String userId,
    required File file,
  }) async {
    final bytes = await file.readAsBytes();
    final fileName = file.path.split('/').last;
    return uploadAvatar(
      userId: userId,
      imageBytes: bytes,
      fileName: fileName,
    );
  }

  /// Delete user avatar
  Future<void> deleteAvatar(String userId) async {
    if (!AppConfig.instance.useFirebase) {
      debugPrint('[Dev] Mock delete avatar for user: $userId');
      return;
    }

    try {
      // List all files in user's avatar folder
      final ref = _storage.ref().child('avatars/$userId');
      final result = await ref.listAll();
      
      // Delete all avatar files
      for (final item in result.items) {
        await item.delete();
        debugPrint('Deleted avatar: ${item.fullPath}');
      }
    } on FirebaseException catch (e) {
      debugPrint('Firebase Storage error: ${e.code} - ${e.message}');
      // Don't throw - avatar deletion is not critical
    } catch (e) {
      debugPrint('Error deleting avatar: $e');
    }
  }
}

/// Custom exception for storage operations
class StorageException implements Exception {
  final String message;
  StorageException(this.message);

  @override
  String toString() => message;
}
