// ============================================
// FILE: src/server.js
// ============================================
require('dotenv').config();

// FOUND-04: Fail fast — crash if JWT_SECRET is not configured
// Never run with a fallback secret in any environment
if (!process.env.JWT_SECRET) {
  process.stderr.write('FATAL: JWT_SECRET environment variable is not set. Server will not start.\n');
  process.exit(1);
}

const express  = require('express');
const cors     = require('cors');
const bcrypt   = require('bcryptjs');
const jwt      = require('jsonwebtoken');
const helmet   = require('helmet');
const pinoHttp = require('pino-http');
const logger   = require('./config/logger');

const db         = require('./config/database');
const routes     = require('./routes');
const swaggerUi  = require('swagger-ui-express');
const swaggerSpec = require('./config/swagger');
const { USER_ROLE, PERMISSIONS } = require('./config/constants');
const { apiLimiter, loginLimiter } = require('./middleware/rateLimiter');

const app  = express();
const PORT = process.env.PORT || 3000;

const JWT_SECRET  = process.env.JWT_SECRET;
const JWT_EXPIRES = process.env.JWT_EXPIRES || '8h';

// ============================================
// Role normalisation helper
// Keeps legacy DB values ("dispatcher", "driver")
// working while the new names roll out.
// ============================================
function normaliseRole(dbRole) {
  const map = {
    dispatcher: USER_ROLE.SCHEDULER,
    driver    : USER_ROLE.TECHNICIAN,
    admin     : USER_ROLE.ADMIN,
    scheduler : USER_ROLE.SCHEDULER,
    technician: USER_ROLE.TECHNICIAN,
  };
  return map[dbRole] ?? dbRole;
}

function getPermissionsForRole(role) {
  return Object.entries(PERMISSIONS)
    .filter(([, roles]) => roles.includes(role))
    .map(([perm]) => perm);
}

// ======================
// MIDDLEWARE
// ======================

// 1. CORS — must come before helmet (helmet sets headers that CORS pre-flight needs to not conflict with)
app.use(cors({
  origin: function (origin, callback) {
    if (!origin) return callback(null, true);
    const localhostPattern   = /^http:\/\/localhost:\d+$/;
    const localhostIPPattern = /^http:\/\/127\.0\.0\.1:\d+$/;
    if (localhostPattern.test(origin) || localhostIPPattern.test(origin)) {
      return callback(null, true);
    }
    callback(new Error(`CORS blocked: ${origin}`));
  },
  credentials  : true,
  methods      : ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Accept', 'Authorization'],
}));

// 2. pino-http request logging — after cors(), before helmet and routes
app.use(pinoHttp({ logger }));

// 3. Body parsers
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// 4. Security headers — ONLY on /api routes (NOT /swagger — Pitfall 2: helmet CSP blocks Swagger inline scripts)
app.use('/api', helmet());

// 5. General API rate limit — 200 req/IP/15min
app.use('/api', apiLimiter);

// ======================
// SWAGGER
// ======================
app.use('/swagger', swaggerUi.serve, swaggerUi.setup(swaggerSpec));
app.get('/swagger.json', (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.send(swaggerSpec);
});

// ======================
// AUTH ROUTES (inline — fast path, no caching issues)
// ======================

// POST /api/auth/login
app.post('/api/auth/login', loginLimiter, async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({
        success: false,
        message: 'Username and password are required',
      });
    }

    const [rows] = await db.query(
      'SELECT id, username, password_hash, role, email, full_name, tenant_id FROM users WHERE username = ? AND is_active = 1',
      [username]
    );

    if (rows.length === 0) {
      logger.warn({ username }, 'Login failed: user not found');
      return res.status(401).json({ success: false, message: 'Invalid username or password' });
    }

    const user = rows[0];

    const passwordMatch = await bcrypt.compare(password, user.password_hash);
    if (!passwordMatch) {
      logger.warn({ username }, 'Login failed: invalid credentials');
      return res.status(401).json({ success: false, message: 'Invalid username or password' });
    }

    const normalisedRole  = normaliseRole(user.role);
    const userPermissions = getPermissionsForRole(normalisedRole);

    const token = jwt.sign(
      {
        id        : user.id,
        username  : user.username,
        role      : normalisedRole,
        email     : user.email,
        tenant_id : user.tenant_id,   // Required for all downstream tenant-scoped queries
        permissions: userPermissions,
      },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES }
    );

    logger.info({ userId: user.id, role: normalisedRole }, 'User logged in');

    return res.status(200).json({
      success  : true,
      token    : token,
      expiresIn: JWT_EXPIRES,
      user     : {
        id         : user.id,
        username   : user.username,
        full_name  : user.full_name,
        role       : normalisedRole,        // <- "admin" | "scheduler" | "technician"
        email      : user.email,
        permissions: userPermissions,       // <- e.g. ["jobs:read", "jobs:create", ...]
      },
    });

  } catch (error) {
    logger.error({ err: error }, 'Login error');
    return res.status(500).json({ success: false, message: 'Login failed: ' + error.message });
  }
});

// GET /api/auth/me
app.get('/api/auth/me', async (req, res) => {
  try {
    const authHeader = req.headers['authorization'];
    if (!authHeader) return res.status(401).json({ success: false, message: 'No token provided' });

    const token   = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, JWT_SECRET);

    const [rows] = await db.query(
      'SELECT id, username, full_name, role, email FROM users WHERE id = ?',
      [decoded.id]
    );

    if (rows.length === 0) return res.status(404).json({ success: false, message: 'User not found' });

    const normalisedRole  = normaliseRole(rows[0].role);
    const userPermissions = getPermissionsForRole(normalisedRole);

    return res.status(200).json({
      success: true,
      user   : { ...rows[0], role: normalisedRole, permissions: userPermissions },
    });

  } catch (error) {
    return res.status(401).json({ success: false, message: 'Invalid or expired token' });
  }
});

// POST /api/auth/logout
app.post('/api/auth/logout', (req, res) => {
  res.status(200).json({ success: true, message: 'Logged out successfully' });
});

// ======================
// ALL OTHER API ROUTES
// ======================
app.use('/api', routes);

// Root
app.get('/', (req, res) => {
  res.json({
    message  : 'Vehicle Scheduling System API',
    version  : '1.0.0',
    status   : 'running',
    timestamp: new Date().toISOString(),
  });
});

// Health check
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', uptime: process.uptime(), timestamp: new Date().toISOString() });
});

// 404
app.use((req, res) => {
  res.status(404).json({ success: false, error: 'Route not found', path: req.originalUrl });
});

// Global error handler
app.use((err, req, res, next) => {
  logger.error({ err }, 'Global error handler');
  res.status(err.status || 500).json({
    success: false,
    error  : process.env.NODE_ENV === 'production' ? 'Internal server error' : err.message,
  });
});

// ======================
// START SERVER
// ======================
// Export app for testing (does not start server when imported as module)
if (require.main === module) {
  (async () => {
    try {
      await db.query('SELECT 1 as test');
      logger.info('Database connection verified');

      // ============================================
      // DB MIGRATION: Notification tables (Phase 5)
      // Idempotent — safe to run on every startup
      // ============================================
      await db.query(`
        CREATE TABLE IF NOT EXISTS notifications (
          id              INT AUTO_INCREMENT PRIMARY KEY,
          tenant_id       INT NOT NULL,
          user_id         INT NOT NULL,
          job_id          INT,
          type            VARCHAR(50) NOT NULL,
          title           VARCHAR(255) NOT NULL,
          body            TEXT NOT NULL,
          is_read         BOOLEAN NOT NULL DEFAULT FALSE,
          created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
          INDEX idx_notifications_tenant_user (tenant_id, user_id),
          INDEX idx_notifications_job (job_id),
          INDEX idx_notifications_created (created_at)
        )
      `);
      await db.query(`
        CREATE TABLE IF NOT EXISTS notification_preferences (
          id              INT AUTO_INCREMENT PRIMARY KEY,
          tenant_id       INT NOT NULL,
          user_id         INT NOT NULL UNIQUE,
          email_enabled   BOOLEAN NOT NULL DEFAULT TRUE,
          push_enabled    BOOLEAN NOT NULL DEFAULT TRUE,
          created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          INDEX idx_notif_prefs_user (user_id)
        )
      `);
      logger.info('Notification tables ensured');

      const { startCronJobs } = require('./services/cronService');
      startCronJobs();

      app.listen(PORT, () => {
        logger.info({ port: PORT }, `FleetScheduler API listening on port ${PORT}`);
      });
    } catch (err) {
      logger.error({ err }, 'Database connection failed');
      process.exit(1);
    }
  })();
}

module.exports = app;
