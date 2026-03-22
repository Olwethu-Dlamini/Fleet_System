// ============================================
// FILE: tests/api/helpers/db.mock.js
// PURPOSE: Jest mock for the MySQL database pool
//
// database.js exports `pool` directly (mysql2/promise pool).
// The pool exposes: pool.query(), pool.getConnection()
// A connection exposes: query(), beginTransaction(), commit(), rollback(), release()
//
// USAGE: require this file BEFORE requiring src/server in each test file.
// The jest.mock() call is hoisted by Jest's transform step, so the mock
// is in place before any module that imports database.js is loaded.
// ============================================

// Mock the database module
jest.mock('../../../src/config/database', () => {
  const mockConnection = {
    query           : jest.fn(),
    beginTransaction: jest.fn().mockResolvedValue(undefined),
    commit          : jest.fn().mockResolvedValue(undefined),
    rollback        : jest.fn().mockResolvedValue(undefined),
    release         : jest.fn().mockReturnValue(undefined),
  };

  const mockDb = {
    query        : jest.fn(),
    getConnection: jest.fn().mockResolvedValue(mockConnection),
    // Expose connection so tests can configure it
    _connection  : mockConnection,
    // pool.on() is called by database.js itself — provide a no-op so the
    // pool initialisation code does not crash when it tries to register
    // the GROUP_CONCAT session-fix listener.
    on           : jest.fn(),
  };

  return mockDb;
});

// Re-export the now-mocked module and a reset helper
const db = require('../../../src/config/database');

/**
 * Resets all mock call history and restores default return values.
 * Call in beforeEach() so each test starts clean.
 */
function resetDbMocks() {
  db.query.mockReset();
  db.getConnection.mockReset();

  // Restore the default mock connection
  const mockConnection = {
    query           : jest.fn(),
    beginTransaction: jest.fn().mockResolvedValue(undefined),
    commit          : jest.fn().mockResolvedValue(undefined),
    rollback        : jest.fn().mockResolvedValue(undefined),
    release         : jest.fn().mockReturnValue(undefined),
  };

  db.getConnection.mockResolvedValue(mockConnection);

  // Default query: return empty result set
  db.query.mockResolvedValue([[], {}]);
}

module.exports = { db, resetDbMocks };
