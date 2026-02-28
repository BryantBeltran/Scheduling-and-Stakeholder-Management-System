import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

// Use Play Integrity only for actual production releases (not profile/debug builds).
// kDebugMode is false for both profile AND release, so we use kReleaseMode here
// to avoid Play Integrity failures on sideloaded/non-Play-Store builds.
const bool _useProductionAppCheck = kReleaseMode;

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

      // Initialize App Check to protect Firebase resources from abuse.
      // Non-blocking: if App Check isn't registered in Firebase Console yet,
      // the app still works — just without App Check protection.
      try {
        await FirebaseAppCheck.instance.activate(
          androidProvider: _useProductionAppCheck
              ? AndroidProvider.playIntegrity
              : AndroidProvider.debug,
          appleProvider: _useProductionAppCheck
              ? AppleProvider.deviceCheck
              : AppleProvider.debug,
        );
        debugPrint('Firebase App Check activated');
      } catch (e) {
        debugPrint('App Check activation failed (non-fatal): $e');
      }

      _initialized = true;
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
