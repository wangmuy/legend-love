const { test, expect } = require('@playwright/test');
const { waitForPageReady } = require('./helpers/setup');
const { saveTestState, loadTestState, getJYSnapshot } = require('./helpers/walkthrough');

const SLOT_A = 11;
const SLOT_B = 12;

test.describe('Walkthrough save/load state', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForPageReady(page);
  });

  test('saveTestState 保存成功', async ({ page }) => {
    test.setTimeout(60000);
    // 先用 initGameState 初始化一些数据
    const initOk = await page.evaluate(async () => {
      if (!window.__luaEval) return { ok: false, result: 'bridge not ready' };
      return await window.__luaEval([
        'initGameState()',
        'local JY = rawget(_G, "JY")',
        'if not JY then return "no-jy" end',
        'JY.Base = JY.Base or {}',
        'JY.Base["金钱"] = 999',
        'JY.Base["人X"] = 100',
        'JY.Base["人Y"] = 200',
        'return "ok"',
      ].join('; '));
    });
    expect(initOk && initOk.ok).toBe(true);

    const ok = await saveTestState(page, SLOT_A);
    expect(ok).toBe(true);
  });

  test('save → load 后游戏状态一致', async ({ page }) => {
    test.setTimeout(60000);
    // 保存初始状态
    const initSnapshot = await page.evaluate(async () => {
      if (!window.__luaEval) return { ok: false, result: 'bridge not ready' };
      return await window.__luaEval([
        'initGameState()',
        'local JY = rawget(_G, "JY")',
        'JY.Base = JY.Base or {}',
        'JY.Person = JY.Person or {}',
        'JY.Person[0] = JY.Person[0] or {}',
        'JY.Base["金钱"] = 500',
        'JY.Base["人X"] = 364',
        'JY.Base["人Y"] = 284',
        'JY.Person[0]["姓名"] = "测试大侠"',
        'JY.Person[0]["生命"] = 80',
        'JY.Person[0]["生命最大值"] = 100',
        'local snap = encodeSimpleJSON({money=500, posX=364, posY=284, name="测试大侠", hp=80, maxHp=100})',
        'return snap',
      ].join('; '));
    });
    expect(initSnapshot && initSnapshot.ok).toBe(true);

    // 保存
    const saveOk = await saveTestState(page, SLOT_A);
    expect(saveOk).toBe(true);

    // 修改状态并验证不同
    await page.evaluate(async () => {
      if (!window.__luaEval) return;
      await window.__luaEval([
        'local JY = rawget(_G, "JY")',
        'JY.Base["金钱"] = 0',
        'JY.Person[0]["姓名"] = "已修改"',
      ].join('; '));
    });

    // 加载存档
    const loadOk = await loadTestState(page, SLOT_A);
    expect(loadOk).toBe(true);

    // 验证恢复
    const restored = await page.evaluate(async () => {
      if (!window.__luaEval) return { ok: false, result: 'bridge not ready' };
      return await window.__luaEval([
        'local JY = rawget(_G, "JY")',
        'if not JY then return "no-jy" end',
        'local money = JY.Base and JY.Base["金钱"] or 0',
        'local name = JY.Person and JY.Person[0] and JY.Person[0]["姓名"] or ""',
        'return tostring(money) .. "|" .. tostring(name)',
      ].join('; '));
    });
    expect(restored && restored.ok).toBe(true);
    expect(restored.result).toBe('500|测试大侠');
  });

  test('存档槽隔离: slot 11 和 slot 12 互不影响', async ({ page }) => {
    test.setTimeout(60000);
    // 保存不同状态到不同槽位
    await page.evaluate(async () => {
      if (!window.__luaEval) return;
      await window.__luaEval([
        'initGameState()',
        'local JY = rawget(_G, "JY")',
        'JY.Base = JY.Base or {}',
        'JY.Base["金钱"] = 111',
        'saveGameState(11)',
        'JY.Base["金钱"] = 222',
        'saveGameState(12)',
      ].join('; '));
    });

    // 加载 slot 11 → 应为 111
    const load11Ok = await loadTestState(page, 11);
    expect(load11Ok).toBe(true);
    const val11 = await page.evaluate(async () => {
      if (!window.__luaEval) return { ok: false };
      return await window.__luaEval('local JY=rawget(_G,"JY"); return tostring(JY.Base and JY.Base["金钱"] or 0)');
    });
    expect(val11 && val11.ok).toBe(true);
    expect(val11.result).toBe('111');

    // 加载 slot 12 → 应为 222
    const load12Ok = await loadTestState(page, 12);
    expect(load12Ok).toBe(true);
    const val12 = await page.evaluate(async () => {
      if (!window.__luaEval) return { ok: false };
      return await window.__luaEval('local JY=rawget(_G,"JY"); return tostring(JY.Base and JY.Base["金钱"] or 0)');
    });
    expect(val12 && val12.ok).toBe(true);
    expect(val12.result).toBe('222');
  });

  test('loadTestState 后无 gameLoop error', async ({ page }) => {
    test.setTimeout(60000);
    // 先存一个档
    await page.evaluate(async () => {
      if (!window.__luaEval) return;
      await window.__luaEval([
        'initGameState()',
        'local JY = rawget(_G, "JY")',
        'JY.Base = JY.Base or {}',
        'JY.Base["金钱"] = 300',
        'saveGameState(11)',
      ].join('; '));
    });

    const loadOk = await loadTestState(page, 11);
    expect(loadOk).toBe(true);

    // 等待几帧让 gameLoop 运行
    await page.waitForTimeout(2000);

    // 检查无 error
    const hasError = await page.evaluate(() => {
      const term = window.__xterm;
      if (!term) return false;
      for (let y = 0; y < term.rows; y++) {
        const text = term.buffer.active.getLine(y)?.translateToString(true) || '';
        if (text.includes('[gameLoop error]')) return true;
      }
      return false;
    });
    expect(hasError).toBe(false);
  });
});
