// e2e/playwright.config.js
// Playwright configuration for Fleet Scheduler E2E tests.
// Supports both API journey tests and browser-based Flutter web capture.

const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  testDir: '.',
  testMatch: '**/*.spec.js',
  timeout: 120000, // 2 min per test — Flutter web can be slow
  retries: 0,
  workers: 1, // Sequential — Flutter app is stateful

  use: {
    baseURL: process.env.E2E_BASE_URL || 'http://localhost:3000',
    extraHTTPHeaders: {
      Accept: 'application/json',
    },
    // Browser capture settings
    screenshot: 'on',
    video: 'on',
    trace: 'on-first-retry',
  },

  projects: [
    // API-only tests (no browser needed)
    {
      name: 'api',
      testMatch: '**/api-*.spec.js',
      use: {
        // No browser — uses apiRequestContext only
      },
    },

    // Browser capture tests (Flutter web app)
    {
      name: 'capture',
      testMatch: '**/capture-*.spec.js',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 430, height: 932 }, // iPhone 15 Pro Max size
        hasTouch: true,
        launchOptions: {
          args: ['--disable-web-security'], // Allow localhost CORS
        },
      },
    },

    // Desktop capture (wider viewport)
    {
      name: 'capture-desktop',
      testMatch: '**/capture-*.spec.js',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 1280, height: 800 },
        launchOptions: {
          args: ['--disable-web-security'],
        },
      },
    },
  ],

  reporter: [['list'], ['html', { outputFolder: './report' }]],

  // Output directory for test artifacts (videos, traces)
  outputDir: './test-results',
});
