// ============================================
// FILE: lib/services/settings_service.dart
// PURPOSE: Admin settings key-value store
// ============================================

import 'package:vehicle_scheduling_app/config/app_config.dart';
import 'package:vehicle_scheduling_app/services/api_service.dart';

class SettingsService {
  final ApiService apiService = ApiService();
  String get _endpoint => AppConfig.settingsEndpoint;

  /// Get all settings as a map
  Future<Map<String, String>> getAllSettings() async {
    final response = await apiService.get(_endpoint);
    if (response['success'] == true && response['settings'] != null) {
      final raw = response['settings'] as Map<String, dynamic>;
      return raw.map((k, v) => MapEntry(k, v?.toString() ?? ''));
    }
    return {};
  }

  /// Get a single setting value
  Future<String?> getSetting(String key) async {
    final response = await apiService.get('$_endpoint/$key');
    if (response['success'] == true) {
      return response['value'] as String?;
    }
    return null;
  }

  /// Update a setting
  Future<void> updateSetting(String key, String value) async {
    final response = await apiService.put(
      '$_endpoint/$key',
      data: {'value': value},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to update setting');
    }
  }
}
