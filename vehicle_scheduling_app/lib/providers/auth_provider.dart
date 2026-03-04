// ============================================
// FILE: lib/providers/auth_provider.dart
// PURPOSE: Auth state management
// Roles: admin | scheduler | technician
// ============================================

import 'package:flutter/material.dart';
import 'package:vehicle_scheduling_app/models/user.dart';
import 'package:vehicle_scheduling_app/services/auth_service.dart';
import 'package:vehicle_scheduling_app/services/api_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  // ── State ────────────────────────────────
  AuthStatus _status = AuthStatus.unknown;
  User? _user = null;
  bool _loading = false;
  String? _error = null;
  String? _token = null;

  // ── Getters ──────────────────────────────
  AuthStatus get status => _status;
  User? get user => _user;
  bool get isLoading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _status == AuthStatus.authenticated;
  String? get token => _token;

  // ── Role shortcuts ────────────────────────
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isScheduler => _user?.isScheduler ?? false;
  bool get isTechnician => _user?.isTechnician ?? false;

  // ── Permission helper ─────────────────────
  /// Use this in widgets to show / hide UI elements.
  ///
  /// Example:
  ///   if (auth.hasPermission('jobs:create')) { ... }
  bool hasPermission(String permission) =>
      _user?.hasPermission(permission) ?? false;

  // ── Inject token into the shared ApiService singleton ───────
  // Since ApiService is now a singleton, calling this once sets
  // the token for ALL services app-wide. No per-screen calls needed.
  // Still accepts an optional argument for backwards compatibility
  // with existing call sites (dashboard, job provider, etc).
  void injectToken([ApiService? apiService]) {
    ApiService().setAuthToken(_token);
  }

  // ── Check auth on app start ───────────────
  Future<void> checkAuthStatus() async {
    _loading = true;
    notifyListeners();

    try {
      final loggedIn = await _authService.isLoggedIn();

      if (loggedIn) {
        _user = await _authService.getStoredUser();
        _token = await _authService.getToken();
        ApiService().setAuthToken(_token); // auto-inject for all services
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
    }

    _loading = false;
    notifyListeners();
  }

  // ── Login ─────────────────────────────────
  Future<bool> login(String username, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.login(username, password);
      _token = await _authService.getToken();
      ApiService().setAuthToken(_token); // auto-inject for all services
      _status = AuthStatus.authenticated;
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Logout ────────────────────────────────
  Future<void> logout() async {
    _loading = true;
    notifyListeners();

    await _authService.logout();

    _user = null;
    _token = null;
    ApiService().setAuthToken(null); // clear token from singleton
    _status = AuthStatus.unauthenticated;
    _loading = false;
    _error = null;
    notifyListeners();
  }

  // ── Clear error ───────────────────────────
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
