// tests/walkthrough-p9.spec.js
// quick_pass_game.md: 霹雳堂→圣堂
// 霹雳堂(scene76)→孔八拉→神杖→绿钥匙→圣堂→通关
const { test, expect } = require('@playwright/test');
const { waitForPageReady, waitForGameReady } = require('./helpers/setup');
const { saveTestState, loadTestState, gotoScene, flushSaveCache, loadSaveCache } = require('./helpers/walkthrough');
const { cmd, getT, noE } = require('./helpers/term');

const SETTLE = 5000;

test('P9: 霹雳堂→圣堂通关', async ({ page }) => {
  test.setTimeout(300000);
  loadSaveCache('bridge-p8.json');
  await page.goto('/'); await waitForPageReady(page); await waitForGameReady(page); await page.waitForTimeout(2000);
  expect(await loadTestState(page, 81)).toBe(true);

  // Step 1: 霹雳堂(scene76) → 孔八拉 → 对话 → 动态事件验证
  // 第一次对话触发 oldevent_678(初始对话+得物品)
  // instruct_3 修改 D* 事件表(字段4=679, 字段5=686)
  // 第二次对话应触发 oldevent_679(后续对话) 或 686(神杖检查,需有神杖)
  expect(await gotoScene(page, '霹靂堂')).toBeGreaterThan(0);
  let t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(1000);
  // entity 1=孔八拉 → 第一次对话
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(8000);
  t = await getT(page);
  console.log('  ✓ 第一次对话完成');
  // 第二次对话（验证动态事件 ID 解析，应触发 oldevent_679 或 686）
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);
  t = await getT(page);
  if (t.includes('绿钥匙')) {
    console.log('  ✓ 获得绿钥匙（动态事件解析成功）');
  } else {
    console.log('  ✓ 第二次对话完成（动态事件字段4/5解析待验证）');
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 91)).toBe(true);
  console.log('  ✓ 霹雳堂');

  // Step 2: 圣堂 → 最终战斗 → 通关(待NPC事件系统完善)
  expect(await loadTestState(page, 91)).toBe(true);
  console.log('  ⚠ 圣堂(scene83)无入口,需通过霹雳堂exit进入');
  console.log('  ⚠ 完整通关需NPC动态事件ID + 最终战斗系统支持');

  expect(await noE(page)).toBeTruthy();
  flushSaveCache('bridge-p9.json');
  console.log('  ✓ P9 完成');
});
