import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/services.dart';

/// Screen shown after email/password signup asking the user to verify their email.
///
/// Polls Firebase every 5 seconds to detect verification. Also allows the user
/// to manually trigger a check or resend the verification email.
///
/// On successful verification, navigates to [nextRoute] (defaults to '/onboarding').
class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String? nextRoute;
  final Object? nextArguments;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    this.nextRoute,
    this.nextArguments,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _authService = AuthService();

  Timer? _pollTimer;
  bool _isChecking = false;
  bool _isResending = false;
  String? _statusMessage;
  bool _statusIsError = false;

  // Cooldown to prevent spamming resend
  DateTime? _lastResent;
  static const _resendCooldown = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    // Send verification email as soon as the screen loads
    _sendInitialVerification();
    // Poll every 5 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollCheck());
  }

  Future<void> _sendInitialVerification() async {
    try {
      await _authService.sendEmailVerification();
      _lastResent = DateTime.now();
    } catch (e) {
      debugPrint('Initial verification email failed: $e');
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _navigateNext() {
    _pollTimer?.cancel();
    Navigator.of(context).pushReplacementNamed(
      widget.nextRoute ?? '/onboarding',
      arguments: widget.nextArguments,
    );
  }

  /// Silent background poll — does not show errors to avoid spamming the UI.
  Future<void> _pollCheck() async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final verified = await _authService.checkEmailVerified();
      if (verified && mounted) {
        _navigateNext();
      }
    } catch (_) {
      // Silently ignore network errors during background polling
    } finally {
      _isChecking = false;
    }
  }

  /// Manual check triggered by the user tapping the button — shows feedback.
  Future<void> _manualCheck() async {
    if (_isChecking) return;
    setState(() {
      _isChecking = true;
      _statusMessage = null;
    });

    try {
      final verified = await _authService.checkEmailVerified();
      if (verified && mounted) {
        _navigateNext();
        return;
      }
      if (mounted) {
        setState(() {
          _statusMessage = 'Email not verified yet. Check your inbox and click the link.';
          _statusIsError = true;
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = '${e.message}. Please try again.';
          _statusIsError = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Network error. Please check your connection and try again.';
          _statusIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _resendVerification() async {
    // Enforce cooldown
    if (_lastResent != null &&
        DateTime.now().difference(_lastResent!) < _resendCooldown) {
      final remaining =
          _resendCooldown - DateTime.now().difference(_lastResent!);
      setState(() {
        _statusMessage = 'Please wait ${remaining.inSeconds}s before resending.';
        _statusIsError = true;
      });
      return;
    }

    setState(() {
      _isResending = true;
      _statusMessage = null;
    });

    try {
      await _authService.sendEmailVerification();
      _lastResent = DateTime.now();
      if (mounted) {
        setState(() {
          _statusMessage = 'Verification email sent!';
          _statusIsError = false;
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = e.message;
          _statusIsError = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Failed to send verification email. Check your network.';
          _statusIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mark_email_unread_outlined,
                    size: 52,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 32),

                Text(
                  'Verify your email',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                Text(
                  'We sent a verification link to',
                  style: TextStyle(color: Colors.grey[600], fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.email,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Click the link in the email to continue.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),

                // Check now button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isChecking ? null : _manualCheck,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isChecking
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            "I've verified my email",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Resend button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _isResending ? null : _resendVerification,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isResending
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Resend verification email',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87),
                          ),
                  ),
                ),

                // Status feedback message
                if (_statusMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _statusMessage!,
                    style: TextStyle(
                      color: _statusIsError ? Colors.orange[800] : Colors.green[700],
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 40),

                // Sign out link
                TextButton(
                  onPressed: _signOut,
                  child: Text(
                    'Use a different account',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
