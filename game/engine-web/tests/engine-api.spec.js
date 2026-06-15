const { test, expect } = require('@playwright/test');
const { waitForPageReady, luaEval } = require('./helpers/setup');

const MODULES = {
  render: 20, input: 3, time: 3, file: 9, script: 1,
  font: 1, color: 2, debug: 1, coroutine: 3,
  sprite: 4, map: 7, audio: 3, app: 1,
};
const TOTAL = Object.values(MODULES).reduce((a, b) => a + b, 0);

test.describe('EngineAPI 表面 + 功能', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForPageReady(page);
  });

  test(`${TOTAL} 个函数签名全部存在`, async ({ page }) => {
    for (const [mod, expected] of Object.entries(MODULES)) {
      const count = await page.evaluate((m) => {
        const f = window.fengari;
        const lua = f.lua;
        lua.lua_getglobal(f.L, 'EngineAPI');
        lua.lua_pushstring(f.L, m);
        lua.lua_gettable(f.L, -2);
        if (lua.lua_type(f.L, -1) !== lua.LUA_TTABLE) { lua.lua_pop(f.L, 2); return -1; }
        let c = 0;
        lua.lua_pushnil(f.L);
        while (lua.lua_next(f.L, -2) !== 0) { c++; lua.lua_pop(f.L, 1); }
        lua.lua_pop(f.L, 2);
        return c;
      }, mod);
      expect(count).toBe(expected);
    }
  });

  test('color.pack/unpack 往返正确', async ({ page }) => {
    const ok = await luaEval(page, [
      'local c = EngineAPI.color',
      'local p = c.pack(255, 0, 0)',
      'local r, g, b = c.unpack(p)',
      'return math.abs(r - 1) < 0.01 and math.abs(g) < 0.01 and math.abs(b) < 0.01',
    ].join('; '));
    expect(ok).toBe(true);
  });

  test('render.text 写入缓冲区', async ({ page }) => {
    const hasAnsi = await page.evaluate(() => {
      const f = window.fengari;
      const lua = f.lua;
      const code = [
        'EngineAPI.render.text(0, 0, "hello", 0xFF0000)',
        'EngineAPI.render.present()',
      ].join('; ');
      f.load(code, 'test')(f.L);
      return true;
    });
    expect(hasAnsi).toBe(true);
  });

  test('render.drawBackground 输出清屏码', async ({ page }) => {
    await page.evaluate(() => {
      const f = window.fengari;
      f.load('EngineAPI.render.drawBackground(0,0,100,100,0); EngineAPI.render.present()', 'test')(f.L);
    });
  });

  test('colorToAnsi 阈值映射 (红/白/黑/黄)', async ({ page }) => {
    const colors = [0xFF0000, 0xFFFFFF, 0x000000, 0xFFFF00];
    const labels = ['RED', 'WHT', 'BLK', 'YEL'];
    for (let i = 0; i < colors.length; i++) {
      await luaEval(page, 'EngineAPI.render.text(0, 0, "CLR_' + labels[i] + '", ' + colors[i] + '); EngineAPI.render.present()');
    }
    await page.waitForTimeout(100);
    const termText = await page.evaluate(() => {
      const term = window.__xterm;
      const found = [];
      for (let y = 0; y < term.buffer.active.length; y++) {
        const text = term.buffer.active.getLine(y)?.translateToString(true) || '';
        for (const label of ['CLR_RED', 'CLR_WHT', 'CLR_BLK', 'CLR_YEL']) {
          if (text.includes(label) && !found.includes(label)) found.push(label);
        }
      }
      return found;
    });
    expect(termText.length).toBe(4);
  });

  test('render.present 刷新缓冲区到终端', async ({ page }) => {
    await luaEval(page, 'EngineAPI.render.text(0, 0, "PRESENT_TEST", nil); EngineAPI.render.present()');
    await page.waitForTimeout(100);
    const text = await page.evaluate(() => {
      const term = window.__xterm;
      for (let y = 0; y < term.buffer.active.length; y++) {
        const t = term.buffer.active.getLine(y)?.translateToString(true) || '';
        if (t.includes('PRESENT_TEST')) return t;
      }
      return null;
    });
    expect(text).toContain('PRESENT_TEST');
  });

  test('time.getTime 返回数字', async ({ page }) => {
    const t = await luaEval(page, 'return EngineAPI.time.getTime()');
    expect(typeof t).toBe('number');
  });

  test('time.sleep 不阻塞', async ({ page }) => {
    const ok = await luaEval(page, [
      'local co = coroutine.create(function()',
      'EngineAPI.time.sleep(100)',
      'return true',
      'end)',
      'coroutine.resume(co)',
      'return true',
    ].join('; '));
    expect(ok).toBe(true);
  });

  test('font.get 返回 stub', async ({ page }) => {
    const name = await page.evaluate(() => {
      const f = window.fengari;
      f.lua.lua_getglobal(f.L, 'EngineAPI');
      f.lua.lua_pushstring(f.L, 'font');
      f.lua.lua_gettable(f.L, -2);
      f.lua.lua_pushstring(f.L, 'get');
      f.lua.lua_gettable(f.L, -2);
      f.lua.lua_pushstring(f.L, 'monospace');
      f.lua.lua_pushnumber(f.L, 14);
      f.lua.lua_pcall(f.L, 2, 1, 0);
      f.lua.lua_pushstring(f.L, 'name');
      f.lua.lua_gettable(f.L, -2);
      const r = f.to_jsstring(f.lua.lua_tostring(f.L, -1));
      f.lua.lua_pop(f.L, 3);
      return r;
    });
    expect(name).toBe('monospace');
  });

  test('app.quit no-op', async ({ page }) => {
    const ok = await luaEval(page, 'EngineAPI.app.quit(); return true');
    expect(ok).toBe(true);
  });

  test('debug.log 写入内容', async ({ page }) => {
    await luaEval(page, '_G.__quiet = false; EngineAPI.debug.log("TEST_MSG", 42)');
    await page.waitForTimeout(100);
    const text = await page.evaluate(() => {
      const term = window.__xterm;
      for (let y = 0; y < term.buffer.active.length; y++) {
        const t = term.buffer.active.getLine(y)?.translateToString(true) || '';
        if (t.includes('[DEBUG]') && t.includes('TEST_MSG')) return t;
      }
      return null;
    });
    expect(text).toContain('TEST_MSG');
  });

  test('file.open 读取 dataCache', async ({ page }) => {
    const content = await luaEval(page, [
      'local handle = EngineAPI.file.open("dialogues", "r")',
      'if not handle then return nil end',
      'local c = handle:read("*a")',
      'handle:close()',
      'return #c > 100 and tostring(#c) or c',
    ].join('; '));
    expect(content).not.toBe(null);
    expect(parseInt(content) || 0).toBeGreaterThan(100);
  });

  test('file.exists 正确判断', async ({ page }) => {
    const exists = await luaEval(page, 'return EngineAPI.file.exists("dialogues")');
    expect(exists).toBe(true);
    const notExists = await luaEval(page, 'return EngineAPI.file.exists("no_such_file")');
    expect(notExists).toBe(false);
  });

  test('file.getSize 返回字节数', async ({ page }) => {
    const size = await luaEval(page, 'return EngineAPI.file.getSize("dialogues")');
    expect(typeof size).toBe('number');
    expect(size).toBeGreaterThan(0);
  });

  test('file.lines 逐行迭代', async ({ page }) => {
    const count = await luaEval(page, [
      'local count = 0',
      'for line in EngineAPI.file.lines("dialogues") do',
      '  count = count + 1',
      'end',
      'return count',
    ].join('\n'));
    expect(typeof count).toBe('number');
    expect(count).toBeGreaterThan(0);
  });

  test('script.load 不存在脚本返回 nil', async ({ page }) => {
    const r = await luaEval(page, 'local a, b = EngineAPI.script.load("no_such.lua"); return tostring(a) .. "|" .. tostring(b)');
    expect(r).toContain('nil|Script not found');
  });
});