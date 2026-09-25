const { test, expect } = require('@playwright/test');
const { waitForPageReady } = require('./helpers/setup');
test('smoke check: page loads', async ({ page }) => {
  const errors = [];
  page.on('console', msg => { if (msg.type() === 'error') errors.push(msg.text()); });
  page.on('pageerror', err => errors.push(err.message));
  await page.goto('/');
  await waitForPageReady(page);
  const ready = await page.evaluate(() => window.__workerReady);
  console.log('workerReady:', ready);
  if (errors.length) console.log('ERRORS:', errors.join('\n'));
  expect(ready).toBe(true);
});