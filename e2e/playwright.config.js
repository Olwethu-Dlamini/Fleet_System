// e2e/playwright.config.js
// Playwright configuration for Fleet Scheduler E2E API journey tests.
// Tests use apiRequestContext — no browser projects required (Flutter renders to canvas).

const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: '.',
  testMatch: '**/*.spec.js',
  timeout: 30000,
  retries: 1,
  use: {
    baseURL: process.env.E2E_BASE_URL || 'http://localhost:3000',
    extraHTTPHeaders: {
      Accept: 'application/json',
    },
  },
  reporter: [['list'], ['html', { outputFolder: './report' }]],
});
