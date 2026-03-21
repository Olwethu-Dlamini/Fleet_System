// ============================================
// FILE: src/middleware/rateLimiter.js
// PURPOSE: Rate limiting middleware — brute-force protection
// Requirements: FOUND-05
// ============================================
const rateLimit = require('express-rate-limit');

// General API limit — 200 requests per IP per 15 minutes
// High enough for normal app usage; catches scrapers and runaway clients
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,   // 15 minutes
  max: 200,
  standardHeaders: true,        // Return rate limit info in RateLimit-* headers
  legacyHeaders: false,
  message: {
    success: false,
    message: 'Too many requests from this IP, please try again in 15 minutes.',
  },
});

// Strict login limit — 10 attempts per IP per 15 minutes
// skipSuccessfulRequests: true prevents legitimate users from being rate-limited
// when on a shared NAT/proxy (common in offices) — only failed attempts count
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: true,
  message: {
    success: false,
    message: 'Too many login attempts from this IP, please try again in 15 minutes.',
  },
});

module.exports = { apiLimiter, loginLimiter };
