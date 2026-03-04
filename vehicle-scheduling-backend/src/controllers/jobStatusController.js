// ============================================
// FILE: src/controllers/jobStatusController.js
// PURPOSE: Handle HTTP requests for job status updates
// LAYER: Controller Layer
// ============================================

const JobStatusService = require('../services/jobStatusService');
const Job = require('../models/Job');

/**
 * Job Status Controller
 * Handles API requests for job status management
 */
class JobStatusController {
  
  // ==========================================
  // FUNCTION: updateStatus
  // PURPOSE: Handle POST request to update job status
  // ROUTE: POST /api/job-status/update
  // ==========================================
  /**
   * Update job status
   * 
   * Request body:
   * {
   *   "job_id": 5,
   *   "new_status": "in_progress",
   *   "changed_by": 1,
   *   "reason": "Driver started work",  // Optional
   *   "metadata": {...}                 // Optional
   * }
   * 
   * Success response (200):
   * {
   *   "success": true,
   *   "message": "Job status updated successfully",
   *   "data": {
   *     "job": {...},
   *     "statusChange": {...}
   *   }
   * }
   * 
   * Error responses:
   * - 400: Validation error or invalid transition
   * - 404: Job not found
   * - 500: Server error
   */
  static async updateStatus(req, res) {
    try {
      const { job_id, new_status, changed_by, reason, metadata } = req.body;
      
      console.log('\n═══════════════════════════════════════════════════════');
      console.log('📝 Status Update Request Received');
      console.log('═══════════════════════════════════════════════════════');
      
      // ============================================
      // Validate required fields
      // ============================================
      if (!job_id) {
        return res.status(400).json({
          success: false,
          message: 'job_id is required',
          error: 'Missing required field: job_id'
        });
      }
      
      if (!new_status) {
        return res.status(400).json({
          success: false,
          message: 'new_status is required',
          error: 'Missing required field: new_status'
        });
      }
      
      if (!changed_by) {
        return res.status(400).json({
          success: false,
          message: 'changed_by (user ID) is required',
          error: 'Missing required field: changed_by'
        });
      }
      
      // Validate that IDs are numbers
      if (isNaN(job_id) || isNaN(changed_by)) {
        return res.status(400).json({
          success: false,
          message: 'job_id and changed_by must be valid numbers'
        });
      }
      
      // Validate status value format
      const validStatuses = ['pending', 'assigned', 'in_progress', 'completed', 'cancelled'];
      if (!validStatuses.includes(new_status)) {
        return res.status(400).json({
          success: false,
          message: `Invalid status value: "${new_status}"`,
          error: `Status must be one of: ${validStatuses.join(', ')}`
        });
      }
      
      console.log(`   Job ID: ${job_id}`);
      console.log(`   New Status: ${new_status}`);
      console.log(`   Changed By: ${changed_by}`);
      if (reason) console.log(`   Reason: ${reason}`);
      
      // ============================================
      // Update the status
      // ============================================
      const result = await JobStatusService.updateJobStatus(
        parseInt(job_id),
        new_status,
        parseInt(changed_by),
        reason || null,
        metadata || null
      );
      
      console.log('═══════════════════════════════════════════════════════');
      console.log('✅ Status Update Successful');
      console.log('═══════════════════════════════════════════════════════\n');
      
      // ============================================
      // Send success response
      // ============================================
      return res.status(200).json({
        success: true,
        message: `Job status updated to "${new_status}" successfully`,
        data: {
          job: result.job,
          statusChange: result.statusChange
        }
      });
      
    } catch (error) {
      console.error('═══════════════════════════════════════════════════════');
      console.error('❌ Error in updateStatus controller:');
      console.error(error.message);
      console.error('═══════════════════════════════════════════════════════\n');
      
      // ============================================
      // Handle specific error types
      // ============================================
      
      // Invalid transition error
      if (error.message.includes('Invalid status transition')) {
        return res.status(400).json({
          success: false,
          message: 'Invalid status transition',
          error: error.message
        });
      }
      
      // Validation error (e.g., no vehicle assigned)
      if (
        error.message.includes('Cannot start job') ||
        error.message.includes('Cannot change status') ||
        error.message.includes('Cannot cancel')
      ) {
        return res.status(400).json({
          success: false,
          message: 'Status update validation failed',
          error: error.message
        });
      }
      
      // Job not found
      if (error.message.includes('not found')) {
        return res.status(404).json({
          success: false,
          message: 'Job not found',
          error: error.message
        });
      }
      
      // Invalid status value
      if (error.message.includes('Invalid status:')) {
        return res.status(400).json({
          success: false,
          message: 'Invalid status value',
          error: error.message
        });
      }
      
      // Generic server error
      return res.status(500).json({
        success: false,
        message: 'An error occurred while updating job status',
        error: error.message
      });
    }
  }
  
  // ==========================================
  // FUNCTION: getStatusHistory
  // PURPOSE: Get status change history for a job
  // ROUTE: GET /api/job-status/history/:job_id
  // ==========================================
  /**
   * Get status history for a job
   * 
   * URL params: job_id
   * Query params: limit (optional)
   * 
   * Example: GET /api/job-status/history/5?limit=10
   */
  static async getStatusHistory(req, res) {
    try {
      const { job_id } = req.params;
      const { limit } = req.query;
      
      if (!job_id || isNaN(job_id)) {
        return res.status(400).json({
          success: false,
          message: 'Valid job_id is required'
        });
      }
      
      // Check if job exists
      const job = await Job.getJobById(parseInt(job_id));
      if (!job) {
        return res.status(404).json({
          success: false,
          message: `Job with ID ${job_id} not found`
        });
      }
      
      // Get history
      const history = await JobStatusService.getJobStatusHistory(
        parseInt(job_id),
        limit ? parseInt(limit) : null
      );
      
      return res.status(200).json({
        success: true,
        data: {
          job_id: parseInt(job_id),
          job_number: job.job_number,
          current_status: job.current_status,
          history: history,
          total_changes: history.length
        }
      });
      
    } catch (error) {
      console.error('Error in getStatusHistory:', error.message);
      
      return res.status(500).json({
        success: false,
        message: 'An error occurred while fetching status history',
        error: error.message
      });
    }
  }
  
  // ==========================================
  // FUNCTION: getAllowedTransitions
  // PURPOSE: Get allowed status transitions for a job
  // ROUTE: GET /api/job-status/allowed-transitions/:job_id
  // ==========================================
  /**
   * Get allowed transitions for a job
   * 
   * URL params: job_id
   * 
   * Example: GET /api/job-status/allowed-transitions/5
   */
  static async getAllowedTransitions(req, res) {
    try {
      const { job_id } = req.params;
      
      if (!job_id || isNaN(job_id)) {
        return res.status(400).json({
          success: false,
          message: 'Valid job_id is required'
        });
      }
      
      // Get job details
      const job = await Job.getJobById(parseInt(job_id));
      if (!job) {
        return res.status(404).json({
          success: false,
          message: `Job with ID ${job_id} not found`
        });
      }
      
      // Get allowed transitions
      const transitions = await JobStatusService.getAllowedTransitions(
        parseInt(job_id)
      );
      
      return res.status(200).json({
        success: true,
        data: {
          job_id: parseInt(job_id),
          job_number: job.job_number,
          current_status: job.current_status,
          allowed_transitions: transitions
        }
      });
      
    } catch (error) {
      console.error('Error in getAllowedTransitions:', error.message);
      
      if (error.message.includes('not found')) {
        return res.status(404).json({
          success: false,
          message: error.message
        });
      }
      
      return res.status(500).json({
        success: false,
        message: 'An error occurred while fetching allowed transitions',
        error: error.message
      });
    }
  }
  
  // ==========================================
  // FUNCTION: validateTransition
  // PURPOSE: Check if a status transition is valid
  // ROUTE: POST /api/job-status/validate-transition
  // ==========================================
  /**
   * Validate a status transition
   * 
   * Request body:
   * {
   *   "job_id": 5,
   *   "target_status": "in_progress"
   * }
   */
  static async validateTransition(req, res) {
    try {
      const { job_id, target_status } = req.body;
      
      if (!job_id || !target_status) {
        return res.status(400).json({
          success: false,
          message: 'job_id and target_status are required'
        });
      }
      
      if (isNaN(job_id)) {
        return res.status(400).json({
          success: false,
          message: 'job_id must be a valid number'
        });
      }
      
      const validation = await JobStatusService.validateJobWorkflow(
        parseInt(job_id),
        target_status
      );
      
      return res.status(200).json({
        success: true,
        data: validation
      });
      
    } catch (error) {
      console.error('Error in validateTransition:', error.message);
      
      return res.status(500).json({
        success: false,
        message: 'An error occurred while validating transition',
        error: error.message
      });
    }
  }
  
  // ==========================================
  // FUNCTION: getRecentStatusChanges
  // PURPOSE: Get recent status changes across all jobs
  // ROUTE: GET /api/job-status/recent-changes
  // ==========================================
  /**
   * Get recent status changes (for dashboard/monitoring)
   * 
   * Query params:
   * - limit: Number of results (default 50)
   * - status: Filter by new_status
   * - days: Only show changes in last X days
   * 
   * Example: GET /api/job-status/recent-changes?limit=20&days=7
   */
  static async getRecentStatusChanges(req, res) {
    try {
      const { limit, status, days } = req.query;
      
      const filters = {
        limit: limit ? parseInt(limit) : 50,
        status: status || null,
        days: days ? parseInt(days) : null
      };
      
      const changes = await JobStatusService.getAllStatusChanges(filters);
      
      return res.status(200).json({
        success: true,
        data: {
          changes: changes,
          total: changes.length,
          filters: filters
        }
      });
      
    } catch (error) {
      console.error('Error in getRecentStatusChanges:', error.message);
      
      return res.status(500).json({
        success: false,
        message: 'An error occurred while fetching recent status changes',
        error: error.message
      });
    }
  }
}

module.exports = JobStatusController;