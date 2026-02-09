// ==============================================================================
// ENVIRONMENT CONFIGURATION
// ==============================================================================
// Handles loading sensitive configuration from environment variables.
// For local development, use a .env file or set environment variables.
// For production, use Firebase Functions + Secret Manager.
// ==============================================================================

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration for secrets and API keys
/// 
/// Usage:
/// 1. For local development: Use --dart-define or set environment variables
/// 2. For CI/CD: Set environment variables in your pipeline
/// 3. For production: Use Firebase Functions + Secret Manager
/// 
/// Example compile-time configuration:
/// ```
/// flutter run --dart-define=GOOGLE_MAPS_API_KEY=your_actual_api_key_here
/// ```
/// 
/// Firebase Secrets Setup:
/// ```bash
/// firebase functions:secrets:set GOOGLE_MAPS_API_KEY
/// firebase deploy --only functions
/// ```
class EnvConfig {
  static EnvConfig? _instance;
  
  /// Google Maps API key for Places Autocomplete
  final String googleMapsApiKey;
  
  EnvConfig._({
    required this.googleMapsApiKey,
  });
  
  /// Get the current environment configuration
  static EnvConfig get instance {
    if (_instance == null) {
      throw StateError(
        'EnvConfig not initialized. Call EnvConfig.initialize() first.',
      );
    }
    return _instance!;
  }
  
  /// Check if configuration has been initialized
  static bool get isInitialized => _instance != null;
  
  /// Initialize from environment variables (for local development)
  /// 
  /// Loads from .env file first, then falls back to --dart-define flags.
  /// Example: flutter run --dart-define=GOOGLE_MAPS_API_KEY=your_key_here
  static Future<void> initialize({
    String? googleMapsApiKey,
  }) async {
    // Try to load .env file
    try {
      await dotenv.load(fileName: '.env');
      debugPrint('[EnvConfig] .env file loaded successfully');
    } catch (e) {
      debugPrint('[EnvConfig] WARNING: .env file not found or couldn\'t load: $e');
      // .env file not found or couldn't load - that's okay
    }

    final apiKey = googleMapsApiKey ?? 
      dotenv.env['GOOGLE_MAPS_API_KEY'] ??
      const String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: '');

    debugPrint('EnvConfig: Google Maps API Key length: ${apiKey.length}');
    
    _instance = EnvConfig._(
      googleMapsApiKey: apiKey,
    );
  }
  
  /// Initialize from Firebase Secrets (via Cloud Functions)
  /// 
  /// Call this after Firebase has been initialized.
  /// 
  /// Fetches secrets from Cloud Functions (which accesses Secret Manager).
  /// This keeps API keys hidden from client code and Firebase Console.
  static Future<void> initFromFirebase() async {
    try {
      // Call Cloud Function to get configuration
      final functions = FirebaseFunctions.instance;
      final result = await functions.httpsCallable('getAppConfig').call();
      
      final data = result.data as Map<String, dynamic>;
      
      _instance = EnvConfig._(
        googleMapsApiKey: data['googleMapsApiKey'] as String? ?? '',
      );
    } catch (e) {
      // If Firebase Functions fails, fall back to environment variables
      initialize();
    }
  }
  
  /// Check if the Google Maps API key is configured
  bool get hasGoogleMapsApiKey => googleMapsApiKey.isNotEmpty;
}
