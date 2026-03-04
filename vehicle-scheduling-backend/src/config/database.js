// ============================================
// Database Connection Configuration
// ============================================
// This file creates a MySQL connection pool using credentials from .env
// A pool manages multiple database connections for better performance
// Instead of opening/closing connections repeatedly, we reuse them

const mysql = require('mysql2/promise'); // Use promise version directly
require('dotenv').config(); // Load environment variables from .env file

// ============================================
// Create Connection Pool
// ============================================
// A pool is better than single connection because:
// - Handles multiple requests simultaneously
// - Automatically reconnects if connection drops
// - Reuses connections (faster than creating new ones)
// - Limits max connections (prevents overwhelming database)

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',           // Database server address (localhost for XAMPP)
  user: process.env.DB_USER || 'root',                // MySQL username (default: root)
  password: process.env.DB_PASSWORD || '',            // MySQL password (default: empty for XAMPP)
  database: process.env.DB_NAME || 'vehicle_scheduling', // Database name
  port: process.env.DB_PORT || 3306,                  // MySQL port (default: 3306)
  
  // Pool configuration
  waitForConnections: true,  // Wait if no connections available (don't reject immediately)
  connectionLimit: 10,       // Maximum 10 simultaneous connections
  queueLimit: 0,            // No limit on queued connection requests
  
  // Connection behavior
  enableKeepAlive: true,    // Keep connections alive
  keepAliveInitialDelay: 0  // Start keep-alive immediately
});

// ============================================
// Export Pool Directly
// ============================================
// Export the pool directly so other files can use:
// const db = require('./config/database');
// await db.query('SELECT...')

module.exports = pool;