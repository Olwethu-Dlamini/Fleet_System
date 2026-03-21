// ============================================
// FILE: src/services/jobStatusService.js
// PURPOSE: Manage job status transitions and validation
// LAYER: Service Layer (business logic)
// ============================================

const db = require('../config/database');
const Job = require('../models/Job');
const logger = require('../config/logger').child({ service: 'jobStatusService' });

/**
 * Job Status Service
 * 
 * This service handles the business logic for job status transitions.
 * It enforces the status lifecycle rules to ensure data integrity.
 * 
 * Valid Status Flow:
 * 1. pending → assigned → in_progress → completed
 * 2. Any status (except completed) → cancelled
 * 3. assigned → pending (when unassigning)
 * 4. cancelled → pending (when reopening)
 */
class JobStatusService {
  
  // ==========================================
  // CONSTANT: Status Transition Rules
  // ==========================================
  /**
   * Defines which status transitions are allowed
   * 
   * Structure:
   * {
   *   'current_status': ['allowed_next_status_1', 'allowed_next_status_2']
   * }
   */
  static ALLOWED_TRANSITIONS = {
    'pending': ['assigned', 'cancelled'],
    'assigned': ['in_progress', 'cancelled', 'pending'], // pending only when unassigning
    'in_progress': ['completed', 'cancelled'],
    'completed': [], // Final state - no transitions allowed
    'cancelled': ['pending'] // Only when reopening a job
  };
  
  // ==========================================
  // CONSTANT: Status Descriptions
  // ==========================================
  static STATUS_DESCRIPTIONS = {
    'pending': 'Job created, awaiting vehicle assignment',
    'assigned': 'Vehicle assigned, awaiting start',
    'in_progress': 'Driver has started the job',
    'completed': 'Job successfully completed',
    'cancelled': 'Job cancelled and will not be completed'
  };
  
  // ==========================================
  // FUNCTION: updateJobStatus
  // PURPOSE: Update job status with validation and history tracking
  // ==========================================
  /**
   * Update a job's status with validation
   * 
   * This function:
   * 1. Gets the current job status
   * 2. Validates the transition is allowed
   * 3. Updates the status if valid
   * 4. Logs the change in status history
   * 5. Returns the updated job
   * 
   * @param {number} jobId - The job ID
   * @param {string} newStatus - The new status to set
   * @param {number} changedBy - User ID making the change
   * @param {string} reason - Optional reason for status change
   * @returns {Promise<Object>} Updated job object with history entry
   * 
   * Example usage:
   *   await JobStatusService.updateJobStatus(5, 'in_progress', 1, 'Driver started work');
   */
  static async updateJobStatus(jobId, newStatus, changedBy, reason = null) {
    // Start a database transaction for data integrity
    const connection = await db.getConnection();
    
    try {
      await connection.beginTransaction();
      
      // ============================================
      // STEP 1: Validate the new status value
      // ============================================
      const validStatuses = ['pending', 'assigned', 'in_progress', 'completed', 'cancelled'];
      
      if (!validStatuses.includes(newStatus)) {
        throw new Error(
          `Invalid status: "${newStatus}". ` +
          `Valid statuses are: ${validStatuses.join(', ')}`
        );
      }
      
      // ============================================
      // STEP 2: Get current job details
      // ============================================
      const [jobRows] = await connection.query(
        'SELECT * FROM jobs WHERE id = ?',
        [jobId]
      );
      
      if (jobRows.length === 0) {
        throw new Error(`Job with ID ${jobId} not found`);
      }
      
      const job = jobRows[0];
      const currentStatus = job.current_status;
      
      logger.debug({ jobNumber: job.job_number, currentStatus, newStatus }, 'Status update request');
      
      // ============================================
      // STEP 3: Check if status is actually changing
      // ============================================
      if (currentStatus === newStatus) {
        logger.debug({ jobId, newStatus }, 'Status unchanged — no update needed');
        await connection.commit();
        return await Job.getJobById(jobId);
      }
      
      // ============================================
      // STEP 4: Validate transition is allowed
      // ============================================
      const allowedTransitions = this.ALLOWED_TRANSITIONS[currentStatus];
      
      if (!allowedTransitions.includes(newStatus)) {
        throw new Error(
          `Invalid status transition: Cannot change from "${currentStatus}" to "${newStatus}". ` +
          `Allowed transitions from "${currentStatus}": ${allowedTransitions.length > 0 ? allowedTransitions.join(', ') : 'none (final state)'}`
        );
      }
      
      logger.debug({ jobId, currentStatus, newStatus }, 'Transition validated');
      
      // ============================================
      // STEP 5: Special business rule validations
      // ============================================
      
      // RULE 1: Cannot move to "in_progress" if no vehicle is assigned
      if (newStatus === 'in_progress') {
        const [assignmentCheck] = await connection.query(
          'SELECT COUNT(*) as count FROM job_assignments WHERE job_id = ?',
          [jobId]
        );
        
        if (assignmentCheck[0].count === 0) {
          throw new Error(
            'Cannot start job without a vehicle assignment. ' +
            'Please assign a vehicle first before changing status to "in_progress".'
          );
        }
      }
      
      // RULE 2: Moving from "assigned" to "pending" should only happen during unassignment
      if (currentStatus === 'assigned' && newStatus === 'pending') {
        const [assignmentCheck] = await connection.query(
          'SELECT COUNT(*) as count FROM job_assignments WHERE job_id = ?',
          [jobId]
        );
        
        if (assignmentCheck[0].count > 0 && !reason?.includes('unassign')) {
          logger.warn({ jobId }, 'Changing assigned job to pending while still assigned');
        }
      }
      
      logger.debug({ jobId }, 'Business rules validated');
      
      // ============================================
      // STEP 6: Update the job status
      // ============================================
      await connection.query(
        'UPDATE jobs SET current_status = ? WHERE id = ?',
        [newStatus, jobId]
      );
      
      logger.debug({ jobId, newStatus }, 'Status updated in database');
      
      // ============================================
      // STEP 7: Log the status change in history
      // ============================================
      // ✅ FIX: Removed 'metadata' column - it doesn't exist in job_status_changes table
      const historyInsertSql = `
        INSERT INTO job_status_changes (
          job_id,
          old_status,
          new_status,
          changed_by,
          reason,
          changed_at
        ) VALUES (?, ?, ?, ?, ?, NOW())
      `;
      
      const [historyResult] = await connection.query(historyInsertSql, [
        jobId,
        currentStatus,
        newStatus,
        changedBy,
        reason
        // ✅ NO metadata parameter - column doesn't exist in schema
      ]);
      
      logger.debug({ jobId, historyId: historyResult.insertId }, 'Status change logged in history');
      
      // ============================================
      // STEP 8: Commit transaction
      // ============================================
      await connection.commit();
      
      logger.info({ jobId, currentStatus, newStatus }, 'Status update completed');
      
      // ============================================
      // STEP 9: Return updated job with history entry
      // ============================================
      const updatedJob = await Job.getJobById(jobId);
      
      // Get the history entry we just created
      const historyEntry = await this.getHistoryEntry(historyResult.insertId);
      
      return {
        job: updatedJob,
        statusChange: historyEntry
      };
      
    } catch (error) {
      // Rollback transaction on error
      await connection.rollback();
      logger.error({ err: error, jobId }, 'Error updating job status');
      throw error;
      
    } finally {
      // Release the connection back to the pool
      connection.release();
    }
  }
  
  // ==========================================
  // FUNCTION: getJobStatusHistory
  // PURPOSE: Get complete status history for a job
  // ==========================================
  /**
   * Get the complete status change history of a job
   * 
   * @param {number} jobId - The job ID
   * @param {number} limit - Optional: limit number of results
   * @returns {Promise<Array>} Array of status changes
   * 
   * Example usage:
   *   const history = await JobStatusService.getJobStatusHistory(5);
   */
  static async getJobStatusHistory(jobId, limit = null) {
    try {
      let sql = `
        SELECT 
          jsh.id,
          jsh.job_id,
          j.job_number,
          jsh.old_status,
          jsh.new_status,
          jsh.reason,
          jsh.changed_at,
          jsh.changed_by,
          u.full_name as changed_by_name,
          u.email as changed_by_email
        FROM job_status_changes jsh
        INNER JOIN jobs j ON jsh.job_id = j.id
        LEFT JOIN users u ON jsh.changed_by = u.id
        WHERE jsh.job_id = ?
        ORDER BY jsh.changed_at DESC
      `;
      
      const params = [jobId];
      
      if (limit) {
        sql += ' LIMIT ?';
        params.push(limit);
      }
      
      const [rows] = await db.query(sql, params);
      
      // ✅ FIX: Removed metadata parsing - column doesn't exist
      return rows;
      
    } catch (error) {
      logger.error({ err: error, jobId }, 'Error in JobStatusService.getJobStatusHistory');
      throw error;
    }
  }

  // ==========================================
  // FUNCTION: getHistoryEntry
  // PURPOSE: Get a single history entry by ID
  // ==========================================
  /**
   * Get a specific history entry
   * 
   * @param {number} historyId - The history entry ID
   * @returns {Promise<Object>} History entry object
   */
  static async getHistoryEntry(historyId) {
    try {
      const sql = `
        SELECT 
          jsh.id,
          jsh.job_id,
          j.job_number,
          jsh.old_status,
          jsh.new_status,
          jsh.reason,
          jsh.changed_at,
          jsh.changed_by,
          u.full_name as changed_by_name
        FROM job_status_changes jsh
        INNER JOIN jobs j ON jsh.job_id = j.id
        LEFT JOIN users u ON jsh.changed_by = u.id
        WHERE jsh.id = ?
      `;
      
      const [rows] = await db.query(sql, [historyId]);
      
      if (rows.length === 0) {
        return null;
      }
      
      // ✅ FIX: Removed metadata parsing - column doesn't exist
      return rows[0];
      
    } catch (error) {
      logger.error({ err: error, historyId }, 'Error in JobStatusService.getHistoryEntry');
      throw error;
    }
  }

  // ==========================================
  // FUNCTION: getAllStatusChanges
  // PURPOSE: Get all recent status changes (for dashboard/monitoring)
  // ==========================================
  /**
   * Get recent status changes across all jobs
   * Useful for dashboard and monitoring
   * 
   * @param {Object} filters - Optional filters
   * @param {number} filters.limit - Number of results (default 50)
   * @param {string} filters.status - Filter by new_status
   * @param {number} filters.days - Only show changes in last X days
   * @returns {Promise<Array>} Array of status changes
   */
  static async getAllStatusChanges(filters = {}) {
    try {
      const { limit = 50, status = null, days = null } = filters;
      
      let sql = `
        SELECT 
          jsh.id,
          jsh.job_id,
          j.job_number,
          j.customer_name,
          jsh.old_status,
          jsh.new_status,
          jsh.reason,
          jsh.changed_at,
          u.full_name as changed_by_name,
          v.vehicle_name
        FROM job_status_changes jsh
        INNER JOIN jobs j ON jsh.job_id = j.id
        LEFT JOIN users u ON jsh.changed_by = u.id
        LEFT JOIN job_assignments ja ON j.id = ja.job_id
        LEFT JOIN vehicles v ON ja.vehicle_id = v.id
        WHERE 1=1
      `;
      
      const params = [];
      
      if (status) {
        sql += ' AND jsh.new_status = ?';
        params.push(status);
      }
      
      if (days) {
        sql += ' AND jsh.changed_at >= DATE_SUB(NOW(), INTERVAL ? DAY)';
        params.push(days);
      }
      
      sql += ' ORDER BY jsh.changed_at DESC LIMIT ?';
      params.push(limit);
      
      const [rows] = await db.query(sql, params);
      
      return rows;
      
    } catch (error) {
      logger.error({ err: error }, 'Error in JobStatusService.getAllStatusChanges');
      throw error;
    }
  }

  // ==========================================
  // FUNCTION: completeJob
  // PURPOSE: STAT-02/03/04 — Complete a job with personnel check and GPS capture
  // ==========================================
  /**
   * Complete a job with personnel authorization check and GPS coordinate capture.
   *
   * STAT-02: Only assigned drivers/technicians or admin/scheduler/dispatcher can complete a job.
   * STAT-03: GPS coordinates are captured at the moment of completion.
   * STAT-04: Completion record is inserted into job_completions table.
   *
   * @param {number} jobId - Job ID
   * @param {number} userId - User completing the job
   * @param {string} userRole - User's role ('admin', 'scheduler', 'dispatcher', 'technician')
   * @param {object} gpsData - { lat, lng, accuracy_m, gps_status }
   * @returns {object} { job, statusChange, completion }
   */
  static async completeJob(jobId, userId, userRole, gpsData = {}) {
    // STAT-02: Verify the user is assigned to this job or is admin/scheduler/dispatcher
    const isAdminOrScheduler = ['admin', 'scheduler', 'dispatcher'].includes(userRole);

    if (!isAdminOrScheduler) {
      // Read-only personnel check — no transaction needed
      const [techRows] = await db.query(
        'SELECT 1 FROM job_technicians WHERE job_id = ? AND user_id = ?',
        [jobId, userId]
      );
      const [assignRow] = await db.query(
        'SELECT 1 FROM job_assignments WHERE job_id = ? AND driver_id = ?',
        [jobId, userId]
      );
      if (techRows.length === 0 && assignRow.length === 0) {
        throw new Error('FORBIDDEN: Only assigned personnel can complete this job.');
      }
    }

    // Use existing updateJobStatus for the status transition (has its own transaction)
    const result = await this.updateJobStatus(jobId, 'completed', userId, 'Job completed');

    // STAT-03/04: Insert into job_completions with GPS data
    const { lat = null, lng = null, accuracy_m = null, gps_status = 'no_gps' } = gpsData;
    await db.query(
      `INSERT INTO job_completions (job_id, completed_by, lat, lng, accuracy_m, gps_status, completed_at, tenant_id)
       VALUES (?, ?, ?, ?, ?, ?, NOW(), (SELECT tenant_id FROM jobs WHERE id = ?))`,
      [jobId, userId, lat, lng, accuracy_m, gps_status, jobId]
    );

    logger.info({ jobId, userId, gps_status }, 'Job completed with GPS capture');

    return {
      job: result.job,
      statusChange: result.statusChange,
      completion: { job_id: jobId, completed_by: userId, lat, lng, accuracy_m, gps_status }
    };
  }

  // ==========================================
  // FUNCTION: canTransitionTo
  // PURPOSE: Check if a status transition is allowed
  // RETURNS: Boolean
  // ==========================================
  /**
   * Check if a job can transition to a new status
   * 
   * @param {string} currentStatus - Current job status
   * @param {string} newStatus - Desired new status
   * @returns {boolean} true if transition is allowed
   */
  static canTransitionTo(currentStatus, newStatus) {
    if (currentStatus === newStatus) {
      return true;
    }
    
    const allowedTransitions = this.ALLOWED_TRANSITIONS[currentStatus];
    return allowedTransitions ? allowedTransitions.includes(newStatus) : false;
  }
  
  // ==========================================
  // FUNCTION: getAllowedTransitions
  // PURPOSE: Get list of allowed next statuses for a job
  // ==========================================
  /**
   * Get all allowed status transitions for a job
   * 
   * @param {number} jobId - The job ID
   * @returns {Promise<Array>} Array of allowed next statuses
   */
  static async getAllowedTransitions(jobId) {
    try {
      const job = await Job.getJobById(jobId);
      
      if (!job) {
        throw new Error(`Job with ID ${jobId} not found`);
      }
      
      const currentStatus = job.current_status;
      const allowedStatuses = this.ALLOWED_TRANSITIONS[currentStatus] || [];
      
      const transitions = allowedStatuses.map(status => ({
        status: status,
        description: this.STATUS_DESCRIPTIONS[status]
      }));
      
      return transitions;
      
    } catch (error) {
      logger.error({ err: error, jobId }, 'Error in JobStatusService.getAllowedTransitions');
      throw error;
    }
  }

  // ==========================================
  // FUNCTION: validateJobWorkflow
  // PURPOSE: Check if job is ready for a specific status
  // ==========================================
  /**
   * Validate if a job meets all requirements for a status
   * 
   * @param {number} jobId - The job ID
   * @param {string} targetStatus - Status to validate for
   * @returns {Promise<Object>} Validation result
   */
  static async validateJobWorkflow(jobId, targetStatus) {
    try {
      const job = await Job.getJobById(jobId);
      
      if (!job) {
        return {
          valid: false,
          errors: [`Job with ID ${jobId} not found`]
        };
      }
      
      const errors = [];
      
      // Check if transition is allowed
      if (!this.canTransitionTo(job.current_status, targetStatus)) {
        errors.push(
          `Cannot transition from "${job.current_status}" to "${targetStatus}". ` +
          `Allowed: ${this.ALLOWED_TRANSITIONS[job.current_status]?.join(', ') || 'none'}`
        );
      }
      
      // Validation rules for each status
      switch (targetStatus) {
        case 'assigned':
          // Will be validated during assignment
          break;
          
        case 'in_progress':
          if (!job.vehicle_id) {
            errors.push('Job must have a vehicle assigned');
          }
          if (job.current_status !== 'assigned') {
            errors.push('Job must be in "assigned" status');
          }
          break;
          
        case 'completed':
          if (job.current_status !== 'in_progress') {
            errors.push('Job must be in "in_progress" status to be completed');
          }
          break;
          
        case 'cancelled':
          if (job.current_status === 'completed') {
            errors.push('Cannot cancel a completed job');
          }
          break;
          
        case 'pending':
          if (job.current_status !== 'assigned' && job.current_status !== 'cancelled') {
            errors.push('Can only return to pending from assigned or cancelled status');
          }
          break;
      }
      
      return {
        valid: errors.length === 0,
        errors: errors,
        currentStatus: job.current_status,
        targetStatus: targetStatus
      };
      
    } catch (error) {
      logger.error({ err: error, jobId }, 'Error in JobStatusService.validateJobWorkflow');
      throw error;
    }
  }
}

module.exports = JobStatusService;