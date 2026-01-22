// ==============================================================================
// DEV SCREEN NAVIGATOR
// ==============================================================================
// Development-only screen for quickly navigating between all app screens.
// Only visible when running in dev mode (AppConfig.isDev).
//
// Features:
// - List of all screens with navigation
// - Current route highlighting
// - Quick access to test all screens
// - Screen descriptions for reference
// ==============================================================================

import 'package:flutter/material.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../auth/forgot_password_screen.dart';
import '../home/home_screen.dart';
import '../events/event_list_screen.dart';
import '../stakeholders/stakeholder_list_screen.dart';
import '../profile/profile_screen.dart';

/// Dev-only screen navigator for testing all screens
class DevScreenNavigator extends StatelessWidget {
  const DevScreenNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🛠️ Dev Screen Navigator'),
        backgroundColor: Colors.green,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Tap any screen to navigate and test:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Auth Screens Section
          const SectionHeader(title: '🔐 Authentication'),
          ScreenTile(
            title: 'Login Screen',
            subtitle: 'Email/password login',
            icon: Icons.login,
            onTap: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
          ),
          ScreenTile(
            title: 'Register Screen',
            subtitle: 'New user registration',
            icon: Icons.person_add,
            onTap: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const RegisterScreen()),
            ),
          ),
          ScreenTile(
            title: 'Forgot Password Screen',
            subtitle: 'Password reset flow',
            icon: Icons.lock_reset,
            onTap: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Main App Screens Section
          const SectionHeader(title: '📱 Main Application'),
          ScreenTile(
            title: 'Home Screen',
            subtitle: 'Dashboard with bottom navigation',
            icon: Icons.home,
            onTap: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            ),
          ),
          ScreenTile(
            title: 'Event List Screen',
            subtitle: 'View and manage events',
            icon: Icons.event,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EventListScreen()),
            ),
          ),
          ScreenTile(
            title: 'Stakeholder List Screen',
            subtitle: 'View and manage stakeholders',
            icon: Icons.people,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StakeholderListScreen()),
            ),
          ),
          ScreenTile(
            title: 'Profile Screen',
            subtitle: 'User profile and settings',
            icon: Icons.person,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Instructions
          const Card(
            color: Colors.green,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Dev Mode Tips',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• This screen only appears in dev mode\n'
                    '• Use the floating button (🛠️) to return here\n'
                    '• Test each screen for UI and functionality\n'
                    '• Check different device sizes and orientations',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section header widget
class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
      ),
    );
  }
}

/// Screen tile widget for navigation
class ScreenTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const ScreenTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.green),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
