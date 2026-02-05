// ==============================================================================
// STAGING ENTRY POINT
// ==============================================================================
// Run command: flutter run --flavor staging -t lib/main_staging.dart
// Build command: flutter build apk --flavor staging -t lib/main_staging.dart
//
// This entry point configures the app for staging environment:
// - Debug features enabled for testing
// - Staging API endpoints
// - Info-level logging
// - Debug banner shown
// - Analytics enabled for testing
// ==============================================================================

import 'package:flutter/material.dart';
import 'config/config.dart';
import 'services/firebase_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize staging configuration
  AppConfig.initialize(AppFlavor.staging);
  
  // Initialize environment config (loads from .env file or environment variables)
  await EnvConfig.initialize();
  
  // Log startup info
  debugPrint('Starting app in STAGING mode');
  debugPrint('API: ${AppConfig.instance.apiBaseUrl}');
  
  // Debug: Check if API key is loaded
  debugPrint('Google Maps API Key configured: ${EnvConfig.instance.hasGoogleMapsApiKey}');
  if (EnvConfig.instance.hasGoogleMapsApiKey) {
    debugPrint('API Key (first 10 chars): ${EnvConfig.instance.googleMapsApiKey.substring(0, 10)}...');
  } else {
    debugPrint('WARNING: Google Maps API Key NOT loaded! Location search will not work.');
  }
  
  // Initialize Firebase for staging
  await FirebaseService.instance.initialize();
  debugPrint('Firebase Initialized!');
  runApp(const SchedulingApp());
}
