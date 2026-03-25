// ============================================
// FILE: lib/screens/notifications/notification_center_screen.dart
// PURPOSE: In-app notification history with read/unread states
//          and notification preferences bottom sheet (NOTIF-04)
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_scheduling_app/providers/notification_provider.dart';
import 'package:vehicle_scheduling_app/providers/auth_provider.dart';
import 'package:vehicle_scheduling_app/models/app_notification.dart';
import 'package:vehicle_scheduling_app/screens/time_management/time_extension_approval_screen.dart';
import 'package:vehicle_scheduling_app/screens/jobs/job_detail_screen.dart';
import 'package:vehicle_scheduling_app/providers/job_provider.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  @override
  void initState() {
    super.initState();
    // Load notifications when screen opens
    Future.microtask(
      () => context.read<NotificationProvider>().loadNotifications(),
    );
  }

  void _showPreferencesSheet() {
    final provider = context.read<NotificationProvider>();
    provider.loadPreferences();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return Consumer<NotificationProvider>(
          builder: (context, provider, _) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notification Preferences',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  if (provider.isPrefsLoading)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    SwitchListTile(
                      title: const Text('Email Notifications'),
                      subtitle: const Text('Receive job alerts via email'),
                      value: provider.emailEnabled,
                      onChanged: (value) =>
                          provider.toggleEmailEnabled(value),
                    ),
                    SwitchListTile(
                      title: const Text('Push Notifications'),
                      subtitle: const Text(
                        'Receive push notifications on this device',
                      ),
                      value: provider.pushEnabled,
                      onChanged: (value) =>
                          provider.togglePushEnabled(value),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _navigateForNotification(AppNotification notif) {
    if (notif.jobId == null) return;

    final auth = context.read<AuthProvider>();

    // Time extension request → admin/scheduler goes to approval screen
    if (notif.type == 'time_extension_requested' &&
        (auth.isAdmin || auth.hasPermission('jobs:update'))) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TimeExtensionApprovalScreen(jobId: notif.jobId!),
        ),
      );
      return;
    }

    // All other job notifications → open the job detail
    final jobProvider = context.read<JobProvider>();
    final job = jobProvider.allJobs.where((j) => j.id == notif.jobId).firstOrNull;
    if (job != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => JobDetailScreen(job: job)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Notification Preferences',
            onPressed: _showPreferencesSheet,
          ),
          TextButton(
            onPressed: () =>
                context.read<NotificationProvider>().markAllRead(),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Failed to load notifications',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => provider.loadNotifications(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadNotifications(),
            child: ListView.separated(
              itemCount: provider.notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final notif = provider.notifications[index];
                return _NotificationTile(
                  notification: notif,
                  onTap: () {
                    if (!notif.isRead) {
                      provider.markRead(notif.id);
                    }
                    _navigateForNotification(notif);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        _getIconForType(notification.type),
        color: notification.isRead
            ? Colors.grey
            : Theme.of(context).primaryColor,
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight:
              notification.isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notification.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            _formatTime(notification.createdAt),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
      tileColor:
          notification.isRead ? null : Colors.blue.withOpacity(0.05),
      onTap: onTap,
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'job_starting_soon':
        return Icons.access_time;
      case 'job_overdue':
        return Icons.warning_amber;
      case 'job_status_changed':
        return Icons.sync;
      case 'time_extension_requested':
        return Icons.timer_outlined;
      case 'time_extension_approved':
        return Icons.check_circle_outline;
      case 'time_extension_denied':
        return Icons.cancel_outlined;
      default:
        return Icons.notifications;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
