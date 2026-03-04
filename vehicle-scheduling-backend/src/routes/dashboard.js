// ============================================
// FILE: src/routes/dashboard.js
// PURPOSE: Define dashboard API routes
// LAYER: Routing Layer
// ============================================
const express = require('express');
const router = express.Router();
const dashboardController = require('../controllers/dashboardController');

/**
 * Dashboard Routes
 * 
 * Base path: /api/dashboard
 * 
 * Available endpoints:
 * - GET /summary  - Full dashboard summary
 * - GET /stats    - Quick stats only (lightweight)
 */

// GET /api/dashboard/summary
// Returns complete dashboard summary with all details
router.get('/summary', dashboardController.getDashboardSummary);

// GET /api/dashboard/stats
// Returns only counts (lightweight for badges/notifications)
router.get('/stats', dashboardController.getQuickStats);

module.exports = router;