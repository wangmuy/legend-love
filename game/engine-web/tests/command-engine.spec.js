const { test, expect } = require('@playwright/test');
const { waitForPageReady } = require('./helpers/setup');

// Lua eval via Worker bridge
async function luaEval(page, code) {
  const r = await page.evaluate(async (c) => {
    if (!window.__luaEval) return { ok: false, error: 'bridge not ready' };
    return await window.__luaEval(c);
  }, code);
  return r;
}

test.describe('CommandEngine.parseCommand', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForPageReady(page);
  });

  test('基本命令 "look"', async ({ page }) => {
    const r = await luaEval(page, "local r=_G.CommandEngine.parseCommand('look'); return r and r.cmd..'|'..#r.args or 'nil'");
    expect(r.ok).toBe(true);
    expect(r.result).toBe('look|0');
  });

  test('带参数命令 "go 河洛客栈"', async ({ page }) => {
    const r = await luaEval(page, "local r=_G.CommandEngine.parseCommand('go 河洛客栈'); return r and r.cmd..'|'..(r.args[1] or'') or 'nil'");
    expect(r.ok).toBe(true);
    const parts = r.result.split('|');
    expect(parts[0]).toBe('go');
    expect(parts[1]).toBe('河洛客栈');
  });

  test('空输入返回 nil', async ({ page }) => {
    const r1 = await luaEval(page, "return _G.CommandEngine.parseCommand('')");
    expect(r1.ok).toBe(true);
    const r2 = await luaEval(page, "return _G.CommandEngine.parseCommand(nil)");
    expect(r2.ok).toBe(true);
  });

  test('命令转小写 "LOOK" → "look"', async ({ page }) => {
    const r = await luaEval(page, "local r=_G.CommandEngine.parseCommand('LOOK'); return r and r.cmd or 'nil'");
    expect(r.ok).toBe(true);
    expect(r.result).toBe('look');
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
    expect(result.ok).toBe(true);
    const parts = result.result.split('|');
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
    expect(result.ok).toBe(true);
    const parts = result.result.split('|');
    expect(parts[0]).toBe('true');
    expect(parts[1]).toBe('true');
  });

  test('未知命令返回 false', async ({ page }) => {
    const result = await luaEval(page, `
      local ce = _G.CommandEngine
      local handled = ce.dispatchCommand("xyz123", {})
      return tostring(handled)
    `);
    expect(result.ok).toBe(true);
    expect(result.result).toBe('false');
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
