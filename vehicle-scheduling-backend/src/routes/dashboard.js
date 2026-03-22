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

/**
 * @swagger
 * /dashboard/summary:
 *   get:
 *     tags: [Dashboard]
 *     summary: Get full dashboard summary
 *     description: Returns the complete dashboard summary including job counts by status, active vehicles, active drivers, and today's jobs. All data is scoped to the authenticated user's tenant.
 *     security:
 *       - ApiKeyAuth: []
 *     responses:
 *       200:
 *         description: Dashboard summary retrieved
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   $ref: '#/components/schemas/DashboardSummary'
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
// GET /api/dashboard/summary
// Returns complete dashboard summary with all details
router.get('/summary', verifyToken, dashboardController.getDashboardSummary);

/**
 * @swagger
 * /dashboard/stats:
 *   get:
 *     tags: [Dashboard]
 *     summary: Get quick stats (lightweight)
 *     description: Returns only job count badges — faster than /summary. Used for notification badges and periodic polling.
 *     security:
 *       - ApiKeyAuth: []
 *     responses:
 *       200:
 *         description: Quick stats retrieved
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 stats:
 *                   type: object
 *                   properties:
 *                     pending:
 *                       type: integer
 *                       example: 4
 *                     in_progress:
 *                       type: integer
 *                       example: 3
 *                     completed_today:
 *                       type: integer
 *                       example: 5
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
// GET /api/dashboard/stats
// Returns only counts (lightweight for badges/notifications)
router.get('/stats', verifyToken, dashboardController.getQuickStats);

/**
 * @swagger
 * /dashboard/chart-data:
 *   get:
 *     tags: [Dashboard]
 *     summary: Get hourly job counts for today (chart data)
 *     description: Returns hourly job counts for today, excluding cancelled jobs. Used to populate the bar chart on the dashboard screen.
 *     security:
 *       - ApiKeyAuth: []
 *     responses:
 *       200:
 *         description: Chart data retrieved
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 chartData:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       hour:
 *                         type: integer
 *                         example: 9
 *                       count:
 *                         type: integer
 *                         example: 3
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
// GET /api/dashboard/chart-data
// Returns hourly job counts for today, scoped to tenant
router.get('/chart-data', verifyToken, dashboardController.getChartData);

module.exports = router;
