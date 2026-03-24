import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

/// Service for initializing and managing Firebase
class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseService get instance => _instance ??= FirebaseService._();

  FirebaseService._();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Initialize Firebase for the app
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp(
        options: _getFirebaseOptions(),
      );

      // Only activate App Check in release builds to avoid debug-token
      // rate-limiting ("Too many attempts") during development.
      if (kReleaseMode) {
        try {
          await FirebaseAppCheck.instance.activate(
            androidProvider: AndroidProvider.playIntegrity,
            appleProvider: AppleProvider.deviceCheck,
          );
          debugPrint('Firebase App Check activated');
        } catch (e) {
          debugPrint('App Check activation failed (non-fatal): $e');
        }
      }

      _initialized = true;

      // Enable Firestore offline persistence so data is available
      // even when the device has no network connection.
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      debugPrint('_______Firebase initialized successfully_____');
    } catch (e) {
      debugPrint(' Firebase initialization error: $e');
      rethrow;
    }
  }
  
  /// Get Firebase options based on platform
  FirebaseOptions _getFirebaseOptions() {
    return DefaultFirebaseOptions.currentPlatform;
  }
}
