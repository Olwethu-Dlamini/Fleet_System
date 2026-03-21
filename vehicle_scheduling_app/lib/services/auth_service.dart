// ============================================
// FILE: lib/services/auth_service.dart
// PURPOSE: Login, logout, token storage
// ============================================

import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_scheduling_app/config/app_config.dart';
import 'package:vehicle_scheduling_app/models/user.dart';
import 'package:vehicle_scheduling_app/services/api_service.dart';
import 'package:vehicle_scheduling_app/services/fcm_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();

  // Keys used to store data in SharedPreferences (local device storage)
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';
  static const String _fullNameKey = 'full_name';
  static const String _roleKey = 'user_role';
  static const String _emailKey = 'user_email';
  static const String _permissionsKey = 'user_permissions'; // ← NEW

  // ==========================================
  // LOGIN
  // POST /api/auth/login
  // ==========================================
  /// Sends credentials to backend, stores token on success.
  /// Returns the logged-in User object.
  /// Throws ApiException with the server error message on failure.
  ///
  /// Example:
  ///   final user = await authService.login('admin', 'Admin@123');
  Future<User> login(String username, String password) async {
    // Get FCM token for push notification registration (NOTIF-06)
    // Fire-and-forget style — login succeeds even if FCM is not configured.
    String? fcmToken;
    try {
      fcmToken = await FcmService.getToken();
    } catch (_) {
      // FCM not available — login still works without push notifications
    }

    final response = await _apiService.post(
      '/auth/login',
      data: {
        'username': username.trim(),
        'password': password,
        if (fcmToken != null) 'fcm_token': fcmToken,
      },
    );

    // Backend returns: { success, token, user: {...} }
    final token = response['token'] as String;
    final user = User.fromJson(response['user'] as Map<String, dynamic>);

    // Save token and user info to device storage
    // This persists across app restarts
    await _saveSession(token, user);

    return user;
  }

  // ==========================================
  // LOGOUT
  // ==========================================
  /// Clears the stored token and user data from device.
  Future<void> logout() async {
    // Tell backend (optional - JWT is stateless)
    try {
      await _apiService.post('/auth/logout');
    } catch (_) {
      // Ignore errors - we clear local data regardless
    }

    // Clear everything from local storage
    await _clearSession();
  }

  // ==========================================
  // CHECK IF LOGGED IN
  // ==========================================
  /// Returns true if a token is stored on the device.
  /// Used on app startup to skip login screen.
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    return token != null && token.isNotEmpty;
  }

  // ==========================================
  // GET STORED TOKEN
  // ==========================================
  /// Returns the JWT token stored on device.
  /// Used by ApiService to add to request headers.
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // ==========================================
  // GET STORED USER
  // ==========================================
  /// Reconstructs the User object from local storage.
  /// Returns null if not logged in.
  Future<User?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);

    if (token == null) return null;

    return User(
      id: prefs.getInt(_userIdKey) ?? 0,
      username: prefs.getString(_usernameKey) ?? '',
      fullName: prefs.getString(_fullNameKey) ?? '',
      role: prefs.getString(_roleKey) ?? '',
      email: prefs.getString(_emailKey) ?? '',
      permissions: (prefs.getStringList(_permissionsKey) ?? const []),
    );
  }

  // ==========================================
  // SAVE SESSION (PRIVATE)
  // ==========================================
  Future<void> _saveSession(String token, User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setInt(_userIdKey, user.id);
    await prefs.setString(_usernameKey, user.username);
    await prefs.setString(_fullNameKey, user.fullName);
    await prefs.setString(_roleKey, user.role);
    await prefs.setString(_emailKey, user.email);
    await prefs.setStringList(_permissionsKey, user.permissions); // ← NEW
  }

  // ==========================================
  // CLEAR SESSION (PRIVATE)
  // ==========================================
  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_fullNameKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_permissionsKey); // ← NEW
  }
}
