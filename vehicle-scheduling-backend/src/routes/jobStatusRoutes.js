// ============================================
// FILE: src/routes/jobStatusRoutes.js
// PURPOSE: Define API routes for job status management
// LAYER: Route Layer
// ============================================

const express = require('express');
const router = express.Router();
const JobStatusController = require('../controllers/jobStatusController');

/**
 * Job Status Routes
 * 
 * Base URL: /api/job-status
 */

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