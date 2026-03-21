// ============================================
// FILE: lib/services/fcm_service.dart
// PURPOSE: Firebase Cloud Messaging initialization,
//          device token retrieval, foreground notification display
// Requirements: NOTIF-01, NOTIF-06
// ============================================

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
