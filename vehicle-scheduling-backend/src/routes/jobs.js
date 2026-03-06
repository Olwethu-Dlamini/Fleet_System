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
const Job       = require('../models/Job');
const db        = require('../config/database');
const { verifyToken } = require('../middleware/authMiddleware');

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
    console.error('GET /jobs error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

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
    console.error('GET /jobs/my-jobs error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

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
    console.error('GET /jobs/:id error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// ==========================================
// POST /api/jobs
// Create a new job.
// Body may include technician_ids: [3, 7] to assign drivers immediately.
// ==========================================
router.post('/', verifyToken, async (req, res) => {
  try {
    const job = await Job.createJob(req.body);
    res.status(201).json({
      success: true,
      job,
      message: 'Job created successfully',
    });
  } catch (error) {
    console.error('POST /jobs error:', error);
    res.status(400).json({ success: false, error: error.message });
  }
});

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

    const { technician_ids = [], assigned_by } = req.body;

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

    // Admin can force-assign drivers even if they have a conflicting job.
    const isAdminOverride = req.user.role === 'admin';
    await Job.assignTechnicians(jobId, techIds, parseInt(assigned_by), isAdminOverride);

    const updated = await Job.getJobById(jobId);
    res.json({
      success: true,
      message: `${techIds.length} driver(s)/technician(s) assigned to job`,
      job    : updated,
    });
  } catch (error) {
    console.error('PUT /jobs/:id/technicians error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error  : error.message,
    });
  }
});

// ==========================================
// PUT /api/jobs/:id  — Full job edit (admin / scheduler)
// ==========================================
router.put('/:id', verifyToken, async (req, res) => {
  try {
    const jobId = parseInt(req.params.id);
    if (isNaN(jobId)) {
      return res.status(400).json({ success: false, message: 'Invalid job ID' });
    }

    const {
      customer_name,
      customer_phone,
      customer_address,
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
    console.error('PUT /jobs/:id error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error  : error.message,
    });
  }
});

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
    console.error('PUT /jobs/:id/schedule error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error  : error.message,
    });
  }
});


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
    console.error('DELETE /jobs/:id/vehicle error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;