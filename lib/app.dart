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
import 'screens/auth/register_password_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/dev/dev_screen_navigator.dart';
import 'screens/events/event_create_screen.dart';
import 'screens/events/event_details_screen.dart';
import 'screens/events/event_edit_screen.dart';
import 'screens/stakeholders/stakeholder_details_screen.dart';
import 'screens/admin/user_management_screen.dart';
import 'screens/profile/notifications_screen.dart';
import 'screens/profile/notification_preferences_screen.dart';
import 'widgets/protected_route.dart';
import 'services/services.dart';
import 'models/models.dart';

/// Global navigator key for push notification navigation.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
      navigatorKey: navigatorKey,
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/home': (context) => const HomeScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/notification-preferences': (context) => const NotificationPreferencesScreen(),
        '/event/create': (context) => const EventCreateScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/register-password') {
          final args = settings.arguments as Map<String, dynamic>?;
          final email = args?['email'] ?? '';
          final inviteToken = args?['inviteToken'] as String?;
          final stakeholderId = args?['stakeholderId'] as String?;
          final defaultRole = args?['defaultRole'] as String?;
          return MaterialPageRoute(
            builder: (context) => RegisterPasswordScreen(
              email: email,
              inviteToken: inviteToken,
              stakeholderId: stakeholderId,
              defaultRole: defaultRole,
            ),
          );
        }
        if (settings.name == '/register') {
          final args = settings.arguments as Map<String, dynamic>?;
          final inviteToken = args?['inviteToken'] as String?;
          return MaterialPageRoute(
            builder: (context) => RegisterScreen(inviteToken: inviteToken),
          );
        }
        if (settings.name == '/onboarding') {
          final args = settings.arguments as Map<String, dynamic>?;
          
          // Check if this is OAuth flow (with UserModel) or email/password flow
          if (args?['user'] != null) {
            // OAuth flow - user from Google/Apple Sign-In
            final user = args!['user'] as UserModel;
            return MaterialPageRoute(
              builder: (context) => OnboardingScreen(
                initialUser: user,
                inviteToken: args['inviteToken'] as String?,
                stakeholderId: args['stakeholderId'] as String?,
                defaultRole: args['defaultRole'] as String?,
              ),
            );
          } else {
            // Email/password flow - use email and displayName
            final email = args?['email'] as String?;
            final displayName = args?['displayName'] as String?;
            return MaterialPageRoute(
              builder: (context) => OnboardingScreen(
                email: email,
                displayName: displayName,
                inviteToken: args?['inviteToken'] as String?,
                stakeholderId: args?['stakeholderId'] as String?,
                defaultRole: args?['defaultRole'] as String?,
              ),
            );
          }
        }
        if (settings.name == '/stakeholder/details') {
          final stakeholderId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (context) => StakeholderDetailsScreen(
              stakeholderId: stakeholderId,
            ),
          );
        }
        if (settings.name == '/event/details') {
          final eventId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (context) => EventDetailsScreen(eventId: eventId),
          );
        }
        if (settings.name == '/event/edit') {
          final event = settings.arguments as EventModel;
          return MaterialPageRoute(
            builder: (context) => EventEditScreen(event: event),
          );
        }
        if (settings.name == '/admin/users') {
          return MaterialPageRoute(
            builder: (context) => ProtectedRoute.userManagement(
              child: const UserManagementScreen(),
            ),
          );
        }
        return null;
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
/// Shows [HomeScreen] if user is authenticated and onboarded,
/// routes to onboarding if needed, [LoginScreen] otherwise.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = AuthService();
  final _userService = UserService();
  final _notificationService = NotificationService();
  final _pushService = PushNotificationService();

  @override
  void initState() {
    super.initState();
    // Initialize push notifications
    _pushService.initialize(navigatorKey);
  }

  @override
  Widget build(BuildContext context) {
    final config = AppConfig.instance;
    
    // In dev mode, always start at login screen to allow testing all screens
    if (config.isDev) {
      debugPrint('Dev mode: Starting at login screen');
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
          final user = snapshot.data!;

          // Start listening to in-app notifications
          _notificationService.startListening(user.id);

          // Register FCM token and request permission
          _pushService.requestPermission().then((_) {
            _pushService.registerToken(user.id);
          });
          
          // Check if new user needs onboarding
          return FutureBuilder<bool>(
            future: _userService.needsOnboarding(user.id),
            builder: (context, onboardingSnapshot) {
              if (onboardingSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              
              if (onboardingSnapshot.data == true) {
                // New user needs onboarding
                return OnboardingScreen(initialUser: user);
              }
              
              return const HomeScreen();
            },
          );
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
