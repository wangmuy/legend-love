const { test, expect } = require('@playwright/test');
const { waitForPageReady } = require('./helpers/setup');

const SETTLE_TIMEOUT = 6000;

async function getTermLines(page) {
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

async function hasNoGameErrors(page) {
  return page.evaluate(() => {
    const term = window.__xterm;
    if (!term) return true;
    for (let y = 0; y < term.rows; y++) {
      const text = term.buffer.active.getLine(y)?.translateToString(true) || '';
      if (text.includes('[gameLoop error]')) return false;
    }
    return true;
  });
}

async function typeCmd(page, text) {
  const input = page.locator('#command-input');
  await input.waitFor({ state: 'visible', timeout: 5000 });
  await input.fill(text);
  await page.keyboard.press('Enter');
}

test.describe('Slice 4 场景交互集成测试', () => {
  test.beforeEach(async ({ page }) => {
    page.on('pageerror', e => console.log('[BROWSER ERROR]', e.message));
    await page.goto('/');
    await waitForPageReady(page);
    await page.waitForTimeout(2000);
  });

  test('SMAP help 显示所有命令', async ({ page }) => {
    test.setTimeout(120000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    await typeCmd(page, 'list');
    await page.waitForTimeout(2000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    await typeCmd(page, 'help');
    await page.waitForTimeout(2000);

    const text = (await getTermLines(page)).join('\n');
    console.log('=== SMAP HELP ===');
    console.log(text);
    expect(text).toContain('look');
    expect(text).toContain('exits');
    expect(text).toContain('go');
    expect(text).toContain('leave');
    expect(text).toContain('choose');
    expect(await hasNoGameErrors(page)).toBeTruthy();
  });

  test('场景交互完整流程: look→choose→leave', async ({ page }) => {
    test.setTimeout(120000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    await typeCmd(page, 'list');
    await page.waitForTimeout(2000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    let lines = await getTermLines(page);
    let text = lines.join('\n');
    console.log('=== SCENE LOOK ===');
    console.log(text);
    expect(text).toContain('你来到了');
    expect(text).toContain('1.');
    expect(text).toContain('choose');
    expect(await hasNoGameErrors(page)).toBeTruthy();

    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);

    expect(await hasNoGameErrors(page)).toBeTruthy();

    await typeCmd(page, 'leave');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    lines = await getTermLines(page);
    text = lines.join('\n');
    expect(text).toContain('回到了大地图');
    expect(await hasNoGameErrors(page)).toBeTruthy();
  });

  test('初始位置附近有 主角的家', async ({ page }) => {
    test.setTimeout(120000);
    // 进入游戏
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    // MMAP look — 显示附近场景
    await typeCmd(page, 'look');
    await page.waitForTimeout(2000);

    const lines = await getTermLines(page);
    const text = lines.join('\n');
    console.log('=== MMAP LOOK ===');
    console.log(text);
    // 主角在初始位置 (364,284)，主角的家在附近
    expect(text).toContain('主角的家');
    expect(text).toContain('步');
    expect(text).toContain('list');
    expect(await hasNoGameErrors(page)).toBeTruthy();
  });

  test('list 包含 主角的家 场景', async ({ page }) => {
    test.setTimeout(120000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    await typeCmd(page, 'list');
    await page.waitForTimeout(3000);

    const lines = await getTermLines(page);
    const text = lines.join('\n');
    console.log('=== LIST ===');
    console.log(text);
    // 主角的家应在场景列表中
    expect(text).toContain('主角的家');
    expect(await hasNoGameErrors(page)).toBeTruthy();
  });
});
