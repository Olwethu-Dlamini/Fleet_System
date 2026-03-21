// ============================================
// FILE: src/services/cronService.js
// PURPOSE: Cron scheduler for auto-transitioning jobs
// Requirements: STAT-01
// ============================================

const cron = require('node-cron');
const db = require('../config/database');
const JobStatusService = require('./jobStatusService');
const logger = require('../config/logger').child({ service: 'cronService' });

/**
 * Start all cron jobs.
 * Call this only inside `if (require.main === module)` guard in server.js
 * to prevent cron from firing during supertest/Jest imports.
 */
function startCronJobs() {
  // STAT-01: Every minute, auto-transition assigned jobs whose start time has passed
  // Assumes single-instance deployment (v1). Multiple instances would cause duplicate transitions.
  cron.schedule('* * * * *', async () => {
    try {
      const [jobs] = await db.query(`
        SELECT id, job_number FROM jobs
        WHERE current_status = 'assigned'
          AND CONCAT(scheduled_date, ' ', scheduled_time_start) <= NOW()
      `);

      for (const job of jobs) {
        try {
          await JobStatusService.updateJobStatus(
            job.id,
            'in_progress',
            null,   // system-initiated: no user ID (changed_by nullable per Plan 01 migration)
            'auto-transitioned by cron scheduler'
          );
          logger.info({ jobId: job.id, jobNumber: job.job_number }, 'Auto-transitioned job to in_progress');
        } catch (err) {
          // Per-job error handling: if transition fails (e.g., job was cancelled between SELECT and UPDATE),
          // log as info not error — this is expected race condition behavior
          logger.info({ jobId: job.id, err: err.message }, 'Skipped auto-transition (transition rule rejected)');
        }
      }
    } catch (err) {
      logger.error({ err }, 'Cron auto-transition query error');
    }
  });

  logger.info('Cron jobs started (auto-transition every 1 minute)');
}

module.exports = { startCronJobs };
