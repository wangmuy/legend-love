// quick_pass_game.md: 百花谷→绝情谷底→古墓→燕子坞→泰山派
const { test, expect } = require('@playwright/test');
const { waitForPageReady } = require('./helpers/setup');
const { saveTestState, loadTestState, gotoScene, flushSaveCache, loadSaveCache } = require('./helpers/walkthrough');
const { cmd, getT, noE } = require('./helpers/term');

const SETTLE = 5000;

test('P3: 百花谷→绝情谷底→古墓→燕子坞→泰山派', async ({ page }) => {
  test.setTimeout(300000);
  loadSaveCache('bridge-p2.json');
  await page.goto('/'); await waitForPageReady(page); await page.waitForTimeout(3000);

  // 昆仑仙境(无入口跳过)→神雕洞(无数据跳过)→百花谷
  expect(await loadTestState(page, 22)).toBe(true);
  expect(await gotoScene(page, '百花谷')).toBeGreaterThan(0);
  let t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 百花谷');

  // 绝情谷底
  expect(await gotoScene(page, '絕情谷底')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 31)).toBe(true);
  console.log('  ✓ 绝情谷底');

  // 古墓/小龙女加入
  expect(await loadTestState(page, 31)).toBe(true);
  expect(await gotoScene(page, '古墓')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 古墓');

  // 燕子坞/慕容复、王语嫣加入
  expect(await gotoScene(page, '燕子塢')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 32)).toBe(true);
  console.log('  ✓ 燕子坞');

  // 泰山派/洗手帖
  expect(await loadTestState(page, 32)).toBe(true);
  expect(await gotoScene(page, '泰山派')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 泰山派');

  expect(await noE(page)).toBeTruthy();
  flushSaveCache('bridge-p3.json');
  console.log('  ✓ P3 完成');
});
