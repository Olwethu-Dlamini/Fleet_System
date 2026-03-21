// ============================================
// FILE: src/routes/vehicle-maintenance.js
// PURPOSE: Vehicle maintenance scheduling CRUD
//
// Base URL: /api/vehicle-maintenance
// Auth:     verifyToken required on all routes
//
// GET    /api/vehicle-maintenance?vehicle_id=X  — all maintenance for a vehicle
// GET    /api/vehicle-maintenance/active         — vehicles currently in maintenance
// POST   /api/vehicle-maintenance                — create maintenance record
// PUT    /api/vehicle-maintenance/:id            — update maintenance record
// DELETE /api/vehicle-maintenance/:id            — soft-delete (mark completed)
// ============================================

const express  = require('express');
const router   = express.Router();
const db       = require('../config/database');
const logger   = require('../config/logger');
const log      = logger.child({ service: 'vehicle-maintenance-route' });
const { verifyToken, requirePermission } = require('../middleware/authMiddleware');
const { body }    = require('express-validator');
const validate    = require('../middleware/validate');
const { MAINTENANCE_TYPE, MAINTENANCE_STATUS } = require('../config/constants');

// ── Middleware bundles ─────────────────────────────────────────────────────
const requireMaintRead  = [verifyToken, requirePermission('maintenance:read')];
const requireMaintAdmin = [verifyToken, requirePermission('maintenance:create')];

// ============================================
// GET /api/vehicle-maintenance
// Query: vehicle_id (required)
// ============================================
router.get('/', requireMaintRead, async (req, res) => {
  try {
    const vehicle_id = parseInt(req.query.vehicle_id);
    if (!vehicle_id || isNaN(vehicle_id)) {
      return res.status(400).json({ success: false, message: 'vehicle_id query parameter is required' });
    }

    const [rows] = await db.query(
      `SELECT vm.*, v.vehicle_name
       FROM vehicle_maintenance vm
       JOIN vehicles v ON vm.vehicle_id = v.id
       WHERE vm.vehicle_id = ?
       ORDER BY vm.start_date DESC`,
      [vehicle_id],
    );

    res.json({ success: true, maintenance: rows, count: rows.length });
  } catch (err) {
    log.error({ err }, 'GET /api/vehicle-maintenance error');
    res.status(500).json({ success: false, error: err.message });
  }
});

// ============================================
// GET /api/vehicle-maintenance/active
// Returns vehicles currently in maintenance
// ============================================
router.get('/active', requireMaintRead, async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT vm.*, v.vehicle_name
       FROM vehicle_maintenance vm
       JOIN vehicles v ON vm.vehicle_id = v.id
       WHERE vm.status IN ('scheduled','in_progress')
         AND vm.start_date <= CURDATE()
         AND vm.end_date   >= CURDATE()
       ORDER BY vm.end_date ASC`,
    );

    res.json({ success: true, maintenance: rows, count: rows.length });
  } catch (err) {
    log.error({ err }, 'GET /api/vehicle-maintenance/active error');
    res.status(500).json({ success: false, error: err.message });
  }
});

// ============================================
// POST /api/vehicle-maintenance
// Create a new maintenance record
// ============================================
const createMaintenanceValidation = [
  body('vehicle_id')
    .isInt({ min: 1 })
    .withMessage('vehicle_id must be a positive integer'),
  body('maintenance_type')
    .isIn(Object.values(MAINTENANCE_TYPE))
    .withMessage(`maintenance_type must be one of: ${Object.values(MAINTENANCE_TYPE).join(', ')}`),
  body('other_type_desc')
    .optional({ nullable: true })
    .isString().trim().isLength({ max: 200 })
    .withMessage('other_type_desc must be 200 characters or less'),
  body('start_date')
    .isDate()
    .withMessage('start_date must be a valid date (YYYY-MM-DD)'),
  body('end_date')
    .isDate()
    .withMessage('end_date must be a valid date (YYYY-MM-DD)'),
  body('notes')
    .optional({ nullable: true })
    .isString().trim().isLength({ max: 2000 })
    .withMessage('notes must be 2000 characters or less'),
];

router.post('/', requireMaintAdmin, createMaintenanceValidation, validate, async (req, res) => {
  try {
    const {
      vehicle_id, maintenance_type, other_type_desc = null,
      start_date, end_date, notes = null,
    } = req.body;

    // Validate end_date >= start_date
    if (new Date(end_date) < new Date(start_date)) {
      return res.status(400).json({ success: false, message: 'end_date must be on or after start_date' });
    }

    // Check for overlapping active maintenance windows
    const [overlap] = await db.query(
      `SELECT id FROM vehicle_maintenance
       WHERE vehicle_id = ? AND status NOT IN ('completed')
         AND start_date <= ? AND end_date >= ?
       LIMIT 1`,
      [vehicle_id, end_date, start_date],
    );
    if (overlap.length > 0) {
      return res.status(409).json({
        success: false,
        message: 'Vehicle already has a maintenance window overlapping these dates',
      });
    }

    const tenant_id  = req.user.tenant_id || 1;
    const created_by = req.user.id;

    const [result] = await db.query(
      `INSERT INTO vehicle_maintenance
         (tenant_id, vehicle_id, maintenance_type, other_type_desc, status, start_date, end_date, notes, created_by)
       VALUES (?, ?, ?, ?, 'scheduled', ?, ?, ?, ?)`,
      [tenant_id, vehicle_id, maintenance_type, other_type_desc, start_date, end_date, notes, created_by],
    );

    const [rows] = await db.query(
      `SELECT vm.*, v.vehicle_name
       FROM vehicle_maintenance vm
       JOIN vehicles v ON vm.vehicle_id = v.id
       WHERE vm.id = ?`,
      [result.insertId],
    );

    log.info({ id: result.insertId, vehicle_id, maintenance_type }, 'Maintenance record created');
    res.status(201).json({ success: true, maintenance: rows[0] });
  } catch (err) {
    log.error({ err }, 'POST /api/vehicle-maintenance error');
    res.status(500).json({ success: false, error: err.message });
  }
});

// ============================================
// PUT /api/vehicle-maintenance/:id
// Update maintenance record
// ============================================
const updateMaintenanceValidation = [
  body('status')
    .optional()
    .isIn(Object.values(MAINTENANCE_STATUS))
    .withMessage(`status must be one of: ${Object.values(MAINTENANCE_STATUS).join(', ')}`),
  body('maintenance_type')
    .optional()
    .isIn(Object.values(MAINTENANCE_TYPE))
    .withMessage(`maintenance_type must be one of: ${Object.values(MAINTENANCE_TYPE).join(', ')}`),
  body('other_type_desc')
    .optional({ nullable: true })
    .isString().trim().isLength({ max: 200 }),
  body('start_date')
    .optional()
    .isDate()
    .withMessage('start_date must be a valid date'),
  body('end_date')
    .optional()
    .isDate()
    .withMessage('end_date must be a valid date'),
  body('notes')
    .optional({ nullable: true })
    .isString().trim().isLength({ max: 2000 }),
];

router.put('/:id', requireMaintAdmin, updateMaintenanceValidation, validate, async (req, res) => {
  try {
    const id = parseInt(req.params.id);

    // Fetch existing record
    const [existing] = await db.query(
      'SELECT * FROM vehicle_maintenance WHERE id = ?', [id],
    );
    if (!existing.length) {
      return res.status(404).json({ success: false, message: 'Maintenance record not found' });
    }
    const record = existing[0];

    const allowed   = ['status', 'start_date', 'end_date', 'notes', 'maintenance_type', 'other_type_desc'];
    const setClauses = [];
    const values     = [];

    for (const [key, val] of Object.entries(req.body)) {
      if (!allowed.includes(key)) continue;
      setClauses.push(`${key} = ?`);
      values.push(val);
    }

    if (!setClauses.length) {
      return res.status(400).json({ success: false, message: 'No valid fields to update' });
    }

    // If dates are being changed, re-check overlap (excluding this record)
    const newStart = req.body.start_date || record.start_date;
    const newEnd   = req.body.end_date   || record.end_date;

    if (req.body.start_date || req.body.end_date) {
      if (new Date(newEnd) < new Date(newStart)) {
        return res.status(400).json({ success: false, message: 'end_date must be on or after start_date' });
      }

      const [overlap] = await db.query(
        `SELECT id FROM vehicle_maintenance
         WHERE vehicle_id = ? AND id != ? AND status NOT IN ('completed')
           AND start_date <= ? AND end_date >= ?
         LIMIT 1`,
        [record.vehicle_id, id, newEnd, newStart],
      );
      if (overlap.length > 0) {
        return res.status(409).json({
          success: false,
          message: 'Vehicle already has a maintenance window overlapping these dates',
        });
      }
    }

    values.push(id);
    await db.query(
      `UPDATE vehicle_maintenance SET ${setClauses.join(', ')} WHERE id = ?`,
      values,
    );

    const [rows] = await db.query(
      `SELECT vm.*, v.vehicle_name
       FROM vehicle_maintenance vm
       JOIN vehicles v ON vm.vehicle_id = v.id
       WHERE vm.id = ?`,
      [id],
    );

    log.info({ id }, 'Maintenance record updated');
    res.json({ success: true, maintenance: rows[0] });
  } catch (err) {
    log.error({ err }, 'PUT /api/vehicle-maintenance/:id error');
    res.status(500).json({ success: false, error: err.message });
  }
});

// ============================================
// DELETE /api/vehicle-maintenance/:id
// Soft-delete: mark as completed
// ============================================
router.delete('/:id', requireMaintAdmin, async (req, res) => {
  try {
    const id = parseInt(req.params.id);

    const [result] = await db.query(
      `UPDATE vehicle_maintenance SET status = 'completed' WHERE id = ?`,
      [id],
    );

    if (!result.affectedRows) {
      return res.status(404).json({ success: false, message: 'Maintenance record not found' });
    }

    log.info({ id }, 'Maintenance record completed/cancelled');
    res.json({ success: true, message: 'Maintenance record completed/cancelled' });
  } catch (err) {
    log.error({ err }, 'DELETE /api/vehicle-maintenance/:id error');
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
