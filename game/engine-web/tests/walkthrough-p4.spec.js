// quick_pass_game.md: 苗人凤居→蝴蝶谷→程瑛→黑龙潭→一灯居→闫基居
const { test, expect } = require('@playwright/test');
const { waitForPageReady } = require('./helpers/setup');
const { saveTestState, loadTestState, gotoScene, flushSaveCache, loadSaveCache } = require('./helpers/walkthrough');
const { cmd, getT, noE } = require('./helpers/term');

const SETTLE = 5000;

test('P4: 苗人凤→蝴蝶谷→程瑛→黑龙潭→一灯居→闫基居', async ({ page }) => {
  test.setTimeout(300000);
  loadSaveCache('bridge-p3.json');
  await page.goto('/'); await waitForPageReady(page); await page.waitForTimeout(3000);

  // 苗人凤居/退敌
  expect(await loadTestState(page, 32)).toBe(true);
  expect(await gotoScene(page, '苗人鳳居')).toBeGreaterThan(0);
  let t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 苗人凤居');

  // 蝴蝶谷/铲子/胡青牛加入
  expect(await gotoScene(page, '蝴蝶谷')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  await cmd(page, 'choose 5'); await page.waitForTimeout(3000);  // 胡青牛(第5NPC)
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);  // 对话
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 是(加入)
  t = await getT(page); expect(t).toContain('胡青牛');
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 蝴蝶谷(胡青牛加入)');

  // 恒山派
  expect(await gotoScene(page, '恒山派')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  console.log('  ✓ 恒山派');

  // 蜘蛛洞
  expect(await gotoScene(page, '蜘蛛洞')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  console.log('  ✓ 蜘蛛洞');

  // 悦来客栈/令狐冲喝酒
  expect(await gotoScene(page, '悅來客棧')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  await cmd(page, 'choose 3'); await page.waitForTimeout(3000);  // 令狐冲(第3NPC)
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);  // 对话
  t = await getT(page); expect(t).toContain('令狐冲');
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 悦来客栈(令狐冲)');

  // 程瑛加入
  expect(await gotoScene(page, '程瑛居')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  await cmd(page, 'choose 2'); await page.waitForTimeout(3000);  // 程英(第2NPC)
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);  // 对话
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 是(加入)
  t = await getT(page); expect(t).toContain('程英');
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 41)).toBe(true);
  console.log('  ✓ 程瑛居(程瑛加入)');

  // 黑龙潭
  expect(await loadTestState(page, 41)).toBe(true);
  expect(await gotoScene(page, '黑龍潭')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 黑龙潭');

  // 一灯居
  expect(await gotoScene(page, '一燈居')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 一灯居');

  // 黑龙潭(二刷, 获得桃花岛位置) → 闫基居/七星海棠
  expect(await gotoScene(page, '閰基居')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 42)).toBe(true);
  console.log('  ✓ 闫基居');

  expect(await noE(page)).toBeTruthy();
  flushSaveCache('bridge-p4.json');
  console.log('  ✓ P4 完成');
});
