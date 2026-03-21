// ============================================
// FILE: src/config/firebase.js
// PURPOSE: Firebase Admin SDK singleton for FCM push notifications
// Requirements: NOTIF-01, NOTIF-02, NOTIF-03
// ============================================
// NOTE: This module is optional — if FCM_SERVICE_ACCOUNT_PATH is not set,
// or the file is missing, the server still starts. Notification sends will
// fail gracefully with logged warnings (via lazy-load in notificationService).

const admin = require('firebase-admin');
const logger = require('./logger').child({ service: 'firebase' });

const accountPath = process.env.FCM_SERVICE_ACCOUNT_PATH;

if (!accountPath) {
  logger.warn('FCM_SERVICE_ACCOUNT_PATH not set — Firebase Admin not initialized (FCM push disabled)');
} else {
  try {
    const path = require('path');
    const serviceAccount = require(path.resolve(accountPath));

    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
    }

    logger.info('Firebase Admin SDK initialized');
  } catch (err) {
    logger.warn({ err: err.message }, 'Firebase Admin init failed — FCM push notifications disabled');
  }
}

module.exports = admin;
