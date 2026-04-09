// ============================================
// FILE: lib/screens/users/users_screen.dart
// PURPOSE: System user management — admin only
//
// Features:
//   • Lists all users with role colour-coding
//   • Filter by role (All / Admin / Scheduler / Technician)
//   • FAB → Add User bottom sheet
//   • Tap card → Edit User bottom sheet
//   • Deactivate / Reactivate toggle
//   • Reset password dialog
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vehicle_scheduling_app/config/theme.dart';
import 'package:vehicle_scheduling_app/models/user.dart';
import 'package:vehicle_scheduling_app/providers/auth_provider.dart';
import 'package:vehicle_scheduling_app/services/user_service.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final UserService _service = UserService();

  List<User> _users = [];
  bool _loading = true;
  String? _error;
  String? _roleFilter; // null = all
  final _searchController = TextEditingController();
  String _searchQuery = '';

  List<User> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    return _users.where((u) {
      final q = _searchQuery;
      return u.fullName.toLowerCase().contains(q) ||
          u.username.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.role.toLowerCase().contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    // Inject token on first frame so context is available
    Future.microtask(() {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await _service.getUsers(
        role: _roleFilter,
        active: 'all', // show both active and inactive
      );
      if (mounted)
        setState(() {
          _users = users;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  // ── Role helpers ─────────────────────────────────────────────
  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return const Color(0xFF7C3AED); // purple
      case 'scheduler':
        return AppTheme.primaryColor;
      case 'technician':
        return AppTheme.successColor;
      default:
        return AppTheme.textHint;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      case 'scheduler':
        return Icons.calendar_month_outlined;
      case 'technician':
        return Icons.engineering_outlined;
      default:
        return Icons.person_outline;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'scheduler':
        return 'Scheduler';
      case 'technician':
        return 'Technician';
      default:
        return role;
    }
  }

  // ── Open add/edit sheet ──────────────────────────────────────
  Future<void> _openForm({User? user}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserFormSheet(user: user, service: _service),
    );
    if (saved == true && mounted) _load();
  }

  // ── Deactivate / reactivate ──────────────────────────────────
  Future<void> _toggleActive(User user) async {
    final isActive = user.isActive;
    final action = isActive ? 'Deactivate' : 'Reactivate';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('$action User'),
        content: Text('$action "${user.fullName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: isActive
                ? ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor)
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      if (isActive) {
        await _service.deactivateUser(user.id);
      } else {
        await _service.updateUser(user.id, {'is_active': 1});
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // ── Reset password ────────────────────────────────────────────
  Future<void> _resetPassword(User user) async {
    final ctrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Reset Password — ${user.fullName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.lock_reset_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password must be at least 6 characters'),
                  ),
                );
                return;
              }
              if (ctrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    try {
      await _service.resetPassword(user.id, ctrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset for ${user.fullName}'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Users without read permission shouldn't reach this screen, but safety net
    if (!auth.hasPermission('users:read')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Users')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 60, color: AppTheme.textHint),
              SizedBox(height: 16),
              Text(
                'Access restricted.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final roleFiltered = _roleFilter == null
        ? _users
        : _users.where((u) => u.role == _roleFilter).toList();
    final filtered = _searchQuery.isEmpty
        ? roleFiltered
        : roleFiltered.where((u) {
            final q = _searchQuery;
            return u.fullName.toLowerCase().contains(q) ||
                u.username.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('System Users'),
        automaticallyImplyLeading: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),

          // ── Role filter chips ──────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip(null, 'All', Icons.people_outline),
                  const SizedBox(width: 8),
                  _filterChip(
                    'admin',
                    'Admins',
                    Icons.admin_panel_settings_outlined,
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    'scheduler',
                    'Schedulers',
                    Icons.calendar_month_outlined,
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    'technician',
                    'Technicians',
                    Icons.engineering_outlined,
                  ),
                ],
              ),
            ),
          ),

          // ── Summary bar ────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: AppTheme.primaryColor.withOpacity(0.05),
            child: Text(
              _loading
                  ? 'Loading...'
                  : '${filtered.length} user(s)'
                        '  •  ${filtered.where((u) => u.isActive).length} active'
                        '  •  ${filtered.where((u) => !(u.isActive)).length} inactive',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),

          // ── List ───────────────────────────────────────────
          Expanded(
            child: _loading
                ? Shimmer.fromColors(
                    baseColor: Colors.grey.shade300,
                    highlightColor: Colors.grey.shade100,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 5,
                      itemBuilder: (_, index) {
                        final nameWidth = [120.0, 100.0, 140.0, 110.0, 130.0][index % 5];
                        final emailWidth = [150.0, 130.0, 170.0, 140.0, 160.0][index % 5];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                const CircleAvatar(radius: 22, backgroundColor: Colors.white),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(height: 14, width: nameWidth, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                                      const SizedBox(height: 8),
                                      Container(height: 10, width: emailWidth, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3))),
                                      const SizedBox(height: 6),
                                      Container(height: 10, width: 70, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3))),
                                    ],
                                  ),
                                ),
                                Container(height: 24, width: 70, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : _error != null
                ? _buildError()
                : filtered.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _UserCard(
                        user: filtered[i],
                        roleColor: _roleColor(filtered[i].role),
                        roleIcon: _roleIcon(filtered[i].role),
                        roleLabel: _roleLabel(filtered[i].role),
                        onEdit: () => _openForm(user: filtered[i]),
                        onToggleActive: () => _toggleActive(filtered[i]),
                        onResetPassword: () => _resetPassword(filtered[i]),
                        isSelf: auth.user?.id == filtered[i].id,
                        canUpdate: auth.hasPermission('users:update'),
                        canDelete: auth.hasPermission('users:delete'),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: auth.hasPermission('users:create')
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Add User'),
            )
          : null,
    );
  }

  Widget _filterChip(String? role, String label, IconData icon) {
    final selected = _roleFilter == role;
    final color = role != null ? _roleColor(role) : AppTheme.primaryColor;
    return FilterChip(
      avatar: Icon(
        icon,
        size: 14,
        color: selected ? color : AppTheme.textSecondary,
      ),
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() {
        _roleFilter = selected ? null : role;
      }),
      selectedColor: color.withOpacity(0.15),
      checkmarkColor: color,
      backgroundColor: AppTheme.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: selected ? color : AppTheme.dividerColor),
      ),
      labelStyle: TextStyle(
        fontSize: 12,
        color: selected ? color : AppTheme.textPrimary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildError() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 52, color: AppTheme.errorColor),
        const SizedBox(height: 12),
        Text(_error!, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.people_outline, size: 60, color: AppTheme.textHint),
        const SizedBox(height: 16),
        Text(
          _roleFilter == null
              ? 'No users found'
              : 'No ${_roleLabel(_roleFilter!).toLowerCase()}s found',
          style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tap + to add a user',
          style: TextStyle(color: AppTheme.textHint, fontSize: 13),
        ),
      ],
    ),
  );
}

// ============================================================
// _UserCard
// ============================================================
class _UserCard extends StatelessWidget {
  final User user;
  final Color roleColor;
  final IconData roleIcon;
  final String roleLabel;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onResetPassword;
  final bool isSelf;
  final bool canUpdate;
  final bool canDelete;

  const _UserCard({
    required this.user,
    required this.roleColor,
    required this.roleIcon,
    required this.roleLabel,
    required this.onEdit,
    required this.onToggleActive,
    required this.onResetPassword,
    required this.isSelf,
    required this.canUpdate,
    required this.canDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = user.isActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isActive
            ? BorderSide.none
            : BorderSide(color: AppTheme.textHint.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isActive
                        ? roleColor.withOpacity(0.12)
                        : AppTheme.textHint.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    roleIcon,
                    color: isActive ? roleColor : AppTheme.textHint,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.fullName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isActive
                                    ? AppTheme.textPrimary
                                    : AppTheme.textHint,
                              ),
                            ),
                          ),
                          if (isSelf)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'You',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          const SizedBox(width: 6),
                          // Role pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? roleColor.withOpacity(0.12)
                                  : AppTheme.textHint.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              roleLabel,
                              style: TextStyle(
                                fontSize: 11,
                                color: isActive ? roleColor : AppTheme.textHint,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '@${user.username}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        user.email,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      if (user.contactPhone != null &&
                          user.contactPhone!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        InkWell(
                          onTap: () => launchUrl(
                            Uri.parse('tel:${user.contactPhone}'),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.phone,
                                size: 14,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                user.contactPhone!,
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (user.contactPhoneSecondary != null &&
                          user.contactPhoneSecondary!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        InkWell(
                          onTap: () => launchUrl(
                            Uri.parse('tel:${user.contactPhoneSecondary}'),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.phone_android,
                                size: 14,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                user.contactPhoneSecondary!,
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (!isActive) ...[
                        const SizedBox(height: 4),
                        const Row(
                          children: [
                            Icon(
                              Icons.block,
                              size: 12,
                              color: AppTheme.textHint,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Inactive',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textHint,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Action row
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Reset password (requires update permission)
                if (canUpdate)
                  _actionBtn(
                    icon: Icons.lock_reset_outlined,
                    label: 'Password',
                    color: AppTheme.textSecondary,
                    onPressed: onResetPassword,
                  ),

                // Activate / Deactivate (not self, requires delete permission)
                if (!isSelf && canDelete)
                  _actionBtn(
                    icon: isActive
                        ? Icons.person_off_outlined
                        : Icons.person_outlined,
                    label: isActive ? 'Deactivate' : 'Reactivate',
                    color: isActive
                        ? AppTheme.warningColor
                        : AppTheme.successColor,
                    onPressed: onToggleActive,
                  ),

                // Edit (requires update permission)
                if (canUpdate)
                  _actionBtn(
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    color: AppTheme.primaryColor,
                    onPressed: onEdit,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// ============================================================
// _UserFormSheet — bottom sheet for create & edit
// ============================================================
class _UserFormSheet extends StatefulWidget {
  final User? user;
  final UserService service;
  const _UserFormSheet({this.user, required this.service});

  @override
  State<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<_UserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _phoneSecondaryCtrl = TextEditingController();

  String _role = 'technician';
  bool _isActive = true;
  bool _saving = false;
  bool _showPass = false;
  bool _showNewPass = false; // visibility toggle for new password
  bool _changePassword = false; // edit mode: expand password section
  String? _saveError;

  bool get _isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final u = widget.user!;
      _usernameCtrl.text = u.username;
      _nameCtrl.text = u.fullName;
      _emailCtrl.text = u.email;
      _role = u.role;
      _isActive = u.isActive;
      _phoneCtrl.text = u.contactPhone ?? '';
      _phoneSecondaryCtrl.text = u.contactPhoneSecondary ?? '';
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _phoneCtrl.dispose();
    _phoneSecondaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      if (_isEditing) {
        // Update profile fields
        final updates = <String, dynamic>{
          'username': _usernameCtrl.text.trim(),
          'full_name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim().toLowerCase(),
          'role': _role,
          'is_active': _isActive ? 1 : 0,
        };
        // Include phone fields if they changed
        if (_phoneCtrl.text != (widget.user!.contactPhone ?? '')) {
          updates['contact_phone'] =
              _phoneCtrl.text.isEmpty ? null : _phoneCtrl.text;
        }
        if (_phoneSecondaryCtrl.text !=
            (widget.user!.contactPhoneSecondary ?? '')) {
          updates['contact_phone_secondary'] =
              _phoneSecondaryCtrl.text.isEmpty
                  ? null
                  : _phoneSecondaryCtrl.text;
        }
        await widget.service.updateUser(widget.user!.id, updates);
        // Also update password if the admin entered a new one
        if (_changePassword && _passCtrl.text.isNotEmpty) {
          await widget.service.resetPassword(widget.user!.id, _passCtrl.text);
        }
      } else {
        await widget.service.createUser(
          username: _usernameCtrl.text.trim(),
          fullName: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim().toLowerCase(),
          password: _passCtrl.text,
          role: _role,
          isActive: _isActive,
          contactPhone: _phoneCtrl.text.isNotEmpty ? _phoneCtrl.text : null,
          contactPhoneSecondary: _phoneSecondaryCtrl.text.isNotEmpty
              ? _phoneSecondaryCtrl.text
              : null,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _saving = false;
        _saveError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + inset),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Text(
                _isEditing ? 'Edit User' : 'Add New User',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Full name
              _field(
                ctrl: _nameCtrl,
                label: 'Full Name',
                icon: Icons.person_outline,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Full name is required'
                    : null,
              ),
              const SizedBox(height: 12),

              // Username
              _field(
                ctrl: _usernameCtrl,
                label: 'Username',
                icon: Icons.alternate_email,
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return 'Username is required';
                  if (v.trim().contains(' ')) return 'No spaces allowed';
                  if (v.trim().length < 3) return 'At least 3 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Email
              _field(
                ctrl: _emailCtrl,
                label: 'Email',
                icon: Icons.email_outlined,
                inputType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Contact Phone (Primary)
              _field(
                ctrl: _phoneCtrl,
                label: 'Contact Phone (Primary)',
                icon: Icons.phone,
                inputType: TextInputType.phone,
                hint: '+268 7X XXX XXXX',
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    final regex = RegExp(r'^\+?[\d\s\-\(\)]{7,20}$');
                    if (!regex.hasMatch(v)) return 'Invalid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Contact Phone (Secondary)
              _field(
                ctrl: _phoneSecondaryCtrl,
                label: 'Contact Phone (Secondary)',
                icon: Icons.phone_android,
                inputType: TextInputType.phone,
                hint: '+268 7X XXX XXXX',
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    final regex = RegExp(r'^\+?[\d\s\-\(\)]{7,20}$');
                    if (!regex.hasMatch(v)) return 'Invalid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Role dropdown
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.dividerColor),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.badge_outlined,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _role,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('Admin'),
                            ),
                            DropdownMenuItem(
                              value: 'scheduler',
                              child: Text('Scheduler'),
                            ),
                            DropdownMenuItem(
                              value: 'technician',
                              child: Text('Technician / Driver'),
                            ),
                          ],
                          onChanged: (v) => setState(() => _role = v!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Password section
              // Create mode: always shown and required
              // Edit mode:   hidden behind a toggle; optional
              if (!_isEditing) ...[
                _field(
                  ctrl: _passCtrl,
                  label: 'Password',
                  icon: Icons.lock_outline,
                  obscure: !_showPass,
                  suffix: IconButton(
                    icon: Icon(
                      _showPass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _showPass = !_showPass),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'At least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _field(
                  ctrl: _confirmCtrl,
                  label: 'Confirm Password',
                  icon: Icons.lock_reset_outlined,
                  obscure: !_showPass,
                  validator: (v) {
                    if (v != _passCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
              ] else ...[
                // ── Edit mode: optional password change ──────────
                InkWell(
                  onTap: () => setState(() {
                    _changePassword = !_changePassword;
                    if (!_changePassword) {
                      _passCtrl.clear();
                      _confirmCtrl.clear();
                    }
                  }),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _changePassword
                          ? AppTheme.primaryColor.withOpacity(0.06)
                          : AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _changePassword
                            ? AppTheme.primaryColor.withOpacity(0.4)
                            : AppTheme.dividerColor,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_reset_outlined,
                          size: 18,
                          color: _changePassword
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Change Password',
                            style: TextStyle(
                              fontSize: 14,
                              color: _changePassword
                                  ? AppTheme.primaryColor
                                  : AppTheme.textPrimary,
                              fontWeight: _changePassword
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        Icon(
                          _changePassword
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: AppTheme.textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_changePassword) ...[
                  const SizedBox(height: 12),
                  _field(
                    ctrl: _passCtrl,
                    label: 'New Password',
                    icon: Icons.lock_outline,
                    obscure: !_showNewPass,
                    suffix: IconButton(
                      icon: Icon(
                        _showNewPass
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                      ),
                      onPressed: () =>
                          setState(() => _showNewPass = !_showNewPass),
                    ),
                    validator: (v) {
                      if (!_changePassword) return null; // not changing — skip
                      if (v == null || v.isEmpty) return 'Enter a new password';
                      if (v.length < 6) return 'At least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _field(
                    ctrl: _confirmCtrl,
                    label: 'Confirm New Password',
                    icon: Icons.lock_reset_outlined,
                    obscure: !_showNewPass,
                    validator: (v) {
                      if (!_changePassword) return null;
                      if (v != _passCtrl.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 12),
              ],

              // Active toggle
              Row(
                children: [
                  const Icon(
                    Icons.toggle_on_outlined,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Account active',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  Switch(
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ],
              ),

              // Error message
              if (_saveError != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.errorColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppTheme.errorColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _saveError!,
                          style: const TextStyle(
                            color: AppTheme.errorColor,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _saving
                            ? 'Saving...'
                            : (_isEditing ? 'Save Changes' : 'Create User'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: inputType,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.errorColor),
        ),
      ),
    );
  }
}
