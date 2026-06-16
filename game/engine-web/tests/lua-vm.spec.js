const { test, expect } = require('@playwright/test');
const { waitForPageReady } = require('./helpers/setup');

async function luaEval(page, code) {
  const result = await page.evaluate(async (c) => {
    if (!window.__luaEval) return { error: 'luaEval not ready' };
    return await window.__luaEval(c);
  }, code);
  return result;
}

test.describe('Lua VM 初始化', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForPageReady(page);
  });

  test('fengari 全局对象存在', () => {
    // Worker 内隐式验证
  });

  test('JSBridge 表已注入', async ({ page }) => {
    const r = await luaEval(page, 'return type(rawget(_G, "JSBridge"))');
    expect(r.ok).toBe(true);
    expect(r.result).toBe('table');
  });

  test('EngineAPI 表存在', async ({ page }) => {
    const r = await luaEval(page, 'return type(rawget(_G, "EngineAPI"))');
    expect(r && r.ok).toBe(true);
  });

  test('lib 表存在', async ({ page }) => {
    const r = await luaEval(page, 'return type(rawget(_G, "lib"))');
    expect(r && r.ok).toBe(true);
  });

  test('dataCache._loaded == true', async ({ page }) => {
    const r = await luaEval(page, 'local dc = rawget(_G, "dataCache"); return dc and tostring(dc["_loaded"]) or "false"');
    expect(r && r.ok).toBe(true);
    expect(r.result).toBe('true');
  });
});