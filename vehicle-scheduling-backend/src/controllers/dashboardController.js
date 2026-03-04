// ============================================
// FILE: src/controllers/dashboardController.js
// PURPOSE: Handle dashboard API requests
// LAYER: Controller Layer (HTTP handling)
// ============================================
const DashboardService = require('../services/dashboardService');

/**
 * Dashboard Controller
 * 
 * Handles HTTP requests for dashboard summary data.
 * Converts service layer data into HTTP responses.
 */
class DashboardController {
  
  // ==========================================
  // GET: Dashboard Summary
  // ==========================================
  /**
   * Get dashboard summary
   * 
   * GET /api/dashboard/summary
   * 
   * Query parameters:
   * - date: Optional specific date (YYYY-MM-DD)
   * 
   * Response:
   * {
   *   success: true,
   *   data: { ...dashboard summary... },
   *   timestamp: "2024-02-20T10:30:00Z"
   * }
   */
  static async getDashboardSummary(req, res) {
    try {
      const { date } = req.query;
      
      console.log('📥 Dashboard summary request received');
      
      // Get dashboard data from service
      const dashboardData = await DashboardService.getDashboardSummary({ date });
      
      // Return success response
      res.status(200).json({
        success: true,
        data: dashboardData,
        timestamp: new Date().toISOString(),
        message: 'Dashboard summary retrieved successfully'
      });
      
    } catch (error) {
      console.error('❌ Error in dashboard controller:', error.message);
      
      // Return error response
      res.status(500).json({
        success: false,
        error: 'Failed to retrieve dashboard summary',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined
      });
    }
  }
  
  // ==========================================
  // GET: Quick Stats (Lightweight version)
  // ==========================================
  /**
   * Get quick stats only (counts without full details)
   * 
   * GET /api/dashboard/stats
   * 
   * Useful for:
   * - Header badges
   * - Quick notifications
   * - Performance-critical views
   * 
   * Response:
   * {
   *   success: true,
   *   data: {
   *     jobsToday: 5,
   *     jobsThisWeek: 23,
   *     vehiclesBusy: 2,
   *     vehiclesAvailable: 1
   *   }
   * }
   */
  static async getQuickStats(req, res) {
    try {
      const { date } = req.query;
      
      console.log('📥 Quick stats request received');
      
      // Get full dashboard data
      const dashboardData = await DashboardService.getDashboardSummary({ date });
      
      // Return only the summary counts
      res.status(200).json({
        success: true,
        data: dashboardData.summary,
        timestamp: new Date().toISOString(),
        message: 'Quick stats retrieved successfully'
      });
      
    } catch (error) {
      console.error('❌ Error in quick stats:', error.message);
      
      res.status(500).json({
        success: false,
        error: 'Failed to retrieve quick stats',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined
      });
    }
  }
}

module.exports = DashboardController;