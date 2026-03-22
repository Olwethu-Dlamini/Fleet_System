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
//
// HOW TO SWITCH ENVIRONMENTS:
// - Set `useLocal = true`  → uses localhost (local dev)
// - Set `useLocal = false` → uses AWS EC2 (production)
// ============================================

import 'package:flutter/foundation.dart';

class AppConfig {
  // ==========================================
  // 🔧 ENVIRONMENT SWITCH (change this only)
  // ==========================================
  static const bool useLocal = true; // true = local dev | false = AWS

  // ==========================================
  // BASE URLs (per environment)
  // ==========================================

  // Local Web / Browser
  static const String baseUrlWeb = 'http://localhost:3000/api';

  // Local Android Emulator
  static const String baseUrlAndroid = 'http://10.0.2.2:3000/api';

  // AWS EC2 (Docker exposes port 8080 → internal 3000)
  static const String baseUrlAWS = 'http://3.231.191.15:8080/api';

  // ==========================================
  // ACTIVE BASE URL (AUTO SELECT)
  // ==========================================
  static String get baseUrl {
    // ── LOCAL DEV MODE ──────────────────────
    if (useLocal) {
      if (kIsWeb) {
        return baseUrlWeb;      // Browser → localhost:3000
      }
      return baseUrlAndroid;    // Emulator → 10.0.2.2:3000
    }

    // ── PRODUCTION MODE (AWS) ───────────────
    return baseUrlAWS;          // All platforms → EC2:8080
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
  // GET /api/dashboard/chart-data
  static const String dashboardEndpoint = '/dashboard';

  // GET /api/dashboard/chart-data
  static String get dashboardChartEndpoint => '$dashboardEndpoint/chart-data';

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

  // VEHICLE MAINTENANCE
  // GET    /api/vehicle-maintenance?vehicle_id=X
  // GET    /api/vehicle-maintenance/active
  // POST   /api/vehicle-maintenance
  // PUT    /api/vehicle-maintenance/:id
  // DELETE /api/vehicle-maintenance/:id
  static const String vehicleMaintenanceEndpoint = '/vehicle-maintenance';

  // SETTINGS
  // GET /api/settings
  // GET /api/settings/:key
  // PUT /api/settings/:key
  static const String settingsEndpoint = '/settings';

  // TIME EXTENSIONS
  // POST  /api/time-extensions
  // GET   /api/time-extensions/:jobId
  // PATCH /api/time-extensions/:id/approve
  // PATCH /api/time-extensions/:id/deny
  static const String timeExtensionsEndpoint = '/time-extensions';

  // GPS
  // GET  /api/gps/directions?job_id=X&origin_lat=Y&origin_lng=Z
  // POST /api/gps/location
  // GET  /api/gps/consent
  // POST /api/gps/consent
  // PUT  /api/gps/consent
  // GET  /api/gps/drivers
  static const String gpsEndpoint = '/gps';
  static String get gpsDirectionsEndpoint => '$gpsEndpoint/directions';
  static String get gpsLocationEndpoint    => '$gpsEndpoint/location';
  static String get gpsConsentEndpoint     => '$gpsEndpoint/consent';
  static String get gpsDriversEndpoint     => '$gpsEndpoint/drivers';

  // WebSocket URL (Socket.IO) — matches backend listening port
  static String get wsUrl {
    if (useLocal) {
      if (kIsWeb) return 'http://localhost:3000';
      return 'http://10.0.2.2:3000';
    }
    return 'http://3.231.191.15:8080';
  }

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