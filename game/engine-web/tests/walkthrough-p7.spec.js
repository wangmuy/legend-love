// quick_pass_game.md: 福威镖局→天宁寺→梅庄→黑木崖→丐帮→桃花岛→主角居
const { test, expect } = require('@playwright/test');
const { waitForPageReady, waitForGameReady } = require('./helpers/setup');
const { saveTestState, loadTestState, gotoScene, flushSaveCache, loadSaveCache } = require('./helpers/walkthrough');
const { cmd, getT, noE } = require('./helpers/term');

const SETTLE = 5000;

test('P7: 福威→天宁→梅庄→黑木崖→丐帮→桃花岛→主角居', async ({ page }) => {
  test.setTimeout(300000);
  loadSaveCache('bridge-p6.json');
  await page.goto('/'); await waitForPageReady(page); await waitForGameReady(page); await page.waitForTimeout(2000);

  expect(await loadTestState(page, 62)).toBe(true);

  // 福威镖局/溪山行旅图
  expect(await gotoScene(page, '福威鏢局')).toBeGreaterThan(0);
  let t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 福威镖局');

  // 天宁寺/《连城诀》
  expect(await gotoScene(page, '天寧寺')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 71)).toBe(true);
  console.log('  ✓ 天宁寺');

  // 梅庄/黑木令
  expect(await loadTestState(page, 71)).toBe(true);
  expect(await gotoScene(page, '梅莊')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 梅庄');

  // 黑木崖/《笑傲江湖》
  expect(await gotoScene(page, '黑木崖')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 黑木崖');

  // 丐帮/《天龙八部》
  expect(await gotoScene(page, '丐幫')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 72)).toBe(true);
  console.log('  ✓ 丐帮');

  // 桃花岛/《射雕英雄传》
  expect(await loadTestState(page, 72)).toBe(true);
  expect(await gotoScene(page, '桃花島')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 桃花岛');

  // 主角居
  expect(await gotoScene(page, '主角的家')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 主角居');

  expect(await noE(page)).toBeTruthy();
  flushSaveCache('bridge-p7.json');
  console.log('  ✓ P7 完成');
});
