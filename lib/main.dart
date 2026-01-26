

import 'package:flutter/material.dart';
import 'config/app_config.dart';
import 'services/firebase_service.dart';
import 'app.dart';

/// Default entry point - runs in production mode.
/// 
/// For development, use: flutter run --flavor dev -t lib/main_dev.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Default to production configuration
  AppConfig.initialize(AppFlavor.prod);
  
  // Initialize Firebase
  await FirebaseService.instance.initialize();
  
  runApp(const SchedulingApp());
}
