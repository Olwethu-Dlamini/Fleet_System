// ============================================
// FILE: src/services/auditService.js
// PURPOSE: Structured audit logging for security-sensitive actions
// ============================================

const db = require('../config/database');
const logger = require('../config/logger').child({ service: 'auditService' });

// Ensure audit_logs table exists (idempotent)
(async () => {
  try {
    await db.query(`
      CREATE TABLE IF NOT EXISTS audit_logs (
        id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        user_id INT UNSIGNED,
        username VARCHAR(100),
        action VARCHAR(100) NOT NULL,
        entity_type VARCHAR(50),
        entity_id INT UNSIGNED,
        details JSON,
        ip_address VARCHAR(45),
        tenant_id INT UNSIGNED DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_user (user_id),
        INDEX idx_action (action),
        INDEX idx_entity (entity_type, entity_id),
        INDEX idx_created (created_at)
      )
    `);
    logger.info('Audit logs table ensured');
  } catch (err) {
    logger.error({ err: err.message }, 'Failed to create audit_logs table');
  }
})();

/**
 * Write an audit log entry.
 *
 * @param {object} req         - Express request (used to extract user info and IP)
 * @param {string} action      - Action name (e.g. 'login', 'logout', 'password_reset')
 * @param {string} entityType  - Entity type (e.g. 'user', 'job', 'vehicle')
 * @param {number} entityId    - Entity ID
 * @param {object} details     - Additional details (free-form JSON)
 */
async function log(req, action, entityType, entityId, details) {
  try {
    await db.query(
      'INSERT INTO audit_logs (user_id, username, action, entity_type, entity_id, details, ip_address, tenant_id) VALUES (?,?,?,?,?,?,?,?)',
      [
        req.user?.id || null,
        req.user?.username || null,
        action,
        entityType,
        entityId || null,
        JSON.stringify(details || {}),
        req.ip || null,
        req.user?.tenant_id || 1,
      ]
    );
  } catch (e) {
    logger.error({ err: e }, 'Audit log write failed');
  }
}

module.exports = { log };
