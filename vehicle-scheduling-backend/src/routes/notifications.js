// ============================================
// FILE: src/routes/notifications.js
// PURPOSE: Notification CRUD routes
// Requirements: NOTIF-04, NOTIF-05
// ============================================

const express = require('express');
const router  = express.Router();
const { verifyToken } = require('../middleware/authMiddleware');
const NotificationController = require('../controllers/notificationController');

/**
 * @swagger
 * /notifications:
 *   get:
 *     tags: [Notifications]
 *     summary: List notifications for current user
 *     description: Returns paginated notifications for the authenticated user, most recent first.
 *     security:
 *       - ApiKeyAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           default: 1
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 20
 *     responses:
 *       200:
 *         description: Notifications retrieved
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 notifications:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Notification'
 *                 total:
 *                   type: integer
 *                   example: 15
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
// All notification routes require authentication
// GET    /api/notifications             — list notifications for current user
router.get('/',               verifyToken, NotificationController.getNotifications);

/**
 * @swagger
 * /notifications/unread-count:
 *   get:
 *     tags: [Notifications]
 *     summary: Get unread notification count
 *     description: Returns the count of unread notifications for the authenticated user. Used to display the badge number on the notification bell icon.
 *     security:
 *       - ApiKeyAuth: []
 *     responses:
 *       200:
 *         description: Unread count
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 count:
 *                   type: integer
 *                   example: 3
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
// GET    /api/notifications/unread-count — count of unread notifications
router.get('/unread-count',   verifyToken, NotificationController.getUnreadCount);

/**
 * @swagger
 * /notifications/preferences:
 *   get:
 *     tags: [Notifications]
 *     summary: Get notification preferences
 *     description: Returns the authenticated user's notification preferences (push, email, event types).
 *     security:
 *       - ApiKeyAuth: []
 *     responses:
 *       200:
 *         description: Preferences retrieved
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 preferences:
 *                   $ref: '#/components/schemas/NotificationPreference'
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
// GET    /api/notifications/preferences — get notification preferences
router.get('/preferences',    verifyToken, NotificationController.getPreferences);

/**
 * @swagger
 * /notifications/read-all:
 *   patch:
 *     tags: [Notifications]
 *     summary: Mark all notifications as read
 *     description: Marks all unread notifications for the authenticated user as read.
 *     security:
 *       - ApiKeyAuth: []
 *     responses:
 *       200:
 *         description: All notifications marked as read
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/SuccessResponse'
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
// PATCH  /api/notifications/read-all    — mark all as read (must come before /:id/read)
router.patch('/read-all',     verifyToken, NotificationController.markAllRead);

/**
 * @swagger
 * /notifications/{id}/read:
 *   patch:
 *     tags: [Notifications]
 *     summary: Mark a notification as read
 *     description: Marks a single notification as read for the authenticated user.
 *     security:
 *       - ApiKeyAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Notification ID
 *     responses:
 *       200:
 *         description: Notification marked as read
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/SuccessResponse'
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       404:
 *         description: Notification not found
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
// PATCH  /api/notifications/:id/read    — mark single notification as read
router.patch('/:id/read',     verifyToken, NotificationController.markRead);

/**
 * @swagger
 * /notifications/preferences:
 *   put:
 *     tags: [Notifications]
 *     summary: Update notification preferences
 *     description: Updates the authenticated user's notification preferences for push notifications, email notifications, and specific event types.
 *     security:
 *       - ApiKeyAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/NotificationPreference'
 *     responses:
 *       200:
 *         description: Preferences updated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 preferences:
 *                   $ref: '#/components/schemas/NotificationPreference'
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
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
// PUT    /api/notifications/preferences — update notification preferences
router.put('/preferences',    verifyToken, NotificationController.updatePreferences);

module.exports = router;
