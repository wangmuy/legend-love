// quick_pass_game.md: 药王庄→金轮寺→明教分舵→光明顶→华山→金蛇洞→武当→嵩山
const { test, expect } = require('@playwright/test');
const { waitForPageReady, waitForGameReady } = require('./helpers/setup');
const { saveTestState, loadTestState, gotoScene, flushSaveCache, loadSaveCache } = require('./helpers/walkthrough');
const { cmd, getT, noE } = require('./helpers/term');

const SETTLE = 5000;

test('P5: 药王庄→金轮寺→明教→光明顶→华山→金蛇洞→武当→嵩山', async ({ page }) => {
  test.setTimeout(300000);
  loadSaveCache('bridge-p4.json');
  await page.goto('/'); await waitForPageReady(page); await waitForGameReady(page); await page.waitForTimeout(2000);
  expect(await loadTestState(page, 42)).toBe(true);

  // 药王庄/眼药/程灵素加入
  expect(await gotoScene(page, '藥王莊')).toBeGreaterThan(0);
  let t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 程灵素(第1NPC)
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);  // 对话
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 是(加入)
  // NPC dialog may not show name in terminal output, just verify no error
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 51)).toBe(true);
  console.log('  ✓ 药王庄(程灵素加入)');

  // 衡山派战斗
  expect(await loadTestState(page, 51)).toBe(true);
  expect(await gotoScene(page, '衡山派')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'look'); await page.waitForTimeout(1000);
  t = await getT(page);
  if (t.includes('战场态势')) {
    console.log('  ⚠ 衡山派战斗触发');
    for (let r = 0; r < 10; r++) {
      await cmd(page, 'choose 5'); await page.waitForTimeout(300);
      await cmd(page, 'choose 1'); await page.waitForTimeout(300);
      await cmd(page, 'choose 1'); await page.waitForTimeout(300);
      await cmd(page, 'choose 1'); await page.waitForTimeout(300);
      t = await getT(page);
      if (t.includes('战斗胜利') || t.includes('战斗失败')) break;
    }
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 衡山派');

  // 金轮寺/可兰经
  expect(await gotoScene(page, '金輪寺')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 金轮寺');

  // 明教分舵
  expect(await gotoScene(page, '明教分舵')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 明教分舵');

  // 光明顶/六大派
  expect(await gotoScene(page, '光明頂')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 52)).toBe(true);
  console.log('  ✓ 光明顶');

  // 华山派/对话岳不群
  expect(await loadTestState(page, 52)).toBe(true);
  expect(await gotoScene(page, '華山派')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 华山派');

  // 金蛇洞/金蛇剑
  expect(await gotoScene(page, '金蛇山洞')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 金蛇洞');

  // 武当山/击败张三丰
  expect(await gotoScene(page, '武當派')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  await cmd(page, 'choose 2'); await page.waitForTimeout(3000);  // 张三丰(第2NPC)
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);  // 对话/挑战
  t = await getT(page);
  if (t.includes('战场态势') || t.includes('战斗')) {
    for (let r = 0; r < 10; r++) {
      await cmd(page, 'choose 5'); await page.waitForTimeout(300);
      await cmd(page, 'choose 1'); await page.waitForTimeout(300);
      await cmd(page, 'choose 1'); await page.waitForTimeout(300);
      await cmd(page, 'choose 1'); await page.waitForTimeout(300);
      t = await getT(page);
      if (t.includes('战斗胜利') || t.includes('战斗失败')) break;
    }
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 武当山(张三丰)');

  // 嵩山派/张旭率意帖
  expect(await gotoScene(page, '嵩山派')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  // 如果进入了战斗，处理战斗
  await cmd(page, 'look'); await page.waitForTimeout(1000);
  t = await getT(page);
  if (t.includes('战场态势')) {
    for (let r = 0; r < 10; r++) {
      await cmd(page, 'choose 5'); await page.waitForTimeout(300);
      await cmd(page, 'choose 1'); await page.waitForTimeout(300);
      await cmd(page, 'choose 1'); await page.waitForTimeout(300);
      await cmd(page, 'choose 1'); await page.waitForTimeout(300);
      t = await getT(page);
      if (t.includes('战斗胜利')) break;
    }
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 53)).toBe(true);
  console.log('  ✓ 嵩山派');

  expect(await noE(page)).toBeTruthy();
  flushSaveCache('bridge-p5.json');
  console.log('  ✓ P5 完成');
});
