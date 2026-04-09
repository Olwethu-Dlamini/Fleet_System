// ============================================
// FILE: src/controllers/authController.js
// PURPOSE: Handle login, token refresh, logout, forgot/reset password
//
// CHANGES:
//   - Refresh token support (7d expiry, separate secret)
//   - Token blacklisting on logout
//   - Forgot password + reset password flows
//   - Audit logging on login, logout, password reset
//   - _normaliseRole() no longer maps dispatcher -> scheduler.
//     dispatcher is now a first-class role that passes through unchanged.
//     Only the truly legacy value 'driver' is still mapped -> technician.
// ============================================

const crypto   = require('crypto');
const db       = require('../config/database');
const bcrypt   = require('bcryptjs');
const jwt      = require('jsonwebtoken');
const { USER_ROLE } = require('../config/constants');
const logger   = require('../config/logger').child({ service: 'auth-controller' });

const JWT_SECRET  = process.env.JWT_SECRET;
// Note: startup guard in server.js ensures JWT_SECRET is always set at runtime
const JWT_EXPIRES = process.env.JWT_EXPIRES || '1h';
const REFRESH_SECRET  = JWT_SECRET + '_refresh';
const REFRESH_EXPIRES = '7d';

// ============================================
// Ensure required tables exist (idempotent)
// ============================================
(async () => {
  try {
    await db.query(`
      CREATE TABLE IF NOT EXISTS token_blacklist (
        id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        token_hash VARCHAR(64) NOT NULL,
        expires_at TIMESTAMP NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_token_hash (token_hash),
        INDEX idx_expires (expires_at)
      )
    `);
    await db.query(`
      CREATE TABLE IF NOT EXISTS password_reset_tokens (
        id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        user_id INT UNSIGNED NOT NULL,
        token_hash VARCHAR(64) NOT NULL,
        expires_at TIMESTAMP NOT NULL,
        used TINYINT DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_token_hash (token_hash)
      )
    `);
    logger.info('Auth tables (token_blacklist, password_reset_tokens) ensured');
  } catch (err) {
    logger.error({ err: err.message }, 'Failed to create auth tables');
  }
})();

// ============================================
// Helper: hash a token for storage
// ============================================
function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

// ============================================
// Helper: check if a token hash is blacklisted
// ============================================
async function isBlacklisted(tokenHash) {
  const [rows] = await db.query(
    'SELECT id FROM token_blacklist WHERE token_hash = ? AND expires_at > NOW() LIMIT 1',
    [tokenHash]
  );
  return rows.length > 0;
}

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
   *   "refreshToken": "eyJhbGci...",
   *   "expiresIn": "1h",
   *   "user": {
   *     "id": 2,
   *     "username": "dispatcher_user",
   *     "full_name": "Jane Doe",
   *     "role": "dispatcher",
   *     "email": "jane@company.com",
   *     "permissions": [...]
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

      // -- Find active user --
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

      // -- Validate password --
      const passwordMatch = await bcrypt.compare(password, user.password_hash);
      if (!passwordMatch) {
        return res.status(401).json({
          success: false,
          message: 'Invalid username or password',
        });
      }

      // -- Normalise role --
      const normalisedRole = AuthController._normaliseRole(user.role);

      // -- Build permission list --
      const userPermissions = AuthController._getPermissionsForRole(normalisedRole);

      // -- Generate access token (short-lived) --
      const tokenPayload = {
        id        : user.id,
        username  : user.username,
        role      : normalisedRole,
        email     : user.email,
        tenant_id : user.tenant_id,
      };

      const token = jwt.sign(tokenPayload, JWT_SECRET, { expiresIn: JWT_EXPIRES });

      // -- Generate refresh token (long-lived) --
      const refreshToken = jwt.sign(
        { id: user.id, username: user.username, type: 'refresh' },
        REFRESH_SECRET,
        { expiresIn: REFRESH_EXPIRES }
      );

      // -- Audit log --
      try {
        const auditService = require('../services/auditService');
        await auditService.log(req, 'login', 'user', user.id, { username });
      } catch (_) { /* audit service not critical */ }

      return res.status(200).json({
        success     : true,
        token       : token,
        refreshToken: refreshToken,
        expiresIn   : JWT_EXPIRES,
        user        : {
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
  // POST /api/auth/refresh
  // ==========================================
  /**
   * Request body: { "refreshToken": "eyJhbGci..." }
   *
   * Success response (200):
   * { "success": true, "token": "eyJhbGci...", "expiresIn": "1h" }
   */
  static async refreshToken(req, res) {
    try {
      const { refreshToken } = req.body;

      if (!refreshToken) {
        return res.status(400).json({
          success: false,
          message: 'Refresh token is required',
        });
      }

      // -- Verify refresh token --
      let decoded;
      try {
        decoded = jwt.verify(refreshToken, REFRESH_SECRET);
      } catch (err) {
        return res.status(401).json({
          success: false,
          message: 'Invalid or expired refresh token',
        });
      }

      // -- Check if blacklisted --
      const tokenHash = hashToken(refreshToken);
      if (await isBlacklisted(tokenHash)) {
        return res.status(401).json({
          success: false,
          message: 'Refresh token has been revoked',
        });
      }

      // -- Fetch current user data (role may have changed) --
      const [rows] = await db.query(
        'SELECT id, username, role, email, tenant_id, is_active FROM users WHERE id = ? AND is_active = 1',
        [decoded.id]
      );

      if (rows.length === 0) {
        return res.status(401).json({
          success: false,
          message: 'User not found or inactive',
        });
      }

      const user = rows[0];
      const normalisedRole = AuthController._normaliseRole(user.role);

      // -- Issue new access token --
      const newToken = jwt.sign(
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

      return res.status(200).json({
        success  : true,
        token    : newToken,
        expiresIn: JWT_EXPIRES,
      });

    } catch (error) {
      logger.error({ err: error.message }, 'Refresh token error');
      return res.status(500).json({
        success: false,
        message: 'Token refresh failed',
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
    try {
      // -- Blacklist the access token --
      const authHeader = req.headers['authorization'];
      if (authHeader) {
        const accessToken = authHeader.split(' ')[1];
        if (accessToken) {
          try {
            const decoded = jwt.decode(accessToken);
            const expiresAt = decoded && decoded.exp
              ? new Date(decoded.exp * 1000)
              : new Date(Date.now() + 3600000); // fallback 1h
            await db.query(
              'INSERT INTO token_blacklist (token_hash, expires_at) VALUES (?, ?)',
              [hashToken(accessToken), expiresAt]
            );
          } catch (_) { /* best effort */ }
        }
      }

      // -- Blacklist the refresh token if provided --
      const { refreshToken } = req.body || {};
      if (refreshToken) {
        try {
          const decoded = jwt.decode(refreshToken);
          const expiresAt = decoded && decoded.exp
            ? new Date(decoded.exp * 1000)
            : new Date(Date.now() + 7 * 86400000); // fallback 7d
          await db.query(
            'INSERT INTO token_blacklist (token_hash, expires_at) VALUES (?, ?)',
            [hashToken(refreshToken), expiresAt]
          );
        } catch (_) { /* best effort */ }
      }

      // -- Audit log --
      try {
        const auditService = require('../services/auditService');
        await auditService.log(req, 'logout', 'user', req.user?.id, {});
      } catch (_) { /* audit service not critical */ }

      return res.status(200).json({ success: true, message: 'Logged out successfully' });
    } catch (error) {
      logger.error({ err: error.message }, 'Logout error');
      return res.status(200).json({ success: true, message: 'Logged out successfully' });
    }
  }

  // ==========================================
  // POST /api/auth/forgot-password
  // ==========================================
  /**
   * Request body: { "email": "user@example.com" }
   *
   * Always returns success (don't leak whether email exists).
   */
  static async forgotPassword(req, res) {
    try {
      const { email } = req.body;

      if (!email) {
        return res.status(400).json({
          success: false,
          message: 'Email is required',
        });
      }

      // -- Find user by email --
      const [rows] = await db.query(
        'SELECT id, email, full_name FROM users WHERE email = ? AND is_active = 1',
        [email]
      );

      if (rows.length > 0) {
        const user = rows[0];

        // -- Generate 6-digit reset code --
        const code = String(Math.floor(100000 + Math.random() * 900000));
        const codeHash = crypto.createHash('sha256').update(code).digest('hex');
        const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes

        // -- Invalidate any previous unused tokens for this user --
        await db.query(
          'UPDATE password_reset_tokens SET used = 1 WHERE user_id = ? AND used = 0',
          [user.id]
        );

        // -- Store the hashed code --
        await db.query(
          'INSERT INTO password_reset_tokens (user_id, token_hash, expires_at) VALUES (?, ?, ?)',
          [user.id, codeHash, expiresAt]
        );

        // -- Attempt to send email --
        try {
          const emailService = require('../services/emailService');
          if (emailService.sendPasswordResetEmail) {
            await emailService.sendPasswordResetEmail({
              to: user.email,
              name: user.full_name,
              code: code,
            });
          } else {
            // Use the generic sendJobNotification as fallback with password reset content
            await emailService.sendJobNotification({
              to: user.email,
              subject: 'Password Reset Code - FleetScheduler Pro',
              title: 'Password Reset Request',
              bodyText: `Your password reset code is: <strong>${code}</strong><br><br>This code expires in 15 minutes. If you did not request this, please ignore this email.`,
              jobNumber: 'N/A',
              scheduledTime: `Expires: ${expiresAt.toISOString()}`,
            });
          }
        } catch (emailErr) {
          logger.warn({ err: emailErr.message, email }, 'Failed to send password reset email');
        }

        logger.info({ userId: user.id }, 'Password reset code generated');
      }

      // Always return the same response regardless of whether email was found
      return res.status(200).json({
        success: true,
        message: 'If the email exists, a reset code has been sent',
      });

    } catch (error) {
      logger.error({ err: error.message }, 'Forgot password error');
      return res.status(500).json({
        success: false,
        message: 'Failed to process password reset request',
      });
    }
  }

  // ==========================================
  // POST /api/auth/reset-password
  // ==========================================
  /**
   * Request body: { "email": "user@example.com", "code": "123456", "newPassword": "newpass" }
   */
  static async resetPassword(req, res) {
    try {
      const { email, code, newPassword } = req.body;

      if (!email || !code || !newPassword) {
        return res.status(400).json({
          success: false,
          message: 'Email, code, and new password are required',
        });
      }

      if (newPassword.length < 6) {
        return res.status(400).json({
          success: false,
          message: 'Password must be at least 6 characters',
        });
      }

      // -- Find user by email --
      const [userRows] = await db.query(
        'SELECT id FROM users WHERE email = ? AND is_active = 1',
        [email]
      );

      if (userRows.length === 0) {
        return res.status(400).json({
          success: false,
          message: 'Invalid or expired reset code',
        });
      }

      const userId = userRows[0].id;
      const codeHash = crypto.createHash('sha256').update(code).digest('hex');

      // -- Find valid, unused reset token --
      const [tokenRows] = await db.query(
        'SELECT id FROM password_reset_tokens WHERE user_id = ? AND token_hash = ? AND used = 0 AND expires_at > NOW() LIMIT 1',
        [userId, codeHash]
      );

      if (tokenRows.length === 0) {
        return res.status(400).json({
          success: false,
          message: 'Invalid or expired reset code',
        });
      }

      // -- Hash the new password and update --
      const saltRounds = 10;
      const passwordHash = await bcrypt.hash(newPassword, saltRounds);

      await db.query(
        'UPDATE users SET password_hash = ? WHERE id = ?',
        [passwordHash, userId]
      );

      // -- Mark token as used --
      await db.query(
        'UPDATE password_reset_tokens SET used = 1 WHERE id = ?',
        [tokenRows[0].id]
      );

      // -- Audit log --
      try {
        const auditService = require('../services/auditService');
        await auditService.log(req, 'password_reset', 'user', userId, { email });
      } catch (_) { /* audit service not critical */ }

      logger.info({ userId }, 'Password reset successful');

      return res.status(200).json({
        success: true,
        message: 'Password reset successfully',
      });

    } catch (error) {
      logger.error({ err: error.message }, 'Reset password error');
      return res.status(500).json({
        success: false,
        message: 'Failed to reset password',
      });
    }
  }

  // ==========================================
  // PRIVATE HELPERS
  // ==========================================

  /**
   * Map legacy DB role values to the current role names.
   *
   *   DB value    Normalised role    Note
   *   -----------------------------------------------
   *   admin       -> admin
   *   dispatcher  -> dispatcher       <- NO LONGER mapped to scheduler
   *   scheduler   -> scheduler        kept for any old rows
   *   driver      -> technician       legacy rename
   *   technician  -> technician
   *
   * Any unknown value is returned as-is so future roles
   * don't silently break.
   */
  static _normaliseRole(dbRole) {
    const map = {
      // current roles -- pass through unchanged
      [USER_ROLE.ADMIN]     : USER_ROLE.ADMIN,
      [USER_ROLE.DISPATCHER]: USER_ROLE.DISPATCHER, // <- was incorrectly -> SCHEDULER
      [USER_ROLE.SCHEDULER] : USER_ROLE.SCHEDULER,
      [USER_ROLE.TECHNICIAN]: USER_ROLE.TECHNICIAN,
      // legacy rename only
      driver: USER_ROLE.TECHNICIAN,
    };
    return map[dbRole] ?? dbRole;
  }

  /**
   * Returns all permission keys that a given role holds.
   * Computed from the PERMISSIONS map in constants.js.
   */
  static _getPermissionsForRole(role) {
    const { PERMISSIONS } = require('../config/constants');
    return Object.entries(PERMISSIONS)
      .filter(([, roles]) => roles.includes(role))
      .map(([permission]) => permission);
  }
}

// Export helper for use by authMiddleware
AuthController.isBlacklisted = isBlacklisted;
AuthController.hashToken     = hashToken;

module.exports = AuthController;
