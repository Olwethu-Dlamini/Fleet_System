# Testing Patterns

**Analysis Date:** 2026-03-21

## Test Framework

**Runner:**
- Framework: None configured
- `package.json` shows: `"test": "echo \"Error: no test specified\" && exit 1"`
- Tests are not set up or executed in this project

**Assertion Library:**
- Not applicable - no testing framework installed

**Run Commands:**
Currently testing is not configured. To run tests once set up:
```bash
npm test                           # Run all tests (when configured)
npm run test:watch                # Watch mode (when configured)
npm run test:coverage             # Coverage report (when configured)
```

**Dart/Flutter Testing:**
- Flutter has built-in test framework via `flutter_test` package (in devDependencies)
- No test files detected in the codebase
- Tests could be run with: `flutter test` or `dart test`

## Test File Organization

**Location:**
- Backend: No test files found
- Frontend: No test files found
- Proposed: Tests should be co-located with source
  - JavaScript: `src/models/__tests__/Job.test.js` alongside `src/models/Job.js`
  - Dart: `test/services/job_service_test.dart` in project root `test/` directory

**Naming:**
- JavaScript: `[module].test.js` or `[module].spec.js` convention
- Dart: `[module]_test.dart` convention

**Structure:**
```
vehicle-scheduling-backend/
├── src/
│   ├── models/
│   │   ├── Job.js
│   │   └── __tests__/
│   │       └── Job.test.js
│   ├── services/
│   │   ├── jobAssignmentService.js
│   │   └── __tests__/
│   │       └── jobAssignmentService.test.js
│   └── routes/
│       ├── jobs.js
│       └── __tests__/
│           └── jobs.integration.test.js

vehicle_scheduling_app/
└── test/
    ├── models/
    │   └── job_test.dart
    ├── services/
    │   └── job_service_test.dart
    └── providers/
        └── job_provider_test.dart
```

## Test Structure

**Recommended Suite Organization:**

JavaScript (Jest/Vitest pattern):
```javascript
describe('Job Model', () => {
  describe('createJob', () => {
    it('should create a job with valid data', async () => {
      // arrange
      const jobData = { ... };

      // act
      const result = await Job.createJob(jobData);

      // assert
      expect(result).toHaveProperty('id');
      expect(result.job_number).toMatch(/^JOB-\d{4}-\d{4}$/);
    });

    it('should throw error when creator user does not exist', async () => {
      const jobData = { created_by: 99999, ... };

      await expect(Job.createJob(jobData))
        .rejects
        .toThrow('Invalid user ID - creator does not exist');
    });
  });

  describe('getJobById', () => {
    it('should return null for non-existent job', async () => {
      const job = await Job.getJobById(99999);
      expect(job).toBeNull();
    });

    it('should parse technicians_json correctly', async () => {
      const job = await Job.getJobById(1);
      expect(job.technicians_json).toBeInstanceOf(Array);
      expect(job.technicians_json[0]).toHaveProperty('id');
      expect(job.technicians_json[0]).toHaveProperty('full_name');
    });
  });
});
```

Dart (Flutter test pattern):
```dart
void main() {
  group('JobProvider', () => {
    late JobProvider provider;

    setUp(() {
      provider = JobProvider();
    });

    test('loadJobs sets status to loading then success', () async {
      expect(provider.isLoading, false);

      // Trigger load
      provider.loadJobs();

      // Should be loading
      expect(provider.isLoading, true);

      // Wait for completion
      await Future.delayed(Duration(milliseconds: 100));

      // Should have completed
      expect(provider.status, JobStatus.success);
    });

    test('error state is set on API failure', () async {
      // Mock service to fail
      provider.loadJobs();
      await Future.delayed(Duration(milliseconds: 100));

      expect(provider.status, JobStatus.error);
      expect(provider.error, isNotNull);
    });
  });
}
```

**Patterns Observed in Codebase:**

1. **Arrange-Act-Assert (AAA):**
   - Setup test data (arrange)
   - Call function under test (act)
   - Verify results (assert)

2. **Error Path Testing:**
   - Code explicitly checks for error conditions
   - Tests should verify error messages match exactly
   - Example from Job.js: "Cannot assign job with status X" — test must check this exact message

3. **State Transitions:**
   - Services manage state machines (JobStatus: idle → loading → success/error)
   - Tests should verify state transitions in order

## Mocking

**Framework:** None configured (would use Jest for JavaScript, mockito or Mocktail for Dart)

**Patterns (Recommended):**

JavaScript (with Jest):
```javascript
// Mock database
jest.mock('../config/database');
const db = require('../config/database');

db.query.mockResolvedValue([
  [{ id: 1, job_number: 'JOB-2026-0001', ... }],
  []
]);

// Mock services
jest.mock('../services/jobAssignmentService');
const JobAssignmentService = require('../services/jobAssignmentService');

JobAssignmentService.assignJobToVehicle.mockResolvedValue({
  success: true,
  assignment_id: 10
});
```

Dart (with Mocktail):
```dart
import 'package:mocktail/mocktail.dart';

class MockJobService extends Mock implements JobService {}
class MockApiService extends Mock implements ApiService {}

void main() {
  late MockJobService mockJobService;
  late JobProvider provider;

  setUp(() {
    mockJobService = MockJobService();
    provider = JobProvider();
    provider._jobService = mockJobService;
  });

  test('loadJobs calls JobService.getAllJobs', () async {
    when(() => mockJobService.getAllJobs())
      .thenAnswer((_) async => [testJob1, testJob2]);

    await provider.loadJobs();

    verify(() => mockJobService.getAllJobs()).called(1);
  });
}
```

**What to Mock:**
- External services (database, API calls, third-party services)
- Dependencies injected into service under test
- Time-dependent behavior (use fake timer/scheduler)
- Random number generators

**What NOT to Mock:**
- Internal helper functions of the class under test
- Value objects and data classes
- Standard library functions (unless truly necessary)
- The implementation being tested (test the real code path)

## Fixtures and Factories

**Test Data (Recommended):**

JavaScript fixtures in `test/fixtures/jobs.js`:
```javascript
module.exports = {
  createValidJobData: () => ({
    customer_name: 'John Doe',
    customer_phone: '555-1234',
    customer_address: '123 Main St',
    destination_lat: 40.7128,
    destination_lng: -74.0060,
    job_type: 'installation',
    description: 'Install new equipment',
    scheduled_date: '2026-03-25',
    scheduled_time_start: '09:00:00',
    scheduled_time_end: '11:00:00',
    estimated_duration_minutes: 120,
    priority: 'normal',
    created_by: 1,
    technician_ids: [2, 3]
  }),

  createJobWithStatus: (status) => ({
    ...createValidJobData(),
    current_status: status
  }),

  createConflictingJob: () => ({
    ...createValidJobData(),
    scheduled_date: '2026-03-25',
    scheduled_time_start: '10:00:00', // Overlaps
    scheduled_time_end: '12:00:00'
  })
};
```

Dart fixtures in `test/fixtures/job_fixtures.dart`:
```dart
final testJob1 = Job(
  id: 1,
  jobNumber: 'JOB-2026-0001',
  jobType: 'installation',
  customerName: 'John Doe',
  customerPhone: '555-1234',
  customerAddress: '123 Main St',
  destinationLat: 40.7128,
  destinationLng: -74.0060,
  description: 'Install new equipment',
  scheduledDate: DateTime(2026, 3, 25),
  scheduledTimeStart: '09:00:00',
  scheduledTimeEnd: '11:00:00',
  estimatedDurationMinutes: 120,
  currentStatus: 'pending',
  priority: 'normal',
  createdBy: 1,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  technicians: [
    JobTechnician(id: 2, fullName: 'Alice'),
    JobTechnician(id: 3, fullName: 'Bob'),
  ],
);

final testJob2 = testJob1.copyWith(
  id: 2,
  jobNumber: 'JOB-2026-0002',
  currentStatus: 'assigned',
);
```

**Location:**
- JavaScript: `test/fixtures/[domain].js` (job fixtures, vehicle fixtures, user fixtures)
- Dart: `test/fixtures/[domain]_fixtures.dart`

## Coverage

**Requirements:** None enforced currently

**Recommended Coverage Targets:**
- Unit tests: 80% coverage for business logic
- Integration tests: Key user flows (create job → assign → update status)
- E2E tests: Critical paths only (create job and view results)

**View Coverage (Once Configured):**

JavaScript (Jest):
```bash
npm run test:coverage
# View coverage in: coverage/lcov-report/index.html
```

Dart (Flutter):
```bash
flutter test --coverage
# View coverage in: coverage/lcov.info
```

## Test Types

**Unit Tests:**
- **Scope:** Individual functions/methods in isolation
- **Approach:** Mock all external dependencies (database, services)
- **Examples to write:**
  - `Job._formatDateOnly()` handles Date objects, plain strings, null values
  - `Job._parseTechnicians()` converts GROUP_CONCAT format to array
  - `AuthController._normaliseRole()` maps legacy roles to current names
  - `JobService._parseJobList()` handles null, empty, and valid JSON arrays
  - Validation functions reject invalid inputs and accept valid ones

**Integration Tests:**
- **Scope:** Multiple modules working together (Model + Service, or Service + Database)
- **Approach:** Use real database connection (test DB) or advanced mocking
- **Examples to write:**
  - Create job → verify job appears in getAllJobs
  - Create job → assign technicians → verify technicians_json populated
  - Assign technician → remove from conflicting job → verify removed from first job
  - Update job status → verify status persists through getJobById
  - Role-based access control: admin can delete, technician cannot

**E2E Tests:**
- **Scope:** Full user workflow through HTTP API
- **Approach:** Real server, real database (test instance), client library
- **Examples to write:**
  - POST /api/auth/login → returns valid JWT
  - GET /api/jobs (with JWT) → returns correct jobs for role
  - POST /api/jobs → PUT /api/job-assignments/:id/technicians → GET /api/jobs/:id → verify technicians assigned
  - Unauthenticated requests return 401
  - Unauthorized role requests return 403

## Common Patterns

**Async Testing:**

JavaScript (Jest):
```javascript
it('should wait for async operation', async () => {
  const result = await Job.createJob(validData);
  expect(result.id).toBeDefined();
});

// Or with done callback (deprecated but may see):
it('completes', (done) => {
  Job.createJob(validData).then(result => {
    expect(result.id).toBeDefined();
    done();
  });
});
```

Dart (Flutter):
```dart
test('async operation completes', () async {
  final job = await jobService.createJob(...);
  expect(job.id, isNotNull);
});

// With timeout
test('operation completes within timeout', () async {
  final result = await jobService.createJob(...)
    .timeout(Duration(seconds: 5));
  expect(result.id, isNotNull);
}, timeout: Timeout(Duration(seconds: 10)));
```

**Error Testing:**

JavaScript (Jest):
```javascript
it('throws specific error for duplicate entry', async () => {
  // Set up duplicate scenario
  await Job.createJob(data1);

  // Second call with same unique field should fail
  await expect(Job.createJob(data1))
    .rejects
    .toThrow('Job number already exists');
});

it('catches MySQL error and re-throws', async () => {
  db.query.mockRejectedValue({
    code: 'ER_NO_REFERENCED_ROW_2',
    message: 'Foreign key constraint fails'
  });

  await expect(Job.createJob(invalidData))
    .rejects
    .toThrow('Invalid user ID - creator does not exist');
});
```

Dart (Flutter):
```dart
test('throws error on invalid input', () async {
  expect(
    () => Job.fromJson({'id': 'not-a-number'}),
    returnsNormally, // Job handles gracefully
  );
});

test('error message is preserved in provider', () async {
  // Mock service to throw
  when(() => mockJobService.getAllJobs())
    .thenThrow(Exception('Network error'));

  await provider.loadJobs();

  expect(provider.error, contains('Network error'));
  expect(provider.status, JobStatus.error);
});
```

**State Transitions (Providers):**

Dart:
```dart
test('status transitions through load cycle', () async {
  expect(provider.status, JobStatus.idle);

  final future = provider.loadJobs();
  // Note: immediately after call but before await
  expect(provider.status, JobStatus.loading);

  await future;
  expect(provider.status, JobStatus.success);
});
```

**Date/Time Testing:**

JavaScript:
```javascript
it('formats dates without timezone shift', () => {
  // MySQL returns: Date object representing 2026-02-23
  const date = new Date('2026-02-23');
  const formatted = Job._formatDateOnly(date);

  // Must always be '2026-02-23', never shifted to 22nd
  expect(formatted).toBe('2026-02-23');
});

it('handles different date input formats', () => {
  expect(Job._formatDateOnly('2026-02-23')).toBe('2026-02-23');
  expect(Job._formatDateOnly(new Date('2026-02-23'))).toBe('2026-02-23');
  expect(Job._formatDateOnly(null)).toBe(null);
});
```

Dart:
```dart
test('parses date string to DateTime', () {
  final job = Job.fromJson({
    'scheduled_date': '2026-03-25',
    ...otherFields
  });

  expect(job.scheduledDate.year, 2026);
  expect(job.scheduledDate.month, 3);
  expect(job.scheduledDate.day, 25);
});
```

---

*Testing analysis: 2026-03-21*

**Note:** This codebase currently has no test files or test framework configured. These patterns are derived from industry best practices and the structure visible in the source code (clear separation of concerns, explicit error handling, state management) which indicates the code is structured to be testable.
