const { test, expect } = require('@playwright/test');
const { waitForPageReady, luaEval } = require('./helpers/setup');

const SETTLE_TIMEOUT = 4000;

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

/** Start a new game: choose 1 (start) → choose 1 (confirm attributes) */
async function startNewGame(page) {
  await typeCmd(page, 'choose 1');
  await page.waitForTimeout(3000);
  await typeCmd(page, 'choose 1');
  await page.waitForTimeout(SETTLE_TIMEOUT);
}

test.describe('Slice 5 WMAP 战斗系统 E2E', () => {
  test.beforeEach(async ({ page }) => {
    page.on('pageerror', e => console.log('[BROWSER ERROR]', e.message));
    await page.goto('/');
    await waitForPageReady(page);
    await page.waitForTimeout(6000);
  });

  test('WmapHandlers and war init via luaEval', async ({ page }) => {
    test.setTimeout(30000);
    await startNewGame(page);

    // Check WmapHandlers available
    const r1 = await luaEval(page, 'return rawget(_G, "WmapHandlers") and "ok" or "nil"');
    expect(r1.ok).toBe(true);
    expect(r1.result).toBe('ok');

    // Init war with single-line table (avoid ; join breaking Lua syntax)
    const r2 = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'local P0 = JY.Person[0]',
      'P0["生命"]=100; P0["生命最大值"]=100; P0["内力"]=50; P0["内力最大值"]=50',
      'P0["攻击力"]=30; P0["防御力"]=20',
      'local W = rawget(_G, "WmapHandlers")',
      'W.initWar({{name="山贼",hp=30,maxHp=30,mp=0,maxMp=0,x=5,attack=15,defense=5}}, 5)',
      'return "ok|"..tostring(#JY.War.teammates).."|"..tostring(#JY.War.enemies)',
    ].join('; '));
    expect(r2.ok).toBe(true);
    expect(r2.result).toMatch(/^ok\|[1-6]\|1$/);

    // Status should be GAME_WMAP (5)
    const r3 = await luaEval(page, 'return tostring(rawget(_G,"JY").Status)');
    expect(r3.ok).toBe(true);
    expect(r3.result).toBe('5');
    expect(await hasNoGameErrors(page)).toBeTruthy();
  });

  test('initWar → look → choose attack', async ({ page }) => {
    test.setTimeout(60000);
    await startNewGame(page);

    // Init war (single-line table to avoid join issue)
    const init = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'local P0 = JY.Person[0]',
      'P0["生命"]=100; P0["生命最大值"]=100; P0["内力"]=50; P0["内力最大值"]=50',
      'P0["攻击力"]=30; P0["防御力"]=20',
      'local W = rawget(_G, "WmapHandlers")',
      'W.initWar({{name="山贼",hp=30,maxHp=30,mp=0,maxMp=0,x=0,attack=15,defense=5}}, 5)',
      'return "ok"',
    ].join('; '));
    expect(init.ok).toBe(true);

    // look
    await page.waitForTimeout(1000);
    await typeCmd(page, 'look');
    await page.waitForTimeout(2000);
    let lines = await getTermLines(page);
    let text = lines.join('\n');
    expect(text).toContain('战场态势');
    expect(text).toContain('山贼');
    expect(text).toContain('我方回合');

    // Auto-select teammate → action menu
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(2000);
    lines = await getTermLines(page);
    text = lines.join('\n');
    expect(text).toContain('攻击');
    expect(text).toContain('武功');

    // Attack → select target
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(2000);
    lines = await getTermLines(page);
    text = lines.join('\n');
    expect(text).toContain('选择目标');

    // Attack enemy
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(2000);
    lines = await getTermLines(page);
    text = lines.join('\n');
    expect(text).toContain('伤害');

    expect(await hasNoGameErrors(page)).toBeTruthy();
  });

  test('full kill → victory → return to MMAP', async ({ page }) => {
    test.setTimeout(60000);
    await startNewGame(page);

    // Weak enemy for quick kill
    const init = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'local P0 = JY.Person[0]',
      'P0["生命"]=100; P0["生命最大值"]=100; P0["内力"]=50; P0["内力最大值"]=50',
      'P0["攻击力"]=60; P0["防御力"]=30',
      'local W = rawget(_G, "WmapHandlers")',
      'W.initWar({{name="小贼",hp=5,maxHp=5,mp=0,maxMp=0,x=0,attack=5,defense=1}}, 3)',
      'return "ok"',
    ].join('; '));
    expect(init.ok).toBe(true);

    await page.waitForTimeout(1000);
    await typeCmd(page, 'look');
    await page.waitForTimeout(2000);

    // Attack flow
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(1500);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(1500);
    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(3000);

    // Should be GAME_MMAP (2)
    const result = await luaEval(page, 'return tostring(rawget(_G,"JY").Status)');
    expect(result.ok).toBe(true);
    expect(result.result).toBe('2');

    const lines = await getTermLines(page);
    const text = lines.join('\n');
    expect(text).toContain('战斗胜利');
    expect(await hasNoGameErrors(page)).toBeTruthy();
  });

  test('WMAP 武功菜单', async ({ page }) => {
    test.setTimeout(60000);
    await startNewGame(page);

    const init = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'local P0 = JY.Person[0]',
      'P0["生命"]=100; P0["生命最大值"]=100; P0["内力"]=50; P0["内力最大值"]=50',
      'P0["武功1"]=1; P0["武功数量"]=1',
      'local W = rawget(_G, "WmapHandlers")',
      'W.initWar({{name="试招木桩",hp=50,maxHp=50,mp=0,maxMp=0,x=0,attack=1,defense=1}}, 2)',
      'return "ok"',
    ].join('; '));
    expect(init.ok).toBe(true);

    await page.waitForTimeout(1000);
    await typeCmd(page, 'look');
    await page.waitForTimeout(2000);

    await typeCmd(page, 'choose 1');
    await page.waitForTimeout(1500);

    await typeCmd(page, 'choose 2');
    await page.waitForTimeout(2000);

    const lines = await getTermLines(page);
    const text = lines.join('\n');
    expect(text).toContain('武功');
    expect(await hasNoGameErrors(page)).toBeTruthy();
  });

  test('MMAP explore 探索命令', async ({ page }) => {
    test.setTimeout(60000);
    await startNewGame(page);

    // 先离开到 MMAP
    await typeCmd(page, 'leave');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    // 检查当前位置
    let lines = await getTermLines(page);
    let text = lines.join('\n');
    expect(text).toContain('当前位置');

    // 探索
    await typeCmd(page, 'explore');
    await page.waitForTimeout(2000);

    lines = await getTermLines(page);
    text = lines.join('\n');
    expect(text).toContain('探索');

    expect(await hasNoGameErrors(page)).toBeTruthy();
  });

  test('MMAP 行走遇敌（直接验证 initWar 调用）', async ({ page }) => {
    test.setTimeout(60000);
    await startNewGame(page);

    // 先离开到 MMAP
    await typeCmd(page, 'leave');
    await page.waitForTimeout(SETTLE_TIMEOUT);

    // 直接通过 lua 调用 initWar 模拟遇敌
    const initResult = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'local P0 = JY.Person[0]',
      'P0["生命"]=100; P0["生命最大值"]=100; P0["内力"]=50; P0["内力最大值"]=50',
      'P0["攻击力"]=30; P0["防御力"]=20',
      'local W = rawget(_G, "WmapHandlers")',
      'W.initWar({{name="山贼",hp=30,maxHp=30,mp=0,maxMp=0,x=1,attack=15,defense=5}}, 5)',
      'return "ok"',
    ].join('; '));
    expect(initResult.ok).toBe(true);

    await page.waitForTimeout(1000);
    await typeCmd(page, 'look');
    await page.waitForTimeout(2000);

    const lines = await getTermLines(page);
    const text = lines.join('\n');
    expect(text).toContain('战场态势');
    expect(text).toContain('山贼');
    expect(text).toContain('我方回合');
    expect(await hasNoGameErrors(page)).toBeTruthy();
  });

  test('战斗胜利奖励验证', async ({ page }) => {
    test.setTimeout(60000);
    await startNewGame(page);

    // Init war with weak enemy, check rewards after kill
    const init = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'local P0 = JY.Person[0]',
      'P0["生命"]=100; P0["生命最大值"]=100; P0["内力"]=50; P0["内力最大值"]=50',
      'P0["攻击力"]=60; P0["防御力"]=30',
      'P0["经验"]=0',
      'local W = rawget(_G, "WmapHandlers")',
      'W.initWar({{name="山贼",hp=5,maxHp=5,mp=0,maxMp=0,x=0,attack=5,defense=1}}, 3)',
      'return "ok"',
    ].join('; '));
    expect(init.ok).toBe(true);

    await page.waitForTimeout(1000);
    await typeCmd(page, 'look');
    await page.waitForTimeout(2000);

    // Kill enemy
    for (let i = 0; i < 3; i++) {
      await typeCmd(page, 'choose 1');
      await page.waitForTimeout(1500);
    }
    await page.waitForTimeout(2000);

    const lines = await getTermLines(page);
    const text = lines.join('\n');
    expect(text).toContain('战斗胜利');
    expect(text).toContain('经验');
    expect(text).toContain('金钱');

    // Verify rewards in Lua state
    const rewardCheck = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'local exp = JY.Person and JY.Person[0] and JY.Person[0]["经验"] or 0',
      'local gold = JY.Base and JY.Base["金钱"] or 0',
      'return tostring(exp) .. "|" .. tostring(gold)',
    ].join('; '));
    expect(rewardCheck.ok).toBe(true);
    const parts = rewardCheck.result.split('|');
    expect(parseInt(parts[0])).toBeGreaterThan(0);
    expect(parseInt(parts[1])).toBeGreaterThan(0);

    expect(await hasNoGameErrors(page)).toBeTruthy();
  });
});
