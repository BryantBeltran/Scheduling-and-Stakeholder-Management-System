// ==============================================================================
// SCHEDULING AND STAKEHOLDER MANAGEMENT SYSTEM - DEFAULT ENTRY POINT
// ==============================================================================
// Application: Event and stakeholder management platform
// Platform: Android (primary), iOS, Web (supported)
// Framework: Flutter 3.9.2+
// Language: Dart
//
// IMPORTANT: For flavor-specific builds, use:
//   flutter run --flavor dev -t lib/main_dev.dart
//   flutter run --flavor staging -t lib/main_staging.dart
//   flutter run --flavor prod -t lib/main_prod.dart
//
// This default entry point runs in production mode.
// For development, use main_dev.dart instead.
//
// Architecture:
// - Service-based architecture with separation of concerns
// - Models: Data structures and business entities
// - Services: Business logic and data management
// - Screens: UI components and user interactions
// - Theme: Centralized design system
// - Config: Environment-specific configurations
//
// Key Features:
// - User authentication with role-based access control
// - Event management with status and priority tracking
// - Stakeholder management with relationship tracking
// - Dashboard with statistics and upcoming events
// - Search and filter capabilities
// - Multi-environment support (dev, staging, prod)
//
// Implementation Notes:
// - AuthWrapper handles authentication state routing
// - StreamBuilder listens for auth state changes
// - Named routes for navigation management
// - Material 3 design system throughout
// - AppConfig provides environment-specific values
//
// Sources:
// - Flutter architecture patterns: https://docs.flutter.dev/app-architecture
// - Flutter Flavors: https://docs.flutter.dev/deployment/flavors
// - Material Design 3: https://m3.material.io/
// - Firebase Auth patterns (mock implementation for development)
//
// Week 2 Deliverables:
// ✓ Low-fidelity wireframes (implemented as functional UI)
// ✓ User flows (authentication, event creation, stakeholder assignment)
// ✓ Database schema (defined in models with ER relationships)
// ✓ Android implementation (primary focus with optimized configuration)
// ✓ Flutter Flavors (dev, staging, prod environments)
//
// Author: AI-Assisted Development
// Date: January 14, 2026
// ==============================================================================

import 'package:flutter/material.dart';
import 'config/app_config.dart';
import 'services/services.dart';
import 'app.dart';

/// Default entry point - runs in production mode.
/// 
/// For development, use: flutter run --flavor dev -t lib/main_dev.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await FirebaseService.initialize();
  
  // Default to production configuration
  AppConfig.initialize(AppFlavor.prod);
  
  runApp(const SchedulingApp());
}
