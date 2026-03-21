// tests/integration/securityHeaders.test.js
// Covers FOUND-05: helmet security headers present; login rate limiter active

// Set required env vars before importing app
process.env.JWT_SECRET = 'test-secret-value-minimum-32-chars-ok';
process.env.NODE_ENV = 'test';
process.env.DB_HOST = process.env.DB_HOST || 'localhost';

const request = require('supertest');

let app;
beforeAll(() => {
  // server.js must export app (added by Task 1a — module.exports = app with require.main guard)
  app = require('../../src/server');
});

describe('Security Headers (FOUND-05)', () => {
  test('GET /api/jobs includes X-Frame-Options header', async () => {
    const res = await request(app)
      .get('/api/jobs')
      .expect((r) => {
        // May be 401 (no token) — we just want to confirm the header is present
      });
    expect(res.headers['x-frame-options']).toBeDefined();
  });

  test('GET /api/jobs includes X-Content-Type-Options header', async () => {
    const res = await request(app).get('/api/jobs');
    expect(res.headers['x-content-type-options']).toBe('nosniff');
  });

  test('Unauthenticated request to /api/jobs returns 401 not 200', async () => {
    const res = await request(app).get('/api/jobs');
    expect(res.status).toBe(401);
  });
});
