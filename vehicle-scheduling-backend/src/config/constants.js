// ============================================
// FILE: src/config/constants.js
//
// CHANGES:
//   • Added USER_ROLE.DISPATCHER = 'dispatcher'
//   • Every permission that scheduler has is also granted to dispatcher
//     (the two roles are functionally identical — dispatcher is the correct
//     DB/display name, scheduler was the old name)
// ============================================

// ============================================
// Job Status Values
// ============================================
const JOB_STATUS = {
  PENDING    : 'pending',
  ASSIGNED   : 'assigned',
  IN_PROGRESS: 'in_progress',
  COMPLETED  : 'completed',
  CANCELLED  : 'cancelled',
};

// ============================================
// Job Types
// ============================================
const JOB_TYPE = {
  INSTALLATION: 'installation',
  DELIVERY    : 'delivery',
  MAINTENANCE : 'maintenance',
};

// ============================================
// Job Priority Levels
// ============================================
const JOB_PRIORITY = {
  LOW   : 'low',
  NORMAL: 'normal',
  HIGH  : 'high',
  URGENT: 'urgent',
};

// ============================================
// User Roles
// ============================================
// admin      → full system access
// dispatcher → manage jobs and assignments  (canonical name going forward)
// scheduler  → alias kept for backwards compatibility with existing DB rows
// technician → update job status only
// ============================================
const USER_ROLE = {
  ADMIN     : 'admin',
  DISPATCHER: 'dispatcher', // ← NEW  (the real role name stored in DB)
  SCHEDULER : 'scheduler',  //   kept so any old rows / JWTs still resolve
  TECHNICIAN: 'technician',
};

// ============================================
// Role Permissions Map
// dispatcher and scheduler are identical in every permission.
// admin is the only role that can manage vehicles or users.
// ============================================
const PERMISSIONS = {
  // ── Job permissions ──────────────────────────────────────────────────────
  'jobs:read'        : [USER_ROLE.ADMIN, USER_ROLE.DISPATCHER, USER_ROLE.SCHEDULER, USER_ROLE.TECHNICIAN],
  'jobs:create'      : [USER_ROLE.ADMIN, USER_ROLE.DISPATCHER, USER_ROLE.SCHEDULER],
  'jobs:update'      : [USER_ROLE.ADMIN, USER_ROLE.DISPATCHER, USER_ROLE.SCHEDULER],
  'jobs:delete'      : [USER_ROLE.ADMIN],
  'jobs:updateStatus': [USER_ROLE.ADMIN, USER_ROLE.DISPATCHER, USER_ROLE.SCHEDULER, USER_ROLE.TECHNICIAN],

  // ── Assignment permissions ────────────────────────────────────────────────
  'assignments:read'  : [USER_ROLE.ADMIN, USER_ROLE.DISPATCHER, USER_ROLE.SCHEDULER, USER_ROLE.TECHNICIAN],
  'assignments:create': [USER_ROLE.ADMIN, USER_ROLE.DISPATCHER, USER_ROLE.SCHEDULER],
  'assignments:update': [USER_ROLE.ADMIN, USER_ROLE.DISPATCHER, USER_ROLE.SCHEDULER],
  'assignments:delete': [USER_ROLE.ADMIN, USER_ROLE.DISPATCHER, USER_ROLE.SCHEDULER],

  // ── Vehicle permissions ───────────────────────────────────────────────────
  // dispatcher can VIEW vehicles but NOT add / edit / delete them
  'vehicles:read'  : [USER_ROLE.ADMIN, USER_ROLE.DISPATCHER, USER_ROLE.SCHEDULER, USER_ROLE.TECHNICIAN],
  'vehicles:create': [USER_ROLE.ADMIN],
  'vehicles:update': [USER_ROLE.ADMIN],
  'vehicles:delete': [USER_ROLE.ADMIN],

  // ── Dashboard / Reports ───────────────────────────────────────────────────
  'dashboard:read': [USER_ROLE.ADMIN, USER_ROLE.DISPATCHER, USER_ROLE.SCHEDULER, USER_ROLE.TECHNICIAN],
  'reports:read'  : [USER_ROLE.ADMIN, USER_ROLE.DISPATCHER, USER_ROLE.SCHEDULER],

  // ── User management ───────────────────────────────────────────────────────
  // admin only — dispatcher cannot manage users
  'users:read'  : [USER_ROLE.ADMIN],
  'users:create': [USER_ROLE.ADMIN],
  'users:update': [USER_ROLE.ADMIN],
  'users:delete': [USER_ROLE.ADMIN],
};

// ============================================
// Vehicle Types
// ============================================
const VEHICLE_TYPE = {
  VAN  : 'van',
  TRUCK: 'truck',
  CAR  : 'car',
};

// ============================================
// HTTP Status Codes
// ============================================
const HTTP_STATUS = {
  OK                   : 200,
  CREATED              : 201,
  BAD_REQUEST          : 400,
  UNAUTHORIZED         : 401,
  FORBIDDEN            : 403,
  NOT_FOUND            : 404,
  CONFLICT             : 409,
  INTERNAL_SERVER_ERROR: 500,
};

// ============================================
// Time Constants
// ============================================
const TIME_CONSTANTS = {
  MINUTES_PER_HOUR      : 60,
  HOURS_PER_DAY         : 24,
  BUFFER_TIME_MINUTES   : 30,
  MAX_JOB_DURATION_HOURS: 8,
};

// ============================================
// Validation Rules
// ============================================
const VALIDATION_RULES = {
  MIN_CUSTOMER_NAME_LENGTH: 2,
  MAX_CUSTOMER_NAME_LENGTH: 100,
  MIN_DESCRIPTION_LENGTH  : 5,
  MAX_DESCRIPTION_LENGTH  : 1000,
  PHONE_REGEX             : /^[\d\s\-\+\(\)]+$/,
  JOB_NUMBER_PREFIX       : 'JOB-',
};

// ============================================
// Error Messages
// ============================================
const ERROR_MESSAGES = {
  DATABASE_ERROR    : 'Database operation failed',
  VALIDATION_ERROR  : 'Invalid input data',
  NOT_FOUND         : 'Resource not found',
  ALREADY_EXISTS    : 'Resource already exists',
  DOUBLE_BOOKING    : 'Vehicle is already booked for this time slot',
  INVALID_TIME_RANGE: 'End time must be after start time',
  PAST_DATE         : 'Cannot schedule jobs in the past',
  VEHICLE_NOT_ACTIVE: 'Vehicle is not available (out of service)',
  UNAUTHORIZED      : 'You do not have permission to perform this action',
};

// ============================================
// Success Messages
// ============================================
const SUCCESS_MESSAGES = {
  JOB_CREATED    : 'Job created successfully',
  JOB_UPDATED    : 'Job updated successfully',
  JOB_DELETED    : 'Job deleted successfully',
  JOB_ASSIGNED   : 'Job assigned successfully',
  STATUS_CHANGED : 'Job status updated successfully',
  VEHICLE_CREATED: 'Vehicle created successfully',
  VEHICLE_UPDATED: 'Vehicle updated successfully',
};

module.exports = {
  JOB_STATUS,
  JOB_TYPE,
  JOB_PRIORITY,
  USER_ROLE,
  PERMISSIONS,
  VEHICLE_TYPE,
  HTTP_STATUS,
  TIME_CONSTANTS,
  VALIDATION_RULES,
  ERROR_MESSAGES,
  SUCCESS_MESSAGES,
};