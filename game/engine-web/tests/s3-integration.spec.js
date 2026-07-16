const { test, expect } = require('@playwright/test');
const { waitForPageReady } = require('./helpers/setup');

const SETTLE_TIMEOUT = 5000;

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

test.describe('Slice 3 完整流程集成测试', () => {
  test.beforeEach(async ({ page }) => {
    page.on('pageerror', e => console.log('[BROWSER ERROR]', e.message));
    await page.goto('/');
    await waitForPageReady(page);
    await page.waitForTimeout(6000);
  });

  test('完整流程: 开始→属性确认→MMAP→list菜单→进入场景→leave返回', async ({ page }) => {
    test.setTimeout(90000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);

    let lines = await getTermLines(page);
    expect(lines.some(l => l.includes('生命'))).toBeTruthy();
    expect(lines.some(l => l.includes('攻击'))).toBeTruthy();
    expect(lines.some(l => l.includes('资质'))).toBeTruthy();

    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    lines = await getTermLines(page);
    const text = lines.join('\n');
    expect(text).toContain('新游戏开始');
    expect(text).toContain('输入 help 查看可用命令');
    expect(await hasNoGameErrors(page)).toBeTruthy();

    // 新游戏从主角的家场景开始，先离开到大地图
    await typeCmd(page, 'leave');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    lines = await getTermLines(page);
    expect(lines.join('\n')).toContain('当前位置');

    await typeCmd(page, 'look');
    await page.waitForTimeout(2000);
    lines = await getTermLines(page);
    expect(lines.join('\n')).toContain('方位');

    await typeCmd(page, 'list');
    await page.waitForTimeout(2000);
    lines = await getTermLines(page);
    expect(lines.some(l => l.includes('可去场景'))).toBeTruthy();

    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    lines = await getTermLines(page);
    const sceneText = lines.join('\n');
    expect(sceneText).toContain('你来到了');
    expect(sceneText).toContain('choose');
    expect(await hasNoGameErrors(page)).toBeTruthy();

    await typeCmd(page, 'exits');
    await page.waitForTimeout(2000);
    lines = await getTermLines(page);
    if (lines.some(l => l.includes('出口'))) {
      expect(lines.join('\n')).toMatch(/\d+\.\s*\S+/);
    }

    await typeCmd(page, 'leave');
    await page.waitForTimeout(SETTLE_TIMEOUT);
    lines = await getTermLines(page);
    const afterLeave = lines.join('\n');
    expect(afterLeave).toContain('回到了大地图');
    expect(afterLeave).toContain('当前位置');
    expect(await hasNoGameErrors(page)).toBeTruthy();

    await typeCmd(page, 'help');
    await page.waitForTimeout(2000);
    lines = await getTermLines(page);
    const helpText = lines.join('\n');
    expect(helpText).toContain('list');
    expect(helpText).toContain('look');
    expect(helpText).toContain('quit');
  });

  test('list 菜单→choose→进入场景→leave 返回 MMAP', async ({ page }) => {
    test.setTimeout(60000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE_TIMEOUT);
    // 从主角的家离开到 MMAP
    await typeCmd(page, 'leave');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    // 使用 list → choose 1 进入场景（go 命令已从 MMAP 移除）
    await typeCmd(page, 'list');
    await page.waitForTimeout(2000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    let lines = await getTermLines(page);
    expect(lines.join('\n')).toContain('你来到了');
    expect(await hasNoGameErrors(page)).toBeTruthy();

    await typeCmd(page, 'exits');
    await page.waitForTimeout(2000);
    lines = await getTermLines(page);
    expect(lines.join('\n')).toContain('出口');

    await typeCmd(page, 'leave');
    await page.waitForTimeout(SETTLE_TIMEOUT);
    lines = await getTermLines(page);
    expect(lines.join('\n')).toContain('回到了大地图');
    expect(await hasNoGameErrors(page)).toBeTruthy();
  });

  test('list 菜单 ESC (choose 0) 不报错', async ({ page }) => {
    test.setTimeout(60000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE_TIMEOUT);
    await typeCmd(page, 'leave');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    await typeCmd(page, 'list');
    await page.waitForTimeout(2000);
    await typeCmd(page, 'choose 0');
    await page.waitForTimeout(2000);

    expect(await hasNoGameErrors(page)).toBeTruthy();

    await typeCmd(page, 'look');
    await page.waitForTimeout(2000);
    const lines = await getTermLines(page);
    expect(lines.join('\n')).toContain('当前位置');
  });

  test('输入 help 在 MMAP 显示所有命令', async ({ page }) => {
    test.setTimeout(60000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE_TIMEOUT);
    await typeCmd(page, 'leave');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    await typeCmd(page, 'help');
    await page.waitForTimeout(2000);

    const lines = await getTermLines(page);
    const text = lines.join('\n');
    expect(text).toContain('list');
    expect(text).toContain('look');
    expect(text).toContain('quit');
    expect(text).toContain('choose');
    expect(await hasNoGameErrors(page)).toBeTruthy();
  });

  test('未知命令不引发 gameLoop 错误', async ({ page }) => {
    test.setTimeout(60000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE_TIMEOUT);
    await typeCmd(page, 'leave');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    await typeCmd(page, 'xyzunknown');
    await page.waitForTimeout(2000);

    expect(await hasNoGameErrors(page)).toBeTruthy();
    const lines = await getTermLines(page);
    expect(lines.join('\n')).toContain('未知命令');
  });

  test('连续 list→choose→leave 多次不累积错误', async ({ page }) => {
    test.setTimeout(90000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE_TIMEOUT);
    // 从主角的家离开到 MMAP
    await typeCmd(page, 'leave');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    for (let i = 0; i < 3; i++) {
      await typeCmd(page, 'list');
      await page.waitForTimeout(1500);
      await typeCmd(page, 'choose 1');
      await page.waitForTimeout(2000);
      await typeCmd(page, 'leave');
      await page.waitForTimeout(SETTLE_TIMEOUT);
      expect(await hasNoGameErrors(page)).toBeTruthy();
    }

    const lines = await getTermLines(page);
    const text = lines.join('\n');
    expect(text).toContain('回到了大地图');
    expect(text).toContain('当前位置');
  });

  test('属性选择提示包含 choose 0 返回开始菜单', async ({ page }) => {
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);

    const lines = await getTermLines(page);
    const text = lines.join('\n');
    expect(text).toContain('choose 0');
    expect(text).toContain('返回开始菜单');
  });

  test('属性 choose 2 (否) 重新生成属性并继续', async ({ page }) => {
    test.setTimeout(60000);
    // choose 1 进入属性确认
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);

    let lines = await getTermLines(page);
    let text = lines.join('\n');
    expect(text).toContain('生命');
    expect(text).toContain('攻击');
    expect(text).toContain('资质');

    // choose 2 否定，重新生成属性
    await typeCmd(page, 'choose 2');
    await page.waitForTimeout(3000);

    lines = await getTermLines(page);
    text = lines.join('\n');
    // 应显示新的属性值
    expect(text).toContain('生命');
    expect(text).toContain('攻击');
    expect(text).toContain('内力性质');

    // choose 1 确认，进入游戏
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    lines = await getTermLines(page);
    text = lines.join('\n');
    expect(text).toContain('新游戏开始');
    expect(text).toContain('输入 help 查看可用命令');
    expect(await hasNoGameErrors(page)).toBeTruthy();

    // 从主角的家离开到 MMAP
    await typeCmd(page, 'leave');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    // 进入 MMAP 后验证基本命令
    await typeCmd(page, 'look');
    await page.waitForTimeout(2000);
    lines = await getTermLines(page);
    expect(lines.join('\n')).toContain('当前位置');
  });

  test('开始菜单 choose 2 (载入进度) 显示无存档提示并返回', async ({ page }) => {
    test.setTimeout(60000);
    await typeCmd(page, 'choose 2');
    await page.waitForTimeout(3000);

    let lines = await getTermLines(page);
    const text = lines.join('\n');
    expect(text).toContain('没有存档');
    // 应提示用户操作，而非仅告知「选择重新开始」
    expect(text).toContain('choose 1');

    // 检查之后重新显示了开始菜单
    expect(text).toContain('重新开始');
    expect(text).toContain('载入进度');
    expect(text).toContain('离开游戏');
    expect(await hasNoGameErrors(page)).toBeTruthy();

    // 返回后可以正常开始新游戏
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);

    lines = await getTermLines(page);
    expect(lines.some(l => l.includes('生命'))).toBeTruthy();
  });

  test('属性确认 choose 0 返回开始菜单后重新显示菜单', async ({ page }) => {
    // 先进入属性确认界面
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);

    let lines = await getTermLines(page);
    expect(lines.join('\n')).toContain('生命');

    // choose 0 返回开始菜单
    await typeCmd(page, 'choose 0');
    await page.waitForTimeout(3000);

    lines = await getTermLines(page);
    const text = lines.join('\n');
    // 应显示"返回开始菜单"
    expect(text).toContain('返回开始菜单');
    // 应重新显示开始菜单选项
    expect(text).toContain('重新开始');
    expect(text).toContain('载入进度');
    expect(text).toContain('离开游戏');
    // 应显示输入提示
    expect(text).toContain('choose 1');
    expect(text).toContain('choose 2');
    expect(await hasNoGameErrors(page)).toBeTruthy();
  });

  test('开始菜单 choose 0 (ESC) 重新显示开始菜单', async ({ page }) => {
    test.setTimeout(60000);
    await page.waitForTimeout(2000);
    await typeCmd(page, 'choose 0');
    await page.waitForTimeout(3000);

    let lines = await getTermLines(page);
    const text = lines.join('\n');
    // Web MUD: showStartMenuCoroutine 用 WebUI.write 输出 "1. 重新开始" 等
    expect(text).toContain('重新开始');
    expect(text).toContain('载入进度');
    expect(text).toContain('离开游戏');
    // 应显示输入提示
    expect(text).toContain('choose 1');
    expect(text).toContain('choose 2');
    expect(await hasNoGameErrors(page)).toBeTruthy();
  });

  test('开始菜单 choose 3 离开(no-op)后仍可开始游戏', async ({ page }) => {
    test.setTimeout(60000);
    // choose 3 离开
    await typeCmd(page, 'choose 3');
    await page.waitForTimeout(3000);

    let lines = await getTermLines(page);
    let text = lines.join('\n');
    expect(text).toContain('游戏已退出');
    expect(text).toContain('choose 1');

    // 之后仍可选择 1 开始游戏
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);

    lines = await getTermLines(page);
    text = lines.join('\n');
    expect(text).toContain('生命');
    expect(await hasNoGameErrors(page)).toBeTruthy();
  });

  test('属性 choose 2 多次重掷后 choose 1 确认进入游戏', async ({ page }) => {
    test.setTimeout(60000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);

    let lines = await getTermLines(page);
    let text = lines.join('\n');
    expect(text).toContain('生命');

    // 重掷 2 次
    for (let i = 0; i < 2; i++) {
      await typeCmd(page, 'choose 2');
      await page.waitForTimeout(2000);
    }

    lines = await getTermLines(page);
    text = lines.join('\n');
    expect(text).toContain('生命');
    expect(text).toContain('内力性质');

    // 确认
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    lines = await getTermLines(page);
    text = lines.join('\n');
    expect(text).toContain('新游戏开始');
    expect(await hasNoGameErrors(page)).toBeTruthy();
  });

  test('NPC对话: 在主角的家与软体娃娃对话', async ({ page }) => {
    test.setTimeout(60000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    // 新游戏开始在主角的家，应该能看到NPC列表
    let lines = await getTermLines(page);
    let text = lines.join('\n');
    expect(text).toContain('软体娃娃');

    // 选第一个NPC（软体娃娃）
    // 注意：场景Entity列表中NPC在第1位（看SmapHandlers.look输出顺序）
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);

    lines = await getTermLines(page);
    text = lines.join('\n');
    // 应出现NPC子菜单（对话/查看）
    expect(text).toContain('对话');
    expect(text).toContain('查看');

    // 选择"对话"
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);

    lines = await getTermLines(page);
    text = lines.join('\n');
    // 应出现软体娃娃的对话文本
    expect(text).toContain('软体娃娃');
    expect(text).toContain('提示');
    expect(await hasNoGameErrors(page)).toBeTruthy();
  });

  test('NPC对话后正确显示交谈结束再重绘场景', async ({ page }) => {
    test.setTimeout(90000);
    // 开始游戏
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    // 离开主角的家到大地图
    await typeCmd(page, 'leave');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    // 进入河洛客栈（按拼音排序第44位）
    await typeCmd(page, 'list');
    await page.waitForTimeout(2000);
    await typeCmd(page, 'choose 44');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    let lines = await getTermLines(page);
    let text = lines.join('\n');
    expect(text).toContain('河洛客棧');
    expect(await hasNoGameErrors(page)).toBeTruthy();

    // 选择掌柜（NPC列表第7位）
    await typeCmd(page, 'choose 7');
    await page.waitForTimeout(3000);

    lines = await getTermLines(page);
    text = lines.join('\n');
    expect(text).toContain('掌柜');
    expect(text).toContain('对话');

    // 选择"对话"
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);

    lines = await getTermLines(page);
    text = lines.join('\n');
    // 应出现掌柜的对话文本（关于住宿）
    expect(text).toContain('掌柜');
    expect(text).toContain('住');

    // 验证关键点：「交谈结束」不应出现在「是否住宿」之前
    const talkEndPos = text.indexOf('交谈结束');
    const dialogPos = text.indexOf('是否住宿');
    if (talkEndPos >= 0 && dialogPos >= 0) {
      expect(talkEndPos).toBeGreaterThan(dialogPos);
    }

    // 选择"否"，不住宿
    await typeCmd(page, 'choose 2');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    lines = await getTermLines(page);
    text = lines.join('\n');
    // 应出现"交谈结束"和场景重绘
    expect(text).toContain('交谈结束');
    expect(text).toContain('河洛客棧');
    expect(await hasNoGameErrors(page)).toBeTruthy();
  });
});