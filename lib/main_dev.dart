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
import 'config/config.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize development configuration
  AppConfig.initialize(AppFlavor.dev);
  
  // Initialize environment config (loads from .env file or environment variables)
  // Create a .env file in project root with: GOOGLE_MAPS_API_KEY=your_key_here
  await EnvConfig.initialize();
  
  // Log startup info in dev mode
  debugPrint('Starting app in DEVELOPMENT mode');
  debugPrint('API: ${AppConfig.instance.apiBaseUrl}');
  debugPrint('Debug features: ${AppConfig.instance.enableDebugFeatures}');
  
  runApp(const SchedulingApp());
}
