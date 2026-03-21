// ============================================
// FILE: src/services/notificationService.js
// PURPOSE: FCM push, upcoming/overdue job checks, and notification cleanup
// Requirements: NOTIF-01, NOTIF-02, NOTIF-03, NOTIF-07
// ============================================

const logger = require('../config/logger').child({ service: 'notificationService' });
const db = require('../config/database');
const EmailService = require('./emailService');

// ============================================
// SEND FCM TOPIC NOTIFICATION
// ============================================
/**
 * Send a push notification to an FCM topic.
 * Lazy-loads Firebase — fails gracefully if not configured.
 * Per CONTEXT decision: no retry on FCM failure — log and move on.
 *
 * @param {string} topic - FCM topic name (e.g. 'driver_42', 'scheduler_7')
 * @param {string} title - Notification title
 * @param {string} body - Notification body text
 * @param {object} [data={}] - Additional data payload (string values only)
 */
async function sendTopicNotification(topic, title, body, data = {}) {
  let admin;
  try {
    admin = require('../config/firebase');
  } catch (e) {
    logger.warn({ topic, err: e.message }, 'Firebase not configured — skipping FCM');
    return;
  }

  // Firebase module exports null when not configured
  if (!admin || !admin.apps || admin.apps.length === 0) {
    logger.warn({ topic }, 'Firebase Admin not initialized — skipping FCM push');
    return;
  }

  try {
    const message = {
      notification: { title, body },
      data,
      topic,
    };
    await admin.messaging().send(message);
    logger.info({ topic, title }, 'FCM topic notification sent');
  } catch (err) {
    // Per CONTEXT decision: no retry — log and move on
    logger.warn({ topic, err: err.message }, 'FCM send failed — skipping');
  }
}

// ============================================
// CHECK UPCOMING JOBS (NOTIF-02)
// 15-minute lead time: query jobs starting 10–20 min from now
// Dedup: skip if same job+user+type notified within 20 minutes
// ============================================
async function checkUpcomingJobs() {
  // Get jobs starting in 10–20 min window (accounts for 1-min cron interval, gives ~15-min lead)
  const [jobs] = await db.query(`
    SELECT
      j.id           AS job_id,
      j.job_number,
      j.title        AS job_title,
      j.scheduled_date,
      j.scheduled_time_start,
      j.tenant_id,
      u.id           AS user_id,
      u.email,
      u.full_name,
      COALESCE(np.email_enabled, TRUE) AS email_enabled
    FROM jobs j
    JOIN job_assignments ja ON ja.job_id = j.id
    JOIN users u ON u.id = ja.driver_id AND u.is_active = 1
    LEFT JOIN notification_preferences np ON np.user_id = u.id AND np.tenant_id = j.tenant_id
    WHERE
      CONCAT(j.scheduled_date, ' ', j.scheduled_time_start) BETWEEN DATE_ADD(NOW(), INTERVAL 10 MINUTE) AND DATE_ADD(NOW(), INTERVAL 20 MINUTE)
      AND j.current_status NOT IN ('completed', 'cancelled')
      AND NOT EXISTS (
        SELECT 1 FROM notifications n
        WHERE n.job_id = j.id
          AND n.user_id = u.id
          AND n.type = 'job_starting_soon'
          AND n.created_at > DATE_SUB(NOW(), INTERVAL 20 MINUTE)
      )
  `);

  for (const job of jobs) {
    const title = 'Job Starting Soon';
    const body = `${job.job_title} starts in ~15 minutes`;
    const scheduledTimeStr = `${job.scheduled_date} ${job.scheduled_time_start}`;

    // 1. Insert in-app notification record
    await db.query(
      `INSERT INTO notifications (tenant_id, user_id, job_id, type, title, body) VALUES (?, ?, ?, 'job_starting_soon', ?, ?)`,
      [job.tenant_id, job.user_id, job.job_id, title, body]
    );

    // 2. Send FCM push to driver topic
    await sendTopicNotification(
      `driver_${job.user_id}`,
      title,
      body,
      { jobId: String(job.job_id), type: 'job_starting_soon' }
    );

    // 3. Email if enabled
    if (job.email_enabled && job.email) {
      await EmailService.sendJobNotification({
        to: job.email,
        subject: `Job Starting Soon: ${job.job_number}`,
        title,
        bodyText: body,
        jobNumber: job.job_number,
        scheduledTime: scheduledTimeStr,
      });
    }

    logger.info({ jobId: job.job_id, userId: job.user_id }, 'Sent job_starting_soon notification');
  }

  // Notify schedulers/admins about upcoming jobs
  if (jobs.length > 0) {
    const tenantIds = [...new Set(jobs.map(j => j.tenant_id))];
    for (const tenantId of tenantIds) {
      const tenantJobs = jobs.filter(j => j.tenant_id === tenantId);

      const [schedulers] = await db.query(
        `SELECT id FROM users WHERE tenant_id = ? AND role IN ('admin', 'scheduler', 'dispatcher') AND is_active = 1`,
        [tenantId]
      );

      for (const scheduler of schedulers) {
        for (const job of tenantJobs) {
          // Dedup check for scheduler notifications
          const [existing] = await db.query(
            `SELECT 1 FROM notifications WHERE job_id = ? AND user_id = ? AND type = 'job_starting_soon' AND created_at > DATE_SUB(NOW(), INTERVAL 20 MINUTE) LIMIT 1`,
            [job.job_id, scheduler.id]
          );
          if (existing.length > 0) continue;

          await db.query(
            `INSERT INTO notifications (tenant_id, user_id, job_id, type, title, body) VALUES (?, ?, ?, 'job_starting_soon', ?, ?)`,
            [tenantId, scheduler.id, job.job_id, 'Job Starting Soon', `${job.job_title} (${job.job_number}) starts in ~15 minutes`]
          );

          await sendTopicNotification(
            `scheduler_${scheduler.id}`,
            'Job Starting Soon',
            `${job.job_title} (${job.job_number}) starts in ~15 minutes`,
            { jobId: String(job.job_id), type: 'job_starting_soon' }
          );
        }
      }
    }
  }
}

// ============================================
// CHECK OVERDUE JOBS (NOTIF-03)
// Query jobs 5+ minutes past their scheduled end time, not yet completed/cancelled
// Dedup: skip if same job+user+type notified within 20 minutes
// ============================================
async function checkOverdueJobs() {
  // Get assigned drivers for overdue jobs
  const [driverJobs] = await db.query(`
    SELECT
      j.id           AS job_id,
      j.job_number,
      j.title        AS job_title,
      j.scheduled_date,
      j.scheduled_time_end,
      j.tenant_id,
      u.id           AS user_id,
      u.email,
      u.full_name    AS driver_name,
      COALESCE(np.email_enabled, TRUE) AS email_enabled
    FROM jobs j
    JOIN job_assignments ja ON ja.job_id = j.id
    JOIN users u ON u.id = ja.driver_id AND u.is_active = 1
    LEFT JOIN notification_preferences np ON np.user_id = u.id AND np.tenant_id = j.tenant_id
    WHERE
      CONCAT(j.scheduled_date, ' ', j.scheduled_time_end) < DATE_SUB(NOW(), INTERVAL 5 MINUTE)
      AND j.current_status NOT IN ('completed', 'cancelled')
      AND NOT EXISTS (
        SELECT 1 FROM notifications n
        WHERE n.job_id = j.id
          AND n.user_id = u.id
          AND n.type = 'job_overdue'
          AND n.created_at > DATE_SUB(NOW(), INTERVAL 20 MINUTE)
      )
  `);

  for (const job of driverJobs) {
    const title = 'Job Overdue';
    const body = `Your job ${job.job_title} is overdue`;
    const scheduledTimeStr = `${job.scheduled_date} ${job.scheduled_time_end}`;

    // Insert in-app notification for driver
    await db.query(
      `INSERT INTO notifications (tenant_id, user_id, job_id, type, title, body) VALUES (?, ?, ?, 'job_overdue', ?, ?)`,
      [job.tenant_id, job.user_id, job.job_id, title, body]
    );

    // FCM push to driver
    await sendTopicNotification(
      `driver_${job.user_id}`,
      title,
      body,
      { jobId: String(job.job_id), type: 'job_overdue' }
    );

    // Email if enabled
    if (job.email_enabled && job.email) {
      await EmailService.sendJobNotification({
        to: job.email,
        subject: `Job Overdue: ${job.job_number}`,
        title,
        bodyText: body,
        jobNumber: job.job_number,
        scheduledTime: scheduledTimeStr,
      });
    }

    // Notify schedulers/admins
    const [schedulers] = await db.query(
      `SELECT id FROM users WHERE tenant_id = ? AND role IN ('admin', 'scheduler', 'dispatcher') AND is_active = 1`,
      [job.tenant_id]
    );

    for (const scheduler of schedulers) {
      // Dedup for scheduler
      const [existing] = await db.query(
        `SELECT 1 FROM notifications WHERE job_id = ? AND user_id = ? AND type = 'job_overdue' AND created_at > DATE_SUB(NOW(), INTERVAL 20 MINUTE) LIMIT 1`,
        [job.job_id, scheduler.id]
      );
      if (existing.length > 0) continue;

      const schedulerTitle = 'Job Overdue';
      const schedulerBody = `Job ${job.job_number} assigned to ${job.driver_name} is overdue`;

      await db.query(
        `INSERT INTO notifications (tenant_id, user_id, job_id, type, title, body) VALUES (?, ?, ?, 'job_overdue', ?, ?)`,
        [job.tenant_id, scheduler.id, job.job_id, schedulerTitle, schedulerBody]
      );

      await sendTopicNotification(
        `scheduler_${scheduler.id}`,
        schedulerTitle,
        schedulerBody,
        { jobId: String(job.job_id), type: 'job_overdue' }
      );
    }

    logger.info({ jobId: job.job_id, userId: job.user_id }, 'Sent job_overdue notification');
  }
}

// ============================================
// CLEAN OLD NOTIFICATIONS (30-day retention)
// Called daily via cron
// ============================================
async function cleanOldNotifications() {
  const [result] = await db.query(
    `DELETE FROM notifications WHERE created_at < DATE_SUB(NOW(), INTERVAL 30 DAY)`
  );
  logger.info({ deletedCount: result.affectedRows }, 'Old notifications cleaned (30-day retention)');
}

module.exports = {
  sendTopicNotification,
  checkUpcomingJobs,
  checkOverdueJobs,
  cleanOldNotifications,
};
