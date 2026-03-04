// ============================================
// FILE: src/models/Vehicle.js
// PURPOSE: Vehicle model - handles all vehicle database operations
// LAYER: Data Layer (talks directly to MySQL)
// ============================================

const db = require('../config/database');

/**
 * Vehicle Model
 * Handles all database operations for the vehicles table
 * 
 * Each function:
 * 1. Accepts parameters
 * 2. Executes SQL query
 * 3. Returns raw data from database
 * 
 * Note: Models do NOT contain business logic - they just fetch/save data
 */
class Vehicle {
  
  // ==========================================
  // FUNCTION: getAllVehicles
  // PURPOSE: Retrieve all vehicles from database
  // RETURNS: Array of vehicle objects
  // ==========================================
  /**
   * Get all vehicles (both active and inactive)
   * 
   * @param {boolean} activeOnly - If true, only return active vehicles
   * @returns {Promise<Array>} Array of vehicle objects
   * 
   * Example usage:
   *   const allVehicles = await Vehicle.getAllVehicles();
   *   const activeVehicles = await Vehicle.getAllVehicles(true);
   */
  static async getAllVehicles(activeOnly = false) {
    try {
      // Build SQL query based on activeOnly parameter
      let sql = `
        SELECT 
          id,
          vehicle_name,
          license_plate,
          vehicle_type,
          capacity_kg,
          is_active,
          last_maintenance_date,
          notes,
          created_at,
          updated_at
        FROM vehicles
      `;
      
      // If activeOnly is true, add WHERE clause to filter
      if (activeOnly) {
        sql += ' WHERE is_active = 1';
      }
      
      // Add ORDER BY to show results in consistent order
      sql += ' ORDER BY vehicle_name ASC';
      
      // Execute query
      // db.query returns [rows, fields] - we only need rows
      const [rows] = await db.query(sql);
      
      // Return the array of vehicles
      return rows;
      
    } catch (error) {
      // If SQL error occurs, log it and re-throw
      console.error('Error in Vehicle.getAllVehicles:', error);
      throw error;
    }
  }
  
  // ==========================================
  // FUNCTION: getVehicleById
  // PURPOSE: Retrieve a single vehicle by its ID
  // RETURNS: Single vehicle object or null if not found
  // ==========================================
  /**
   * Get a specific vehicle by ID
   * 
   * @param {number} id - The vehicle ID
   * @returns {Promise<Object|null>} Vehicle object or null if not found
   * 
   * Example usage:
   *   const vehicle = await Vehicle.getVehicleById(1);
   *   if (vehicle) {
   *     console.log(vehicle.vehicle_name);
   *   }
   */
  static async getVehicleById(id) {
    try {
      // SQL query with placeholder (?) for security (prevents SQL injection)
      const sql = `
        SELECT 
          id,
          vehicle_name,
          license_plate,
          vehicle_type,
          capacity_kg,
          is_active,
          last_maintenance_date,
          notes,
          created_at,
          updated_at
        FROM vehicles
        WHERE id = ?
      `;
      
      // Execute query with parameter
      // The ? is replaced with the id value safely
      const [rows] = await db.query(sql, [id]);
      
      // rows[0] = first result (or undefined if not found)
      // Return the vehicle object or null
      return rows[0] || null;
      
    } catch (error) {
      console.error('Error in Vehicle.getVehicleById:', error);
      throw error;
    }
  }
  
  // ==========================================
  // FUNCTION: createVehicle
  // PURPOSE: Insert a new vehicle into database
  // RETURNS: Newly created vehicle object with ID
  // ==========================================
  /**
   * Create a new vehicle in the database
   * 
   * @param {Object} vehicleData - Vehicle information
   * @param {string} vehicleData.vehicle_name - Name of the vehicle
   * @param {string} vehicleData.license_plate - License plate number
   * @param {string} vehicleData.vehicle_type - Type: 'van', 'truck', or 'car'
   * @param {number} vehicleData.capacity_kg - Weight capacity in kg (optional)
   * @param {string} vehicleData.notes - Additional notes (optional)
   * @returns {Promise<Object>} The newly created vehicle with its ID
   * 
   * Example usage:
   *   const newVehicle = await Vehicle.createVehicle({
   *     vehicle_name: 'Delivery Van 4',
   *     license_plate: 'DEF-999',
   *     vehicle_type: 'van',
   *     capacity_kg: 1200.50,
   *     notes: 'New vehicle for city deliveries'
   *   });
   *   console.log('Created vehicle ID:', newVehicle.id);
   */
  static async createVehicle(vehicleData) {
    try {
      // Destructure the vehicleData object to get individual fields
      const {
        vehicle_name,
        license_plate,
        vehicle_type,
        capacity_kg = null,  // Default to null if not provided
        notes = null         // Default to null if not provided
      } = vehicleData;
      
      // SQL INSERT statement
      // is_active defaults to 1 (active) in database schema
      const sql = `
        INSERT INTO vehicles (
          vehicle_name,
          license_plate,
          vehicle_type,
          capacity_kg,
          notes
        ) VALUES (?, ?, ?, ?, ?)
      `;
      
      // Execute INSERT query
      // Values array must match the order of placeholders (?)
      const [result] = await db.query(sql, [
        vehicle_name,
        license_plate,
        vehicle_type,
        capacity_kg,
        notes
      ]);
      
      // result.insertId = the auto-generated ID of the new row
      const newVehicleId = result.insertId;
      
      // Fetch and return the complete vehicle object
      // This ensures we return all fields including defaults and timestamps
      const newVehicle = await this.getVehicleById(newVehicleId);
      
      return newVehicle;
      
    } catch (error) {
      console.error('Error in Vehicle.createVehicle:', error);
      
      // Check for specific MySQL errors
      if (error.code === 'ER_DUP_ENTRY') {
        // Duplicate license plate (UNIQUE constraint violated)
        throw new Error('A vehicle with this license plate already exists');
      }
      
      throw error;
    }
  }
  
  // ==========================================
  // FUNCTION: updateVehicleStatus
  // PURPOSE: Activate or deactivate a vehicle
  // RETURNS: Updated vehicle object
  // ==========================================
  /**
   * Update vehicle active status (enable/disable vehicle)
   * 
   * Use cases:
   * - Set is_active = 0 when vehicle is in maintenance
   * - Set is_active = 1 when vehicle is back in service
   * 
   * @param {number} id - The vehicle ID
   * @param {boolean} isActive - true = active, false = inactive
   * @returns {Promise<Object>} Updated vehicle object
   * 
   * Example usage:
   *   // Take vehicle out of service
   *   await Vehicle.updateVehicleStatus(1, false);
   *   
   *   // Put vehicle back in service
   *   await Vehicle.updateVehicleStatus(1, true);
   */
  static async updateVehicleStatus(id, isActive) {
    try {
      // Convert boolean to 1 or 0 for MySQL TINYINT
      const statusValue = isActive ? 1 : 0;
      
      // SQL UPDATE statement
      const sql = `
        UPDATE vehicles
        SET is_active = ?
        WHERE id = ?
      `;
      
      // Execute UPDATE query
      const [result] = await db.query(sql, [statusValue, id]);
      
      // result.affectedRows = number of rows updated
      if (result.affectedRows === 0) {
        // No rows were updated - vehicle ID doesn't exist
        throw new Error(`Vehicle with ID ${id} not found`);
      }
      
      // Fetch and return the updated vehicle
      const updatedVehicle = await this.getVehicleById(id);
      
      return updatedVehicle;
      
    } catch (error) {
      console.error('Error in Vehicle.updateVehicleStatus:', error);
      throw error;
    }
  }
  
  // ==========================================
  // BONUS FUNCTION: updateVehicle
  // PURPOSE: Update all vehicle details
  // RETURNS: Updated vehicle object
  // ==========================================
  /**
   * Update vehicle information (comprehensive update)
   * 
   * @param {number} id - The vehicle ID
   * @param {Object} updates - Fields to update
   * @returns {Promise<Object>} Updated vehicle object
   * 
   * Example usage:
   *   await Vehicle.updateVehicle(1, {
   *     vehicle_name: 'Updated Van Name',
   *     capacity_kg: 1800,
   *     notes: 'Capacity increased after upgrade'
   *   });
   */
  static async updateVehicle(id, updates) {
    try {
      // Build dynamic UPDATE query based on which fields are provided
      const allowedFields = [
        'vehicle_name',
        'license_plate',
        'vehicle_type',
        'capacity_kg',
        'is_active',
        'last_maintenance_date',
        'notes'
      ];
      
      // Filter out any fields that aren't in allowedFields
      const updateFields = [];
      const updateValues = [];
      
      for (const [key, value] of Object.entries(updates)) {
        if (allowedFields.includes(key)) {
          updateFields.push(`${key} = ?`);
          updateValues.push(value);
        }
      }
      
      // If no valid fields to update, throw error
      if (updateFields.length === 0) {
        throw new Error('No valid fields provided for update');
      }
      
      // Add the ID to the end of values array (for WHERE clause)
      updateValues.push(id);
      
      // Build the SQL query
      const sql = `
        UPDATE vehicles
        SET ${updateFields.join(', ')}
        WHERE id = ?
      `;
      
      // Execute UPDATE query
      const [result] = await db.query(sql, updateValues);
      
      if (result.affectedRows === 0) {
        throw new Error(`Vehicle with ID ${id} not found`);
      }
      
      // Return updated vehicle
      const updatedVehicle = await this.getVehicleById(id);
      return updatedVehicle;
      
    } catch (error) {
      console.error('Error in Vehicle.updateVehicle:', error);
      
      if (error.code === 'ER_DUP_ENTRY') {
        throw new Error('A vehicle with this license plate already exists');
      }
      
      throw error;
    }
  }
  
  // ==========================================
  // BONUS FUNCTION: getAvailableVehicles
  // PURPOSE: Get vehicles available for a specific date/time
  // RETURNS: Array of available vehicles
  // ==========================================
  /**
   * Get vehicles that are available (not assigned) for a specific date and time
   * This is useful when scheduling new jobs
   * 
   * @param {string} date - Date in 'YYYY-MM-DD' format
   * @param {string} startTime - Start time in 'HH:MM:SS' format
   * @param {string} endTime - End time in 'HH:MM:SS' format
   * @returns {Promise<Array>} Array of available vehicles
   * 
   * Example usage:
   *   const available = await Vehicle.getAvailableVehicles(
   *     '2024-02-15',
   *     '10:00:00',
   *     '14:00:00'
   *   );
   */
  static async getAvailableVehicles(date, startTime, endTime) {
    try {
      // This query finds vehicles that are NOT assigned to any job
      // during the specified time period
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
          SELECT ja.vehicle_id
          FROM job_assignments ja
          JOIN jobs j ON ja.job_id = j.id
          WHERE j.scheduled_date = ?
          AND j.current_status NOT IN ('completed', 'cancelled')
          AND (
            -- Time overlap condition
            ? < j.scheduled_time_end
            AND ? > j.scheduled_time_start
          )
        )
        ORDER BY v.vehicle_name ASC
      `;
      
      const [rows] = await db.query(sql, [date, startTime, endTime]);
      return rows;
      
    } catch (error) {
      console.error('Error in Vehicle.getAvailableVehicles:', error);
      throw error;
    }
  }
  
  // ==========================================
  // BONUS FUNCTION: deleteVehicle
  // PURPOSE: Soft delete a vehicle (set inactive)
  // NOTE: We don't actually DELETE from database (data preservation)
  // ==========================================
  /**
   * Soft delete a vehicle (set is_active to 0)
   * We don't actually delete from database to preserve historical data
   * 
   * @param {number} id - The vehicle ID
   * @returns {Promise<Object>} Result of the operation
   */
  static async deleteVehicle(id) {
    try {
      // Check if vehicle has any assignments
      const checkSql = `
        SELECT COUNT(*) as assignment_count
        FROM job_assignments
        WHERE vehicle_id = ?
      `;
      
      const [checkResult] = await db.query(checkSql, [id]);
      
      if (checkResult[0].assignment_count > 0) {
        // Vehicle has assignments - just deactivate it
        return await this.updateVehicleStatus(id, false);
      } else {
        // Vehicle has no assignments - safe to actually delete
        const deleteSql = 'DELETE FROM vehicles WHERE id = ?';
        const [result] = await db.query(deleteSql, [id]);
        
        if (result.affectedRows === 0) {
          throw new Error(`Vehicle with ID ${id} not found`);
        }
        
        return { success: true, message: 'Vehicle deleted' };
      }
      
    } catch (error) {
      console.error('Error in Vehicle.deleteVehicle:', error);
      throw error;
    }
  }
}

// Export the Vehicle class so other files can use it
module.exports = Vehicle;