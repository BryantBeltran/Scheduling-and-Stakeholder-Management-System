// ==============================================================================
// ONBOARDING SCREEN
// ==============================================================================
// Completes user profile setup for new Google Sign-In users.
// Collects additional information before granting full access.
// ==============================================================================

import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';

/// Screen for completing user profile after sign up
/// 
/// Shown to new users who authenticate with Google/Apple or email/password
/// to collect additional profile information.
class OnboardingScreen extends StatefulWidget {
  final UserModel? initialUser;
  final String? email;
  final String? displayName;
  final String? inviteToken;
  final String? stakeholderId;
  final String? defaultRole;

  const OnboardingScreen({
    super.key,
    this.initialUser,
    this.email,
    this.displayName,
    this.inviteToken,
    this.stakeholderId,
    this.defaultRole,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserService();
  final _inviteService = InviteService();
  
  late TextEditingController _displayNameController;
  late TextEditingController _organizationController;
  late TextEditingController _phoneController;
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.initialUser?.displayName ?? widget.displayName ?? '',
    );
    _organizationController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _organizationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? userId;
      
      // For OAuth users, update existing user
      if (widget.initialUser != null) {
        userId = widget.initialUser!.id;
        final updatedUser = widget.initialUser!.copyWith(
          displayName: _displayNameController.text.trim(),
        );

        await _userService.completeOnboarding(
          updatedUser,
          organization: _organizationController.text.trim(),
          phone: _phoneController.text.trim(),
        );
      } else {
        // For email/password users, create complete user profile
        final currentUser = AuthService().currentUser;
        if (currentUser != null) {
          userId = currentUser.id;
          await _userService.completeOnboarding(
            currentUser,
            organization: _organizationController.text.trim(),
            phone: _phoneController.text.trim(),
          );
        }
      }

      // If user came from an invite, link them to their stakeholder
      if (userId != null && widget.inviteToken != null) {
        await _inviteService.linkUserToStakeholder(
          userId: userId,
          token: widget.inviteToken!,
        );
      }

      if (mounted) {
        // Navigate to home screen
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/home',
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to complete setup: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        automaticallyImplyLeading: false, // Can't go back
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Welcome message
                Icon(
                  Icons.person_add_alt_1,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 24),
                
                Text(
                  'Welcome!',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                Text(
                  'Please complete your profile to continue',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Display Name
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email (read-only)
                TextFormField(
                  initialValue: widget.initialUser?.email ?? widget.email ?? '',
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  enabled: false,
                ),
                const SizedBox(height: 16),

                // Organization (optional)
                TextFormField(
                  controller: _organizationController,
                  decoration: const InputDecoration(
                    labelText: 'Organization (Optional)',
                    prefixIcon: Icon(Icons.business),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Phone (optional)
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (Optional)',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 24),

                // Error message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_errorMessage != null) const SizedBox(height: 24),

                // Complete button
                ElevatedButton(
                  onPressed: _isLoading ? null : _completeOnboarding,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Complete Setup'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
