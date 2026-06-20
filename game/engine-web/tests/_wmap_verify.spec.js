const { test, expect } = require('@playwright/test');
const { waitForPageReady } = require('./helpers/setup');

test('WmapHandlers exists', async ({ page }) => {
  test.setTimeout(120000);
  await page.goto('/');
  await waitForPageReady(page);
  await page.waitForTimeout(1000);
  const r = await page.evaluate(async () => {
    if (!window.__luaEval) return 'no bridge';
    const r1 = await window.__luaEval('return type(rawget(_G,"WmapHandlers"))');
    const r2 = await window.__luaEval('return type(rawget(_G,"WmapHandlers") and rawget(_G,"WmapHandlers").look)');
    return { handlers: r1, look: r2 };
  });
  console.log(JSON.stringify(r));
  expect(r.handlers && r.handlers.ok).toBe(true);
  expect(r.handlers.result).toBe('table');
  expect(r.look && r.look.ok).toBe(true);
  expect(r.look.result).toBe('function');
});
