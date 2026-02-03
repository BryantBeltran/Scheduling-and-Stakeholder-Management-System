// ==============================================================================
// APP CONFIGURATION
// ==============================================================================
// Source: Flutter Flavors pattern
// Reference: https://docs.flutter.dev/deployment/flavors
//
// This file defines environment-specific configurations for the app.
// Each flavor (dev, staging, prod) has its own configuration values.
// ==============================================================================

import 'env_config.dart';

/// Enum representing the different app environments/flavors
enum AppFlavor {
  dev,
  staging,
  prod,
}

/// Configuration class that holds environment-specific values
/// 
/// Example:
/// ```dart
/// final config = AppConfig.instance;
/// print(config.apiBaseUrl); // Prints the API URL for current flavor
/// ```
class AppConfig {
  /// The current app flavor/environment
  final AppFlavor flavor;
  
  /// Display name of the app (shown in launcher)
  final String appName;
  
  /// Base URL for API calls
  final String apiBaseUrl;
  
  /// Whether to enable debug features
  final bool enableDebugFeatures;
  
  /// Whether to show debug banner
  final bool showDebugBanner;
  
  /// Firebase project ID (if using Firebase)
  final String? firebaseProjectId;
  
  /// Analytics enabled flag
  final bool analyticsEnabled;
  
  /// Logging level
  final String logLevel;
  
  /// Whether to use mock data instead of Firebase
  final bool useMockData;
  
  /// Whether to use Firebase
  final bool useFirebase;

  const AppConfig._({
    required this.flavor,
    required this.appName,
    required this.apiBaseUrl,
    required this.enableDebugFeatures,
    required this.showDebugBanner,
    this.firebaseProjectId,
    required this.analyticsEnabled,
    required this.logLevel,
    required this.useMockData,
    required this.useFirebase,
  });
  
  /// Get Google Maps API key from environment configuration
  /// Returns empty string if not configured
  String get googleMapsApiKey {
    // Lazy load from EnvConfig to support runtime configuration
    try {
      return EnvConfig.instance.googleMapsApiKey;
    } catch (_) {
      return '';
    }
  }

  /// Singleton instance of the current configuration
  static AppConfig? _instance;
  
  /// Get the current app configuration
  /// 
  /// Throws if [initialize] hasn't been called yet.
  static AppConfig get instance {
    if (_instance == null) {
      throw StateError('AppConfig not initialized. Call AppConfig.initialize() first.');
    }
    return _instance!;
  }

  /// Check if configuration has been initialized
  static bool get isInitialized => _instance != null;

  /// Initialize the app configuration for a specific flavor
  /// 
  /// Call this at app startup before runApp().
  /// 
  /// Example:
  /// ```dart
  /// void main() {
  ///   AppConfig.initialize(AppFlavor.dev);
  ///   runApp(const MyApp());
  /// }
  /// ```
  static void initialize(AppFlavor flavor) {
    _instance = _getConfigForFlavor(flavor);
  }

  /// Get the configuration values for a specific flavor
  static AppConfig _getConfigForFlavor(AppFlavor flavor) {
    switch (flavor) {
      case AppFlavor.dev:
        return const AppConfig._(
          flavor: AppFlavor.dev,
          appName: 'SSMS Dev',
          apiBaseUrl: 'https://dev-api.example.com',
          enableDebugFeatures: true,
          showDebugBanner: true,
          firebaseProjectId: 'ssms-dev',
          analyticsEnabled: false,
          logLevel: 'debug',
          useMockData: true,
          useFirebase: false,
        );
      
      case AppFlavor.staging:
        return const AppConfig._(
          flavor: AppFlavor.staging,
          appName: 'SSMS Staging',
          apiBaseUrl: 'https://staging-api.example.com',
          enableDebugFeatures: true,
          showDebugBanner: true,
          firebaseProjectId: 'ssms-staging',
          analyticsEnabled: true,
          logLevel: 'info',
          useMockData: false,
          useFirebase: true,
        );
      
      case AppFlavor.prod:
        return const AppConfig._(
          flavor: AppFlavor.prod,
          appName: 'Scheduling & Stakeholder',
          apiBaseUrl: 'https://api.example.com',
          enableDebugFeatures: false,
          showDebugBanner: false,
          firebaseProjectId: 'ssms-prod',
          analyticsEnabled: true,
          logLevel: 'warning',
          useMockData: false,
          useFirebase: true,
        );
    }
  }

  /// Check if current flavor is development
  bool get isDev => flavor == AppFlavor.dev;
  
  /// Check if current flavor is staging
  bool get isStaging => flavor == AppFlavor.staging;
  
  /// Check if current flavor is production
  bool get isProd => flavor == AppFlavor.prod;

  @override
  String toString() {
    return 'AppConfig(flavor: $flavor, appName: $appName, apiBaseUrl: $apiBaseUrl)';
  }
}
