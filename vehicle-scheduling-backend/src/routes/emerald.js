// ============================================
// FILE: src/routes/emerald.js
// PURPOSE: Emerald v6 integration endpoints
//          Sync customers, incidents, and proxy search
// ============================================

const express = require('express');
const router  = express.Router();

const { verifyToken, requireRole } = require('../middleware/authMiddleware');
const EmeraldService               = require('../services/emeraldService');
const db                           = require('../config/database');
const logger                       = require('../config/logger').child({ service: 'emerald-routes' });

// ============================================
// DB MIGRATION: emerald_sync_log table
// Idempotent — safe to run on every startup
// ============================================
async function ensureTables() {
  try {
    await db.query(`
      CREATE TABLE IF NOT EXISTS emerald_sync_log (
        id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        sync_type       VARCHAR(50) NOT NULL,
        records_synced  INT DEFAULT 0,
        status          ENUM('success','failed') DEFAULT 'success',
        error_message   TEXT,
        synced_by       INT UNSIGNED,
        tenant_id       INT UNSIGNED DEFAULT 1,
        created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    logger.info('emerald_sync_log table ensured');
  } catch (err) {
    logger.error({ err: err.message }, 'Failed to create emerald_sync_log table');
  }
}
ensureTables();

// ============================================
// Helper: log sync result
// ============================================
async function logSync(syncType, recordsSynced, status, errorMessage, syncedBy, tenantId) {
  try {
    await db.query(
      `INSERT INTO emerald_sync_log (sync_type, records_synced, status, error_message, synced_by, tenant_id)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [syncType, recordsSynced, status, errorMessage, syncedBy, tenantId]
    );
  } catch (err) {
    logger.error({ err: err.message }, 'Failed to write emerald_sync_log');
  }
}

// ============================================
// Helper: check if Emerald sync is enabled
// ============================================
function isSyncEnabled() {
  return process.env.EMERALD_SYNC_ENABLED === 'true';
}

// ============================================
// GET /api/emerald/status
// Test connection to Emerald API
// Admin only
// ============================================

/**
 * @swagger
 * /emerald/status:
 *   get:
 *     tags: [Emerald]
 *     summary: Test Emerald API connection
 *     description: Checks if the backend can reach and authenticate with the Emerald v6 API. Admin only.
 *     security:
 *       - ApiKeyAuth: []
 *     responses:
 *       200:
 *         description: Connection status
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 connected:
 *                   type: boolean
 *                 sync_enabled:
 *                   type: boolean
 *                 message:
 *                   type: string
 *       401:
 *         description: Not authenticated
 *       403:
 *         description: Admin role required
 */
router.get('/status', verifyToken, requireRole('admin'), async (req, res) => {
  try {
    const result = await EmeraldService.testConnection();
    return res.status(200).json({
      success     : true,
      connected   : result.connected,
      sync_enabled: isSyncEnabled(),
      message     : result.message,
    });
  } catch (err) {
    logger.error({ err: err.message }, 'GET /emerald/status error');
    return res.status(500).json({ success: false, message: 'Failed to check Emerald status' });
  }
});

// ============================================
// POST /api/emerald/sync/customers
// Pull customers from Emerald, upsert into local jobs customer fields
// Admin only
// ============================================

/**
 * @swagger
 * /emerald/sync/customers:
 *   post:
 *     tags: [Emerald]
 *     summary: Sync customers from Emerald
 *     description: Pulls customer data from Emerald v6 and upserts customer info into local jobs table. Admin only.
 *     security:
 *       - ApiKeyAuth: []
 *     responses:
 *       200:
 *         description: Sync complete
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 synced:
 *                   type: integer
 *                 message:
 *                   type: string
 *       400:
 *         description: Sync not enabled
 *       401:
 *         description: Not authenticated
 *       403:
 *         description: Admin role required
 *       500:
 *         description: Sync failed
 */
router.post('/sync/customers', verifyToken, requireRole('admin'), async (req, res) => {
  if (!isSyncEnabled()) {
    return res.status(400).json({
      success: false,
      message: 'Emerald sync is disabled. Set EMERALD_SYNC_ENABLED=true to enable.',
    });
  }

  try {
    const data = await EmeraldService.getCustomers({ limit: 1000 });

    // Emerald returns customers in a data array (adapt field names as needed)
    const customers = data.data || data.customers || [];
    let syncedCount = 0;

    for (const customer of customers) {
      const name    = customer.name || customer.customer_name || '';
      const phone   = customer.phone || customer.contact_phone || '';
      const address = customer.address || customer.street_address || '';

      if (!name) continue;

      // Upsert: update jobs that match this customer name with latest phone/address
      const [result] = await db.query(
        `UPDATE jobs
         SET customer_phone   = COALESCE(NULLIF(?, ''), customer_phone),
             customer_address = COALESCE(NULLIF(?, ''), customer_address)
         WHERE customer_name = ? AND tenant_id = ?`,
        [phone, address, name, req.user.tenant_id]
      );

      if (result.affectedRows > 0) {
        syncedCount += result.affectedRows;
      }
    }

    await logSync('customers', syncedCount, 'success', null, req.user.id, req.user.tenant_id);

    return res.status(200).json({
      success: true,
      synced : syncedCount,
      message: `Synced ${syncedCount} customer record(s) from Emerald`,
    });
  } catch (err) {
    logger.error({ err: err.message }, 'POST /emerald/sync/customers error');
    await logSync('customers', 0, 'failed', err.message, req.user.id, req.user.tenant_id);
    return res.status(500).json({ success: false, message: `Customer sync failed: ${err.message}` });
  }
});

// ============================================
// POST /api/emerald/sync/incidents
// Pull incidents from Emerald, create as jobs
// Admin only
// ============================================

/**
 * @swagger
 * /emerald/sync/incidents:
 *   post:
 *     tags: [Emerald]
 *     summary: Sync incidents from Emerald as jobs
 *     description: Pulls incident/work order data from Emerald v6 and creates them as new jobs in the local system. Admin only.
 *     security:
 *       - ApiKeyAuth: []
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               date_from:
 *                 type: string
 *                 description: Filter incidents from this date (YYYY-MM-DD)
 *               date_to:
 *                 type: string
 *                 description: Filter incidents to this date (YYYY-MM-DD)
 *     responses:
 *       200:
 *         description: Sync complete
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 created:
 *                   type: integer
 *                 skipped:
 *                   type: integer
 *                 message:
 *                   type: string
 *       400:
 *         description: Sync not enabled
 *       401:
 *         description: Not authenticated
 *       403:
 *         description: Admin role required
 *       500:
 *         description: Sync failed
 */
router.post('/sync/incidents', verifyToken, requireRole('admin'), async (req, res) => {
  if (!isSyncEnabled()) {
    return res.status(400).json({
      success: false,
      message: 'Emerald sync is disabled. Set EMERALD_SYNC_ENABLED=true to enable.',
    });
  }

  try {
    const filters = {};
    if (req.body.date_from) filters.date_from = req.body.date_from;
    if (req.body.date_to)   filters.date_to   = req.body.date_to;

    const data = await EmeraldService.getIncidents(filters);

    const incidents = data.data || data.incidents || [];
    let createdCount = 0;
    let skippedCount = 0;

    for (const incident of incidents) {
      const emeraldRef = incident.id || incident.incident_id || incident.reference;

      // Skip if already imported (check job_number for emerald reference)
      if (emeraldRef) {
        const jobRef = `EMR-${emeraldRef}`;
        const [existing] = await db.query(
          'SELECT id FROM jobs WHERE job_number = ? AND tenant_id = ?',
          [jobRef, req.user.tenant_id]
        );
        if (existing.length > 0) {
          skippedCount++;
          continue;
        }
      }

      const customerName  = incident.customer_name || incident.name || 'Unknown Customer';
      const phone         = incident.customer_phone || incident.phone || null;
      const address       = incident.address || incident.customer_address || '';
      const description   = incident.description || incident.notes || incident.subject || '';
      const priority      = incident.priority || 'normal';
      const scheduledDate = incident.scheduled_date || incident.date || new Date().toISOString().slice(0, 10);
      const jobType       = incident.job_type || incident.type || 'installation';
      const jobNumber     = emeraldRef ? `EMR-${emeraldRef}` : `EMR-${Date.now()}`;

      // Time fields — use incident values or sensible defaults
      const timeStart     = incident.scheduled_time_start || incident.time_start || '08:00:00';
      const timeEnd       = incident.scheduled_time_end   || incident.time_end   || '09:00:00';
      const duration      = incident.estimated_duration_minutes || incident.duration || 60;

      await db.query(
        `INSERT INTO jobs (
          job_number, job_type, customer_name, customer_phone, customer_address,
          description, priority, scheduled_date, scheduled_time_start, scheduled_time_end,
          estimated_duration_minutes, current_status, created_by, tenant_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          jobNumber,
          jobType,
          customerName,
          phone,
          address,
          description,
          priority,
          scheduledDate,
          timeStart,
          timeEnd,
          duration,
          'pending',
          req.user.id,
          req.user.tenant_id,
        ]
      );

      createdCount++;
    }

    await logSync('incidents', createdCount, 'success', null, req.user.id, req.user.tenant_id);

    return res.status(200).json({
      success: true,
      created: createdCount,
      skipped: skippedCount,
      message: `Created ${createdCount} job(s) from Emerald incidents (${skippedCount} skipped as duplicates)`,
    });
  } catch (err) {
    logger.error({ err: err.message }, 'POST /emerald/sync/incidents error');
    await logSync('incidents', 0, 'failed', err.message, req.user.id, req.user.tenant_id);
    return res.status(500).json({ success: false, message: `Incident sync failed: ${err.message}` });
  }
});

// ============================================
// GET /api/emerald/customers
// Proxy search of Emerald customers (for typeahead)
// Admin only
// ============================================

/**
 * @swagger
 * /emerald/customers:
 *   get:
 *     tags: [Emerald]
 *     summary: Search Emerald customers (proxy)
 *     description: Proxies a customer search to the Emerald v6 API for typeahead/autocomplete use. Admin only.
 *     security:
 *       - ApiKeyAuth: []
 *     parameters:
 *       - in: query
 *         name: search
 *         schema:
 *           type: string
 *         description: Search term for customer name/account
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 20
 *         description: Max results to return
 *     responses:
 *       200:
 *         description: Customer search results
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 customers:
 *                   type: array
 *                   items:
 *                     type: object
 *       401:
 *         description: Not authenticated
 *       403:
 *         description: Admin role required
 *       500:
 *         description: Search failed
 */
router.get('/customers', verifyToken, requireRole('admin'), async (req, res) => {
  try {
    const { search, limit } = req.query;

    const filters = {};
    if (search) filters.search = search;
    filters.limit = limit ? parseInt(limit, 10) : 20;

    const data = await EmeraldService.getCustomers(filters);

    const customers = data.data || data.customers || [];

    return res.status(200).json({
      success  : true,
      customers: customers,
    });
  } catch (err) {
    logger.error({ err: err.message }, 'GET /emerald/customers error');
    return res.status(500).json({ success: false, message: `Customer search failed: ${err.message}` });
  }
});

// ============================================
// GET /api/emerald/jobs
// Return all Emerald-sourced jobs (job_number LIKE 'EMR-%')
// Admin only
// ============================================

/**
 * @swagger
 * /emerald/jobs:
 *   get:
 *     tags: [Emerald]
 *     summary: List all Emerald-sourced jobs
 *     description: Returns all jobs that were created via Emerald sync (job_number starts with EMR-). Admin only.
 *     security:
 *       - ApiKeyAuth: []
 *     parameters:
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *         description: Filter by job status (pending, assigned, in_progress, completed, cancelled)
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           default: 1
 *         description: Page number
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 50
 *         description: Results per page
 *     responses:
 *       200:
 *         description: Emerald jobs list
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 jobs:
 *                   type: array
 *                   items:
 *                     type: object
 *                 total:
 *                   type: integer
 *                 page:
 *                   type: integer
 *                 limit:
 *                   type: integer
 *       401:
 *         description: Not authenticated
 *       403:
 *         description: Admin role required
 *       500:
 *         description: Query failed
 */
router.get('/jobs', verifyToken, requireRole('admin'), async (req, res) => {
  try {
    const page  = Math.max(1, parseInt(req.query.page, 10) || 1);
    const limit = Math.min(200, Math.max(1, parseInt(req.query.limit, 10) || 50));
    const offset = (page - 1) * limit;

    let whereClause = `WHERE j.job_number LIKE 'EMR-%' AND j.tenant_id = ?`;
    const params = [req.user.tenant_id];

    if (req.query.status) {
      whereClause += ' AND j.current_status = ?';
      params.push(req.query.status);
    }

    // Count total
    const [countRows] = await db.query(
      `SELECT COUNT(*) AS total FROM jobs j ${whereClause}`,
      params
    );
    const total = countRows[0].total;

    // Fetch page
    const [jobs] = await db.query(
      `SELECT j.*, v.vehicle_name, v.license_plate
       FROM jobs j
       LEFT JOIN vehicles v ON j.vehicle_id = v.id
       ${whereClause}
       ORDER BY j.scheduled_date DESC, j.scheduled_time_start DESC
       LIMIT ? OFFSET ?`,
      [...params, limit, offset]
    );

    return res.status(200).json({
      success: true,
      jobs,
      total,
      page,
      limit,
    });
  } catch (err) {
    logger.error({ err: err.message }, 'GET /emerald/jobs error');
    return res.status(500).json({ success: false, message: `Failed to fetch Emerald jobs: ${err.message}` });
  }
});

module.exports = router;
