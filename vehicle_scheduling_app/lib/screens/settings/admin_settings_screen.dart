// ============================================
// FILE: lib/screens/settings/admin_settings_screen.dart
// PURPOSE: Admin settings (GPS visibility toggle, extensible)
// ============================================

import 'package:flutter/material.dart';
import 'package:vehicle_scheduling_app/config/app_config.dart';
import 'package:vehicle_scheduling_app/config/theme.dart';
import 'package:vehicle_scheduling_app/services/api_service.dart';
import 'package:vehicle_scheduling_app/services/settings_service.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  final ApiService _apiService = ApiService();

  // Emerald text controllers
  final TextEditingController _emeraldUrlController = TextEditingController();
  final TextEditingController _emeraldUserController = TextEditingController();
  final TextEditingController _emeraldPasswordController = TextEditingController();

  Map<String, String> _settings = {};
  bool _loading = true;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _emeraldUrlController.dispose();
    _emeraldUserController.dispose();
    _emeraldPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await _settingsService.getAllSettings();
      setState(() {
        _settings = settings;
        _emeraldUrlController.text = settings['emerald_api_url'] ?? '';
        _emeraldUserController.text = settings['emerald_api_user'] ?? '';
        _emeraldPasswordController.text = settings['emerald_api_password'] ?? '';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleSchedulerGps(bool value) async {
    setState(() => _saving = true);
    try {
      await _settingsService.updateSetting(
        'scheduler_gps_visible',
        value ? 'true' : 'false',
      );
      setState(() {
        _settings['scheduler_gps_visible'] = value ? 'true' : 'false';
        _saving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Schedulers can now see live GPS positions'
                  : 'GPS positions hidden from schedulers',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save setting: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _saveEmeraldSetting(String key, String value) async {
    setState(() => _saving = true);
    try {
      await _settingsService.updateSetting(key, value);
      setState(() {
        _settings[key] = value;
        _saving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Setting "$key" saved'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save setting: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _toggleEmeraldSync(bool value) async {
    await _saveEmeraldSetting('emerald_sync_enabled', value ? 'true' : 'false');
  }

  Future<void> _testEmeraldConnection() async {
    setState(() => _saving = true);
    try {
      final result = await _apiService.get(AppConfig.emeraldStatusEndpoint);
      setState(() => _saving = false);
      if (mounted) {
        final message = result['message'] ?? result['status'] ?? 'Connection OK';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Emerald: $message'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Emerald connection failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _syncEmeraldNow() async {
    setState(() => _saving = true);
    try {
      final result = await _apiService.post(AppConfig.emeraldSyncEndpoint);
      setState(() => _saving = false);
      if (mounted) {
        final message = result['message'] ?? 'Sync completed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Emerald: $message'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Emerald sync failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Admin Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSettings,
            tooltip: 'Reload settings',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildSettings(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadSettings,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettings() {
    final schedulerGpsVisible =
        _settings['scheduler_gps_visible'] == 'true';
    final emeraldSyncEnabled =
        _settings['emerald_sync_enabled'] == 'true';

    return ListView(
      children: [
        // ── GPS & Maps section ────────────────────────
        _SectionHeader(title: 'GPS & Maps'),
        SwitchListTile(
          title: const Text('Scheduler GPS Visibility'),
          subtitle: const Text(
            'Allow schedulers to see live GPS positions',
          ),
          value: schedulerGpsVisible,
          onChanged: _saving ? null : _toggleSchedulerGps,
          secondary: Icon(
            Icons.location_on_outlined,
            color: schedulerGpsVisible
                ? AppTheme.primaryColor
                : AppTheme.textSecondary,
          ),
          activeColor: AppTheme.primaryColor,
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Text(
            schedulerGpsVisible
                ? 'Schedulers can currently see driver locations on the map.'
                : 'Driver locations are currently hidden from schedulers.',
            style: TextStyle(
              fontSize: 12,
              color: schedulerGpsVisible
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondary,
            ),
          ),
        ),

        // ── Emerald Integration section ─────────────────
        _SectionHeader(title: 'Emerald Integration'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _emeraldUrlController,
            decoration: const InputDecoration(
              labelText: 'Emerald API URL',
              hintText: 'https://emerald.example.com/api',
              prefixIcon: Icon(Icons.link),
            ),
            onSubmitted: (value) =>
                _saveEmeraldSetting('emerald_api_url', value),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _emeraldUserController,
            decoration: const InputDecoration(
              labelText: 'API Username',
              prefixIcon: Icon(Icons.person_outline),
            ),
            onSubmitted: (value) =>
                _saveEmeraldSetting('emerald_api_user', value),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _emeraldPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            onSubmitted: (value) =>
                _saveEmeraldSetting('emerald_api_password', value),
          ),
        ),
        SwitchListTile(
          title: const Text('Enable Sync'),
          subtitle: const Text(
            'Automatically sync data with Emerald',
          ),
          value: emeraldSyncEnabled,
          onChanged: _saving ? null : _toggleEmeraldSync,
          secondary: Icon(
            Icons.sync,
            color: emeraldSyncEnabled
                ? AppTheme.primaryColor
                : AppTheme.textSecondary,
          ),
          activeColor: AppTheme.primaryColor,
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _testEmeraldConnection,
                  icon: const Icon(Icons.wifi_tethering),
                  label: const Text('Test Connection'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _syncEmeraldNow,
                  icon: const Icon(Icons.sync),
                  label: const Text('Sync Now'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Section header widget ────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
