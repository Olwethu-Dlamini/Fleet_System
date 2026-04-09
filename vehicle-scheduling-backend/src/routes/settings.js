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

/**
 * @swagger
 * /settings:
 *   get:
 *     tags: [Settings]
 *     summary: Get all settings for the tenant
 *     description: Returns all key-value settings for the authenticated user's tenant as a flat object. Requires settings:read permission (admin role).
 *     security:
 *       - ApiKeyAuth: []
 *     responses:
 *       200:
 *         description: Settings retrieved
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 settings:
 *                   type: object
 *                   example:
 *                     scheduler_gps_visible: 'true'
 *                     notifications_enabled: 'true'
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       403:
 *         description: settings:read permission required
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
// ============================================
// GET /api/settings
// Returns all settings for the calling user's tenant
// ============================================
router.get('/', verifyToken, requirePermission('settings:read'), async (req, res) => {
  try {
    const tenant_id = req.user.tenant_id || 1;

    const [rows] = await db.query(
      'SELECT setting_key, setting_value FROM settings WHERE tenant_id = ?',
      [tenant_id],
    );

    const settings = Object.fromEntries(rows.map(r => [r.setting_key, r.setting_value]));
    res.json({ success: true, settings });
  } catch (err) {
    log.error({ err }, 'GET /api/settings error');
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * @swagger
 * /settings/{key}:
 *   get:
 *     tags: [Settings]
 *     summary: Get a single setting by key
 *     description: Returns the value for a single setting key. Requires settings:read permission.
 *     security:
 *       - ApiKeyAuth: []
 *     parameters:
 *       - in: path
 *         name: key
 *         required: true
 *         schema:
 *           type: string
 *         description: Setting key
 *         example: scheduler_gps_visible
 *     responses:
 *       200:
 *         description: Setting value
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 key:
 *                   type: string
 *                   example: scheduler_gps_visible
 *                 value:
 *                   type: string
 *                   example: 'true'
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       403:
 *         description: Insufficient permissions
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       404:
 *         description: Setting not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
// ============================================
// GET /api/settings/:key
// Returns a single setting by key
// ============================================
router.get('/:key', verifyToken, requirePermission('settings:read'), async (req, res) => {
  try {
    const tenant_id = req.user.tenant_id || 1;
    const { key }   = req.params;

    const [rows] = await db.query(
      'SELECT setting_value FROM settings WHERE tenant_id = ? AND setting_key = ?',
      [tenant_id, key],
    );

    if (!rows.length) {
      return res.status(404).json({ success: false, message: `Setting "${key}" not found` });
    }

    res.json({ success: true, key, value: rows[0].setting_value });
  } catch (err) {
    log.error({ err }, 'GET /api/settings/:key error');
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * @swagger
 * /settings/{key}:
 *   put:
 *     tags: [Settings]
 *     summary: Upsert a setting value
 *     description: Creates or updates a setting value by key for the tenant. Requires settings:update permission (admin role).
 *     security:
 *       - ApiKeyAuth: []
 *     parameters:
 *       - in: path
 *         name: key
 *         required: true
 *         schema:
 *           type: string
 *         description: Setting key
 *         example: scheduler_gps_visible
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [value]
 *             properties:
 *               value:
 *                 type: string
 *                 example: 'true'
 *     responses:
 *       200:
 *         description: Setting saved
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 key:
 *                   type: string
 *                   example: scheduler_gps_visible
 *                 value:
 *                   type: string
 *                   example: 'true'
 *       400:
 *         description: Value must be a string
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       403:
 *         description: settings:update permission required
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
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
        'UPDATE settings SET setting_value = ? WHERE tenant_id = ? AND setting_key = ?',
        [value, tenant_id, key],
      );

      if (result.affectedRows === 0) {
        // Key does not exist yet — insert it
        await db.query(
          'INSERT INTO settings (tenant_id, setting_key, setting_value) VALUES (?, ?, ?)',
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
