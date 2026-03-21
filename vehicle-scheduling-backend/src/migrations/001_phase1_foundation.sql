-- Migration: 001_phase1_foundation.sql
-- Phase: 1 — Foundation & Security Hardening
-- Requirements: FOUND-01, FOUND-03, FOUND-07 (tenant_timezone), FOUND-09
-- Safe to re-run: YES (all statements use IF NOT EXISTS)
-- Run: mysql -u root vehicle_scheduling < src/migrations/001_phase1_foundation.sql

-- ============================================================
-- Step 1: Tenants root table (FOUND-01)
-- ============================================================
CREATE TABLE IF NOT EXISTS `tenants` (
  `id`               INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`             VARCHAR(100) NOT NULL,
  `slug`             VARCHAR(50)  NOT NULL,
  `is_active`        TINYINT(1)   NOT NULL DEFAULT 1,
  `tenant_timezone`  VARCHAR(50)  NOT NULL DEFAULT 'UTC',
  `created_at`       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_slug` (`slug`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `tenants` (`id`, `name`, `slug`) VALUES (1, 'Default Tenant', 'default');

-- ============================================================
-- Step 2: Add tenant_id to all 6 existing tables (FOUND-01)
-- Idempotent syntax supported in MariaDB 10.3+ and MySQL 8.0.3+
-- This makes the migration idempotent (safe to re-run)
-- ============================================================
ALTER TABLE `jobs`               ADD COLUMN IF NOT EXISTS `tenant_id` INT UNSIGNED NOT NULL DEFAULT 1 AFTER `id`;
ALTER TABLE `vehicles`           ADD COLUMN IF NOT EXISTS `tenant_id` INT UNSIGNED NOT NULL DEFAULT 1 AFTER `id`;
ALTER TABLE `users`              ADD COLUMN IF NOT EXISTS `tenant_id` INT UNSIGNED NOT NULL DEFAULT 1 AFTER `id`;
ALTER TABLE `job_assignments`    ADD COLUMN IF NOT EXISTS `tenant_id` INT UNSIGNED NOT NULL DEFAULT 1 AFTER `id`;
ALTER TABLE `job_technicians`    ADD COLUMN IF NOT EXISTS `tenant_id` INT UNSIGNED NOT NULL DEFAULT 1 AFTER `id`;
ALTER TABLE `job_status_changes` ADD COLUMN IF NOT EXISTS `tenant_id` INT UNSIGNED NOT NULL DEFAULT 1 AFTER `id`;

-- ============================================================
-- Step 3: Job number sequence table (FOUND-03)
-- Atomic counter generation to avoid job_number collisions
-- ============================================================
CREATE TABLE IF NOT EXISTS `job_number_sequences` (
  `year`    YEAR         NOT NULL,
  `counter` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`year`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Seed with current max job number to avoid collision with existing data
INSERT INTO `job_number_sequences` (`year`, `counter`)
SELECT YEAR(CURDATE()),
       COALESCE(MAX(CAST(SUBSTRING_INDEX(job_number, '-', -1) AS UNSIGNED)), 0)
FROM `jobs`
WHERE job_number LIKE CONCAT('JOB-', YEAR(CURDATE()), '-%')
ON DUPLICATE KEY UPDATE `counter` = `counter`;

-- ============================================================
-- Step 4: Composite indexes with tenant_id as leading column (FOUND-09)
-- ADD KEY IF NOT EXISTS is supported in MariaDB 10.3+
-- ============================================================

-- jobs table indexes
ALTER TABLE `jobs`
  ADD KEY IF NOT EXISTS `idx_jobs_tenant_date`        (`tenant_id`, `scheduled_date`),
  ADD KEY IF NOT EXISTS `idx_jobs_tenant_status`      (`tenant_id`, `current_status`),
  ADD KEY IF NOT EXISTS `idx_jobs_tenant_date_status` (`tenant_id`, `scheduled_date`, `current_status`);

-- job_assignments index
ALTER TABLE `job_assignments`
  ADD KEY IF NOT EXISTS `idx_ja_tenant_vehicle` (`tenant_id`, `vehicle_id`);

-- job_technicians index
ALTER TABLE `job_technicians`
  ADD KEY IF NOT EXISTS `idx_jt_tenant_user` (`tenant_id`, `user_id`);

-- users index
ALTER TABLE `users`
  ADD KEY IF NOT EXISTS `idx_users_tenant` (`tenant_id`);

-- vehicles index
ALTER TABLE `vehicles`
  ADD KEY IF NOT EXISTS `idx_vehicles_tenant` (`tenant_id`);
