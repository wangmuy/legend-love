const { test, expect } = require('@playwright/test');

test('welcome text + help shows only built-in commands', async ({ page }) => {
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  await page.goto('/');
  await page.waitForTimeout(6000);

  const head = await page.evaluate(() => {
    const t = window.__xterm;
    let out = [];
    for (let y = 0; y < t.buffer.active.length; y++) {
      const l = t.buffer.active.getLine(y)?.translateToString(true) || '';
      if (l.trim()) out.push(l.trim());
    }
    return out;
  });
  expect(head.some(l => l.includes('欢迎'))).toBeTruthy();

  const input = page.locator('#command-input');
  await input.fill('help');
  await page.keyboard.press('Enter');
  await page.waitForTimeout(2000);

  const tail = await page.evaluate(() => {
    const t = window.__xterm;
    const total = t.buffer.active.length;
    let out = [];
    for (let y = Math.max(0, total - 15); y < total; y++) {
      const l = t.buffer.active.getLine(y)?.translateToString(true) || '';
      if (l.trim()) out.push(l.trim());
    }
    return out;
  });

  const helpText = tail.join('\n');
  expect(helpText).toContain('choose');
  expect(helpText).toContain('help');
  expect(helpText).not.toContain('list');
  expect(helpText).not.toContain('go');
  expect(helpText).not.toContain('where');
});
