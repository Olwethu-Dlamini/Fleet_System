// ============================================
// FILE: src/routes/jobs.js
//
// FIXES:
//   • GET /  now uses verifyToken and returns only the calling user's
//     jobs when role === 'technician', instead of all jobs. This prevents
//     technicians accidentally receiving the full job list if they hit
//     the wrong endpoint, and makes the payload consistent with my-jobs.
//   • GET /my-jobs  confirmed correct — placed before /:id so Express
//     does not treat the literal string "my-jobs" as a numeric job ID.
//   • PUT /:id/technicians  kept as-is (already correct).
// ============================================

const express   = require('express');
const router    = express.Router();
const Job                   = require('../models/Job');
const JobAssignmentService  = require('../services/jobAssignmentService');
const db                    = require('../config/database');
const { verifyToken, requirePermission } = require('../middleware/authMiddleware');
const { body }              = require('express-validator');
const validate              = require('../middleware/validate');
const logger = require('../config/logger');
const log    = logger.child({ service: 'jobs-route' });

// ============================================
// Validation schemas — FOUND-06
// ============================================
const createJobValidation = [
  body('job_type')
    .isIn(['installation', 'delivery', 'miscellaneous'])
    .withMessage('job_type must be installation, delivery, or miscellaneous'),
  body('customer_name')
    .isString().trim().isLength({ min: 2, max: 100 })
    .withMessage('customer_name must be 2-100 characters'),
  body('customer_address')
    .isString().trim().notEmpty()
    .withMessage('customer_address is required'),
  body('scheduled_date')
    .isDate({ format: 'YYYY-MM-DD' })
    .withMessage('scheduled_date must be YYYY-MM-DD format'),
  body('scheduled_time_start')
    .matches(/^\d{2}:\d{2}(:\d{2})?$/)
    .withMessage('scheduled_time_start must be HH:MM or HH:MM:SS'),
  body('scheduled_time_end')
    .matches(/^\d{2}:\d{2}(:\d{2})?$/)
    .withMessage('scheduled_time_end must be HH:MM or HH:MM:SS'),
  body('estimated_duration_minutes')
    .isInt({ min: 1, max: 1440 })
    .withMessage('estimated_duration_minutes must be 1-1440'),
  body('priority')
    .optional().isIn(['low', 'normal', 'high', 'urgent'])
    .withMessage('priority must be low, normal, high, or urgent'),
  body('destination_lat')
    .optional().isFloat({ min: -90, max: 90 })
    .withMessage('destination_lat must be -90 to 90'),
  body('destination_lng')
    .optional().isFloat({ min: -180, max: 180 })
    .withMessage('destination_lng must be -180 to 180'),
];

const updateJobValidation = [
  body('job_type')
    .optional().isIn(['installation', 'delivery', 'miscellaneous'])
    .withMessage('job_type must be installation, delivery, or miscellaneous'),
  body('customer_name')
    .optional().isString().trim().isLength({ min: 2, max: 100 })
    .withMessage('customer_name must be 2-100 characters'),
  body('scheduled_date')
    .optional().isDate({ format: 'YYYY-MM-DD' })
    .withMessage('scheduled_date must be YYYY-MM-DD format'),
  body('estimated_duration_minutes')
    .optional().isInt({ min: 1, max: 1440 })
    .withMessage('estimated_duration_minutes must be 1-1440'),
  body('priority')
    .optional().isIn(['low', 'normal', 'high', 'urgent'])
    .withMessage('priority must be low, normal, high, or urgent'),
];

/**
 * @swagger
 * /jobs:
 *   get:
 *     tags: [Jobs]
 *     summary: List jobs (role-scoped)
 *     description: Returns all jobs for admin/scheduler roles. Technicians receive only their own assigned jobs. Supports optional filtering by status, job_type, and priority.
 *     security:
 *       - ApiKeyAuth: []
 *     parameters:
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [pending, assigned, in_progress, completed, cancelled]
 *         description: Filter by job status
 *       - in: query
 *         name: job_type
 *         schema:
 *           type: string
 *           enum: [installation, delivery, miscellaneous]
 *         description: Filter by job type
 *       - in: query
 *         name: priority
 *         schema:
 *           type: string
 *           enum: [low, normal, high, urgent]
 *         description: Filter by priority
 *     responses:
 *       200:
 *         description: Job list retrieved
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 jobs:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Job'
 *                 count:
 *                   type: integer
 *                   example: 8
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
// GET /api/jobs
// Admin / Scheduler  → all jobs
// Technician         → their own jobs only (same as /my-jobs)
//
// Having a single endpoint that auto-scopes by role means the Flutter
// app can always call GET /api/jobs without needing to know which
// endpoint to use — but we keep /my-jobs for explicit use too.
// ==========================================
router.get('/', verifyToken, async (req, res) => {
  try {
    const { status, job_type, priority } = req.query;
    const filters = {};
    if (status)   filters.status   = status;
    if (job_type) filters.job_type = job_type;
    if (priority) filters.priority = priority;

    let jobs;

    if (req.user.role === 'technician') {
      // Technicians only see jobs they are assigned to
      jobs = await Job.getJobsByTechnician(req.user.id, filters);
    } else {
      // Admin / Scheduler / Dispatcher see everything
      jobs = await Job.getAllJobs(filters);
    }

    res.json({ success: true, jobs, count: jobs.length });
  } catch (error) {
    log.error({ err: error }, 'GET /jobs error');
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @swagger
 * /jobs/my-jobs:
 *   get:
 *     tags: [Jobs]
 *     summary: Get current user's assigned jobs
 *     description: Returns only the jobs assigned to the authenticated user (driver/technician). Equivalent to GET /jobs for technician roles but explicit.
 *     security:
 *       - ApiKeyAuth: []
 *     parameters:
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [pending, assigned, in_progress, completed, cancelled]
 *         description: Filter by job status
 *     responses:
 *       200:
 *         description: Jobs list retrieved
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 jobs:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Job'
 *                 count:
 *                   type: integer
 *                   example: 3
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
// GET /api/jobs/my-jobs
// Explicit endpoint for technician's own jobs.
// MUST be declared before /:id so Express does not treat the
// literal string "my-jobs" as a numeric job ID parameter.
// ==========================================
router.get('/my-jobs', verifyToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const filters = {};
    if (req.query.status) filters.status = req.query.status;

    const jobs = await Job.getJobsByTechnician(userId, filters);
    res.json({ success: true, jobs, count: jobs.length });
  } catch (error) {
    log.error({ err: error }, 'GET /jobs/my-jobs error');
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @swagger
 * /jobs/{id}:
 *   get:
 *     tags: [Jobs]
 *     summary: Get a single job by ID
 *     description: Returns job details. Technicians can only view jobs they are assigned to; accessing another job returns 403.
 *     security:
 *       - ApiKeyAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Job ID
 *     responses:
 *       200:
 *         description: Job found
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 job:
 *                   $ref: '#/components/schemas/Job'
 *       400:
 *         description: Invalid job ID
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
 *         description: Technician not assigned to this job
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       404:
 *         description: Job not found
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
// GET /api/jobs/:id
// Any authenticated user can view a single job by ID.
// Technicians will see their driver entry highlighted in the
// technicians_json array returned by Job.getJobById().
// ==========================================
router.get('/:id', verifyToken, async (req, res) => {
  try {
    const jobId = parseInt(req.params.id);
    if (isNaN(jobId)) {
      return res.status(400).json({ success: false, error: 'Invalid job ID' });
    }

    const job = await Job.getJobById(jobId);
    if (!job) {
      return res.status(404).json({ success: false, error: 'Job not found' });
    }

    // For technicians: verify they are actually assigned to this job
    // before returning it (prevents URL-guessing access to other jobs).
    if (req.user.role === 'technician') {
      const technicianIds = Array.isArray(job.technicians_json)
        ? job.technicians_json.map(t => t.id)
        : [];
      const isAssigned =
        technicianIds.includes(req.user.id) ||
        job.driver_id === req.user.id;

      if (!isAssigned) {
        return res.status(403).json({
          success: false,
          error: 'You are not assigned to this job',
        });
      }
    }

    res.json({ success: true, job });
  } catch (error) {
    log.error({ err: error }, 'GET /jobs/:id error');
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @swagger
 * /jobs:
 *   post:
 *     tags: [Jobs]
 *     summary: Create a new job
 *     description: Creates a new job. Optionally include technician_ids to assign drivers immediately on creation.
 *     security:
 *       - ApiKeyAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [job_type, customer_name, customer_address, scheduled_date, scheduled_time_start, scheduled_time_end, estimated_duration_minutes]
 *             properties:
 *               job_type:
 *                 type: string
 *                 enum: [installation, delivery, miscellaneous]
 *                 example: installation
 *               customer_name:
 *                 type: string
 *                 example: Acme Corp
 *               customer_address:
 *                 type: string
 *                 example: 123 Main St, Johannesburg
 *               scheduled_date:
 *                 type: string
 *                 format: date
 *                 example: '2026-03-25'
 *               scheduled_time_start:
 *                 type: string
 *                 example: '09:00'
 *               scheduled_time_end:
 *                 type: string
 *                 example: '11:00'
 *               estimated_duration_minutes:
 *                 type: integer
 *                 example: 120
 *               priority:
 *                 type: string
 *                 enum: [low, normal, high, urgent]
 *                 example: normal
 *               destination_lat:
 *                 type: number
 *                 example: -26.2041
 *               destination_lng:
 *                 type: number
 *                 example: 28.0473
 *               technician_ids:
 *                 type: array
 *                 items:
 *                   type: integer
 *                 example: [3, 7]
 *     responses:
 *       201:
 *         description: Job created successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 job:
 *                   $ref: '#/components/schemas/Job'
 *                 message:
 *                   type: string
 *                   example: Job created successfully
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
// ==========================================
// POST /api/jobs
// Create a new job.
// Body may include technician_ids: [3, 7] to assign drivers immediately.
// ==========================================
router.post('/', verifyToken, createJobValidation, validate, async (req, res) => {
  try {
    const job = await Job.createJob(req.body);
    res.status(201).json({
      success: true,
      job,
      message: 'Job created successfully',
    });
  } catch (error) {
    log.error({ err: error }, 'POST /jobs error');
    res.status(400).json({ success: false, error: error.message });
  }
});

/**
 * @swagger
 * /jobs/{id}/technicians:
 *   put:
 *     tags: [Jobs]
 *     summary: Replace driver/technician list on a job
 *     description: Replaces the full set of drivers/technicians assigned to a job. Does not change the vehicle assignment. Pass technician_ids as empty array to clear all drivers. Admin can send force_override=true to bypass scheduling conflicts.
 *     security:
 *       - ApiKeyAuth: []
 *     parameters:
 *       - in: path
 *         name: id
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
 *             required: [assigned_by]
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
 *                 description: Admin only — bypass scheduling conflict check
 *                 example: false
 *     responses:
 *       200:
 *         description: Technicians assigned
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
 *                   example: 2 driver(s)/technician(s) assigned to job
 *                 job:
 *                   $ref: '#/components/schemas/Job'
 *       400:
 *         description: Invalid job ID or missing assigned_by
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
 *         description: Job not found
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
// PUT /api/jobs/:id/technicians
// Replace the full driver/technician list on a job.
// Does NOT change the vehicle assignment.
// Body: { "technician_ids": [3, 7], "assigned_by": 1 }
// Pass technician_ids: [] to clear all drivers.
// ==========================================
router.put('/:id/technicians', verifyToken, async (req, res) => {
  try {
    const jobId = parseInt(req.params.id);
    if (isNaN(jobId)) {
      return res.status(400).json({ success: false, message: 'Invalid job ID' });
    }

    // BUG 3 FIX: Read force_override from the request body.
    // When an admin deliberately selects a driver who is already booked
    // on another overlapping job, the Flutter screen sends force_override: true.
    // Without reading this flag, isAdminOverride was always false because the
    // admin's intent was never communicated to the backend.
    //
    // SECURITY: force_override only takes effect when req.user.role === 'admin'.
    // A non-admin cannot trigger override behaviour regardless of what they send.
    const { technician_ids = [], assigned_by, force_override = false } = req.body;

    if (!assigned_by) {
      return res.status(400).json({
        success: false,
        message: 'assigned_by is required',
      });
    }

    const job = await Job.getJobById(jobId);
    if (!job) {
      return res.status(404).json({ success: false, message: 'Job not found' });
    }

    const techIds = Array.isArray(technician_ids)
      ? technician_ids.map(Number).filter(Boolean)
      : [];

    // forceOverride requires BOTH conditions to be true:
    //   1. The caller is admin (role check — non-admins cannot override)
    //   2. The Flutter screen explicitly sent force_override: true (intent check)
    //
    // FIX: Route through JobAssignmentService.assignTechnicians(), NOT
    // Job.assignTechnicians() directly.
    //
    // The old code called Job.assignTechnicians() here, which skips the entire
    // service layer. That meant:
    //   • On the normal path  → conflict check in the service was never run
    //                           (it ran anyway inside the model, but only logged)
    //   • On the override path → removeDriversFromConflictingJobs() was never
    //                            called, so the driver was never freed from their
    //                            old job, and the INSERT then hit the same
    //                            conflict check in the service and threw.
    //
    // JobAssignmentService.assignTechnicians() is the correct entry point:
    //   forceOverride=false → runs checkDriversAvailability(), throws on conflict
    //   forceOverride=true  → calls removeDriversFromConflictingJobs() first,
    //                          then proceeds to the INSERT (driver is moved)
    const forceOverride = req.user.role === 'admin' && force_override === true;
    await JobAssignmentService.assignTechnicians(
      jobId,
      techIds,
      parseInt(assigned_by),
      forceOverride
    );

    const updated = await Job.getJobById(jobId);
    res.json({
      success: true,
      message: `${techIds.length} driver(s)/technician(s) assigned to job`,
      job    : updated,
    });
  } catch (error) {
    log.error({ err: error }, 'PUT /jobs/:id/technicians error');
    res.status(500).json({
      success: false,
      message: 'Server error',
      error  : error.message,
    });
  }
});

/**
 * @swagger
 * /jobs/{id}:
 *   put:
 *     tags: [Jobs]
 *     summary: Update a job (full edit)
 *     description: Updates all editable fields on a job. Requires admin or scheduler role.
 *     security:
 *       - ApiKeyAuth: []
 *     parameters:
 *       - in: path
 *         name: id
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
 *             required: [customer_name, customer_address, job_type, scheduled_date]
 *             properties:
 *               customer_name:
 *                 type: string
 *                 example: Acme Corp
 *               customer_address:
 *                 type: string
 *                 example: 123 Main St
 *               job_type:
 *                 type: string
 *                 enum: [installation, delivery, miscellaneous]
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
 *               estimated_duration_minutes:
 *                 type: integer
 *                 example: 120
 *               priority:
 *                 type: string
 *                 enum: [low, normal, high, urgent]
 *     responses:
 *       200:
 *         description: Job updated
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
 *                   example: Job updated successfully
 *                 job:
 *                   $ref: '#/components/schemas/Job'
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
 *       404:
 *         description: Job not found
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
// PUT /api/jobs/:id  — Full job edit (admin / scheduler)
// ==========================================
router.put('/:id', verifyToken, updateJobValidation, validate, async (req, res) => {
  try {
    const jobId = parseInt(req.params.id);
    if (isNaN(jobId)) {
      return res.status(400).json({ success: false, message: 'Invalid job ID' });
    }

    const {
      customer_name,
      customer_phone,
      customer_address,
      destination_lat,
      destination_lng,
      job_type,
      description,
      scheduled_date,
      scheduled_time_start,
      scheduled_time_end,
      estimated_duration_minutes,
      priority,
    } = req.body;

    if (!customer_name || !customer_address || !job_type || !scheduled_date) {
      return res.status(400).json({
        success: false,
        message:
          'customer_name, customer_address, job_type and scheduled_date are required',
      });
    }

    if (!/^\d{4}-\d{2}-\d{2}$/.test(scheduled_date)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid date format. Use YYYY-MM-DD',
      });
    }

    const [result] = await db.query(
      `UPDATE jobs SET
         customer_name               = ?,
         customer_phone              = ?,
         customer_address            = ?,
         destination_lat             = ?,
         destination_lng             = ?,
         job_type                    = ?,
         description                 = ?,
         scheduled_date              = ?,
         scheduled_time_start        = ?,
         scheduled_time_end          = ?,
         estimated_duration_minutes  = ?,
         priority                    = ?,
         updated_at                  = NOW()
       WHERE id = ?`,
      [
        customer_name,
        customer_phone             || null,
        customer_address,
        destination_lat            || null,
        destination_lng            || null,
        job_type,
        description                || null,
        scheduled_date,
        scheduled_time_start,
        scheduled_time_end,
        estimated_duration_minutes,
        priority                   || 'normal',
        jobId,
      ]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'Job not found' });
    }

    const job = await Job.getJobById(jobId);
    res.json({ success: true, message: 'Job updated successfully', job });
  } catch (error) {
    log.error({ err: error }, 'PUT /jobs/:id error');
    res.status(500).json({
      success: false,
      message: 'Server error',
      error  : error.message,
    });
  }
});

/**
 * @swagger
 * /jobs/{id}/schedule:
 *   put:
 *     tags: [Jobs]
 *     summary: Update job schedule (date/time only)
 *     description: Updates only the schedule fields (date, start time, end time, duration) without touching other job fields. Useful for rescheduling without a full edit.
 *     security:
 *       - ApiKeyAuth: []
 *     parameters:
 *       - in: path
 *         name: id
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
 *             required: [scheduled_date]
 *             properties:
 *               scheduled_date:
 *                 type: string
 *                 format: date
 *                 example: '2026-03-26'
 *               scheduled_time_start:
 *                 type: string
 *                 example: '10:00:00'
 *               scheduled_time_end:
 *                 type: string
 *                 example: '12:00:00'
 *               estimated_duration_minutes:
 *                 type: integer
 *                 example: 120
 *     responses:
 *       200:
 *         description: Schedule updated
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
 *                   example: Job schedule updated
 *                 job:
 *                   $ref: '#/components/schemas/Job'
 *       400:
 *         description: Invalid date format
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
 *         description: Job not found
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
// PUT /api/jobs/:id/schedule  — Update time/date only
// ==========================================
router.put('/:id/schedule', verifyToken, async (req, res) => {
  try {
    const jobId = parseInt(req.params.id);
    if (isNaN(jobId)) {
      return res.status(400).json({ success: false, message: 'Invalid job ID' });
    }

    const {
      scheduled_date,
      scheduled_time_start,
      scheduled_time_end,
      estimated_duration_minutes,
    } = req.body;

    if (!scheduled_date || !/^\d{4}-\d{2}-\d{2}$/.test(scheduled_date)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid date format. Use YYYY-MM-DD',
      });
    }

    const [result] = await db.query(
      `UPDATE jobs
       SET scheduled_date              = ?,
           scheduled_time_start        = ?,
           scheduled_time_end          = ?,
           estimated_duration_minutes  = ?,
           updated_at                  = NOW()
       WHERE id = ?`,
      [
        scheduled_date,
        scheduled_time_start,
        scheduled_time_end,
        estimated_duration_minutes,
        jobId,
      ]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'Job not found' });
    }

    const job = await Job.getJobById(jobId);
    res.json({ success: true, message: 'Job schedule updated', job });
  } catch (error) {
    log.error({ err: error }, 'PUT /jobs/:id/schedule error');
    res.status(500).json({
      success: false,
      message: 'Server error',
      error  : error.message,
    });
  }
});


/**
 * @swagger
 * /jobs/{id}/vehicle:
 *   delete:
 *     tags: [Jobs]
 *     summary: Remove vehicle assignment from a job (admin only)
 *     description: Unassigns the vehicle from the job. If the job status was 'assigned', it reverts to 'pending'. Only administrators can perform this action.
 *     security:
 *       - ApiKeyAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Job ID
 *     responses:
 *       200:
 *         description: Vehicle unassigned
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
 *                   example: Vehicle unassigned. Job reverted to Pending.
 *                 job:
 *                   $ref: '#/components/schemas/Job'
 *       400:
 *         description: Invalid job ID
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
 *         description: Admin role required
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       404:
 *         description: Job not found
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
// DELETE /api/jobs/:id/vehicle  — admin only
// Removes the vehicle assignment from a job.
// If the job was 'assigned', it reverts to 'pending'.
// ==========================================
router.delete('/:id/vehicle', verifyToken, async (req, res) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({
      success: false,
      message: 'Only administrators can remove vehicle assignments',
    });
  }

  try {
    const jobId = parseInt(req.params.id);
    if (isNaN(jobId)) {
      return res.status(400).json({ success: false, message: 'Invalid job ID' });
    }

    const job = await Job.getJobById(jobId);
    if (!job) {
      return res.status(404).json({ success: false, message: 'Job not found' });
    }

    // Remove the vehicle assignment row
    await db.query('DELETE FROM job_assignments WHERE job_id = ?', [jobId]);

    // Revert status from 'assigned' → 'pending' so the job is re-schedulable
    await db.query(
      `UPDATE jobs
       SET current_status = 'pending', updated_at = NOW()
       WHERE id = ? AND current_status = 'assigned'`,
      [jobId]
    );

    // Log the status change
    await db.query(
      `INSERT INTO job_status_history (job_id, status, changed_by, reason, created_at)
       VALUES (?, 'pending', ?, 'Vehicle unassigned by admin', NOW())`,
      [jobId, req.user.id]
    ).catch(() => {}); // non-fatal if history table not present

    const updated = await Job.getJobById(jobId);
    res.json({
      success: true,
      message: 'Vehicle unassigned. Job reverted to Pending.',
      job: updated,
    });
  } catch (error) {
    log.error({ err: error }, 'DELETE /jobs/:id/vehicle error');
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @swagger
 * /jobs/{id}/swap-vehicle:
 *   put:
 *     tags: [Jobs]
 *     summary: Swap vehicle on a job (scheduler/admin)
 *     description: Swaps the vehicle assigned to a job with a new vehicle. Checks availability before swapping. Requires assignments:update permission (admin or scheduler).
 *     security:
 *       - ApiKeyAuth: []
 *     parameters:
 *       - in: path
 *         name: id
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
 *             required: [new_vehicle_id]
 *             properties:
 *               new_vehicle_id:
 *                 type: integer
 *                 example: 4
 *               note:
 *                 type: string
 *                 example: Swapped due to breakdown
 *     responses:
 *       200:
 *         description: Vehicle swapped successfully
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
 *                   example: Vehicle swapped successfully
 *                 vehicle:
 *                   $ref: '#/components/schemas/Vehicle'
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
 *         description: Insufficient permissions
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       404:
 *         description: Job or vehicle not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       409:
 *         description: Vehicle not available for this time slot
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
// PUT /api/jobs/:id/swap-vehicle — SCHED-02
// Scheduler or admin can swap the vehicle on an existing job assignment
// ============================================
router.put('/:id/swap-vehicle',
  verifyToken,
  requirePermission('assignments:update'),
  body('new_vehicle_id').isInt({ min: 1 }).withMessage('new_vehicle_id must be a positive integer'),
  body('note').optional().isString().trim().isLength({ max: 500 }),
  validate,
  async (req, res) => {
    const jobId = parseInt(req.params.id);
    const { new_vehicle_id, note } = req.body;
    try {
      // 1. Get job details to check date/time
      const [jobRows] = await db.query(
        'SELECT id, scheduled_date, scheduled_time_start, scheduled_time_end, current_status FROM jobs WHERE id = ?',
        [jobId]
      );
      if (!jobRows.length) return res.status(404).json({ success: false, message: 'Job not found' });
      const job = jobRows[0];

      // 2. Check vehicle exists and is active
      const [vRows] = await db.query('SELECT id, vehicle_name FROM vehicles WHERE id = ? AND is_active = 1', [new_vehicle_id]);
      if (!vRows.length) return res.status(404).json({ success: false, message: 'Vehicle not found or inactive' });

      // 3. Check new vehicle is available (not assigned to another job at this time)
      const Vehicle = require('../models/Vehicle');
      const available = await Vehicle.getAvailableVehicles(
        job.scheduled_date, job.scheduled_time_start, job.scheduled_time_end
      );
      const isAvailable = available.some(v => v.id === new_vehicle_id);
      // Also allow if the vehicle is the one currently assigned to this job
      const [currentAssignment] = await db.query(
        'SELECT vehicle_id FROM job_assignments WHERE job_id = ?', [jobId]
      );
      const currentVehicleId = currentAssignment.length ? currentAssignment[0].vehicle_id : null;
      if (!isAvailable && currentVehicleId !== new_vehicle_id) {
        return res.status(409).json({ success: false, message: 'Vehicle is not available for this time slot' });
      }

      // 4. Update assignment
      const noteSql    = note ? ', notes = ?' : '';
      const noteParams = note ? [note] : [];
      const [result] = await db.query(
        `UPDATE job_assignments SET vehicle_id = ?${noteSql} WHERE job_id = ?`,
        [new_vehicle_id, ...noteParams, jobId]
      );
      if (!result.affectedRows) {
        return res.status(404).json({ success: false, message: 'No assignment found for this job' });
      }

      log.info({ jobId, new_vehicle_id, swapped_by: req.user.id }, 'Vehicle swapped on job');
      res.json({ success: true, message: 'Vehicle swapped successfully', vehicle: vRows[0] });
    } catch (err) {
      log.error({ err }, 'PUT /api/jobs/:id/swap-vehicle error');
      res.status(500).json({ success: false, error: err.message });
    }
  }
);

module.exports = router;