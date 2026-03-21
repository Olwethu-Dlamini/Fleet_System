// ============================================
// FILE: src/routes/settings.js
// PURPOSE: Key-value settings store for admin toggles
//
// Base URL: /api/settings
// Auth:     admin only (settings:read / settings:update)
//
// GET /api/settings       — all settings for tenant
// GET /api/settings/:key  — single setting by key
// PUT /api/settings/:key  — upsert a setting value
// ============================================

const express  = require('express');
const router   = express.Router();
const db       = require('../config/database');
const logger   = require('../config/logger');
const log      = logger.child({ service: 'settings-route' });
const { verifyToken, requirePermission } = require('../middleware/authMiddleware');
const { body }  = require('express-validator');
const validate  = require('../middleware/validate');

// ============================================
// GET /api/settings
// Returns all settings for the calling user's tenant
// ============================================
router.get('/', verifyToken, requirePermission('settings:read'), async (req, res) => {
  try {
    const tenant_id = req.user.tenant_id || 1;

    const [rows] = await db.query(
      'SELECT setting_key, setting_val FROM settings WHERE tenant_id = ?',
      [tenant_id],
    );

    const settings = Object.fromEntries(rows.map(r => [r.setting_key, r.setting_val]));
    res.json({ success: true, settings });
  } catch (err) {
    log.error({ err }, 'GET /api/settings error');
    res.status(500).json({ success: false, error: err.message });
  }
});

// ============================================
// GET /api/settings/:key
// Returns a single setting by key
// ============================================
router.get('/:key', verifyToken, requirePermission('settings:read'), async (req, res) => {
  try {
    const tenant_id = req.user.tenant_id || 1;
    const { key }   = req.params;

    const [rows] = await db.query(
      'SELECT setting_val FROM settings WHERE tenant_id = ? AND setting_key = ?',
      [tenant_id, key],
    );

    if (!rows.length) {
      return res.status(404).json({ success: false, message: `Setting "${key}" not found` });
    }

    res.json({ success: true, key, value: rows[0].setting_val });
  } catch (err) {
    log.error({ err }, 'GET /api/settings/:key error');
    res.status(500).json({ success: false, error: err.message });
  }
});

// ============================================
// PUT /api/settings/:key
// Upsert a setting value
// Body: { value: string }
// ============================================
router.put('/:key',
  verifyToken,
  requirePermission('settings:update'),
  body('value').isString().withMessage('value must be a string'),
  validate,
  async (req, res) => {
    try {
      const tenant_id = req.user.tenant_id || 1;
      const { key }   = req.params;
      const { value } = req.body;

      const [result] = await db.query(
        'UPDATE settings SET setting_val = ? WHERE tenant_id = ? AND setting_key = ?',
        [value, tenant_id, key],
      );

      if (result.affectedRows === 0) {
        // Key does not exist yet — insert it
        await db.query(
          'INSERT INTO settings (tenant_id, setting_key, setting_val) VALUES (?, ?, ?)',
          [tenant_id, key, value],
        );
      }

      log.info({ key, value }, 'Setting updated');
      res.json({ success: true, key, value });
    } catch (err) {
      log.error({ err }, 'PUT /api/settings/:key error');
      res.status(500).json({ success: false, error: err.message });
    }
  },
);

module.exports = router;
