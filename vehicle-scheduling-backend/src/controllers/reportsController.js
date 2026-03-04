// ============================================
// FILE: src/controllers/reportsController.js
// PURPOSE: Handle reports API requests
// LAYER: Controller Layer (HTTP handling)
// ============================================
const ReportsService = require('../services/reportsService');

/**
 * Reports Controller
 * 
 * Handles HTTP requests for all reporting endpoints.
 * Provides date filtering and proper error handling.
 */
class ReportsController {
  
  // ==========================================
  // GET: Jobs Per Vehicle Report
  // ==========================================
  /**
   * Get jobs per vehicle report
   * 
   * GET /api/reports/jobs-per-vehicle
   * 
   * Query parameters:
   * - startDate: Required (YYYY-MM-DD)
   * - endDate: Required (YYYY-MM-DD)
   * - jobType: Optional (installation, delivery, maintenance)
   * 
   * Example:
   * GET /api/reports/jobs-per-vehicle?startDate=2024-01-01&endDate=2024-01-31
   */
  static async getJobsPerVehicle(req, res) {
    try {
      const { startDate, endDate, jobType } = req.query;
      
      // Validate required parameters
      if (!startDate || !endDate) {
        return res.status(400).json({
          success: false,
          error: 'Missing required parameters: startDate and endDate'
        });
      }
      
      console.log('📥 Jobs Per Vehicle report request');
      
      // Generate report
      const report = await ReportsService.getJobsPerVehicle({
        startDate,
        endDate,
        jobType
      });
      
      // Return success response
      res.status(200).json({
        success: true,
        data: report,
        timestamp: new Date().toISOString(),
        message: 'Jobs per vehicle report generated successfully'
      });
      
    } catch (error) {
      console.error('❌ Error in reports controller (jobs per vehicle):', error.message);
      
      res.status(500).json({
        success: false,
        error: 'Failed to generate jobs per vehicle report',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined
      });
    }
  }
  
  // ==========================================
  // GET: Vehicle Utilization Report
  // ==========================================
  /**
   * Get vehicle utilization report
   * 
   * GET /api/reports/utilization
   * 
   * Query parameters:
   * - startDate: Required (YYYY-MM-DD)
   * - endDate: Required (YYYY-MM-DD)
   * 
   * Example:
   * GET /api/reports/utilization?startDate=2024-01-01&endDate=2024-01-31
   */
  static async getVehicleUtilization(req, res) {
    try {
      const { startDate, endDate } = req.query;
      
      if (!startDate || !endDate) {
        return res.status(400).json({
          success: false,
          error: 'Missing required parameters: startDate and endDate'
        });
      }
      
      console.log('📥 Vehicle utilization report request');
      
      const report = await ReportsService.getVehicleUtilization({
        startDate,
        endDate
      });
      
      res.status(200).json({
        success: true,
        data: report,
        timestamp: new Date().toISOString(),
        message: 'Vehicle utilization report generated successfully'
      });
      
    } catch (error) {
      console.error('❌ Error in reports controller (utilization):', error.message);
      
      res.status(500).json({
        success: false,
        error: 'Failed to generate vehicle utilization report',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined
      });
    }
  }
  
  // ==========================================
  // GET: Jobs By Service Type Report
  // ==========================================
  /**
   * Get jobs by service type report
   * 
   * GET /api/reports/jobs-by-type
   * 
   * Query parameters:
   * - startDate: Required (YYYY-MM-DD)
   * - endDate: Required (YYYY-MM-DD)
   * - includeTrends: Optional (boolean, default: false)
   * 
   * Example:
   * GET /api/reports/jobs-by-type?startDate=2024-01-01&endDate=2024-01-31&includeTrends=true
   */
  static async getJobsByServiceType(req, res) {
    try {
      const { startDate, endDate, includeTrends } = req.query;
      
      if (!startDate || !endDate) {
        return res.status(400).json({
          success: false,
          error: 'Missing required parameters: startDate and endDate'
        });
      }
      
      console.log('📥 Jobs by service type report request');
      
      const report = await ReportsService.getJobsByServiceType({
        startDate,
        endDate,
        includeTrends: includeTrends === 'true'
      });
      
      res.status(200).json({
        success: true,
        data: report,
        timestamp: new Date().toISOString(),
        message: 'Jobs by service type report generated successfully'
      });
      
    } catch (error) {
      console.error('❌ Error in reports controller (jobs by type):', error.message);
      
      res.status(500).json({
        success: false,
        error: 'Failed to generate jobs by service type report',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined
      });
    }
  }
  
  // ==========================================
  // GET: Completion Analysis Report
  // ==========================================
  /**
   * Get completion analysis report
   * 
   * GET /api/reports/completion-analysis
   * 
   * Query parameters:
   * - startDate: Required (YYYY-MM-DD)
   * - endDate: Required (YYYY-MM-DD)
   * - jobType: Optional (installation, delivery, maintenance)
   * 
   * Example:
   * GET /api/reports/completion-analysis?startDate=2024-01-01&endDate=2024-01-31
   */
  static async getCompletionAnalysis(req, res) {
    try {
      const { startDate, endDate, jobType } = req.query;
      
      if (!startDate || !endDate) {
        return res.status(400).json({
          success: false,
          error: 'Missing required parameters: startDate and endDate'
        });
      }
      
      console.log('📥 Completion analysis report request');
      
      const report = await ReportsService.getCompletionAnalysis({
        startDate,
        endDate,
        jobType
      });
      
      res.status(200).json({
        success: true,
        data: report,
        timestamp: new Date().toISOString(),
        message: 'Completion analysis report generated successfully'
      });
      
    } catch (error) {
      console.error('❌ Error in reports controller (completion analysis):', error.message);
      
      res.status(500).json({
        success: false,
        error: 'Failed to generate completion analysis report',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined
      });
    }
  }
  
  // ==========================================
  // GET: Executive Dashboard
  // ==========================================
  /**
   * Get executive dashboard report
   * 
   * GET /api/reports/executive-dashboard
   * 
   * Query parameters:
   * - startDate: Required (YYYY-MM-DD)
   * - endDate: Required (YYYY-MM-DD)
   * 
   * Example:
   * GET /api/reports/executive-dashboard?startDate=2024-01-01&endDate=2024-01-31
   */
  static async getExecutiveDashboard(req, res) {
    try {
      const { startDate, endDate } = req.query;
      
      if (!startDate || !endDate) {
        return res.status(400).json({
          success: false,
          error: 'Missing required parameters: startDate and endDate'
        });
      }
      
      console.log('📥 Executive dashboard report request');
      
      const dashboard = await ReportsService.getExecutiveDashboard({
        startDate,
        endDate
      });
      
      res.status(200).json({
        success: true,
        data: dashboard,
        timestamp: new Date().toISOString(),
        message: 'Executive dashboard generated successfully'
      });
      
    } catch (error) {
      console.error('❌ Error in reports controller (executive dashboard):', error.message);
      
      res.status(500).json({
        success: false,
        error: 'Failed to generate executive dashboard',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined
      });
    }
  }
  
  // ==========================================
  // GET: Quick Stats (Lightweight)
  // ==========================================
  /**
   * Get quick stats for a date range
   * 
   * GET /api/reports/quick-stats
   * 
   * Lightweight endpoint for basic metrics.
   * 
   * Query parameters:
   * - startDate: Required (YYYY-MM-DD)
   * - endDate: Required (YYYY-MM-DD)
   */
  static async getQuickStats(req, res) {
    try {
      const { startDate, endDate } = req.query;
      
      if (!startDate || !endDate) {
        return res.status(400).json({
          success: false,
          error: 'Missing required parameters: startDate and endDate'
        });
      }
      
      // Quick SQL query for basic stats
      const sql = `
        SELECT 
          COUNT(*) as total_jobs,
          SUM(CASE WHEN current_status = 'completed' THEN 1 ELSE 0 END) as completed,
          SUM(CASE WHEN current_status = 'cancelled' THEN 1 ELSE 0 END) as cancelled,
          SUM(CASE WHEN current_status IN ('assigned', 'in_progress') THEN 1 ELSE 0 END) as active,
          COUNT(DISTINCT job_type) as service_types
        FROM jobs
        WHERE scheduled_date BETWEEN ? AND ?
      `;
      
      const [stats] = await require('../config/database').query(sql, [startDate, endDate]);
      
      const stat = stats[0];
      const completionRate = stat.total_jobs > 0 
        ? Math.round((stat.completed / stat.total_jobs) * 100) 
        : 0;
      
      res.status(200).json({
        success: true,
        data: {
          totalJobs: Number(stat.total_jobs),
          completed: Number(stat.completed),
          cancelled: Number(stat.cancelled),
          active: Number(stat.active),
          completionRate: completionRate,
          serviceTypes: Number(stat.service_types),
          dateRange: { startDate, endDate }
        },
        timestamp: new Date().toISOString(),
        message: 'Quick stats retrieved successfully'
      });
      
    } catch (error) {
      console.error('❌ Error in reports controller (quick stats):', error.message);
      
      res.status(500).json({
        success: false,
        error: 'Failed to retrieve quick stats',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined
      });
    }
  }
}

module.exports = ReportsController;