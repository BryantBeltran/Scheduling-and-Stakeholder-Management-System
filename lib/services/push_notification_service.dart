// ==============================================================================
// PUSH NOTIFICATION SERVICE
// ==============================================================================
// Manages Firebase Cloud Messaging (FCM) for push notifications.
// Handles token registration, permission requests, foreground/background
// message display via flutter_local_notifications, and navigation on tap.
//
// Architecture:
// - FCM delivers push messages when app is background/terminated
// - flutter_local_notifications displays heads-up banners in foreground
// - Firestore notifications collection provides in-app real-time list
// - Tapping a notification navigates to the related event (if eventId present)
//
// Usage:
//   await PushNotificationService().initialize(navigatorKey);
//   PushNotificationService().registerToken(userId);
// ==============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_config.dart';

/// Top-level handler for background FCM messages.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background FCM message: ${message.messageId}');
  // Background messages are automatically displayed as system notifications
  // by FCM on Android/iOS. No extra handling needed here.
}

/// Service for managing push notifications via Firebase Cloud Messaging.
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// Global navigator key for navigation from notification taps
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Whether the service has been initialized
  bool _initialized = false;

  /// Android notification channel for event reminders
  static const String _channelId = 'ssms_notifications';
  static const String _channelName = 'SSMS Notifications';
  static const String _channelDesc =
      'Notifications for events, reminders, and stakeholder updates';

  /// Reminder-specific channel (higher priority)
  static const String _reminderChannelId = 'ssms_reminders';
  static const String _reminderChannelName = 'Event Reminders';
  static const String _reminderChannelDesc =
      'Reminders for upcoming scheduled events';

  // ---------------------------------------------------------------------------
  // INITIALIZATION
  // ---------------------------------------------------------------------------

  /// Initialize push notification service.
  ///
  /// Call this once from main() after Firebase is initialized.
  /// [navigatorKey] is used to navigate when a notification is tapped.
  Future<void> initialize(GlobalKey<NavigatorState>? navigatorKey) async {
    if (_initialized) return;
    if (!AppConfig.instance.useFirebase) {
      debugPrint('Push notifications skipped (dev mode)');
      _initialized = true;
      return;
    }

    _navigatorKey = navigatorKey;

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Initialize local notifications plugin
    await _initLocalNotifications();

    // Create Android notification channels
    await _createNotificationChannels();

    // Listen to foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a terminated-state notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      // Delay slightly so navigator is ready
      Future.delayed(
        const Duration(milliseconds: 500),
        () => _handleNotificationTap(initialMessage),
      );
    }

    _initialized = true;
    debugPrint('Push notification service initialized');
  }

  /// Initialize flutter_local_notifications with platform-specific settings.
  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );
  }

  /// Create Android notification channels (required for Android 8+).
  Future<void> _createNotificationChannels() async {
    if (!Platform.isAndroid) return;

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // General notifications channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.defaultImportance,
      ),
    );

    // High-priority reminders channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _reminderChannelId,
        _reminderChannelName,
        description: _reminderChannelDesc,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PERMISSIONS
  // ---------------------------------------------------------------------------

  /// Request notification permissions from the user.
  ///
  /// Returns true if permission was granted (or already granted).
  /// Only shows the OS prompt if permission has not yet been determined.
  Future<bool> requestPermission() async {
    if (!AppConfig.instance.useFirebase) return false;

    try {
      // Check current status — avoid re-prompting on every login.
      final current = await _messaging.getNotificationSettings();
      if (current.authorizationStatus != AuthorizationStatus.notDetermined) {
        final granted =
            current.authorizationStatus == AuthorizationStatus.authorized ||
                current.authorizationStatus == AuthorizationStatus.provisional;
        debugPrint('Notification permission (cached): ${current.authorizationStatus}');
        return granted;
      }

      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final granted = settings.authorizationStatus ==
              AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      debugPrint(
        'Notification permission: ${settings.authorizationStatus}',
      );
      return granted;
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // TOKEN MANAGEMENT
  // ---------------------------------------------------------------------------

  /// Register the FCM token for the given user.
  ///
  /// Stores the token in the user's Firestore document under `fcmTokens` array.
  /// Also sets up a listener to refresh the token when it changes.
  Future<void> registerToken(String userId) async {
    if (!AppConfig.instance.useFirebase) return;

    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(userId, token);
        debugPrint('FCM token registered for user: $userId');
      }

      // Listen for token refreshes
      _messaging.onTokenRefresh.listen((newToken) {
        _saveToken(userId, newToken);
        debugPrint('FCM token refreshed for user: $userId');
      });
    } catch (e) {
      debugPrint('Error registering FCM token: $e');
    }
  }

  /// Save FCM token to the user's Firestore document.
  Future<void> _saveToken(String userId, String token) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Remove the current FCM token (call on logout).
  Future<void> unregisterToken(String userId) async {
    if (!AppConfig.instance.useFirebase) return;

    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
        debugPrint('FCM token removed for user: $userId');
      }
    } catch (e) {
      debugPrint('Error removing FCM token: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // MESSAGE HANDLERS
  // ---------------------------------------------------------------------------

  /// Handle FCM messages received while the app is in the foreground.
  ///
  /// Shows both a local system notification banner AND an in-app overlay toast.
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground FCM: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    final type = message.data['type'] ?? 'general';
    final isReminder = type == 'event_reminder';

    // System notification banner (flutter_local_notifications)
    _localNotifications.show(
      message.hashCode,
      notification.title ?? 'SSMS',
      notification.body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          isReminder ? _reminderChannelId : _channelId,
          isReminder ? _reminderChannelName : _channelName,
          importance: isReminder ? Importance.high : Importance.defaultImportance,
          priority: isReminder ? Priority.high : Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );

    // In-app overlay toast
    _showInAppToast(
      title: notification.title ?? 'SSMS',
      body: notification.body ?? '',
      data: message.data,
    );
  }

  /// Show a dismissible in-app banner toast over the current screen.
  ///
  /// Auto-dismisses after 4 seconds. Tapping it navigates using the same
  /// logic as a regular notification tap.
  void _showInAppToast({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) {
    final overlay = _navigatorKey?.currentState?.overlay;
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _InAppNotificationToast(
        title: title,
        body: body,
        onTap: () {
          entry.remove();
          _navigateFromPayload(data);
        },
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);

    // Auto-remove after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
    });
  }

  /// Handle notification tap when app was in background.
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.data}');
    _navigateFromPayload(message.data);
  }

  /// Handle tap on a local notification displayed in the foreground.
  void _onLocalNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;

    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _navigateFromPayload(data);
    } catch (e) {
      debugPrint('Error parsing notification payload: $e');
    }
  }

  /// Navigate based on notification data payload.
  void _navigateFromPayload(Map<String, dynamic> data) {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    final type = data['type'] as String?;
    final eventId = data['eventId'] as String?;

    if (eventId != null && eventId.isNotEmpty) {
      // Navigate to event details
      navigator.pushNamed('/event/details', arguments: eventId);
    } else if (type == 'welcome' || type == 'invite_accepted') {
      // Navigate to notifications list
      navigator.pushNamed('/notifications');
    }
  }

  // ---------------------------------------------------------------------------
  // SCHEDULE LOCAL REMINDER (CLIENT-SIDE FALLBACK)
  // ---------------------------------------------------------------------------

  /// Schedule a local notification reminder for an event.
  ///
  /// This is a client-side fallback. The primary reminder system uses
  /// Cloud Functions scheduled triggers + FCM push.
  Future<void> scheduleEventReminder({
    required String eventId,
    required String title,
    required DateTime eventTime,
    required int reminderMinutesBefore,
  }) async {
    final scheduledTime =
        eventTime.subtract(Duration(minutes: reminderMinutesBefore));

    if (scheduledTime.isBefore(DateTime.now())) return; // Already past

    final id = eventId.hashCode + reminderMinutesBefore;

    String timeLabel;
    if (reminderMinutesBefore >= 1440) {
      timeLabel = '${reminderMinutesBefore ~/ 1440} day(s)';
    } else if (reminderMinutesBefore >= 60) {
      timeLabel = '${reminderMinutesBefore ~/ 60} hour(s)';
    } else {
      timeLabel = '$reminderMinutesBefore minutes';
    }

    // Use show() as a simple notification at the trigger time.
    // For precise scheduling, the Cloud Functions scheduler is
    // the primary mechanism (sendEventReminders runs every 15 min).
    // This local notification is an immediate display fallback
    // that can be called when the user views event details.
    _localNotifications.show(
      id,
      'Reminder: $title',
      'Starting in $timeLabel',
      NotificationDetails(
        android: const AndroidNotificationDetails(
          _reminderChannelId,
          _reminderChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode({'type': 'event_reminder', 'eventId': eventId}),
    );

    debugPrint('Reminder displayed for $title');
  }

  /// Cancel a scheduled reminder for an event.
  Future<void> cancelEventReminder(String eventId,
      {int? reminderMinutesBefore}) async {
    if (reminderMinutesBefore != null) {
      await _localNotifications
          .cancel(eventId.hashCode + reminderMinutesBefore);
    } else {
      // Cancel common reminder intervals
      for (final mins in [15, 30, 60, 1440]) {
        await _localNotifications.cancel(eventId.hashCode + mins);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // NOTIFICATION PREFERENCES
  // ---------------------------------------------------------------------------

  /// Update the user's notification preferences on the server.
  Future<void> updateNotificationPreferences({
    required String userId,
    bool? pushEnabled,
    bool? emailEnabled,
    int? defaultReminderMinutes,
    List<String>? mutedEventIds,
  }) async {
    if (!AppConfig.instance.useFirebase) return;

    try {
      final prefs = <String, dynamic>{};
      if (pushEnabled != null) prefs['pushEnabled'] = pushEnabled;
      if (emailEnabled != null) prefs['emailEnabled'] = emailEnabled;
      if (defaultReminderMinutes != null) {
        prefs['defaultReminderMinutes'] = defaultReminderMinutes;
      }
      if (mutedEventIds != null) prefs['mutedEventIds'] = mutedEventIds;

      await _firestore.collection('users').doc(userId).update({
        'notificationPreferences': prefs,
      });
    } catch (e) {
      debugPrint('Error updating notification preferences: $e');
    }
  }

  /// Get user's notification preferences.
  Future<Map<String, dynamic>> getNotificationPreferences(
      String userId) async {
    if (!AppConfig.instance.useFirebase) {
      return {
        'pushEnabled': true,
        'emailEnabled': true,
        'defaultReminderMinutes': 30,
      };
    }

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();
      return (data?['notificationPreferences'] as Map<String, dynamic>?) ??
          {
            'pushEnabled': true,
            'emailEnabled': true,
            'defaultReminderMinutes': 30,
          };
    } catch (e) {
      debugPrint('Error getting notification preferences: $e');
      return {
        'pushEnabled': true,
        'emailEnabled': true,
        'defaultReminderMinutes': 30,
      };
    }
  }
}

// ---------------------------------------------------------------------------
// IN-APP NOTIFICATION TOAST WIDGET
// ---------------------------------------------------------------------------

/// Animated in-app banner shown when a push notification arrives in the
/// foreground. Slides down from the top and auto-dismisses after 4 seconds.
class _InAppNotificationToast extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _InAppNotificationToast({
    required this.title,
    required this.body,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_InAppNotificationToast> createState() => _InAppNotificationToastState();
}

class _InAppNotificationToastState extends State<_InAppNotificationToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.notifications, color: Colors.blue.shade700, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.body.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.body,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: Colors.grey[500]),
                    onPressed: widget.onDismiss,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
