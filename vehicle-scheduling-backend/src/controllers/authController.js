// ============================================
// FILE: src/controllers/authController.js
// PURPOSE: Handle login and token generation
//
// CHANGES:
//   • _normaliseRole() no longer maps dispatcher → scheduler.
//     dispatcher is now a first-class role that passes through unchanged.
//     Only the truly legacy value 'driver' is still mapped → technician.
// ============================================

const db       = require('../config/database');
const bcrypt   = require('bcryptjs');
const jwt      = require('jsonwebtoken');
const { USER_ROLE } = require('../config/constants');
const logger   = require('../config/logger').child({ service: 'auth-controller' });

const JWT_SECRET  = process.env.JWT_SECRET;
// Note: startup guard in server.js ensures JWT_SECRET is always set at runtime
const JWT_EXPIRES = process.env.JWT_EXPIRES || '8h';

class AuthController {

  // ==========================================
  // POST /api/auth/login
  // ==========================================
  /**
   * Request body:
   * {
   *   "username": "dispatcher_user",
   *   "password": "yourpassword"
   * }
   *
   * Success response (200):
   * {
   *   "success": true,
   *   "token": "eyJhbGci...",
   *   "expiresIn": "8h",
   *   "user": {
   *     "id": 2,
   *     "username": "dispatcher_user",
   *     "full_name": "Jane Doe",
   *     "role": "dispatcher",     ← passes through as-is (no longer → "scheduler")
   *     "email": "jane@company.com",
   *     "permissions": [          ← server-computed from PERMISSIONS map
   *       "jobs:read", "jobs:create", "jobs:update", "jobs:updateStatus",
   *       "assignments:read", "assignments:create", "assignments:update", "assignments:delete",
   *       "vehicles:read",
   *       "dashboard:read", "reports:read"
   *     ]
   *   }
   * }
   */
  static async login(req, res) {
    try {
      const { username, password } = req.body;

      if (!username || !password) {
        return res.status(400).json({
          success: false,
          message: 'Username and password are required',
        });
      }

      // ── Find active user ──────────────────
      const [rows] = await db.query(
        'SELECT * FROM users WHERE username = ? AND is_active = 1',
        [username]
      );

      if (rows.length === 0) {
        return res.status(401).json({
          success: false,
          message: 'Invalid username or password',
        });
      }

      const user = rows[0];

      // ── Validate password ─────────────────
      const passwordMatch = await bcrypt.compare(password, user.password_hash);
      if (!passwordMatch) {
        return res.status(401).json({
          success: false,
          message: 'Invalid username or password',
        });
      }

      // ── Normalise role ────────────────────
      const normalisedRole = AuthController._normaliseRole(user.role);

      // ── Generate JWT ──────────────────────
      const token = jwt.sign(
        {
          id        : user.id,
          username  : user.username,
          role      : normalisedRole,
          email     : user.email,
          tenant_id : user.tenant_id,
        },
        JWT_SECRET,
        { expiresIn: JWT_EXPIRES }
      );

      // ── Build permission list for this role ──
      const userPermissions = AuthController._getPermissionsForRole(normalisedRole);

      return res.status(200).json({
        success  : true,
        token    : token,
        expiresIn: JWT_EXPIRES,
        user     : {
          id         : user.id,
          username   : user.username,
          full_name  : user.full_name,
          role       : normalisedRole,
          email      : user.email,
          permissions: userPermissions,
        },
      });

    } catch (error) {
      logger.error({ err: error.message }, 'Login error');
      return res.status(500).json({
        success: false,
        message: 'Login failed. Please try again.',
      });
    }
  }

  // ==========================================
  // GET /api/auth/me
  // ==========================================
  static async getMe(req, res) {
    try {
      const [rows] = await db.query(
        'SELECT id, username, full_name, role, email, is_active, created_at FROM users WHERE id = ?',
        [req.user.id]
      );

      if (rows.length === 0) {
        return res.status(404).json({ success: false, message: 'User not found' });
      }

      const user            = rows[0];
      const normalisedRole  = AuthController._normaliseRole(user.role);
      const userPermissions = AuthController._getPermissionsForRole(normalisedRole);

      return res.status(200).json({
        success: true,
        user   : {
          ...user,
          role       : normalisedRole,
          permissions: userPermissions,
        },
      });

    } catch (error) {
      logger.error({ err: error.message }, 'GetMe error');
      return res.status(500).json({ success: false, message: 'Failed to get user info' });
    }
  }

  // ==========================================
  // POST /api/auth/logout
  // ==========================================
  static async logout(req, res) {
    // JWT is stateless — actual logout is handled client-side
    return res.status(200).json({ success: true, message: 'Logged out successfully' });
  }

  // ==========================================
  // PRIVATE HELPERS
  // ==========================================

  /**
   * Map legacy DB role values to the current role names.
   *
   *   DB value    Normalised role    Note
   *   ──────────────────────────────────────────────────────
   *   admin       → admin
   *   dispatcher  → dispatcher       ← NO LONGER mapped to scheduler
   *   scheduler   → scheduler        kept for any old rows
   *   driver      → technician       legacy rename
   *   technician  → technician
   *
   * Any unknown value is returned as-is so future roles
   * don't silently break.
   */
  static _normaliseRole(dbRole) {
    const map = {
      // current roles — pass through unchanged
      [USER_ROLE.ADMIN]     : USER_ROLE.ADMIN,
      [USER_ROLE.DISPATCHER]: USER_ROLE.DISPATCHER, // ← was incorrectly → SCHEDULER
      [USER_ROLE.SCHEDULER] : USER_ROLE.SCHEDULER,
      [USER_ROLE.TECHNICIAN]: USER_ROLE.TECHNICIAN,
      // legacy rename only
      driver: USER_ROLE.TECHNICIAN,
    };
    return map[dbRole] ?? dbRole;
  }

  /**
   * Returns all permission keys that a given role holds.
   * Computed from the PERMISSIONS map in constants.js — no
   * duplication of permission logic here.
   */
  static _getPermissionsForRole(role) {
    const { PERMISSIONS } = require('../config/constants');
    return Object.entries(PERMISSIONS)
      .filter(([, roles]) => roles.includes(role))
      .map(([permission]) => permission);
  }
}

module.exports = AuthController;