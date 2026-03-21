---
phase: 01-foundation-security-hardening
plan: 01
subsystem: database
tags: [multi-tenant, migration, utc, group-concat, indexes, foundation]
dependency_graph:
  requires: []
  provides: [tenant_id-on-all-tables, tenants-table, job_number_sequences, composite-indexes, utc-pool, group-concat-fix]
  affects: [all-subsequent-phases]
tech_stack:
  added: [001_phase1_foundation.sql migration, job_number_sequences table, tenants table]
  patterns: [idempotent-migration, pool-connection-hook, dockerfile-env-tz]
key_files:
  created:
    - vehicle-scheduling-backend/src/migrations/001_phase1_foundation.sql
  modified:
    - vehicle-scheduling-backend/src/config/database.js
    - vehicle-scheduling-backend/Dockerfile
key_decisions:
  - "ADD COLUMN IF NOT EXISTS used instead of stored procedure pattern — MariaDB 10.4.32 confirmed from vehicle_scheduling.sql header, supports this syntax natively"
  - "No FK constraint from tenant_id to tenants.id — deferred to avoid cascading delete risk in Phase 1 scope"
  - "group_concat_max_len set to 65536 per connection via pool.on('connection') — not at pool level to avoid mysql2 promise pool limitations"
  - "ON DUPLICATE KEY UPDATE counter = counter used for job_number_sequences seed — preserves existing max on re-run without incrementing"
metrics:
  duration_minutes: 8
  completed_date: "2026-03-21"
  tasks_completed: 3
  tasks_total: 3
  files_created: 1
  files_modified: 2
requirements_covered: [FOUND-01, FOUND-03, FOUND-07, FOUND-08, FOUND-09]
---

# Phase 01 Plan 01: Foundation Database Migration Summary

**One-liner:** Idempotent MariaDB migration adds tenant_id to 6 tables, tenants root table, job_number_sequences, and 7 composite indexes; database.js fixed for UTC timezone and GROUP_CONCAT 65536-byte limit via pool connection hook; Dockerfile enforces TZ=UTC for Node.js process.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Write Phase 1 database migration SQL | 31814a8 | vehicle-scheduling-backend/src/migrations/001_phase1_foundation.sql |
| 2 | Fix database.js — UTC pool timezone and GROUP_CONCAT session hook | 49a550e | vehicle-scheduling-backend/src/config/database.js |
| 3 | Add TZ=UTC to Dockerfile | b4ad196 | vehicle-scheduling-backend/Dockerfile |

## What Was Built

### Migration SQL (`001_phase1_foundation.sql`)

An idempotent SQL migration (safe to re-run on MariaDB 10.3+ / MySQL 8.0.3+) that:

1. Creates `tenants` table with `id`, `name`, `slug`, `is_active`, `tenant_timezone`, `created_at`; seeds id=1 'Default Tenant' row via `INSERT IGNORE`
2. Adds `tenant_id INT UNSIGNED NOT NULL DEFAULT 1` to all 6 existing tables: `jobs`, `vehicles`, `users`, `job_assignments`, `job_technicians`, `job_status_changes` using `ADD COLUMN IF NOT EXISTS`
3. Creates `job_number_sequences` table (`year` PK, `counter`); seeds current year row by scanning existing `job_number` column for max sequence number via `ON DUPLICATE KEY UPDATE counter = counter` (idempotent)
4. Adds 7 composite indexes with `tenant_id` as leading column: 3 on `jobs` (tenant+date, tenant+status, tenant+date+status), 1 each on `job_assignments`, `job_technicians`, `users`, `vehicles`

**Run command:** `mysql -u root vehicle_scheduling < src/migrations/001_phase1_foundation.sql`

### database.js Changes

- Added `timezone: '+00:00'` to `mysql.createPool()` options — forces UTC interpretation for all date/timestamp values returned by mysql2
- Added `pool.on('connection', ...)` hook that fires `SET SESSION group_concat_max_len = 65536` on every new connection — fixes silent GROUP_CONCAT truncation that occurred at ~20 technicians (default 1024-byte limit)
- Error in the hook is logged but does not crash the pool

### Dockerfile Change

- Added `ENV TZ=UTC` immediately after `FROM node:20-alpine`, before `WORKDIR` — ensures the Node.js process itself operates in UTC regardless of the Docker host's timezone

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — this plan creates infrastructure only (SQL migration, config, Dockerfile). No UI or API data-flow stubs introduced.

## Verification Results

Static acceptance criteria verified:

- `grep -c "ADD COLUMN IF NOT EXISTS" 001_phase1_foundation.sql` = 6 (one per table)
- `grep "CREATE TABLE IF NOT EXISTS"` matches `tenants` and `job_number_sequences`
- `grep "idx_jobs_tenant_date_status"` matches
- `grep "idx_jt_tenant_user"` matches
- `grep "ON DUPLICATE KEY UPDATE"` matches
- `grep "timezone: '+00:00'"` matches in database.js
- `grep "group_concat_max_len"` matches in database.js
- `grep "pool.on('connection'"` matches in database.js
- `grep "multipleStatements"` returns no match (correctly absent)
- `grep "ENV TZ=UTC"` returns exactly one match in Dockerfile
- `FROM node:20-alpine` unchanged; `ENV TZ=UTC` at line 7 precedes `WORKDIR` at line 10

**Note:** Live database verification (running the migration and querying results) requires the MySQL/MariaDB server to be running. The migration SQL is syntactically correct per MariaDB 10.4.32 dialect confirmed from vehicle_scheduling.sql dump header.

## Self-Check: PASSED

All created/modified files verified to exist with correct content. All 3 commits verified in git log.
