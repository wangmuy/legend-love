const { test, expect } = require('@playwright/test');
const { waitForPageReady, luaEval } = require('./helpers/setup');

test.describe('错误场景', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForPageReady(page);
  });

  test('file.open 不存在文件返回 nil', async ({ page }) => {
    const r = await luaEval(page, 'return EngineAPI.file.open("no_such_file", "r")');
    expect(r).toBeUndefined();
  });

  test('script.load 不存在脚本返回 nil,error', async ({ page }) => {
    const r = await luaEval(page, 'local a, b = EngineAPI.script.load("no_such.lua"); return tostring(a) .. "|" .. tostring(b)');
    expect(r).toContain('nil|Script not found');
  });

  test('parseJSON 非法 JSON 抛错误', async ({ page }) => {
    const r = await luaEval(page, 'return parseJSON("{{invalid}")');
    expect(r).toHaveProperty('__error');
    expect(typeof r.__error).toBe('string');
    expect(r.__error.length).toBeGreaterThan(0);
  });

  test('控制台无 error/warning', async ({ page }) => {
    const logs = [];
    page.on('console', msg => {
      if (msg.type() === 'error' || msg.type() === 'warning') {
        logs.push({ type: msg.type(), text: msg.text() });
      }
    });
    await page.goto('/');
    await waitForPageReady(page);
    const relevant = logs.filter(l => !l.text.includes('favicon') && !l.text.includes('libva'));
    expect(relevant).toEqual([]);
  });

  test('网络请求无失败', async ({ page }) => {
    const failed = [];
    page.on('requestfailed', req => failed.push(req.url()));
    await page.goto('/');
    await waitForPageReady(page);
    expect(failed).toEqual([]);
  });
});