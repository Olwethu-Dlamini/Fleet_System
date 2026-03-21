// ============================================
// FILE: src/server.js
// ============================================
require('dotenv').config();

// FOUND-04: Fail fast — crash if JWT_SECRET is not configured
// Never run with a fallback secret in any environment
if (!process.env.JWT_SECRET) {
  console.error('FATAL: JWT_SECRET environment variable is not set. Server will not start.');
  process.exit(1);
}

const express = require('express');
const cors    = require('cors');
const bcrypt  = require('bcryptjs');
const jwt     = require('jsonwebtoken');
const helmet  = require('helmet');

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

// 2. Body parsers
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// 3. Security headers — ONLY on /api routes (NOT /swagger — Pitfall 2: helmet CSP blocks Swagger inline scripts)
app.use('/api', helmet());

// 4. General API rate limit — 200 req/IP/15min
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
      return res.status(401).json({ success: false, message: 'Invalid username or password' });
    }

    const user = rows[0];

    const passwordMatch = await bcrypt.compare(password, user.password_hash);
    if (!passwordMatch) {
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
    console.error('Login error:', error.message);
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
  console.error('Global error:', err.message);
  res.status(err.status || 500).json({
    success: false,
    error  : process.env.NODE_ENV === 'production' ? 'Internal server error' : err.message,
  });
});

// ======================
// START SERVER
// ======================
(async () => {
  try {
    await db.query('SELECT 1 as test');
    console.log('Database connection successful');

    app.listen(PORT, () => {
      console.log('\n' + '='.repeat(50));
      console.log('Vehicle Scheduling API');
      console.log('='.repeat(50));
      console.log(`Server:  http://localhost:${PORT}`);
      console.log(`API:     http://localhost:${PORT}/api`);
      console.log(`Login:   POST http://localhost:${PORT}/api/auth/login`);
      console.log('='.repeat(50) + '\n');
      console.log('Roles:  admin | scheduler | technician');
      console.log('='.repeat(50) + '\n');
    });
  } catch (err) {
    console.error('Database connection failed:', err.message);
    process.exit(1);
  }
})();
