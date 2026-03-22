// ============================================
// FILE: src/services/gpsService.js
// PURPOSE: In-memory GPS location cache, Socket.IO broadcast,
//          tiered storage with cron flush, and consent management
// Requirements: GPS-02, GPS-03, GPS-04, GPS-06, GPS-07, GPS-08
// ============================================

const logger = require('../config/logger').child({ service: 'gpsService' });
const db     = require('../config/database');

// In-memory location cache
// keyed by driverId, value: { lat, lng, accuracy_m, updated_at, tenant_id, driver_name }
const locationCache = new Map();

// Socket.IO instance — set via init()
let _io = null;

/**
 * Initialize gpsService with the Socket.IO server instance.
 * Called from server.js after Socket.IO setup.
 * @param {import('socket.io').Server} io
 */
function init(io) {
  _io = io;
  logger.info('GpsService initialized with Socket.IO');
}

/**
 * Update a driver's in-memory location and broadcast to tracking room.
 * @param {{ driverId, tenantId, driverName, lat, lng, accuracyM }} params
 */
function updateLocation({ driverId, tenantId, driverName, lat, lng, accuracyM }) {
  const entry = {
    lat,
    lng,
    accuracy_m : accuracyM ?? null,
    updated_at : Date.now(),
    tenant_id  : tenantId,
    driver_name: driverName,
  };

  locationCache.set(driverId, entry);

  if (_io) {
    _io.to(`tracking:${tenantId}`).emit('driver_location', {
      driver_id  : driverId,
      lat,
      lng,
      accuracy_m : entry.accuracy_m,
      driver_name: driverName,
      updated_at : entry.updated_at,
    });
  }

  logger.debug({ driverId, tenantId, lat, lng }, 'Driver location updated');
}

/**
 * Return live driver positions for a tenant.
 * Excludes entries older than 5 minutes (stale position eviction).
 * @param {number} tenantId
 * @returns {Array}
 */
function getDriverLocations(tenantId) {
  const fiveMinutesAgo = Date.now() - 5 * 60 * 1000;
  const result = [];

  for (const [driverId, entry] of locationCache.entries()) {
    if (entry.tenant_id === tenantId && entry.updated_at >= fiveMinutesAgo) {
      result.push({
        driver_id  : driverId,
        lat        : entry.lat,
        lng        : entry.lng,
        accuracy_m : entry.accuracy_m,
        driver_name: entry.driver_name,
        updated_at : entry.updated_at,
      });
    }
  }

  return result;
}

/**
 * Check whether the current time is within working hours for a tenant.
 * Working hours: 6 AM – 8 PM in the tenant's configured timezone.
 * @param {number} tenantId
 * @returns {Promise<boolean>}
 */
async function isWithinWorkingHours(tenantId) {
  let timeZone = 'Africa/Johannesburg';

  try {
    const [rows] = await db.query(
      "SELECT setting_value FROM settings WHERE tenant_id = ? AND setting_key = 'tenant_timezone'",
      [tenantId]
    );
    if (rows.length > 0 && rows[0].setting_value) {
      timeZone = rows[0].setting_value;
    }
  } catch (err) {
    logger.warn({ err: err.message, tenantId }, 'Failed to fetch tenant timezone — using default');
  }

  const hourStr = new Intl.DateTimeFormat('en-US', {
    timeZone,
    hour    : 'numeric',
    hour12  : false,
  }).format(new Date());

  const hour = parseInt(hourStr, 10);
  return hour >= 6 && hour < 20;
}

/**
 * Flush in-memory location cache to driver_location_history table.
 * Does NOT clear the cache — positions remain live.
 * @returns {Promise<void>}
 */
async function flushLocationHistory() {
  if (locationCache.size === 0) {
    logger.debug('GPS flush: cache empty, skipping');
    return;
  }

  const entries = Array.from(locationCache.entries());

  // Build batch VALUES for INSERT
  const placeholders = entries.map(() => '(?, ?, ?, ?, ?)').join(', ');
  const values       = [];

  for (const [driverId, entry] of entries) {
    values.push(entry.tenant_id, driverId, entry.lat, entry.lng, entry.accuracy_m ?? null);
  }

  await db.query(
    `INSERT INTO driver_location_history (tenant_id, driver_id, lat, lng, accuracy_m) VALUES ${placeholders}`,
    values
  );

  logger.info({ count: entries.length }, 'GPS location history flushed');
}

/**
 * Get GPS consent record for a user.
 * @param {number} userId
 * @param {number} tenantId
 * @returns {Promise<object|null>}
 */
async function getConsent(userId, tenantId) {
  const [rows] = await db.query(
    'SELECT * FROM gps_consent WHERE user_id = ? AND tenant_id = ?',
    [userId, tenantId]
  );
  return rows.length > 0 ? rows[0] : null;
}

/**
 * Create or update GPS consent for a user.
 * Uses INSERT ... ON DUPLICATE KEY UPDATE for atomicity.
 * @param {number} userId
 * @param {number} tenantId
 * @param {boolean} gpsEnabled
 * @returns {Promise<object>}
 */
async function setConsent(userId, tenantId, gpsEnabled) {
  await db.query(
    `INSERT INTO gps_consent (tenant_id, user_id, gps_enabled)
     VALUES (?, ?, ?)
     ON DUPLICATE KEY UPDATE gps_enabled = VALUES(gps_enabled), updated_at = NOW()`,
    [tenantId, userId, gpsEnabled]
  );

  const [rows] = await db.query(
    'SELECT * FROM gps_consent WHERE user_id = ? AND tenant_id = ?',
    [userId, tenantId]
  );
  return rows[0];
}

module.exports = {
  init,
  updateLocation,
  getDriverLocations,
  isWithinWorkingHours,
  flushLocationHistory,
  getConsent,
  setConsent,
};
