// ==============================================================================
// NOTIFICATION SERVICE
// ==============================================================================
// Manages in-app notifications from Firestore in real-time.
// Listens to the 'notifications' collection for the current user and
// provides streams for live notification updates.
//
// Cloud Functions already write notifications (welcome, invite, event updates).
// This service reads, marks as read, and deletes them on the client side.
// ==============================================================================

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/notification_model.dart' as app;

/// Service for managing in-app notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot>? _notificationSub;
  final _notificationsController = StreamController<List<app.Notification>>.broadcast();
  final _unreadCountController = StreamController<int>.broadcast();

  List<app.Notification> _notifications = [];
  String? _currentUserId;

  /// Stream of all notifications for the current user (newest first)
  Stream<List<app.Notification>> get notificationsStream => _notificationsController.stream;

  /// Stream of unread notification count
  Stream<int> get unreadCountStream => _unreadCountController.stream;

  /// Current cached notifications
  List<app.Notification> get notifications => _notifications;

  /// Current unread count
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Start listening to notifications for a specific user
  void startListening(String userId) {
    if (_currentUserId == userId) return; // Already listening
    stopListening(); // Clean up previous listener

    _currentUserId = userId;

    if (!AppConfig.instance.useFirebase) {
      // Dev mode: emit mock notifications
      _notifications = _getMockNotifications(userId);
      _notificationsController.add(_notifications);
      _unreadCountController.add(unreadCount);
      return;
    }

    _notificationSub = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen(
      (snapshot) {
        _notifications = snapshot.docs.map((doc) {
          final data = doc.data();
          return app.Notification(
            id: doc.id,
            title: data['title'] as String? ?? '',
            body: data['body'] as String? ?? '',
            userId: data['userId'] as String? ?? '',
            createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            isRead: data['isRead'] as bool? ?? false,
            type: app.parseNotificationType(data['type'] as String?),
            eventId: data['eventId'] as String?,
            data: data['data'] as Map<String, dynamic>?,
          );
        }).toList();

        _notificationsController.add(_notifications);
        _unreadCountController.add(unreadCount);
      },
      onError: (error) {
        debugPrint('Error listening to notifications: $error');
      },
    );
  }

  /// Stop listening to notifications
  void stopListening() {
    _notificationSub?.cancel();
    _notificationSub = null;
    _currentUserId = null;
    _notifications = [];
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    if (!AppConfig.instance.useFirebase) {
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index].isRead = true;
        _notificationsController.add(_notifications);
        _unreadCountController.add(unreadCount);
      }
      return;
    }

    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    if (!AppConfig.instance.useFirebase) {
      for (final n in _notifications) {
        n.isRead = true;
      }
      _notificationsController.add(_notifications);
      _unreadCountController.add(unreadCount);
      return;
    }

    try {
      final unread = _notifications.where((n) => !n.isRead);
      final batch = _firestore.batch();
      for (final notification in unread) {
        batch.update(
          _firestore.collection('notifications').doc(notification.id),
          {'isRead': true},
        );
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    if (!AppConfig.instance.useFirebase) {
      _notifications.removeWhere((n) => n.id == notificationId);
      _notificationsController.add(_notifications);
      _unreadCountController.add(unreadCount);
      return;
    }

    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  /// Clear all notifications for the current user
  Future<void> clearAll() async {
    if (!AppConfig.instance.useFirebase) {
      _notifications = [];
      _notificationsController.add(_notifications);
      _unreadCountController.add(0);
      return;
    }

    try {
      final batch = _firestore.batch();
      for (final notification in _notifications) {
        batch.delete(
          _firestore.collection('notifications').doc(notification.id),
        );
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
    }
  }

  /// Mock notifications for dev mode
  List<app.Notification> _getMockNotifications(String userId) {
    final now = DateTime.now();
    return [
      app.Notification(
        id: 'mock-notif-1',
        title: 'Welcome to SSMS!',
        body: 'Welcome to the Scheduling & Stakeholder Management System.',
        userId: userId,
        createdAt: now.subtract(const Duration(minutes: 5)),
        isRead: false,
      ),
      app.Notification(
        id: 'mock-notif-2',
        title: 'New Event Created',
        body: 'A new event "Team Meeting" has been created.',
        userId: userId,
        createdAt: now.subtract(const Duration(hours: 1)),
        isRead: false,
      ),
      app.Notification(
        id: 'mock-notif-3',
        title: 'Stakeholder Updated',
        body: 'John Doe\'s contact information has been updated.',
        userId: userId,
        createdAt: now.subtract(const Duration(hours: 3)),
        isRead: true,
      ),
    ];
  }

  /// Dispose resources
  void dispose() {
    stopListening();
    _notificationsController.close();
    _unreadCountController.close();
  }
}
