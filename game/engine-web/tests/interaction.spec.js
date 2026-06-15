const { test, expect } = require('@playwright/test');
const { waitForPageReady } = require('./helpers/setup');

async function getAllTermLines(page) {
  return page.evaluate(() => {
    const term = window.__xterm;
    if (!term) return [];
    const lines = [];
    for (let y = 0; y < term.buffer.active.length; y++) {
      const text = term.buffer.active.getLine(y)?.translateToString(true) || '';
      if (text.trim()) lines.push(text.trimEnd());
    }
    return lines;
  });
}

test.describe('交互流程', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForPageReady(page);
    await page.waitForTimeout(6000);
  });

  test('输入命令后终端显示回显 > 命令名', async ({ page }) => {
    const input = page.locator('#command-input');
    await input.waitFor({ state: 'visible', timeout: 5000 });
    await input.fill('hello');
    await page.keyboard.press('Enter');
    await page.waitForTimeout(1000);

    const lines = await getAllTermLines(page);
    expect(lines.some(l => l.includes('> hello'))).toBe(true);
  });

  test('Lua 侧能消费输入事件（处理后队列为空）', async ({ page }) => {
    const input = page.locator('#command-input');
    await input.fill('world');
    await page.keyboard.press('Enter');
    await page.waitForTimeout(2000);

    const empty = await page.evaluate(() => {
      const f = window.fengari;
      const lua = f.lua;
      lua.lua_getglobal(f.L, 'JSBridge');
      lua.lua_pushstring(f.L, 'getEventCount');
      lua.lua_gettable(f.L, -2);
      lua.lua_pcall(f.L, 0, 1, 0);
      const count = lua.lua_tonumber(f.L, -1);
      lua.lua_pop(f.L, 2);
      return count;
    });
    expect(empty).toBe(0);
  });

  test('未知命令显示提示信息', async ({ page }) => {
    const input = page.locator('#command-input');
    await input.fill('xyzzy');
    await page.keyboard.press('Enter');
    await page.waitForTimeout(2000);

    const lines = await getAllTermLines(page);
    expect(lines.some(l => l.includes('未知命令'))).toBe(true);
  });
});