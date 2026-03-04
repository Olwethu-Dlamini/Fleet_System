// ============================================
// FILE: scripts/seedPasswords.js
// PURPOSE: Hash passwords for existing users
// RUN ONCE: node scripts/seedPasswords.js
// ============================================

// This updates your sample users with real bcrypt hashed passwords
// Run this ONCE after setting up the database

const bcrypt = require('bcryptjs');
const db     = require('../src/config/database');

const users = [
  { username: 'admin',       password: 'Admin@123'      },
  { username: 'dispatcher1', password: 'Dispatch@123'   },
  { username: 'driver1',     password: 'Driver@123'     },
  { username: 'driver2',     password: 'Driver@123'     },
  { username: 'driver3',     password: 'Driver@123'     },
];

async function seedPasswords() {
  console.log('Hashing passwords...');

  for (const user of users) {
    // Generate hash (10 = salt rounds, higher = more secure but slower)
    const hash = await bcrypt.hash(user.password, 10);

    await db.query(
      'UPDATE users SET password_hash = ? WHERE username = ?',
      [hash, user.username]
    );

    console.log(`Updated: ${user.username} → password: ${user.password}`);
  }

  console.log('\nDone! Login credentials:');
  console.log('  admin       / Admin@123');
  console.log('  dispatcher1 / Dispatch@123');
  console.log('  driver1     / Driver@123');

  process.exit(0);
}

seedPasswords().catch(console.error);