// ============================================
// FILE: src/config/logger.js
// PURPOSE: Singleton pino structured logger
// Requirements: FOUND-10
// ============================================
const pino = require('pino');

const logger = pino({
  // 'debug' in development, 'info' in production
  level: process.env.LOG_LEVEL || (process.env.NODE_ENV === 'production' ? 'info' : 'debug'),
  // Human-readable colorized output in development; raw JSON in production (for log shipping)
  // IMPORTANT: pino-pretty is slow — NEVER use it in production (see RESEARCH anti-patterns)
  transport: process.env.NODE_ENV !== 'production'
    ? { target: 'pino-pretty', options: { colorize: true } }
    : undefined,
});

module.exports = logger;
