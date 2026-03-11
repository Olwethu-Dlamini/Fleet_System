// ============================================
// FILE: src/controllers/dashboardController.js
// PURPOSE: Business logic for the dashboard endpoints.
//
// Called by:
//   GET /api/dashboard/summary  → getDashboardSummary
//   GET /api/dashboard/stats    → getQuickStats
//
// getDashboardSummary — full overview with job lists, vehicle list,
//   recent status changes, and all KPI counts.
//
// getQuickStats — lightweight count-only response, used for
//   notification badges and the sidebar count chips.
// ============================================

const db  = require('../config/database');
const Job = require('../models/Job');

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
      const today = new Date().toISOString().slice(0, 10);

      // Run all queries in parallel for speed
      const [
        [statusRows],
        todayJobs,
        [recentRows],
        [vehicleRows],
        [[{ activeVehicles }]],
      ] = await Promise.all([
        // 1. Job counts per status
        db.query(
          `SELECT current_status AS status, COUNT(*) AS cnt
           FROM jobs
           GROUP BY current_status`
        ),

        // 2. Today's jobs (full job objects with vehicle/technician info)
        Job.getJobsByDate(today),

        // 3. Last 10 status changes across all jobs
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
           JOIN jobs  j ON j.id  = jsc.job_id
           LEFT JOIN users u ON u.id = jsc.changed_by
           ORDER BY jsc.changed_at DESC
           LIMIT 10`
        ),

        // 4. All vehicles with today's assigned job count
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
           WHERE v.is_active = 1
           GROUP BY v.id, v.vehicle_name, v.license_plate, v.vehicle_type, v.is_active
           ORDER BY v.vehicle_name ASC`,
          [today]
        ),

        // 5. Active vehicle count (assigned at least one job today)
        db.query(
          `SELECT COUNT(DISTINCT ja.vehicle_id) AS activeVehicles
           FROM job_assignments ja
           JOIN jobs j ON j.id = ja.job_id
           WHERE j.scheduled_date = ?
             AND j.current_status NOT IN ('completed', 'cancelled')`,
          [today]
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
      console.error('getDashboardSummary error:', err);
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
      const today = new Date().toISOString().slice(0, 10);

      const [[allStatRows], [todayStatRows]] = await Promise.all([
        // All-time counts per status
        db.query(
          `SELECT current_status AS status, COUNT(*) AS cnt
           FROM jobs GROUP BY current_status`
        ),
        // Today's counts per status
        db.query(
          `SELECT current_status AS status, COUNT(*) AS cnt
           FROM jobs
           WHERE scheduled_date = ?
           GROUP BY current_status`,
          [today]
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
      console.error('getQuickStats error:', err);
      return res.status(500).json({ success: false, error: err.message });
    }
  }
}

module.exports = DashboardController;