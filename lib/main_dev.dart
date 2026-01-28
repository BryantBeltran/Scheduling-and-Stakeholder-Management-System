// ==============================================================================
// DEVELOPMENT ENTRY POINT
// ==============================================================================
// Run command: flutter run --flavor dev -t lib/main_dev.dart
// Build command: flutter build apk --flavor dev -t lib/main_dev.dart
//
// This entry point configures the app for development environment:
// - Debug features enabled
// - Mock API endpoints
// - Verbose logging
// - Debug banner shown
// ==============================================================================

import 'package:flutter/material.dart';
import 'config/app_config.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize development configuration
  AppConfig.initialize(AppFlavor.dev);
  
  // Log startup info in dev mode
  debugPrint('Starting app in DEVELOPMENT mode');
  debugPrint('API: ${AppConfig.instance.apiBaseUrl}');
  debugPrint('Debug features: ${AppConfig.instance.enableDebugFeatures}');
  
  runApp(const SchedulingApp());
}
