

import 'package:flutter/material.dart';
import 'config/app_config.dart';
import 'app.dart';

/// Default entry point - runs in production mode.
/// 
/// For development, use: flutter run --flavor dev -t lib/main_dev.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Default to production configuration
  AppConfig.initialize(AppFlavor.prod);
  
  runApp(const SchedulingApp());
}
