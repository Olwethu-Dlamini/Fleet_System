// e2e/fixtures/flutter-helpers.js
// Utilities for interacting with Flutter web in Playwright.
// Login uses API + localStorage injection (Flutter canvas can't receive keyboard input).

const SCREENSHOT_DIR = 'screenshots';

/**
 * Wait for Flutter app to finish loading.
 */
async function waitForFlutterReady(page, timeout = 30000) {
  await page.waitForLoadState('domcontentloaded', { timeout });
  await page.waitForTimeout(4000);
}

/**
 * Wait for screen transition to settle.
 */
async function waitForTransition(page, ms = 1500) {
  await page.waitForTimeout(ms);
}

/**
 * Take a named screenshot.
 */
async function capture(page, name) {
  await page.screenshot({
    path: `${SCREENSHOT_DIR}/${name}.png`,
    fullPage: true,
  });
  console.log(`  Captured: ${name}.png`);
}

/**
 * Click a bottom nav tab by position index.
 */
async function clickNavTabByIndex(page, tabIndex, totalTabs) {
  const vp = page.viewportSize();
  const navY = vp.height - 30;
  const tabWidth = vp.width / totalTabs;
  const tabX = tabWidth * tabIndex + tabWidth / 2;
  await page.mouse.click(tabX, navY);
  await waitForTransition(page);
}

/**
 * Login to the Flutter web app via keyboard interaction.
 * Flutter CanvasKit creates hidden <input> elements on Tab focus.
 * Flow: Tab → type username → Tab → type password → Enter to submit.
 */
async function login(page, username, password) {
  await waitForFlutterReady(page);

  // Tab to focus the first text field (username)
  await page.keyboard.press('Tab');
  await page.waitForTimeout(800);
  await page.keyboard.type(username, { delay: 30 });

  // Tab to next field (password)
  await page.keyboard.press('Tab');
  await page.waitForTimeout(800);
  await page.keyboard.type(password, { delay: 30 });

  // Submit with Enter
  await page.keyboard.press('Enter');
  await page.waitForTimeout(4000);

  console.log(`  Logged in as ${username}`);
}

/**
 * Logout by clearing Flutter's localStorage and reloading.
 */
async function logout(page) {
  await page.evaluate(() => {
    const keys = Object.keys(localStorage).filter(k => k.startsWith('flutter.'));
    keys.forEach(k => localStorage.removeItem(k));
  });
  await page.reload();
  await waitForFlutterReady(page);
}

module.exports = {
  waitForFlutterReady,
  waitForTransition,
  capture,
  clickNavTabByIndex,
  login,
  logout,
  SCREENSHOT_DIR,
};
