// ============================================
// FILE: src/routes/index.js
// PURPOSE: Register all API routes
// ============================================

const express = require('express');
const router  = express.Router();

// ==========================================
// IMPORT ALL ROUTE FILES
// ==========================================

const authRoutes          = require('./authRoutes');
const jobRoutes           = require('./jobs');
const vehicleRoutes       = require('./vehicles');
const jobAssignmentRoutes = require('./jobAssignmentRoutes');
const jobStatusRoutes     = require('./jobStatusRoutes');
const dashboardRoutes     = require('./dashboard');
const reportsRoutes       = require('./reports');
const userRoutes              = require('./users');               // ← NEW
const availabilityRoutes      = require('./availabilityRoutes');  // ← NEW
const vehicleMaintenanceRoutes = require('./vehicle-maintenance'); // ← Phase 2
const settingsRoutes           = require('./settings');            // ← Phase 2
const notificationRoutes       = require('./notifications');        // ← Phase 5
const timeExtensionRoutes      = require('./timeExtension');         // ← Phase 6

// ==========================================
// REGISTER ROUTES
// Order matters - auth first
// ==========================================
router.use('/auth',            authRoutes);           // /api/auth/login
router.use('/jobs',            jobRoutes);             // /api/jobs
router.use('/vehicles',        vehicleRoutes);         // /api/vehicles
router.use('/job-assignments', jobAssignmentRoutes);   // /api/job-assignments
router.use('/job-status',      jobStatusRoutes);       // /api/job-status
router.use('/dashboard',       dashboardRoutes);       // /api/dashboard
router.use('/reports',         reportsRoutes);         // /api/reports
router.use('/users',               userRoutes);               // /api/users  ← NEW
router.use('/availability',        availabilityRoutes);        // /api/availability ← NEW
router.use('/vehicle-maintenance', vehicleMaintenanceRoutes);  // /api/vehicle-maintenance ← Phase 2
router.use('/settings',            settingsRoutes);             // /api/settings ← Phase 2
router.use('/notifications',       notificationRoutes);         // /api/notifications ← Phase 5
router.use('/time-extensions',     timeExtensionRoutes);         // /api/time-extensions ← Phase 6

// ==========================================
// HEALTH CHECK
// ==========================================
router.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// ==========================================
// module.exports MUST be at the bottom
// Anything after this line is NEVER executed
// ==========================================
module.exports = router;