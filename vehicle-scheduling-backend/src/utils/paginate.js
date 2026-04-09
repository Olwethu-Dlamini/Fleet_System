// ============================================
// FILE: src/utils/paginate.js
// PURPOSE: Reusable pagination helper for all list endpoints
//
// Usage:
//   const { paginate } = require('../utils/paginate');
//   const result = await paginate(db, {
//     dataQuery:  'SELECT * FROM jobs WHERE 1=1',
//     countQuery: 'SELECT COUNT(*) AS total FROM jobs WHERE 1=1',
//     params:     [],
//     page:       req.query.page,
//     limit:      req.query.limit,
//   });
//   // result = { rows: [...], pagination: { page, limit, total, totalPages } }
// ============================================

/**
 * Execute a paginated query and return rows + pagination metadata.
 *
 * @param {import('mysql2/promise').Pool} db - mysql2 pool
 * @param {Object} opts
 * @param {string} opts.dataQuery   - SELECT query WITHOUT LIMIT/OFFSET (will be appended)
 * @param {string} opts.countQuery  - Matching COUNT(*) query (same WHERE clause)
 * @param {Array}  opts.params      - Bind params for both queries (shared WHERE)
 * @param {string|number} [opts.page=1]   - Current page (1-based)
 * @param {string|number} [opts.limit=20] - Rows per page
 * @param {number} [opts.maxLimit=200]    - Upper bound to prevent abuse
 * @returns {Promise<{rows: Array, pagination: {page: number, limit: number, total: number, totalPages: number}}>}
 */
async function paginate(db, opts) {
  const {
    dataQuery,
    countQuery,
    params = [],
    page: rawPage = 1,
    limit: rawLimit = 20,
    maxLimit = 200,
  } = opts;

  // Sanitise page/limit — must be positive integers
  let page  = Math.max(1, parseInt(rawPage, 10) || 1);
  let limit = Math.max(1, Math.min(parseInt(rawLimit, 10) || 20, maxLimit));
  const offset = (page - 1) * limit;

  // Run count + data in parallel for speed
  const [
    [[{ total: rawTotal }]],
    [rows],
  ] = await Promise.all([
    db.query(countQuery, params),
    db.query(`${dataQuery} LIMIT ? OFFSET ?`, [...params, limit, offset]),
  ]);

  const total      = Number(rawTotal);
  const totalPages = Math.ceil(total / limit) || 1;

  return {
    rows,
    pagination: { page, limit, total, totalPages },
  };
}

module.exports = { paginate };
