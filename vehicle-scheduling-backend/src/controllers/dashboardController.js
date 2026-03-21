// ============================================
// FILE: src/controllers/dashboardController.js
// PURPOSE: Business logic for the dashboard endpoints.
//
// Called by:
//   GET /api/dashboard/summary    → getDashboardSummary
//   GET /api/dashboard/stats      → getQuickStats
//   GET /api/dashboard/chart-data → getChartData
//
// getDashboardSummary — full overview with job lists, vehicle list,
//   recent status changes, and all KPI counts.
//
// getQuickStats — lightweight count-only response, used for
//   notification badges and the sidebar count chips.
//
// getChartData — hourly job counts for today, scoped to tenant.
//   Used for the "Jobs Today" bar chart on the dashboard.
// ============================================

const db  = require('../config/database');
const Job = require('../models/Job');
const logger = require('../config/logger');
const log    = logger.child({ service: 'dashboard-controller' });

class DashboardController {

  // ─────────────────────────────────────────────────────────────────────
  // getDashboardSummary
  // GET /api/dashboard/summary
  //
  // Returns:
  // {
  //   success: true,
  //   stats: {
  //     pending, assigned, inProgress, completed, cancelled, total
  //   },
  //   todayJobs:      [...],   // all jobs scheduled for today
  //   recentChanges:  [...],   // last 10 status changes
  //   activeVehicles: number,
  //   vehicles:       [...],   // all vehicles with today's job count
  // }
  // ─────────────────────────────────────────────────────────────────────
  static async getDashboardSummary(req, res) {
    try {
      const today    = new Date().toISOString().slice(0, 10);
      const tenantId = req.user.tenant_id;

      // Run all queries in parallel for speed
      const [
        [statusRows],
        todayJobs,
        [recentRows],
        [vehicleRows],
        [[{ activeVehicles }]],
      ] = await Promise.all([
        // 1. Job counts per status (scoped to tenant)
        db.query(
          `SELECT current_status AS status, COUNT(*) AS cnt
           FROM jobs
           WHERE tenant_id = ?
           GROUP BY current_status`,
          [tenantId]
        ),

        // 2. Today's jobs (full job objects with vehicle/technician info)
        Job.getJobsByDate(today, null, tenantId),

        // 3. Last 10 status changes across all jobs (scoped to tenant)
        db.query(
          `SELECT
             jsc.id,
             jsc.job_id,
             j.job_number,
             j.customer_name,
             jsc.old_status,
             jsc.new_status,
             jsc.reason,
             jsc.changed_at,
             u.full_name AS changed_by_name
           FROM job_status_changes jsc
           JOIN jobs  j ON j.id  = jsc.job_id AND j.tenant_id = ?
           LEFT JOIN users u ON u.id = jsc.changed_by
           ORDER BY jsc.changed_at DESC
           LIMIT 10`,
          [tenantId]
        ),

        // 4. All vehicles with today's assigned job count (scoped to tenant)
        db.query(
          `SELECT
             v.id,
             v.vehicle_name,
             v.license_plate,
             v.vehicle_type,
             v.is_active,
             COUNT(ja.job_id) AS jobs_today
           FROM vehicles v
           LEFT JOIN job_assignments ja ON ja.vehicle_id = v.id
           LEFT JOIN jobs j
             ON j.id = ja.job_id
             AND j.scheduled_date = ?
             AND j.current_status NOT IN ('completed', 'cancelled')
             AND j.tenant_id = ?
           WHERE v.is_active = 1
             AND v.tenant_id = ?
           GROUP BY v.id, v.vehicle_name, v.license_plate, v.vehicle_type, v.is_active
           ORDER BY v.vehicle_name ASC`,
          [today, tenantId, tenantId]
        ),

        // 5. Active vehicle count (assigned at least one job today, scoped to tenant)
        db.query(
          `SELECT COUNT(DISTINCT ja.vehicle_id) AS activeVehicles
           FROM job_assignments ja
           JOIN jobs j ON j.id = ja.job_id
           WHERE j.scheduled_date = ?
             AND j.current_status NOT IN ('completed', 'cancelled')
             AND j.tenant_id = ?`,
          [today, tenantId]
        ),
      ]);

      // Build status map
      const statusMap = {};
      statusRows.forEach(r => { statusMap[r.status] = Number(r.cnt); });

      const stats = {
        pending    : statusMap['pending']     || 0,
        assigned   : statusMap['assigned']    || 0,
        inProgress : statusMap['in_progress'] || 0,
        completed  : statusMap['completed']   || 0,
        cancelled  : statusMap['cancelled']   || 0,
        total      : statusRows.reduce((s, r) => s + Number(r.cnt), 0),
      };

      return res.json({
        success       : true,
        today,
        stats,
        todayJobs,
        recentChanges : recentRows,
        activeVehicles: Number(activeVehicles),
        vehicles      : vehicleRows.map(v => ({
          id          : v.id,
          vehicleName : v.vehicle_name,
          licensePlate: v.license_plate,
          vehicleType : v.vehicle_type,
          isActive    : v.is_active === 1,
          jobsToday   : Number(v.jobs_today),
        })),
      });

    } catch (err) {
      log.error({ err: err }, 'getDashboardSummary error');
      return res.status(500).json({ success: false, error: err.message });
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // getQuickStats
  // GET /api/dashboard/stats
  //
  // Lightweight — returns only counts. Used for badge chips and the
  // sidebar summary row. No job lists, no vehicle details.
  //
  // Returns:
  // {
  //   success: true,
  //   stats: {
  //     pending, assigned, inProgress, completed, cancelled, total,
  //     todayTotal, todayCompleted, todayPending
  //   }
  // }
  // ─────────────────────────────────────────────────────────────────────
  static async getQuickStats(req, res) {
    try {
      const today    = new Date().toISOString().slice(0, 10);
      const tenantId = req.user.tenant_id;

      const [[allStatRows], [todayStatRows]] = await Promise.all([
        // All-time counts per status (scoped to tenant)
        db.query(
          `SELECT current_status AS status, COUNT(*) AS cnt
           FROM jobs
           WHERE tenant_id = ?
           GROUP BY current_status`,
          [tenantId]
        ),
        // Today's counts per status (scoped to tenant)
        db.query(
          `SELECT current_status AS status, COUNT(*) AS cnt
           FROM jobs
           WHERE scheduled_date = ?
             AND tenant_id = ?
           GROUP BY current_status`,
          [today, tenantId]
        ),
      ]);

      const all   = {};
      const todays = {};
      allStatRows.forEach(r   => { all[r.status]    = Number(r.cnt); });
      todayStatRows.forEach(r => { todays[r.status] = Number(r.cnt); });

      return res.json({
        success: true,
        stats: {
          pending     : all['pending']     || 0,
          assigned    : all['assigned']    || 0,
          inProgress  : all['in_progress'] || 0,
          completed   : all['completed']   || 0,
          cancelled   : all['cancelled']   || 0,
          total       : allStatRows.reduce((s, r) => s + Number(r.cnt), 0),
          todayTotal    : todayStatRows.reduce((s, r) => s + Number(r.cnt), 0),
          todayCompleted: todays['completed']   || 0,
          todayPending  : todays['pending']     || 0,
          todayAssigned : todays['assigned']    || 0,
          todayInProgress: todays['in_progress'] || 0,
        },
      });

    } catch (err) {
      log.error({ err: err }, 'getQuickStats error');
      return res.status(500).json({ success: false, error: err.message });
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // getChartData
  // GET /api/dashboard/chart-data
  //
  // Returns hourly job counts for today, scoped to tenant.
  // Used for the "Jobs Today" bar chart on the dashboard.
  //
  // Returns:
  // {
  //   success: true,
  //   date: "YYYY-MM-DD",
  //   hourly: [{ hour: 0, count: 3 }, { hour: 9, count: 5 }, ...]
  // }
  // ─────────────────────────────────────────────────────────────────────
  static async getChartData(req, res) {
    try {
      const tenantId = req.user.tenant_id;
      const today    = new Date().toISOString().slice(0, 10);

      const [rows] = await db.query(
        `SELECT HOUR(scheduled_time_start) AS hour, COUNT(*) AS count
         FROM jobs
         WHERE scheduled_date = ?
           AND tenant_id = ?
           AND current_status NOT IN ('cancelled')
         GROUP BY HOUR(scheduled_time_start)
         ORDER BY hour ASC`,
        [today, tenantId]
      );

      return res.json({
        success: true,
        date   : today,
        hourly : rows.map(r => ({ hour: Number(r.hour), count: Number(r.count) })),
      });

    } catch (err) {
      log.error({ err }, 'getChartData error');
      return res.status(500).json({ success: false, error: err.message });
    }
  }
}

module.exports = DashboardController;
