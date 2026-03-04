# 🤖 AI Handoff Prompt - Vehicle Scheduling Flutter Frontend

## PROJECT OVERVIEW
Building a Flutter (Web + Android) frontend for a Vehicle Scheduling System.
Backend is Node.js + Express + MySQL - fully complete and running.

---

## ✅ ALREADY BUILT - DO NOT REBUILD THESE

### Backend (Node.js - COMPLETE, running on http://localhost:3000)
All endpoints working. Do not touch backend.

### Flutter Files Already Built:
```
lib/
├── config/
│   ├── app_config.dart     ✅ DONE
│   └── theme.dart          ✅ DONE
├── models/
│   ├── vehicle.dart        ✅ DONE
│   ├── job.dart            ✅ DONE
│   └── user.dart           ✅ DONE
├── services/
│   ├── api_service.dart    ✅ DONE
│   ├── vehicle_service.dart ✅ DONE
│   ├── job_service.dart    ✅ DONE
│   └── auth_service.dart   ✅ DONE
├── providers/
│   └── auth_provider.dart  ✅ DONE
├── screens/
│   ├── login_screen.dart   ✅ DONE
│   └── dashboard/
│       └── dashboard_screen.dart ✅ DONE
└── main.dart               ✅ DONE (has AuthGate routing)
```

---

## ❌ WHAT NEEDS TO BE BUILT

### Priority 1 - Providers (build FIRST, screens depend on these)
```
lib/providers/job_provider.dart
lib/providers/vehicle_provider.dart
```

### Priority 2 - Reusable Widgets (build SECOND, screens use these)
```
lib/widgets/job/job_card.dart
lib/widgets/job/job_status_badge.dart
lib/widgets/vehicle/vehicle_card.dart
lib/widgets/common/loading_widget.dart
lib/widgets/common/error_widget.dart
lib/widgets/common/empty_state_widget.dart
```

### Priority 3 - Screens (build LAST)
```
lib/screens/jobs/jobs_list_screen.dart
lib/screens/jobs/job_detail_screen.dart
lib/screens/jobs/create_job_screen.dart
lib/screens/vehicles/vehicles_list_screen.dart
```

### Priority 4 - Update main.dart
Add bottom navigation bar with tabs:
- Dashboard (index 0)
- Jobs (index 1)
- Vehicles (index 2)

---

## STRICT RULES - MUST FOLLOW

### 1. Package Imports Only
```dart
// ✅ CORRECT
import 'package:vehicle_scheduling_app/config/app_config.dart';
import 'package:vehicle_scheduling_app/models/job.dart';

// ❌ WRONG - never use relative imports
import '../models/job.dart';
import '../../config/app_config.dart';
```

### 2. CardThemeData (not CardTheme)
```dart
// ✅ CORRECT
cardTheme: CardThemeData(elevation: 2)

// ❌ WRONG
cardTheme: CardTheme(elevation: 2)
```

### 3. No Screen Can Reference a File That Doesn't Exist Yet
Build in this order: providers → widgets → screens → main.dart

### 4. App Package Name
```
vehicle_scheduling_app
```
Used in all package imports.

### 5. StatefulWidget - Never Use const
```dart
// ✅ CORRECT
home: JobsListScreen()

// ❌ WRONG
home: const JobsListScreen()  // only valid for StatelessWidget
```

---

## BACKEND RESPONSE KEYS (EXACT - must match)

```javascript
GET  /api/vehicles        → { success: true, data: [...],   count: N }     // key = 'data'
GET  /api/vehicles/:id    → { success: true, data: {...} }                 // key = 'data'
GET  /api/jobs            → { success: true, jobs: [...],   count: N }     // key = 'jobs'
GET  /api/jobs/:id        → { success: true, job: {...} }                  // key = 'job'
POST /api/jobs            → { success: true, job: {...},    message: '' }  // key = 'job'
POST /api/auth/login      → { success: true, token: '',     user: {...} }
GET  /api/dashboard/summary → { success: true, data: { summary, todaysJobs, vehicleStatus } }
POST /api/job-assignments/assign → { success: true, message: '', data: {} }
POST /api/job-status/update      → { success: true, message: '', data: {} }
```

---

## APP CONFIG (AppConfig class)

```dart
AppConfig.baseUrl             = 'http://localhost:3000/api'
AppConfig.vehiclesEndpoint    = '/vehicles'
AppConfig.jobsEndpoint        = '/jobs'
AppConfig.assignmentsEndpoint = '/job-assignments'
AppConfig.statusEndpoint      = '/job-status'
AppConfig.dashboardEndpoint   = '/dashboard'
AppConfig.reportsEndpoint     = '/reports'
AppConfig.connectionTimeout   = Duration(seconds: 30)
AppConfig.defaultUserId       = 1
```

---

## THEME COLORS (AppTheme class)

```dart
AppTheme.primaryColor     // Blue #2196F3
AppTheme.successColor     // Green #4CAF50
AppTheme.errorColor       // Red #F44336
AppTheme.warningColor     // Amber #FFC107
AppTheme.backgroundColor  // #F5F5F5
AppTheme.textPrimary      // #212121
AppTheme.textSecondary    // #757575
AppTheme.textHint         // #9E9E9E
AppTheme.pendingColor     // Grey
AppTheme.assignedColor    // Blue
AppTheme.inProgressColor  // Orange
AppTheme.completedColor   // Green
AppTheme.cancelledColor   // Red

// Helper methods
AppTheme.getStatusColor(status)   // returns Color for job status
AppTheme.getJobTypeIcon(jobType)  // returns IconData for job type
AppTheme.getPriorityColor(p)      // returns Color for priority
```

---

## JOB MODEL FIELDS

```dart
job.id
job.jobNumber          // 'JOB-2024-0001'
job.jobType            // 'installation' | 'delivery' | 'maintenance'
job.customerName
job.customerPhone      // nullable
job.customerAddress
job.description        // nullable
job.scheduledDate      // DateTime
job.scheduledTimeStart // '09:00:00'
job.scheduledTimeEnd   // '12:00:00'
job.currentStatus      // 'pending'|'assigned'|'in_progress'|'completed'|'cancelled'
job.priority           // 'low'|'normal'|'high'|'urgent'
job.vehicleName        // nullable (from JOIN)
job.driverName         // nullable (from JOIN)

// Helper getters
job.statusDisplayName  // 'In Progress'
job.typeDisplayName    // 'Installation'
job.isAssigned         // bool
job.formattedDate      // 'Feb 17, 2026'
job.formattedTimeRange // '09:00 - 12:00'
```

---

## VEHICLE MODEL FIELDS

```dart
vehicle.id
vehicle.vehicleName    // 'Vehicle 1 - Delivery Van'
vehicle.licensePlate   // 'ABC-123'
vehicle.vehicleType    // 'van' | 'truck' | 'car'
vehicle.capacityKg     // nullable double
vehicle.isActive       // bool
vehicle.statusText     // 'Active' | 'Inactive'
vehicle.typeDisplayName // 'Van' | 'Truck' | 'Car'
```

---

## JOB STATUS FLOW

```
pending → assigned → in_progress → completed
                                 → cancelled
```

---

## AUTH PROVIDER (available via context.watch/read)

```dart
context.watch<AuthProvider>().user        // User object
context.watch<AuthProvider>().isAdmin     // bool
context.watch<AuthProvider>().isDispatcher // bool
context.watch<AuthProvider>().isDriver    // bool
context.read<AuthProvider>().logout()     // Future<void>
```

---

## PUBSPEC.yaml DEPENDENCIES (already installed)

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.1
  http: ^1.1.0
  shared_preferences: ^2.2.2
  intl: ^0.19.0
  flutter_spinkit: ^5.2.0
  fluttertoast: ^8.2.4
  table_calendar: ^3.0.9
  fl_chart: ^0.66.0
```

---

## DEBUGGING GUIDE

### Error: "Couldn't resolve package"
```bash
flutter pub add <package_name>
flutter pub get
```

### Error: "Not found: package:..."
Check import path matches exactly:
```dart
import 'package:vehicle_scheduling_app/...'
//                ^^^^^^^^^^^^^^^^^^^^^^
// Must match name in pubspec.yaml
```

### Error: "The method 'watch' isn't defined"
Missing provider import:
```dart
import 'package:provider/provider.dart';
```

### Error: "ClientException: Failed to fetch"
CORS issue. In backend server.js:
```javascript
app.use(cors({
  origin: /^http:\/\/localhost:\d+$/,  // allows all localhost ports
  credentials: true,
}));
```

### Error: "CardTheme" issues
Use CardThemeData not CardTheme:
```dart
cardTheme: CardThemeData(...)
```

### Error: "const" on StatefulWidget
Remove const:
```dart
// ❌ JobsListScreen()  is StatefulWidget
home: const JobsListScreen()

// ✅
home: JobsListScreen()
```

### API returns 404
1. Check backend is running: `npm run dev`
2. Check URL: `http://localhost:3000/api/...`
3. Check response key matches exactly (jobs vs data vs job)

### API returns wrong data / null
Always check exact key from backend:
```dart
// GET /api/jobs returns { jobs: [...] }  NOT { data: [...] }
final list = response['jobs'];  // ✅
final list = response['data'];  // ❌ null
```

### Flutter shows blank screen after login
Check AuthGate in main.dart is watching AuthProvider:
```dart
final auth = context.watch<AuthProvider>();  // watch not read
```

### Android emulator can't reach backend
Change in app_config.dart:
```dart
static String get baseUrl => baseUrlAndroid; // uses 10.0.2.2:3000
```

---

## BUILD ORDER (follow exactly)

```
Step 1: lib/providers/job_provider.dart
Step 2: lib/providers/vehicle_provider.dart
Step 3: lib/widgets/common/loading_widget.dart
Step 4: lib/widgets/common/error_widget.dart
Step 5: lib/widgets/common/empty_state_widget.dart
Step 6: lib/widgets/job/job_status_badge.dart
Step 7: lib/widgets/job/job_card.dart
Step 8: lib/widgets/vehicle/vehicle_card.dart
Step 9: lib/screens/vehicles/vehicles_list_screen.dart
Step 10: lib/screens/jobs/jobs_list_screen.dart
Step 11: lib/screens/jobs/job_detail_screen.dart
Step 12: lib/screens/jobs/create_job_screen.dart
Step 13: lib/main.dart (add bottom navigation)
```

---

## BOTTOM NAVIGATION STRUCTURE (for main.dart update)

```dart
BottomNavigationBar with 3 tabs:
  Tab 0: Dashboard  - icon: Icons.dashboard   - DashboardScreen()
  Tab 1: Jobs       - icon: Icons.work        - JobsListScreen()
  Tab 2: Vehicles   - icon: Icons.local_shipping - VehiclesListScreen()
```

---

## TESTING CREDENTIALS

```
admin       / Admin@123      (role: admin)
dispatcher1 / Dispatch@123   (role: dispatcher)
driver1     / Driver@123     (role: driver)
```

Backend URL: http://localhost:3000/api
