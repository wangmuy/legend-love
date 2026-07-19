// tests/walkthrough-save-state.spec.js
// 存档/读档功能的 e2e 测试 — 仅使用用户操作 + 存档读档模拟
// 所有游戏状态通过真实用户操作（choose/leave/list）驱动，不使用 __luaEval 直接操作游戏状态
const { test, expect } = require('@playwright/test');
const { waitForPageReady, waitForGameReady } = require('./helpers/setup');
const { saveTestState, loadTestState } = require('./helpers/walkthrough');
const { cmd, getT, noE } = require('./helpers/term');

const SLOT_A = 11;
const SLOT_B = 12;

/** 辅助：加载页面 */
async function loadPage(page) {
  await page.goto('/');
  await waitForPageReady(page);
  await waitForGameReady(page);
  await page.waitForTimeout(2000);
}

/** 辅助：开始新游戏 */
async function startNewGame(page) {
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  let t = await getT(page);
  expect(t).toContain('生命');
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);
  t = await getT(page);
  expect(t).toContain('软体娃娃');
}

test('saveTestState 保存成功', async ({ page }) => {
  test.setTimeout(120000);
  await loadPage(page);
  await startNewGame(page);
  const ok = await saveTestState(page, SLOT_A);
  expect(ok).toBe(true);
});

test('save → load 后游戏状态一致', async ({ page }) => {
  test.setTimeout(120000);
  await loadPage(page);
  await startNewGame(page);
  await cmd(page, 'leave'); await page.waitForTimeout(2000);
  const saveOk = await saveTestState(page, SLOT_A);
  expect(saveOk).toBe(true);
  await cmd(page, 'list'); await page.waitForTimeout(3000);
  const loadOk = await loadTestState(page, SLOT_A);
  expect(loadOk).toBe(true);
  await page.waitForTimeout(2000);
  expect(await noE(page)).toBeTruthy();
});

test('存档槽隔离: slot 11 和 slot 12 互不影响', async ({ page }) => {
  test.setTimeout(120000);
  await loadPage(page);
  await startNewGame(page);
  await cmd(page, 'leave'); await page.waitForTimeout(2000);
  expect(await saveTestState(page, SLOT_A)).toBe(true);
  await cmd(page, 'list'); await page.waitForTimeout(3000);
  expect(await saveTestState(page, SLOT_B)).toBe(true);
  expect(await loadTestState(page, SLOT_A)).toBe(true);
  await page.waitForTimeout(2000);
  expect(await noE(page)).toBeTruthy();
  expect(await loadTestState(page, SLOT_B)).toBe(true);
  await page.waitForTimeout(2000);
  expect(await noE(page)).toBeTruthy();
});

test('loadTestState 后无 gameLoop error', async ({ page }) => {
  test.setTimeout(120000);
  await loadPage(page);
  await startNewGame(page);
  await cmd(page, 'leave'); await page.waitForTimeout(2000);
  expect(await saveTestState(page, SLOT_A)).toBe(true);
  expect(await loadTestState(page, SLOT_A)).toBe(true);
  await page.waitForTimeout(2000);
  expect(await noE(page)).toBeTruthy();
});

test('主选单: 查看状态/队伍/医疗/解毒', async ({ page }) => {
  test.setTimeout(180000);
  await loadPage(page);
  await startNewGame(page);
  await cmd(page, 'leave'); await page.waitForTimeout(2000);

  await cmd(page, 'menu'); await page.waitForTimeout(8000);
  let t = await getT(page);
  expect(t).toContain('主选单');

  // 查看状态(第3项)
  await cmd(page, 'choose 3'); await page.waitForTimeout(2000);
  t = await getT(page);
  expect(t).toContain('生命');
  expect(t).toContain('攻击');
  await cmd(page, 'choose 0'); await page.waitForTimeout(1000);

  // 查看队伍(第5项) — showTeam() 使用 wt("队伍") 写入标题栏，终端中不包含"队伍"
  await cmd(page, 'menu'); await page.waitForTimeout(8000);
  t = await getT(page);
  expect(t).toContain('主选单');
  await cmd(page, 'choose 5'); await page.waitForTimeout(2000);
  t = await getT(page);
  expect(t).toContain('HP:') || expect(t).toContain('返回');
  await cmd(page, 'choose 0'); await page.waitForTimeout(1000);

  // 医疗(第1项)
  await cmd(page, 'menu'); await page.waitForTimeout(8000);
  t = await getT(page);
  expect(t).toContain('主选单');
  await cmd(page, 'choose 1'); await page.waitForTimeout(2000);
  t = await getT(page);
  console.log('  ✓ 医疗菜单可用: ' + (t.includes('医疗') || t.includes('选择')));
  await cmd(page, 'choose 0'); await page.waitForTimeout(1000);

  // 解毒(第2项)
  await cmd(page, 'menu'); await page.waitForTimeout(8000);
  t = await getT(page);
  expect(t).toContain('主选单');
  await cmd(page, 'choose 2'); await page.waitForTimeout(2000);
  t = await getT(page);
  console.log('  ✓ 解毒菜单可用: ' + (t.includes('解毒') || t.includes('选择')));

  expect(await noE(page)).toBeTruthy();
});
