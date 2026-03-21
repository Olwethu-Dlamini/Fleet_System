// ============================================
// FILE: lib/widgets/common/notification_bell.dart
// PURPOSE: Bell icon widget with unread count badge for AppBar
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import 'package:vehicle_scheduling_app/providers/notification_provider.dart';
import 'package:vehicle_scheduling_app/screens/notifications/notification_center_screen.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notifProvider, _) {
        final count = notifProvider.unreadCount;
        return IconButton(
          icon: badges.Badge(
            showBadge: count > 0,
            badgeContent: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            child: const Icon(Icons.notifications_outlined),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationCenterScreen(),
              ),
            );
          },
        );
      },
    );
  }
}
