// tests/walkthrough-p2.spec.js
// quick_pass_game.md: 回族部落→胡斐加入→冰火岛→绝情谷→大轮寺
const { test, expect } = require('@playwright/test');
const { waitForPageReady } = require('./helpers/setup');
const { saveTestState, loadTestState, gotoScene, flushSaveCache, loadSaveCache } = require('./helpers/walkthrough');
const { cmd, getT, noE } = require('./helpers/term');

const SETTLE = 5000;

test('P2: 回族→胡斐→冰火岛→绝情谷→大轮寺', async ({ page }) => {
  test.setTimeout(300000);
  loadSaveCache('bridge-p1.json');
  await page.goto('/'); await waitForPageReady(page); await page.waitForTimeout(3000);
  expect(await loadTestState(page, 16)).toBe(true);

  // 无量山洞已在P1完成，从回族部落继续
  expect(await gotoScene(page, '回族部落')).toBeGreaterThan(0);
  let t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 回族部落');

  // 胡斐加入 — Entity 1/2=搜索, Entity 3=胡斐
  expect(await gotoScene(page, '胡斐居')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 3'); await page.waitForTimeout(3000);  // 选胡斐(entity 3)
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);  // 选"对话"
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 选"是"（加入）
  t = await getT(page); expect(t).toContain('胡斐');
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 21)).toBe(true);
  console.log('  ✓ 胡斐加入');

  // 冰火岛/金毛
  expect(await loadTestState(page, 21)).toBe(true);
  expect(await gotoScene(page, '冰火島')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 冰火岛');

  // 绝情谷/玉玺/断肠草/君子剑/玉蜂针
  expect(await loadTestState(page, 21)).toBe(true);
  expect(await gotoScene(page, '絕情谷')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 22)).toBe(true);
  console.log('  ✓ 绝情谷');

  // 冰蚕洞(TODO:无入口) → 船停大轮寺东 → 大轮寺
  expect(await loadTestState(page, 22)).toBe(true);
  expect(await gotoScene(page, '大輪寺')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 大轮寺');

  expect(await noE(page)).toBeTruthy();
  flushSaveCache('bridge-p2.json');
  console.log('  ✓ P2 完成');
});
