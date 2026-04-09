// ============================================
// FILE: src/routes/audit.js
// PURPOSE: Audit log API endpoints (admin only)
// ============================================

const express = require('express');
const router  = express.Router();
const db      = require('../config/database');
const { verifyToken, adminOnly } = require('../middleware/authMiddleware');

/**
 * @swagger
 * /audit:
 *   get:
 *     tags: [Audit]
 *     summary: Get paginated audit logs
 *     description: Returns audit log entries. Admin only. Supports filtering by action, entity_type, user_id, and date range.
 *     security:
 *       - ApiKeyAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           default: 1
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 50
 *       - in: query
 *         name: action
 *         schema:
 *           type: string
 *         description: Filter by action (e.g. login, logout, password_reset)
 *       - in: query
 *         name: entity_type
 *         schema:
 *           type: string
 *         description: Filter by entity type (e.g. user, job)
 *       - in: query
 *         name: user_id
 *         schema:
 *           type: integer
 *         description: Filter by user ID
 *       - in: query
 *         name: from
 *         schema:
 *           type: string
 *           format: date-time
 *         description: Start date (ISO 8601)
 *       - in: query
 *         name: to
 *         schema:
 *           type: string
 *           format: date-time
 *         description: End date (ISO 8601)
 *     responses:
 *       200:
 *         description: Paginated audit logs
 *       401:
 *         description: Not authenticated
 *       403:
 *         description: Not authorized (admin only)
 */
router.get('/', verifyToken, adminOnly, async (req, res) => {
  try {
    const page  = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(200, Math.max(1, parseInt(req.query.limit) || 50));
    const offset = (page - 1) * limit;

    const conditions = [];
    const params     = [];

    // -- Optional filters --
    if (req.query.action) {
      conditions.push('action = ?');
      params.push(req.query.action);
    }

    if (req.query.entity_type) {
      conditions.push('entity_type = ?');
      params.push(req.query.entity_type);
    }

    if (req.query.user_id) {
      conditions.push('user_id = ?');
      params.push(parseInt(req.query.user_id));
    }

    if (req.query.from) {
      conditions.push('created_at >= ?');
      params.push(req.query.from);
    }

    if (req.query.to) {
      conditions.push('created_at <= ?');
      params.push(req.query.to);
    }

    // -- Tenant scoping --
    conditions.push('tenant_id = ?');
    params.push(req.user.tenant_id || 1);

    const whereClause = conditions.length > 0
      ? 'WHERE ' + conditions.join(' AND ')
      : '';

    // -- Count total --
    const [countRows] = await db.query(
      `SELECT COUNT(*) as total FROM audit_logs ${whereClause}`,
      params
    );
    const total = countRows[0].total;

    // -- Fetch page --
    const [rows] = await db.query(
      `SELECT * FROM audit_logs ${whereClause} ORDER BY created_at DESC LIMIT ? OFFSET ?`,
      [...params, limit, offset]
    );

    return res.status(200).json({
      success: true,
      data: rows,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    });

  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Failed to retrieve audit logs',
    });
  }
});

module.exports = router;
