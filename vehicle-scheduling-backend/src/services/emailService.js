// ============================================
// FILE: src/services/emailService.js
// PURPOSE: SMTP email dispatch with HTML templates for job notifications
// Requirements: NOTIF-03
// ============================================
// NOTE: If SMTP env vars are not set, transporter is null and sendJobNotification
// logs a warning and returns without throwing. No retry — log and move on.

const nodemailer = require('nodemailer');
const logger = require('../config/logger').child({ service: 'emailService' });

// ============================================
// Create SMTP Transporter
// ============================================
let transporter = null;
try {
  if (!process.env.SMTP_HOST || !process.env.SMTP_USER || !process.env.SMTP_PASS) {
    logger.warn('SMTP env vars (SMTP_HOST, SMTP_USER, SMTP_PASS) not set — email notifications disabled');
  } else {
    transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: parseInt(process.env.SMTP_PORT || '587', 10),
      secure: parseInt(process.env.SMTP_PORT || '587', 10) === 465,
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });
    logger.info({ host: process.env.SMTP_HOST, port: process.env.SMTP_PORT || '587' }, 'SMTP transporter created');
  }
} catch (err) {
  logger.warn({ err: err.message }, 'SMTP transporter creation failed — email notifications disabled');
  transporter = null;
}

// ============================================
// HTML Template Builder
// ============================================
/**
 * Build inline-styled HTML email body for job notifications.
 * @param {string} title - Email heading text
 * @param {string} bodyText - Main message content
 * @param {string} jobNumber - Job reference number
 * @param {string} scheduledTime - Human-readable scheduled time string
 * @returns {string} HTML string
 */
function buildJobNotificationHtml(title, bodyText, jobNumber, scheduledTime) {
  return `
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><title>${title}</title></head>
<body style="margin:0;padding:0;background-color:#f4f6f9;font-family:Arial,Helvetica,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f6f9;padding:20px 0;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color:#ffffff;border-radius:8px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.08);">

          <!-- Header -->
          <tr>
            <td style="background-color:#1976D2;padding:24px 32px;">
              <h1 style="margin:0;color:#ffffff;font-size:20px;font-weight:700;letter-spacing:0.5px;">
                FleetScheduler Pro
              </h1>
              <p style="margin:4px 0 0;color:#BBDEFB;font-size:13px;">Vehicle Scheduling System</p>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding:32px;">
              <h2 style="margin:0 0 16px;color:#212121;font-size:18px;font-weight:700;">${title}</h2>
              <p style="margin:0 0 24px;color:#424242;font-size:15px;line-height:1.6;">${bodyText}</p>

              <!-- Job Details Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#F5F5F5;border-radius:6px;padding:16px;">
                <tr>
                  <td>
                    <p style="margin:0 0 8px;color:#757575;font-size:12px;font-weight:700;text-transform:uppercase;letter-spacing:0.8px;">Job Details</p>
                    <p style="margin:0 0 4px;color:#212121;font-size:14px;"><strong>Job Number:</strong> ${jobNumber}</p>
                    <p style="margin:0;color:#212121;font-size:14px;"><strong>Scheduled Time:</strong> ${scheduledTime}</p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color:#FAFAFA;padding:16px 32px;border-top:1px solid #E0E0E0;">
              <p style="margin:0;color:#9E9E9E;font-size:12px;text-align:center;">
                This is an automated notification from FleetScheduler Pro. Do not reply to this email.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
  `.trim();
}

// ============================================
// Send Job Notification Email
// ============================================
/**
 * Send a job-related notification email.
 * Never throws — catches all errors and logs as warning.
 *
 * @param {object} params
 * @param {string} params.to - Recipient email address
 * @param {string} params.subject - Email subject line
 * @param {string} params.title - Heading in email body
 * @param {string} params.bodyText - Main content paragraph
 * @param {string} params.jobNumber - Job reference number
 * @param {string} params.scheduledTime - Human-readable scheduled time
 */
async function sendJobNotification({ to, subject, title, bodyText, jobNumber, scheduledTime }) {
  if (!transporter) {
    logger.warn({ to, subject }, 'Email not sent — SMTP transporter not configured');
    return;
  }

  try {
    const html = buildJobNotificationHtml(title, bodyText, jobNumber, scheduledTime);

    await transporter.sendMail({
      from: `"FleetScheduler Pro" <${process.env.SMTP_USER}>`,
      to,
      subject,
      html,
    });

    logger.info({ to, subject }, 'Job notification email sent');
  } catch (err) {
    // Per CONTEXT decision: no retry — log and move on
    logger.warn({ to, subject, err: err.message }, 'Job notification email failed — skipping');
  }
}

module.exports = { sendJobNotification };
