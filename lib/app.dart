// ==============================================================================
// SCHEDULING APP - MAIN APPLICATION WIDGET
// ==============================================================================
// This is the shared app widget used by all flavor entry points.
// It reads configuration from AppConfig to customize behavior per environment.
//
// Reference: https://docs.flutter.dev/deployment/flavors
// ==============================================================================

import 'package:flutter/material.dart';
import 'config/app_config.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/dev/dev_screen_navigator.dart';
import 'services/services.dart';
import 'models/models.dart';

/// Main application widget that configures theming and routing.
/// 
/// This widget reads from [AppConfig] to customize behavior based on
/// the current flavor (dev, staging, prod).
class SchedulingApp extends StatelessWidget {
  const SchedulingApp({super.key});

  @override
  Widget build(BuildContext context) {
    final config = AppConfig.instance;
    
    return MaterialApp(
      title: config.appName,
      debugShowCheckedModeBanner: config.showDebugBanner,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/home': (context) => const HomeScreen(),
      },
      // Add a banner for non-prod environments
      builder: (context, child) {
        if (config.isDev || config.isStaging) {
          return Banner(
            message: config.isDev ? 'DEV' : 'STAGING',
            location: BannerLocation.topEnd,
            color: config.isDev ? Colors.green : Colors.orange,
            child: child!,
          );
        }
        return child!;
      },
    );
  }
}

/// Wrapper widget that handles authentication state routing.
/// 
/// Shows [HomeScreen] if user is authenticated, [LoginScreen] otherwise.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final config = AppConfig.instance;
    
    // In dev mode, always start at login screen to allow testing all screens
    if (config.isDev) {
      debugPrint('🔓 Dev mode: Starting at login screen');
      return const DevModeWrapper(child: LoginScreen());
    }
    
    return StreamBuilder<UserModel?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading only if we haven't received any data yet
        if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Show home if authenticated, otherwise show login
        if (snapshot.hasData && snapshot.data != null) {
          return const HomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

/// Wrapper widget that adds dev tools to any screen in dev mode.
/// 
/// Adds a floating action button to access the dev screen navigator.
class DevModeWrapper extends StatelessWidget {
  final Widget child;

  const DevModeWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          right: 16,
          bottom: 80,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.green,
            heroTag: 'devNavButton', // Prevent hero animation conflicts
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DevScreenNavigator(),
                ),
              );
            },
            child: const Icon(Icons.build, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
