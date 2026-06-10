const { test, expect } = require('@playwright/test');
const { waitForPageReady, luaEval } = require('./helpers/setup');

test('debug luaEval', async ({ page }) => {
  const logs = [];
  page.on('console', msg => {
    if (msg.type() === 'log') logs.push(msg.text());
  });
  await page.goto('/');
  await waitForPageReady(page);

  console.log('=== Terminal output sample ===');
  for (const l of logs.slice(-15)) console.log('  ' + l);
  console.log('============================');

  const r = await luaEval(page, 'return 42');
  console.log('DEBUG return 42:', JSON.stringify(r));
  expect(r).toBe(42);
});
