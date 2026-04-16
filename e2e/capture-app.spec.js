// e2e/capture-app.spec.js
// Full visual capture of the Vehicle Scheduling System.
// Logs in ONCE per role, then navigates all tabs to avoid rate limiting.
//
// Run:
//   cd e2e && ./node_modules/.bin/playwright test capture-app.spec.js --project=capture

const { test } = require('@playwright/test');
const {
  waitForFlutterReady,
  waitForTransition,
  capture,
  clickNavTabByIndex,
  login,
  SCREENSHOT_DIR,
} = require('./fixtures/flutter-helpers');
const fs = require('fs');
const path = require('path');

const FLUTTER_URL = process.env.FLUTTER_URL || 'http://localhost:58285';

const USERS = {
  admin: { username: 'admin', password: 'admin' },
  technician: { username: 'george.manyatsi', password: 'admin' },
};

// Ensure screenshots directory exists
const dir = path.resolve(__dirname, SCREENSHOT_DIR);
if (!fs.existsSync(dir)) {
  fs.mkdirSync(dir, { recursive: true });
}

// Admin has 8 tabs: Dashboard(0) Jobs(1) Vehicles(2) Schedule(3) Tracking(4) Users(5) Reports(6) Settings(7)
const ADMIN_TABS = 8;
// Technician has 2 tabs: Dashboard(0) My Jobs(1)
const TECH_TABS = 2;

// ============================================================
// LOGIN SCREEN (no auth needed)
// ============================================================
test('00 - Login screen', async ({ page }) => {
  await page.goto(FLUTTER_URL);
  await waitForFlutterReady(page);
  await capture(page, '01-login-screen');
});

// ============================================================
// ADMIN — single test, one login, all screens
// ============================================================
test('01 - Admin full walkthrough', async ({ page }) => {
  test.setTimeout(180000); // 3 minutes for full walkthrough

  await page.goto(FLUTTER_URL);
  await login(page, USERS.admin.username, USERS.admin.password);

  // Dashboard (tab 0 — default after login)
  await capture(page, '02-admin-dashboard');
  await page.mouse.wheel(0, 500);
  await waitForTransition(page, 1000);
  await capture(page, '02-admin-dashboard-scrolled');
  await page.mouse.wheel(0, -500); // scroll back up

  // Jobs (tab 1)
  await clickNavTabByIndex(page, 1, ADMIN_TABS);
  await capture(page, '03-admin-jobs-list');
  await page.mouse.wheel(0, 400);
  await waitForTransition(page, 1000);
  await capture(page, '03-admin-jobs-scrolled');
  await page.mouse.wheel(0, -400);

  // Click first job for detail view
  const vp = page.viewportSize();
  await page.mouse.click(vp.width / 2, 200);
  await waitForTransition(page, 2000);
  await capture(page, '04-admin-job-detail');
  await page.mouse.wheel(0, 400);
  await waitForTransition(page, 1000);
  await capture(page, '04-admin-job-detail-scrolled');

  // Go back to Jobs list (click back or re-click Jobs tab)
  await clickNavTabByIndex(page, 1, ADMIN_TABS);
  await waitForTransition(page);

  // Click FAB for Create Job (bottom-right, above nav bar)
  await page.mouse.click(vp.width - 60, vp.height - 100);
  await waitForTransition(page, 2000);
  await capture(page, '05-admin-create-job');
  await page.mouse.wheel(0, 500);
  await waitForTransition(page, 1000);
  await capture(page, '05-admin-create-job-scrolled');

  // Vehicles (tab 2)
  await clickNavTabByIndex(page, 2, ADMIN_TABS);
  await capture(page, '06-admin-vehicles');
  await page.mouse.wheel(0, 400);
  await waitForTransition(page, 1000);
  await capture(page, '06-admin-vehicles-scrolled');

  // Scheduler (tab 3)
  await clickNavTabByIndex(page, 3, ADMIN_TABS);
  await capture(page, '07-admin-scheduler');

  // Live Tracking (tab 4)
  await clickNavTabByIndex(page, 4, ADMIN_TABS);
  await waitForTransition(page, 2000);
  await capture(page, '08-admin-live-tracking');

  // Users (tab 5)
  await clickNavTabByIndex(page, 5, ADMIN_TABS);
  await capture(page, '09-admin-users');
  await page.mouse.wheel(0, 400);
  await waitForTransition(page, 1000);
  await capture(page, '09-admin-users-scrolled');

  // Reports (tab 6)
  await clickNavTabByIndex(page, 6, ADMIN_TABS);
  await waitForTransition(page, 2000);
  await capture(page, '10-admin-reports');
  await page.mouse.wheel(0, 500);
  await waitForTransition(page, 1000);
  await capture(page, '10-admin-reports-scrolled');

  // Settings (tab 7)
  await clickNavTabByIndex(page, 7, ADMIN_TABS);
  await capture(page, '11-admin-settings');
});

// ============================================================
// TECHNICIAN — single test, one login, all screens
// ============================================================
test('02 - Technician full walkthrough', async ({ page }) => {
  test.setTimeout(120000);

  await page.goto(FLUTTER_URL);
  await login(page, USERS.technician.username, USERS.technician.password);

  // May see GPS consent screen or dashboard
  await capture(page, '12-technician-dashboard');

  // Try scrolling to see more
  await page.mouse.wheel(0, 300);
  await waitForTransition(page, 1000);
  await capture(page, '12-technician-dashboard-scrolled');

  // My Jobs (tab 1)
  await clickNavTabByIndex(page, 1, TECH_TABS);
  await capture(page, '13-technician-my-jobs');
  await page.mouse.wheel(0, 400);
  await waitForTransition(page, 1000);
  await capture(page, '13-technician-my-jobs-scrolled');
});

// ============================================================
// SWAGGER API DOCS (no login needed)
// ============================================================
test('03 - Swagger API docs', async ({ page }) => {
  const backendUrl = process.env.E2E_BASE_URL || 'http://localhost:3000';
  await page.goto(`${backendUrl}/swagger`);
  await page.waitForLoadState('networkidle');
  await page.waitForTimeout(2000);
  await capture(page, '14-swagger-api-docs');

  await page.mouse.wheel(0, 800);
  await page.waitForTimeout(1000);
  await capture(page, '14-swagger-scrolled');

  await page.mouse.wheel(0, 800);
  await page.waitForTimeout(1000);
  await capture(page, '14-swagger-scrolled-2');
});
