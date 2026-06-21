const { test, expect } = require('@playwright/test');
const { waitForPageReady, waitForGameReady } = require('./helpers/setup');

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

  test('TC-06: 角色管理菜单和状态查看', async ({ page }) => {
    test.setTimeout(120000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(4000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(SETTLE + 4000);

    // 直接通过 luaEval 验证角色管理菜单入口已注册
    const menuCheck = await luaEval(page, 'return tostring(type(rawget(_G, "RoleMenu_handleChoose")) == "function")');
    expect(menuCheck.ok).toBe(true);
    expect(menuCheck.result).toBe('true');

    // 测试状态查看功能
    await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
    let text = await term(page);
    expect(text).toContain('角色状态');
    expect(text).toContain('生命');
    expect(await ok(page)).toBeTruthy();
  });

  test('TC-06b: 角色管理背包和存档菜单', async ({ page }) => {
    test.setTimeout(120000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(SETTLE);

    // 返回主菜单 → 选择背包
    await cmd(page, 'choose 2'); await page.waitForTimeout(3000);
    let text = await term(page);
    expect(text).toContain('背包');

    // 返回 → 选存档
    await cmd(page, 'choose 0'); await page.waitForTimeout(2000);
    text = await term(page);
    expect(text).toContain('角色管理');

    await cmd(page, 'choose 4'); await page.waitForTimeout(3000);
    text = await term(page);
    expect(text).toContain('存档');
    expect(text).toContain('槽位');
    expect(await ok(page)).toBeTruthy();
  });
});
