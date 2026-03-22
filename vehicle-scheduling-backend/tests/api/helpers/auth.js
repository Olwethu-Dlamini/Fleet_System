// ============================================
// FILE: tests/api/helpers/auth.js
// PURPOSE: JWT test fixture helper for API tests
// ============================================

const jwt = require('jsonwebtoken');

// Test JWT secret — must match what we set in process.env.JWT_SECRET before loading app
const JWT_SECRET = 'test-secret-value-minimum-32-chars-ok';

/**
 * Mint a valid JWT for use in tests.
 *
 * @param {string} role - 'admin' | 'scheduler' | 'technician' | 'dispatcher'
 * @param {object} overrides - Any payload fields to override (e.g. { id: 99 })
 * @returns {string} Signed JWT token
 */
function makeToken(role = 'admin', overrides = {}) {
  const payload = {
    id        : 1,
    username  : 'test_' + role,
    role      : role,
    tenant_id : 1,
    permissions: [],
    ...overrides,
  };

  return jwt.sign(payload, JWT_SECRET, { expiresIn: '1h' });
}

module.exports = { makeToken, JWT_SECRET };
