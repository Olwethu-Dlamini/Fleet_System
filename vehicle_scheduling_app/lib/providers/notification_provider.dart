// ============================================
// FILE: lib/providers/notification_provider.dart
// PURPOSE: State management for in-app notifications
// ============================================

import 'package:flutter/material.dart';
import 'package:vehicle_scheduling_app/models/app_notification.dart';
import 'package:vehicle_scheduling_app/services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _service = NotificationService();

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _loading = false;
  String? _error;
  bool _emailEnabled = true;
  bool _pushEnabled = true;
  bool _prefsLoading = false;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _loading;
  String? get error => _error;
  bool get emailEnabled => _emailEnabled;
  bool get pushEnabled => _pushEnabled;
  bool get isPrefsLoading => _prefsLoading;

  Future<void> loadNotifications() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _service.getNotifications();
      _notifications = result;
      _unreadCount = result.where((n) => !n.isRead).length;
    } catch (e) {
      _error = e.toString();
      // ignore: avoid_print
      print('NotificationProvider.loadNotifications error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUnreadCount() async {
    try {
      _unreadCount = await _service.getUnreadCount();
      notifyListeners();
    } catch (e) {
      // ignore: avoid_print
      print('NotificationProvider.refreshUnreadCount error: $e');
    }
  }

  Future<void> markRead(int notificationId) async {
    try {
      await _service.markRead(notificationId);
      final idx = _notifications.indexWhere((n) => n.id == notificationId);
      if (idx >= 0) {
        _notifications[idx] = _notifications[idx].copyWith(isRead: true);
        _unreadCount = _notifications.where((n) => !n.isRead).length;
        notifyListeners();
      }
    } catch (e) {
      // ignore: avoid_print
      print('NotificationProvider.markRead error: $e');
    }
  }

  Future<void> markAllRead() async {
    try {
      await _service.markAllRead();
      _notifications =
          _notifications.map((n) => n.copyWith(isRead: true)).toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      // ignore: avoid_print
      print('NotificationProvider.markAllRead error: $e');
    }
  }

  Future<void> loadPreferences() async {
    _prefsLoading = true;
    notifyListeners();
    try {
      final prefs = await _service.getPreferences();
      _emailEnabled = prefs['email_enabled'] == true;
      _pushEnabled = prefs['push_enabled'] == true;
    } catch (e) {
      // ignore: avoid_print
      print('NotificationProvider.loadPreferences error: $e');
    } finally {
      _prefsLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleEmailEnabled(bool value) async {
    final oldValue = _emailEnabled;
    _emailEnabled = value;
    notifyListeners();
    try {
      await _service.updatePreferences(emailEnabled: value);
    } catch (e) {
      _emailEnabled = oldValue; // rollback on failure
      notifyListeners();
      // ignore: avoid_print
      print('NotificationProvider.toggleEmailEnabled error: $e');
    }
  }

  Future<void> togglePushEnabled(bool value) async {
    final oldValue = _pushEnabled;
    _pushEnabled = value;
    notifyListeners();
    try {
      await _service.updatePreferences(pushEnabled: value);
    } catch (e) {
      _pushEnabled = oldValue; // rollback on failure
      notifyListeners();
      // ignore: avoid_print
      print('NotificationProvider.togglePushEnabled error: $e');
    }
  }
}
