// 一次性探测 spec：打印大地图 list 真实输出（验证后删除）
const { test } = require('@playwright/test');
const { cmd, getT } = require('./helpers/term');
const { waitForPageReady, waitForGameReady } = require('./helpers/setup');

test('mmap list real output', async ({ page }) => {
  test.setTimeout(180000);
  await page.goto('/');
  await waitForPageReady(page);
  await waitForGameReady(page);
  await cmd(page, 'choose 1');
  await page.waitForTimeout(2500);
  await cmd(page, 'choose 1');
  await page.waitForTimeout(2500);
  await cmd(page, 'leave');
  await page.waitForTimeout(2000);
  await cmd(page, 'list');
  // 轮询等待 list 输出（异步渲染）
  await page.waitForFunction(() => {
    const term = window.__xterm;
    if (!term) return false;
    for (let y = 0; y < term.buffer.active.length; y++) {
      const s = term.buffer.active.getLine(y)?.translateToString(true) || '';
      if (s.includes('可去场景')) return true;
    }
    return false;
  }, { timeout: 30000 });
  await page.waitForTimeout(1000);
  const out = await getT(page);
  console.log('===REAL_LIST_BEGIN===');
  console.log(out);
  console.log('===REAL_LIST_END===');
  expect(out).toContain('可去场景');
});
const { expect } = require('@playwright/test');
