const { test, expect } = require('@playwright/test');

test('Slice 3 menu + dialog interaction', async ({ page }) => {
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  await page.goto('/');
  await page.waitForTimeout(10000);

  const input = page.locator('#command-input');
  await input.waitFor({ state: 'visible', timeout: 5000 });

  // Step 1: Choose "重新开始" from start menu
  await input.fill('choose 1');
  await page.keyboard.press('Enter');
  await page.waitForTimeout(5000);

  // Step 2: Accept attribute by choosing "是"
  await input.fill('choose 1');
  await page.keyboard.press('Enter');
  await page.waitForTimeout(5000);

  const termText = await page.evaluate(() => {
    const t = window.__xterm;
    if (!t) return '(no xterm)';
    const lines = [];
    const totalLines = t.buffer.active.length;
    for (let y = Math.max(0, totalLines - 80); y < totalLines; y++) {
      const l = t.buffer.active.getLine(y)?.translateToString(true) || '';
      if (l.trim()) lines.push(l);
    }
    return lines.join('\n');
  });
  console.log('=== TERMINAL (last 80 lines) ===');
  console.log(termText);
  console.log('=== ERRORS ===');
  console.log(JSON.stringify(errors));
  expect(termText).not.toContain('Bootstrap failed');
});