// ============================================
// FILE: src/routes/dashboard.js
// PURPOSE: Define dashboard API routes
// LAYER: Routing Layer
// ============================================
const express = require('express');
const router = express.Router();
const dashboardController = require('../controllers/dashboardController');
const { verifyToken } = require('../middleware/authMiddleware');

/**
 * Dashboard Routes
 *
 * Base path: /api/dashboard
 *
 * All routes require a valid JWT (verifyToken middleware).
 * All controller methods scope queries to req.user.tenant_id.
 *
 * Available endpoints:
 * - GET /summary    - Full dashboard summary
 * - GET /stats      - Quick stats only (lightweight)
 * - GET /chart-data - Hourly job counts for today (bar chart data)
 */

// GET /api/dashboard/summary
// Returns complete dashboard summary with all details
router.get('/summary', verifyToken, dashboardController.getDashboardSummary);

// GET /api/dashboard/stats
// Returns only counts (lightweight for badges/notifications)
router.get('/stats', verifyToken, dashboardController.getQuickStats);

// GET /api/dashboard/chart-data
// Returns hourly job counts for today, scoped to tenant
router.get('/chart-data', verifyToken, dashboardController.getChartData);

module.exports = router;
