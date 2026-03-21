# Coding Conventions

**Analysis Date:** 2026-03-21

## Backend (Node.js/Express)

### Naming Patterns

**Files:**
- Controllers: PascalCase + `Controller` suffix → `authController.js`
- Models: PascalCase → `Job.js`, `Vehicle.js`
- Services: camelCase + `Service` suffix → `jobAssignmentService.js`
- Routes: camelCase + plural nouns → `jobs.js`, `vehicles.js`
- Middleware: camelCase → `authMiddleware.js`
- Config: camelCase → `database.js`, `constants.js`

**Functions:**
- Controller/Service methods: camelCase → `login()`, `assignJobToVehicle()`, `getJobById()`
- Private/Helper methods: camelCase prefixed with underscore → `_normaliseRole()`, `_fixDates()`, `_parseTechnicians()`
- Async/await preferred throughout

**Variables:**
- camelCase for local variables: `jobId`, `vehicleId`, `technicianIds`
- UPPERCASE for constants: `JWT_SECRET`, `JWT_EXPIRES`, `PORT`
- Prefix with underscore for private class fields: `_formatDateOnly()`

**Types/Objects:**
- Database queries return destructured arrays: `const [rows] = await db.query()`
- Standard response envelope: `{ success: boolean, data?: object, error?: string }`
- Error objects include `.code` property for MySQL error handling

### Code Style

**Formatting:**
- 2-space indentation (observed throughout)
- No automatic formatter configured
- Comments use visual separators: `// ==========`, `// ──────`

**Linting:**
- Not configured (no .eslintrc found)
- No pre-commit hooks enforced
- Manual style consistency expected

### Import Organization

**Order:**
1. Core Node.js modules (`require('dotenv')`, `require('express')`)
2. Third-party packages (`require('cors')`, `require('bcryptjs')`)
3. Local imports (`require('./config/database')`, `require('./routes')`)

**Path Aliases:**
- Not used; relative paths are standard
- All imports are explicit relative paths: `require('../config/database')`

**Example from `src/server.js`:**
```javascript
require('dotenv').config();
const express = require('express');
const cors    = require('cors');
const bcrypt  = require('bcryptjs');
const jwt     = require('jsonwebtoken');

const db         = require('./config/database');
const routes     = require('./routes');
const swaggerUi  = require('swagger-ui-express');
```

### Error Handling

**Patterns:**
- Try-catch blocks for all async operations
- Specific error type checking for database errors: `error.code === 'ER_DUP_ENTRY'`
- Throw custom Error instances with descriptive messages
- Log errors to console before responding: `console.error('Error in Job.createJob:', error)`
- Never expose sensitive error details in production (check `NODE_ENV`)

**Response Format:**
```javascript
// Success
res.status(200).json({
  success: true,
  data: object,
  message: 'Optional message'
});

// Error
res.status(400).json({
  success: false,
  error: error.message,
  message: 'User-friendly message'
});
```

**Example from `src/models/Job.js` (createJob):**
```javascript
try {
  // ... operation ...
  return newJob;
} catch (error) {
  console.error('Error in Job.createJob:', error);

  if (error.code === 'ER_DUP_ENTRY') {
    throw new Error('Job number already exists (duplicate entry)');
  }
  if (error.code === 'ER_NO_REFERENCED_ROW_2') {
    throw new Error('Invalid user ID - creator does not exist');
  }
  throw error;
}
```

### Comments

**When to Comment:**
- Block separators for logical sections (visual clarity)
- Explain "why" not "what" (code already shows what it does)
- Document non-obvious transformations (e.g., timezone handling in Job model)
- Mark temporary fixes with reason: `// MySQL 5.6 does not have JSON_ARRAYAGG`
- Flag issues: `// ← NEW`, `// ← FIX`, `// ← TODO`

**Format:**
- Single-line comments for inline: `// comment`
- Section headers with visual separators:
  ```javascript
  // ==========================================
  // FUNCTION: createJob
  // PURPOSE: Insert a new job
  // RETURNS: Newly created job object
  // ==========================================
  ```

**JSDoc/TSDoc:**
- Used for public methods with `/**` blocks
- Includes `@param` and `@returns` for clarity
- Example from Job model:
  ```javascript
  /**
   * Create a new job in the database
   *
   * @param {Object} jobData - Job information
   * @param {string} jobData.customer_name - Customer name
   * @returns {Promise<Object>} The newly created job
   */
  ```

### Function Design

**Size:**
- Generally 50-200 lines (observed in Job.js model)
- Longer functions have clear subsections marked with comments
- Helper functions extracted for reusable logic

**Parameters:**
- Single objects preferred for multiple related parameters: `jobData` object passed instead of 5+ individual args
- Destructuring used in function signature: `const { username, password } = req.body`
- Optional params get default values: `statusFilter = null`, `excludeStatuses = []`

**Return Values:**
- Async functions always return Promises
- Null returned for "not found" cases: `return null`
- Objects returned with all fields populated (not partial)
- Models return raw database results, services/controllers apply formatting

**Example from Job model:**
```javascript
static async getJobById(id) {
  try {
    const sql = `SELECT ... WHERE j.id = ?`;
    const [rows] = await db.query(sql, [id]);
    const fixed = Job._parseTechnicians(Job._fixDates(rows));
    return fixed[0] || null;  // ← null if not found
  } catch (error) {
    console.error('Error in Job.getJobById:', error);
    throw error;  // ← propagate error
  }
}
```

### Module Design

**Exports:**
- Single class export per model file: `module.exports = Job;`
- Multiple exports from middleware: `module.exports = { verifyToken, requireRole, requirePermission };`
- Routes export router: `module.exports = router;`

**Barrel Files:**
- Not used; `routes/index.js` imports and re-exports route files
- No centralized barrel pattern for models or services

**File Structure - Backend:**
```
vehicle-scheduling-backend/
├── src/
│   ├── config/           # Configuration files (db, constants, swagger)
│   ├── controllers/      # Request handlers (legacy, mostly inline in routes)
│   ├── middleware/       # Express middleware (auth, validation)
│   ├── models/           # Database models (Job.js, Vehicle.js)
│   ├── routes/           # Express route definitions
│   ├── services/         # Business logic services
│   └── server.js         # Entry point
├── scripts/              # Utilities (seedPasswords.js)
├── package.json
└── .env
```

---

## Frontend (Flutter/Dart)

### Naming Patterns

**Files:**
- Screens: snake_case + `_screen` suffix → `create_job_screen.dart`, `job_detail_screen.dart`
- Models: snake_case → `job.dart`, `user.dart`, `vehicle.dart`
- Providers: snake_case + `_provider` suffix → `job_provider.dart`, `auth_provider.dart`
- Services: snake_case + `_service` suffix → `job_service.dart`, `user_service.dart`
- Widgets: snake_case in directory → `lib/widgets/common/location_picker_popup.dart`

**Classes:**
- PascalCase: `Job`, `JobTechnician`, `CreateJobScreen`, `JobProvider`
- Enums: PascalCase → `JobStatus` (with lowercase values: `idle`, `loading`, `success`)
- Private classes: prefix with underscore → `_CreateJobScreenState`, `_SummaryRow`

**Variables/Properties:**
- camelCase for all variables: `jobId`, `vehicleId`, `customerName`
- Private fields: prefix with underscore → `_selectedJob`, `_jobService`, `_formKey`
- Final constants: camelCase with `const` → `const minDuration = 15;`

### Code Style

**Formatting:**
- 2-space indentation (observed in pubspec.yaml and source files)
- Analysis options: `package:flutter_lints/flutter.yaml` enabled
- Comments can use `// ignore: lint_name` to suppress specific rules

**Linting:**
- Flutter lints configured via `analysis_options.yaml`
- Run with: `flutter analyze`
- Recommended rules enabled by default
- No custom rule overrides in codebase

### Import Organization

**Order:**
1. Dart core imports: `import 'package:flutter/material.dart';`
2. Package imports: `import 'package:provider/provider.dart';`
3. Relative imports: `import '../models/job.dart';`

**Package Paths:**
- Absolute paths used for local imports: `import 'package:vehicle_scheduling_app/models/job.dart';`
- Not relative paths like `import '../models/job.dart';`

**Example from CreateJobScreen:**
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_scheduling_app/config/app_config.dart';
import 'package:vehicle_scheduling_app/models/job.dart';
import 'package:vehicle_scheduling_app/providers/job_provider.dart';
```

### Error Handling

**Patterns:**
- Try-catch blocks for async operations
- Error messages displayed via `Fluttertoast.showToast()`
- Status enums track operation state: `JobStatus { idle, loading, success, error }`
- Null-safe optional fields: `Job? selectedJob`, `int? vehicleId`

**Response Handling:**
- Check success flag before using data: `if (response['success'] == true) { ... }`
- Store error in provider state: `_error = e.toString()`
- Notify listeners after error: `notifyListeners()`

**Example from JobProvider:**
```dart
Future<Job?> createJob({...}) async {
  _status = JobStatus.loading;
  _error = null;
  notifyListeners();

  try {
    final newJob = await _jobService.createJob(...);
    _status = JobStatus.success;
    return newJob;
  } catch (e) {
    _error = e.toString();
    _status = JobStatus.error;
    notifyListeners();
    return null;
  }
}
```

### Comments

**When to Comment:**
- Block headers explaining complex logic flows
- "Why" comments for non-obvious decisions
- Mark fixes and changes: `// FIX (Bug 1):`, `// NEW`, `// CHANGED`

**Format:**
- Block comments for sections:
  ```dart
  // ==========================================
  // FIX (Bug 1): Driver assignment now works...
  // ==========================================
  ```
- Inline comments for context: `// ← NEW`, `// ← for backwards-compat`

**Documentation:**
- JSDoc-style rarely used in Dart
- Prefer clear code over comments
- Comments explain design decisions, not implementation

### Function/Method Design

**Size:**
- Methods 30-100 lines typical
- Large methods broken into helper functions or state management chunks
- Build methods can be longer but usually factored out to smaller widgets

**Parameters:**
- Named parameters preferred: `method({required int id, String? filter})`
- Required parameters marked with `required`
- Optional parameters with defaults: `int limit = 10`

**Return Values:**
- Futures for async: `Future<Job?>`, `Future<void>`
- Nullable returns for optional results: `Job?`
- Future lists: `Future<List<Job>>`

**Null Safety:**
- Non-nullable by default: `int jobId`
- Nullable explicitly: `int? vehicleId`
- Null coalescing: `value ?? defaultValue`
- Bang operator only when certain: `value!`

**Example from JobProvider:**
```dart
Future<void> loadJobById(int id) async {  // ← Future<void> for side effects
  _status = JobStatus.loading;
  _error = null;
  notifyListeners();

  try {
    _selectedJob = await _jobService.getJobById(id);  // ← null safe assignment
    _status = JobStatus.success;
  } catch (e) {
    _error = e.toString();
    _status = JobStatus.error;
  }
  notifyListeners();
}
```

### Module Design

**Exports:**
- Single class per file: each screen, model, provider in own file
- Re-export common utilities from shared files
- No barrel files pattern used

**Providers Pattern:**
- Each feature has dedicated provider: `JobProvider`, `VehicleProvider`, `AuthProvider`
- ChangeNotifier for state management
- Getters expose immutable state: `List<Job> get jobs => _filteredJobs;`
- Private state with underscore prefix: `List<Job> _jobs = []`

**Widget Hierarchy:**
- Screens are StatefulWidget or Consumer wrappers
- Reusable components extracted to `lib/widgets/`
- Private state classes for StatefulWidgets: `_CreateJobScreenState`

**File Structure - Frontend:**
```
vehicle_scheduling_app/
├── lib/
│   ├── config/               # App configuration, theme
│   ├── models/               # Data models (job.dart, user.dart)
│   ├── providers/            # State management (job_provider.dart)
│   ├── screens/              # Full-page widgets
│   │   └── jobs/             # Job-related screens
│   ├── services/             # API calls (job_service.dart)
│   ├── widgets/
│   │   └── common/           # Reusable components
│   ├── main.dart             # Entry point
│   └── config/app_config.dart # API base URL, constants
├── assets/
│   ├── images/
│   └── icon/
├── pubspec.yaml
└── analysis_options.yaml
```

---

## Cross-Layer Patterns

### Data Flow

**Backend Request/Response:**
1. Route receives request + verifies token middleware
2. Controller/Service handles business logic
3. Model executes database operation
4. Response wrapped in standard envelope
5. HTTP status codes follow REST conventions

**Frontend Data Flow:**
1. Service makes HTTP call to backend
2. Provider receives result, updates state
3. Screen listens to provider changes
4. Widget rebuilds with new data

### Field Naming Alignment

**API vs Flutter:**
- Snake_case in API responses: `customer_name`, `scheduled_date`, `job_id`
- Converted to camelCase in Dart models: `customerName`, `scheduledDate`, `jobId`
- Safe converters handle both old and new field names for compatibility

**Example from Job model (Dart):**
```dart
factory JobTechnician.fromJson(Map<String, dynamic> json) {
  return JobTechnician(
    id: _parseInt(json['id']),
    fullName: (json['full_name'] ?? json['fullName'] ?? '').toString(),  // ← handles both
  );
}
```

### Database Timezone Handling

**Issue:** MySQL DATE columns shift by timezone when serialized to ISO format

**Solution in Backend (`src/models/Job.js`):**
```javascript
// Use LOCAL year/month/day — NOT getUTCFullYear — to preserve the date
const y   = d.getFullYear();
const m   = String(d.getMonth() + 1).padStart(2, '0');
const day = String(d.getDate()).padStart(2, '0');
return `${y}-${m}-${day}`;  // Always 'YYYY-MM-DD' format
```

**Applied on:** Every query that returns scheduled_date
- Model methods call `Job._fixDates()` before returning
- Result is plain string, never JavaScript Date object

---

*Convention analysis: 2026-03-21*
