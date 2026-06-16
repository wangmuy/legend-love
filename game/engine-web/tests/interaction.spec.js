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

async function luaEval(page, code) {
  return page.evaluate(async (c) => {
    if (!window.__luaEval) return { __error: 'luaEval not ready' };
    return await window.__luaEval(c);
  }, code);
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

  test('输入事件被 Lua 侧消费（事件队列为空）', async ({ page }) => {
    const input = page.locator('#command-input');
    await input.waitFor({ state: 'visible', timeout: 5000 });

    // 输入一个命令
    await input.fill('test_cmd');
    await page.keyboard.press('Enter');
    await page.waitForTimeout(2000);

    // 通过 __luaEval 检查 Worker 内的事件队列
    const result = await luaEval(page, 'return rawget(_G, "JSBridge") and rawget(_G, "JSBridge").getEventCount and rawget(_G, "JSBridge").getEventCount() or -1');
    // 结果为 0 表示事件已被消费
    expect(result.ok).toBe(true);
    expect(result.result).toBe('0');
  });

  test('未知命令显示提示信息', async ({ page }) => {
    const input = page.locator('#command-input');
    await input.waitFor({ state: 'visible', timeout: 5000 });
    await input.fill('xyzzy');
    await page.keyboard.press('Enter');
    await page.waitForTimeout(2000);

    const lines = await getAllTermLines(page);
    expect(lines.some(l => l.includes('未知命令'))).toBe(true);
  });
});