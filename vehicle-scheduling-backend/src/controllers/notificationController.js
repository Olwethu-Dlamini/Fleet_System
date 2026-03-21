// ============================================
// FILE: src/controllers/notificationController.js
// PURPOSE: Handler logic for notification API endpoints
// Requirements: NOTIF-04, NOTIF-05
// ============================================

const db = require('../config/database');
const logger = require('../config/logger').child({ service: 'notificationController' });

class NotificationController {

  // ============================================
  // GET /api/notifications
  // Returns tenant-scoped notifications for authenticated user (last 100)
  // ============================================
  static async getNotifications(req, res) {
    try {
      const [rows] = await db.query(
        `SELECT * FROM notifications
         WHERE tenant_id = ? AND user_id = ?
         ORDER BY created_at DESC
         LIMIT 100`,
        [req.user.tenant_id, req.user.id]
      );
      return res.status(200).json({ success: true, notifications: rows, count: rows.length });
    } catch (err) {
      logger.error({ err }, 'getNotifications error');
      return res.status(500).json({ success: false, message: 'Failed to fetch notifications' });
    }
  }

  // ============================================
  // GET /api/notifications/unread-count
  // Returns count of unread notifications for authenticated user
  // ============================================
  static async getUnreadCount(req, res) {
    try {
      const [rows] = await db.query(
        `SELECT COUNT(*) as count FROM notifications
         WHERE tenant_id = ? AND user_id = ? AND is_read = FALSE`,
        [req.user.tenant_id, req.user.id]
      );
      return res.status(200).json({ success: true, unread_count: rows[0].count });
    } catch (err) {
      logger.error({ err }, 'getUnreadCount error');
      return res.status(500).json({ success: false, message: 'Failed to fetch unread count' });
    }
  }

  // ============================================
  // PATCH /api/notifications/:id/read
  // Marks a single notification as read (tenant + user scoped)
  // ============================================
  static async markRead(req, res) {
    try {
      const { id } = req.params;
      const [result] = await db.query(
        `UPDATE notifications SET is_read = TRUE
         WHERE id = ? AND tenant_id = ? AND user_id = ?`,
        [id, req.user.tenant_id, req.user.id]
      );

      if (result.affectedRows === 0) {
        return res.status(404).json({ success: false, message: 'Notification not found' });
      }

      return res.status(200).json({ success: true, message: 'Notification marked as read' });
    } catch (err) {
      logger.error({ err }, 'markRead error');
      return res.status(500).json({ success: false, message: 'Failed to mark notification as read' });
    }
  }

  // ============================================
  // PATCH /api/notifications/read-all
  // Marks all unread notifications as read for authenticated user
  // ============================================
  static async markAllRead(req, res) {
    try {
      const [result] = await db.query(
        `UPDATE notifications SET is_read = TRUE
         WHERE tenant_id = ? AND user_id = ? AND is_read = FALSE`,
        [req.user.tenant_id, req.user.id]
      );
      return res.status(200).json({
        success: true,
        message: 'All notifications marked as read',
        count: result.affectedRows,
      });
    } catch (err) {
      logger.error({ err }, 'markAllRead error');
      return res.status(500).json({ success: false, message: 'Failed to mark all notifications as read' });
    }
  }

  // ============================================
  // GET /api/notifications/preferences
  // Returns current notification preferences (or defaults if not set)
  // ============================================
  static async getPreferences(req, res) {
    try {
      const [rows] = await db.query(
        `SELECT email_enabled, push_enabled FROM notification_preferences
         WHERE tenant_id = ? AND user_id = ?`,
        [req.user.tenant_id, req.user.id]
      );

      if (rows.length === 0) {
        // Return defaults if no preferences row exists yet
        return res.status(200).json({
          success: true,
          preferences: { email_enabled: true, push_enabled: true },
        });
      }

      return res.status(200).json({ success: true, preferences: rows[0] });
    } catch (err) {
      logger.error({ err }, 'getPreferences error');
      return res.status(500).json({ success: false, message: 'Failed to fetch notification preferences' });
    }
  }

  // ============================================
  // PUT /api/notifications/preferences
  // Upserts notification preferences for authenticated user (NOTIF-04 toggle)
  // Pattern: UPDATE first, INSERT if affectedRows === 0 (avoids REPLACE INTO ID reset)
  // ============================================
  static async updatePreferences(req, res) {
    try {
      const { email_enabled, push_enabled } = req.body;

      // Validate input
      if (email_enabled === undefined && push_enabled === undefined) {
        return res.status(400).json({
          success: false,
          message: 'At least one of email_enabled or push_enabled must be provided',
        });
      }

      // Fetch current preferences for merge
      const [existing] = await db.query(
        `SELECT email_enabled, push_enabled FROM notification_preferences
         WHERE tenant_id = ? AND user_id = ?`,
        [req.user.tenant_id, req.user.id]
      );

      const currentEmailEnabled = existing.length > 0 ? existing[0].email_enabled : true;
      const currentPushEnabled  = existing.length > 0 ? existing[0].push_enabled  : true;

      const finalEmailEnabled = email_enabled !== undefined ? Boolean(email_enabled) : currentEmailEnabled;
      const finalPushEnabled  = push_enabled  !== undefined ? Boolean(push_enabled)  : currentPushEnabled;

      // UPDATE first
      const [updateResult] = await db.query(
        `UPDATE notification_preferences
         SET email_enabled = ?, push_enabled = ?, updated_at = NOW()
         WHERE tenant_id = ? AND user_id = ?`,
        [finalEmailEnabled, finalPushEnabled, req.user.tenant_id, req.user.id]
      );

      // INSERT if no row existed
      if (updateResult.affectedRows === 0) {
        await db.query(
          `INSERT INTO notification_preferences (tenant_id, user_id, email_enabled, push_enabled)
           VALUES (?, ?, ?, ?)`,
          [req.user.tenant_id, req.user.id, finalEmailEnabled, finalPushEnabled]
        );
      }

      return res.status(200).json({
        success: true,
        preferences: { email_enabled: finalEmailEnabled, push_enabled: finalPushEnabled },
      });
    } catch (err) {
      logger.error({ err }, 'updatePreferences error');
      return res.status(500).json({ success: false, message: 'Failed to update notification preferences' });
    }
  }
}

module.exports = NotificationController;
