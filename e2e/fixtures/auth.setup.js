// e2e/fixtures/auth.setup.js
// Auth helper for Fleet Scheduler E2E tests.
// loginAs() performs a real POST /api/auth/login against the live server and returns the token.
// Credentials can be overridden via environment variables for CI/staging use.

const CREDENTIALS = {
  admin: {
    username: process.env.TEST_ADMIN_USER || 'admin',
    password: process.env.TEST_ADMIN_PASS || 'admin123',
  },
  scheduler: {
    username: process.env.TEST_SCHEDULER_USER || 'scheduler',
    password: process.env.TEST_SCHEDULER_PASS || 'scheduler123',
  },
  technician: {
    username: process.env.TEST_TECHNICIAN_USER || 'technician',
    password: process.env.TEST_TECHNICIAN_PASS || 'tech123',
  },
};

/**
 * Login as a given role and return the auth token.
 * @param {import('@playwright/test').APIRequestContext} apiContext - Playwright API context
 * @param {'admin' | 'scheduler' | 'technician'} role
 * @returns {Promise<string>} JWT token
 */
async function loginAs(apiContext, role) {
  const creds = CREDENTIALS[role];
  if (!creds) {
    throw new Error(`Unknown role: "${role}". Valid roles: ${Object.keys(CREDENTIALS).join(', ')}`);
  }

  const res = await apiContext.post('/api/auth/login', {
    data: { username: creds.username, password: creds.password },
  });

  if (!res.ok()) {
    const body = await res.text();
    throw new Error(`Login failed for role "${role}" (HTTP ${res.status()}): ${body}`);
  }

  const body = await res.json();
  if (!body.token) {
    throw new Error(`Login response for role "${role}" did not contain a token: ${JSON.stringify(body)}`);
  }

  return body.token;
}

module.exports = { loginAs, CREDENTIALS };
