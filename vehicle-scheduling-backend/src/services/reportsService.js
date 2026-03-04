// ============================================
// FILE: src/services/reportsService.js
// PURPOSE: Generate various reports for the vehicle scheduling system
// LAYER: Service Layer (business logic)
// ============================================
const db = require('../config/database');
const Job = require('../models/Job');
const Vehicle = require('../models/Vehicle');

/**
 * Reports Service
 * 
 * This service provides various analytical reports for the system.
 * All reports support date filtering for flexible analysis.
 * 
 * Available reports:
 * - Jobs per vehicle (count, duration, status breakdown)
 * - Vehicle utilization percentage (time-based)
 * - Jobs by service type (installation, delivery, maintenance)
 * - Completed vs cancelled jobs (success rate analysis)
 * 
 * All queries are optimized for MySQL and include proper indexing hints.
 */
class ReportsService {
  
  // ==========================================
  // REPORT 1: Jobs Per Vehicle
  // PURPOSE: Count jobs assigned to each vehicle
  // ==========================================
  /**
   * Get jobs per vehicle report
   * 
   * Shows how many jobs each vehicle has handled
   * within a date range, broken down by status.
   * 
   * @param {Object} filters - Date filters
   * @param {string} filters.startDate - Start date YYYY-MM-DD
   * @param {string} filters.endDate - End date YYYY-MM-DD
   * @param {string} filters.jobType - Optional: filter by job type
   * @returns {Promise} Report data with vehicle statistics
   * 
   * Example response:
   * {
   *   summary: {
   *     totalJobs: 45,
   *     totalVehicles: 3,
   *     avgJobsPerVehicle: 15
   *   },
   *   vehicles: [
   *     {
   *       vehicleId: 1,
   *       vehicleName: "Delivery Van 1",
   *       totalJobs: 20,
   *       jobsByStatus: {
   *         completed: 15,
   *         assigned: 3,
   *         in_progress: 2,
   *         cancelled: 0
   *       },
   *       totalDurationMinutes: 1800
   *     }
   *   ]
   * }
   */
  static async getJobsPerVehicle(filters = {}) {
    try {
      const { startDate, endDate, jobType = null } = filters;
      
      console.log('📊 Generating Jobs Per Vehicle Report');
      console.log(`   Date Range: ${startDate} to ${endDate}`);
      if (jobType) console.log(`   Job Type Filter: ${jobType}`);
      
      // Validate date range
      this.validateDateRange(startDate, endDate);
      
      // Build SQL query with dynamic filters
      let sql = `
        SELECT 
          v.id as vehicle_id,
          v.vehicle_name,
          v.license_plate,
          v.vehicle_type,
          v.capacity_kg,
          v.is_active,
          COUNT(j.id) as total_jobs,
          SUM(j.estimated_duration_minutes) as total_duration_minutes,
          
          -- Breakdown by status
          SUM(CASE WHEN j.current_status = 'completed' THEN 1 ELSE 0 END) as completed_count,
          SUM(CASE WHEN j.current_status = 'assigned' THEN 1 ELSE 0 END) as assigned_count,
          SUM(CASE WHEN j.current_status = 'in_progress' THEN 1 ELSE 0 END) as in_progress_count,
          SUM(CASE WHEN j.current_status = 'cancelled' THEN 1 ELSE 0 END) as cancelled_count,
          SUM(CASE WHEN j.current_status = 'pending' THEN 1 ELSE 0 END) as pending_count,
          
          -- Breakdown by job type
          SUM(CASE WHEN j.job_type = 'installation' THEN 1 ELSE 0 END) as installation_count,
          SUM(CASE WHEN j.job_type = 'delivery' THEN 1 ELSE 0 END) as delivery_count,
          SUM(CASE WHEN j.job_type = 'maintenance' THEN 1 ELSE 0 END) as maintenance_count
          
        FROM vehicles v
        LEFT JOIN job_assignments ja ON v.id = ja.vehicle_id
        LEFT JOIN jobs j ON ja.job_id = j.id
          AND j.scheduled_date BETWEEN ? AND ?
          ${jobType ? 'AND j.job_type = ?' : ''}
        WHERE v.is_active = 1
        GROUP BY v.id, v.vehicle_name, v.license_plate, v.vehicle_type, v.capacity_kg, v.is_active
        ORDER BY total_jobs DESC, v.vehicle_name ASC
      `;
      
      const params = [startDate, endDate];
      if (jobType) params.push(jobType);
      
      const [vehicleStats] = await db.query(sql, params);
      
      // Calculate summary statistics
      const totalJobs = vehicleStats.reduce((sum, v) => sum + v.total_jobs, 0);
      const activeVehicles = vehicleStats.filter(v => v.is_active === 1).length;
      
      // Format the response
      const report = {
        summary: {
          totalJobs: totalJobs,
          totalVehicles: vehicleStats.length,
          activeVehicles: activeVehicles,
          avgJobsPerVehicle: vehicleStats.length > 0 ? Math.round(totalJobs / vehicleStats.length) : 0,
          dateRange: { startDate, endDate }
        },
        vehicles: vehicleStats.map(vehicle => ({
          vehicleId: vehicle.vehicle_id,
          vehicleName: vehicle.vehicle_name,
          licensePlate: vehicle.license_plate,
          vehicleType: vehicle.vehicle_type,
          capacityKg: vehicle.capacity_kg,
          isActive: vehicle.is_active === 1,
          
          // Job counts
          totalJobs: Number(vehicle.total_jobs) || 0,
          totalDurationMinutes: Number(vehicle.total_duration_minutes) || 0,
          totalDurationHours: vehicle.total_duration_minutes ? Math.round(vehicle.total_duration_minutes / 60) : 0,
          
          // Status breakdown
          jobsByStatus: {
            completed: Number(vehicle.completed_count) || 0,
            assigned: Number(vehicle.assigned_count) || 0,
            inProgress: Number(vehicle.in_progress_count) || 0,
            cancelled: Number(vehicle.cancelled_count) || 0,
            pending: Number(vehicle.pending_count) || 0
          },
          
          // Job type breakdown
          jobsByType: {
            installation: Number(vehicle.installation_count) || 0,
            delivery: Number(vehicle.delivery_count) || 0,
            maintenance: Number(vehicle.maintenance_count) || 0
          },
          
          // Calculate completion rate
          completionRate: vehicle.total_jobs > 0 
            ? Math.round((vehicle.completed_count / vehicle.total_jobs) * 100) 
            : 0
        }))
      };
      
      console.log(`✅ Jobs Per Vehicle Report Generated`);
      console.log(`   Total Jobs: ${report.summary.totalJobs}`);
      console.log(`   Vehicles: ${report.summary.totalVehicles}`);
      
      return report;
      
    } catch (error) {
      console.error('❌ Error in ReportsService.getJobsPerVehicle:', error);
      throw error;
    }
  }
  
  // ==========================================
  // REPORT 2: Vehicle Utilization
  // PURPOSE: Calculate vehicle utilization percentage
  // ==========================================
  /**
   * Get vehicle utilization report
   * 
   * Calculates how much time each vehicle was utilized
   * vs available within the date range.
   * 
   * Utilization Formula:
   * (Total job duration minutes / Total available minutes) * 100
   * 
   * @param {Object} filters - Date filters
   * @param {string} filters.startDate - Start date YYYY-MM-DD
   * @param {string} filters.endDate - End date YYYY-MM-DD
   * @returns {Promise} Utilization report
   * 
   * Example response:
   * {
   *   summary: {
   *     avgUtilization: 65.5,
   *     totalAvailableHours: 216,
   *     totalUtilizedHours: 141
   *   },
   *   vehicles: [
   *     {
   *       vehicleId: 1,
   *       vehicleName: "Delivery Van 1",
   *       utilizationPercent: 75.2,
   *       utilizedMinutes: 2700,
   *       utilizedHours: 45,
   *       availableMinutes: 3600,
   *       availableHours: 60
   *     }
   *   ]
   * }
   */
  static async getVehicleUtilization(filters = {}) {
    try {
      const { startDate, endDate } = filters;
      
      console.log('📊 Generating Vehicle Utilization Report');
      console.log(`   Date Range: ${startDate} to ${endDate}`);
      
      // Validate date range
      this.validateDateRange(startDate, endDate);
      
      // Calculate total available minutes in date range
      const dateRangeDays = this.getDateRangeDays(startDate, endDate);
      const WORKING_HOURS_PER_DAY = 12; // 6:00 AM to 6:00 PM (adjust as needed)
      const MINUTES_PER_DAY = WORKING_HOURS_PER_DAY * 60;
      const totalAvailableMinutes = dateRangeDays * MINUTES_PER_DAY;
      
      // SQL query to get utilization data
      const sql = `
        SELECT 
          v.id as vehicle_id,
          v.vehicle_name,
          v.license_plate,
          v.vehicle_type,
          v.is_active,
          
          -- Sum of all job durations for this vehicle
          COALESCE(SUM(j.estimated_duration_minutes), 0) as utilized_minutes,
          
          -- Count of jobs
          COUNT(j.id) as total_jobs,
          
          -- Breakdown by status
          SUM(CASE WHEN j.current_status = 'completed' THEN j.estimated_duration_minutes ELSE 0 END) as completed_minutes,
          SUM(CASE WHEN j.current_status = 'cancelled' THEN j.estimated_duration_minutes ELSE 0 END) as cancelled_minutes
          
        FROM vehicles v
        LEFT JOIN job_assignments ja ON v.id = ja.vehicle_id
        LEFT JOIN jobs j ON ja.job_id = j.id
          AND j.scheduled_date BETWEEN ? AND ?
          AND j.current_status NOT IN ('pending')
        WHERE v.is_active = 1
        GROUP BY v.id, v.vehicle_name, v.license_plate, v.vehicle_type, v.is_active
        ORDER BY utilized_minutes DESC
      `;
      
      const [utilizationData] = await db.query(sql, [startDate, endDate]);
      
      // Format the response
      const vehicles = utilizationData.map(vehicle => {
        const utilizedMinutes = Number(vehicle.utilized_minutes);
        const utilizationPercent = Math.min(
          Math.round((utilizedMinutes / totalAvailableMinutes) * 1000) / 10,
          100
        );
        
        return {
          vehicleId: vehicle.vehicle_id,
          vehicleName: vehicle.vehicle_name,
          licensePlate: vehicle.license_plate,
          vehicleType: vehicle.vehicle_type,
          isActive: vehicle.is_active === 1,
          
          utilizationPercent: utilizationPercent,
          utilizedMinutes: utilizedMinutes,
          utilizedHours: Math.round(utilizedMinutes / 60),
          
          availableMinutes: totalAvailableMinutes,
          availableHours: Math.round(totalAvailableMinutes / 60),
          
          totalJobs: Number(vehicle.total_jobs) || 0,
          
          // Breakdown by status
          completedMinutes: Number(vehicle.completed_minutes) || 0,
          cancelledMinutes: Number(vehicle.cancelled_minutes) || 0,
          
          // Efficiency metrics
          efficiency: vehicle.total_jobs > 0 
            ? Math.round(utilizedMinutes / vehicle.total_jobs) 
            : 0 // Avg minutes per job
        };
      });
      
      // Calculate summary statistics
      const totalUtilizedMinutes = vehicles.reduce((sum, v) => sum + v.utilizedMinutes, 0);
      const avgUtilization = vehicles.length > 0 
        ? Math.round((totalUtilizedMinutes / (vehicles.length * totalAvailableMinutes)) * 1000) / 10 
        : 0;
      
      const report = {
        summary: {
          avgUtilization: avgUtilization,
          totalVehicles: vehicles.length,
          totalAvailableHours: Math.round((vehicles.length * totalAvailableMinutes) / 60),
          totalUtilizedHours: Math.round(totalUtilizedMinutes / 60),
          totalAvailableMinutes: vehicles.length * totalAvailableMinutes,
          totalUtilizedMinutes: totalUtilizedMinutes,
          dateRange: { startDate, endDate },
          workingHoursPerDay: WORKING_HOURS_PER_DAY,
          dateRangeDays: dateRangeDays
        },
        vehicles: vehicles.sort((a, b) => b.utilizationPercent - a.utilizationPercent)
      };
      
      console.log(`✅ Vehicle Utilization Report Generated`);
      console.log(`   Average Utilization: ${report.summary.avgUtilization}%`);
      console.log(`   Total Utilized Hours: ${report.summary.totalUtilizedHours}`);
      
      return report;
      
    } catch (error) {
      console.error('❌ Error in ReportsService.getVehicleUtilization:', error);
      throw error;
    }
  }
  
  // ==========================================
  // REPORT 3: Jobs By Service Type
  // PURPOSE: Analyze jobs by type (installation, delivery, maintenance)
  // ==========================================
  /**
   * Get jobs by service type report
   * 
   * Breaks down jobs by type and shows trends over time.
   * 
   * @param {Object} filters - Date filters
   * @param {string} filters.startDate - Start date YYYY-MM-DD
   * @param {string} filters.endDate - End date YYYY-MM-DD
   * @param {boolean} filters.includeTrends - Include daily/weekly trends
   * @returns {Promise} Service type report
   * 
   * Example response:
   * {
   *   summary: {
   *     totalJobs: 45,
   *     mostCommonType: "delivery"
   *   },
   *   byType: {
   *     installation: { count: 15, percent: 33.3, avgDuration: 180 },
   *     delivery: { count: 20, percent: 44.4, avgDuration: 90 },
   *     maintenance: { count: 10, percent: 22.2, avgDuration: 240 }
   *   },
   *   trends: [...] // Daily breakdown if requested
   * }
   */
  static async getJobsByServiceType(filters = {}) {
    try {
      const { startDate, endDate, includeTrends = false } = filters;
      
      console.log('📊 Generating Jobs By Service Type Report');
      console.log(`   Date Range: ${startDate} to ${endDate}`);
      console.log(`   Include Trends: ${includeTrends}`);
      
      // Validate date range
      this.validateDateRange(startDate, endDate);
      
      // Main query: Jobs by type
      const mainSql = `
        SELECT 
          j.job_type,
          COUNT(j.id) as job_count,
          SUM(j.estimated_duration_minutes) as total_duration_minutes,
          AVG(j.estimated_duration_minutes) as avg_duration_minutes,
          
          -- Breakdown by status
          SUM(CASE WHEN j.current_status = 'completed' THEN 1 ELSE 0 END) as completed_count,
          SUM(CASE WHEN j.current_status = 'cancelled' THEN 1 ELSE 0 END) as cancelled_count,
          SUM(CASE WHEN j.current_status = 'assigned' THEN 1 ELSE 0 END) as assigned_count,
          
          -- Breakdown by priority
          SUM(CASE WHEN j.priority = 'urgent' THEN 1 ELSE 0 END) as urgent_count,
          SUM(CASE WHEN j.priority = 'high' THEN 1 ELSE 0 END) as high_count,
          SUM(CASE WHEN j.priority = 'normal' THEN 1 ELSE 0 END) as normal_count,
          SUM(CASE WHEN j.priority = 'low' THEN 1 ELSE 0 END) as low_count
          
        FROM jobs j
        WHERE j.scheduled_date BETWEEN ? AND ?
        GROUP BY j.job_type
        ORDER BY job_count DESC
      `;
      
      const [byTypeData] = await db.query(mainSql, [startDate, endDate]);
      
      // Calculate total jobs
      const totalJobs = byTypeData.reduce((sum, item) => sum + item.job_count, 0);
      
      // Format by-type data
      const byType = {};
      byTypeData.forEach(item => {
        const percent = totalJobs > 0 ? Math.round((item.job_count / totalJobs) * 1000) / 10 : 0;
        
        byType[item.job_type] = {
          count: Number(item.job_count),
          percent: percent,
          totalDurationMinutes: Number(item.total_duration_minutes) || 0,
          totalDurationHours: item.total_duration_minutes ? Math.round(item.total_duration_minutes / 60) : 0,
          avgDurationMinutes: Math.round(item.avg_duration_minutes) || 0,
          avgDurationHours: item.avg_duration_minutes ? Math.round(item.avg_duration_minutes / 60) : 0,
          
          // Status breakdown
          byStatus: {
            completed: Number(item.completed_count) || 0,
            cancelled: Number(item.cancelled_count) || 0,
            assigned: Number(item.assigned_count) || 0,
            other: item.job_count - (item.completed_count + item.cancelled_count + item.assigned_count)
          },
          
          // Priority breakdown
          byPriority: {
            urgent: Number(item.urgent_count) || 0,
            high: Number(item.high_count) || 0,
            normal: Number(item.normal_count) || 0,
            low: Number(item.low_count) || 0
          },
          
          // Success rate
          successRate: item.job_count > 0 
            ? Math.round((item.completed_count / item.job_count) * 100) 
            : 0
        };
      });
      
      // Find most common type
      const mostCommonType = byTypeData.length > 0 
        ? byTypeData[0].job_type 
        : null;
      
      // Get trends if requested
      let trends = [];
      if (includeTrends) {
        trends = await this.getDailyTrends(startDate, endDate);
      }
      
      const report = {
        summary: {
          totalJobs: totalJobs,
          mostCommonType: mostCommonType,
          typesCount: Object.keys(byType).length,
          dateRange: { startDate, endDate }
        },
        byType: byType,
        trends: trends
      };
      
      console.log(`✅ Jobs By Service Type Report Generated`);
      console.log(`   Total Jobs: ${report.summary.totalJobs}`);
      console.log(`   Types: ${report.summary.typesCount}`);
      
      return report;
      
    } catch (error) {
      console.error('❌ Error in ReportsService.getJobsByServiceType:', error);
      throw error;
    }
  }
  
  // ==========================================
  // REPORT 4: Completed vs Cancelled Jobs
  // PURPOSE: Analyze job completion and cancellation rates
  // ==========================================
  /**
   * Get completed vs cancelled jobs report
   * 
   * Analyzes success rates, cancellation reasons, and trends.
   * 
   * @param {Object} filters - Date filters
   * @param {string} filters.startDate - Start date YYYY-MM-DD
   * @param {string} filters.endDate - End date YYYY-MM-DD
   * @param {string} filters.jobType - Optional: filter by job type
   * @returns {Promise} Completion analysis report
   * 
   * Example response:
   * {
   *   summary: {
   *     totalJobs: 50,
   *     completed: 40,
   *     cancelled: 5,
   *     completionRate: 80,
   *     cancellationRate: 10
   *   },
   *   byStatus: {
   *     completed: { count: 40, percent: 80 },
   *     cancelled: { count: 5, percent: 10 },
   *     inProgress: { count: 3, percent: 6 }
   *   },
   *   byType: {...}, // Breakdown by job type
   *   byVehicle: {...}, // Breakdown by vehicle
   *   cancellationReasons: [...] // If available
   * }
   */
  static async getCompletionAnalysis(filters = {}) {
    try {
      const { startDate, endDate, jobType = null } = filters;
      
      console.log('📊 Generating Completion Analysis Report');
      console.log(`   Date Range: ${startDate} to ${endDate}`);
      if (jobType) console.log(`   Job Type Filter: ${jobType}`);
      
      // Validate date range
      this.validateDateRange(startDate, endDate);
      
      // Build SQL query
      let sql = `
        SELECT 
          j.current_status,
          j.job_type,
          v.vehicle_name,
          v.id as vehicle_id,
          COUNT(j.id) as job_count,
          SUM(j.estimated_duration_minutes) as total_duration_minutes,
          
          -- Priority breakdown
          SUM(CASE WHEN j.priority = 'urgent' THEN 1 ELSE 0 END) as urgent_count,
          SUM(CASE WHEN j.priority = 'high' THEN 1 ELSE 0 END) as high_count
          
        FROM jobs j
        LEFT JOIN job_assignments ja ON j.id = ja.job_id
        LEFT JOIN vehicles v ON ja.vehicle_id = v.id
        WHERE j.scheduled_date BETWEEN ? AND ?
        ${jobType ? 'AND j.job_type = ?' : ''}
        GROUP BY j.current_status, j.job_type, v.vehicle_name, v.id
        ORDER BY j.current_status, job_count DESC
      `;
      
      const params = [startDate, endDate];
      if (jobType) params.push(jobType);
      
      const [rawData] = await db.query(sql, params);
      
      // Aggregate data
      const totalJobs = rawData.reduce((sum, row) => sum + row.job_count, 0);
      
      // Group by status
      const byStatus = {};
      const byType = {};
      const byVehicle = {};
      
      rawData.forEach(row => {
        const status = row.current_status;
        const type = row.job_type;
        const vehicle = row.vehicle_name;
        
        // By status
        if (!byStatus[status]) {
          byStatus[status] = { count: 0, duration: 0, byType: {}, byVehicle: {} };
        }
        byStatus[status].count += row.job_count;
        byStatus[status].duration += row.total_duration_minutes || 0;
        
        // By type within status
        if (!byStatus[status].byType[type]) {
          byStatus[status].byType[type] = 0;
        }
        byStatus[status].byType[type] += row.job_count;
        
        // By vehicle within status
        if (vehicle) {
          if (!byStatus[status].byVehicle[vehicle]) {
            byStatus[status].byVehicle[vehicle] = 0;
          }
          byStatus[status].byVehicle[vehicle] += row.job_count;
        }
        
        // By type (overall)
        if (!byType[type]) {
          byType[type] = { count: 0, byStatus: {} };
        }
        byType[type].count += row.job_count;
        
        if (!byType[type].byStatus[status]) {
          byType[type].byStatus[status] = 0;
        }
        byType[type].byStatus[status] += row.job_count;
        
        // By vehicle (overall)
        if (vehicle) {
          if (!byVehicle[vehicle]) {
            byVehicle[vehicle] = { 
              count: 0, 
              vehicleId: row.vehicle_id,
              byStatus: {} 
            };
          }
          byVehicle[vehicle].count += row.job_count;
          
          if (!byVehicle[vehicle].byStatus[status]) {
            byVehicle[vehicle].byStatus[status] = 0;
          }
          byVehicle[vehicle].byStatus[status] += row.job_count;
        }
      });
      
      // Calculate percentages and format
      const formattedByStatus = {};
      Object.keys(byStatus).forEach(status => {
        formattedByStatus[status] = {
          count: byStatus[status].count,
          percent: totalJobs > 0 ? Math.round((byStatus[status].count / totalJobs) * 1000) / 10 : 0,
          durationMinutes: byStatus[status].duration,
          durationHours: Math.round(byStatus[status].duration / 60),
          byType: byStatus[status].byType,
          byVehicle: byStatus[status].byVehicle
        };
      });
      
      const formattedByType = {};
      Object.keys(byType).forEach(type => {
        formattedByType[type] = {
          count: byType[type].count,
          percent: totalJobs > 0 ? Math.round((byType[type].count / totalJobs) * 1000) / 10 : 0,
          byStatus: byType[type].byStatus
        };
      });
      
      const formattedByVehicle = {};
      Object.keys(byVehicle).forEach(vehicle => {
        formattedByVehicle[vehicle] = {
          count: byVehicle[vehicle].count,
          vehicleId: byVehicle[vehicle].vehicleId,
          percent: totalJobs > 0 ? Math.round((byVehicle[vehicle].count / totalJobs) * 1000) / 10 : 0,
          byStatus: byVehicle[vehicle].byStatus
        };
      });
      
      // Calculate rates
      const completedCount = byStatus.completed?.count || 0;
      const cancelledCount = byStatus.cancelled?.count || 0;
      const assignedCount = byStatus.assigned?.count || 0;
      const inProgressCount = byStatus.in_progress?.count || 0;
      
      const completionRate = totalJobs > 0 ? Math.round((completedCount / totalJobs) * 100) : 0;
      const cancellationRate = totalJobs > 0 ? Math.round((cancelledCount / totalJobs) * 100) : 0;
      const activeRate = totalJobs > 0 ? Math.round(((assignedCount + inProgressCount) / totalJobs) * 100) : 0;
      
      const report = {
        summary: {
          totalJobs: totalJobs,
          completed: completedCount,
          cancelled: cancelledCount,
          assigned: assignedCount,
          inProgress: inProgressCount,
          pending: byStatus.pending?.count || 0,
          
          completionRate: completionRate,
          cancellationRate: cancellationRate,
          activeRate: activeRate,
          pendingRate: 100 - completionRate - cancellationRate - activeRate,
          
          dateRange: { startDate, endDate }
        },
        byStatus: formattedByStatus,
        byType: formattedByType,
        byVehicle: formattedByVehicle
      };
      
      console.log(`✅ Completion Analysis Report Generated`);
      console.log(`   Completion Rate: ${report.summary.completionRate}%`);
      console.log(`   Cancellation Rate: ${report.summary.cancellationRate}%`);
      
      return report;
      
    } catch (error) {
      console.error('❌ Error in ReportsService.getCompletionAnalysis:', error);
      throw error;
    }
  }
  
  // ==========================================
  // COMBINED REPORT: Executive Dashboard
  // PURPOSE: All key metrics in one report
  // ==========================================
  /**
   * Get executive dashboard report
   * 
   * Combines all key metrics into a single comprehensive report.
   * Useful for high-level overview.
   * 
   * @param {Object} filters - Date filters
   * @param {string} filters.startDate - Start date YYYY-MM-DD
   * @param {string} filters.endDate - End date YYYY-MM-DD
   * @returns {Promise} Executive dashboard data
   */
  static async getExecutiveDashboard(filters = {}) {
    try {
      console.log('📊 Generating Executive Dashboard Report');
      
      // Execute all reports in parallel
      const [
        jobsPerVehicle,
        utilization,
        jobsByType,
        completionAnalysis
      ] = await Promise.all([
        this.getJobsPerVehicle(filters),
        this.getVehicleUtilization(filters),
        this.getJobsByServiceType(filters),
        this.getCompletionAnalysis(filters)
      ]);
      
      const dashboard = {
        dateRange: filters,
        
        // Key metrics
        keyMetrics: {
          totalJobs: completionAnalysis.summary.totalJobs,
          completedJobs: completionAnalysis.summary.completed,
          cancelledJobs: completionAnalysis.summary.cancelled,
          activeJobs: completionAnalysis.summary.assigned + completionAnalysis.summary.inProgress,
          
          completionRate: completionAnalysis.summary.completionRate,
          cancellationRate: completionAnalysis.summary.cancellationRate,
          
          avgVehicleUtilization: utilization.summary.avgUtilization,
          totalUtilizedHours: utilization.summary.totalUtilizedHours,
          
          totalVehicles: jobsPerVehicle.summary.totalVehicles,
          activeVehicles: jobsPerVehicle.summary.activeVehicles
        },
        
        // Top performers
        topPerformers: {
          mostUtilizedVehicle: utilization.vehicles[0],
          mostJobsVehicle: jobsPerVehicle.vehicles[0],
          mostCompletedJobsVehicle: jobsPerVehicle.vehicles.sort(
            (a, b) => b.jobsByStatus.completed - a.jobsByStatus.completed
          )[0],
          mostReliableVehicle: jobsPerVehicle.vehicles.sort(
            (a, b) => b.completionRate - a.completionRate
          )[0]
        },
        
        // Service type insights
        serviceTypeInsights: jobsByType.byType,
        
        // Vehicle breakdown
        vehiclesBreakdown: jobsPerVehicle.vehicles,
        
        // Completion trends
        completionTrends: completionAnalysis.byStatus
      };
      
      console.log(`✅ Executive Dashboard Generated`);
      console.log(`   Total Jobs: ${dashboard.keyMetrics.totalJobs}`);
      console.log(`   Completion Rate: ${dashboard.keyMetrics.completionRate}%`);
      
      return dashboard;
      
    } catch (error) {
      console.error('❌ Error in ReportsService.getExecutiveDashboard:', error);
      throw error;
    }
  }
  
  // ==========================================
  // HELPER: Get Daily Trends
  // PURPOSE: Get daily job counts for trend analysis
  // ==========================================
  static async getDailyTrends(startDate, endDate) {
    try {
      const sql = `
        SELECT 
          j.scheduled_date,
          j.job_type,
          j.current_status,
          COUNT(j.id) as job_count,
          SUM(j.estimated_duration_minutes) as total_duration_minutes
        FROM jobs j
        WHERE j.scheduled_date BETWEEN ? AND ?
        GROUP BY j.scheduled_date, j.job_type, j.current_status
        ORDER BY j.scheduled_date ASC, job_count DESC
      `;
      
      const [trends] = await db.query(sql, [startDate, endDate]);
      
      // Group by date
      const dailyTrends = {};
      trends.forEach(row => {
        const date = row.scheduled_date;
        
        if (!dailyTrends[date]) {
          dailyTrends[date] = {
            date: date,
            totalJobs: 0,
            totalDurationMinutes: 0,
            byType: {},
            byStatus: {}
          };
        }
        
        dailyTrends[date].totalJobs += row.job_count;
        dailyTrends[date].totalDurationMinutes += row.total_duration_minutes || 0;
        
        // By type
        if (!dailyTrends[date].byType[row.job_type]) {
          dailyTrends[date].byType[row.job_type] = 0;
        }
        dailyTrends[date].byType[row.job_type] += row.job_count;
        
        // By status
        if (!dailyTrends[date].byStatus[row.current_status]) {
          dailyTrends[date].byStatus[row.current_status] = 0;
        }
        dailyTrends[date].byStatus[row.current_status] += row.job_count;
      });
      
      return Object.values(dailyTrends);
      
    } catch (error) {
      console.error('Error in getDailyTrends:', error);
      return [];
    }
  }
  
  // ==========================================
  // HELPER: Validate Date Range
  // ==========================================
  static validateDateRange(startDate, endDate) {
    if (!startDate || !endDate) {
      throw new Error('Both startDate and endDate are required');
    }
    
    // Basic date format validation
    const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
    if (!dateRegex.test(startDate) || !dateRegex.test(endDate)) {
      throw new Error('Dates must be in YYYY-MM-DD format');
    }
    
    // Check that end date is not before start date
    if (endDate < startDate) {
      throw new Error('End date cannot be before start date');
    }
    
    // Optional: Limit date range to reasonable period (e.g., 1 year max)
    const start = new Date(startDate);
    const end = new Date(endDate);
    const diffTime = Math.abs(end - start);
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    
    if (diffDays > 365) {
      throw new Error('Date range cannot exceed 365 days');
    }
  }
  
  // ==========================================
  // HELPER: Calculate Date Range Days
  // ==========================================
  static getDateRangeDays(startDate, endDate) {
    const start = new Date(startDate);
    const end = new Date(endDate);
    const diffTime = Math.abs(end - start);
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24)) + 1; // +1 to include both start and end dates
    return diffDays;
  }
}

module.exports = ReportsService;