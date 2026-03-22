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

/**
 * @swagger
 * /job-assignments/driver-load:
 *   get:
 *     tags: [Job Assignments]
 *     summary: Get driver load statistics for load-balanced assignment
 *     description: Returns all active drivers with job_count, rank, and a below_average flag. Used by the Flutter assignment picker to highlight under-loaded drivers with a green glow (ASGN-01, ASGN-02).
 *     security:
 *       - ApiKeyAuth: []
 *     parameters:
 *       - in: query
 *         name: range
 *         schema:
 *           type: string
 *           enum: [weekly, monthly, yearly]
 *           default: weekly
 *         description: Time range for job count calculation
 *     responses:
 *       200:
 *         description: Driver load stats retrieved
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
 *                     $ref: '#/components/schemas/DriverLoad'
 *       400:
 *         description: Invalid range parameter
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

/**
 * @swagger
 * /job-assignments/assign:
 *   post:
 *     tags: [Job Assignments]
 *     summary: Assign a vehicle to a job
 *     description: Creates a job assignment record linking a vehicle (and optionally drivers) to a job. Checks for vehicle availability conflicts before assigning.
 *     security:
 *       - ApiKeyAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [job_id, vehicle_id, assigned_by]
 *             properties:
 *               job_id:
 *                 type: integer
 *                 example: 5
 *               vehicle_id:
 *                 type: integer
 *                 example: 2
 *               technician_ids:
 *                 type: array
 *                 items:
 *                   type: integer
 *                 example: [3, 7]
 *               notes:
 *                 type: string
 *                 example: Priority assignment
 *               assigned_by:
 *                 type: integer
 *                 example: 1
 *     responses:
 *       200:
 *         description: Vehicle assigned to job
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 assignment:
 *                   $ref: '#/components/schemas/Assignment'
 *       400:
 *         description: Validation error or conflict
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

/**
 * @swagger
 * /job-assignments/unassign:
 *   post:
 *     tags: [Job Assignments]
 *     summary: Remove vehicle assignment from a job
 *     description: Removes the vehicle assignment from the specified job.
 *     security:
 *       - ApiKeyAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [job_id]
 *             properties:
 *               job_id:
 *                 type: integer
 *                 example: 5
 *     responses:
 *       200:
 *         description: Vehicle unassigned
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/SuccessResponse'
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
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
// ==========================================
// POST /api/job-assignments/unassign
// PURPOSE: Remove vehicle assignment from a job
// ==========================================
// ✅ FIX: Removed authMiddleware - auth is handled at app level
router.post('/unassign', JobAssignmentController.unassignJob);

/**
 * @swagger
 * /job-assignments/check-conflict:
 *   post:
 *     tags: [Job Assignments]
 *     summary: Check if a vehicle is available for a time slot
 *     description: Checks whether a vehicle has scheduling conflicts for the given date and time window. Pass exclude_job_id when editing an existing job to exclude its own assignment from the conflict check.
 *     security:
 *       - ApiKeyAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [vehicle_id, scheduled_date, scheduled_time_start, scheduled_time_end]
 *             properties:
 *               vehicle_id:
 *                 type: integer
 *                 example: 2
 *               scheduled_date:
 *                 type: string
 *                 format: date
 *                 example: '2026-03-25'
 *               scheduled_time_start:
 *                 type: string
 *                 example: '09:00:00'
 *               scheduled_time_end:
 *                 type: string
 *                 example: '11:00:00'
 *               exclude_job_id:
 *                 type: integer
 *                 example: 5
 *     responses:
 *       200:
 *         description: Availability result
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 available:
 *                   type: boolean
 *                   example: true
 *                 conflicts:
 *                   type: array
 *                   items:
 *                     type: object
 *                 message:
 *                   type: string
 *                   example: Vehicle is available for this time slot
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

/**
 * @swagger
 * /job-assignments/{jobId}/technicians:
 *   put:
 *     tags: [Job Assignments]
 *     summary: Assign technicians to a job
 *     description: Assigns one or more technicians to a job. Admin can use force_override to bypass conflict checks and move drivers from their current assignments.
 *     security:
 *       - ApiKeyAuth: []
 *     parameters:
 *       - in: path
 *         name: jobId
 *         required: true
 *         schema:
 *           type: integer
 *         description: Job ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [technician_ids, assigned_by]
 *             properties:
 *               technician_ids:
 *                 type: array
 *                 items:
 *                   type: integer
 *                 example: [3, 7]
 *               assigned_by:
 *                 type: integer
 *                 example: 1
 *               force_override:
 *                 type: boolean
 *                 example: false
 *     responses:
 *       200:
 *         description: Technicians assigned
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/SuccessResponse'
 *       400:
 *         description: Validation error or conflict
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
// PUT /api/job-assignments/:jobId/technicians
// verifyToken is applied explicitly here (not relying on server.js global auth)
// because req.user.role is needed in the controller to gate force-override.
// Pattern matches users.js — verifyToken inline on every route that needs req.user.
router.put('/:jobId/technicians', verifyToken, JobAssignmentController.assignTechnicians);

/**
 * @swagger
 * /job-assignments/vehicle/{vehicle_id}:
 *   get:
 *     tags: [Job Assignments]
 *     summary: Get all assignments for a specific vehicle
 *     description: Returns all job assignments for a given vehicle. Useful for viewing a vehicle's workload history.
 *     security:
 *       - ApiKeyAuth: []
 *     parameters:
 *       - in: path
 *         name: vehicle_id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Vehicle ID
 *     responses:
 *       200:
 *         description: Assignments retrieved
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 assignments:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Assignment'
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
// ==========================================
// GET /api/job-assignments/vehicle/:vehicle_id
// PURPOSE: Get all assignments for a specific vehicle
// ==========================================
// ✅ Keep original - auth handled at app level
router.get('/vehicle/:vehicle_id', JobAssignmentController.getAssignmentsByVehicle);

// Export the router
module.exports = router;