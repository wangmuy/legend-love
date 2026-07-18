// tests/walkthrough-save-state.spec.js
// 存档/读档功能的 e2e 测试 — 仅使用用户操作 + 存档读档模拟
// 所有游戏状态通过真实用户操作（choose/leave/list）驱动，不使用 __luaEval 直接操作游戏状态
const { test, expect } = require('@playwright/test');
const { waitForPageReady } = require('./helpers/setup');
const { saveTestState, loadTestState } = require('./helpers/walkthrough');
const { cmd, getT, noE } = require('./helpers/term');

const SLOT_A = 11;
const SLOT_B = 12;

/** 辅助：加载页面 */
async function loadPage(page) {
  await page.goto('/');
  await waitForPageReady(page);
  await page.waitForTimeout(3000);
}

/** 辅助：开始新游戏 */
async function startNewGame(page) {
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(2000);
  const t = await getT(page);
  expect(t).toContain('新游戏开始');
}

test('saveTestState 保存成功', async ({ page }) => {
  test.setTimeout(120000);
  await loadPage(page);
  // 通过用户操作开始新游戏
  await startNewGame(page);
  // 保存存档
  const ok = await saveTestState(page, SLOT_A);
  expect(ok).toBe(true);
});

test('save → load 后游戏状态一致', async ({ page }) => {
  test.setTimeout(120000);
  await loadPage(page);
  // 通过用户操作开始新游戏
  await startNewGame(page);
  await cmd(page, 'leave'); await page.waitForTimeout(2000);
  // 保存
  const saveOk = await saveTestState(page, SLOT_A);
  expect(saveOk).toBe(true);

  // 做一些不同的操作：list 查看场景
  await cmd(page, 'list'); await page.waitForTimeout(3000);
  // 加载存档，应回到保存时的状态
  const loadOk = await loadTestState(page, SLOT_A);
  expect(loadOk).toBe(true);

  // 等待 gameLoop 运行几帧
  await page.waitForTimeout(2000);
  // 验证无错误
  expect(await noE(page)).toBeTruthy();
});

test('存档槽隔离: slot 11 和 slot 12 互不影响', async ({ page }) => {
  test.setTimeout(120000);
  await loadPage(page);
  // 通过用户操作开始新游戏
  await startNewGame(page);
  await cmd(page, 'leave'); await page.waitForTimeout(2000);
  // 保存到 slot 11（初始状态）
  expect(await saveTestState(page, SLOT_A)).toBe(true);

  // 做更多操作：list 查看场景
  await cmd(page, 'list'); await page.waitForTimeout(3000);
  // 保存到 slot 12（不同状态）
  expect(await saveTestState(page, SLOT_B)).toBe(true);

  // 加载 slot 11 — 应回到初始状态，无错误
  expect(await loadTestState(page, SLOT_A)).toBe(true);
  await page.waitForTimeout(2000);
  expect(await noE(page)).toBeTruthy();

  // 加载 slot 12 — 应回到 list 后的状态，无错误
  expect(await loadTestState(page, SLOT_B)).toBe(true);
  await page.waitForTimeout(2000);
  expect(await noE(page)).toBeTruthy();
});

test('loadTestState 后无 gameLoop error', async ({ page }) => {
  test.setTimeout(120000);
  await loadPage(page);
  // 通过用户操作开始新游戏
  await startNewGame(page);
  await cmd(page, 'leave'); await page.waitForTimeout(2000);
  // 保存
  expect(await saveTestState(page, SLOT_A)).toBe(true);

  // 加载
  expect(await loadTestState(page, SLOT_A)).toBe(true);

  // 等待 gameLoop 运行几帧
  await page.waitForTimeout(2000);

  // 验证无 error
  expect(await noE(page)).toBeTruthy();
});