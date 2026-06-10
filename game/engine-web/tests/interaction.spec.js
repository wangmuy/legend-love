const { test, expect } = require('@playwright/test');
const { waitForPageReady } = require('./helpers/setup');
const { readAllTermLines } = require('./helpers/term-reader');

test.describe('交互流程', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForPageReady(page);
  });

  test('输入文字后终端显示回显', async ({ page }) => {
    const input = page.locator('#command-input');
    await input.fill('hello');
    await page.keyboard.press('Enter');
    await page.waitForTimeout(300);
    const lines = await readAllTermLines(page);
    expect(lines.some(l => l.includes('> hello'))).toBe(true);
  });

  test('Lua 侧能消费输入事件', async ({ page }) => {
    const input = page.locator('#command-input');
    await input.fill('world');
    await page.keyboard.press('Enter');
    await page.waitForTimeout(200);
    const event = await page.evaluate(() => {
      const f = window.fengari;
      const lua = f.lua;
      lua.lua_getglobal(f.L, 'JSBridge');
      lua.lua_pushstring(f.L, 'getEvent');
      lua.lua_gettable(f.L, -2);
      lua.lua_pcall(f.L, 0, 1, 0);
      const t = lua.lua_type(f.L, -1);
      if (t !== lua.LUA_TTABLE) { lua.lua_pop(f.L, 2); return null; }
      lua.lua_pushstring(f.L, 'data');
      lua.lua_gettable(f.L, -2);
      const data = f.to_jsstring(lua.lua_tostring(f.L, -1));
      lua.lua_pop(f.L, 3);
      return data;
    });
    expect(event).toBe('world');
  });
});