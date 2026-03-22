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

/**
 * @swagger
 * /job-status/complete:
 *   post:
 *     tags: [Job Status]
 *     summary: Complete a job with GPS capture
 *     description: Marks a job as completed. Only assigned personnel or admin/scheduler can complete a job. Optionally captures GPS coordinates at completion for audit trail.
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
 *               lat:
 *                 type: number
 *                 example: -26.2041
 *               lng:
 *                 type: number
 *                 example: 28.0473
 *               accuracy_m:
 *                 type: number
 *                 example: 15.0
 *               gps_status:
 *                 type: string
 *                 enum: [ok, low_accuracy, no_gps]
 *                 example: ok
 *     responses:
 *       200:
 *         description: Job completed successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 message:
 *                   type: string
 *                   example: Job completed successfully
 *                 data:
 *                   type: object
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
 *       403:
 *         description: User not assigned to this job
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

/**
 * @swagger
 * /job-status/update:
 *   post:
 *     tags: [Job Status]
 *     summary: Update a job's status
 *     description: Transitions a job to a new status. Validates that the transition is allowed based on the current status and state machine rules.
 *     security:
 *       - ApiKeyAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [job_id, new_status, changed_by]
 *             properties:
 *               job_id:
 *                 type: integer
 *                 example: 5
 *               new_status:
 *                 type: string
 *                 enum: [pending, assigned, in_progress, completed, cancelled]
 *                 example: in_progress
 *               changed_by:
 *                 type: integer
 *                 example: 1
 *               reason:
 *                 type: string
 *                 example: Driver started work
 *               metadata:
 *                 type: object
 *     responses:
 *       200:
 *         description: Status updated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 message:
 *                   type: string
 *                   example: "Job status updated to 'in_progress' successfully"
 *                 data:
 *                   type: object
 *       400:
 *         description: Invalid transition
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

/**
 * @swagger
 * /job-status/history/{job_id}:
 *   get:
 *     tags: [Job Status]
 *     summary: Get status change history for a job
 *     description: Returns the full status change history for a job, ordered chronologically. Supports a limit query param to restrict results.
 *     security:
 *       - ApiKeyAuth: []
 *     parameters:
 *       - in: path
 *         name: job_id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Job ID
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           example: 10
 *         description: Maximum number of history entries to return
 *     responses:
 *       200:
 *         description: Status history retrieved
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 history:
 *                   type: array
 *                   items:
 *                     type: object
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

/**
 * @swagger
 * /job-status/allowed-transitions/{job_id}:
 *   get:
 *     tags: [Job Status]
 *     summary: Get allowed status transitions for a job
 *     description: Returns which status values the job can transition to from its current state, based on the status state machine.
 *     security:
 *       - ApiKeyAuth: []
 *     parameters:
 *       - in: path
 *         name: job_id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Job ID
 *     responses:
 *       200:
 *         description: Allowed transitions retrieved
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 transitions:
 *                   type: array
 *                   items:
 *                     type: string
 *                   example: [in_progress, cancelled]
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
// GET /api/job-status/allowed-transitions/:job_id
// PURPOSE: Get allowed status transitions for a job
// ==========================================
/**
 * Get allowed transitions
 * 
 * Example: GET /api/job-status/allowed-transitions/5
 */
router.get('/allowed-transitions/:job_id', JobStatusController.getAllowedTransitions);

/**
 * @swagger
 * /job-status/validate-transition:
 *   post:
 *     tags: [Job Status]
 *     summary: Validate if a status transition is allowed
 *     description: Checks whether a job can transition to the specified target status without actually making the change.
 *     security:
 *       - ApiKeyAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [job_id, target_status]
 *             properties:
 *               job_id:
 *                 type: integer
 *                 example: 5
 *               target_status:
 *                 type: string
 *                 enum: [pending, assigned, in_progress, completed, cancelled]
 *                 example: in_progress
 *     responses:
 *       200:
 *         description: Validation result
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 valid:
 *                   type: boolean
 *                   example: true
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
// POST /api/job-status/validate-transition
// PURPOSE: Validate if a transition is allowed
// ==========================================
/**
 * Validate transition
 * 
 * Body: { "job_id": 5, "target_status": "in_progress" }
 */
router.post('/validate-transition', JobStatusController.validateTransition);

/**
 * @swagger
 * /job-status/recent-changes:
 *   get:
 *     tags: [Job Status]
 *     summary: Get recent status changes across all jobs
 *     description: Returns recent status change events across all jobs. Used by the dashboard to display activity feeds.
 *     security:
 *       - ApiKeyAuth: []
 *     parameters:
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           example: 20
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [pending, assigned, in_progress, completed, cancelled]
 *       - in: query
 *         name: days
 *         schema:
 *           type: integer
 *           example: 7
 *     responses:
 *       200:
 *         description: Recent changes retrieved
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 changes:
 *                   type: array
 *                   items:
 *                     type: object
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