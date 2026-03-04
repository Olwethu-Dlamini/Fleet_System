// ============================================
// FILE: lib/models/user.dart
// PURPOSE: User data model
// Roles: admin | dispatcher | scheduler | technician
//
// CHANGES:
//   • Added isDispatcher getter  (role == 'dispatcher')
//   • isScheduler kept as-is     (role == 'scheduler', legacy DB rows)
//   • Added 'dispatcher' case to roleDisplayName
//   • hasPermission() unchanged — checks server-returned permissions list
// ============================================

class User {
  final int id;
  final String username;
  final String fullName;
  final String role;
  final String email;
  final bool isActive;

  /// Permission keys returned by the server at login / /me.
  /// e.g. ["jobs:read", "jobs:create", "assignments:create", ...]
  /// Use [hasPermission] instead of checking [role] directly in the UI.
  final List<String> permissions;

  const User({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.email,
    this.isActive = true,
    this.permissions = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
      email: json['email'] as String,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      permissions:
          (json['permissions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  // ── Role helpers ──────────────────────────────────────────────
  bool get isAdmin => role == 'admin';
  bool get isDispatcher => role == 'dispatcher'; // ← NEW
  bool get isScheduler => role == 'scheduler'; // legacy rows only
  bool get isTechnician => role == 'technician';

  // ── Permission helper ─────────────────────────────────────────
  // Fully server-driven: the backend computes permissions from the
  // PERMISSIONS map in constants.js and sends them at login / /me.
  bool hasPermission(String permission) => permissions.contains(permission);

  // ── Human-readable role name ──────────────────────────────────
  String get roleDisplayName {
    switch (role) {
      case 'admin':
        return 'Administrator';
      case 'dispatcher':
        return 'Dispatcher'; // ← NEW
      case 'scheduler':
        return 'Scheduler';
      case 'technician':
        return 'Technician';
      default:
        return role;
    }
  }

  User copyWith({
    int? id,
    String? username,
    String? fullName,
    String? role,
    String? email,
    bool? isActive,
    List<String>? permissions,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      email: email ?? this.email,
      isActive: isActive ?? this.isActive,
      permissions: permissions ?? this.permissions,
    );
  }
}
