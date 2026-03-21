// ============================================
// FILE: src/models/Job.js
// PURPOSE: Job model - handles all job database operations
// LAYER: Data Layer (talks directly to MySQL)
// ============================================

const db = require('../config/database');
const logger = require('../config/logger').child({ service: 'Job' });

/**
 * Job Model
 * Handles all database operations for the jobs table
 * 
 * Jobs represent work orders: installations, deliveries, maintenance
 * Each job has a customer, location, time slot, and gets assigned to a vehicle
 */
class Job {

  // ==========================================
  // HELPER: _formatDateOnly
  // PURPOSE: Convert MySQL Date object OR string to plain 'YYYY-MM-DD'
  //
  // WHY THIS EXISTS:
  //   MySQL returns DATE columns as JavaScript Date objects.
  //   JSON.stringify calls .toISOString() on them, which shifts to UTC:
  //   '2026-02-23 00:00:00 UTC+2' → '2026-02-22T22:00:00.000Z'
  //   Flutter then parses the 22nd instead of the 23rd.
  //
  //   Fix: always convert to a plain 'YYYY-MM-DD' string on the Node side
  //   before the response leaves the server. We use LOCAL date methods
  //   (getFullYear/getMonth/getDate) — NOT UTC methods — so the date
  //   is never shifted by the server's timezone offset.
  // ==========================================
  static _formatDateOnly(value) {
    if (!value) return value;
    // Already a plain date string like '2026-02-23' — return as-is
    if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value)) {
      return value;
    }
    // JavaScript Date object (what MySQL driver returns for DATE columns)
    const d = new Date(value);
    if (isNaN(d.getTime())) return value; // unparseable — return original
    // Use LOCAL year/month/day — NOT getUTCFullYear etc — to preserve the date
    const y   = d.getFullYear();
    const m   = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
  }

  // Apply _formatDateOnly to scheduled_date on every row in an array
  static _fixDates(rows) {
    return rows.map(row => ({
      ...row,
      scheduled_date: Job._formatDateOnly(row.scheduled_date),
    }));
  }

  // Apply _formatDateOnly to a single row object
  static _fixDate(row) {
    if (!row) return row;
    return {
      ...row,
      scheduled_date: Job._formatDateOnly(row.scheduled_date),
    };
  }

  // ── Parse technicians_json on every row ─────────────────────────────────
  // MySQL 5.6 does not have JSON_ARRAYAGG / JSON_OBJECT.
  // We use GROUP_CONCAT instead, which produces a pipe-delimited string:
  //   "1|Alice,2|Bob"
  // This method converts that string into the same [{id, full_name}] array
  // shape that the Flutter model expects, so nothing else needs to change.
  static _parseTechnicians(rows) {
    return rows.map(row => {
      let technicians = [];
      if (row.technicians_json) {
        try {
          const raw = row.technicians_json;
          if (typeof raw === 'string' && raw.length > 0) {
            // Try JSON first (future-proof if DB is upgraded to 8.0+)
            if (raw.trim().startsWith('[')) {
              const parsed = JSON.parse(raw);
              if (Array.isArray(parsed)) technicians = parsed;
            } else {
              // GROUP_CONCAT format: "id|name,id|name"
              technicians = raw.split(',').map(entry => {
                const [id, ...nameParts] = entry.split('|');
                return { id: parseInt(id, 10) || 0, full_name: nameParts.join('|') };
              }).filter(t => t.id > 0);
            }
          } else if (Array.isArray(raw)) {
            technicians = raw;
          }
        } catch (_) {}
      }
      return { ...row, technicians_json: technicians };
    });
  }

  // ── MySQL 5.6-compatible technician subquery ─────────────────────────────
  // Replaces JSON_ARRAYAGG(JSON_OBJECT(...)) with GROUP_CONCAT.
  // Output format: "1|Alice,2|Bob"  (id|full_name pairs, comma-separated)
  // Alias MUST remain technicians_json so all callers stay unchanged.
  // Uses alias 'j' for the outer jobs table — all existing queries already do.
  static get _technicianSubquery() {
    return `(
      SELECT GROUP_CONCAT(jt2.user_id, '|', u2.full_name ORDER BY jt2.user_id SEPARATOR ',')
      FROM   job_technicians jt2
      JOIN   users u2 ON jt2.user_id = u2.id
      WHERE  jt2.job_id = j.id
    ) AS technicians_json`;
  }

  // ==========================================
  // FUNCTION: createJob
  // PURPOSE: Insert a new job into database
  // RETURNS: Newly created job object with ID
  // ==========================================
  /**
   * Create a new job in the database
   * 
   * @param {Object} jobData - Job information
   * @param {string} jobData.customer_name - Customer name
   * @param {string} jobData.customer_phone - Customer phone number
   * @param {string} jobData.customer_address - Job location/address
   * @param {string} jobData.job_type - Type: 'installation', 'delivery', or 'maintenance'
   * @param {string} jobData.description - Job description/notes
   * @param {string} jobData.scheduled_date - Date in 'YYYY-MM-DD' format
   * @param {string} jobData.scheduled_time_start - Start time 'HH:MM:SS' format
   * @param {string} jobData.scheduled_time_end - End time 'HH:MM:SS' format
   * @param {number} jobData.estimated_duration_minutes - Estimated duration
   * @param {string} jobData.priority - Priority: 'low', 'normal', 'high', 'urgent'
   * @param {number} jobData.created_by - User ID who created the job
   * @param {number[]} jobData.technician_ids - Optional array of technician user IDs
   * @returns {Promise<Object>} The newly created job with auto-generated fields
   */
  static async createJob(jobData) {
    try {
      // Destructure job data
      const {
        customer_name,
        customer_phone = null,
        customer_address,
        destination_lat = null, // ← NEW
        destination_lng = null, // ← NEW
        job_type,
        description = null,
        scheduled_date,
        scheduled_time_start,
        scheduled_time_end,
        estimated_duration_minutes,
        priority = 'normal',
        created_by,
        technician_ids = []   // ← NEW: optional array of user IDs
      } = jobData;

      // Generate unique job number (format: JOB-YYYY-NNNN)
      const jobNumber = await this.generateJobNumber();

      // SQL INSERT statement
      // current_status defaults to 'pending' in database
      const sql = `
        INSERT INTO jobs (
          job_number,
          job_type,
          customer_name,
          customer_phone,
          customer_address,
          destination_lat,
          destination_lng,
          description,
          scheduled_date,
          scheduled_time_start,
          scheduled_time_end,
          estimated_duration_minutes,
          priority,
          created_by
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `;

      // Execute INSERT query
      const [result] = await db.query(sql, [
        jobNumber,
        job_type,
        customer_name,
        customer_phone,
        customer_address,
        destination_lat,
        destination_lng,
        description,
        scheduled_date,
        scheduled_time_start,
        scheduled_time_end,
        estimated_duration_minutes,
        priority,
        created_by
      ]);

      // Get the auto-generated ID
      const newJobId = result.insertId;

      // ── NEW: assign technicians immediately if IDs were provided ──
      if (technician_ids.length > 0) {
        await Job.assignTechnicians(newJobId, technician_ids, created_by);
      }

      // Fetch and return the complete job object (date already fixed inside getJobById)
      const newJob = await this.getJobById(newJobId);
      return newJob;

    } catch (error) {
      logger.error({ err: error }, 'Error in Job.createJob');

      // Check for specific errors
      if (error.code === 'ER_DUP_ENTRY') {
        throw new Error('Job number already exists (duplicate entry)');
      }

      if (error.code === 'ER_NO_REFERENCED_ROW_2') {
        throw new Error('Invalid user ID - creator does not exist');
      }

      throw error;
    }
  }

  // ==========================================
  // FUNCTION: updateJob
  // PURPOSE: Update job details
  // RETURNS: Updated job object
  // ==========================================
  /**
   * Update job information
   * Only updates fields that are provided in the updates object
   * 
   * @param {number} id - The job ID
   * @param {Object} updates - Fields to update
   * @returns {Promise<Object>} Updated job object
   */
  static async updateJob(id, updates) {
    try {
      // Define which fields are allowed to be updated
      const allowedFields = [
        'customer_name',
        'customer_phone',
        'customer_address',
        'destination_lat', // ← NEW
        'destination_lng', // ← NEW
        'job_type',
        'description',
        'scheduled_date',
        'scheduled_time_start',
        'scheduled_time_end',
        'estimated_duration_minutes',
        'priority',
        'current_status'
      ];

      // Build dynamic UPDATE query
      const updateFields = [];
      const updateValues = [];

      // Loop through updates and build SQL
      for (const [key, value] of Object.entries(updates)) {
        if (allowedFields.includes(key)) {
          updateFields.push(`${key} = ?`);
          updateValues.push(value);
        }
      }

      // If no valid fields to update
      if (updateFields.length === 0) {
        throw new Error('No valid fields provided for update');
      }

      // Add job ID to values array (for WHERE clause)
      updateValues.push(id);

      // Build final SQL query
      const sql = `
        UPDATE jobs
        SET ${updateFields.join(', ')}
        WHERE id = ?
      `;

      // Execute UPDATE
      const [result] = await db.query(sql, updateValues);

      // Check if job exists
      if (result.affectedRows === 0) {
        throw new Error(`Job with ID ${id} not found`);
      }

      // Fetch and return updated job (date already fixed inside getJobById)
      const updatedJob = await this.getJobById(id);
      return updatedJob;

    } catch (error) {
      logger.error({ err: error, id }, 'Error in Job.updateJob');
      throw error;
    }
  }

  // ==========================================
  // FUNCTION: getJobsByDate
  // PURPOSE: Get all jobs scheduled for a specific date
  // RETURNS: Array of jobs for that date
  // ==========================================
  /**
   * Get all jobs scheduled for a specific date
   * Useful for daily schedule view
   * 
   * @param {string} date - Date in 'YYYY-MM-DD' format
   * @param {string} statusFilter - Optional: filter by status ('pending', 'assigned', etc.)
   * @returns {Promise<Array>} Array of jobs for that date
   */
  static async getJobsByDate(date, statusFilter = null) {
    try {
      // Base SQL query
      let sql = `
        SELECT 
          j.id,
          j.job_number,
          j.job_type,
          j.customer_name,
          j.customer_phone,
          j.customer_address,
          j.destination_lat, -- ← NEW
          j.destination_lng, -- ← NEW
          j.description,
          j.scheduled_date,
          j.scheduled_time_start,
          j.scheduled_time_end,
          j.estimated_duration_minutes,
          j.current_status,
          j.priority,
          j.created_by,
          j.created_at,
          j.updated_at,
          -- Also get assigned vehicle info (if assigned)
          ja.vehicle_id,
          v.vehicle_name,
          v.license_plate,
          -- Also get assigned driver info (if assigned)
          ja.driver_id,
          u.full_name as driver_name,
          ${Job._technicianSubquery}
        FROM jobs j
        LEFT JOIN job_assignments ja ON j.id = ja.job_id
        LEFT JOIN vehicles v ON ja.vehicle_id = v.id
        LEFT JOIN users u ON ja.driver_id = u.id
        WHERE j.scheduled_date = ?
      `;

      const params = [date];

      // Add status filter if provided
      if (statusFilter) {
        sql += ' AND j.current_status = ?';
        params.push(statusFilter);
      }

      // Order by start time
      sql += ' ORDER BY j.scheduled_time_start ASC';

      // Execute query
      const [rows] = await db.query(sql, params);
      return Job._parseTechnicians(Job._fixDates(rows));

    } catch (error) {
      logger.error({ err: error, date }, 'Error in Job.getJobsByDate');
      throw error;
    }
  }

  // ==========================================
  // FUNCTION: getJobsByVehicle
  // PURPOSE: Get all jobs assigned to a specific vehicle
  // RETURNS: Array of jobs for that vehicle
  // ==========================================
  /**
   * Get all jobs assigned to a specific vehicle
   * Useful for vehicle schedule view and checking conflicts
   * 
   * @param {number} vehicleId - The vehicle ID
   * @param {string} date - Optional: filter by specific date 'YYYY-MM-DD'
   * @param {Array<string>} excludeStatuses - Optional: exclude certain statuses
   * @returns {Promise<Array>} Array of jobs assigned to this vehicle
   */
  static async getJobsByVehicle(vehicleId, date = null, excludeStatuses = []) {
    try {
      // Base SQL query
      let sql = `
        SELECT 
          j.id,
          j.job_number,
          j.job_type,
          j.customer_name,
          j.customer_phone,
          j.customer_address,
          j.destination_lat,
          j.destination_lng,
          j.description,
          j.scheduled_date,
          j.scheduled_time_start,
          j.scheduled_time_end,
          j.estimated_duration_minutes,
          j.current_status,
          j.priority,
          j.created_at,
          j.updated_at,
          -- Vehicle info
          v.vehicle_name,
          v.license_plate,
          -- Driver info
          u.full_name as driver_name,
          ja.assigned_at,
          ${Job._technicianSubquery}
        FROM jobs j
        INNER JOIN job_assignments ja ON j.id = ja.job_id
        INNER JOIN vehicles v ON ja.vehicle_id = v.id
        LEFT JOIN users u ON ja.driver_id = u.id
        WHERE ja.vehicle_id = ?
      `;

      const params = [vehicleId];

      // Add date filter if provided
      if (date) {
        sql += ' AND j.scheduled_date = ?';
        params.push(date);
      }

      // Exclude certain statuses if provided
      if (excludeStatuses.length > 0) {
        const placeholders = excludeStatuses.map(() => '?').join(', ');
        sql += ` AND j.current_status NOT IN (${placeholders})`;
        params.push(...excludeStatuses);
      }

      // Order by date and start time
      sql += ' ORDER BY j.scheduled_date ASC, j.scheduled_time_start ASC';

      // Execute query
      const [rows] = await db.query(sql, params);
      return Job._parseTechnicians(Job._fixDates(rows));

    } catch (error) {
      logger.error({ err: error, vehicleId }, 'Error in Job.getJobsByVehicle');
      throw error;
    }
  }

  // ==========================================
  // FUNCTION: getJobById
  // PURPOSE: Get a single job by ID with full details
  // RETURNS: Job object with assignment info or null
  // ==========================================
  /**
   * Get a specific job by ID with all related information
   * 
   * @param {number} id - The job ID
   * @returns {Promise<Object|null>} Job object or null if not found
   */
  static async getJobById(id) {
    try {
      const sql = `
        SELECT 
          j.id,
          j.job_number,
          j.job_type,
          j.customer_name,
          j.customer_phone,
          j.customer_address,
          j.destination_lat, -- ← NEW
          j.destination_lng, -- ← NEW
          j.description,
          j.scheduled_date,
          j.scheduled_time_start,
          j.scheduled_time_end,
          j.estimated_duration_minutes,
          j.current_status,
          j.priority,
          j.created_by,
          j.created_at,
          j.updated_at,
          -- Assignment info (if exists)
          ja.id as assignment_id,
          ja.vehicle_id,
          v.vehicle_name,
          v.license_plate,
          ja.driver_id,
          u.full_name as driver_name,
          ja.assigned_at,
          ja.notes as assignment_notes,
          -- Creator info
          creator.full_name as created_by_name,
          ${Job._technicianSubquery}
        FROM jobs j
        LEFT JOIN job_assignments ja ON j.id = ja.job_id
        LEFT JOIN vehicles v ON ja.vehicle_id = v.id
        LEFT JOIN users u ON ja.driver_id = u.id
        LEFT JOIN users creator ON j.created_by = creator.id
        WHERE j.id = ?
      `;

      const [rows] = await db.query(sql, [id]);
      const fixed = Job._parseTechnicians(Job._fixDates(rows));
      return fixed[0] || null;

    } catch (error) {
      logger.error({ err: error, id }, 'Error in Job.getJobById');
      throw error;
    }
  }

  // ==========================================
  // FUNCTION: getAllJobs
  // PURPOSE: Get all jobs with optional filters
  // RETURNS: Array of all jobs
  // ==========================================
  /**
   * Get all jobs with optional filtering
   * 
   * @param {Object} filters - Optional filters
   * @param {string} filters.status - Filter by status
   * @param {string} filters.job_type - Filter by job type
   * @param {string} filters.priority - Filter by priority
   * @param {number} filters.limit - Limit number of results
   * @returns {Promise<Array>} Array of jobs
   */
  static async getAllJobs(filters = {}) {
    try {
      let sql = `
        SELECT 
          j.id,
          j.job_number,
          j.job_type,
          j.customer_name,
          j.customer_phone,
          j.customer_address,
          j.destination_lat,
          j.destination_lng,
          j.description,
          j.scheduled_date,
          j.scheduled_time_start,
          j.scheduled_time_end,
          j.estimated_duration_minutes,
          j.current_status,
          j.priority,
          j.created_at,
          -- ✅ FIX: vehicle_id and driver_id included so Flutter can place
          --         jobs in the correct vehicle column on the scheduler
          ja.vehicle_id,
          ja.driver_id,
          -- Vehicle info if assigned
          v.vehicle_name,
          v.license_plate,
          -- Driver info if assigned
          u.full_name as driver_name,
          ${Job._technicianSubquery}
        FROM jobs j
        LEFT JOIN job_assignments ja ON j.id = ja.job_id
        LEFT JOIN vehicles v ON ja.vehicle_id = v.id
        LEFT JOIN users u ON ja.driver_id = u.id
        WHERE 1=1
      `;

      const params = [];

      // Apply filters
      if (filters.status) {
        sql += ' AND j.current_status = ?';
        params.push(filters.status);
      }

      if (filters.job_type) {
        sql += ' AND j.job_type = ?';
        params.push(filters.job_type);
      }

      if (filters.priority) {
        sql += ' AND j.priority = ?';
        params.push(filters.priority);
      }

      sql += ' ORDER BY j.scheduled_date DESC, j.scheduled_time_start DESC';

      if (filters.limit) {
        sql += ' LIMIT ?';
        params.push(filters.limit);
      }

      const [rows] = await db.query(sql, params);
      return Job._parseTechnicians(Job._fixDates(rows));

    } catch (error) {
      logger.error({ err: error }, 'Error in Job.getAllJobs');
      throw error;
    }
  }

  // ==========================================
  // FUNCTION: getJobsByTechnician  ← NEW
  // PURPOSE: Return only jobs assigned to a specific technician user
  // Used by GET /api/jobs/my-jobs  (technician role sees only their jobs)
  // ==========================================
  static async getJobsByTechnician(userId, filters = {}) {
    try {
      let sql = `
        SELECT 
          j.id,
          j.job_number,
          j.job_type,
          j.customer_name,
          j.customer_phone,
          j.customer_address,
          j.destination_lat,
          j.destination_lng,
          j.description,
          j.scheduled_date,
          j.scheduled_time_start,
          j.scheduled_time_end,
          j.estimated_duration_minutes,
          j.current_status,
          j.priority,
          j.created_at,
          ja.vehicle_id,
          ja.driver_id,
          v.vehicle_name,
          v.license_plate,
          u.full_name as driver_name,
          ${Job._technicianSubquery}
        FROM jobs j
        INNER JOIN job_technicians jt_filter ON j.id = jt_filter.job_id
                                            AND jt_filter.user_id = ?
        LEFT JOIN  job_assignments ja ON j.id = ja.job_id
        LEFT JOIN  vehicles        v  ON ja.vehicle_id = v.id
        LEFT JOIN  users           u  ON ja.driver_id  = u.id
        WHERE 1=1
      `;

      const params = [userId];

      if (filters.status) {
        sql += ' AND j.current_status = ?';
        params.push(filters.status);
      }

      sql += ' ORDER BY j.scheduled_date DESC, j.scheduled_time_start DESC';

      const [rows] = await db.query(sql, params);
      return Job._parseTechnicians(Job._fixDates(rows));

    } catch (error) {
      logger.error({ err: error, userId }, 'Error in Job.getJobsByTechnician');
      throw error;
    }
  }

  // ==========================================
  // FUNCTION: assignTechnicians  ← NEW
  // PURPOSE: Replace the full technician list for a job atomically.
  // Pass [] to clear all technicians.
  //
  // FIX (Bug 3): Added isAdminOverride parameter.
  // When true, the service layer has already cleared conflicting
  // assignments via removeDriversFromConflictingJobs(), so we skip
  // straight to the DELETE + INSERT without any further conflict check.
  // The isAdminOverride flag is passed through from the route layer,
  // which enforces that only admin-role JWTs can set it to true.
  // ==========================================
  static async assignTechnicians(jobId, technicianIds, assignedBy, isAdminOverride = false) {
    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();

      // Remove all current technician assignments for this job
      await conn.query(
        'DELETE FROM job_technicians WHERE job_id = ?',
        [jobId]
      );

      // Bulk-insert the new list
      if (technicianIds.length > 0) {
        const rows = technicianIds.map(uid => [jobId, uid, assignedBy]);
        await conn.query(
          'INSERT INTO job_technicians (job_id, user_id, assigned_by) VALUES ?',
          [rows]
        );
      }

      await conn.commit();

      if (isAdminOverride) {
        logger.info({ jobId }, 'Admin override: technician list replaced');
      }
    } catch (err) {
      await conn.rollback();
      logger.error({ err, jobId }, 'Error in Job.assignTechnicians');
      throw err;
    } finally {
      conn.release();
    }
  }

  // ==========================================
  // FUNCTION: removeDriversFromConflictingJobs  ← NEW (Bug 3 fix)
  // PURPOSE: Before an admin override INSERT, remove the given drivers
  //          from any other job that overlaps with the target time window
  //          on the same date. This ensures a driver is never on two jobs
  //          simultaneously — the admin's intent is to MOVE the driver,
  //          not to double-book them.
  //
  // Called by: jobAssignmentService.assignTechnicians() when forceOverride=true
  //
  // @param {number[]} technicianIds  - Driver user IDs to free up
  // @param {string}   date           - YYYY-MM-DD
  // @param {string}   startTime      - HH:MM:SS
  // @param {string}   endTime        - HH:MM:SS
  // @param {number}   excludeJobId   - The job we're assigning TO (don't
  //                                    delete this job's existing rows)
  // ==========================================
  static async removeDriversFromConflictingJobs(technicianIds, date, startTime, endTime, excludeJobId) {
    if (!technicianIds || technicianIds.length === 0) return;

    // Find all job IDs where any of these drivers is currently booked
    // in an overlapping window on the same date
    const [conflictingJobs] = await db.query(
      `SELECT DISTINCT jt.job_id
       FROM job_technicians jt
       JOIN jobs j ON jt.job_id = j.id
       WHERE jt.user_id IN (?)
         AND j.scheduled_date = ?
         AND j.current_status NOT IN ('completed', 'cancelled')
         AND ? < j.scheduled_time_end
         AND ? > j.scheduled_time_start
         AND j.id != ?`,
      [technicianIds, date, startTime, endTime, excludeJobId]
    );

    if (conflictingJobs.length === 0) return;

    const conflictingJobIds = conflictingJobs.map(r => r.job_id);

    // Remove only these specific drivers from those conflicting jobs —
    // do NOT touch other drivers on those jobs
    await db.query(
      `DELETE FROM job_technicians
       WHERE user_id IN (?)
         AND job_id  IN (?)`,
      [technicianIds, conflictingJobIds]
    );

    logger.info({ technicianIds, conflictingJobIds }, 'Removed drivers from conflicting jobs');
  }

  // ==========================================
  // FUNCTION: updateJobStatus
  // PURPOSE: Update the status of a job
  // RETURNS: Updated job object
  // ==========================================
  /**
   * Update job status
   * Status flow: pending → assigned → in_progress → completed/cancelled
   * 
   * @param {number} id - The job ID
   * @param {string} newStatus - New status value
   * @returns {Promise<Object>} Updated job object
   */
  static async updateJobStatus(id, newStatus) {
    try {
      // Valid statuses (must match database ENUM)
      const validStatuses = ['pending', 'assigned', 'in_progress', 'completed', 'cancelled'];

      if (!validStatuses.includes(newStatus)) {
        throw new Error(`Invalid status: ${newStatus}. Must be one of: ${validStatuses.join(', ')}`);
      }

      const sql = `
        UPDATE jobs
        SET current_status = ?
        WHERE id = ?
      `;

      const [result] = await db.query(sql, [newStatus, id]);

      if (result.affectedRows === 0) {
        throw new Error(`Job with ID ${id} not found`);
      }

      // Return updated job (date already fixed inside getJobById)
      const updatedJob = await this.getJobById(id);
      return updatedJob;

    } catch (error) {
      logger.error({ err: error, id }, 'Error in Job.updateJobStatus');
      throw error;
    }
  }

  // ==========================================
  // HELPER FUNCTION: generateJobNumber
  // PURPOSE: Generate unique job number
  // RETURNS: String like 'JOB-2024-0001'
  // ==========================================
  static async generateJobNumber() {
    try {
      const year = new Date().getFullYear();

      // Ensure a row exists for the current year.
      // INSERT IGNORE is a no-op if the row already exists (unique key on year).
      // This handles the January 1st year-rollover edge case automatically.
      await db.query(
        `INSERT IGNORE INTO job_number_sequences (year, counter) VALUES (?, 0)`,
        [year]
      );

      // Atomic increment using the LAST_INSERT_ID(expr) trick:
      // MySQL/MariaDB stores the expression result as the connection's last insert ID.
      // No two connections can receive the same counter value — this is guaranteed atomic.
      await db.query(
        `UPDATE job_number_sequences SET counter = LAST_INSERT_ID(counter + 1) WHERE year = ?`,
        [year]
      );

      // Retrieve the value we just set (same connection context via pool)
      const [[seq]] = await db.query(`SELECT LAST_INSERT_ID() AS counter`);

      // Format: JOB-2026-0001
      return `JOB-${year}-${String(seq.counter).padStart(4, '0')}`;

    } catch (error) {
      logger.error({ err: error }, 'Error in Job.generateJobNumber');
      throw error;
    }
  }

  // ==========================================
  // BONUS FUNCTION: deleteJob
  // PURPOSE: Delete a job (only if not assigned)
  // RETURNS: Success result
  // ==========================================
  static async deleteJob(id) {
    try {
      // Check if job has assignment
      const checkSql = `
        SELECT COUNT(*) as assignment_count
        FROM job_assignments
        WHERE job_id = ?
      `;

      const [checkResult] = await db.query(checkSql, [id]);

      if (checkResult[0].assignment_count > 0) {
        throw new Error('Cannot delete job that is assigned to a vehicle. Cancel it instead.');
      }

      // Safe to delete
      const deleteSql = 'DELETE FROM jobs WHERE id = ?';
      const [result]  = await db.query(deleteSql, [id]);

      if (result.affectedRows === 0) {
        throw new Error(`Job with ID ${id} not found`);
      }

      return { success: true, message: 'Job deleted successfully' };

    } catch (error) {
      logger.error({ err: error, id }, 'Error in Job.deleteJob');
      throw error;
    }
  }

  // ==========================================
  // BONUS FUNCTION: getJobsByDateRange
  // PURPOSE: Get jobs within a date range
  // RETURNS: Array of jobs
  // ==========================================
  static async getJobsByDateRange(startDate, endDate) {
    try {
      const sql = `
        SELECT 
          j.*,
          v.vehicle_name,
          v.license_plate,
          u.full_name as driver_name,
          ${Job._technicianSubquery}
        FROM jobs j
        LEFT JOIN job_assignments ja ON j.id = ja.job_id
        LEFT JOIN vehicles v ON ja.vehicle_id = v.id
        LEFT JOIN users u ON ja.driver_id = u.id
        WHERE j.scheduled_date BETWEEN ? AND ?
        ORDER BY j.scheduled_date ASC, j.scheduled_time_start ASC
      `;

      const [rows] = await db.query(sql, [startDate, endDate]);
      return Job._parseTechnicians(Job._fixDates(rows));

    } catch (error) {
      logger.error({ err: error, startDate, endDate }, 'Error in Job.getJobsByDateRange');
      throw error;
    }
  }
}

// Export the Job class
module.exports = Job;