const { test } = require('@playwright/test');
test('diagnose override', async ({ page }) => {
  const logs = [];
  page.on('console', msg => logs.push(msg.type() + ': ' + msg.text().substring(0,120)));
  await page.goto('/');
  await page.waitForFunction(() => window.__workerReady === true, { timeout: 30000 });
  await page.waitForTimeout(1000);
  // Check Lua globals via Worker message
  for (const l of logs) console.log(l);
});
