// ============================================
// FILE: src/routes/users.js
// PURPOSE: User management endpoints
//
// Base URL: /api/users
// Auth:     Applied globally in server.js (JWT required for all /api/* routes)
//
// GET  /api/users              — admin + scheduler (list / filter)
// GET  /api/users/:id          — admin + scheduler
// POST /api/users              — admin only (create user)
// PUT  /api/users/:id          — admin only (update user)
// DELETE /api/users/:id        — admin only (deactivate, never hard-delete)
// POST /api/users/:id/reset-password — admin only
// ============================================

const express = require('express');
const router  = express.Router();
const db      = require('../config/database');
const bcrypt  = require('bcryptjs');

// Use shared middleware so role checks use the same USER_ROLE constants as JWT
const { verifyToken, adminOnly, schedulerOrAbove } = require('../middleware/authMiddleware');
const { body }  = require('express-validator');
const validate  = require('../middleware/validate');

// verifyToken must run first to populate req.user, then the role guard.
// We wrap both into single middleware arrays so each route is self-contained
// and works regardless of whether server.js applies a global auth middleware.
const requireAdmin            = [verifyToken, adminOnly];
const requireAdminOrScheduler = [verifyToken, schedulerOrAbove];

// ============================================
// Validation schemas — FOUND-06
// ============================================
const createUserValidation = [
  body('username')
    .isString().trim().isLength({ min: 3, max: 50 })
    .withMessage('username must be 3-50 characters'),
  body('email')
    .isEmail().normalizeEmail()
    .withMessage('email must be a valid email address'),
  body('password')
    .isLength({ min: 8 })
    .withMessage('password must be at least 8 characters'),
  body('role')
    .isIn(['admin', 'scheduler', 'technician', 'dispatcher', 'driver'])
    .withMessage('role must be admin, scheduler, technician, dispatcher, or driver'),
  body('full_name')
    .optional().isString().trim().isLength({ max: 100 })
    .withMessage('full_name must be 100 characters or less'),
];

const updateUserValidation = [
  body('email')
    .optional().isEmail().normalizeEmail()
    .withMessage('email must be a valid email address'),
  body('role')
    .optional().isIn(['admin', 'scheduler', 'technician', 'dispatcher', 'driver'])
    .withMessage('role must be admin, scheduler, technician, dispatcher, or driver'),
  body('full_name')
    .optional().isString().trim().isLength({ max: 100 })
    .withMessage('full_name must be 100 characters or less'),
];

// ── Role normalisation maps ──────────────────────────────────────────────────
const TO_DB_ROLE   = { scheduler: 'dispatcher', technician: 'driver' };
const FROM_DB_ROLE = { dispatcher: 'scheduler', driver: 'technician' };

const toDbRole      = r => TO_DB_ROLE[r]   ?? r;
const fromDbRole    = r => FROM_DB_ROLE[r] ?? r;
const normaliseUser = u => ({ ...u, role: fromDbRole(u.role) });

// ============================================================
// GET /api/users
// Query: role (optional), active ('1'|'0'|'all', default '1')
// ============================================================
router.get('/', requireAdminOrScheduler, async (req, res) => {
  try {
    const { role, active = '1' } = req.query;

    const conditions = [];
    const params     = [];

    if (role) {
      conditions.push('role = ?');
      params.push(toDbRole(role));
    }

    if (active !== 'all') {
      conditions.push('is_active = ?');
      params.push(active === '0' ? 0 : 1);
    }

    const where = conditions.length ? 'WHERE ' + conditions.join(' AND ') : '';

    const [rows] = await db.query(
      `SELECT id, username, full_name, role, email, is_active, created_at
       FROM users ${where} ORDER BY full_name ASC`,
      params,
    );

    res.json({ success: true, users: rows.map(normaliseUser), count: rows.length });
  } catch (err) {
    console.error('GET /api/users error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ============================================================
// GET /api/users/:id
// ============================================================
router.get('/:id', requireAdminOrScheduler, async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT id, username, full_name, role, email, is_active, created_at
       FROM users WHERE id = ?`,
      [parseInt(req.params.id)],
    );

    if (!rows.length) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }

    res.json({ success: true, user: normaliseUser(rows[0]) });
  } catch (err) {
    console.error('GET /api/users/:id error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ============================================================
// POST /api/users  —  create user  (admin only)
// Body: { username, full_name, email, password, role, is_active? }
// role accepts app values ('scheduler','technician') or DB values
// ============================================================
router.post('/', requireAdmin, createUserValidation, validate, async (req, res) => {
  try {
    const { username, full_name, email, password, role, is_active = 1 } = req.body;

    // Validate required fields
    const missing = ['username','full_name','email','password','role']
      .filter(f => !req.body[f]);
    if (missing.length) {
      return res.status(400).json({
        success: false,
        message: `Missing required fields: ${missing.join(', ')}`,
      });
    }

    // Map role to DB value
    const dbRole = toDbRole(role);
    const validDbRoles = ['admin', 'dispatcher', 'driver'];
    if (!validDbRoles.includes(dbRole)) {
      return res.status(400).json({
        success: false,
        message: `Invalid role. Accepted: admin, scheduler, technician`,
      });
    }

    // Hash password
    const password_hash = await bcrypt.hash(password, 10);

    const [result] = await db.query(
      `INSERT INTO users (username, full_name, email, password_hash, role, is_active)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [username.trim(), full_name.trim(), email.trim().toLowerCase(),
       password_hash, dbRole, is_active ? 1 : 0],
    );

    const [rows] = await db.query(
      `SELECT id, username, full_name, role, email, is_active, created_at
       FROM users WHERE id = ?`,
      [result.insertId],
    );

    res.status(201).json({
      success: true,
      user:    normaliseUser(rows[0]),
      message: 'User created successfully',
    });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      const field = err.message.includes('username') ? 'username' : 'email';
      return res.status(409).json({
        success: false,
        message: `A user with this ${field} already exists`,
      });
    }
    console.error('POST /api/users error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ============================================================
// PUT /api/users/:id  —  update user  (admin only)
// Body: any subset of { username, full_name, email, role, is_active }
// password is NOT updated here — use /reset-password
// ============================================================
router.put('/:id', requireAdmin, updateUserValidation, validate, async (req, res) => {
  try {
    const id = parseInt(req.params.id);

    // Prevent admin from accidentally locking themselves out
    if (id === req.user.id && req.body.is_active === 0) {
      return res.status(400).json({
        success: false,
        message: 'You cannot deactivate your own account',
      });
    }

    const allowed = ['username', 'full_name', 'email', 'role', 'is_active'];
    const setClauses = [];
    const values     = [];

    for (const [key, val] of Object.entries(req.body)) {
      if (!allowed.includes(key)) continue;
      const dbVal = key === 'role' ? toDbRole(val) : val;

      if (key === 'role') {
        const validDbRoles = ['admin', 'dispatcher', 'driver'];
        if (!validDbRoles.includes(dbVal)) {
          return res.status(400).json({
            success: false,
            message: 'Invalid role. Accepted: admin, scheduler, technician',
          });
        }
      }

      setClauses.push(`${key} = ?`);
      values.push(dbVal);
    }

    if (!setClauses.length) {
      return res.status(400).json({ success: false, message: 'No valid fields to update' });
    }

    values.push(id);
    const [result] = await db.query(
      `UPDATE users SET ${setClauses.join(', ')} WHERE id = ?`,
      values,
    );

    if (!result.affectedRows) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    const [rows] = await db.query(
      `SELECT id, username, full_name, role, email, is_active, created_at
       FROM users WHERE id = ?`,
      [id],
    );

    res.json({ success: true, user: normaliseUser(rows[0]), message: 'User updated' });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      const field = err.message.includes('username') ? 'username' : 'email';
      return res.status(409).json({
        success: false,
        message: `A user with this ${field} already exists`,
      });
    }
    console.error('PUT /api/users/:id error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ============================================================
// DELETE /api/users/:id  —  deactivate  (admin only)
// We never hard-delete users — too many FK references.
// ============================================================
router.delete('/:id', requireAdmin, async (req, res) => {
  try {
    const id = parseInt(req.params.id);

    if (id === req.user.id) {
      return res.status(400).json({
        success: false,
        message: 'You cannot deactivate your own account',
      });
    }

    const [result] = await db.query(
      'UPDATE users SET is_active = 0 WHERE id = ?',
      [id],
    );

    if (!result.affectedRows) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    res.json({ success: true, message: 'User deactivated successfully' });
  } catch (err) {
    console.error('DELETE /api/users/:id error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ============================================================
// POST /api/users/:id/reset-password  (admin only)
// Body: { new_password }
// ============================================================
router.post('/:id/reset-password', requireAdmin, async (req, res) => {
  try {
    const { new_password } = req.body;

    if (!new_password || new_password.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters',
      });
    }

    const hash = await bcrypt.hash(new_password, 10);

    const [result] = await db.query(
      'UPDATE users SET password_hash = ? WHERE id = ?',
      [hash, parseInt(req.params.id)],
    );

    if (!result.affectedRows) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    res.json({ success: true, message: 'Password reset successfully' });
  } catch (err) {
    console.error('POST /api/users/:id/reset-password error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;