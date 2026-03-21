# Coding Conventions

**Analysis Date:** 2026-03-21

## Naming Patterns

**Files:**
- JavaScript backend: `camelCase` with `.js` extension (e.g., `authController.js`, `jobAssignmentService.js`)
- Dart/Flutter: `snake_case` with `.dart` extension (e.g., `job_service.dart`, `create_job_screen.dart`)
- Model classes: Capitalized singular nouns (e.g., `Job.js`, `Vehicle.js`)
- Service classes: Capitalized with `Service` suffix (e.g., `JobAssignmentService`, `VehicleAvailabilityService`)
- Configuration files: `camelCase` or `snake_case` (e.g., `database.js`, `app_config.dart`)

**Functions/Methods:**
- JavaScript: `camelCase` for function names, `snake_case` for SQL parameters
  - Private methods prefixed with underscore: `_normaliseRole()`, `_formatDateOnly()`
  - Public static methods without underscore: `createJob()`, `getJobById()`
- Dart: `camelCase` for all methods and functions
  - Private methods prefixed with underscore: `_parseTechnicians()`, `_formatDate()`
  - Future/async functions use `async`/`await` keywords

**Variables:**
- JavaScript: `camelCase` for local variables, objects, and constants in code
  - Database fields use `snake_case` (e.g., `customer_name`, `scheduled_date`)
  - Environment variables use `UPPER_SNAKE_CASE` (e.g., `JWT_SECRET`, `PORT`)
- Dart: `camelCase` for all variables and instance members
  - Constants defined with `const` keyword
  - Nullable types marked with `?` (e.g., `String?`, `int?`)

**Types/Classes:**
- JavaScript: `PascalCase` for class names (e.g., `Job`, `AuthController`)
- Dart: `PascalCase` for classes and type names (e.g., `JobProvider`, `JobStatus`)
- Dart enums: `PascalCase` for enum names, `camelCase` for values (e.g., `enum JobStatus { idle, loading, success, error }`)

## Code Style

**Formatting:**
- JavaScript: No explicit formatter configured (Prettier not in devDependencies)
- Dart: Flutter built-in formatter via `dart format`
- 2-space indentation used throughout (JavaScript)
- 2-space indentation used throughout (Dart)
- Multi-line comments use `/* */` block format for file headers
- Single-line comments use `//` with space

**Linting:**
- JavaScript: No ESLint configuration detected in project
- Dart: `flutter_lints` v5.0.0 configured with analysis_options.yaml
- Manual code review and static analysis via IDE

**File Header Pattern:**
Every significant file starts with a header comment block:
```javascript
// ============================================
// FILE: src/models/Job.js
// PURPOSE: [What the file does]
// LAYER: [Layer designation like "Data Layer", "Service Layer"]
// ============================================
```

**Decorative Separators:**
- Section headers use `// ==========...` lines for visual separation
- Subsection headers use `// ──────...` for lighter separation
- Helps navigate large files visually

## Import Organization

**Order (JavaScript):**
1. Core Node.js modules (no imports needed)
2. Third-party dependencies (express, bcrypt, jwt, etc.)
3. Local config imports (database, constants)
4. Local models/services (relative imports with `require`)
5. Middleware (authMiddleware)

Example from `src/controllers/authController.js`:
```javascript
const db       = require('../config/database');
const bcrypt   = require('bcryptjs');
const jwt      = require('jsonwebtoken');
const { USER_ROLE } = require('../config/constants');
```

**Order (Dart/Flutter):**
1. Core Flutter/Dart imports (`package:flutter/...`)
2. Package imports (`package:provider/...`, `package:google_maps_flutter/...`)
3. Local imports (relative `package:vehicle_scheduling_app/...`)

Example from `lib/providers/job_provider.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vehicle_scheduling_app/models/job.dart';
import 'package:vehicle_scheduling_app/services/job_service.dart';
```

**Path Aliases:**
- No path aliases configured in either backend or frontend
- All imports are relative (`../`) or absolute package-based

## Error Handling

**JavaScript/Express:**
- All routes wrapped in try-catch blocks
- Errors logged to console with descriptive message: `console.error('Error in Job.createJob:', error);`
- Errors re-thrown after logging to propagate to global error handler
- Specific MySQL error codes checked: `error.code === 'ER_DUP_ENTRY'`, `'ER_NO_REFERENCED_ROW_2'`
- Global error handler at `app.use((err, req, res, next) => {...})` in `src/server.js`
- HTTP status codes explicitly set: `res.status(400).json()`, `res.status(401).json()`, etc.
- Error responses follow pattern: `{ success: false, message: '...', error: '...' }`

**Dart/Flutter:**
- Service methods use try-catch with `rethrow` to propagate errors to caller
- Console logging with `print()` for error messages: `print('JobService.getAllJobs error: $e');`
- Provider methods catch errors and set `_status = JobStatus.error` and `_error = e.toString()`
- Error messages passed through `_error` state variable to UI
- Toast notifications used for user-facing error display

**Transaction Error Handling (JavaScript):**
- Database transactions explicitly managed: `await conn.beginTransaction()` / `await conn.commit()` / `await conn.rollback()`
- Errors in transaction block trigger automatic `rollback()` in catch handler
- Connection always released in finally block: `conn.release()`

## Logging

**Framework:** `console` in JavaScript, `print()` in Dart (no dedicated logging library)

**Patterns:**

JavaScript:
- Informational: `console.log('✅ Database connection successful');`
- Errors: `console.error('Error in Job.createJob:', error);`
- Warnings: `console.warn('⚠️ Unknown permission key: "${permission}"');`
- Decorative progress logging in assignment flow: `console.log('═══════════════════════════════════════════════════════');`

Dart:
- Errors: `print('JobService.getAllJobs error: $e');`
- Debug info: `print('Job created successfully');`
- Uses string interpolation: `print('Job #$jobId created');`

**When to Log:**
- Errors: Always log with full context (`Error in [Function]: [message]`)
- Database operations: Log at start and completion of major operations
- Authentication: Log login attempts and token verification failures
- API transitions: Log step-by-step progress in multi-step operations (see `jobAssignmentService.js`)

## Comments

**When to Comment:**
- File headers: Mandatory for every source file (explain purpose and layer)
- Complex business logic: Comment the "why" not the "what"
- Database compatibility notes: Explain workarounds for specific DB versions (MySQL 5.6 vs 8.0)
- Breaking changes or fixes: Document BUG fixes with comments explaining the issue and solution
- Regex patterns: Document what regex validates (e.g., `PHONE_REGEX: /^[\d\s\-\+\(\)]+$/` for phone numbers)

**JSDoc/TSDoc:**
- Public methods documented with JSDoc blocks (see `src/models/Job.js` line 118-135)
- Parameter types documented: `@param {string} date - Date in 'YYYY-MM-DD' format`
- Return types documented: `@returns {Promise<Object>} Updated job object`
- Exception behavior documented: describes what errors might be thrown
- Not used on private methods (prefixed with `_`)

Example from `src/models/Job.js`:
```javascript
/**
 * Create a new job in the database
 *
 * @param {Object} jobData - Job information
 * @param {string} jobData.customer_name - Customer name
 * @returns {Promise<Object>} The newly created job with auto-generated fields
 */
```

**Dart Documentation:**
- Class documentation above class definition: `/// A lightweight model for a technician...`
- Method documentation above method signature
- Less formal than JavaScript JSDoc, more focused on intent

## Function Design

**Size:**
- Average function length 30-50 lines (small focused functions)
- Largest functions are complex query builders with explicit comments (e.g., `Job.getJobsByDate` is 57 lines due to SQL)
- Helper functions extracted for reuse: `_formatDateOnly()`, `_parseTechnicians()`, `_fixDates()`

**Parameters:**
- Maximum 5-6 parameters before using object destructuring
- Destructuring used extensively: `const { job_id, vehicle_id, driver_id = null, technician_ids = [] } = assignmentData;`
- Default values provided in destructuring for optional fields

**Return Values:**
- Explicit return type documentation in JSDoc
- `null` returned when resource not found (e.g., `Job.getJobById()` returns `null`)
- Arrays returned (never `undefined`) - empty array `[]` for "no results"
- Boolean status only in simple cases; object with `{ success, message }` preferred for complex operations

**Async/Await:**
- All database operations marked `async`
- Routes always use `async (req, res) => { ... }`
- Service methods marked `async` when calling database methods
- Errors propagate via thrown exceptions, not error callbacks

## Module Design

**Exports:**
- JavaScript: Single class export via `module.exports = ClassName` (one per file)
- Middleware files export multiple named exports: `module.exports = { verifyToken, requireRole, adminOnly }`
- Configuration files export single object: `module.exports = { ...constants }`
- Dart: Each file typically contains one or two related classes

**Barrel Files:**
- Not used in this codebase
- Each module imported directly from its file path
- No index.js re-exports for convenience

**Layer Separation:**
Clear 3-layer architecture with no circular dependencies:

1. **Models** (`src/models/`): Database operations only
   - One class per file (Job.js, Vehicle.js)
   - Static methods for all operations
   - No business logic, just SQL + response mapping

2. **Services** (`src/services/`): Business logic and orchestration
   - Calls models for data, adds validation/conflict checking
   - Coordinates between multiple models if needed
   - Returns processed data ready for API response

3. **Routes** (`src/routes/`): HTTP layer
   - Calls services to perform operations
   - Validates inputs and request format
   - Handles HTTP status codes and error responses
   - Extracts path parameters and query strings

**Controller Pattern (Partial):**
- `src/controllers/` exists but infrequently used
- Most logic is in Services, not Controllers
- Controllers (like `authController.js`) contain public static methods called from `src/server.js`

## Code Organization Patterns

**Defensive Programming:**
- Null checks on returned objects: `if (!job) { throw new Error(...) }`
- Array bounds checking: `if (rows.length === 0) { ... }`
- Explicit validation of IDs: `if (isNaN(jobId)) { return res.status(400)... }`
- Type coercion helpers: `_parseInt()`, `_parseDouble()` for safe type conversion in Dart

**Data Format Consistency:**
- Dates always formatted as `YYYY-MM-DD` strings before JSON response (see `Job._formatDateOnly()`)
- JavaScript Date objects converted to strings on server to prevent UTC timezone shifts
- Nullable fields explicitly typed in Dart (`String?`, `int?`)

**Configuration Centralization:**
- `src/config/constants.js` contains all enums and validation rules
- `src/config/database.js` exports single pool instance used everywhere
- `lib/config/app_config.dart` holds API endpoint URLs
- Environment variables loaded once at startup

## API Response Format

All success responses follow pattern:
```javascript
{
  success: true,
  [data_key]: [data],
  count: [optional array length]
}
```

All error responses follow pattern:
```javascript
{
  success: false,
  message: "User-friendly error message",
  error: "Technical error details (dev only)"
}
```

Status codes always explicit: 200, 400, 401, 403, 404, 409, 500

---

*Convention analysis: 2026-03-21*
