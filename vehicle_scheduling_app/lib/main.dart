// ============================================
// FILE: lib/main.dart
// PURPOSE: App entry point, providers, navigation
// ROLES: admin | scheduler | technician
// CHANGES:
//   • Admin gets a 5th tab: Users (people icon)
//   • Admin gets a 6th tab: Reports (bar chart icon)
//   • Scheduler/technician tabs unchanged
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_scheduling_app/config/theme.dart';
import 'package:vehicle_scheduling_app/providers/auth_provider.dart';
import 'package:vehicle_scheduling_app/providers/job_provider.dart';
import 'package:vehicle_scheduling_app/providers/vehicle_provider.dart';
import 'package:vehicle_scheduling_app/providers/notification_provider.dart';
import 'package:vehicle_scheduling_app/providers/time_extension_provider.dart';
import 'package:vehicle_scheduling_app/providers/gps_provider.dart';
import 'package:vehicle_scheduling_app/screens/gps/gps_consent_screen.dart';
import 'package:vehicle_scheduling_app/screens/login_screen.dart';
import 'package:vehicle_scheduling_app/screens/dashboard/dashboard_screen.dart';
import 'package:vehicle_scheduling_app/screens/jobs/jobs_list_screen.dart';
import 'package:vehicle_scheduling_app/screens/jobs/create_job_screen.dart';
import 'package:vehicle_scheduling_app/screens/jobs/scheduler_screen.dart';
import 'package:vehicle_scheduling_app/screens/vehicles/vehicles_list_screen.dart';
import 'package:vehicle_scheduling_app/screens/users/users_screen.dart';
import 'package:vehicle_scheduling_app/screens/reports/reports_screen.dart'; // ← NEW
import 'package:vehicle_scheduling_app/screens/settings/admin_settings_screen.dart';
import 'package:vehicle_scheduling_app/screens/gps/live_tracking_screen.dart';
import 'package:vehicle_scheduling_app/screens/jobs/data_export_screen.dart';
import 'package:vehicle_scheduling_app/services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await FcmService.initialize();
  } catch (e) {
    // Firebase not configured (missing google-services.json) — app still
    // works without push notifications. Graceful degradation by design.
    // ignore: avoid_print
    print('FCM initialization skipped: $e');
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => JobProvider()),
        ChangeNotifierProvider(create: (_) => VehicleProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => TimeExtensionProvider()),
        ChangeNotifierProvider(create: (_) => GpsProvider()),
      ],
      child: const VehicleSchedulingApp(),
    ),
  );
}

class VehicleSchedulingApp extends StatelessWidget {
  const VehicleSchedulingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vehicle Scheduling',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      navigatorKey: FcmService.navigatorKey,
      home: const AuthGate(),
    );
  }
}

// ============================================
// AUTH GATE — routes to login or main app
// ============================================
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<AuthProvider>().checkAuthStatus());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.status == AuthStatus.unknown) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_shipping,
                size: 60,
                color: AppTheme.primaryColor,
              ),
              SizedBox(height: 20),
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading...'),
            ],
          ),
        ),
      );
    }

    if (auth.status == AuthStatus.unauthenticated) {
      return const LoginScreen();
    }

    // ── GPS consent gate for driver/technician roles ──────────────
    // Admin and scheduler bypass consent entirely.
    if (auth.isTechnician) {
      final gps = context.watch<GpsProvider>();

      // Trigger consent check if not done yet — use microtask to
      // avoid calling async work directly during the build phase.
      if (!gps.consentChecked) {
        Future.microtask(() => gps.checkConsent());
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      // Consent not yet granted — show the POPIA consent screen.
      if (gps.needsConsent) {
        return const GpsConsentScreen();
      }

      // Consent resolved — start location timer if GPS is enabled
      // and the timer is not already running.
      if (gps.gpsEnabled && !gps.isTimerRunning) {
        Future.microtask(() => gps.startLocationTimer());
      }
    }

    return const MainApp();
  }
}

// ============================================
// MAIN APP — bottom navigation + "More" menu
//
// Tab layout per role:
//
//   admin      → Bottom: Dashboard | Jobs | Schedule | More
//                More:   Vehicles, Tracking, Users, Reports, Settings
//   scheduler  → Bottom: Dashboard | Jobs | Schedule | More
//                More:   Vehicles, Tracking
//   technician → Bottom: Dashboard | My Jobs
// ============================================
class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    final tabs = _buildTabsForRole(auth);
    final navItems = _buildNavItemsForRole(auth);

    final safeIndex = _currentIndex < tabs.length ? _currentIndex : 0;

    return Scaffold(
      body: IndexedStack(index: safeIndex, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: safeIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.textSecondary,
        type: BottomNavigationBarType.fixed,
        items: navItems,
      ),
      floatingActionButton: _buildFab(auth, safeIndex),
    );
  }

  // ==========================================
  // TABS
  // ==========================================
  List<Widget> _buildTabsForRole(AuthProvider auth) {
    if (auth.isTechnician) {
      return [const DashboardScreen(), const JobsListScreen()];
    }

    // Admin & Scheduler: Dashboard | Jobs | Schedule | More
    return [
      const DashboardScreen(),
      const JobsListScreen(),
      const SchedulerScreen(),
      _MoreMenuScreen(isAdmin: auth.isAdmin),
    ];
  }

  // ==========================================
  // NAV ITEMS
  // ==========================================
  List<BottomNavigationBarItem> _buildNavItemsForRole(AuthProvider auth) {
    if (auth.isTechnician) {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.work_outline),
          activeIcon: Icon(Icons.work),
          label: 'My Jobs',
        ),
      ];
    }

    // Admin & Scheduler
    return const [
      BottomNavigationBarItem(
        icon: Icon(Icons.dashboard_outlined),
        activeIcon: Icon(Icons.dashboard),
        label: 'Dashboard',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.work_outline),
        activeIcon: Icon(Icons.work),
        label: 'Jobs',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.calendar_today_outlined),
        activeIcon: Icon(Icons.calendar_today),
        label: 'Schedule',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.menu_outlined),
        activeIcon: Icon(Icons.menu),
        label: 'More',
      ),
    ];
  }

  // ==========================================
  // FAB
  // Jobs tab (index 1) for admin/scheduler → New Job
  // Technician                             → no FAB
  // ==========================================
  Widget? _buildFab(AuthProvider auth, int currentIndex) {
    if (auth.isTechnician) return null;
    if (currentIndex == 1 && auth.hasPermission('jobs:create')) {
      return FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateJobScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New Job'),
        backgroundColor: AppTheme.primaryColor,
      );
    }
    return null;
  }
}

// ============================================
// MORE MENU — clean grid of navigation items
// ============================================
class _MoreMenuScreen extends StatelessWidget {
  final bool isAdmin;

  const _MoreMenuScreen({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final items = <_MoreMenuItem>[
      _MoreMenuItem(
        icon: Icons.local_shipping,
        label: 'Vehicles',
        color: const Color(0xFF43A047),
        screen: const VehiclesListScreen(),
      ),
      _MoreMenuItem(
        icon: Icons.map,
        label: 'Live Tracking',
        color: const Color(0xFF1E88E5),
        screen: const LiveTrackingScreen(),
      ),
      if (isAdmin) ...[
        _MoreMenuItem(
          icon: Icons.people,
          label: 'Users',
          color: const Color(0xFF8E24AA),
          screen: const UsersScreen(),
        ),
        _MoreMenuItem(
          icon: Icons.bar_chart,
          label: 'Reports',
          color: const Color(0xFFE65100),
          screen: const ReportsScreen(),
        ),
        _MoreMenuItem(
          icon: Icons.download,
          label: 'Export Data',
          color: const Color(0xFF00838F),
          screen: const DataExportScreen(),
        ),
        _MoreMenuItem(
          icon: Icons.settings,
          label: 'Settings',
          color: const Color(0xFF546E7A),
          screen: const AdminSettingsScreen(),
        ),
      ],
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: item.color, size: 24),
            ),
            title: Text(
              item.label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: AppTheme.textHint,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => item.screen),
            ),
          );
        },
      ),
    );
  }
}

class _MoreMenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final Widget screen;

  const _MoreMenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.screen,
  });
}
