-- Phase 2 Migration: User contacts, Vehicle maintenance, Settings
-- Pattern: ADD COLUMN IF NOT EXISTS (MariaDB 10.4.32 confirmed)

-- USR-01/02/03: Add contact phone columns to users table
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS contact_phone           VARCHAR(20) DEFAULT NULL
    COMMENT 'Primary contact number in E.164 format',
  ADD COLUMN IF NOT EXISTS contact_phone_secondary VARCHAR(20) DEFAULT NULL
    COMMENT 'Secondary contact number in E.164 format';

-- MAINT-01/02/03/04/05: Vehicle maintenance scheduling table
CREATE TABLE IF NOT EXISTS vehicle_maintenance (
  id                INT UNSIGNED NOT NULL AUTO_INCREMENT,
  tenant_id         INT UNSIGNED NOT NULL DEFAULT 1,
  vehicle_id        INT UNSIGNED NOT NULL,
  maintenance_type  ENUM('service','repair','inspection','tyre_change','other') NOT NULL,
  other_type_desc   VARCHAR(200) DEFAULT NULL COMMENT 'Used when maintenance_type = other',
  status            ENUM('scheduled','in_progress','completed') NOT NULL DEFAULT 'scheduled',
  start_date        DATE NOT NULL,
  end_date          DATE NOT NULL,
  notes             TEXT DEFAULT NULL,
  created_by        INT UNSIGNED NOT NULL,
  created_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_vm_vehicle_id (vehicle_id),
  KEY idx_vm_tenant_id (tenant_id),
  KEY idx_vm_dates (vehicle_id, start_date, end_date, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- SCHED-04: Settings key-value table for admin toggles
CREATE TABLE IF NOT EXISTS settings (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  tenant_id   INT UNSIGNED NOT NULL DEFAULT 1,
  setting_key VARCHAR(100) NOT NULL,
  setting_val TEXT DEFAULT NULL,
  updated_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tenant_key (tenant_id, setting_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed default GPS visibility setting
INSERT IGNORE INTO settings (tenant_id, setting_key, setting_val)
VALUES (1, 'scheduler_gps_visible', 'false');
