const { test, expect } = require('@playwright/test');
const { waitForPageReady, getLuaGlobal } = require('./helpers/setup');

test.describe('Lua VM 初始化', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForPageReady(page);
  });

  test('fengari 全局对象存在', async () => {
    // 在 setup.js 的 waitForPageReady 中已隐式验证
  });

  test('JSBridge 表已注入', async ({ page }) => {
    const bridge = await getLuaGlobal(page, 'JSBridge');
    expect(bridge.type).toBe('table');
    const hasWrite = await page.evaluate(() => {
      const f = window.fengari;
      f.lua.lua_getglobal(f.L, 'JSBridge');
      f.lua.lua_pushstring(f.L, 'write');
      f.lua.lua_gettable(f.L, -2);
      const t = f.lua.lua_type(f.L, -1);
      f.lua.lua_pop(f.L, 2);
      return t === f.lua.LUA_TFUNCTION;
    });
    expect(hasWrite).toBe(true);
  });

  test('EngineAPI 表存在', async ({ page }) => {
    const api = await getLuaGlobal(page, 'EngineAPI');
    expect(api.type).toBe('table');
  });

  test('lib 表存在', async ({ page }) => {
    const lib = await getLuaGlobal(page, 'lib');
    expect(lib.type).toBe('table');
  });

  test('dataCache._loaded == true', async ({ page }) => {
    const loaded = await page.evaluate(() => {
      const f = window.fengari;
      f.lua.lua_getglobal(f.L, 'dataCache');
      f.lua.lua_pushstring(f.L, '_loaded');
      f.lua.lua_gettable(f.L, -2);
      const v = f.lua.lua_toboolean(f.L, -1);
      f.lua.lua_pop(f.L, 2);
      return v;
    });
    expect(loaded).toBe(true);
  });
});