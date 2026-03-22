// ============================================
// FILE: lib/screens/gps/gps_consent_screen.dart
// PURPOSE: POPIA/GDPR-compliant GPS consent screen with Accept/Decline
//          and a manage-mode toggle for drivers/technicians.
// Requirements: GPS-06
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_scheduling_app/config/theme.dart';
import 'package:vehicle_scheduling_app/providers/gps_provider.dart';
import 'package:vehicle_scheduling_app/services/gps_service.dart';

class GpsConsentScreen extends StatefulWidget {
  /// When true, the screen is navigated to from the dashboard for managing
  /// GPS settings after initial consent has already been given.
  final bool isManageMode;

  const GpsConsentScreen({super.key, this.isManageMode = false});

  @override
  State<GpsConsentScreen> createState() => _GpsConsentScreenState();
}

class _GpsConsentScreenState extends State<GpsConsentScreen> {
  bool _submitting = false;

  // ==========================================
  // ACCEPT — grant consent and enable GPS
  // ==========================================
  Future<void> _acceptConsent() async {
    setState(() => _submitting = true);
    final gps = context.read<GpsProvider>();
    final success = await gps.grantConsent();

    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      // Pop the consent gate and continue to the main app
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save consent. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==========================================
  // DECLINE — record a declined consent in DB for POPIA audit trail
  // GPS is granted then immediately disabled (gps_enabled=false).
  // ==========================================
  Future<void> _declineConsent() async {
    setState(() => _submitting = true);
    final gps = context.read<GpsProvider>();

    // First create the consent record (POPIA audit requirement)
    await GpsService.grantConsent();
    // Then immediately disable GPS tracking
    await gps.toggleGps(false);

    if (!mounted) return;
    setState(() => _submitting = false);

    // Proceed to main app without GPS
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/',
      (route) => false,
    );
  }

  // ==========================================
  // TOGGLE (manage mode only)
  // ==========================================
  Future<void> _toggleGps(bool value) async {
    final gps = context.read<GpsProvider>();
    await gps.toggleGps(value);
  }

  @override
  Widget build(BuildContext context) {
    final gps = context.watch<GpsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Tracking Consent'),
        // First-time consent: no back button (mandatory screen)
        automaticallyImplyLeading: widget.isManageMode,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              // ── Icon ─────────────────────────────
              const Icon(
                Icons.location_on,
                size: 80,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 16),

              // ── Heading ──────────────────────────
              const Text(
                'Location Tracking',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              const Text(
                'We need your permission to track your location during active jobs.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // ── Manage mode: current status toggle ───
              if (widget.isManageMode) ...[
                SwitchListTile(
                  title: Text(
                    gps.gpsEnabled ? 'GPS Tracking: ON' : 'GPS Tracking: OFF',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: gps.gpsEnabled ? Colors.green : AppTheme.textSecondary,
                    ),
                  ),
                  subtitle: Text(
                    gps.gpsEnabled
                        ? 'Your location is being shared during working hours.'
                        : 'Location sharing is currently disabled.',
                  ),
                  value: gps.gpsEnabled,
                  onChanged: gps.isLoading ? null : _toggleGps,
                  activeColor: AppTheme.primaryColor,
                ),
                const SizedBox(height: 16),
              ],

              // ── Consent explanation card ──────────
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ConsentSection(
                        icon: Icons.gps_fixed,
                        title: 'What we collect',
                        body:
                            'Your GPS coordinates (latitude and longitude) while you are on active jobs.',
                      ),
                      const Divider(height: 24),
                      _ConsentSection(
                        icon: Icons.route,
                        title: 'Why we collect it',
                        body:
                            'To optimize dispatch routing and provide real-time job tracking for schedulers.',
                      ),
                      const Divider(height: 24),
                      _ConsentSection(
                        icon: Icons.schedule,
                        title: 'When we collect it',
                        body:
                            'Only during working hours (6:00 AM - 8:00 PM) while the app is open.',
                      ),
                      const Divider(height: 24),
                      _ConsentSection(
                        icon: Icons.security,
                        title: 'Your rights',
                        body:
                            'You can disable GPS tracking at any time from the dashboard. '
                            'Your location data is stored securely and only visible to authorized personnel.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Action buttons (first-time consent only) ──
              if (!widget.isManageMode) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _acceptConsent,
                    icon: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('I Agree - Enable GPS Tracking'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _submitting ? null : _declineConsent,
                    child: const Text(
                      'Decline - Skip GPS Tracking',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                ),
              ],

              // ── Manage mode: close button ─────────
              if (widget.isManageMode) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ),
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// HELPER WIDGET — consent section row
// ============================================
class _ConsentSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _ConsentSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
