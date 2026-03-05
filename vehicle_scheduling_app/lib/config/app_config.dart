// ============================================
// FILE: lib/config/app_config.dart
// PURPOSE: App-wide configuration and API settings
//
// HOW ENDPOINTS WORK:
//   baseUrl  = 'http://172.16.100.56:3000/api'
//   endpoint = '/vehicles'
//   ApiService builds full URL = baseUrl + endpoint
//                              = 'http://172.16.100.56:3000/api/vehicles'
//
// NEVER bake the full URL into an endpoint constant.
// Endpoints must always be a short relative path like '/jobs'
// ============================================

class AppConfig {
  // ==========================================
  // BASE URLs - one per environment
  // ==========================================

  // Chrome / Web browser
  static const String baseUrlWeb = 'http://localhost:3000/api';

  // Android Emulator (10.0.2.2 maps to your PC localhost)
  static const String baseUrlAndroid = 'http://10.0.2.2:3000/api';

  // Real Android device on same WiFi
  static const String baseUrlDevice =
      'http://172.16.100.56:3000/api'; //for local
  //static const String baseUrlDevice ='http://3.231.191.15:8080/api'; //foe aws instance

  // ==========================================
  // ACTIVE BASE URL
  // ✅ Pointing to real device on WiFi
  // ==========================================
  static String get baseUrl => baseUrlDevice;

  // ==========================================
  // API ENDPOINTS
  // Short relative paths ONLY - no full URLs here
  // ApiService prepends baseUrl automatically
  // ==========================================

  // GET  /api/health
  static const String healthEndpoint = '/health';

  // GET  /api/vehicles
  // GET  /api/vehicles/:id
  // POST /api/vehicles        (admin)
  // PUT  /api/vehicles/:id    (admin)
  // DELETE /api/vehicles/:id  (admin)
  static const String vehiclesEndpoint = '/vehicles';

  // GET  /api/jobs
  // GET  /api/jobs/:id
  // POST /api/jobs
  static const String jobsEndpoint = '/jobs';

  // POST /api/job-assignments/assign
  // POST /api/job-assignments/unassign
  // GET  /api/job-assignments/vehicle/:id
  static const String assignmentsEndpoint = '/job-assignments';

  // POST /api/job-status/update
  // GET  /api/job-status/history/:job_id
  // GET  /api/job-status/allowed-transitions/:job_id
  static const String statusEndpoint = '/job-status';

  // GET  /api/dashboard/summary
  // GET  /api/dashboard/stats
  static const String dashboardEndpoint = '/dashboard';

  // GET  /api/reports/jobs-per-vehicle
  // GET  /api/reports/utilization
  // GET  /api/reports/quick-stats
  static const String reportsEndpoint = '/reports';

  // GET    /api/users               (admin + scheduler)
  // GET    /api/users/:id           (admin + scheduler)
  // POST   /api/users               (admin)
  // PUT    /api/users/:id           (admin)
  // DELETE /api/users/:id           (admin)
  // POST   /api/users/:id/reset-password (admin)
  static const String usersEndpoint = '/users'; // ← NEW

  // GET  /api/availability/drivers?date=&start_time=&end_time=&exclude_job_id=
  // GET  /api/availability/vehicles?date=&start_time=&end_time=
  // POST /api/availability/check-drivers { technician_ids, date, start_time, end_time }
  static const String availabilityEndpoint = '/availability'; // ← NEW

  // ==========================================
  // HTTP TIMEOUT
  // ==========================================
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ==========================================
  // APP INFO
  // ==========================================
  static const String appName = 'Vehicle Scheduling';
  static const String appVersion = '1.0.0';

  // ==========================================
  // DEFAULT USER ID
  // ==========================================
  static const int defaultUserId = 1;
}
