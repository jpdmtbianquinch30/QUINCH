import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Handles local push notifications and periodic polling from backend.
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._();
  factory PushNotificationService() => _instance;
  PushNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  Timer? _pollTimer;
  ApiService? _api;
  bool _initialized = false;
  int _lastKnownUnread = 0;

  // Notification channel
  static const _channelId = 'quinch_channel';
  static const _channelName = 'QUINCH';
  static const _channelDesc = 'Notifications de QUINCH';

  /// Initialize the notification system
  Future<void> initialize(ApiService api) async {
    if (_initialized) return;
    _api = api;

    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS/macOS settings
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create the Android notification channel
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );
    }

    _initialized = true;
    debugPrint('[PushNotif] Initialized');
  }

  /// Request notification permission (required for Android 13+)
  Future<bool> requestPermission() async {
    final status = await Permission.notification.status;
    debugPrint('[PushNotif] Current permission status: $status');

    if (status.isGranted) return true;

    if (status.isDenied) {
      final result = await Permission.notification.request();
      debugPrint('[PushNotif] Permission request result: $result');
      return result.isGranted;
    }

    if (status.isPermanentlyDenied) {
      debugPrint('[PushNotif] Permission permanently denied - user needs to go to settings');
      return false;
    }

    return false;
  }

  /// Start polling for new notifications from the backend
  void startPolling({Duration interval = const Duration(seconds: 30)}) {
    stopPolling();
    debugPrint('[PushNotif] Starting poll every ${interval.inSeconds}s');
    _pollTimer = Timer.periodic(interval, (_) => _checkForNewNotifications());
    // Also check immediately
    _checkForNewNotifications();
  }

  /// Stop polling
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Check backend for new unread notifications
  Future<void> _checkForNewNotifications() async {
    if (_api == null) return;
    try {
      final response = await _api!.get('/notifications/unread-count');
      final count = response.data['count'] as int? ?? 0;

      debugPrint('[PushNotif] Unread count: $count (last known: $_lastKnownUnread)');

      if (count > _lastKnownUnread && _lastKnownUnread >= 0) {
        // There are new notifications — fetch the latest ones
        final notifResponse = await _api!.get('/notifications', queryParameters: {'page': 1, 'per_page': 5});
        final data = notifResponse.data;
        final list = data['data'] ?? data['notifications']?['data'] ?? data['notifications'] ?? [];

        if (list is List && list.isNotEmpty) {
          // Show the most recent unread notification
          for (final notif in list) {
            if (notif['read_at'] == null) {
              await _showNotification(
                id: notif['id'].hashCode,
                title: notif['title'] ?? 'QUINCH',
                body: notif['body'] ?? notif['message'] ?? 'Vous avez une nouvelle notification',
                payload: notif['action_url'] ?? '',
              );
              break; // Show only the latest one to avoid spam
            }
          }
        }
      }

      _lastKnownUnread = count;

      // Save last count
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('quinch_last_unread', count);
    } catch (e) {
      debugPrint('[PushNotif] Poll error: $e');
    }
  }

  /// Show a local notification
  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF4F6EF7),
      enableVibration: true,
      playSound: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _plugin.show(id: id, title: title, body: body, notificationDetails: details, payload: payload);
    debugPrint('[PushNotif] Showed notification: $title - $body');
  }

  /// Send a direct local notification (for testing or immediate feedback)
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) return;
    await _showNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      payload: payload,
    );
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[PushNotif] Notification tapped: ${response.payload}');
    // Navigation can be handled via a global navigator key or callback
  }

  /// Reset the unread counter (call when user views notifications)
  void resetCounter() {
    _lastKnownUnread = 0;
  }

  /// Dispose
  void dispose() {
    stopPolling();
  }
}
