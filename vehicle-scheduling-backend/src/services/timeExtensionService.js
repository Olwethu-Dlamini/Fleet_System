// ============================================
// FILE: src/services/timeExtensionService.js
// PURPOSE: Time extension workflow — request creation, impact analysis,
//          suggestion engine, approval/denial, notifications.
// Requirements: TIME-01, TIME-02, TIME-03, TIME-04, TIME-05, TIME-06, TIME-07
// ============================================

const db = require('../config/database');
const NotificationService = require('./notificationService');
const logger = require('../config/logger').child({ service: 'timeExtensionService' });

// ============================================
// HELPER: addMinutesToTime
// Adds N minutes to a HH:MM:SS time string and returns HH:MM:SS
// ============================================
function addMinutesToTime(timeStr, minutes) {
  const parts = timeStr.split(':');
  const hours = parseInt(parts[0], 10);
  const mins  = parseInt(parts[1], 10);
  const secs  = parseInt(parts[2] || '0', 10);

  let totalSeconds = hours * 3600 + mins * 60 + secs + minutes * 60;

  // Clamp to 23:59:59 to avoid wrapping (edge case for very long extensions)
  if (totalSeconds >= 86400) totalSeconds = 86399;

  const h = Math.floor(totalSeconds / 3600);
  const m = Math.floor((totalSeconds % 3600) / 60);
  const s = totalSeconds % 60;

  return [
    String(h).padStart(2, '0'),
    String(m).padStart(2, '0'),
    String(s).padStart(2, '0'),
  ].join(':');
}

class TimeExtensionService {

  // ============================================
  // createRequest
  // Creates a time extension request with one-active guard.
  // Runs impact analysis and suggestion generation AFTER committing
  // the request so the transaction is minimal.
  // ============================================
  /**
   * @param {object} params
   * @param {number} params.jobId
   * @param {number} params.requestedBy   - user ID of the driver/technician
   * @param {number} params.durationMinutes
   * @param {string} params.reason
   * @param {number} params.tenantId
   * @returns {{ request, affectedJobs, suggestions }}
   */
  static async createRequest({ jobId, requestedBy, durationMinutes, reason, tenantId }) {
    let request = null;
    let job     = null;

    // ---- Transaction: validate + INSERT ----
    const connection = await db.getConnection();
    try {
      await connection.beginTransaction();

      // 1. Verify job exists, is in_progress, belongs to tenant — lock the row
      const [jobRows] = await connection.query(
        `SELECT id, job_number, scheduled_date, scheduled_time_start, scheduled_time_end,
                estimated_duration_minutes
         FROM jobs
         WHERE id = ? AND tenant_id = ? AND current_status = 'in_progress'
         FOR UPDATE`,
        [jobId, tenantId]
      );

      if (jobRows.length === 0) {
        await connection.rollback();
        const err = new Error('Job not found, not in progress, or does not belong to your organisation');
        err.statusCode = 400;
        throw err;
      }

      job = jobRows[0];

      // 2. One-active-request guard (SELECT FOR UPDATE so concurrent inserts lose)
      const [existing] = await connection.query(
        `SELECT id FROM time_extension_requests
         WHERE job_id = ? AND status = 'pending'
         LIMIT 1
         FOR UPDATE`,
        [jobId]
      );

      if (existing.length > 0) {
        await connection.rollback();
        const err = new Error('A time extension request is already pending for this job');
        err.statusCode = 409;
        throw err;
      }

      // 3. Verify requestedBy is an assigned driver or technician on this job
      const [assignment] = await connection.query(
        `SELECT 1
         FROM job_technicians
         WHERE job_id = ? AND user_id = ?
         UNION
         SELECT 1
         FROM job_assignments
         WHERE job_id = ? AND driver_id = ?
         LIMIT 1`,
        [jobId, requestedBy, jobId, requestedBy]
      );

      if (assignment.length === 0) {
        await connection.rollback();
        const err = new Error('You are not assigned to this job');
        err.statusCode = 403;
        throw err;
      }

      // 4. INSERT the request
      const [insertResult] = await connection.query(
        `INSERT INTO time_extension_requests
           (tenant_id, job_id, requested_by, duration_minutes, reason, status)
         VALUES (?, ?, ?, ?, ?, 'pending')`,
        [tenantId, jobId, requestedBy, durationMinutes, reason]
      );

      request = {
        id: insertResult.insertId,
        tenant_id: tenantId,
        job_id: jobId,
        requested_by: requestedBy,
        duration_minutes: durationMinutes,
        reason,
        status: 'pending',
      };

      await connection.commit();
    } catch (err) {
      await connection.rollback().catch(() => {});
      throw err;
    } finally {
      connection.release();
    }

    // ---- Outside transaction: impact analysis + suggestions + notifications ----
    let affectedJobs = [];
    let suggestions  = [];

    try {
      // Compute new end time
      const newEndTime = addMinutesToTime(job.scheduled_time_end, durationMinutes);

      affectedJobs = await TimeExtensionService.analyzeImpact(
        jobId, newEndTime, job.scheduled_date, tenantId, job.scheduled_time_end
      );

      suggestions = await TimeExtensionService._buildSuggestions(
        job, durationMinutes, affectedJobs, tenantId
      );

      // Insert reschedule_options rows
      for (const suggestion of suggestions) {
        const [res] = await db.query(
          `INSERT INTO reschedule_options (request_id, tenant_id, type, label, changes_json)
           VALUES (?, ?, ?, ?, ?)`,
          [request.id, tenantId, suggestion.type, suggestion.label, JSON.stringify(suggestion.changes)]
        );
        suggestion.id = res.insertId;
      }

      // Notify schedulers
      await TimeExtensionService._notifySchedulers(
        jobId, job.job_number, request.id, durationMinutes, tenantId
      );
    } catch (err) {
      // Non-fatal: request is committed, analysis failures should not surface 500
      logger.error({ err, requestId: request.id }, 'Post-commit steps failed for time extension request');
    }

    return { request, affectedJobs, suggestions };
  }

  // ============================================
  // analyzeImpact
  // Finds same-day jobs that share the driver, vehicle, or technician with
  // the source job and whose time range overlaps the extension window
  // [sourceJobCurrentEnd, newEndTime].
  // ============================================
  /**
   * @param {number} jobId                - source job to exclude
   * @param {string} newEndTime           - HH:MM:SS new end time after extension
   * @param {string} scheduledDate        - YYYY-MM-DD
   * @param {number} tenantId
   * @param {string} sourceJobCurrentEnd  - HH:MM:SS current end time of source job
   * @returns {Array}
   */
  static async analyzeImpact(jobId, newEndTime, scheduledDate, tenantId, sourceJobCurrentEnd) {
    const [affected] = await db.query(
      `SELECT DISTINCT
         j.id, j.job_number, j.scheduled_date, j.scheduled_time_start, j.scheduled_time_end,
         j.estimated_duration_minutes, ja.vehicle_id, ja.driver_id
       FROM jobs j
       LEFT JOIN job_assignments ja ON ja.job_id = j.id
       WHERE j.tenant_id = ?
         AND j.scheduled_date = ?
         AND j.id != ?
         AND j.current_status NOT IN ('completed', 'cancelled')
         AND j.scheduled_time_start < ?
         AND j.scheduled_time_end > ?
         AND (
           ja.vehicle_id = (SELECT vehicle_id FROM job_assignments WHERE job_id = ? LIMIT 1)
           OR EXISTS (
             SELECT 1
             FROM job_technicians jt
             JOIN job_technicians jt2 ON jt2.user_id = jt.user_id AND jt2.job_id = j.id
             WHERE jt.job_id = ?
           )
           OR ja.driver_id IN (
             SELECT driver_id FROM job_assignments WHERE job_id = ? AND driver_id IS NOT NULL
           )
         )
       ORDER BY j.scheduled_time_start ASC`,
      [tenantId, scheduledDate, jobId, newEndTime, sourceJobCurrentEnd, jobId, jobId, jobId]
    );

    return affected;
  }

  // ============================================
  // getDaySchedule
  // Returns all jobs for the same day as the source job, grouped by
  // driver/technician personnel. Used by the scheduler approval screen.
  // ============================================
  /**
   * @param {number} jobId
   * @param {number} tenantId
   * @returns {{ date: string, personnel: Array }}
   */
  static async getDaySchedule(jobId, tenantId) {
    // Fetch the source job's scheduled_date
    const [jobRows] = await db.query(
      `SELECT scheduled_date FROM jobs WHERE id = ? AND tenant_id = ? LIMIT 1`,
      [jobId, tenantId]
    );

    if (jobRows.length === 0) {
      const err = new Error('Job not found');
      err.statusCode = 404;
      throw err;
    }

    const scheduledDate = jobRows[0].scheduled_date;

    // Fetch all jobs for that date (excluding cancelled), with driver and technician info
    const [rows] = await db.query(
      `SELECT j.id, j.job_number, j.scheduled_time_start, j.scheduled_time_end,
              j.current_status, j.customer_name,
              ja.driver_id, ja.vehicle_id,
              CONCAT(COALESCE(ud.first_name, ''), ' ', COALESCE(ud.last_name, '')) AS driver_name,
              (SELECT GROUP_CONCAT(CONCAT(COALESCE(u2.first_name, ''), ' ', COALESCE(u2.last_name, '')) SEPARATOR ', ')
               FROM job_technicians jt2
               JOIN users u2 ON u2.id = jt2.user_id
               WHERE jt2.job_id = j.id) AS technician_names,
              (SELECT GROUP_CONCAT(jt3.user_id) FROM job_technicians jt3 WHERE jt3.job_id = j.id) AS technician_ids
       FROM jobs j
       LEFT JOIN job_assignments ja ON ja.job_id = j.id
       LEFT JOIN users ud ON ud.id = ja.driver_id
       WHERE j.tenant_id = ? AND j.scheduled_date = ? AND j.current_status != 'cancelled'
       ORDER BY j.scheduled_time_start ASC`,
      [tenantId, scheduledDate]
    );

    // Group jobs by personnel (driver first, then technicians)
    const personnelMap = new Map();

    for (const row of rows) {
      const jobEntry = {
        id: row.id,
        job_number: row.job_number,
        scheduled_time_start: row.scheduled_time_start,
        scheduled_time_end: row.scheduled_time_end,
        current_status: row.current_status,
        customer_name: row.customer_name,
        vehicle_id: row.vehicle_id,
      };

      // Add under driver if present
      if (row.driver_id) {
        const key = `driver_${row.driver_id}`;
        if (!personnelMap.has(key)) {
          const rawName = (row.driver_name || '').trim();
          personnelMap.set(key, {
            id: row.driver_id,
            name: rawName || `Driver #${row.driver_id}`,
            role: 'driver',
            jobs: [],
          });
        }
        personnelMap.get(key).jobs.push(jobEntry);
      }

      // Add under each technician if present (avoids duplication from driver already added)
      if (row.technician_ids) {
        const techIds = row.technician_ids.split(',').map(id => parseInt(id.trim(), 10));
        const techNameList = row.technician_names
          ? row.technician_names.split(',').map(n => n.trim())
          : [];

        techIds.forEach((techId, idx) => {
          // Skip if this technician is already the driver (same person)
          if (techId === row.driver_id) return;

          const key = `tech_${techId}`;
          if (!personnelMap.has(key)) {
            personnelMap.set(key, {
              id: techId,
              name: techNameList[idx] || `Technician #${techId}`,
              role: 'technician',
              jobs: [],
            });
          }
          personnelMap.get(key).jobs.push(jobEntry);
        });
      }
    }

    return {
      date: scheduledDate,
      personnel: Array.from(personnelMap.values()),
    };
  }

  // ============================================
  // _buildSuggestions
  // Generates 2–3 rescheduling options for the scheduler.
  // ============================================
  /**
   * @param {object} sourceJob        - row from jobs table (includes scheduled_time_*)
   * @param {number} extensionMinutes
   * @param {Array}  affectedJobs     - result of analyzeImpact
   * @param {number} tenantId
   * @returns {Array} suggestions array with { type, label, changes }
   */
  static async _buildSuggestions(sourceJob, extensionMinutes, affectedJobs, tenantId) {
    const suggestions = [];

    // 1. Push suggestion — always included
    const pushChanges = affectedJobs.map(j => ({
      jobId:        j.id,
      jobNumber:    j.job_number,
      currentStart: j.scheduled_time_start,
      currentEnd:   j.scheduled_time_end,
      newStart:     addMinutesToTime(j.scheduled_time_start, extensionMinutes),
      newEnd:       addMinutesToTime(j.scheduled_time_end,   extensionMinutes),
    }));

    suggestions.push({
      type:    'push',
      label:   `Push all later jobs by ${extensionMinutes} min`,
      changes: pushChanges,
    });

    // 2. Swap suggestion — only if a free driver/technician is available
    try {
      // Determine current driver on source job
      const [sourceAssignment] = await db.query(
        `SELECT driver_id FROM job_assignments WHERE job_id = ? LIMIT 1`,
        [sourceJob.id]
      );
      const currentDriverId = sourceAssignment.length > 0 ? sourceAssignment[0].driver_id : null;

      // New end time for overlap check (in seconds since midnight)
      const [h, m, s] = sourceJob.scheduled_time_end.split(':').map(Number);
      const sourceEndSec = h * 3600 + m * 60 + s + extensionMinutes * 60;

      // Source start in seconds
      const [sh, sm, ss] = sourceJob.scheduled_time_start.split(':').map(Number);
      const sourceStartSec = sh * 3600 + sm * 60 + ss;

      // Find drivers not busy during the extension window
      const [availableDrivers] = await db.query(
        `SELECT DISTINCT u.id, u.first_name, u.last_name
         FROM users u
         WHERE u.tenant_id = ?
           AND u.role IN ('driver', 'technician')
           AND u.is_active = 1
           AND u.id != ?
           AND u.id NOT IN (
             SELECT jt.user_id
             FROM job_technicians jt
             JOIN jobs j2 ON j2.id = jt.job_id
             WHERE j2.scheduled_date = ?
               AND j2.current_status NOT IN ('completed', 'cancelled')
               AND TIME_TO_SEC(j2.scheduled_time_start) < ?
               AND TIME_TO_SEC(j2.scheduled_time_end) > ?
           )`,
        [tenantId, currentDriverId || 0, sourceJob.scheduled_date, sourceEndSec, sourceStartSec]
      );

      if (availableDrivers.length > 0) {
        const driver = availableDrivers[0];
        const driverName = `${driver.first_name || ''} ${driver.last_name || ''}`.trim() ||
                           `Driver #${driver.id}`;
        suggestions.push({
          type:    'swap',
          label:   `Reassign to ${driverName}`,
          changes: [],
        });
      }
    } catch (err) {
      logger.warn({ err }, 'Swap suggestion check failed — skipping swap option');
    }

    // 3. Custom suggestion — always included
    suggestions.push({
      type:    'custom',
      label:   'Enter custom times',
      changes: [],
    });

    return suggestions;
  }

  // ============================================
  // _notifySchedulers
  // Inserts in-app notification rows and sends FCM to all admin/scheduler/dispatcher users.
  // ============================================
  static async _notifySchedulers(jobId, jobNumber, requestId, durationMinutes, tenantId) {
    const [schedulers] = await db.query(
      `SELECT id FROM users
       WHERE tenant_id = ? AND role IN ('admin', 'scheduler', 'dispatcher') AND is_active = 1`,
      [tenantId]
    );

    const title = 'Time Extension Request';
    const body  = `${jobNumber}: ${durationMinutes} min extension requested`;

    for (const scheduler of schedulers) {
      try {
        await db.query(
          `INSERT INTO notifications (tenant_id, user_id, job_id, type, title, body)
           VALUES (?, ?, ?, 'time_extension_requested', ?, ?)`,
          [tenantId, scheduler.id, jobId, title, body]
        );

        await NotificationService.sendTopicNotification(
          `scheduler_${scheduler.id}`,
          title,
          body,
          { jobId: String(jobId), requestId: String(requestId), type: 'time_extension_requested' }
        );
      } catch (err) {
        logger.warn({ err, schedulerId: scheduler.id }, 'Failed to notify scheduler');
      }
    }
  }

  // ============================================
  // getPendingRequests
  // Returns all pending time extension requests for a tenant, with job + requester info.
  // ============================================
  /**
   * @param {number} tenantId
   * @returns {Array<object>} list of pending requests with job_number and requester_name
   */
  static async getPendingRequests(tenantId) {
    const [rows] = await db.query(
      `SELECT ter.*, j.job_number, j.customer_name,
              u.full_name AS requester_name
       FROM time_extension_requests ter
       JOIN jobs j ON j.id = ter.job_id
       JOIN users u ON u.id = ter.requested_by
       WHERE ter.tenant_id = ? AND ter.status = 'pending'
       ORDER BY ter.created_at DESC`,
      [tenantId]
    );
    return rows;
  }

  // ============================================
  // getActiveRequest
  // Returns the current pending request (with suggestions) for a job, or null.
  // ============================================
  /**
   * @param {number} jobId
   * @param {number} tenantId
   * @returns {{ request, suggestions } | { request: null }}
   */
  static async getActiveRequest(jobId, tenantId) {
    const [requests] = await db.query(
      `SELECT * FROM time_extension_requests
       WHERE job_id = ? AND tenant_id = ? AND status = 'pending'
       LIMIT 1`,
      [jobId, tenantId]
    );

    if (requests.length === 0) {
      return { request: null, suggestions: [] };
    }

    const request = requests[0];

    const [suggestions] = await db.query(
      `SELECT * FROM reschedule_options
       WHERE request_id = ? AND tenant_id = ?
       ORDER BY id ASC`,
      [request.id, tenantId]
    );

    // Parse changes_json back to object
    const parsedSuggestions = suggestions.map(s => ({
      ...s,
      changes: (() => { try { return JSON.parse(s.changes_json); } catch (_) { return []; } })(),
    }));

    return { request, suggestions: parsedSuggestions };
  }

  // ============================================
  // approveRequest
  // Atomically updates source job + all affected jobs in one transaction.
  // Notifications sent AFTER commit.
  // ============================================
  /**
   * @param {number}      requestId
   * @param {number|null} suggestionId   - reschedule_options.id chosen by scheduler
   * @param {Array|null}  customChanges  - array of { jobId, newStart, newEnd } for custom type
   * @param {number}      approvedBy
   * @param {number}      tenantId
   */
  static async approveRequest(requestId, suggestionId, customChanges, approvedBy, tenantId) {
    let requestRow = null;
    let changes    = [];

    const connection = await db.getConnection();
    try {
      await connection.beginTransaction();

      // Lock the request + source job
      const [requests] = await connection.query(
        `SELECT ter.*, j.scheduled_time_end, j.estimated_duration_minutes, j.job_number,
                j.id AS source_job_id
         FROM time_extension_requests ter
         JOIN jobs j ON j.id = ter.job_id
         WHERE ter.id = ? AND ter.tenant_id = ? AND ter.status = 'pending'
         FOR UPDATE`,
        [requestId, tenantId]
      );

      if (requests.length === 0) {
        await connection.rollback();
        const err = new Error('Request not found or already processed');
        err.statusCode = 404;
        throw err;
      }

      requestRow = requests[0];

      // Resolve changes from suggestion or custom input
      if (suggestionId) {
        const [opts] = await connection.query(
          `SELECT changes_json FROM reschedule_options
           WHERE id = ? AND request_id = ?`,
          [suggestionId, requestId]
        );
        if (opts.length > 0) {
          try { changes = JSON.parse(opts[0].changes_json); } catch (_) { changes = []; }
        }
      } else if (customChanges && customChanges.length > 0) {
        changes = customChanges;
      }

      // Mark request approved
      await connection.query(
        `UPDATE time_extension_requests
         SET status = 'approved', approved_denied_by = ?, approved_denied_at = NOW(),
             selected_suggestion_id = ?
         WHERE id = ? AND tenant_id = ?`,
        [approvedBy, suggestionId || null, requestId, tenantId]
      );

      // Extend source job: add duration_minutes to scheduled_time_end and estimated_duration_minutes
      await connection.query(
        `UPDATE jobs
         SET scheduled_time_end = SEC_TO_TIME(TIME_TO_SEC(scheduled_time_end) + ? * 60),
             estimated_duration_minutes = estimated_duration_minutes + ?,
             updated_at = NOW()
         WHERE id = ? AND tenant_id = ?`,
        [requestRow.duration_minutes, requestRow.duration_minutes, requestRow.job_id, tenantId]
      );

      // Apply changes to affected jobs
      for (const change of changes) {
        if (!change.jobId || !change.newStart || !change.newEnd) continue;
        await connection.query(
          `UPDATE jobs
           SET scheduled_time_start = ?, scheduled_time_end = ?, updated_at = NOW()
           WHERE id = ? AND tenant_id = ?`,
          [change.newStart, change.newEnd, change.jobId, tenantId]
        );
      }

      await connection.commit();
    } catch (err) {
      await connection.rollback().catch(() => {});
      throw err;
    } finally {
      connection.release();
    }

    // Notify all affected parties AFTER commit
    try {
      await TimeExtensionService._notifyAffectedParties(requestRow, changes, tenantId);
    } catch (err) {
      logger.warn({ err, requestId }, 'Post-approval notifications failed');
    }
  }

  // ============================================
  // denyRequest
  // Updates status to denied and notifies driver + technicians.
  // ============================================
  /**
   * @param {number}      requestId
   * @param {string|null} reason
   * @param {number}      deniedBy
   * @param {number}      tenantId
   */
  static async denyRequest(requestId, reason, deniedBy, tenantId) {
    const [result] = await db.query(
      `UPDATE time_extension_requests
       SET status = 'denied', denial_reason = ?, approved_denied_by = ?, approved_denied_at = NOW()
       WHERE id = ? AND tenant_id = ? AND status = 'pending'`,
      [reason || null, deniedBy, requestId, tenantId]
    );

    if (result.affectedRows === 0) {
      const err = new Error('Request not found or already processed');
      err.statusCode = 404;
      throw err;
    }

    // Fetch request to get job_id for notification
    const [requests] = await db.query(
      `SELECT * FROM time_extension_requests WHERE id = ? AND tenant_id = ?`,
      [requestId, tenantId]
    );
    if (requests.length === 0) return;

    const req = requests[0];

    // Notify driver + technicians
    try {
      await TimeExtensionService._notifyJobPersonnel(
        req.job_id, tenantId,
        'Time Extension Denied',
        `Your time extension request has been denied`,
        'time_extension_denied'
      );
    } catch (err) {
      logger.warn({ err, requestId }, 'Denial notifications failed');
    }
  }

  // ============================================
  // _notifyAffectedParties
  // Notifies driver, technicians on source job, and drivers of affected jobs.
  // ============================================
  static async _notifyAffectedParties(request, changes, tenantId) {
    // Get driver_id and technician user_ids for source job
    const [sourcePersonnel] = await db.query(
      `SELECT ja.driver_id,
              (SELECT GROUP_CONCAT(jt.user_id) FROM job_technicians jt WHERE jt.job_id = ?) AS tech_ids
       FROM job_assignments ja
       WHERE ja.job_id = ?
       LIMIT 1`,
      [request.job_id, request.job_id]
    );

    let userIds = new Set();

    if (sourcePersonnel.length > 0) {
      if (sourcePersonnel[0].driver_id) userIds.add(sourcePersonnel[0].driver_id);
      if (sourcePersonnel[0].tech_ids) {
        sourcePersonnel[0].tech_ids.split(',').forEach(id => userIds.add(parseInt(id, 10)));
      }
    }

    // Get driver_ids for affected jobs from changes
    for (const change of changes) {
      if (!change.jobId) continue;
      const [asgn] = await db.query(
        `SELECT driver_id FROM job_assignments WHERE job_id = ? LIMIT 1`,
        [change.jobId]
      );
      if (asgn.length > 0 && asgn[0].driver_id) {
        userIds.add(asgn[0].driver_id);
      }
    }

    const title = 'Time Extension Approved';
    const body  = 'A time extension has been approved — check your updated schedule';

    for (const userId of userIds) {
      if (!userId) continue;
      try {
        await db.query(
          `INSERT INTO notifications (tenant_id, user_id, job_id, type, title, body)
           VALUES (?, ?, ?, 'time_extension_approved', ?, ?)`,
          [tenantId, userId, request.job_id, title, body]
        );

        await NotificationService.sendTopicNotification(
          `driver_${userId}`,
          title,
          body,
          { jobId: String(request.job_id), type: 'time_extension_approved' }
        );
      } catch (err) {
        logger.warn({ err, userId }, 'Failed to notify affected party');
      }
    }
  }

  // ============================================
  // _notifyJobPersonnel (helper for denyRequest)
  // Notifies all drivers/technicians assigned to a job.
  // ============================================
  static async _notifyJobPersonnel(jobId, tenantId, title, body, type) {
    // Get assigned driver
    const [assignments] = await db.query(
      `SELECT driver_id FROM job_assignments WHERE job_id = ? LIMIT 1`,
      [jobId]
    );

    // Get all technicians
    const [technicians] = await db.query(
      `SELECT user_id FROM job_technicians WHERE job_id = ?`,
      [jobId]
    );

    const userIds = new Set();
    if (assignments.length > 0 && assignments[0].driver_id) {
      userIds.add(assignments[0].driver_id);
    }
    technicians.forEach(t => userIds.add(t.user_id));

    for (const userId of userIds) {
      if (!userId) continue;
      try {
        await db.query(
          `INSERT INTO notifications (tenant_id, user_id, job_id, type, title, body)
           VALUES (?, ?, ?, ?, ?, ?)`,
          [tenantId, userId, jobId, type, title, body]
        );

        await NotificationService.sendTopicNotification(
          `driver_${userId}`,
          title,
          body,
          { jobId: String(jobId), type }
        );
      } catch (err) {
        logger.warn({ err, userId }, `Failed to notify user for ${type}`);
      }
    }
  }
}

module.exports = TimeExtensionService;
