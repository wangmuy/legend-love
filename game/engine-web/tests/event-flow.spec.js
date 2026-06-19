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

  test('TC-01: 软体娃娃对话 (oldevent_691)', async ({ page }) => {
    test.setTimeout(120000);
    await cmd(page, 'choose 1');
    await page.waitForTimeout(3000);
    await cmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE);

    let text = await term(page);
    expect(text).toContain('主角的家');
    expect(text).toContain('软体娃娃');
    expect(await ok(page)).toBeTruthy();

    // 选择 软体娃娃 → 对话
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
    // instruct_1 应输出对话文本
    expect(text).toContain('你与');
    expect(text).toContain('交谈');
    expect(await ok(page)).toBeTruthy();

    // WaitKey — 按回车继续
    await cmd(page, '1');
    await page.waitForTimeout(2000);
    text = await term(page);
    console.log('=== AFTER WAITKEY ===');
    console.log(text);
    expect(await ok(page)).toBeTruthy();
  });

  test('TC-04: 泛化 oldevent 执行', async ({ page }) => {
    // 通过 luaEval 直接加载 3 个随机 oldevent 脚本
    const ids = [1, 100, 500];
    for (const id of ids) {
      const r = await page.evaluate(async (eid) => {
        if (!window.__luaEval) return { ok: false, error: 'no bridge' };
        return await window.__luaEval(
          'local fn, err = load(FrameworkSources["script/oldevent/oldevent_' + eid + '.lua"], "@oldevent_' + eid + '"); ' +
          'if not fn then return "load_fail:" .. tostring(err) end; ' +
          'local ok, result = pcall(fn); ' +
          'if not ok then return "exec_fail:" .. tostring(result) end; ' +
          'return "ok"'
        );
      }, id);
      console.log('oldevent_' + id + ': ' + JSON.stringify(r));
      expect(r.ok).toBe(true);
    }
  });
});
