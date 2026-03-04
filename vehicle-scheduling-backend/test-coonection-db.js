// ============================================
// Database Connection Test Script
// ============================================
// Run this file to test if database connection works
// Command: node test-db-connection.js

const { pool, testConnection, getDatabaseInfo, closePool } = require('./src/config/database');

async function runTest() {
  console.log('===========================================');
  console.log('Testing Database Connection...');
  console.log('===========================================\n');

  // Test 1: Basic connection
  console.log('Test 1: Testing basic connection...');
  const isConnected = await testConnection();
  
  if (!isConnected) {
    console.log('\n❌ Connection test failed. Please check:');
    console.log('1. XAMPP MySQL is running');
    console.log('2. .env file has correct credentials');
    console.log('3. Database "vehicle_scheduling" exists');
    process.exit(1);
  }
  
  console.log(''); // Blank line for readability
  
  // Test 2: Get database info
  console.log('Test 2: Getting database information...');
  await getDatabaseInfo();
  
  console.log(''); // Blank line
  
  // Test 3: Query tables
  console.log('Test 3: Checking if tables exist...');
  try {
    const [tables] = await pool.query('SHOW TABLES');
    
    if (tables.length === 0) {
      console.log('⚠️  No tables found. Run the SQL schema script first.');
    } else {
      console.log(`✅ Found ${tables.length} tables:`);
      tables.forEach(table => {
        const tableName = Object.values(table)[0];
        console.log(`   - ${tableName}`);
      });
    }
  } catch (error) {
    console.error('❌ Error querying tables:', error.message);
  }
  
  console.log(''); // Blank line
  
  // Test 4: Count records
  console.log('Test 4: Counting records in tables...');
  try {
    const [vehicleCount] = await pool.query('SELECT COUNT(*) as count FROM vehicles');
    const [jobCount] = await pool.query('SELECT COUNT(*) as count FROM jobs');
    const [userCount] = await pool.query('SELECT COUNT(*) as count FROM users');
    
    console.log(`✅ Vehicles: ${vehicleCount[0].count}`);
    console.log(`✅ Jobs: ${jobCount[0].count}`);
    console.log(`✅ Users: ${userCount[0].count}`);
  } catch (error) {
    console.error('❌ Error counting records:', error.message);
  }
  
  console.log('\n===========================================');
  console.log('All tests completed!');
  console.log('===========================================\n');
  
  // Close pool
  await closePool();
  process.exit(0);
}

// Run the test
runTest();