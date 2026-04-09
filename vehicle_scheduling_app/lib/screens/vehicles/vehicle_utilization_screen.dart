// ============================================
// FILE: lib/screens/vehicles/vehicle_utilization_screen.dart
// PURPOSE: Vehicle utilization stats — jobs today, hours, progress bar
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_scheduling_app/config/theme.dart';
import 'package:vehicle_scheduling_app/models/vehicle.dart';
import 'package:vehicle_scheduling_app/providers/job_provider.dart';
import 'package:vehicle_scheduling_app/providers/vehicle_provider.dart';

class VehicleUtilizationScreen extends StatelessWidget {
  const VehicleUtilizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Vehicle Utilization'),
      ),
      body: const VehicleUtilizationBody(),
    );
  }
}

/// Reusable body content for vehicle utilization — can be embedded
/// in any parent (standalone screen or as a tab in Reports).
class VehicleUtilizationBody extends StatelessWidget {
  const VehicleUtilizationBody({super.key});

  @override
  Widget build(BuildContext context) {
    final jobs = context.watch<JobProvider>().allJobs;
    final vehicles = context.watch<VehicleProvider>().vehicles;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Build per-vehicle stats
    final stats = vehicles.map((vehicle) {
      final vehicleJobs = jobs.where((job) {
        final jobDate = DateTime(
          job.scheduledDate.year,
          job.scheduledDate.month,
          job.scheduledDate.day,
        );
        return job.vehicleId == vehicle.id && jobDate == today;
      }).toList();

      final totalMinutes = vehicleJobs.fold<int>(
        0,
        (sum, job) => sum + job.estimatedDurationMinutes,
      );

      return _VehicleStats(
        vehicle: vehicle,
        jobsToday: vehicleJobs.length,
        totalMinutes: totalMinutes,
      );
    }).toList();

    // Sort: highest utilization first
    stats.sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));

    if (vehicles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping_outlined,
                size: 48, color: AppTheme.textHint),
            SizedBox(height: 12),
            Text(
              'No vehicles found',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        return _VehicleUtilizationCard(stats: stats[index]);
      },
    );
  }
}

// ── Per-vehicle stats data ────────────────────────────────────
class _VehicleStats {
  final Vehicle vehicle;
  final int jobsToday;
  final int totalMinutes;

  const _VehicleStats({
    required this.vehicle,
    required this.jobsToday,
    required this.totalMinutes,
  });

  double get hoursScheduled => totalMinutes / 60.0;

  /// Utilization as a fraction of an 8-hour workday
  double get utilization => (hoursScheduled / 8.0).clamp(0.0, 1.0);

  /// Color based on utilization percentage
  Color get utilizationColor {
    final pct = utilization * 100;
    if (pct > 85) return AppTheme.errorColor;
    if (pct >= 60) return AppTheme.warningColor;
    return AppTheme.successColor;
  }
}

// ── Card widget ───────────────────────────────────────────────
class _VehicleUtilizationCard extends StatelessWidget {
  final _VehicleStats stats;

  const _VehicleUtilizationCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final pctLabel = (stats.utilization * 100).toStringAsFixed(0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle name + plate
            Row(
              children: [
                Icon(
                  Icons.local_shipping,
                  color: stats.utilizationColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stats.vehicle.vehicleName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        stats.vehicle.licensePlate,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Utilization percentage badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: stats.utilizationColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$pctLabel%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: stats.utilizationColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Stats row
            Row(
              children: [
                _StatChip(
                  icon: Icons.work_outline,
                  label: '${stats.jobsToday} jobs today',
                ),
                const SizedBox(width: 16),
                _StatChip(
                  icon: Icons.schedule,
                  label:
                      '${stats.hoursScheduled.toStringAsFixed(1)}h / 8h',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: stats.utilization,
                minHeight: 8,
                backgroundColor: AppTheme.dividerColor,
                valueColor:
                    AlwaysStoppedAnimation<Color>(stats.utilizationColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
