// ============================================
// FILE: src/routes/gps.js
// PURPOSE: GPS REST endpoints — directions, location updates, driver tracking, consent
// Requirements: GPS-01, GPS-02, GPS-03, GPS-04, GPS-06, GPS-07, GPS-08
// ============================================

const express              = require('express');
const { body, validationResult } = require('express-validator');
const { verifyToken }      = require('../middleware/authMiddleware');
const GpsService           = require('../services/gpsService');
const DirectionsService    = require('../services/directionsService');
const db                   = require('../config/database');
const logger               = require('../config/logger').child({ service: 'gps-routes' });

const router = express.Router();

// ============================================
// GET /api/gps/directions
// Returns directions (polyline, ETA, distance) for a job via Google Routes API v2.
// Requires job_id. Optional origin_lat/origin_lng for route from current position.
// Requirements: GPS-01
// ============================================
router.get('/directions', verifyToken, async (req, res) => {
  try {
    const { job_id, origin_lat, origin_lng } = req.query;

    if (!job_id) {
      return res.status(400).json({ success: false, message: 'job_id query param is required' });
    }

    // Fetch job destination coordinates (tenant-scoped)
    const [rows] = await db.query(
      'SELECT id, destination_lat, destination_lng FROM jobs WHERE id = ? AND tenant_id = ?',
      [job_id, req.user.tenant_id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Job not found' });
    }

    const job = rows[0];

    if (job.destination_lat == null || job.destination_lng == null) {
      return res.status(404).json({
        success: false,
        message: 'Job has no destination coordinates',
      });
    }

    const destLat = parseFloat(job.destination_lat);
    const destLng = parseFloat(job.destination_lng);

    // If no origin coords provided, return destination only
    if (origin_lat == null || origin_lng == null) {
      return res.status(200).json({
        success: true,
        directions: {
          encoded_polyline : null,
          duration_text    : null,
          distance_text    : null,
          destination_lat  : destLat,
          destination_lng  : destLng,
          note             : 'Provide origin_lat and origin_lng for full directions',
        },
      });
    }

    const originLat = parseFloat(origin_lat);
    const originLng = parseFloat(origin_lng);

    const result = await DirectionsService.getDirections(originLat, originLng, destLat, destLng);

    return res.status(200).json({
      success: true,
      directions: {
        encoded_polyline : result.encoded_polyline,
        duration_text    : result.duration_text,
        distance_text    : result.distance_text,
        destination_lat  : destLat,
        destination_lng  : destLng,
      },
    });
  } catch (err) {
    // Do NOT expose API key errors or raw Google error details to client
    logger.error({ err: err.message }, 'GET /gps/directions error');
    return res.status(500).json({ success: false, message: 'Failed to fetch directions' });
  }
});

// ============================================
// POST /api/gps/location
// Driver posts their current location.
// Enforces working hours and consent checks.
// ============================================
router.post(
  '/location',
  verifyToken,
  [
    body('lat').isFloat({ min: -90, max: 90 }).withMessage('lat must be a float between -90 and 90'),
    body('lng').isFloat({ min: -180, max: 180 }).withMessage('lng must be a float between -180 and 180'),
    body('accuracy_m').optional().isFloat({ min: 0 }).withMessage('accuracy_m must be a non-negative float'),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    try {
      // GPS-06: Reject location updates outside working hours
      const withinHours = await GpsService.isWithinWorkingHours(req.user.tenant_id);
      if (!withinHours) {
        return res.status(403).json({
          success: false,
          message: 'GPS tracking only active during working hours (6AM-8PM)',
        });
      }

      // GPS-07: Require GPS consent
      const consent = await GpsService.getConsent(req.user.id, req.user.tenant_id);
      if (!consent || consent.gps_enabled === false || consent.gps_enabled === 0) {
        return res.status(403).json({
          success: false,
          message: 'GPS consent not granted',
        });
      }

      const { lat, lng, accuracy_m } = req.body;

      GpsService.updateLocation({
        driverId  : req.user.id,
        tenantId  : req.user.tenant_id,
        driverName: req.user.username,
        lat       : parseFloat(lat),
        lng       : parseFloat(lng),
        accuracyM : accuracy_m != null ? parseFloat(accuracy_m) : null,
      });

      return res.status(200).json({ success: true });
    } catch (err) {
      logger.error({ err }, 'POST /gps/location error');
      return res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }
);

// ============================================
// GET /api/gps/drivers
// Returns live driver positions for the tenant.
// Admin and scheduler only (GPS-03/GPS-04).
// ============================================
router.get('/drivers', verifyToken, async (req, res) => {
  try {
    // Only admin or scheduler can view live tracking
    if (!['admin', 'scheduler'].includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. Admin or scheduler role required.',
      });
    }

    // GPS-04: Check if scheduler GPS visibility is enabled (admin-controlled setting)
    if (req.user.role === 'scheduler') {
      const [rows] = await db.query(
        "SELECT setting_value FROM settings WHERE tenant_id = ? AND setting_key = 'scheduler_gps_visible'",
        [req.user.tenant_id]
      );
      const visible = rows.length > 0 ? rows[0].setting_value : 'true';
      if (visible === 'false') {
        return res.status(403).json({
          success: false,
          message: 'GPS tracking visibility has been disabled for scheduler role by admin.',
        });
      }
    }

    const locations = GpsService.getDriverLocations(req.user.tenant_id);
    return res.status(200).json({ success: true, data: locations });
  } catch (err) {
    logger.error({ err }, 'GET /gps/drivers error');
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

// ============================================
// GET /api/gps/consent
// Returns the current user's GPS consent record.
// ============================================
router.get('/consent', verifyToken, async (req, res) => {
  try {
    const consent = await GpsService.getConsent(req.user.id, req.user.tenant_id);
    return res.status(200).json({ success: true, data: consent });
  } catch (err) {
    logger.error({ err }, 'GET /gps/consent error');
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

// ============================================
// POST /api/gps/consent
// First-time consent grant (gps_enabled = true).
// ============================================
router.post(
  '/consent',
  verifyToken,
  [
    body('gps_enabled').optional().isBoolean().withMessage('gps_enabled must be a boolean'),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    try {
      const record = await GpsService.setConsent(req.user.id, req.user.tenant_id, true);
      return res.status(201).json({ success: true, data: record });
    } catch (err) {
      logger.error({ err }, 'POST /gps/consent error');
      return res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }
);

// ============================================
// PUT /api/gps/consent
// Update GPS consent (enable or disable tracking).
// ============================================
router.put(
  '/consent',
  verifyToken,
  [
    body('gps_enabled').isBoolean().withMessage('gps_enabled must be a boolean'),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    try {
      const { gps_enabled } = req.body;
      const record = await GpsService.setConsent(req.user.id, req.user.tenant_id, gps_enabled);
      return res.status(200).json({ success: true, data: record });
    } catch (err) {
      logger.error({ err }, 'PUT /gps/consent error');
      return res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }
);

module.exports = router;
