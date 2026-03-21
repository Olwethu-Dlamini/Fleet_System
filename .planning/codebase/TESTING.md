# Testing Patterns

**Analysis Date:** 2026-03-21

## Backend Testing

### Test Framework

**Status:** Not Configured
- No test framework installed (Jest, Mocha, etc.)
- `package.json` script shows: `"test": "echo \"Error: no test specified\" && exit 1"`
- No test files present in repository (`*.test.js`, `*.spec.js`)

### Alternative Verification Methods

**Current Approach:**
- Manual HTTP testing via cURL or Postman
- Database state inspection via direct MySQL queries
- Inline console logging for debugging

**Swagger Documentation:**
- API routes documented in `src/config/swagger.js`
- Swagger UI accessible at `/swagger`
- Serves as live test/documentation interface

**Entry Point for Manual Testing:**
- `src/server.js` - starts Express server on PORT (default 3000)
- Prints startup messages with endpoints:
  ```
  📡 Server:  http://localhost:3000
  🔗 API:     http://localhost:3000/api
  🔐 Login:   POST http://localhost:3000/api/auth/login
  ```

**Database Testing Script:**
- `test-coonection-db.js` - manual connection test
- Seed script: `scripts/seedPasswords.js` - populate test data

### Recommended Testing Patterns (If Implemented)

**Unit Test Structure:**
```javascript
describe('Job Model', () => {
  describe('createJob', () => {
    it('should create a job with required fields', async () => {
      const jobData = {
        customer_name: 'John Doe',
        customer_address: '123 Main St',
        job_type: 'installation',
        scheduled_date: '2026-03-21',
        scheduled_time_start: '09:00:00',
        scheduled_time_end: '10:00:00',
        estimated_duration_minutes: 60,
        created_by: 1
      };

      const job = await Job.createJob(jobData);

      expect(job).toHaveProperty('id');
      expect(job.customer_name).toBe('John Doe');
      expect(job.current_status).toBe('pending');  // ← default status
    });

    it('should throw on duplicate job number', async () => {
      const jobData = { /* ... */ };

      await expect(Job.createJob(jobData)).rejects.toThrow('duplicate entry');
    });

    it('should handle date formatting correctly', async () => {
      const jobData = {
        // ...
        scheduled_date: '2026-02-23'
      };

      const job = await Job.createJob(jobData);
      expect(job.scheduled_date).toBe('2026-02-23');  // ← never shifted
    });
  });
});
```

**Integration Test Structure:**
```javascript
describe('Job Assignment Workflow', () => {
  let job, vehicle, driver;

  beforeAll(async () => {
    // Setup: create test fixtures
    job = await Job.createJob({...});
    vehicle = await Vehicle.getVehicleById(1);
    driver = await User.getUserById(1);
  });

  it('should assign vehicle to job', async () => {
    const assignment = await JobAssignmentService.assignJobToVehicle({
      job_id: job.id,
      vehicle_id: vehicle.id,
      driver_id: driver.id,
      assigned_by: 1
    });

    expect(assignment.success).toBe(true);
    const updated = await Job.getJobById(job.id);
    expect(updated.vehicle_id).toBe(vehicle.id);
    expect(updated.current_status).toBe('assigned');
  });

  it('should detect time conflicts', async () => {
    // Assign same vehicle to overlapping time
    const conflict = await JobAssignmentService.assignJobToVehicle({
      job_id: conflictingJob.id,
      vehicle_id: vehicle.id,
      assigned_by: 1
    });

    expect(conflict.success).toBe(false);
    expect(conflict.error).toMatch(/conflict/i);
  });

  afterAll(async () => {
    // Cleanup
    await db.query('DELETE FROM jobs WHERE id = ?', [job.id]);
  });
});
```

**Error Handling Tests:**
```javascript
describe('Error Handling', () => {
  it('should catch database errors gracefully', async () => {
    const invalidJob = await Job.createJob({
      customer_name: null,  // ← NOT NULL constraint
      // ...
    });

    expect(invalidJob).toBeNull();
    // OR
    // expect(() => Job.createJob(...)).rejects.toThrow();
  });

  it('should validate input before DB call', async () => {
    expect(() => {
      JobAssignmentService.assignJobToVehicle({
        job_id: null,  // ← required
        vehicle_id: 1
      });
    }).toThrow('job_id is required');
  });

  it('should handle permission denial', async () => {
    const technician = { role: 'technician' };
    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn()
    };

    requirePermission('vehicles:delete')(
      { user: technician },
      res,
      jest.fn()
    );

    expect(res.status).toHaveBeenCalledWith(403);
  });
});
```

**Mocking Patterns (If Implemented):**
```javascript
// Mock database layer
jest.mock('../config/database', () => ({
  query: jest.fn(),
  getConnection: jest.fn()
}));

// Mock external services
jest.mock('../services/vehicleAvailabilityService', () => ({
  checkVehicleAvailability: jest.fn().mockResolvedValue({
    isAvailable: true,
    conflicts: []
  })
}));

// Mock JWT verification
jest.mock('jsonwebtoken', () => ({
  sign: jest.fn().mockReturnValue('token'),
  verify: jest.fn().mockReturnValue({ id: 1, role: 'admin' })
}));
```

---

## Frontend Testing

### Test Framework

**Status:** Not Configured
- No test runner installed (Flutter Test, Mocktail, etc.)
- `pubspec.yaml` includes `flutter_test` SDK dependency (available, not used)
- No test files present in repository

### Alternative Verification Methods

**Hot Reload & Manual Testing:**
- `flutter run` with hot reload for rapid iteration
- Debug prints via `print()` and `debugPrint()`
- Flutter DevTools for performance/widget inspection

**State Inspection:**
- Provider state debuggable via DevTools
- Error messages displayed via Fluttertoast
- Status enums (`JobStatus`) show operation state in UI

### Recommended Testing Patterns (If Implemented)

**Widget Test Structure:**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_scheduling_app/models/job.dart';
import 'package:vehicle_scheduling_app/providers/job_provider.dart';
import 'package:vehicle_scheduling_app/screens/jobs/job_detail_screen.dart';

void main() {
  group('JobDetailScreen', () => {
    testWidgets('displays job details when loaded', (WidgetTester tester) async {
      final mockJob = Job(
        id: 1,
        jobNumber: 'JOB-2026-0001',
        jobType: 'installation',
        customerName: 'John Doe',
        customerAddress: '123 Main St',
        scheduledDate: DateTime(2026, 3, 21),
        scheduledTimeStart: '09:00:00',
        scheduledTimeEnd: '10:00:00',
        estimatedDurationMinutes: 60,
        currentStatus: 'pending',
        priority: 'normal',
        createdBy: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => JobProvider()..selectedJob = mockJob,
            ),
          ],
          child: const MaterialApp(
            home: JobDetailScreen(jobId: 1),
          ),
        ),
      );

      expect(find.text('JOB-2026-0001'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('pending'), findsOneWidget);
    });

    testWidgets('shows loading indicator while fetching', (WidgetTester tester) async {
      final jobProvider = JobProvider();
      // Simulate loading state
      jobProvider.loadJobById(1);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: jobProvider,
          child: const MaterialApp(
            home: Scaffold(body: CircularProgressIndicator()),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays error message on failure', (WidgetTester tester) async {
      final jobProvider = JobProvider();
      // Simulate error
      jobProvider._error = 'Failed to load job';
      jobProvider._status = JobStatus.error;

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: jobProvider,
          child: const MaterialApp(
            home: Scaffold(body: Text('Error loading job')),
          ),
        ),
      );

      expect(find.text('Error loading job'), findsOneWidget);
    });
  });
}
```

**Provider/Service Test Structure:**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vehicle_scheduling_app/models/job.dart';
import 'package:vehicle_scheduling_app/providers/job_provider.dart';
import 'package:vehicle_scheduling_app/services/job_service.dart';

class MockJobService extends Mock implements JobService {}

void main() {
  group('JobProvider', () => {
    late JobProvider jobProvider;
    late MockJobService mockJobService;

    setUp(() {
      mockJobService = MockJobService();
      jobProvider = JobProvider();
      // Replace internal service with mock
      jobProvider._jobService = mockJobService;
    });

    test('loadJobs sets status to loading initially', () async {
      when(() => mockJobService.getAllJobs()).thenAnswer(
        (_) async => []
      );

      final future = jobProvider.loadJobs();
      expect(jobProvider.isLoading, true);

      await future;
      expect(jobProvider.isLoading, false);
    });

    test('loadJobs populates jobs list on success', () async {
      final mockJobs = [
        Job(
          id: 1,
          jobNumber: 'JOB-2026-0001',
          // ... other required fields
        ),
      ];

      when(() => mockJobService.getAllJobs()).thenAnswer(
        (_) async => mockJobs
      );

      await jobProvider.loadJobs();

      expect(jobProvider.allJobs, equals(mockJobs));
      expect(jobProvider.status, JobStatus.success);
    });

    test('loadJobs stores error on failure', () async {
      const errorMsg = 'Network error';

      when(() => mockJobService.getAllJobs()).thenThrow(
        Exception(errorMsg)
      );

      await jobProvider.loadJobs();

      expect(jobProvider.status, JobStatus.error);
      expect(jobProvider.error, contains(errorMsg));
    });

    test('createJob returns Job? with correct ID', () async {
      final newJob = Job(
        id: 999,
        jobNumber: 'JOB-2026-0999',
        // ...
      );

      when(() => mockJobService.createJob(any())).thenAnswer(
        (_) async => newJob
      );

      final result = await jobProvider.createJob(
        customerName: 'Test Customer',
        // ... other params
      );

      expect(result, equals(newJob));
      expect(result?.id, equals(999));
    });

    test('assignTechnicians notifies listeners after success', () async {
      when(() => mockJobService.assignTechnicians(any(), any(), any()))
        .thenAnswer((_) async => true);

      expect(() async {
        await jobProvider.assignTechnicians(1, [2, 3], 1);
      }, anyOf(isNotEmpty));  // ← would trigger notifyListeners
    });
  });
}
```

**Error Scenario Testing:**
```dart
test('handles API connection error gracefully', () async {
  when(() => mockJobService.getAllJobs()).thenThrow(
    SocketException('Failed to connect')
  );

  await jobProvider.loadJobs();

  expect(jobProvider.status, JobStatus.error);
  expect(jobProvider.error, contains('Failed to connect'));
  expect(jobProvider.allJobs, isEmpty);  // ← state preserved
});

test('filters jobs by status correctly', () {
  jobProvider._jobs = [
    Job(currentStatus: 'pending', ...),
    Job(currentStatus: 'assigned', ...),
    Job(currentStatus: 'completed', ...),
  ];

  jobProvider._statusFilter = 'pending';

  expect(jobProvider.filteredJobs.length, 1);
  expect(jobProvider.filteredJobs[0].currentStatus, 'pending');
});
```

**Mocking Patterns (If Implemented):**
```dart
// Mock HTTP client
class MockHttpClient extends Mock implements http.Client {}

// Mock JobService
class MockJobService extends Mock implements JobService {}

// Mock Provider for widget tests
ChangeNotifierProvider.value(
  value: mockJobProvider,
  child: const MyWidget(),
)

// Mock shared_preferences
MockSharedPreferences mockSharedPrefs = MockSharedPreferences();
when(mockSharedPrefs.getString('auth_token'))
  .thenReturn('test-token');
```

---

## What to Test

### Backend Priority Areas

**Must Test:**
- `src/models/Job.js` - Data layer (create, read, update)
  - Date formatting (`_fixDates()`) - critical timezone bug area
  - Technician parsing (`_parseTechnicians()`) - GROUP_CONCAT handling
  - Query filtering and edge cases

- `src/middleware/authMiddleware.js` - Security
  - Token validation (valid, expired, malformed)
  - Role-based access control
  - Permission checking

- `src/services/jobAssignmentService.js` - Business logic
  - Conflict detection (vehicle time overlaps)
  - Driver availability checks
  - Transaction handling (atomicity)

**Should Test:**
- `src/routes/jobs.js` - API endpoints
  - Role-based filtering (technician vs admin)
  - Parameter validation
  - Response format consistency

**Could Test:**
- Error recovery paths
- Performance with large datasets
- Concurrent request handling

### Frontend Priority Areas

**Must Test:**
- `lib/providers/job_provider.dart` - State management
  - Status transitions (idle → loading → success/error)
  - Notifier behavior (listeners called at right time)
  - Null safety (Job?, error handling)
  - BUG FIX: createJob returns Job? not bool

- `lib/services/job_service.dart` - API integration
  - HTTP call success and error paths
  - Response parsing (JSON → Job objects)
  - Field mapping (snake_case → camelCase)
  - Null safety handling

- `lib/models/job.dart` - Data models
  - fromJson parsing (both old and new API formats)
  - Null coalescing for optional fields
  - Type conversion (string → int, etc.)

**Should Test:**
- `lib/screens/jobs/create_job_screen.dart` - Critical flow
  - Job creation (returns Job?)
  - Technician assignment after creation (separate call)
  - Form validation
  - Error display

- Widgets for interaction and layout

**Could Test:**
- Navigation flows
- Complex animations
- Theme switching

---

## Testing Challenges & Notes

### Backend

- **Database State:** Tests need real database or transaction rollback for isolation
- **Timezone Handling:** Tests must validate date format preservation (critical bug area)
- **Concurrency:** Difficult to test race conditions without load tooling
- **Async Patterns:** Proper await/promise handling essential

### Frontend

- **Provider State:** Must test both sync (getters) and async (Future) state changes
- **Navigation:** Flutter routing requires Navigator mocking
- **Permissions:** Location, camera features need platform-specific mocking
- **Null Safety:** Dart's strong null checking makes many bugs compile-time errors

---

## Quick Setup (If Implementing)

### Backend (Node.js)

```bash
npm install --save-dev jest @types/jest supertest

# Create jest.config.js
echo "module.exports = { testEnvironment: 'node' };" > jest.config.js

# Add to package.json
"test": "jest",
"test:watch": "jest --watch",
"test:coverage": "jest --coverage"
```

### Frontend (Flutter)

```bash
# Tests run built-in:
flutter test

# Watch mode:
flutter test --watch

# Coverage:
flutter test --coverage

# Install testing dependencies (if needed):
flutter pub add dev:mocktail
```

---

*Testing analysis: 2026-03-21*
