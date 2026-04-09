// ============================================
// FILE: src/services/emeraldService.js
// PURPOSE: Emerald v6 API integration service
//          Wraps HTTP calls to Emerald ISP/billing system
// ============================================

const axios  = require('axios');
const logger = require('../config/logger').child({ service: 'emeraldService' });

const EMERALD_API_URL  = process.env.EMERALD_API_URL;
const EMERALD_API_USER = process.env.EMERALD_API_USER;
const EMERALD_API_PASS = process.env.EMERALD_API_PASSWORD;

// ============================================
// Emerald Error Classes
// ============================================

class EmeraldApiError extends Error {
  constructor(message, retcode, action) {
    super(message);
    this.name    = 'EmeraldApiError';
    this.retcode = retcode;
    this.action  = action;
  }
}

class EmeraldConnectionError extends Error {
  constructor(message, cause) {
    super(message);
    this.name  = 'EmeraldConnectionError';
    this.cause = cause;
  }
}

// ============================================
// Core API caller
// ============================================

/**
 * Make a raw call to the Emerald API.
 *
 * @param {string} action  - Emerald API action name (e.g. "customer_list")
 * @param {Object} params  - Additional key/value params for the request
 * @returns {Promise<Object>} Parsed JSON response body
 * @throws {EmeraldConnectionError} If the HTTP request fails entirely
 * @throws {EmeraldApiError}        If Emerald returns a non-zero retcode
 */
async function callApi(action, params = {}) {
  if (!EMERALD_API_URL) {
    throw new EmeraldConnectionError('EMERALD_API_URL is not configured');
  }
  if (!EMERALD_API_USER || !EMERALD_API_PASS) {
    throw new EmeraldConnectionError('Emerald API credentials are not configured');
  }

  const url = `${EMERALD_API_URL.replace(/\/+$/, '')}/api.ews`;

  const formData = new URLSearchParams({
    login_user    : EMERALD_API_USER,
    login_password: EMERALD_API_PASS,
    action,
    format: 'json',
    ...params,
  });

  logger.debug({ action, url }, 'Emerald API request');

  let response;
  try {
    response = await axios.post(url, formData.toString(), {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      timeout: 30000, // 30 second timeout
    });
  } catch (err) {
    const msg = err.response
      ? `Emerald API HTTP ${err.response.status}: ${err.response.statusText}`
      : `Emerald API connection failed: ${err.message}`;
    logger.error({ err: err.message, action }, msg);
    throw new EmeraldConnectionError(msg, err);
  }

  const data = response.data;

  // Emerald returns retcode 0 on success
  if (data.retcode !== undefined && data.retcode !== 0) {
    const errMsg = data.message || `Emerald API error (retcode=${data.retcode})`;
    logger.warn({ action, retcode: data.retcode, message: data.message }, errMsg);
    throw new EmeraldApiError(errMsg, data.retcode, action);
  }

  logger.debug({ action, retcode: data.retcode }, 'Emerald API response OK');
  return data;
}

// ============================================
// High-level methods
// ============================================

/**
 * Test connectivity and authentication to the Emerald API.
 * @returns {Promise<{connected: boolean, message: string}>}
 */
async function testConnection() {
  try {
    // Use a lightweight action to verify credentials
    await callApi('customer_list', { limit: 1 });
    return { connected: true, message: 'Connected to Emerald API' };
  } catch (err) {
    return {
      connected: false,
      message: err instanceof EmeraldConnectionError
        ? `Connection failed: ${err.message}`
        : `API error: ${err.message}`,
    };
  }
}

/**
 * Fetch customers from Emerald.
 * @param {Object} filters - Optional filters (search, limit, offset, etc.)
 * @returns {Promise<Object>} Emerald response with customer data
 */
async function getCustomers(filters = {}) {
  const params = {};
  if (filters.search)  params.search = filters.search;
  if (filters.limit)   params.limit  = String(filters.limit);
  if (filters.offset)  params.offset = String(filters.offset);
  if (filters.status)  params.status = filters.status;

  return callApi('customer_list', params);
}

/**
 * Fetch incidents/work orders from Emerald.
 * @param {Object} filters - Optional filters (customer_id, status, date range, etc.)
 * @returns {Promise<Object>} Emerald response with incident data
 */
async function getIncidents(filters = {}) {
  const params = {};
  if (filters.customer_id) params.customer_id = String(filters.customer_id);
  if (filters.status)      params.status      = filters.status;
  if (filters.date_from)   params.date_from   = filters.date_from;
  if (filters.date_to)     params.date_to     = filters.date_to;
  if (filters.limit)       params.limit       = String(filters.limit);
  if (filters.offset)      params.offset      = String(filters.offset);

  return callApi('incident_list', params);
}

/**
 * Fetch schedule data from Emerald.
 * @param {Object} filters - Optional filters (date, technician, etc.)
 * @returns {Promise<Object>} Emerald response with schedule data
 */
async function getSchedule(filters = {}) {
  const params = {};
  if (filters.date)          params.date          = filters.date;
  if (filters.technician_id) params.technician_id = String(filters.technician_id);
  if (filters.limit)         params.limit         = String(filters.limit);
  if (filters.offset)        params.offset        = String(filters.offset);

  return callApi('schedule_list', params);
}

// ============================================
// Exports
// ============================================

module.exports = {
  callApi,
  testConnection,
  getCustomers,
  getIncidents,
  getSchedule,
  EmeraldApiError,
  EmeraldConnectionError,
};
