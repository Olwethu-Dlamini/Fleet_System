// ============================================
// FILE: lib/screens/settings/admin_settings_screen.dart
// PURPOSE: Admin settings (GPS visibility toggle, extensible)
// ============================================

import 'package:flutter/material.dart';
import 'package:vehicle_scheduling_app/config/theme.dart';
import 'package:vehicle_scheduling_app/services/settings_service.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final SettingsService _settingsService = SettingsService();

  Map<String, String> _settings = {};
  bool _loading = true;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
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
