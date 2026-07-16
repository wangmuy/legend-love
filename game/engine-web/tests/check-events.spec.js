// Quick diagnostic: check events data
const { test } = require('@playwright/test');
const { waitForPageReady } = require('./helpers/setup');
test('check events', async ({ page }) => {
  await page.goto('/'); await waitForPageReady(page); await page.waitForTimeout(3000);
  const r = await page.evaluate(async () => {
    if (!window.__luaEval) return 'no bridge';
    const res = await window.__luaEval([
      'local ds = rawget(_G, "initDataSource")',
      'local ev = ds and ds["events"]',
      'local arr = ev and ev["events"]',
      'if not arr then return "no events array" end',
      'local cnt = 0; local s50 = 0; local extra20 = 0',
      'for _, e in ipairs(arr) do',
      '  cnt = cnt + 1',
      '  if e.sceneId == 50 then s50 = s50 + 1 end',
      '  if e.eventExtra and e.eventExtra > 0 then extra20 = extra20 + 1 end',
      'end',
      'return "total=" .. cnt .. " s50=" .. s50 .. " extra>0=" .. extra20',
    ].join('; '));
    return res && res.ok ? res.result : 'fail';
  });
  console.log('RESULT:', r);
});
