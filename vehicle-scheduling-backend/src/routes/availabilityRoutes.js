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