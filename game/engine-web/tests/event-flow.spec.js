const { test, expect } = require('@playwright/test');
const { waitForPageReady } = require('./helpers/setup');

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
    await page.waitForTimeout(2000);
  });

  test('TC-01: 主角的家场景包含 NPC', async ({ page }) => {
    test.setTimeout(120000);
    await cmd(page, 'choose 1');
    await page.waitForTimeout(3000);
    await cmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE);

    let text = await term(page);
    console.log('=== HOME SCENE ===');
    console.log(text);
    expect(text).toContain('主角的家');
    // 场景应有 NPC 可交互
    expect(text).toContain('1.');
    expect(text).toContain('choose');
    expect(await ok(page)).toBeTruthy();

    // 选择第一个 NPC → 查看子菜单
    await cmd(page, 'choose 1');
    await page.waitForTimeout(2000);
    text = await term(page);
    console.log('=== NPC SUBMENU ===');
    console.log(text);
    expect(text).toContain('对话');
    expect(await ok(page)).toBeTruthy();

    // 选择 对话
    await cmd(page, 'choose 1');
    await page.waitForTimeout(3000);
    text = await term(page);
    console.log('=== DIALOGUE ===');
    console.log(text);
    expect(text).toContain('你与');
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

  test('TC-02: 悦来客栈 场景导航', async ({ page }) => {
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
});
