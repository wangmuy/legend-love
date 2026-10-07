const { test, expect } = require('@playwright/test');
const { waitForPageReady } = require('./helpers/setup');
const { saveTestState, loadTestState } = require('./helpers/walkthrough');

const SETTLE = 5000;

async function cmd(page, text) {
  const input = page.locator('#command-input');
  await input.waitFor({ state: 'visible', timeout: 5000 });
  await input.fill(text);
  await page.keyboard.press('Enter');
}

async function getText(page) {
  return page.evaluate(() => {
    const term = window.__xterm;
    if (!term) return '';
    const lines = [];
    for (let y = 0; y < term.buffer.active.length; y++) {
      const s = term.buffer.active.getLine(y)?.translateToString(true) || '';
      if (s.trim()) lines.push(s.trimEnd());
    }
    return lines.join('\n');
  });
}

test.describe('Tile event debug', () => {
  test('阎基居 tile event trigger', async ({ page }) => {
    test.setTimeout(120000);
    await page.goto('/');
    await waitForPageReady(page);
    await page.waitForTimeout(3000);

    // 开局
    await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(SETTLE);

    // 离开家到MMAP
    await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);

    // 去阎基居
    await cmd(page, 'list'); await page.waitForTimeout(2000);
    await cmd(page, 'choose 72'); await page.waitForTimeout(SETTLE);

    // 看输出
    let text = await getText(page);
    console.log('DEBUG OUTPUT:', text);

    // 触发tile event #4
    await cmd(page, 'choose 4'); await page.waitForTimeout(5000);

    // 看输出（含DEBUG信息）
    text = await getText(page);
    console.log('DEBUG AFTER CHOOSE 4:', text);

    // 检查DEBUG信息
    expect(text).toContain('[DEBUG]');
  });
});
