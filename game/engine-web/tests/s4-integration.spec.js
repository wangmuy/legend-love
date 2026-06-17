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
    // 进入游戏 → MMAP
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    // 进入场景
    await typeCmd(page, 'list');
    await page.waitForTimeout(2000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    // SMAP help
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

  test('场景交互完整流程: look→choose→NPC对话→leave', async ({ page }) => {
    test.setTimeout(120000);
    // 进入游戏
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    // 进入场景
    await typeCmd(page, 'list');
    await page.waitForTimeout(2000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    // look 显示编号列表
    let lines = await getTermLines(page);
    let text = lines.join('\n');
    console.log('=== SCENE LOOK ===');
    console.log(text);
    expect(text).toContain('你来到了');
    expect(text).toContain('1.');
    expect(text).toContain('choose');
    expect(await hasNoGameErrors(page)).toBeTruthy();

    // choose 1 — 选择第一个交互对象（NPC → 子菜单，或出口 → 传送）
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);

    lines = await getTermLines(page);
    text = lines.join('\n');
    console.log('=== AFTER CHOOSE 1 ===');
    console.log(text);
    // 不应报错
    expect(await hasNoGameErrors(page)).toBeTruthy();

    // 回到大地图
    await typeCmd(page, 'leave');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    lines = await getTermLines(page);
    text = lines.join('\n');
    expect(text).toContain('回到了大地图');
    expect(await hasNoGameErrors(page)).toBeTruthy();
  });
});
