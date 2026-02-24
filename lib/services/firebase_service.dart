import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

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
  FirebaseOptions? _getFirebaseOptions() {
    // TODO: Replace with your Firebase project configuration
    // Get these values from Firebase Console > Project Settings
    // For now, returning null will use the default configuration from google-services.json/GoogleService-Info.plist
    return null;
    
    // Example configuration (uncomment and fill in your values):
    /*
    if (defaultTargetPlatform == TargetPlatform.android) {
      return const FirebaseOptions(
        apiKey: 'YOUR_ANDROID_API_KEY',
        appId: 'YOUR_ANDROID_APP_ID',
        messagingSenderId: 'YOUR_SENDER_ID',
        projectId: 'YOUR_PROJECT_ID',
        storageBucket: 'YOUR_STORAGE_BUCKET',
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return const FirebaseOptions(
        apiKey: 'YOUR_IOS_API_KEY',
        appId: 'YOUR_IOS_APP_ID',
        messagingSenderId: 'YOUR_SENDER_ID',
        projectId: 'YOUR_PROJECT_ID',
        storageBucket: 'YOUR_STORAGE_BUCKET',
        iosBundleId: 'YOUR_BUNDLE_ID',
      );
    }
    return null;
    */
  }
}
