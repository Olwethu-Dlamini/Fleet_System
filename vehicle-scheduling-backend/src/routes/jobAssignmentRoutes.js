// ============================================
// FILE: src/routes/jobAssignmentRoutes.js
// PURPOSE: Define API routes for job assignments
// LAYER: Route Layer (URL endpoints)
// ============================================

const express = require('express');
const router = express.Router();

const VehicleAvailabilityService = require('../services/vehicleAvailabilityService');
const JobAssignmentController    = require('../controllers/jobAssignmentController');
const { verifyToken }            = require('../middleware/authMiddleware');
const Job                        = require('../models/Job');
const logger = require('../config/logger');
const log    = logger.child({ service: 'job-assignment-route' });

/**
 * Job Assignment Routes
 *
 * Base URL: /api/job-assignments
 * Note: Auth middleware is applied globally in server.js for /api/* routes
 */

// ==========================================
// GET /api/job-assignments/driver-load
// PURPOSE: Return all active drivers with job_count, rank, and below_average
//          flag for load-balanced assignment picker in the Flutter UI.
// QUERY PARAMS: range=weekly|monthly|yearly (default: weekly)
// ==========================================
router.get('/driver-load', verifyToken, async (req, res) => {
  try {
    const range = req.query.range || 'weekly';
    if (!['weekly', 'monthly', 'yearly'].includes(range)) {
      return res.status(400).json({ success: false, message: 'Invalid range. Use weekly, monthly, or yearly.' });
    }
    const tenantId = req.user.tenant_id;
    const drivers = await Job.getDriverLoadStats(tenantId, range);
    return res.status(200).json({ success: true, data: drivers });
  } catch (err) {
    log.error({ err }, 'Failed to get driver load stats');
    return res.status(500).json({ success: false, message: 'Failed to get driver load stats' });
  }
});

// ==========================================
// POST /api/job-assignments/assign
// PURPOSE: Assign a vehicle to a job
// ==========================================
/**
 * Assign a vehicle to a job
 * 
 * Request body:
 * {
 *   "job_id": 5,
 *   "vehicle_id": 2,
 *   "driver_id": 3,            // Optional — legacy single driver
 *   "technician_ids": [3, 7],  // Optional — preferred multi-driver list
 *   "notes": "Some notes",
 *   "assigned_by": 1
 * }
 */
// ✅ FIX: Removed authMiddleware - auth is handled at app level in server.js
router.post('/assign', JobAssignmentController.assignJob);

// ==========================================
// POST /api/job-assignments/unassign
// PURPOSE: Remove vehicle assignment from a job
// ==========================================
// ✅ FIX: Removed authMiddleware - auth is handled at app level
router.post('/unassign', JobAssignmentController.unassignJob);

// ==========================================
// POST /api/job-assignments/check-conflict
// PURPOSE: Check if vehicle is available for time slot
// ==========================================
/**
 * Check vehicle availability for a time slot (double-booking prevention)
 * 
 * Request body:
 * {
 *   "vehicle_id": 2,
 *   "scheduled_date": "2024-02-20",
 *   "scheduled_time_start": "09:00:00",
 *   "scheduled_time_end": "12:00:00",
 *   "exclude_job_id": 5
 * }
 */
// ✅ NEW: Conflict check endpoint (auth handled at app level)
router.post('/check-conflict', async (req, res) => {
  try {
    const { vehicle_id, scheduled_date, scheduled_time_start, scheduled_time_end, exclude_job_id } = req.body;
    
    // Validate required fields
    if (!vehicle_id || !scheduled_date || !scheduled_time_start || !scheduled_time_end) {
      return res.status(400).json({ 
        success: false, 
        message: 'Missing required fields: vehicle_id, scheduled_date, scheduled_time_start, scheduled_time_end' 
      });
    }
    
    // Validate date format (YYYY-MM-DD)
    if (!/^\d{4}-\d{2}-\d{2}$/.test(scheduled_date)) {
      return res.status(400).json({ 
        success: false, 
        message: 'Invalid date format. Use YYYY-MM-DD' 
      });
    }
    
    // Reuse existing availability service for conflict detection
    const availability = await VehicleAvailabilityService.checkVehicleAvailability(
      vehicle_id,
      scheduled_date,
      scheduled_time_start,
      scheduled_time_end,
      exclude_job_id || null
    );
    
    res.json({
      success: true,
      available: availability.isAvailable,
      conflicts: availability.conflicts || [],
      message: availability.isAvailable 
        ? 'Vehicle is available for this time slot' 
        : 'Vehicle has scheduling conflicts'
    });
    
  } catch (error) {
    log.error({ err: error }, 'Conflict check error');
    res.status(500).json({ 
      success: false, 
      message: 'Server error while checking availability',
      error: error.message 
    });
  }
});

// PUT /api/job-assignments/:jobId/technicians
// verifyToken is applied explicitly here (not relying on server.js global auth)
// because req.user.role is needed in the controller to gate force-override.
// Pattern matches users.js — verifyToken inline on every route that needs req.user.
router.put('/:jobId/technicians', verifyToken, JobAssignmentController.assignTechnicians);

// ==========================================
// GET /api/job-assignments/vehicle/:vehicle_id
// PURPOSE: Get all assignments for a specific vehicle
// ==========================================
// ✅ Keep original - auth handled at app level
router.get('/vehicle/:vehicle_id', JobAssignmentController.getAssignmentsByVehicle);

// Export the router
module.exports = router;