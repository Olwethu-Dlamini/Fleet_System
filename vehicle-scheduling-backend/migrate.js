const mysql = require('mysql2/promise');

async function migrate() {
  const pool = mysql.createPool({
    host: 'localhost', user: 'root', password: '',
    database: 'vehicle_scheduling', port: 3306
  });

  const migrations = [
    // === MISSING COLUMNS ===
    "ALTER TABLE users ADD COLUMN IF NOT EXISTS contact_phone_secondary VARCHAR(20) DEFAULT NULL AFTER contact_phone",
    "ALTER TABLE job_assignments ADD COLUMN IF NOT EXISTS tenant_id INT UNSIGNED NOT NULL DEFAULT 1",
    "ALTER TABLE job_technicians ADD COLUMN IF NOT EXISTS tenant_id INT UNSIGNED NOT NULL DEFAULT 1",
    "ALTER TABLE job_status_changes ADD COLUMN IF NOT EXISTS tenant_id INT UNSIGNED NOT NULL DEFAULT 1",
    "ALTER TABLE job_status_changes MODIFY COLUMN changed_by INT UNSIGNED DEFAULT NULL",

    // === MISSING TABLES ===
    `CREATE TABLE IF NOT EXISTS tenants (
      id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
      name VARCHAR(100) NOT NULL,
      slug VARCHAR(50) NOT NULL UNIQUE,
      is_active TINYINT(1) DEFAULT 1,
      tenant_timezone VARCHAR(50) DEFAULT 'UTC',
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

    "INSERT IGNORE INTO tenants (id, name, slug, is_active, tenant_timezone) VALUES (1, 'Default Company', 'default', 1, 'Africa/Johannesburg')",

    `CREATE TABLE IF NOT EXISTS job_number_sequences (
      year YEAR NOT NULL PRIMARY KEY,
      counter INT UNSIGNED NOT NULL DEFAULT 0
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

    `CREATE TABLE IF NOT EXISTS vehicle_maintenance (
      id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
      tenant_id INT UNSIGNED NOT NULL DEFAULT 1,
      vehicle_id INT UNSIGNED NOT NULL,
      maintenance_type ENUM('service','repair','inspection','tyre_change','other') NOT NULL,
      other_type_desc VARCHAR(200) DEFAULT NULL,
      status ENUM('scheduled','in_progress','completed') DEFAULT 'scheduled',
      start_date DATE NOT NULL,
      end_date DATE NOT NULL,
      notes TEXT DEFAULT NULL,
      created_by INT UNSIGNED NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      KEY idx_vm_vehicle (vehicle_id),
      KEY idx_vm_dates (start_date, end_date),
      KEY idx_vm_tenant (tenant_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

    `CREATE TABLE IF NOT EXISTS settings (
      id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
      tenant_id INT UNSIGNED NOT NULL DEFAULT 1,
      setting_key VARCHAR(100) NOT NULL,
      setting_value TEXT DEFAULT NULL,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY uk_settings_tenant_key (tenant_id, setting_key)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

    `CREATE TABLE IF NOT EXISTS assignment_history (
      id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
      job_id INT UNSIGNED NOT NULL,
      event_type ENUM('create','reassign','swap','cancel','technician_add','technician_remove') NOT NULL,
      old_user_id INT UNSIGNED DEFAULT NULL,
      new_user_id INT UNSIGNED DEFAULT NULL,
      changed_by INT UNSIGNED NOT NULL,
      changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      notes TEXT DEFAULT NULL,
      tenant_id INT UNSIGNED DEFAULT NULL,
      KEY idx_ah_job (job_id),
      KEY idx_ah_tenant (tenant_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

    `CREATE TABLE IF NOT EXISTS job_completions (
      id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
      job_id INT UNSIGNED NOT NULL UNIQUE,
      completed_by INT UNSIGNED NOT NULL,
      lat DOUBLE DEFAULT NULL,
      lng DOUBLE DEFAULT NULL,
      accuracy_m FLOAT DEFAULT NULL,
      gps_status ENUM('ok','low_accuracy','no_gps') DEFAULT 'no_gps',
      completed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      tenant_id INT UNSIGNED DEFAULT NULL,
      KEY idx_jc_tenant (tenant_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

    `CREATE TABLE IF NOT EXISTS time_extension_requests (
      id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
      tenant_id INT UNSIGNED NOT NULL,
      job_id INT UNSIGNED NOT NULL,
      requested_by INT UNSIGNED NOT NULL,
      duration_minutes INT UNSIGNED NOT NULL,
      reason TEXT NOT NULL,
      status ENUM('pending','approved','denied') DEFAULT 'pending',
      denial_reason TEXT DEFAULT NULL,
      approved_denied_by INT UNSIGNED DEFAULT NULL,
      approved_denied_at TIMESTAMP DEFAULT NULL,
      selected_suggestion_id INT UNSIGNED DEFAULT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      KEY idx_ter_job (job_id),
      KEY idx_ter_tenant (tenant_id),
      KEY idx_ter_status (status)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

    `CREATE TABLE IF NOT EXISTS reschedule_options (
      id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
      request_id INT UNSIGNED NOT NULL,
      tenant_id INT UNSIGNED NOT NULL,
      type VARCHAR(20) NOT NULL,
      label VARCHAR(100) NOT NULL,
      changes_json TEXT NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      KEY idx_ro_request (request_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

    // === FIX: Widen reschedule_options.type from ENUM to VARCHAR to support new types ===
    "ALTER TABLE reschedule_options MODIFY COLUMN type VARCHAR(20) NOT NULL",

    // === DEFAULT SETTINGS ===
    "INSERT IGNORE INTO settings (tenant_id, setting_key, setting_value) VALUES (1, 'scheduler_gps_visible', 'true')",
    "INSERT IGNORE INTO settings (tenant_id, setting_key, setting_value) VALUES (1, 'tenant_timezone', 'Africa/Johannesburg')",
  ];

  let success = 0, skipped = 0, errors = 0;
  for (const sql of migrations) {
    try {
      await pool.query(sql);
      success++;
      console.log('OK:', sql.replace(/\s+/g, ' ').substring(0, 70));
    } catch (e) {
      if (e.code === 'ER_DUP_FIELDNAME' || e.code === 'ER_DUP_KEYNAME' || e.message.includes('Duplicate')) {
        skipped++;
        console.log('SKIP:', e.message.substring(0, 60));
      } else {
        errors++;
        console.log('ERR:', e.message.substring(0, 100));
      }
    }
  }

  console.log('\n=== Migration Complete ===');
  console.log('Success:', success, '| Skipped:', skipped, '| Errors:', errors);

  const [tables] = await pool.query('SHOW TABLES');
  console.log('Total tables:', tables.length);
  console.log('Tables:', tables.map(t => Object.values(t)[0]).join(', '));

  await pool.end();
}

migrate().catch(e => console.error('FATAL:', e.message));
