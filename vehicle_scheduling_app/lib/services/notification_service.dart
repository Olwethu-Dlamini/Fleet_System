// ============================================
// FILE: lib/services/notification_service.dart
// PURPOSE: API calls to /api/notifications endpoints
// ============================================

import 'package:vehicle_scheduling_app/models/app_notification.dart';
import 'package:vehicle_scheduling_app/services/api_service.dart';

class NotificationService {
  final ApiService _apiService = ApiService();

  Future<List<AppNotification>> getNotifications() async {
    final response = await _apiService.get('/notifications');
    final list = response['notifications'] as List<dynamic>;
    return list
        .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<int> getUnreadCount() async {
    final response = await _apiService.get('/notifications/unread-count');
    return response['unread_count'] as int;
  }

  Future<void> markRead(int notificationId) async {
    await _apiService.patch('/notifications/$notificationId/read');
  }

  Future<void> markAllRead() async {
    await _apiService.patch('/notifications/read-all');
  }

  Future<Map<String, dynamic>> getPreferences() async {
    final response = await _apiService.get('/notifications/preferences');
    return response['preferences'] as Map<String, dynamic>;
  }

  Future<void> updatePreferences({
    bool? emailEnabled,
    bool? pushEnabled,
  }) async {
    await _apiService.put('/notifications/preferences', data: {
      if (emailEnabled != null) 'email_enabled': emailEnabled,
      if (pushEnabled != null) 'push_enabled': pushEnabled,
    });
  }
}
