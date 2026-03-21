// ============================================
// FILE: src/routes/notifications.js
// PURPOSE: Notification CRUD routes
// Requirements: NOTIF-04, NOTIF-05
// ============================================

const express = require('express');
const router  = express.Router();
const { verifyToken } = require('../middleware/authMiddleware');
const NotificationController = require('../controllers/notificationController');

// All notification routes require authentication
// GET    /api/notifications             — list notifications for current user
router.get('/',               verifyToken, NotificationController.getNotifications);

// GET    /api/notifications/unread-count — count of unread notifications
router.get('/unread-count',   verifyToken, NotificationController.getUnreadCount);

// GET    /api/notifications/preferences — get notification preferences
router.get('/preferences',    verifyToken, NotificationController.getPreferences);

// PATCH  /api/notifications/read-all    — mark all as read (must come before /:id/read)
router.patch('/read-all',     verifyToken, NotificationController.markAllRead);

// PATCH  /api/notifications/:id/read    — mark single notification as read
router.patch('/:id/read',     verifyToken, NotificationController.markRead);

// PUT    /api/notifications/preferences — update notification preferences
router.put('/preferences',    verifyToken, NotificationController.updatePreferences);

module.exports = router;
