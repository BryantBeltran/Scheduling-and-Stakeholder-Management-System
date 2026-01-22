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
import 'config/app_config.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize staging configuration
  AppConfig.initialize(AppFlavor.staging);
  
  // Log startup info
  debugPrint('🎭 Starting app in STAGING mode');
  debugPrint('📡 API: ${AppConfig.instance.apiBaseUrl}');
  
  runApp(const SchedulingApp());
}
