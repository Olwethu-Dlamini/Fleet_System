// ============================================
// FILE: src/routes/timeExtension.js
// PURPOSE: REST endpoints for time extension workflow
// Requirements: TIME-01, TIME-02, TIME-03, TIME-04, TIME-05, TIME-06, TIME-07
// ============================================

const express = require('express');
const router  = express.Router();
const { body, param, validationResult } = require('express-validator');
const { verifyToken, requirePermission } = require('../middleware/authMiddleware');
const TimeExtensionService = require('../services/timeExtensionService');
const logger = require('../config/logger').child({ service: 'timeExtensionRoutes' });

// ============================================
// HELPER: run express-validator checks
// ============================================
function validate(req, res) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    res.status(400).json({ success: false, error: 'Validation failed', details: errors.array() });
    return false;
  }
  return true;
}

// ============================================
// POST /api/time-extensions
// Create a time extension request
// Auth: any authenticated user (service layer validates assignment)
// ============================================
/**
 * Body:
 * {
 *   "job_id": 5,
 *   "duration_minutes": 30,
 *   "reason": "Water damage discovered under flooring"
 * }
 *
 * Success (201):
 * { "success": true, "request": {...}, "affectedJobs": [...], "suggestions": [...] }
 *
 * Errors:
 *   400 — validation failure or job not in_progress
 *   403 — not assigned to job
 *   409 — active request already exists
 */
router.post(
  '/',
  verifyToken,
  [
    body('job_id').isInt({ min: 1 }).withMessage('job_id must be a positive integer'),
    body('duration_minutes')
      .isInt({ min: 1, max: 480 })
      .withMessage('duration_minutes must be between 1 and 480'),
    body('reason')
      .isString()
      .trim()
      .isLength({ min: 10 })
      .withMessage('reason must be at least 10 characters'),
  ],
  async (req, res) => {
    if (!validate(req, res)) return;

    try {
      const { job_id, duration_minutes, reason } = req.body;

      const result = await TimeExtensionService.createRequest({
        jobId:           job_id,
        requestedBy:     req.user.id,
        durationMinutes: duration_minutes,
        reason,
        tenantId:        req.user.tenant_id,
      });

      return res.status(201).json({
        success:     true,
        request:     result.request,
        affectedJobs: result.affectedJobs,
        suggestions: result.suggestions,
      });
    } catch (err) {
      if (err.statusCode === 409) {
        return res.status(409).json({ success: false, error: err.message });
      }
      if (err.statusCode === 403) {
        return res.status(403).json({ success: false, error: err.message });
      }
      if (err.statusCode === 400) {
        return res.status(400).json({ success: false, error: err.message });
      }
      logger.error({ err, jobId: req.body.job_id, userId: req.user?.id }, 'createRequest failed');
      return res.status(500).json({ success: false, error: 'Internal server error' });
    }
  }
);

// ============================================
// GET /api/time-extensions/:jobId
// Get active (pending) extension request for a job
// Auth: any authenticated user
// ============================================
/**
 * Success (200):
 * { "success": true, "request": {...} | null, "suggestions": [...] }
 */
router.get(
  '/:jobId',
  verifyToken,
  [
    param('jobId').isInt({ min: 1 }).withMessage('jobId must be a positive integer'),
  ],
  async (req, res) => {
    if (!validate(req, res)) return;

    try {
      const jobId = parseInt(req.params.jobId, 10);
      const result = await TimeExtensionService.getActiveRequest(jobId, req.user.tenant_id);

      return res.status(200).json({
        success:     true,
        request:     result.request,
        suggestions: result.suggestions,
      });
    } catch (err) {
      logger.error({ err, jobId: req.params.jobId }, 'getActiveRequest failed');
      return res.status(500).json({ success: false, error: 'Internal server error' });
    }
  }
);

// ============================================
// PATCH /api/time-extensions/:id/approve
// Approve a time extension request
// Auth: verifyToken + jobs:update permission (admin/scheduler only)
// ============================================
/**
 * Body (all optional):
 * {
 *   "suggestion_id": 3,         // ID of chosen reschedule_options row
 *   "custom_changes": [          // Only when type=custom
 *     { "jobId": 7, "newStart": "14:30:00", "newEnd": "16:00:00" }
 *   ]
 * }
 *
 * Success (200):
 * { "success": true, "message": "Extension approved" }
 */
router.patch(
  '/:id/approve',
  verifyToken,
  requirePermission('jobs:update'),
  [
    param('id').isInt({ min: 1 }).withMessage('id must be a positive integer'),
    body('suggestion_id')
      .optional({ nullable: true })
      .isInt({ min: 1 })
      .withMessage('suggestion_id must be a positive integer'),
    body('custom_changes')
      .optional({ nullable: true })
      .isArray()
      .withMessage('custom_changes must be an array'),
  ],
  async (req, res) => {
    if (!validate(req, res)) return;

    try {
      const requestId    = parseInt(req.params.id, 10);
      const suggestionId = req.body.suggestion_id || null;
      const customChanges = req.body.custom_changes || null;

      await TimeExtensionService.approveRequest(
        requestId, suggestionId, customChanges, req.user.id, req.user.tenant_id
      );

      return res.status(200).json({ success: true, message: 'Extension approved' });
    } catch (err) {
      if (err.statusCode === 404) {
        return res.status(404).json({ success: false, error: err.message });
      }
      logger.error({ err, requestId: req.params.id }, 'approveRequest failed');
      return res.status(500).json({ success: false, error: 'Internal server error' });
    }
  }
);

// ============================================
// PATCH /api/time-extensions/:id/deny
// Deny a time extension request
// Auth: verifyToken + jobs:update permission (admin/scheduler only)
// ============================================
/**
 * Body (optional):
 * { "reason": "Schedule is fully booked" }
 *
 * Success (200):
 * { "success": true, "message": "Extension denied" }
 */
router.patch(
  '/:id/deny',
  verifyToken,
  requirePermission('jobs:update'),
  [
    param('id').isInt({ min: 1 }).withMessage('id must be a positive integer'),
    body('reason')
      .optional()
      .isString()
      .withMessage('reason must be a string'),
  ],
  async (req, res) => {
    if (!validate(req, res)) return;

    try {
      const requestId = parseInt(req.params.id, 10);
      const reason    = req.body.reason || null;

      await TimeExtensionService.denyRequest(
        requestId, reason, req.user.id, req.user.tenant_id
      );

      return res.status(200).json({ success: true, message: 'Extension denied' });
    } catch (err) {
      if (err.statusCode === 404) {
        return res.status(404).json({ success: false, error: err.message });
      }
      logger.error({ err, requestId: req.params.id }, 'denyRequest failed');
      return res.status(500).json({ success: false, error: 'Internal server error' });
    }
  }
);

module.exports = router;
