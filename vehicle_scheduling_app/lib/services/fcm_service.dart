// ============================================
// FILE: lib/services/fcm_service.dart
// PURPOSE: Firebase Cloud Messaging initialization,
//          device token retrieval, foreground notification display,
//          and deep-link routing on notification tap
// Requirements: NOTIF-01, NOTIF-06, TIME-05, TIME-06, TIME-07
// ============================================

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vehicle_scheduling_app/screens/time_management/time_extension_approval_screen.dart';

// Top-level function — required by firebase_messaging background handler.
// Must be annotated with @pragma('vm:entry-point') so the Dart VM
// can call it directly from a separate isolate.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Background messages are auto-displayed by the OS on Android;
  // no extra action needed here.
}

class FcmService {
  static final FlutterLocalNotificationsPlugin _localNotifs =
      FlutterLocalNotificationsPlugin();

  /// Global navigator key used for notification tap routing.
  ///
  /// Must be set as `navigatorKey` on MaterialApp in main.dart so that
  /// [_routeToNotification] can push routes without a BuildContext.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Initialize Firebase, background handler, notification channel,
  /// local notifications plugin, and foreground message listener.
  ///
  /// Wrapped in a try/catch by main() so the app starts without FCM
  /// when google-services.json is missing (e.g., dev machines).
  static Future<void> initialize() async {
    await Firebase.initializeApp();

    // Register the background handler (must be top-level function)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Android notification channel (required for Android 8.0+ / API 26+)
    const channel = AndroidNotificationChannel(
      'high_importance_channel',
      'Job Notifications',
      importance: Importance.high,
    );
    await _localNotifs
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Initialize local notifications plugin
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotifs.initialize(initSettings);

    // Request notification permission (Android 13+ / API 33+)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground: FCM suppresses display on Android by default;
    // we intercept and show via flutter_local_notifications.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        _localNotifs.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              importance: Importance.high,
            ),
          ),
        );
      }
    });

    // App opened from a notification tap (terminated → foreground)
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _routeToNotification(initialMessage.data);
    }

    // App opened from a notification tap (background → foreground)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _routeToNotification(message.data);
    });
  }

  /// Routes the user to the correct screen based on the FCM data payload type.
  ///
  /// Payload shape from backend:
  ///   { "type": "time_extension_requested", "jobId": "42", "requestId": "7" }
  ///   { "type": "time_extension_approved",  "jobId": "42" }
  ///   { "type": "time_extension_denied",    "jobId": "42" }
  static void _routeToNotification(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final navigator = navigatorKey.currentState;
    if (navigator == null || type == null) return;

    switch (type) {
      case 'time_extension_requested':
        // Deep-link directly to scheduler approval screen
        final jobIdRaw = data['jobId'] ?? data['job_id'];
        final requestIdRaw = data['requestId'] ?? data['request_id'];
        final jobId = jobIdRaw != null ? int.tryParse(jobIdRaw.toString()) : null;
        final requestId =
            requestIdRaw != null ? int.tryParse(requestIdRaw.toString()) : null;
        if (jobId != null) {
          navigator.push(
            MaterialPageRoute(
              builder: (_) => TimeExtensionApprovalScreen(
                jobId: jobId,
                requestId: requestId,
              ),
            ),
          );
        }
        break;

      case 'time_extension_approved':
      case 'time_extension_denied':
        // Navigate to job detail — job_detail_screen requires a Job object,
        // so we pop back to jobs list and let the user tap the job.
        // This is the standard pattern for notification-to-list navigation.
        navigator.popUntil((route) => route.isFirst);
        break;
    }
  }

  /// Get FCM registration token for this device.
  ///
  /// Returns null if Firebase is not configured (e.g., missing google-services.json).
  /// Callers (auth_service.dart) must handle null gracefully — login still works.
  static Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      // ignore: avoid_print
      print('FCM getToken failed: $e');
      return null;
    }
  }
}
