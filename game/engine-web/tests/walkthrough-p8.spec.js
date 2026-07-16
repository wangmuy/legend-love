// tests/walkthrough-p8.spec.js
// quick_pass_game.md: 闯王山洞→鸳鸯岛
// 闯王山洞(scene5,雪山区): 雪山飞狐+鸯刀+金丝背心
// 鸳鸯岛(scene79,东北角): 鸳鸯刀+千年人参
const { test, expect } = require('@playwright/test');
const { waitForPageReady } = require('./helpers/setup');
const { saveTestState, loadTestState, gotoScene, flushSaveCache, loadSaveCache } = require('./helpers/walkthrough');
const { cmd, getT, noE } = require('./helpers/term');

const SETTLE = 5000;

// 按场景列表索引导航（用于同名场景区分）
async function gotoSceneByIdx(page, idx) {
  await cmd(page, 'leave'); await page.waitForTimeout(500);
  await cmd(page, 'choose 0'); await page.waitForTimeout(300);
  await cmd(page, 'list'); await page.waitForTimeout(3000);
  await cmd(page, 'choose ' + idx); await page.waitForTimeout(SETTLE);
}

test('P8: 闯王山洞→鸳鸯岛', async ({ page }) => {
  test.setTimeout(300000);
  loadSaveCache('bridge-p7.json');
  await page.goto('/'); await waitForPageReady(page); await page.waitForTimeout(3000);
  expect(await loadTestState(page, 71)).toBe(true);

  // Step 1: 闯王山洞(场景列表第19项=scene5) — 雪山飞狐+鸯刀+金丝背心
  await gotoSceneByIdx(page, 19);
  let t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(1000);
  // entity 3=oldevent_54 → 雪山飞狐
  await cmd(page, 'choose 3'); await page.waitForTimeout(2000);
  // entity 5=oldevent_56 → 鸯刀
  await cmd(page, 'choose 5'); await page.waitForTimeout(2000);
  // entity 7=oldevent_58 → 金丝背心
  await cmd(page, 'choose 7'); await page.waitForTimeout(2000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 81)).toBe(true);
  console.log('  ✓ 闯王山洞(雪山飞狐+鸯刀+金丝背心)');

  // Step 2: 鸳鸯岛(场景列表第26项=scene79) — 鸳鸯刀+千年人参
  expect(await loadTestState(page, 81)).toBe(true);
  await gotoSceneByIdx(page, 26);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(1000);
  // entity 2=oldevent_651 → 鸳鸯刀
  await cmd(page, 'choose 2'); await page.waitForTimeout(2000);
  // entity 3=oldevent_652 → 千年人参
  await cmd(page, 'choose 3'); await page.waitForTimeout(2000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 鸳鸯岛(鸳鸯刀+千年人参)');

  expect(await noE(page)).toBeTruthy();
  flushSaveCache('bridge-p8.json');
  console.log('  ✓ P8 完成');
});
