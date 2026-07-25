// quick_pass_game.md: 神龙教→破庙→成昆→沙漠→北丑→灵蛇→渤泥岛→侠客岛
const { test, expect } = require('@playwright/test');
const { waitForPageReady, waitForGameReady } = require('./helpers/setup');
const { saveTestState, loadTestState, gotoScene, flushSaveCache, loadSaveCache } = require('./helpers/walkthrough');
const { cmd, getT, noE } = require('./helpers/term');

const SETTLE = 5000;

test('P6: 神龙教→破庙→成昆→沙漠→北丑→灵蛇→渤泥→侠客', async ({ page }) => {
  test.setTimeout(360000);
  loadSaveCache('bridge-p5.json');
  await page.goto('/'); await waitForPageReady(page); await waitForGameReady(page); await page.waitForTimeout(2000);
  expect(await loadTestState(page, 3)).toBe(true);

  // 神龙教《鹿鼎记》— 洪教主对话(oldevent_609)
  expect(await gotoScene(page, '神龍教')).toBeGreaterThan(0);
  let t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  // entity 1=洪教主, entity 2-3=守卫
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);  // 对话
  t = await getT(page);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 神龙教(洪教主)');

  // 破庙/广陵散
  expect(await gotoScene(page, '破廟')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 1)).toBe(true);
  console.log('  ✓ 破庙');

  // 成昆居
  expect(await loadTestState(page, 1)).toBe(true);
  expect(await gotoScene(page, '成崑居')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 成昆居');

  // 沙漠废墟/《白马啸西风》
  expect(await gotoScene(page, '沙漠廢墟')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 沙漠废墟');

  // 北丑居
  expect(await gotoScene(page, '北丑居')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 2)).toBe(true);
  console.log('  ✓ 北丑居');

  // 灵蛇岛/紫衫龙王
  expect(await loadTestState(page, 2)).toBe(true);
  expect(await gotoScene(page, '靈蛇島')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 灵蛇岛');

  // 渤泥岛/《碧血剑》— 袁承志对话(oldevent_635)
  expect(await gotoScene(page, '浡泥島')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);  // 对话
  t = await getT(page);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 渤泥岛(袁承志)');

  // 侠客岛/《侠客行》— 龙岛主对话(oldevent_353)
  expect(await gotoScene(page, '俠客島')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  // entity 1=张三, 2=李四, 3=龙岛主, 4=木岛主
  await cmd(page, 'choose 3'); await page.waitForTimeout(3000);  // 龙岛主
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);  // 对话
  t = await getT(page);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 3)).toBe(true);
  console.log('  ✓ 侠客岛(龙岛主)');

  expect(await noE(page)).toBeTruthy();
  flushSaveCache('bridge-p6.json');
  console.log('  ✓ P6 完成');
});
