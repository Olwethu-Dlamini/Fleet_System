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
import 'package:vehicle_scheduling_app/screens/login_screen.dart';
import 'package:vehicle_scheduling_app/screens/dashboard/dashboard_screen.dart';
import 'package:vehicle_scheduling_app/screens/jobs/jobs_list_screen.dart';
import 'package:vehicle_scheduling_app/screens/jobs/create_job_screen.dart';
import 'package:vehicle_scheduling_app/screens/jobs/scheduler_screen.dart';
import 'package:vehicle_scheduling_app/screens/vehicles/vehicles_list_screen.dart';
import 'package:vehicle_scheduling_app/screens/users/users_screen.dart';
import 'package:vehicle_scheduling_app/screens/reports/reports_screen.dart'; // ← NEW
import 'package:vehicle_scheduling_app/screens/settings/admin_settings_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => JobProvider()),
        ChangeNotifierProvider(create: (_) => VehicleProvider()),
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

    return const MainApp();
  }
}

// ============================================
// MAIN APP — bottom navigation container
//
// Tab layout per role:
//
//   admin      → Dashboard | Jobs | Vehicles | Schedule | Users | Reports | Settings
//   scheduler  → Dashboard | Jobs | Vehicles | Schedule
//   technician → Dashboard | My Jobs
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

    if (auth.isAdmin) {
      return [
        const DashboardScreen(), // 0
        const JobsListScreen(), // 1
        const VehiclesListScreen(), // 2
        const SchedulerScreen(), // 3
        const UsersScreen(), // 4
        const ReportsScreen(), // 5
        if (auth.hasPermission('settings:read'))
          const AdminSettingsScreen(), // 6
      ];
    }

    // Scheduler
    return [
      const DashboardScreen(),
      const JobsListScreen(),
      const VehiclesListScreen(),
      const SchedulerScreen(),
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

    if (auth.isAdmin) {
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
          icon: Icon(Icons.local_shipping_outlined),
          activeIcon: Icon(Icons.local_shipping),
          label: 'Vehicles',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today_outlined),
          activeIcon: Icon(Icons.calendar_today),
          label: 'Schedule',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people_outline),
          activeIcon: Icon(Icons.people),
          label: 'Users',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_outlined),
          activeIcon: Icon(Icons.bar_chart),
          label: 'Reports',
        ),
        if (auth.hasPermission('settings:read'))
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
      ];
    }

    // Scheduler — no Users or Reports tab
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
        icon: Icon(Icons.local_shipping_outlined),
        activeIcon: Icon(Icons.local_shipping),
        label: 'Vehicles',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.calendar_today_outlined),
        activeIcon: Icon(Icons.calendar_today),
        label: 'Schedule',
      ),
    ];
  }

  // ==========================================
  // FAB
  // Jobs tab (index 1) for admin/scheduler → New Job
  // Schedule tab (index 3)                 → SchedulerScreen owns its own FAB
  // Users tab (index 4, admin)             → no FAB here; UsersScreen has its own
  // Reports tab (index 5, admin)           → no FAB
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
