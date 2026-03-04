// ============================================
// FILE: src/services/dashboardService.js
// PURPOSE: Aggregate dashboard summary data
// LAYER: Service Layer (business logic)
// ============================================
const db = require('../config/database');
const Job = require('../models/Job');
const Vehicle = require('../models/Vehicle');
const VehicleAvailabilityService = require('./vehicleAvailabilityService');

/**
 * Dashboard Service
 * 
 * This service provides aggregated summary data for the dashboard.
 * It combines information from jobs, vehicles, and assignments
 * to give a quick overview of the system state.
 * 
 * Data returned:
 * - Jobs scheduled today
 * - Jobs scheduled this week
 * - Vehicles currently busy
 * - Vehicles currently available
 * 
 * Optimized for frontend consumption with clear structure.
 */
class DashboardService {
  
  // ==========================================
  // MAIN FUNCTION: getDashboardSummary
  // PURPOSE: Get complete dashboard summary
  // ==========================================
  /**
   * Get complete dashboard summary
   * 
   * @param {Object} options - Optional filters
   * @param {string} options.date - Specific date to check (defaults to today)
   * @returns {Promise} Dashboard summary object
   * 
   * Example response:
   * {
   *   summary: {
   *     jobsToday: 5,
   *     jobsThisWeek: 23,
   *     vehiclesBusy: 2,
   *     vehiclesAvailable: 1,
   *     totalVehicles: 3
   *   },
   *   jobsToday: [...],
   *   jobsThisWeek: [...],
   *   vehiclesBusy: [...],
   *   vehiclesAvailable: [...]
   * }
   */
  static async getDashboardSummary(options = {}) {
    try {
      const { date = null } = options;
      
      // Get today's date in YYYY-MM-DD format
      const today = date || new Date().toISOString().split('T')[0];
      const todayDate = new Date(today);
      
      // Calculate week range (Monday to Sunday)
      const weekStart = this.getWeekStart(todayDate);
      const weekEnd = this.getWeekEnd(todayDate);
      
      console.log('📊 Dashboard Summary Request');
      console.log(`   Today: ${today}`);
      console.log(`   Week: ${weekStart} to ${weekEnd}`);
      
      // Execute all queries in parallel for better performance
      const [
        jobsToday,
        jobsThisWeek,
        allVehicles,
        currentAssignments
      ] = await Promise.all([
        // Get jobs scheduled for today
        this.getJobsForDate(today),
        
        // Get jobs scheduled for this week
        this.getJobsForWeek(weekStart, weekEnd),
        
        // Get all active vehicles
        Vehicle.getAllVehicles(true),
        
        // Get current assignments (for busy/available calculation)
        this.getCurrentAssignments(today)
      ]);
      
      // Separate vehicles into busy and available
      const { busyVehicles, availableVehicles } = this.categorizeVehicles(
        allVehicles,
        currentAssignments,
        today
      );
      
      // Build summary response
      const summary = {
        summary: {
          jobsToday: jobsToday.length,
          jobsThisWeek: jobsThisWeek.length,
          vehiclesBusy: busyVehicles.length,
          vehiclesAvailable: availableVehicles.length,
          totalVehicles: allVehicles.length
        },
        jobsToday: this.formatJobsForFrontend(jobsToday),
        jobsThisWeek: this.formatJobsForFrontend(jobsThisWeek),
        vehiclesBusy: this.formatVehiclesForFrontend(busyVehicles),
        vehiclesAvailable: this.formatVehiclesForFrontend(availableVehicles)
      };
      
      console.log('✅ Dashboard summary compiled');
      console.log(`   Jobs today: ${summary.summary.jobsToday}`);
      console.log(`   Jobs this week: ${summary.summary.jobsThisWeek}`);
      console.log(`   Vehicles busy: ${summary.summary.vehiclesBusy}`);
      console.log(`   Vehicles available: ${summary.summary.vehiclesAvailable}`);
      
      return summary;
      
    } catch (error) {
      console.error('❌ Error in DashboardService.getDashboardSummary:', error);
      throw error;
    }
  }
  
  // ==========================================
  // HELPER: Get jobs for a specific date
  // ==========================================
  /**
   * Get all jobs scheduled for a specific date
   * 
   * @param {string} date - Date in YYYY-MM-DD format
   * @returns {Promise<Array>} Array of job objects
   */
  static async getJobsForDate(date) {
    try {
      const jobs = await Job.getJobsByDate(date);
      return jobs;
    } catch (error) {
      console.error('Error getting jobs for date:', error);
      throw error;
    }
  }
  
  // ==========================================
  // HELPER: Get jobs for a week range
  // ==========================================
  /**
   * Get all jobs scheduled within a week range
   * 
   * @param {string} startDate - Start date YYYY-MM-DD
   * @param {string} endDate - End date YYYY-MM-DD
   * @returns {Promise<Array>} Array of job objects
   */
  static async getJobsForWeek(startDate, endDate) {
    try {
      const jobs = await Job.getJobsByDateRange(startDate, endDate);
      return jobs;
    } catch (error) {
      console.error('Error getting jobs for week:', error);
      throw error;
    }
  }
  
  // ==========================================
  // HELPER: Get current assignments for today
  // ==========================================
  /**
   * Get all current job assignments for today
   * Used to determine which vehicles are busy
   * 
   * @param {string} date - Date in YYYY-MM-DD format
   * @returns {Promise<Array>} Array of assignment objects
   */
  static async getCurrentAssignments(date) {
    try {
      // Get current time to check which jobs are active now
      const now = new Date();
      const currentTime = now.toTimeString().split(' ')[0]; // HH:MM:SS
      
      // Query to get jobs that are currently in progress or assigned for now
      const sql = `
        SELECT 
          ja.id as assignment_id,
          ja.job_id,
          ja.vehicle_id,
          ja.driver_id,
          j.job_number,
          j.customer_name,
          j.scheduled_time_start,
          j.scheduled_time_end,
          j.current_status,
          v.vehicle_name,
          v.license_plate,
          u.full_name as driver_name
        FROM job_assignments ja
        INNER JOIN jobs j ON ja.job_id = j.id
        INNER JOIN vehicles v ON ja.vehicle_id = v.id
        LEFT JOIN users u ON ja.driver_id = u.id
        WHERE 
          j.scheduled_date = ?
          AND j.current_status IN ('assigned', 'in_progress')
          AND ? BETWEEN j.scheduled_time_start AND j.scheduled_time_end
      `;
      
      const [assignments] = await db.query(sql, [date, currentTime]);
      return assignments;
    } catch (error) {
      console.error('Error getting current assignments:', error);
      throw error;
    }
  }
  
  // ==========================================
  // HELPER: Categorize vehicles by availability
  // ==========================================
  /**
   * Separate vehicles into busy and available arrays
   * 
   * @param {Array} allVehicles - All active vehicles
   * @param {Array} currentAssignments - Current job assignments
   * @param {string} date - Current date
   * @returns {Object} { busyVehicles, availableVehicles }
   */
  static categorizeVehicles(allVehicles, currentAssignments, date) {
    const busyVehicleIds = new Set(
      currentAssignments.map(assignment => assignment.vehicle_id)
    );
    
    const busyVehicles = [];
    const availableVehicles = [];
    
    allVehicles.forEach(vehicle => {
      if (busyVehicleIds.has(vehicle.id)) {
        // Find the assignment for this vehicle
        const assignment = currentAssignments.find(
          a => a.vehicle_id === vehicle.id
        );
        
        busyVehicles.push({
          ...vehicle,
          currentAssignment: assignment
        });
      } else {
        // Check if vehicle is available right now
        availableVehicles.push(vehicle);
      }
    });
    
    return { busyVehicles, availableVehicles };
  }
  
  // ==========================================
  // HELPER: Format jobs for frontend
  // ==========================================
  /**
   * Format job data for easy frontend consumption
   * 
   * @param {Array} jobs - Array of job objects
   * @returns {Array} Formatted job objects
   */
  static formatJobsForFrontend(jobs) {
    return jobs.map(job => ({
      id: job.id,
      jobNumber: job.job_number,
      jobType: job.job_type,
      customerName: job.customer_name,
      customerPhone: job.customer_phone,
      customerAddress: job.customer_address,
      description: job.description,
      scheduledDate: job.scheduled_date,
      scheduledTimeStart: job.scheduled_time_start,
      scheduledTimeEnd: job.scheduled_time_end,
      durationMinutes: job.estimated_duration_minutes,
      status: job.current_status,
      priority: job.priority,
      vehicleName: job.vehicle_name || 'Not assigned',
      licensePlate: job.license_plate || null,
      driverName: job.driver_name || null,
      createdAt: job.created_at,
      updatedAt: job.updated_at
    }));
  }
  
  // ==========================================
  // HELPER: Format vehicles for frontend
  // ==========================================
  /**
   * Format vehicle data for easy frontend consumption
   * 
   * @param {Array} vehicles - Array of vehicle objects
   * @returns {Array} Formatted vehicle objects
   */
  static formatVehiclesForFrontend(vehicles) {
    return vehicles.map(vehicle => {
      const baseVehicle = {
        id: vehicle.id,
        name: vehicle.vehicle_name,
        licensePlate: vehicle.license_plate,
        type: vehicle.vehicle_type,
        capacityKg: vehicle.capacity_kg,
        isActive: vehicle.is_active === 1,
        lastMaintenance: vehicle.last_maintenance_date,
        notes: vehicle.notes
      };
      
      // Add assignment info if vehicle is busy
      if (vehicle.currentAssignment) {
        return {
          ...baseVehicle,
          isBusy: true,
          currentJob: {
            id: vehicle.currentAssignment.job_id,
            jobNumber: vehicle.currentAssignment.job_number,
            customerName: vehicle.currentAssignment.customer_name,
            timeStart: vehicle.currentAssignment.scheduled_time_start,
            timeEnd: vehicle.currentAssignment.scheduled_time_end,
            status: vehicle.currentAssignment.current_status,
            driverName: vehicle.currentAssignment.driver_name
          }
        };
      }
      
      return {
        ...baseVehicle,
        isBusy: false
      };
    });
  }
  
  // ==========================================
  // HELPER: Calculate week start (Monday)
  // ==========================================
  /**
   * Get the start of the week (Monday) for a given date
   * 
   * @param {Date} date - The reference date
   * @returns {string} Date in YYYY-MM-DD format
   */
  static getWeekStart(date) {
    const day = date.getDay(); // 0 (Sunday) to 6 (Saturday)
    const diff = date.getDate() - day + (day === 0 ? -6 : 1); // Adjust to Monday
    const monday = new Date(date);
    monday.setDate(diff);
    return monday.toISOString().split('T')[0];
  }
  
  // ==========================================
  // HELPER: Calculate week end (Sunday)
  // ==========================================
  /**
   * Get the end of the week (Sunday) for a given date
   * 
   * @param {Date} date - The reference date
   * @returns {string} Date in YYYY-MM-DD format
   */
  static getWeekEnd(date) {
    const day = date.getDay(); // 0 (Sunday) to 6 (Saturday)
    const diff = date.getDate() - day + (day === 0 ? 0 : 7); // Adjust to Sunday
    const sunday = new Date(date);
    sunday.setDate(diff);
    return sunday.toISOString().split('T')[0];
  }
}

module.exports = DashboardService;