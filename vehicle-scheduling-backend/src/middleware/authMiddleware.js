// ============================================
// FILE: src/middleware/authMiddleware.js
// PURPOSE: Protect routes — verify JWT + check roles/permissions
// ============================================

const jwt                    = require('jsonwebtoken');
const { USER_ROLE, PERMISSIONS } = require('../config/constants');

const JWT_SECRET = process.env.JWT_SECRET;
// Note: startup guard in server.js ensures JWT_SECRET is always set at runtime

// ============================================
// VERIFY TOKEN
// Attaches decoded user to req.user, then calls next().
// Returns 401 if token is missing, invalid, or expired.
// ============================================
/**
 * Usage:
 *   router.get('/protected', verifyToken, controller.method);
 */
const verifyToken = (req, res, next) => {
  try {
    const authHeader = req.headers['authorization'];

    if (!authHeader) {
      return res.status(401).json({
        success: false,
        message: 'No authorization token provided',
      });
    }

    const token = authHeader.split(' ')[1];

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Token format invalid. Use: Bearer <token>',
      });
    }

    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    next();

  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        message: 'Session expired. Please log in again.',
      });
    }
    return res.status(401).json({
      success: false,
      message: 'Invalid token. Please log in again.',
    });
  }
};

// ============================================
// REQUIRE ROLE
// Restricts a route to one or more specific roles.
// Must be used AFTER verifyToken.
// ============================================
/**
 * Usage:
 *   router.delete('/jobs/:id', verifyToken, requireRole('admin'), controller.delete);
 *   router.post('/jobs',       verifyToken, requireRole('admin', 'scheduler'), controller.create);
 */
const requireRole = (...allowedRoles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Not authenticated' });
    }

    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: `Access denied. Required role: ${allowedRoles.join(' or ')}`,
      });
    }

    next();
  };
};

// ============================================
// REQUIRE PERMISSION
// Fine-grained permission check using the
// PERMISSIONS map in constants.js.
// Must be used AFTER verifyToken.
// ============================================
/**
 * Permissions are defined in constants.js → PERMISSIONS object.
 *
 * Usage:
 *   router.get('/vehicles',    verifyToken, requirePermission('vehicles:read'),   controller.list);
 *   router.post('/vehicles',   verifyToken, requirePermission('vehicles:create'), controller.create);
 *   router.delete('/vehicles/:id', verifyToken, requirePermission('vehicles:delete'), controller.delete);
 *
 * Role → permission matrix (defined in constants.js):
 *
 *   Permission            admin  scheduler  technician
 *   ─────────────────────────────────────────────────
 *   jobs:read               ✓       ✓          ✓
 *   jobs:create             ✓       ✓          ✗
 *   jobs:update             ✓       ✓          ✗
 *   jobs:delete             ✓       ✗          ✗
 *   jobs:updateStatus       ✓       ✓          ✓
 *   assignments:read        ✓       ✓          ✓
 *   assignments:create      ✓       ✓          ✗
 *   assignments:update      ✓       ✓          ✗
 *   assignments:delete      ✓       ✓          ✗
 *   vehicles:read           ✓       ✓          ✓
 *   vehicles:create         ✓       ✗          ✗
 *   vehicles:update         ✓       ✗          ✗
 *   vehicles:delete         ✓       ✗          ✗
 *   dashboard:read          ✓       ✓          ✓
 *   reports:read            ✓       ✓          ✗
 *   users:read              ✓       ✗          ✗
 *   users:create            ✓       ✗          ✗
 *   users:update            ✓       ✗          ✗
 *   users:delete            ✓       ✗          ✗
 */
const requirePermission = (permission) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Not authenticated' });
    }

    const allowedRoles = PERMISSIONS[permission];

    if (!allowedRoles) {
      // Unknown permission key — fail safe (deny access)
      console.warn(`⚠️  Unknown permission key: "${permission}"`);
      return res.status(403).json({
        success: false,
        message: 'Permission not defined. Access denied.',
      });
    }

    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: `Access denied. You do not have the "${permission}" permission.`,
        yourRole: req.user.role,
        requiredOneOf: allowedRoles,
      });
    }

    next();
  };
};

// ============================================
// ROLE CONVENIENCE SHORTCUTS
// Sugar helpers for common single-role guards.
// ============================================
const adminOnly      = requireRole(USER_ROLE.ADMIN);
const schedulerOrAbove = requireRole(USER_ROLE.ADMIN, USER_ROLE.SCHEDULER);

module.exports = {
  verifyToken,
  requireRole,
  requirePermission,
  adminOnly,
  schedulerOrAbove,
};