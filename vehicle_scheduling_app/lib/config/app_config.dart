// ============================================
// FILE: lib/config/app_config.dart
// PURPOSE: App-wide configuration and API settings
//
// HOW ENDPOINTS WORK:
//   baseUrl  = 'http://localhost:3000/api'
//   endpoint = '/vehicles'
//   ApiService builds full URL = baseUrl + endpoint
//                              = 'http://localhost:3000/api/vehicles'
//
// RULE:
// - NEVER bake full URLs into endpoints
// - Endpoints must ALWAYS be relative paths
// ============================================

import 'package:flutter/foundation.dart';

class AppConfig {
  // ==========================================
  // BASE URLs (per environment)
  // ==========================================

  // Web / Browser (PRIMARY for now)
  static const String baseUrlWeb = 'http://localhost:3000/api';

  // Android Emulator (kept for future use)
  static const String baseUrlAndroid = 'http://10.0.2.2:3000/api';

  // ==========================================
  // ❌ REAL DEVICE (TEMPORARILY DISABLED)
  // ==========================================
  // Reason:
  // - Not needed for Flutter Web
  // - Causes CORS / cross-origin issues in browser
  //
  // To re-enable later:
  // 1. Uncomment below
  // 2. Ensure backend allows external connections
  // 3. Ensure CORS is configured
  //
  // static const String baseUrlDevice =
  //     'http://172.16.100.56:3000/api';
  //
  // Alternative (AWS):
  // static const String baseUrlDevice =
  //     'http://3.231.191.15:8080/api';

  // ==========================================
  // ACTIVE BASE URL (AUTO SELECT)
  // ==========================================
  static String get baseUrl {
    // Web → use localhost
    if (kIsWeb) {
      return baseUrlWeb;
    }

    // Mobile → emulator (safe default)
    return baseUrlAndroid;
  }

  // ==========================================
  // API ENDPOINTS
  // (RELATIVE PATHS ONLY)
  // ==========================================

  // GET  /api/health
  static const String healthEndpoint = '/health';

  // VEHICLES
  // GET    /api/vehicles
  // GET    /api/vehicles/:id
  // POST   /api/vehicles
  // PUT    /api/vehicles/:id
  // DELETE /api/vehicles/:id
  static const String vehiclesEndpoint = '/vehicles';

  // JOBS
  // GET  /api/jobs
  // GET  /api/jobs/:id
  // POST /api/jobs
  static const String jobsEndpoint = '/jobs';

  // JOB ASSIGNMENTS
  // POST /api/job-assignments/assign
  // POST /api/job-assignments/unassign
  // GET  /api/job-assignments/vehicle/:id
  static const String assignmentsEndpoint = '/job-assignments';

  // JOB STATUS
  // POST /api/job-status/update
  // GET  /api/job-status/history/:job_id
  // GET  /api/job-status/allowed-transitions/:job_id
  static const String statusEndpoint = '/job-status';

  // DASHBOARD
  // GET /api/dashboard/summary
  // GET /api/dashboard/stats
  static const String dashboardEndpoint = '/dashboard';

  // REPORTS
  // GET /api/reports/jobs-per-vehicle
  // GET /api/reports/utilization
  // GET /api/reports/quick-stats
  static const String reportsEndpoint = '/reports';

  // USERS
  // GET    /api/users
  // GET    /api/users/:id
  // POST   /api/users
  // PUT    /api/users/:id
  // DELETE /api/users/:id
  // POST   /api/users/:id/reset-password
  static const String usersEndpoint = '/users';

  // AVAILABILITY
  // GET  /api/availability/drivers
  // GET  /api/availability/vehicles
  // POST /api/availability/check-drivers
  static const String availabilityEndpoint = '/availability';

  // ==========================================
  // NETWORK CONFIG
  // ==========================================
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ==========================================
  // APP INFO
  // ==========================================
  static const String appName = 'Vehicle Scheduling';
  static const String appVersion = '1.0.0';

  // ==========================================
  // DEFAULT USER
  // ==========================================
  static const int defaultUserId = 1;
}