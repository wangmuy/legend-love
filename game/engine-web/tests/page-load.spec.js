const { test, expect } = require('@playwright/test');
const { waitForPageReady } = require('./helpers/setup');

test.describe('页面加载基础', () => {
  test('页面标题正确', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle('金庸群侠传 Web MUD');
  });

  test('xterm 终端渲染', async ({ page }) => {
    await page.goto('/');
    await page.waitForSelector('.xterm', { timeout: 10000 });
    expect(await page.locator('.xterm').count()).toBe(1);
  });

  test('输入框存在且可交互', async ({ page }) => {
    await page.goto('/');
    const input = page.locator('#command-input');
    await expect(input).toBeVisible();
    await input.fill('test');
    expect(await input.inputValue()).toBe('test');
  });

  test('CDN 脚本加载无 404', async ({ page }) => {
    const failed = [];
    page.on('requestfailed', req => failed.push(req.url()));
    await page.goto('/');
    await waitForPageReady(page);
    expect(failed.filter(u => !u.includes('localhost'))).toEqual([]);
  });
});