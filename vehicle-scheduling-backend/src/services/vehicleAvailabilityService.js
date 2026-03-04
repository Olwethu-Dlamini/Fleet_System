// ============================================
// FILE: src/services/vehicleAvailabilityService.js
// PURPOSE: Check vehicle availability and prevent double booking
// LAYER: Business Logic Layer
// CHANGE: Added findAvailableDrivers() so the Flutter UI can
//         pre-filter the driver picker (greying out already-booked
//         drivers) before submission.
//         Everything else is original — untouched.
// ============================================

const db = require('../config/database');
const Job = require('../models/Job');

/**
 * Vehicle Availability Service
 * 
 * This service handles all vehicle availability checking logic
 * to prevent double booking of vehicles.
 * 
 * CRITICAL: This is the core business logic that prevents scheduling conflicts!
 */
class VehicleAvailabilityService {
  
  // ==========================================
  // MAIN FUNCTION: checkVehicleAvailability
  // PURPOSE: Check if vehicle is available for a time slot
  // RETURNS: Object with availability status and conflicts
  // ==========================================
  /**
   * Check if a vehicle is available for a specific date and time
   * 
   * @param {number} vehicleId - The vehicle ID to check
   * @param {string} date - Date in 'YYYY-MM-DD' format
   * @param {string} startTime - Start time in 'HH:MM:SS' format
   * @param {string} endTime - End time in 'HH:MM:SS' format
   * @param {number} excludeJobId - Optional: Job ID to exclude (for updates)
   * @returns {Promise<Object>} Availability result
   * 
   * Return value:
   * {
   *   isAvailable: true/false,
   *   conflicts: [...],  // Array of conflicting jobs (if any)
   *   message: "...",    // Human-readable message
   *   details: {...}     // Additional info
   * }
   * 
   * Example usage:
   *   const result = await VehicleAvailabilityService.checkVehicleAvailability(
   *     1,                  // Vehicle ID
   *     '2024-02-20',       // Date
   *     '10:00:00',         // Start time
   *     '14:00:00'          // End time
   *   );
   *   
   *   if (!result.isAvailable) {
   *     console.log('Conflict!', result.conflicts);
   *   }
   */
  static async checkVehicleAvailability(vehicleId, date, startTime, endTime, excludeJobId = null) {
    try {
      // STEP 1: Validate inputs
      this.validateInputs(vehicleId, date, startTime, endTime);
      
      // STEP 2: Check if vehicle exists and is active
      const vehicleCheck = await this.validateVehicle(vehicleId);
      if (!vehicleCheck.isValid) {
        return {
          isAvailable: false,
          conflicts: [],
          message: vehicleCheck.message,
          details: { vehicleId, date, startTime, endTime }
        };
      }
      
      // STEP 3: Build SQL query to find conflicts
      let sql = `
        SELECT 
          j.id,
          j.job_number,
          j.customer_name,
          j.customer_address,
          j.job_type,
          j.scheduled_date,
          j.scheduled_time_start,
          j.scheduled_time_end,
          j.current_status,
          j.priority,
          v.vehicle_name,
          v.license_plate,
          u.full_name as driver_name
        FROM job_assignments ja
        INNER JOIN jobs j ON ja.job_id = j.id
        INNER JOIN vehicles v ON ja.vehicle_id = v.id
        LEFT JOIN users u ON ja.driver_id = u.id
        WHERE 
          ja.vehicle_id = ?
          AND j.scheduled_date = ?
          AND j.current_status NOT IN ('completed', 'cancelled')
          AND (
            -- TIME OVERLAP DETECTION
            ? < j.scheduled_time_end
            AND 
            ? > j.scheduled_time_start
          )
      `;
      
      const params = [vehicleId, date, startTime, endTime];
      
      // STEP 4: Exclude specific job if updating an existing assignment
      if (excludeJobId) {
        sql += ' AND j.id != ?';
        params.push(excludeJobId);
      }
      
      sql += ' ORDER BY j.scheduled_time_start ASC';
      
      // STEP 5: Execute query
      const [conflicts] = await db.query(sql, params);
      
      // STEP 6: Determine availability
      const isAvailable = conflicts.length === 0;
      
      // STEP 7: Build response
      if (isAvailable) {
        return {
          isAvailable: true,
          conflicts: [],
          message: 'Vehicle is available for this time slot',
          details: {
            vehicleId,
            vehicleName: vehicleCheck.vehicleName,
            date,
            startTime,
            endTime,
            duration: this.calculateDuration(startTime, endTime)
          }
        };
      } else {
        // Vehicle has conflicts
        return {
          isAvailable: false,
          conflicts: conflicts,
          message: `Vehicle already has ${conflicts.length} job(s) scheduled during this time`,
          details: {
            vehicleId,
            vehicleName: vehicleCheck.vehicleName,
            date,
            startTime,
            endTime,
            conflictCount: conflicts.length,
            conflictingSummary: conflicts.map(c => ({
              jobNumber: c.job_number,
              customer: c.customer_name,
              timeSlot: `${c.scheduled_time_start} - ${c.scheduled_time_end}`
            }))
          }
        };
      }
      
    } catch (error) {
      console.error('Error in checkVehicleAvailability:', error);
      throw new Error(`Failed to check vehicle availability: ${error.message}`);
    }
  }
  
  // ==========================================
  // FUNCTION: findAvailableVehicles
  // PURPOSE: Get list of all available vehicles for a time slot
  // RETURNS: Array of available vehicles
  // ==========================================
  /**
   * Find all vehicles available for a specific date and time
   * Useful for suggesting alternatives when primary choice is busy
   * 
   * @param {string} date - Date in 'YYYY-MM-DD' format
   * @param {string} startTime - Start time in 'HH:MM:SS' format
   * @param {string} endTime - End time in 'HH:MM:SS' format
   * @returns {Promise<Array>} Array of available vehicles
   * 
   * Example usage:
   *   const available = await VehicleAvailabilityService.findAvailableVehicles(
   *     '2024-02-20',
   *     '10:00:00',
   *     '14:00:00'
   *   );
   *   
   *   console.log(`${available.length} vehicles available`);
   */
  static async findAvailableVehicles(date, startTime, endTime) {
    try {
      // SQL query to find vehicles NOT assigned during this time
      const sql = `
        SELECT 
          v.id,
          v.vehicle_name,
          v.license_plate,
          v.vehicle_type,
          v.capacity_kg,
          v.is_active
        FROM vehicles v
        WHERE v.is_active = 1
        AND v.id NOT IN (
          -- Subquery: Find all vehicles that ARE busy during this time
          SELECT DISTINCT ja.vehicle_id
          FROM job_assignments ja
          INNER JOIN jobs j ON ja.job_id = j.id
          WHERE j.scheduled_date = ?
          AND j.current_status NOT IN ('completed', 'cancelled')
          AND (
            -- Time overlap condition
            ? < j.scheduled_time_end
            AND 
            ? > j.scheduled_time_start
          )
        )
        ORDER BY v.vehicle_name ASC
      `;
      
      const [availableVehicles] = await db.query(sql, [date, startTime, endTime]);
      
      return availableVehicles;
      
    } catch (error) {
      console.error('Error in findAvailableVehicles:', error);
      throw error;
    }
  }

  // ==========================================
  // FUNCTION: findAvailableDrivers              ← NEW
  // PURPOSE: Return all active technician/driver users who have NO
  //          overlapping job during the given time window.
  //          Checks BOTH job_technicians (multi-driver path) AND the
  //          legacy driver_id column on job_assignments so every
  //          booking pattern is covered.
  //
  // Used by: GET /api/availability/drivers
  //          Flutter driver chip picker greys out busy drivers before
  //          the user submits — this is a UX pre-filter only.
  //          checkDriversAvailability() below remains the authoritative
  //          server-side guard.
  //
  // @param {string}      date          YYYY-MM-DD
  // @param {string}      startTime     HH:MM:SS
  // @param {string}      endTime       HH:MM:SS
  // @param {number|null} excludeJobId  Skip this job when checking
  //                                    (pass the job being edited)
  // @returns {Promise<{available, busy, availableIds}>}
  // ==========================================
  static async findAvailableDrivers(date, startTime, endTime, excludeJobId = null) {
    try {
      if (!date || !startTime || !endTime) {
        throw new Error('date, startTime, and endTime are required');
      }
      if (endTime <= startTime) {
        throw new Error('End time must be after start time');
      }

      // ── Query 1: busy via job_technicians (multi-driver path) ──────
      let techSql = `
        SELECT DISTINCT jt.user_id
        FROM job_technicians jt
        JOIN jobs j ON jt.job_id = j.id
        WHERE j.scheduled_date = ?
          AND j.current_status NOT IN ('completed', 'cancelled')
          AND ? < j.scheduled_time_end
          AND ? > j.scheduled_time_start
      `;
      const techParams = [date, startTime, endTime];
      if (excludeJobId) {
        techSql += ' AND j.id != ?';
        techParams.push(excludeJobId);
      }

      // ── Query 2: busy via legacy driver_id on job_assignments ──────
      let legacySql = `
        SELECT DISTINCT ja.driver_id AS user_id
        FROM job_assignments ja
        JOIN jobs j ON ja.job_id = j.id
        WHERE ja.driver_id IS NOT NULL
          AND j.scheduled_date = ?
          AND j.current_status NOT IN ('completed', 'cancelled')
          AND ? < j.scheduled_time_end
          AND ? > j.scheduled_time_start
      `;
      const legacyParams = [date, startTime, endTime];
      if (excludeJobId) {
        legacySql += ' AND j.id != ?';
        legacyParams.push(excludeJobId);
      }

      // Run both in parallel for performance
      const [[techRows], [legacyRows]] = await Promise.all([
        db.query(techSql, techParams),
        db.query(legacySql, legacyParams),
      ]);

      // Merge into one set of busy IDs
      const busyIds = new Set([
        ...techRows.map(r => r.user_id),
        ...legacyRows.map(r => r.user_id),
      ]);

      // ── All active technicians / drivers ───────────────────────────
      const [allDrivers] = await db.query(
        `SELECT id, full_name, email, role
         FROM users
         WHERE is_active = 1
           AND role IN ('technician', 'driver')
         ORDER BY full_name ASC`
      );

      const available = [];
      const busy      = [];

      allDrivers.forEach(driver => {
        if (busyIds.has(driver.id)) {
          busy.push({ ...driver, isAvailable: false });
        } else {
          available.push({ ...driver, isAvailable: true });
        }
      });

      return {
        available,
        busy,
        availableIds: available.map(d => d.id),
      };

    } catch (error) {
      console.error('Error in findAvailableDrivers:', error);
      throw new Error(`Failed to check driver availability: ${error.message}`);
    }
  }
  
  // ==========================================
  // FUNCTION: getVehicleSchedule
  // PURPOSE: Get complete schedule for a vehicle on a specific date
  // RETURNS: Array of all jobs for that vehicle
  // ==========================================
  /**
   * Get complete schedule for a vehicle on a specific date
   * Shows all time slots (occupied and available)
   * 
   * @param {number} vehicleId - The vehicle ID
   * @param {string} date - Date in 'YYYY-MM-DD' format
   * @returns {Promise<Object>} Schedule with jobs and gaps
   * 
   * Example usage:
   *   const schedule = await VehicleAvailabilityService.getVehicleSchedule(1, '2024-02-20');
   *   console.log('Occupied slots:', schedule.occupiedSlots);
   *   console.log('Available gaps:', schedule.availableGaps);
   */
  static async getVehicleSchedule(vehicleId, date) {
    try {
      // Get all jobs for this vehicle on this date
      const jobs = await Job.getJobsByVehicle(
        vehicleId, 
        date, 
        ['completed', 'cancelled']  // Exclude finished jobs
      );
      
      // Calculate available time gaps between jobs
      const gaps = this.calculateTimeGaps(jobs);
      
      return {
        vehicleId,
        date,
        occupiedSlots: jobs,
        availableGaps: gaps,
        totalJobs: jobs.length
      };
      
    } catch (error) {
      console.error('Error in getVehicleSchedule:', error);
      throw error;
    }
  }
  
  // ==========================================
  // HELPER FUNCTION: validateInputs
  // PURPOSE: Validate input parameters
  // ==========================================
  static validateInputs(vehicleId, date, startTime, endTime) {
    // Check vehicle ID
    if (!vehicleId || isNaN(vehicleId)) {
      throw new Error('Valid vehicle ID is required');
    }
    
    // Check date - handle both Date objects and strings
    if (!date) {
      throw new Error('Date is required');
    }
    
    // If date is a Date object (from MySQL), convert to YYYY-MM-DD string
    if (date instanceof Date) {
      const year = date.getFullYear();
      const month = String(date.getMonth() + 1).padStart(2, '0');
      const day = String(date.getDate()).padStart(2, '0');
      date = `${year}-${month}-${day}`;
    }
    
    // Now validate string format
    if (typeof date === 'string' && !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
      throw new Error(`Date must be in YYYY-MM-DD format, got: ${date}`);
    }
    
    // Check time format
    if (!startTime || !/^\d{2}:\d{2}:\d{2}$/.test(startTime)) {
      throw new Error('Start time must be in HH:MM:SS format');
    }
    
    if (!endTime || !/^\d{2}:\d{2}:\d{2}$/.test(endTime)) {
      throw new Error('End time must be in HH:MM:SS format');
    }
    
    // Check that end time is after start time
    if (endTime <= startTime) {
      throw new Error('End time must be after start time');
    }
    
    // Check that date is not in the past
    const today = new Date().toISOString().split('T')[0];
    const checkDate = (date instanceof Date) 
      ? date.toISOString().split('T')[0] 
      : date;
      
    if (checkDate < today) {
      throw new Error('Cannot schedule jobs in the past');
    }
  }
  
  // ==========================================
  // HELPER FUNCTION: validateVehicle
  // PURPOSE: Check if vehicle exists and is active
  // ==========================================
  static async validateVehicle(vehicleId) {
    const sql = 'SELECT id, vehicle_name, is_active FROM vehicles WHERE id = ?';
    const [rows] = await db.query(sql, [vehicleId]);
    
    if (rows.length === 0) {
      return {
        isValid: false,
        message: `Vehicle with ID ${vehicleId} does not exist`
      };
    }
    
    const vehicle = rows[0];
    
    if (vehicle.is_active === 0) {
      return {
        isValid: false,
        message: `Vehicle "${vehicle.vehicle_name}" is currently inactive (out of service)`
      };
    }
    
    return {
      isValid: true,
      vehicleName: vehicle.vehicle_name
    };
  }
  
  // ==========================================
  // HELPER FUNCTION: calculateDuration
  // PURPOSE: Calculate duration in minutes
  // ==========================================
  static calculateDuration(startTime, endTime) {
    const start = new Date(`2000-01-01T${startTime}`);
    const end = new Date(`2000-01-01T${endTime}`);
    const diffMs = end - start;
    const diffMinutes = Math.floor(diffMs / 60000);
    return diffMinutes;
  }
  
  // ==========================================
  // HELPER FUNCTION: calculateTimeGaps
  // PURPOSE: Find available time gaps between jobs
  // ==========================================
  static calculateTimeGaps(jobs) {
    if (jobs.length === 0) {
      return [{
        start: '00:00:00',
        end: '23:59:59',
        message: 'Entire day available'
      }];
    }
    
    // Sort jobs by start time
    const sortedJobs = jobs.sort((a, b) => 
      a.scheduled_time_start.localeCompare(b.scheduled_time_start)
    );
    
    const gaps = [];
    
    // Gap before first job
    if (sortedJobs[0].scheduled_time_start > '00:00:00') {
      gaps.push({
        start: '00:00:00',
        end: sortedJobs[0].scheduled_time_start
      });
    }
    
    // Gaps between jobs
    for (let i = 0; i < sortedJobs.length - 1; i++) {
      const currentEnd = sortedJobs[i].scheduled_time_end;
      const nextStart = sortedJobs[i + 1].scheduled_time_start;
      
      if (currentEnd < nextStart) {
        gaps.push({
          start: currentEnd,
          end: nextStart
        });
      }
    }
    
    // Gap after last job
    const lastJob = sortedJobs[sortedJobs.length - 1];
    if (lastJob.scheduled_time_end < '23:59:59') {
      gaps.push({
        start: lastJob.scheduled_time_end,
        end: '23:59:59'
      });
    }
    
    return gaps;
  }

  // ==========================================
  // FUNCTION: checkDriversAvailability
  // PURPOSE: Check if ALL requested drivers are free during a time slot.
  //          A driver is "busy" if they appear in job_technicians for any
  //          overlapping job on the same date.
  // RETURNS: { allAvailable, conflicts: [{ driverId, driverName, ... }] }
  // ==========================================
  static async checkDriversAvailability(technicianIds, date, startTime, endTime, excludeJobId = null) {
    if (!technicianIds || technicianIds.length === 0) {
      return { allAvailable: true, conflicts: [] };
    }

    try {
      let sql = `
        SELECT
          u.id        AS driver_id,
          u.full_name AS driver_name,
          j.id        AS job_id,
          j.job_number,
          j.customer_name,
          j.scheduled_date,
          j.scheduled_time_start,
          j.scheduled_time_end,
          j.current_status
        FROM job_technicians jt
        JOIN users u ON jt.user_id = u.id
        JOIN jobs  j ON jt.job_id  = j.id
        WHERE
          jt.user_id IN (?)
          AND j.scheduled_date = ?
          AND j.current_status NOT IN ('completed', 'cancelled')
          AND ? < j.scheduled_time_end
          AND ? > j.scheduled_time_start
      `;

      const params = [technicianIds, date, startTime, endTime];

      if (excludeJobId) {
        sql += ' AND j.id != ?';
        params.push(excludeJobId);
      }

      const [rows] = await db.query(sql, params);

      if (rows.length === 0) {
        return { allAvailable: true, conflicts: [] };
      }

      return {
        allAvailable: false,
        conflicts: rows.map(r => ({
          driverId  : r.driver_id,
          driverName: r.driver_name,
          jobNumber : r.job_number,
          customer  : r.customer_name,
          timeSlot  : `${r.scheduled_time_start} - ${r.scheduled_time_end}`,
        })),
      };
    } catch (error) {
      console.error('Error in checkDriversAvailability:', error);
      throw new Error(`Failed to check driver availability: ${error.message}`);
    }
  }
}

// Export the service
module.exports = VehicleAvailabilityService;