

import 'package:flutter/material.dart';
import 'config/config.dart';
import 'services/firebase_service.dart';
import 'app.dart';

/// Default entry point - runs in production mode.
/// 
/// For development, use: flutter run --flavor dev -t lib/main_dev.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Default to production configuration
  AppConfig.initialize(AppFlavor.prod);
  
  // Initialize Firebase only in production
  if (AppConfig.instance.useFirebase) {
    await FirebaseService.instance.initialize();
  }
  
  // Initialize environment config (from Firebase in prod, env vars otherwise)
  if (AppConfig.instance.useFirebase) {
    await EnvConfig.initFromFirebase();
  } else {
    EnvConfig.initialize();
  }
  
  runApp(const SchedulingApp());
}
