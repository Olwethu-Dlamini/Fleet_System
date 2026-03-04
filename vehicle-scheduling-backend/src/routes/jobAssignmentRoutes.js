// ============================================
// FILE: src/routes/jobAssignmentRoutes.js
// PURPOSE: Define API routes for job assignments
// LAYER: Route Layer (URL endpoints)
// ============================================

const express = require('express');
const router = express.Router();

// ✅ Import required services (auth is applied at app level in server.js)
const VehicleAvailabilityService = require('../services/vehicleAvailabilityService');
const JobAssignmentController = require('../controllers/jobAssignmentController');

/**
 * Job Assignment Routes
 * 
 * Base URL: /api/job-assignments
 * Note: Auth middleware is applied globally in server.js for /api/* routes
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
    console.error('Conflict check error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Server error while checking availability',
      error: error.message 
    });
  }
});

// ==========================================
// NEW: PUT /api/job-assignments/:jobId/technicians
// PURPOSE: Replace the driver/technician list on an existing job
//          without changing the vehicle assignment.
// Body: { "technician_ids": [3, 7], "assigned_by": 1 }
// ==========================================
router.put('/:jobId/technicians', JobAssignmentController.assignTechnicians);

// ==========================================
// GET /api/job-assignments/vehicle/:vehicle_id
// PURPOSE: Get all assignments for a specific vehicle
// ==========================================
// ✅ Keep original - auth handled at app level
router.get('/vehicle/:vehicle_id', JobAssignmentController.getAssignmentsByVehicle);

// Export the router
module.exports = router;