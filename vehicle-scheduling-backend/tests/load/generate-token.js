#!/usr/bin/env node
// ============================================
// FILE: tests/load/generate-token.js
// PURPOSE: Generate a valid JWT token for load testing.
//
// USAGE:
//   JWT_SECRET=your-secret node tests/load/generate-token.js
//   TEST_ADMIN_TOKEN=$(node tests/load/generate-token.js) npm run test:load
//
// The token is printed to stdout so it can be captured by the shell.
// Uses the same secret pattern as the backend (JWT_SECRET env var).
// ============================================

const jwt = require('jsonwebtoken');

// Use JWT_SECRET from env, falling back to test secret for convenience.
// In a real load test against a live server, set JWT_SECRET to the
// server's actual secret so tokens are accepted.
const secret = process.env.JWT_SECRET || 'test-secret-value-minimum-32-chars-ok';

const payload = {
  id        : 1,
  username  : 'load_test_admin',
  role      : 'admin',
  tenant_id : 1,
  permissions: [],
};

// Long expiry so the token survives the full load test run
const token = jwt.sign(payload, secret, { expiresIn: '4h' });

process.stdout.write(token + '\n');
