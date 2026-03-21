// jest.config.js
module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/tests/**/*.test.js'],
  verbose: true,
  // Timeout for integration tests that hit the database
  testTimeout: 10000,
};
