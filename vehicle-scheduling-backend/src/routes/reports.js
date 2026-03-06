// ============================================
// FILE: src/routes/reports.js
// PURPOSE: Admin reporting & analytics endpoints
//
// All endpoints require: admin or scheduler role.
// All endpoints accept optional query params:
//   date_from  YYYY-MM-DD  (default: 30 days ago)
//   date_to    YYYY-MM-DD  (default: today)
//
// Endpoints:
//   GET /api/reports/summary              — KPI overview cards
//   GET /api/reports/jobs-by-vehicle      — per-vehicle breakdown
//   GET /api/reports/jobs-by-technician   — per-technician breakdown
//   GET /api/reports/jobs-by-type         — installation/delivery/misc
//   GET /api/reports/jobs-by-status       — status funnel
//   GET /api/reports/cancellations        — cancellation detail + reasons
//   GET /api/reports/daily-volume         — jobs per day (chart data)
//   GET /api/reports/vehicle-utilisation  — % of working days a vehicle was used
//   GET /api/reports/technician-performance — completion rate, avg duration
//   GET /api/reports/executive-dashboard  — everything in one call (boss view)
// ============================================

const express = require('express');
const router  = express.Router();
const db      = require('../config/database');
const { verifyToken, schedulerOrAbove } = require('../middleware/authMiddleware');

// ── Auth ─────────────────────────────────────────────────────────────────────
router.use(verifyToken, schedulerOrAbove);

// ── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Parse date_from / date_to from query string.
 * Defaults to the last 30 days.
 */
function parseDateRange(query) {
  const today    = new Date();
  const defFrom  = new Date(today);
  defFrom.setDate(defFrom.getDate() - 30);

  const dateFrom = query.date_from || defFrom.toISOString().slice(0, 10);
  const dateTo   = query.date_to   || today.toISOString().slice(0, 10);
  return { dateFrom, dateTo };
}

/** Zero-pad helper so we never get "undefined" in SQL strings. */
const safe = (v, fallback = 0) => (v === null || v === undefined ? fallback : v);

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/reports/summary
// Quick KPI cards for the top of the Reports screen.
// ─────────────────────────────────────────────────────────────────────────────
router.get('/summary', async (req, res) => {
  try {
    const { dateFrom, dateTo } = parseDateRange(req.query);

    // Total jobs in period + counts per status
    const [statusRows] = await db.query(
      `SELECT current_status AS status, COUNT(*) AS cnt
       FROM jobs
       WHERE scheduled_date BETWEEN ? AND ?
       GROUP BY current_status`,
      [dateFrom, dateTo]
    );

    const statusMap = {};
    statusRows.forEach(r => { statusMap[r.status] = Number(r.cnt); });

    const total       = statusRows.reduce((s, r) => s + Number(r.cnt), 0);
    const completed   = safe(statusMap['completed']);
    const cancelled   = safe(statusMap['cancelled']);
    const inProgress  = safe(statusMap['in_progress']);
    const assigned    = safe(statusMap['assigned']);
    const pending     = safe(statusMap['pending']);

    const completionRate = total > 0
      ? ((completed / total) * 100).toFixed(1)
      : '0.0';
    const cancellationRate = total > 0
      ? ((cancelled / total) * 100).toFixed(1)
      : '0.0';

    // Active vehicles used at least once in period
    const [[{ activeVehicles }]] = await db.query(
      `SELECT COUNT(DISTINCT ja.vehicle_id) AS activeVehicles
       FROM job_assignments ja
       JOIN jobs j ON j.id = ja.job_id
       WHERE j.scheduled_date BETWEEN ? AND ?`,
      [dateFrom, dateTo]
    );

    // Active technicians who had at least one job in period
    const [[{ activeTechs }]] = await db.query(
      `SELECT COUNT(DISTINCT jt.user_id) AS activeTechs
       FROM job_technicians jt
       JOIN jobs j ON j.id = jt.job_id
       WHERE j.scheduled_date BETWEEN ? AND ?`,
      [dateFrom, dateTo]
    );

    // Avg jobs per day
    const daysDiff = Math.max(
      1,
      Math.round((new Date(dateTo) - new Date(dateFrom)) / 86400000) + 1
    );
    const avgPerDay = (total / daysDiff).toFixed(1);

    res.json({
      success: true,
      period : { dateFrom, dateTo, daysDiff },
      summary: {
        total,
        completed,
        cancelled,
        inProgress,
        assigned,
        pending,
        completionRate:    parseFloat(completionRate),
        cancellationRate:  parseFloat(cancellationRate),
        activeVehicles:    Number(activeVehicles),
        activeTechnicians: Number(activeTechs),
        avgJobsPerDay:     parseFloat(avgPerDay),
      },
    });
  } catch (err) {
    console.error('GET /reports/summary error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/reports/jobs-by-vehicle
// Per-vehicle job counts, status breakdown, most recent job date.
// ─────────────────────────────────────────────────────────────────────────────
router.get('/jobs-by-vehicle', async (req, res) => {
  try {
    const { dateFrom, dateTo } = parseDateRange(req.query);

    const [rows] = await db.query(
      `SELECT
         v.id                                                        AS vehicle_id,
         v.vehicle_name,
         v.license_plate,
         v.vehicle_type,
         COUNT(j.id)                                                 AS total_jobs,
         SUM(j.current_status = 'completed')                         AS completed,
         SUM(j.current_status = 'cancelled')                         AS cancelled,
         SUM(j.current_status = 'in_progress')                       AS in_progress,
         SUM(j.current_status = 'assigned')                          AS assigned,
         SUM(j.current_status = 'pending')                           AS pending,
         SUM(j.job_type = 'installation')                            AS installations,
         SUM(j.job_type = 'delivery')                                AS deliveries,
         SUM(j.job_type = 'miscellaneous')                           AS miscellaneous,
         MAX(j.scheduled_date)                                       AS last_job_date,
         MIN(j.scheduled_date)                                       AS first_job_date,
         ROUND(
           SUM(j.current_status = 'completed') * 100.0 / COUNT(j.id), 1
         )                                                           AS completion_rate
       FROM vehicles v
       JOIN job_assignments ja ON ja.vehicle_id = v.id
       JOIN jobs j             ON j.id = ja.job_id
       WHERE j.scheduled_date BETWEEN ? AND ?
         AND v.is_active = 1
       GROUP BY v.id, v.vehicle_name, v.license_plate, v.vehicle_type
       ORDER BY total_jobs DESC`,
      [dateFrom, dateTo]
    );

    res.json({
      success: true,
      period : { dateFrom, dateTo },
      vehicles: rows.map(r => ({
        vehicleId      : r.vehicle_id,
        vehicleName    : r.vehicle_name,
        licensePlate   : r.license_plate,
        vehicleType    : r.vehicle_type,
        totalJobs      : Number(r.total_jobs),
        completed      : Number(r.completed),
        cancelled      : Number(r.cancelled),
        inProgress     : Number(r.in_progress),
        assigned       : Number(r.assigned),
        pending        : Number(r.pending),
        installations  : Number(r.installations),
        deliveries     : Number(r.deliveries),
        miscellaneous  : Number(r.miscellaneous),
        completionRate : Number(r.completion_rate),
        lastJobDate    : r.last_job_date,
        firstJobDate   : r.first_job_date,
      })),
    });
  } catch (err) {
    console.error('GET /reports/jobs-by-vehicle error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/reports/jobs-by-technician
// Per-technician job counts, completion rate, cancellations.
// ─────────────────────────────────────────────────────────────────────────────
router.get('/jobs-by-technician', async (req, res) => {
  try {
    const { dateFrom, dateTo } = parseDateRange(req.query);

    const [rows] = await db.query(
      `SELECT
         u.id                                                         AS technician_id,
         u.full_name,
         u.username,
         COUNT(DISTINCT j.id)                                         AS total_jobs,
         SUM(j.current_status = 'completed')                          AS completed,
         SUM(j.current_status = 'cancelled')                          AS cancelled,
         SUM(j.current_status = 'in_progress')                        AS in_progress,
         SUM(j.current_status = 'assigned')                           AS assigned,
         SUM(j.current_status = 'pending')                            AS pending,
         SUM(j.job_type = 'installation')                             AS installations,
         SUM(j.job_type = 'delivery')                                 AS deliveries,
         SUM(j.job_type = 'miscellaneous')                            AS miscellaneous,
         MAX(j.scheduled_date)                                        AS last_job_date,
         ROUND(
           SUM(j.current_status = 'completed') * 100.0 /
           NULLIF(COUNT(DISTINCT j.id), 0), 1
         )                                                            AS completion_rate,
         ROUND(
           SUM(j.current_status = 'cancelled') * 100.0 /
           NULLIF(COUNT(DISTINCT j.id), 0), 1
         )                                                            AS cancellation_rate
       FROM users u
       JOIN job_technicians jt ON jt.user_id = u.id
       JOIN jobs j             ON j.id = jt.job_id
       WHERE j.scheduled_date BETWEEN ? AND ?
         AND u.is_active = 1
       GROUP BY u.id, u.full_name, u.username
       ORDER BY total_jobs DESC`,
      [dateFrom, dateTo]
    );

    res.json({
      success: true,
      period: { dateFrom, dateTo },
      technicians: rows.map(r => ({
        technicianId     : r.technician_id,
        fullName         : r.full_name,
        username         : r.username,
        totalJobs        : Number(r.total_jobs),
        completed        : Number(r.completed),
        cancelled        : Number(r.cancelled),
        inProgress       : Number(r.in_progress),
        assigned         : Number(r.assigned),
        pending          : Number(r.pending),
        installations    : Number(r.installations),
        deliveries       : Number(r.deliveries),
        miscellaneous    : Number(r.miscellaneous),
        completionRate   : Number(r.completion_rate || 0),
        cancellationRate : Number(r.cancellation_rate || 0),
        lastJobDate      : r.last_job_date,
      })),
    });
  } catch (err) {
    console.error('GET /reports/jobs-by-technician error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/reports/jobs-by-type
// Breakdown by job_type with status sub-counts.
// ─────────────────────────────────────────────────────────────────────────────
router.get('/jobs-by-type', async (req, res) => {
  try {
    const { dateFrom, dateTo } = parseDateRange(req.query);

    const [rows] = await db.query(
      `SELECT
         job_type,
         COUNT(*)                                  AS total,
         SUM(current_status = 'completed')          AS completed,
         SUM(current_status = 'cancelled')          AS cancelled,
         SUM(current_status = 'in_progress')        AS in_progress,
         SUM(current_status = 'assigned')           AS assigned,
         SUM(current_status = 'pending')            AS pending,
         ROUND(
           SUM(current_status = 'completed') * 100.0 / COUNT(*), 1
         )                                         AS completion_rate
       FROM jobs
       WHERE scheduled_date BETWEEN ? AND ?
       GROUP BY job_type
       ORDER BY total DESC`,
      [dateFrom, dateTo]
    );

    res.json({
      success: true,
      period: { dateFrom, dateTo },
      byType: rows.map(r => ({
        jobType        : r.job_type,
        total          : Number(r.total),
        completed      : Number(r.completed),
        cancelled      : Number(r.cancelled),
        inProgress     : Number(r.in_progress),
        assigned       : Number(r.assigned),
        pending        : Number(r.pending),
        completionRate : Number(r.completion_rate || 0),
      })),
    });
  } catch (err) {
    console.error('GET /reports/jobs-by-type error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/reports/cancellations
// Cancelled job detail — who cancelled, which technician, vehicle, reason.
// ─────────────────────────────────────────────────────────────────────────────
router.get('/cancellations', async (req, res) => {
  try {
    const { dateFrom, dateTo } = parseDateRange(req.query);

    // Cancelled jobs with last status-history reason
    const [jobs] = await db.query(
      `SELECT
         j.id,
         j.customer_name,
         j.job_type,
         j.priority,
         j.scheduled_date,
         j.scheduled_time_start,
         v.vehicle_name,
         v.license_plate,
         (
           SELECT GROUP_CONCAT(u2.full_name ORDER BY u2.full_name SEPARATOR ', ')
           FROM job_technicians jt2
           JOIN users u2 ON u2.id = jt2.user_id
           WHERE jt2.job_id = j.id
         )                          AS technician_names,
         (
           SELECT jsh.reason
           FROM job_status_changes jsh
           WHERE jsh.job_id = j.id
             AND jsh.new_status = 'cancelled'
           ORDER BY jsh.changed_at DESC
           LIMIT 1
         )                          AS cancel_reason,
         (
           SELECT u3.full_name
           FROM job_status_changes jsh2
           JOIN users u3 ON u3.id = jsh2.changed_by
           WHERE jsh2.job_id = j.id
             AND jsh2.new_status = 'cancelled'
           ORDER BY jsh2.changed_at DESC
           LIMIT 1
         )                          AS cancelled_by,
         (
           SELECT jsh3.changed_at
           FROM job_status_changes jsh3
           WHERE jsh3.job_id = j.id
             AND jsh3.new_status = 'cancelled'
           ORDER BY jsh3.changed_at DESC
           LIMIT 1
         )                          AS cancelled_at
       FROM jobs j
       LEFT JOIN job_assignments ja ON ja.job_id = j.id
       LEFT JOIN vehicles v         ON v.id = ja.vehicle_id
       WHERE j.current_status = 'cancelled'
         AND j.scheduled_date BETWEEN ? AND ?
       ORDER BY j.scheduled_date DESC`,
      [dateFrom, dateTo]
    );

    // Summary counts by reason (best-effort from status_history)
    const [reasonRows] = await db.query(
      `SELECT
         COALESCE(jsh.reason, 'No reason given') AS reason,
         COUNT(*)                                 AS cnt
       FROM jobs j
       LEFT JOIN job_status_changes jsh
         ON jsh.job_id = j.id AND jsh.new_status = 'cancelled'
       WHERE j.current_status = 'cancelled'
         AND j.scheduled_date BETWEEN ? AND ?
       GROUP BY reason
       ORDER BY cnt DESC`,
      [dateFrom, dateTo]
    );

    res.json({
      success: true,
      period : { dateFrom, dateTo },
      total  : jobs.length,
      byReason: reasonRows.map(r => ({
        reason: r.reason,
        count : Number(r.cnt),
      })),
      jobs: jobs.map(j => ({
        jobId           : j.id,
        customerName    : j.customer_name,
        jobType         : j.job_type,
        priority        : j.priority,
        scheduledDate   : j.scheduled_date,
        scheduledTime   : j.scheduled_time_start,
        vehicleName     : j.vehicle_name || null,
        licensePlate    : j.license_plate || null,
        technicianNames : j.technician_names || null,
        cancelReason    : j.cancel_reason || null,
        cancelledBy     : j.cancelled_by || null,
        cancelledAt     : j.cancelled_at || null,
      })),
    });
  } catch (err) {
    console.error('GET /reports/cancellations error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/reports/daily-volume
// Jobs created/scheduled per calendar day — for the line/bar chart.
// ─────────────────────────────────────────────────────────────────────────────
router.get('/daily-volume', async (req, res) => {
  try {
    const { dateFrom, dateTo } = parseDateRange(req.query);

    const [rows] = await db.query(
      `SELECT
         scheduled_date                        AS date,
         COUNT(*)                              AS total,
         SUM(current_status = 'completed')      AS completed,
         SUM(current_status = 'cancelled')      AS cancelled,
         SUM(current_status IN
           ('pending','assigned','in_progress'))AS active
       FROM jobs
       WHERE scheduled_date BETWEEN ? AND ?
       GROUP BY scheduled_date
       ORDER BY scheduled_date ASC`,
      [dateFrom, dateTo]
    );

    res.json({
      success: true,
      period : { dateFrom, dateTo },
      days   : rows.map(r => ({
        date      : r.date,
        total     : Number(r.total),
        completed : Number(r.completed),
        cancelled : Number(r.cancelled),
        active    : Number(r.active),
      })),
    });
  } catch (err) {
    console.error('GET /reports/daily-volume error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/reports/vehicle-utilisation
// For each vehicle: how many distinct days it was scheduled vs total days
// in range — gives a utilisation % the boss can act on.
// ─────────────────────────────────────────────────────────────────────────────
router.get('/vehicle-utilisation', async (req, res) => {
  try {
    const { dateFrom, dateTo } = parseDateRange(req.query);

    const totalDays = Math.max(
      1,
      Math.round((new Date(dateTo) - new Date(dateFrom)) / 86400000) + 1
    );

    const [rows] = await db.query(
      `SELECT
         v.id                                          AS vehicle_id,
         v.vehicle_name,
         v.license_plate,
         v.vehicle_type,
         COUNT(DISTINCT j.scheduled_date)              AS days_used,
         COUNT(j.id)                                   AS total_jobs,
         SUM(j.current_status = 'completed')            AS completed_jobs,
         ROUND(
           COUNT(DISTINCT j.scheduled_date) * 100.0 / ?, 1
         )                                             AS utilisation_pct
       FROM vehicles v
       LEFT JOIN job_assignments ja ON ja.vehicle_id = v.id
       LEFT JOIN jobs j ON j.id = ja.job_id
         AND j.scheduled_date BETWEEN ? AND ?
       WHERE v.is_active = 1
       GROUP BY v.id, v.vehicle_name, v.license_plate, v.vehicle_type
       ORDER BY utilisation_pct DESC`,
      [totalDays, dateFrom, dateTo]
    );

    res.json({
      success   : true,
      period    : { dateFrom, dateTo, totalDays },
      vehicles  : rows.map(r => ({
        vehicleId      : r.vehicle_id,
        vehicleName    : r.vehicle_name,
        licensePlate   : r.license_plate,
        vehicleType    : r.vehicle_type,
        daysUsed       : Number(r.days_used),
        totalJobs      : Number(r.total_jobs),
        completedJobs  : Number(r.completed_jobs),
        utilisationPct : Number(r.utilisation_pct || 0),
      })),
    });
  } catch (err) {
    console.error('GET /reports/vehicle-utilisation error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/reports/technician-performance
// Completion rate, cancellation rate, jobs per type, busiest days.
// ─────────────────────────────────────────────────────────────────────────────
router.get('/technician-performance', async (req, res) => {
  try {
    const { dateFrom, dateTo } = parseDateRange(req.query);

    const [rows] = await db.query(
      `SELECT
         u.id                                                          AS technician_id,
         u.full_name,
         u.username,
         COUNT(DISTINCT j.id)                                          AS total_jobs,
         SUM(j.current_status = 'completed')                           AS completed,
         SUM(j.current_status = 'cancelled')                           AS cancelled,
         SUM(j.current_status = 'in_progress')                         AS in_progress,
         SUM(j.current_status IN ('pending','assigned'))               AS upcoming,
         SUM(j.job_type = 'installation')                              AS installations,
         SUM(j.job_type = 'delivery')                                  AS deliveries,
         SUM(j.job_type = 'miscellaneous')                             AS miscellaneous,
         SUM(j.priority = 'high')                                      AS high_priority,
         SUM(j.priority = 'urgent')                                    AS urgent,
         ROUND(
           SUM(j.current_status = 'completed') * 100.0 /
           NULLIF(COUNT(DISTINCT j.id), 0), 1
         )                                                             AS completion_rate,
         ROUND(
           SUM(j.current_status = 'cancelled') * 100.0 /
           NULLIF(COUNT(DISTINCT j.id), 0), 1
         )                                                             AS cancellation_rate,
         MAX(j.scheduled_date)                                         AS last_active_date
       FROM users u
       JOIN job_technicians jt ON jt.user_id = u.id
       JOIN jobs j             ON j.id = jt.job_id
       WHERE j.scheduled_date BETWEEN ? AND ?
         AND u.is_active = 1
       GROUP BY u.id, u.full_name, u.username
       ORDER BY completed DESC, total_jobs DESC`,
      [dateFrom, dateTo]
    );

    res.json({
      success     : true,
      period      : { dateFrom, dateTo },
      technicians : rows.map(r => ({
        technicianId     : r.technician_id,
        fullName         : r.full_name,
        username         : r.username,
        totalJobs        : Number(r.total_jobs),
        completed        : Number(r.completed),
        cancelled        : Number(r.cancelled),
        inProgress       : Number(r.in_progress),
        upcoming         : Number(r.upcoming),
        installations    : Number(r.installations),
        deliveries       : Number(r.deliveries),
        miscellaneous    : Number(r.miscellaneous),
        highPriority     : Number(r.high_priority),
        urgent           : Number(r.urgent),
        completionRate   : Number(r.completion_rate   || 0),
        cancellationRate : Number(r.cancellation_rate || 0),
        lastActiveDate   : r.last_active_date,
      })),
    });
  } catch (err) {
    console.error('GET /reports/technician-performance error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/reports/executive-dashboard
// Everything in a single call — used by the Flutter Reports screen on load.
// Fires all sub-queries in parallel with Promise.all for speed.
// ─────────────────────────────────────────────────────────────────────────────
router.get('/executive-dashboard', async (req, res) => {
  try {
    const { dateFrom, dateTo } = parseDateRange(req.query);

    const totalDays = Math.max(
      1,
      Math.round((new Date(dateTo) - new Date(dateFrom)) / 86400000) + 1
    );

    const [
      [statusRows],
      [vehicleRows],
      [techRows],
      [typeRows],
      [dailyRows],
      [utilisationRows],
      [[{ activeVehicles }]],
      [[{ activeTechs }]],
    ] = await Promise.all([
      // 1. Status summary
      db.query(
        `SELECT current_status AS status, COUNT(*) AS cnt
         FROM jobs WHERE scheduled_date BETWEEN ? AND ?
         GROUP BY current_status`,
        [dateFrom, dateTo]
      ),
      // 2. Per vehicle
      db.query(
        `SELECT
           v.id AS vehicle_id, v.vehicle_name, v.license_plate, v.vehicle_type,
           COUNT(j.id)                                  AS total_jobs,
           SUM(j.current_status = 'completed')           AS completed,
           SUM(j.current_status = 'cancelled')           AS cancelled,
           COUNT(DISTINCT j.scheduled_date)              AS days_used,
           ROUND(COUNT(DISTINCT j.scheduled_date)*100.0/?, 1) AS utilisation_pct
         FROM vehicles v
         JOIN job_assignments ja ON ja.vehicle_id = v.id
         JOIN jobs j ON j.id = ja.job_id
         WHERE j.scheduled_date BETWEEN ? AND ? AND v.is_active = 1
         GROUP BY v.id, v.vehicle_name, v.license_plate, v.vehicle_type
         ORDER BY total_jobs DESC`,
        [totalDays, dateFrom, dateTo]
      ),
      // 3. Per technician
      db.query(
        `SELECT
           u.id AS technician_id, u.full_name,
           COUNT(DISTINCT j.id)                                      AS total_jobs,
           SUM(j.current_status = 'completed')                        AS completed,
           SUM(j.current_status = 'cancelled')                        AS cancelled,
           ROUND(SUM(j.current_status='completed')*100.0/NULLIF(COUNT(DISTINCT j.id),0),1) AS completion_rate
         FROM users u
         JOIN job_technicians jt ON jt.user_id = u.id
         JOIN jobs j ON j.id = jt.job_id
         WHERE j.scheduled_date BETWEEN ? AND ? AND u.is_active = 1
         GROUP BY u.id, u.full_name
         ORDER BY completed DESC`,
        [dateFrom, dateTo]
      ),
      // 4. By job type
      db.query(
        `SELECT job_type, COUNT(*) AS total,
                SUM(current_status='completed') AS completed,
                SUM(current_status='cancelled') AS cancelled
         FROM jobs WHERE scheduled_date BETWEEN ? AND ?
         GROUP BY job_type ORDER BY total DESC`,
        [dateFrom, dateTo]
      ),
      // 5. Daily volume (last 14 days only for chart performance)
      db.query(
        `SELECT scheduled_date AS date,
                COUNT(*) AS total,
                SUM(current_status='completed') AS completed,
                SUM(current_status='cancelled') AS cancelled
         FROM jobs
         WHERE scheduled_date BETWEEN ? AND ?
         GROUP BY scheduled_date ORDER BY scheduled_date ASC`,
        [dateFrom, dateTo]
      ),
      // 6. Utilisation
      db.query(
        `SELECT v.id AS vehicle_id, v.vehicle_name,
                COUNT(DISTINCT j.scheduled_date) AS days_used,
                ROUND(COUNT(DISTINCT j.scheduled_date)*100.0/?, 1) AS utilisation_pct
         FROM vehicles v
         LEFT JOIN job_assignments ja ON ja.vehicle_id = v.id
         LEFT JOIN jobs j ON j.id = ja.job_id AND j.scheduled_date BETWEEN ? AND ?
         WHERE v.is_active = 1
         GROUP BY v.id, v.vehicle_name
         ORDER BY utilisation_pct DESC`,
        [totalDays, dateFrom, dateTo]
      ),
      // 7. Active vehicles scalar
      db.query(
        `SELECT COUNT(DISTINCT ja.vehicle_id) AS activeVehicles
         FROM job_assignments ja
         JOIN jobs j ON j.id = ja.job_id
         WHERE j.scheduled_date BETWEEN ? AND ?`,
        [dateFrom, dateTo]
      ),
      // 8. Active technicians scalar
      db.query(
        `SELECT COUNT(DISTINCT jt.user_id) AS activeTechs
         FROM job_technicians jt
         JOIN jobs j ON j.id = jt.job_id
         WHERE j.scheduled_date BETWEEN ? AND ?`,
        [dateFrom, dateTo]
      ),
    ]);

    // Build status map
    const statusMap = {};
    statusRows.forEach(r => { statusMap[r.status] = Number(r.cnt); });
    const total     = statusRows.reduce((s, r) => s + Number(r.cnt), 0);
    const completed = statusMap['completed'] || 0;
    const cancelled = statusMap['cancelled'] || 0;

    res.json({
      success : true,
      period  : { dateFrom, dateTo, totalDays },
      summary : {
        total,
        completed,
        cancelled,
        inProgress        : statusMap['in_progress'] || 0,
        assigned          : statusMap['assigned']    || 0,
        pending           : statusMap['pending']     || 0,
        completionRate    : total > 0 ? parseFloat(((completed / total) * 100).toFixed(1)) : 0,
        cancellationRate  : total > 0 ? parseFloat(((cancelled / total) * 100).toFixed(1)) : 0,
        activeVehicles    : Number(activeVehicles),
        activeTechnicians : Number(activeTechs),
        avgJobsPerDay     : parseFloat((total / totalDays).toFixed(1)),
      },
      vehicles: vehicleRows.map(r => ({
        vehicleId      : r.vehicle_id,
        vehicleName    : r.vehicle_name,
        licensePlate   : r.license_plate,
        vehicleType    : r.vehicle_type,
        totalJobs      : Number(r.total_jobs),
        completed      : Number(r.completed),
        cancelled      : Number(r.cancelled),
        daysUsed       : Number(r.days_used),
        utilisationPct : Number(r.utilisation_pct || 0),
      })),
      technicians: techRows.map(r => ({
        technicianId   : r.technician_id,
        fullName       : r.full_name,
        totalJobs      : Number(r.total_jobs),
        completed      : Number(r.completed),
        cancelled      : Number(r.cancelled),
        completionRate : Number(r.completion_rate || 0),
      })),
      byType: typeRows.map(r => ({
        jobType   : r.job_type,
        total     : Number(r.total),
        completed : Number(r.completed),
        cancelled : Number(r.cancelled),
      })),
      dailyVolume: dailyRows.map(r => ({
        date      : r.date,
        total     : Number(r.total),
        completed : Number(r.completed),
        cancelled : Number(r.cancelled),
      })),
      utilisation: utilisationRows.map(r => ({
        vehicleId      : r.vehicle_id,
        vehicleName    : r.vehicle_name,
        daysUsed       : Number(r.days_used),
        utilisationPct : Number(r.utilisation_pct || 0),
      })),
    });
  } catch (err) {
    console.error('GET /reports/executive-dashboard error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;