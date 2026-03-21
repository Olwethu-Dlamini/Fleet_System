// ============================================
// FILE: lib/services/user_service.dart
// PURPOSE: CRUD for system users (admin only for writes)
// ============================================

import 'package:vehicle_scheduling_app/config/app_config.dart';
import 'package:vehicle_scheduling_app/models/user.dart';
import 'package:vehicle_scheduling_app/services/api_service.dart';

class UserService {
  final ApiService apiService = ApiService();

  // Use the same pattern as all other services — AppConfig.usersEndpoint
  // contains the full URL already (e.g. http://host/api/users).
  String get _endpoint => AppConfig.usersEndpoint;

  // ── List ────────────────────────────────────────────────────
  Future<List<User>> getUsers({String? role, String active = '1'}) async {
    String url = _endpoint;
    final params = <String>[];
    if (role != null) params.add('role=$role');
    if (active != '1') params.add('active=$active');
    if (params.isNotEmpty) url += '?${params.join('&')}';

    final response = await apiService.get(url);
    if (response['success'] == true) {
      return (response['users'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(User.fromJson)
          .toList();
    }
    return [];
  }

  // ── Single ──────────────────────────────────────────────────
  Future<User?> getUserById(int id) async {
    final response = await apiService.get('$_endpoint/$id');
    if (response['success'] == true && response['user'] != null) {
      return User.fromJson(response['user']);
    }
    return null;
  }

  // ── Create ──────────────────────────────────────────────────
  Future<User> createUser({
    required String username,
    required String fullName,
    required String email,
    required String password,
    required String role, // 'admin' | 'scheduler' | 'technician'
    bool isActive = true,
    String? contactPhone,
    String? contactPhoneSecondary,
  }) async {
    final data = <String, dynamic>{
      'username': username.trim(),
      'full_name': fullName.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
      'role': role,
      'is_active': isActive ? 1 : 0,
    };
    if (contactPhone != null && contactPhone.isNotEmpty) {
      data['contact_phone'] = contactPhone;
    }
    if (contactPhoneSecondary != null && contactPhoneSecondary.isNotEmpty) {
      data['contact_phone_secondary'] = contactPhoneSecondary;
    }
    final response = await apiService.post(_endpoint, data: data);
    if (response['success'] == true && response['user'] != null) {
      return User.fromJson(response['user']);
    }
    throw Exception(
      response['message'] ?? response['error'] ?? 'Create user failed',
    );
  }

  // ── Update ──────────────────────────────────────────────────
  Future<User> updateUser(int id, Map<String, dynamic> updates) async {
    final response = await apiService.put('$_endpoint/$id', data: updates);
    if (response['success'] == true && response['user'] != null) {
      return User.fromJson(response['user']);
    }
    throw Exception(
      response['message'] ?? response['error'] ?? 'Update user failed',
    );
  }

  // ── Deactivate ──────────────────────────────────────────────
  Future<void> deactivateUser(int id) async {
    final response = await apiService.delete('$_endpoint/$id');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Deactivate failed');
    }
  }

  // ── Reset password ───────────────────────────────────────────
  Future<void> resetPassword(int id, String newPassword) async {
    final response = await apiService.post(
      '$_endpoint/$id/reset-password',
      data: {'new_password': newPassword},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Password reset failed');
    }
  }
}
