// ==============================================================================
// PRODUCTION ENTRY POINT
// ==============================================================================
// Run command: flutter run --flavor prod -t lib/main_prod.dart
// Build command: flutter build apk --flavor prod -t lib/main_prod.dart
// Release command: flutter build appbundle --flavor prod -t lib/main_prod.dart
//
// This entry point configures the app for production environment:
// - Debug features disabled
// - Production API endpoints
// - Minimal logging (warnings only)
// - No debug banner
// - Full analytics enabled
// ==============================================================================

import 'package:flutter/material.dart';
import 'config/app_config.dart';
import 'services/firebase_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize production configuration
  AppConfig.initialize(AppFlavor.prod);
  
  // Initialize Firebase for production
  await FirebaseService.instance.initialize();
  
  runApp(const SchedulingApp());
}
