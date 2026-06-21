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
    // 进入游戏，直接进入主角的家（SMAP 状态）
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    // 直接测试 SMAP help（玩家在主角的家场景中）
    await typeCmd(page, 'help');
    await page.waitForTimeout(2000);

    const text = (await getTermLines(page)).join('\n');
    console.log('=== SMAP HELP ===');
    console.log(text);
    expect(text).toContain('look');
    expect(text).toContain('exits');
    expect(text).toContain('leave');
    expect(text).toContain('choose');
    expect(text).toContain('rest');
    expect(await hasNoGameErrors(page)).toBeTruthy();
  });

  test('场景交互完整流程: 主角的家→look→leave→MMAP', async ({ page }) => {
    test.setTimeout(120000);
    // 进入游戏，在主角的家场景中
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    // look 显示主角的家场景（SMAP 编号列表）
    let lines = await getTermLines(page);
    let text = lines.join('\n');
    console.log('=== HOME LOOK ===');
    console.log(text);
    expect(text).toContain('新游戏开始');
    expect(await hasNoGameErrors(page)).toBeTruthy();

    // 离开主角的家到 MMAP
    await typeCmd(page, 'leave');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    lines = await getTermLines(page);
    text = lines.join('\n');
    expect(text).toContain('回到了大地图');
    expect(await hasNoGameErrors(page)).toBeTruthy();

    // 在 MMAP 测试 list
    await typeCmd(page, 'list');
    await page.waitForTimeout(2000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    lines = await getTermLines(page);
    text = lines.join('\n');
    expect(text).toContain('你来到了');
    expect(await hasNoGameErrors(page)).toBeTruthy();

    // 在新场景中离开
    await typeCmd(page, 'leave');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    lines = await getTermLines(page);
    text = lines.join('\n');
    expect(text).toContain('回到了大地图');
    expect(await hasNoGameErrors(page)).toBeTruthy();
  });

  test('初始位置在主角的家场景，离开后到达大地图', async ({ page }) => {
    test.setTimeout(120000);
    // 进入游戏
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    // 游戏中显示主角的家场景
    let lines = await getTermLines(page);
    let text = lines.join('\n');
    console.log('=== HOME SCENE ===');
    console.log(text);
    expect(text).toContain('主角的家');

    // 离开场景到大地图
    await typeCmd(page, 'leave');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    lines = await getTermLines(page);
    text = lines.join('\n');
    console.log('=== MMAP AFTER LEAVE ===');
    console.log(text);
    expect(text).toContain('回到了大地图');
    expect(text).toContain('当前位置');
    expect(await hasNoGameErrors(page)).toBeTruthy();
  });

  test('list 包含 主角的家 场景', async ({ page }) => {
    test.setTimeout(120000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE_TIMEOUT);
    // 离开主角的家到 MMAP
    await typeCmd(page, 'leave');
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

  test('talk 命令注册 + help 显示', async ({ page }) => {
    test.setTimeout(60000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(6000);

    // help 应显示 talk/take/give 命令
    await typeCmd(page, 'help');
    await page.waitForTimeout(2000);

    const lines = await getTermLines(page);
    const text = lines.join('\n');
    expect(text).toContain('talk');
    expect(text).toContain('take');
    expect(text).toContain('give');
    expect(text).toContain('rest');
    expect(await hasNoGameErrors(page)).toBeTruthy();
  });

  test('talk NPC 返回提示', async ({ page }) => {
    test.setTimeout(60000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(6000);

    // talk 命令（当前场景数据 NPC 数组为空，输出相应提示）
    await typeCmd(page, 'talk 软体娃娃');
    await page.waitForTimeout(3000);

    const lines = await getTermLines(page);
    const text = lines.join('\n');
    expect(text).toContain('可以对话的 NPC');
    expect(await hasNoGameErrors(page)).toBeTruthy();
  });

  test('take/give 命令基本注册', async ({ page }) => {
    test.setTimeout(60000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(6000);

    // help 应显示 take/give 命令
    await typeCmd(page, 'help');
    await page.waitForTimeout(2000);

    let lines = await getTermLines(page);
    let text = lines.join('\n');
    expect(text).toContain('take');
    expect(text).toContain('give');
    expect(await hasNoGameErrors(page)).toBeTruthy();
  });
});
