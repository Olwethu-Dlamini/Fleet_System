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

/**
 * @swagger
 * /gps/directions:
 *   get:
 *     tags: [GPS]
 *     summary: Get directions to a job destination
 *     description: Returns encoded polyline, ETA, and distance from an optional origin to the job's destination coordinates. Uses Google Routes API v2 server-side (API key never sent to client). If no origin is provided, returns only the destination coordinates.
 *     security:
 *       - ApiKeyAuth: []
 *     parameters:
 *       - in: query
 *         name: job_id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Job ID to get directions to
 *       - in: query
 *         name: origin_lat
 *         schema:
 *           type: number
 *         description: Origin latitude (driver's current position)
 *         example: -26.1
 *       - in: query
 *         name: origin_lng
 *         schema:
 *           type: number
 *         description: Origin longitude (driver's current position)
 *         example: 28.0
 *     responses:
 *       200:
 *         description: Directions result
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 directions:
 *                   type: object
 *                   properties:
 *                     encoded_polyline:
 *                       type: string
 *                       nullable: true
 *                     duration_text:
 *                       type: string
 *                       nullable: true
 *                       example: 25 mins
 *                     distance_text:
 *                       type: string
 *                       nullable: true
 *                       example: 18.3 km
 *                     destination_lat:
 *                       type: number
 *                     destination_lng:
 *                       type: number
 *       400:
 *         description: Missing job_id
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       404:
 *         description: Job not found or has no destination coordinates
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       500:
 *         description: Directions fetch failed
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
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

/**
 * @swagger
 * /gps/location:
 *   post:
 *     tags: [GPS]
 *     summary: Post driver location update
 *     description: Driver/technician posts their current GPS coordinates. Enforces working hours (6AM-8PM) and requires GPS consent. Location is stored in memory for real-time dispatch view.
 *     security:
 *       - ApiKeyAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [lat, lng]
 *             properties:
 *               lat:
 *                 type: number
 *                 example: -26.2041
 *               lng:
 *                 type: number
 *                 example: 28.0473
 *               accuracy_m:
 *                 type: number
 *                 example: 10.5
 *     responses:
 *       200:
 *         description: Location accepted
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       403:
 *         description: Outside working hours or GPS consent not granted
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
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

/**
 * @swagger
 * /gps/drivers:
 *   get:
 *     tags: [GPS]
 *     summary: Get live driver positions (admin/scheduler only)
 *     description: Returns in-memory GPS positions for all active drivers in the tenant. Stale positions (>5 min) are automatically filtered. Scheduler access can be disabled by the admin via the scheduler_gps_visible setting.
 *     security:
 *       - ApiKeyAuth: []
 *     responses:
 *       200:
 *         description: Live driver positions
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/GpsPosition'
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       403:
 *         description: Admin or scheduler role required (or scheduler GPS visibility disabled)
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
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

/**
 * @swagger
 * /gps/consent:
 *   get:
 *     tags: [GPS]
 *     summary: Get current user's GPS consent record
 *     description: Returns the GPS consent status for the authenticated user. Used by the Flutter app to determine whether to show the consent screen on startup.
 *     security:
 *       - ApiKeyAuth: []
 *     responses:
 *       200:
 *         description: Consent record
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/GpsConsent'
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
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

/**
 * @swagger
 * /gps/consent:
 *   post:
 *     tags: [GPS]
 *     summary: Grant GPS consent (first-time)
 *     description: Creates a GPS consent record for the user (gps_enabled=true). This is the POPIA/GDPR consent audit record. Call this when the user accepts the consent screen.
 *     security:
 *       - ApiKeyAuth: []
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               gps_enabled:
 *                 type: boolean
 *                 example: true
 *     responses:
 *       201:
 *         description: Consent granted
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/GpsConsent'
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
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

/**
 * @swagger
 * /gps/consent:
 *   put:
 *     tags: [GPS]
 *     summary: Update GPS consent (enable or disable tracking)
 *     description: Updates the user's GPS consent. Send gps_enabled=false to stop tracking. The POPIA audit record is still created even when disabling — this matches the decline flow.
 *     security:
 *       - ApiKeyAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [gps_enabled]
 *             properties:
 *               gps_enabled:
 *                 type: boolean
 *                 example: false
 *     responses:
 *       200:
 *         description: Consent updated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/GpsConsent'
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
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
