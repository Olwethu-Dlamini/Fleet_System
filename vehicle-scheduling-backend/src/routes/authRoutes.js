// ============================================
// FILE: src/routes/authRoutes.js
// PURPOSE: Auth API endpoints
// ============================================

const express        = require('express');
const router         = express.Router();
const AuthController = require('../controllers/authController');
const { verifyToken } = require('../middleware/authMiddleware');

// POST /api/auth/login  - no token needed (public)
router.post('/login', AuthController.login);

// POST /api/auth/logout - token needed
router.post('/logout', verifyToken, AuthController.logout);

// GET  /api/auth/me     - get current user info
router.get('/me', verifyToken, AuthController.getMe);

module.exports = router;