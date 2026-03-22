// ============================================
// FILE: src/routes/availabilityRoutes.js          ← NEW FILE
// PURPOSE: Pre-flight availability checks so the Flutter app can
//          grey out busy vehicles and drivers before the user submits
//          an assignment.  The server-side guards in
//          jobAssignmentService.js remain the authoritative check —
//          these endpoints are a UX convenience layer on top.
//
// Mounted in src/routes/index.js:
//   router.use('/availability', availabilityRoutes);
// Full URLs:
//   GET  /api/availability/drivers
//   GET  /api/availability/vehicles
//   POST /api/availability/check-drivers
// ============================================

const express = require('express');
const router  = express.Router();

// Same auth middleware used by every other route file in this project
const { verifyToken } = require('../middleware/authMiddleware');
const VehicleAvailabilityService = require('../services/vehicleAvailabilityService');
const logger = require('../config/logger');
const log    = logger.child({ service: 'availability-route' });

// All routes require a valid JWT
router.use(verifyToken);

// ──────────────────────────────────────────────────────────────
// GET /api/availability/drivers
//
// Query params (all required):
//   date        YYYY-MM-DD
//   start_time  HH:MM:SS
//   end_time    HH:MM:SS
//
// Optional:
//   exclude_job_id  number  — omit this job's own assignments when
//                             checking (pass the job being edited)
//
// Returns:
// {
//   success: true,
//   available:    [{ id, full_name, email, role, isAvailable: true  }, ...],
//   busy:         [{ id, full_name, email, role, isAvailable: false }, ...],
//   availableIds: [1, 3, 7, ...]
// }
//
// Flutter usage: CreateJobScreen + job_detail_screen driver pickers
//   call this whenever date/time changes to grey out already-booked
//   drivers before the user submits.
// ──────────────────────────────────────────────────────────────
/**
 * @swagger
 * /availability/drivers:
 *   get:
 *     tags: [Availability]
 *     summary: Get available and busy drivers for a time slot
 *     description: Returns all active drivers split into available and busy lists for a given date/time window. Used by the Flutter assignment picker to grey out already-booked drivers before submission.
 *     security:
 *       - ApiKeyAuth: []
 *     parameters:
 *       - in: query
 *         name: date
 *         required: true
 *         schema:
 *           type: string
 *           format: date
 *         description: Date (YYYY-MM-DD)
 *       - in: query
 *         name: start_time
 *         required: true
 *         schema:
 *           type: string
 *         description: Start time (HH:MM:SS)
 *         example: '09:00:00'
 *       - in: query
 *         name: end_time
 *         required: true
 *         schema:
 *           type: string
 *         description: End time (HH:MM:SS)
 *         example: '11:00:00'
 *       - in: query
 *         name: exclude_job_id
 *         schema:
 *           type: integer
 *         description: Job ID to exclude from conflict check (when editing an existing job)
 *     responses:
 *       200:
 *         description: Driver availability lists
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 available:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/User'
 *                 busy:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/User'
 *                 availableIds:
 *                   type: array
 *                   items:
 *                     type: integer
 *       400:
 *         description: Missing required query params
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
router.get('/drivers', async (req, res) => {
  try {
    const { date, start_time, end_time, exclude_job_id } = req.query;

    if (!date || !start_time || !end_time) {
      return res.status(400).json({
        success: false,
        error: 'date, start_time, and end_time are required query parameters',
      });
    }

    const result = await VehicleAvailabilityService.findAvailableDrivers(
      date,
      start_time,
      end_time,
      exclude_job_id ? parseInt(exclude_job_id, 10) : null
    );

    return res.json({ success: true, ...result });

  } catch (error) {
    log.error({ err: error.message }, 'GET /api/availability/drivers error');
    return res.status(400).json({ success: false, error: error.message });
  }
});

// ──────────────────────────────────────────────────────────────
// GET /api/availability/vehicles
//
// Query params (all required):
//   date        YYYY-MM-DD
//   start_time  HH:MM:SS
//   end_time    HH:MM:SS
//
// Returns:
// {
//   success: true,
//   available: [{ id, vehicle_name, license_plate, vehicle_type,
//                 capacity_kg, is_active }, ...]
// }
//
// Flutter usage: CreateJobScreen vehicle picker — wraps the existing
//   findAvailableVehicles() method already in vehicleAvailabilityService.
// ──────────────────────────────────────────────────────────────
/**
 * @swagger
 * /availability/vehicles:
 *   get:
 *     tags: [Availability]
 *     summary: Get available vehicles for a time slot
 *     description: Returns vehicles that are not already assigned to another job in the given date/time window. Used by the Flutter vehicle picker.
 *     security:
 *       - ApiKeyAuth: []
 *     parameters:
 *       - in: query
 *         name: date
 *         required: true
 *         schema:
 *           type: string
 *           format: date
 *         description: Date (YYYY-MM-DD)
 *       - in: query
 *         name: start_time
 *         required: true
 *         schema:
 *           type: string
 *         description: Start time (HH:MM:SS)
 *       - in: query
 *         name: end_time
 *         required: true
 *         schema:
 *           type: string
 *         description: End time (HH:MM:SS)
 *     responses:
 *       200:
 *         description: Available vehicles
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 available:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Vehicle'
 *       400:
 *         description: Missing required query params
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
router.get('/vehicles', async (req, res) => {
  try {
    const { date, start_time, end_time } = req.query;

    if (!date || !start_time || !end_time) {
      return res.status(400).json({
        success: false,
        error: 'date, start_time, and end_time are required query parameters',
      });
    }

    const available = await VehicleAvailabilityService.findAvailableVehicles(
      date,
      start_time,
      end_time
    );

    return res.json({ success: true, available });

  } catch (error) {
    log.error({ err: error.message }, 'GET /api/availability/vehicles error');
    return res.status(400).json({ success: false, error: error.message });
  }
});

// ──────────────────────────────────────────────────────────────
// POST /api/availability/check-drivers
//
// Body:
// {
//   technician_ids: [1, 2, 3],  // required — non-empty array
//   date:           "YYYY-MM-DD",
//   start_time:     "HH:MM:SS",
//   end_time:       "HH:MM:SS",
//   exclude_job_id: 5            // optional
// }
//
// Returns:
// {
//   success: true,
//   allAvailable: true | false,
//   conflicts: [{ driverId, driverName, jobNumber, customer, timeSlot }, ...]
// }
//
// Flutter usage: validate a specific driver selection before calling
//   the assign endpoint — e.g. the "Save" button on edit screens.
// ──────────────────────────────────────────────────────────────
/**
 * @swagger
 * /availability/check-drivers:
 *   post:
 *     tags: [Availability]
 *     summary: Check availability of specific drivers
 *     description: Checks whether a specific set of drivers is available for a time slot. Returns allAvailable flag and any conflicts. Used to validate a driver selection before the Save button is pressed.
 *     security:
 *       - ApiKeyAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [technician_ids, date, start_time, end_time]
 *             properties:
 *               technician_ids:
 *                 type: array
 *                 items:
 *                   type: integer
 *                 example: [3, 7]
 *               date:
 *                 type: string
 *                 format: date
 *                 example: '2026-03-25'
 *               start_time:
 *                 type: string
 *                 example: '09:00:00'
 *               end_time:
 *                 type: string
 *                 example: '11:00:00'
 *               exclude_job_id:
 *                 type: integer
 *                 example: 5
 *     responses:
 *       200:
 *         description: Availability check result
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 allAvailable:
 *                   type: boolean
 *                   example: true
 *                 conflicts:
 *                   type: array
 *                   items:
 *                     type: object
 *       400:
 *         description: Missing required fields
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
router.post('/check-drivers', async (req, res) => {
  try {
    const { technician_ids, date, start_time, end_time, exclude_job_id } = req.body;

    if (!Array.isArray(technician_ids) || technician_ids.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'technician_ids must be a non-empty array',
      });
    }
    if (!date || !start_time || !end_time) {
      return res.status(400).json({
        success: false,
        error: 'date, start_time, and end_time are required',
      });
    }

    const result = await VehicleAvailabilityService.checkDriversAvailability(
      technician_ids,
      date,
      start_time,
      end_time,
      exclude_job_id || null
    );

    return res.json({ success: true, ...result });

  } catch (error) {
    log.error({ err: error.message }, 'POST /api/availability/check-drivers error');
    return res.status(400).json({ success: false, error: error.message });
  }
});

module.exports = router;