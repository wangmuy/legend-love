const { test, expect } = require('@playwright/test');
const { waitForPageReady } = require('./helpers/setup');

// Lua eval with JSON string conversion for table returns
async function luaEval(page, code) {
  return page.evaluate((c) => {
    const f = window.fengari;
    const lua = f.lua;
    try {
      const fn = f.load(c, 'eval');
      const raw = fn();
      if (raw === null || raw === undefined) return { __type: 'nil' };
      if (typeof raw === 'boolean') return { __type: 'boolean', value: raw };
      if (typeof raw === 'number') return { __type: 'number', value: raw };
      if (typeof raw === 'string') return { __type: 'string', value: raw };
      return { __type: 'unknown', raw: String(raw) };
    } catch (e) {
      return { __type: 'error', value: (e && e.message) || String(e) };
    }
  }, code);
}

test.describe('CommandEngine.parseCommand', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForPageReady(page);
  });

  test('基本命令 "look"', async ({ page }) => {
    // Access via C API since load() doesn't convert tables
    const result = await page.evaluate(() => {
      const f = window.fengari;
      const lua = f.lua;
      lua.lua_getglobal(f.L, 'CommandEngine');
      const cmdType = lua.lua_type(f.L, -1);
      if (cmdType !== lua.LUA_TTABLE) { lua.lua_pop(f.L, 1); return { error: 'CommandEngine not table' }; }
      lua.lua_pushstring(f.L, 'parseCommand');
      lua.lua_gettable(f.L, -2);
      lua.lua_pushstring(f.L, 'look');
      const status = lua.lua_pcall(f.L, 1, 1, 0);
      if (status !== 0) {
        const err = lua.lua_tostring(f.L, -1);
        lua.lua_pop(f.L, 2);
        return { error: 'pcall: ' + f.to_jsstring(err) };
      }
      const t = lua.lua_type(f.L, -1);
      if (t === lua.LUA_TNIL) { lua.lua_pop(f.L, 2); return { error: 'nil result' }; }
      if (t !== lua.LUA_TTABLE) { lua.lua_pop(f.L, 2); return { error: 'not table: ' + t }; }
      lua.lua_pushstring(f.L, 'cmd');
      lua.lua_gettable(f.L, -2);
      const cmd = lua.lua_type(f.L, -1) === lua.LUA_TSTRING ? f.to_jsstring(lua.lua_tostring(f.L, -1)) : null;
      lua.lua_pop(f.L, 1);
      
      lua.lua_pushstring(f.L, 'raw');
      lua.lua_gettable(f.L, -2);
      const raw = lua.lua_type(f.L, -1) === lua.LUA_TSTRING ? f.to_jsstring(lua.lua_tostring(f.L, -1)) : null;
      lua.lua_pop(f.L, 1);
      
      // Check args length
      lua.lua_pushstring(f.L, 'args');
      lua.lua_gettable(f.L, -2);
      const argsLen = lua.lua_type(f.L, -1) === lua.LUA_TTABLE ? lua.lua_rawlen(f.L, -1) : -1;
      lua.lua_pop(f.L, 1);
      
      lua.lua_pop(f.L, 2); // pop table + CommandEngine
      return { cmd: cmd, raw: raw, argsLen: argsLen };
    });
    expect(result.error).toBeUndefined();
    expect(result.cmd).toBe('look');
    expect(result.argsLen).toBe(0);
    expect(result.raw).toBe('look');
  });

  test('带参数命令 "go 河洛客栈"', async ({ page }) => {
    const result = await page.evaluate(() => {
      const f = window.fengari;
      const lua = f.lua;
      lua.lua_getglobal(f.L, 'CommandEngine');
      lua.lua_pushstring(f.L, 'parseCommand');
      lua.lua_gettable(f.L, -2);
      lua.lua_pushstring(f.L, 'go 河洛客栈');
      lua.lua_pcall(f.L, 1, 1, 0);
      
      lua.lua_pushstring(f.L, 'cmd');
      lua.lua_gettable(f.L, -2);
      const cmd = lua.lua_type(f.L, -1) === lua.LUA_TSTRING ? f.to_jsstring(lua.lua_tostring(f.L, -1)) : null;
      lua.lua_pop(f.L, 1);
      
      lua.lua_pushstring(f.L, 'args');
      lua.lua_gettable(f.L, -2);
      lua.lua_pushinteger(f.L, 1);
      lua.lua_gettable(f.L, -2);
      const arg1 = lua.lua_type(f.L, -1) === lua.LUA_TSTRING ? f.to_jsstring(lua.lua_tostring(f.L, -1)) : null;
      lua.lua_pop(f.L, 2);
      
      lua.lua_pushstring(f.L, 'raw');
      lua.lua_gettable(f.L, -2);
      const raw = lua.lua_type(f.L, -1) === lua.LUA_TSTRING ? f.to_jsstring(lua.lua_tostring(f.L, -1)) : null;
      lua.lua_pop(f.L, 1);
      
      lua.lua_pop(f.L, 2);
      return { cmd: cmd, arg1: arg1, raw: raw };
    });
    expect(result.cmd).toBe('go');
    expect(result.arg1).toBe('河洛客栈');
    expect(result.raw).toBe('go 河洛客栈');
  });

  test('空输入返回 nil', async ({ page }) => {
    let result = await page.evaluate(() => {
      const f = window.fengari;
      const lua = f.lua;
      lua.lua_getglobal(f.L, 'CommandEngine');
      lua.lua_pushstring(f.L, 'parseCommand');
      lua.lua_gettable(f.L, -2);
      lua.lua_pushstring(f.L, '');
      lua.lua_pcall(f.L, 1, 1, 0);
      const t = lua.lua_type(f.L, -1);
      const isNil = t === lua.LUA_TNIL;
      lua.lua_pop(f.L, 2);
      return { r1: isNil };
    });
    expect(result.r1).toBe(true);
    
    result = await page.evaluate(() => {
      const f = window.fengari;
      const lua = f.lua;
      lua.lua_getglobal(f.L, 'CommandEngine');
      lua.lua_pushstring(f.L, 'parseCommand');
      lua.lua_gettable(f.L, -2);
      lua.lua_pushnil(f.L);
      lua.lua_pcall(f.L, 1, 1, 0);
      const t = lua.lua_type(f.L, -1);
      const isNil = t === lua.LUA_TNIL;
      lua.lua_pop(f.L, 2);
      return { r2: isNil };
    });
    expect(result.r2).toBe(true);
  });

  test('命令转小写 "LOOK" → "look"', async ({ page }) => {
    const result = await page.evaluate(() => {
      const f = window.fengari;
      const lua = f.lua;
      lua.lua_getglobal(f.L, 'CommandEngine');
      lua.lua_pushstring(f.L, 'parseCommand');
      lua.lua_gettable(f.L, -2);
      lua.lua_pushstring(f.L, 'LOOK');
      lua.lua_pcall(f.L, 1, 1, 0);
      lua.lua_pushstring(f.L, 'cmd');
      lua.lua_gettable(f.L, -2);
      const cmd = lua.lua_type(f.L, -1) === lua.LUA_TSTRING ? f.to_jsstring(lua.lua_tostring(f.L, -1)) : null;
      lua.lua_pop(f.L, 3);
      return cmd;
    });
    expect(result).toBe('look');
  });
});

test.describe('CommandEngine 命令注册表', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForPageReady(page);
  });

  test('注册和查询', async ({ page }) => {
    // Use Lua code instead of C API for command registration
    const result = await luaEval(page, `
      local ce = _G.CommandEngine
      ce.registerCommands(100, {look={handler=function()end, description="查看"}})
      local cmds = ce.getCommands(100)
      local cmdsNil = ce.getCommands(200)
      return tostring(cmds.look ~= nil) .. "|" .. (cmds.look.description or "") .. "|" .. tostring(#cmdsNil == 0)
    `);
    expect(result.__type).toBe('string');
    const parts = result.value.split('|');
    expect(parts[0]).toBe('true');
    expect(parts[1]).toBe('查看');
    expect(parts[2]).toBe('true');
  });
});

test.describe('CommandEngine.dispatchCommand', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForPageReady(page);
  });

  test('已知命令被分发', async ({ page }) => {
    // Use Lua eval that returns JSON string for table results
    const result = await luaEval(page, `
      local ce = _G.CommandEngine
      local called = false
      local status = (_G.JY and _G.JY.Status) or 0
      ce.registerCommands(status, {testcmd={handler=function(args) called = true end, description="test"}})
      local handled = ce.dispatchCommand("testcmd", {})
      return tostring(handled) .. "|" .. tostring(called)
    `);
    expect(result.__type).toBe('string');
    const parts = result.value.split('|');
    expect(parts[0]).toBe('true');
    expect(parts[1]).toBe('true');
  });

  test('未知命令返回 false', async ({ page }) => {
    const result = await luaEval(page, `
      local ce = _G.CommandEngine
      local handled = ce.dispatchCommand("xyz123", {})
      return tostring(handled)
    `);
    expect(result.__type).toBe('string');
    expect(result.value).toBe('false');
  });
});

test.describe('CommandEngine help 命令 (E2E)', () => {
  test('help 输出', async ({ page }) => {
    await page.goto('/');
    await waitForPageReady(page);

    const input = page.locator('#command-input');
    await input.waitFor({ state: 'visible', timeout: 5000 });
    await input.fill('help');
    await page.keyboard.press('Enter');
    await page.waitForTimeout(3000);

    const termText = await page.evaluate(() => {
      const t = window.__xterm;
      if (!t) return '(no xterm)';
      const lines = [];
      for (let y = 0; y < t.buffer.active.length; y++) {
        const l = t.buffer.active.getLine(y)?.translateToString(true) || '';
        if (l.trim()) lines.push(l);
      }
      return lines.join('\n');
    });
    console.log('=== HELP OUTPUT ===');
    console.log(termText);
    expect(termText).toContain('可用命令');
  });

  test('未知命令提示', async ({ page }) => {
    await page.goto('/');
    await waitForPageReady(page);

    const input = page.locator('#command-input');
    await input.waitFor({ state: 'visible', timeout: 5000 });
    await input.fill('zzzunknown');
    await page.keyboard.press('Enter');
    await page.waitForTimeout(3000);

    const termText = await page.evaluate(() => {
      const t = window.__xterm;
      if (!t) return '(no xterm)';
      const lines = [];
      for (let y = 0; y < t.buffer.active.length; y++) {
        const l = t.buffer.active.getLine(y)?.translateToString(true) || '';
        if (l.trim()) lines.push(l);
      }
      return lines.join('\n');
    });
    console.log('=== UNKNOWN COMMAND OUTPUT ===');
    console.log(termText);
    expect(termText).toContain('未知命令');
  });
});
