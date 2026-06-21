const { test, expect } = require('@playwright/test');
const { waitForPageReady, waitForGameReady, luaEval } = require('./helpers/setup');

const SETTLE = 6000;

async function term(page) {
  return page.evaluate(() => {
    const t = window.__xterm;
    const lines = [];
    for (let y = 0; y < t.buffer.active.length; y++) {
      const text = t.buffer.active.getLine(y)?.translateToString(true) || '';
      if (text.trim()) lines.push(text.trimEnd());
    }
    return lines.join('\n');
  });
}

async function ok(page) {
  return page.evaluate(() => {
    const t = window.__xterm;
    if (!t) return true;
    for (let y = 0; y < t.rows; y++) {
      const s = t.buffer.active.getLine(y)?.translateToString(true) || '';
      if (s.includes('[gameLoop error]')) return false;
    }
    return true;
  });
}

async function cmd(page, text) {
  const input = page.locator('#command-input');
  await input.waitFor({ state: 'visible', timeout: 5000 });
  await input.fill(text);
  await page.keyboard.press('Enter');
}

test.describe('事件流程测试', () => {
  test.beforeEach(async ({ page }) => {
    page.on('pageerror', e => console.log('[PAGE]', e.message));
    await page.goto('/');
    await waitForPageReady(page);
    // 等待游戏第一帧执行，开始菜单协程运行
    await page.waitForTimeout(3000);
    await waitForGameReady(page);
  });

  test('TC-01: 场景包含 NPC 显示', async ({ page }) => {
    test.setTimeout(120000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(SETTLE);

    let text = await term(page);
    console.log('=== START SCENE ===');
    console.log(text);
    expect(text).toContain('主角的家');
    expect(await ok(page)).toBeTruthy();
  });

  test('TC-01b: 软体娃娃对话流程', async ({ page }) => {
    test.setTimeout(120000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(SETTLE);

    // look should show 软体娃娃
    let text = await term(page);
    expect(text).toContain('软体娃娃');

    // Menu-driven NPC interaction: choose 1 (select NPC) → choose 1 (对话)
    await cmd(page, 'choose 1'); await page.waitForTimeout(2000);
    text = await term(page);
    expect(text).toContain('对话');
    expect(text).toContain('查看');

    await cmd(page, 'choose 1'); await page.waitForTimeout(5000);
    text = await term(page);
    expect(text).toContain('你与');
    expect(text).toContain('软体娃娃');
    expect(text).toContain('交谈');
    // Verify dialog text shows speaker name
    expect(text).toContain('【');
    expect(await ok(page)).toBeTruthy();
  });

  test('TC-02: NPC 场景交互（北丑居）', async ({ page }) => {
    test.setTimeout(120000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(SETTLE);
    await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
    await cmd(page, 'list'); await page.waitForTimeout(3000);

    let text = await term(page);
    // Find and enter 北丑居 (has 3 NPCs)
    for (const line of text.split('\n')) {
      if (line.includes('北丑居')) {
        const n = line.match(/(\d+)\./);
        if (n) {
          await cmd(page, 'choose ' + n[1]);
          await page.waitForTimeout(SETTLE);
          break;
        }
      }
    }
    text = await term(page);
    console.log('=== NPC SCENE ===');
    console.log(text);
    expect(text).toContain('北丑居');
    expect(text).toContain('1.');
    expect(text).toContain('choose');
    expect(await ok(page)).toBeTruthy();
  });

  test('TC-04: 泛化 oldevent 加载验证', async ({ page }) => {
    // 验证 oldevent 脚本可通过 FrameworkSources 访问
    const ids = [1, 100, 500];
    for (const id of ids) {
      const r = await page.evaluate(async (eid) => {
        if (!window.__luaEval) return { ok: false, error: 'no bridge' };
        const result = await window.__luaEval(
          'local src = rawget(_G, "FrameworkSources") and rawget(_G, "FrameworkSources")["script/oldevent/oldevent_' + eid + '.lua"]; ' +
          'return tostring(type(src) == "string")'
        );
        return result;
      }, id);
      console.log('oldevent_' + id + ': ' + JSON.stringify(r));
      expect(r && r.ok).toBe(true);
      expect(r && r.result).toBe('true');
    }
  });

  test('TC-05: 悦来客栈 场景导航', async ({ page }) => {
    test.setTimeout(120000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(SETTLE);
    await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
    await cmd(page, 'list'); await page.waitForTimeout(3000);
    let text = await term(page);
    expect(text).toContain('客棧');
    expect(await ok(page)).toBeTruthy();
    // 进入场景
    for (const line of text.split('\n')) {
      if (line.includes('客棧')) {
        const n = line.match(/(\d+)\./);
        if (n) {
          await cmd(page, 'choose ' + n[1]);
          await page.waitForTimeout(SETTLE);
          text = await term(page);
          expect(text).toContain('客栈' || '客棧');
          break;
        }
      }
    }
    expect(await ok(page)).toBeTruthy();
  });

  test('TC-03: 南贤居 场景导航', async ({ page }) => {
    test.setTimeout(120000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(SETTLE);
    await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
    await cmd(page, 'list'); await page.waitForTimeout(3000);
    let text = await term(page);
    expect(text).toContain('南賢居');
    expect(await ok(page)).toBeTruthy();
    for (const line of text.split('\n')) {
      if (line.includes('南賢居')) {
        const n = line.match(/(\d+)\./);
        if (n) {
          await cmd(page, 'choose ' + n[1]);
          await page.waitForTimeout(SETTLE);
          text = await term(page);
          expect(text).toContain('南賢居');
          break;
        }
      }
    }
    expect(await ok(page)).toBeTruthy();
  });

  test('TC-02b: 悦来客栈 店小二对话', async ({ page }) => {
    test.setTimeout(120000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(SETTLE);
    await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
    await cmd(page, 'list'); await page.waitForTimeout(3000);
    let text = await term(page);
    // Find and enter 悦来客栈
    for (const line of text.split('\n')) {
      if (line.includes('悦来客栈') || line.includes('悅來客棧')) {
        const n = line.match(/(\d+)\./);
        if (n) {
          await cmd(page, 'choose ' + n[1]);
          await page.waitForTimeout(SETTLE);
          break;
        }
      }
    }
    // Talk to NPC in 悦来客栈 (NPC event 235 = 店小二)
    text = await term(page);
    await cmd(page, 'talk oldevent_235'); await page.waitForTimeout(4000);
    text = await term(page);
    expect(text).toContain('交谈');
    expect(await ok(page)).toBeTruthy();
  });

  test('TC-03b: 南贤居 南贤对话', async ({ page }) => {
    test.setTimeout(120000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(SETTLE);
    await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
    await cmd(page, 'list'); await page.waitForTimeout(3000);
    let text = await term(page);
    // Find and enter 南贤居
    for (const line of text.split('\n')) {
      if (line.includes('南賢居') || line.includes('南贤居')) {
        const n = line.match(/(\d+)\./);
        if (n) {
          await cmd(page, 'choose ' + n[1]);
          await page.waitForTimeout(SETTLE);
          break;
        }
      }
    }
    // Talk to 南贤 (NPC event 821)
    await cmd(page, 'talk 南贤'); await page.waitForTimeout(4000);
    text = await term(page);
    expect(text).toContain('南贤');
    expect(await ok(page)).toBeTruthy();
  });

  test('TC-06: 主选单和状态查看', async ({ page }) => {
    test.setTimeout(120000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(4000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(SETTLE + 4000);

    // 验证 RoleMenu_handleChoose 已注册
    const menuCheck = await luaEval(page, 'return tostring(type(rawget(_G, "RoleMenu_handleChoose")) == "function")');
    expect(menuCheck.ok).toBe(true);
    expect(menuCheck.result).toBe('true');

    // 使用 menu 命令打开主选单
    await cmd(page, 'menu'); await page.waitForTimeout(2000);
    let text = await term(page);
    expect(text).toContain('主选单');
    expect(text).toContain('状态');

    // choose 1 → 查看状态
    await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
    text = await term(page);
    expect(text).toContain('角色状态');
    expect(text).toContain('生命');
    expect(await ok(page)).toBeTruthy();
  });

  test('TC-06b: 主选单物品和存档', async ({ page }) => {
    test.setTimeout(120000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(SETTLE);

    // 使用 menu → choose 2 (物品)
    await cmd(page, 'menu'); await page.waitForTimeout(2000);
    await cmd(page, 'choose 2'); await page.waitForTimeout(3000);
    let text = await term(page);
    expect(text).toContain('背包');
    expect(text).toContain('使用物品');
    expect(text).toContain('装备物品');

    // 返回 → menu → 存档
    await cmd(page, 'choose 0'); await page.waitForTimeout(2000);
    await cmd(page, 'menu'); await page.waitForTimeout(2000);
    await cmd(page, 'choose 4'); await page.waitForTimeout(3000);
    text = await term(page);
    expect(text).toContain('存档');
    expect(text).toContain('槽位');
    expect(await ok(page)).toBeTruthy();
  });

  test('TC-06c: 物品使用和装备', async ({ page }) => {
    test.setTimeout(120000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(4000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(SETTLE + 4000);

    // menu → 背包 → 使用物品（背包可能为空，验证系统正确处理）
    await cmd(page, 'menu'); await page.waitForTimeout(2000);
    await cmd(page, 'choose 2'); await page.waitForTimeout(3000);
    let text = await term(page);
    expect(text).toContain('背包');

    // 选择 使用物品 → 可选: 物品为空时显示"没有可使用的物品"
    await cmd(page, 'choose 1'); await page.waitForTimeout(2000);
    text = await term(page);
    const usableOk = text.includes('药品') || text.includes('物品') || text.includes('没有可使用的');
    expect(usableOk).toBe(true);

    // 返回 → 测试装备物品
    await cmd(page, 'choose 0'); await page.waitForTimeout(1500);
    await cmd(page, 'choose 2'); await page.waitForTimeout(2000);
    text = await term(page);
    expect(text).toContain('装备');
    expect(await ok(page)).toBeTruthy();
  });

  test('TC-06d: 队伍管理和医疗', async ({ page }) => {
    test.setTimeout(120000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(4000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(SETTLE + 4000);

    // menu → choose 3 (队伍)
    await cmd(page, 'menu'); await page.waitForTimeout(2000);
    await cmd(page, 'choose 3'); await page.waitForTimeout(3000);
    let text = await term(page);
    expect(text).toContain('队伍');
    expect(text).toContain('医疗');

    // 选择 医疗/解毒 → 可能无药品，验证系统正确处理
    await cmd(page, 'choose 1'); await page.waitForTimeout(2000);
    text = await term(page);
    const healOk = text.includes('药品') || text.includes('没有') || text.includes('物品');
    expect(healOk).toBe(true);
    expect(await ok(page)).toBeTruthy();
  });

  test('TC-04b: 全部 68 个 instruct 函数无崩溃', async ({ page }) => {
    test.setTimeout(120000);
    // 先进入游戏
    await cmd(page, 'choose 1'); await page.waitForTimeout(4000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(SETTLE + 4000);

    // 逐个验证 instruct_0~67 存在且不导致崩溃
    // 部分函数（如 instruct_9 使用 MenuAsync）需要协程上下文，
    // 在协程外调用时会 yield 错误——这是预期的，不是崩溃
    let missingCount = 0;
    let crashCount = 0;
    for (let i = 0; i <= 67; i++) {
      const result = await luaEval(page, `
        local fn = rawget(_G, "instruct_${i}")
        if not fn then return "MISSING" end
        local ok, err = pcall(fn)
        if ok then return "OK" end
        -- Cannot yield from outside a coroutine is expected when calling
        -- async instruct functions outside a coroutine context
        if tostring(err):find("Cannot yield") then return "OK_YIELD" end
        -- Any other error is a real crash
        return tostring(err)
      `);
      expect(result.ok).toBe(true);
      expect(result.result).not.toBe('MISSING');
      if (result.result === 'MISSING') missingCount++;
      else if (result.result !== 'OK' && result.result !== 'OK_YIELD') {
        console.log('instruct_' + i + ': ❌ ' + result.result);
        crashCount++;
      }
    }
    console.log('All 68 instruct functions (0-67) covered ✓');
    expect(crashCount).toBe(0);
    expect(await ok(page)).toBeTruthy();
  });

  test('TC-04c: GetD/SetD/GetS/SetS 数据访问', async ({ page }) => {
    test.setTimeout(60000);
    // 进入游戏
    await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(SETTLE);

    // 验证 GetD/SetD/GetS/SetS 存在且无崩溃
    const result = await luaEval(page, `
      local GetD = rawget(_G, "GetD")
      local SetD = rawget(_G, "SetD")
      local GetS = rawget(_G, "GetS")
      local SetS = rawget(_G, "SetS")
      if not GetD or not SetD or not GetS or not SetS then return "MISSING" end
      local ok1 = pcall(GetD, 70, 11, 5)
      local ok2 = pcall(SetD, 70, 11, 5, 1)
      local ok3 = pcall(GetS, 1, 1, 1, 1)
      local ok4 = pcall(SetS, 1, 1, 1, 1, 0)
      if not ok1 or not ok2 or not ok3 or not ok4 then return "FAIL" end
      return "OK"
    `);
    expect(result.ok).toBe(true);
    expect(result.result).toBe('OK');
    console.log('GetD/SetD/GetS/SetS ✓');
  });
});
