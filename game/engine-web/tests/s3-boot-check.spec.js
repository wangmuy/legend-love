const { test, expect } = require('@playwright/test');

test('Slice 3 bootstrap check', async ({ page }) => {
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  await page.goto('/');
  await page.waitForTimeout(20000);
  const termText = await page.evaluate(() => {
    const t = window.__xterm;
    if (!t) return '(no xterm)';
    const lines = [];
    const totalLines = t.buffer.active.length;
    for (let y = 0; y < totalLines; y++) {
      const l = t.buffer.active.getLine(y)?.translateToString(true) || '';
      if (l.trim()) lines.push(l);
    }
    return lines.join('\n');
  });
  console.log('=== TERMINAL OUTPUT ===');
  console.log(termText);
  console.log('=== ERRORS ===');
  console.log(JSON.stringify(errors));
  expect(termText).not.toContain('Bootstrap failed');
});