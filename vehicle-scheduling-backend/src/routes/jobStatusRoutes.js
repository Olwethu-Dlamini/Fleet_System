// ============================================
// FILE: src/routes/jobStatusRoutes.js
// PURPOSE: Define API routes for job status management
// LAYER: Route Layer
// ============================================

const express = require('express');
const router = express.Router();
const JobStatusController = require('../controllers/jobStatusController');
const { verifyToken } = require('../middleware/authMiddleware');
const JobStatusService = require('../services/jobStatusService');
const logger = require('../config/logger').child({ service: 'jobStatusRoutes' });

/**
 * Job Status Routes
 *
 * Base URL: /api/job-status
 */

// ==========================================
// POST /api/job-status/complete
// PURPOSE: STAT-02/03/04 — Complete a job with personnel check and GPS capture
// Only assigned personnel or admin/scheduler can mark a job complete.
// ==========================================
/**
 * Complete a job
 *
 * Body:
 * {
 *   "job_id": 5,
 *   "lat": -26.2041,        // optional, null if no GPS
 *   "lng": 28.0473,         // optional, null if no GPS
 *   "accuracy_m": 15.0,     // optional
 *   "gps_status": "ok"      // optional: "ok" | "low_accuracy" | "no_gps" (default: "no_gps")
 * }
 *
 * Success response (200):
 * {
 *   "success": true,
 *   "message": "Job completed successfully",
 *   "data": { "job": {...}, "statusChange": {...}, "completion": {...} }
 * }
 *
 * Error response (403): Non-assigned, non-admin user
 */
// STAT-02/03/04: Complete a job — only assigned personnel or admin/scheduler
router.post('/complete', verifyToken, async (req, res) => {
  try {
    const { job_id, lat, lng, accuracy_m, gps_status } = req.body;

    if (!job_id) {
      return res.status(400).json({ success: false, message: 'job_id is required' });
    }

    const validGpsStatuses = ['ok', 'low_accuracy', 'no_gps'];
    const sanitizedGpsStatus = validGpsStatuses.includes(gps_status) ? gps_status : 'no_gps';

    const result = await JobStatusService.completeJob(
      job_id,
      req.user.id,
      req.user.role,
      { lat: lat || null, lng: lng || null, accuracy_m: accuracy_m || null, gps_status: sanitizedGpsStatus }
    );

    return res.status(200).json({
      success: true,
      message: 'Job completed successfully',
      data: result
    });
  } catch (err) {
    if (err.message.startsWith('FORBIDDEN')) {
      return res.status(403).json({ success: false, message: 'Only assigned personnel can complete this job.' });
    }
    logger.error({ err, jobId: req.body.job_id }, 'Job completion failed');
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ==========================================
// POST /api/job-status/update
// PURPOSE: Update a job's status
// ==========================================
/**
 * Update job status
 * 
 * Body: 
 * {
 *   "job_id": 5,
 *   "new_status": "in_progress",
 *   "changed_by": 1,
 *   "reason": "Driver started work",
 *   "metadata": {}
 * }
 * 
 * Success response (200):
 * {
 *   "success": true,
 *   "message": "Job status updated to 'in_progress' successfully",
 *   "data": {
 *     "job": {...},
 *     "statusChange": {...}
 *   }
 * }
 */
router.post('/update', JobStatusController.updateStatus);

// ==========================================
// GET /api/job-status/history/:job_id
// PURPOSE: Get status change history for a job
// ==========================================
/**
 * Get status history
 * 
 * URL params: job_id
 * Query params: limit (optional)
 * 
 * Example: GET /api/job-status/history/5?limit=10
 */
router.get('/history/:job_id', JobStatusController.getStatusHistory);

// ==========================================
// GET /api/job-status/allowed-transitions/:job_id
// PURPOSE: Get allowed status transitions for a job
// ==========================================
/**
 * Get allowed transitions
 * 
 * Example: GET /api/job-status/allowed-transitions/5
 */
router.get('/allowed-transitions/:job_id', JobStatusController.getAllowedTransitions);

// ==========================================
// POST /api/job-status/validate-transition
// PURPOSE: Validate if a transition is allowed
// ==========================================
/**
 * Validate transition
 * 
 * Body: { "job_id": 5, "target_status": "in_progress" }
 */
router.post('/validate-transition', JobStatusController.validateTransition);

// ==========================================
// GET /api/job-status/recent-changes
// PURPOSE: Get recent status changes across all jobs
// ==========================================
/**
 * Get recent status changes (for dashboard)
 * 
 * Query params: limit, status, days
 * 
 * Example: GET /api/job-status/recent-changes?limit=20&days=7
 */
router.get('/recent-changes', JobStatusController.getRecentStatusChanges);

module.exports = router;