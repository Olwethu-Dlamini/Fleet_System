// ============================================
// FILE: src/routes/reports.js
// PURPOSE: Define reports API routes
// LAYER: Routing Layer
// ============================================
const express = require('express');
const router = express.Router();
const reportsController = require('../controllers/reportsController');

/**
 * Reports Routes
 * 
 * Base path: /api/reports
 * 
 * Available endpoints:
 * - GET /jobs-per-vehicle        - Jobs per vehicle breakdown
 * - GET /utilization             - Vehicle utilization percentage
 * - GET /jobs-by-type            - Jobs by service type
 * - GET /completion-analysis     - Completed vs cancelled analysis
 * - GET /executive-dashboard     - Combined executive dashboard
 * - GET /quick-stats             - Lightweight quick stats
 */

// GET /api/reports/jobs-per-vehicle
// Returns jobs per vehicle report with optional job type filter
router.get('/jobs-per-vehicle', reportsController.getJobsPerVehicle);

// GET /api/reports/utilization
// Returns vehicle utilization percentage report
router.get('/utilization', reportsController.getVehicleUtilization);

// GET /api/reports/jobs-by-type
// Returns jobs broken down by service type
router.get('/jobs-by-type', reportsController.getJobsByServiceType);

// GET /api/reports/completion-analysis
// Returns completed vs cancelled jobs analysis
router.get('/completion-analysis', reportsController.getCompletionAnalysis);

// GET /api/reports/executive-dashboard
// Returns comprehensive executive dashboard
router.get('/executive-dashboard', reportsController.getExecutiveDashboard);

// GET /api/reports/quick-stats
// Returns lightweight quick stats (for badges/notifications)
router.get('/quick-stats', reportsController.getQuickStats);

module.exports = router;