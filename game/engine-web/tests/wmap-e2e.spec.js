const { test, expect } = require('@playwright/test');
const { waitForPageReady, waitForGameReady, luaEval } = require('./helpers/setup');

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

/** 等待游戏稳定进入可操作地图场景（主角的家），避免在软体娃娃开场对话尚未结束时调用 initWar
 * 导致对话协程随后把 JY.Status 覆盖回 SMAP，战斗未真正建立。轮询终端的场景交互列表标记。 */
async function waitForMap(page, timeoutMs = 60000) {
  const start = Date.now();
  let prev = '';
  while (Date.now() - start < timeoutMs) {
    const text = (await getTermLines(page)).join('\n');
    if (text.includes('选择交互对象') || text.includes('menu 打开主选单')) {
      if (prev.includes('选择交互对象')) return true;  // 连续两次稳定在地图交互界面
      prev = text;
    } else {
      prev = '';
    }
    await page.waitForTimeout(500);
  }
  return false;
}

/** 轮询终端是否出现标记（game loop 刚启动时可能吞掉输入，需轮询确认到达指定阶段） */
async function waitForMarker(page, marker, timeoutMs = 10000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const text = (await getTermLines(page)).join('\n');
    if (text.includes(marker)) return true;
    await page.waitForTimeout(500);
  }
  return false;
}

/** Start a new game: choose 1 (start, 属性确认) → choose 1 (confirm) → 地图。
 * 由于 game loop 启动后一小段窗口内输入可能被丢弃（非确定竞态），逐阶段轮询并在
 * 输入未生效时重发 choose 1，确保在调用 initWar 前游戏已真正进入地图场景。 */
async function startNewGame(page) {
  // 阶段1: 每次点击开始新游戏后，等待属性确认屏（生命/攻击/资质）出现；若被吞则重发。
  let gotAttr = false;
  for (let k = 0; k < 8 && !gotAttr; k++) {
    await typeCmd(page, 'choose 1');
    gotAttr = await waitForMarker(page, '生命', 6000);
  }
  if (!gotAttr) throw new Error('startNewGame: 未能进入属性确认屏幕');

  // 阶段2: 确认属性 → 进入地图场景
  await typeCmd(page, 'choose 1');
  await waitForMap(page);
}

test.describe('Slice 5 WMAP 战斗系统 E2E', () => {
  test.beforeEach(async ({ page }) => {
    page.on('pageerror', e => console.log('[BROWSER ERROR]', e.message));
    await page.goto('/');
    await waitForPageReady(page);
    // 等待真正的游戏起始菜单出现（而非固定时延），避免低配置/多 worker 负载下启动未完成
    await waitForGameReady(page);
    await page.waitForTimeout(2000);
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
      'W.initWar({{name="山贼",hp=30,maxHp=30,mp=0,maxMp=0,x=5,attack=15,defense=5}}, 1)',
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
      'W.initWar({{name="山贼",hp=30,maxHp=30,mp=0,maxMp=0,x=0,attack=15,defense=5}}, 1)',
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
      'W.initWar({{name="小贼",hp=5,maxHp=5,mp=0,maxMp=0,x=0,attack=5,defense=1}}, 1)',
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

  test('脚本触发战斗（initWar 直接调用）', async ({ page }) => {
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
      'W.initWar({{name="山贼",hp=30,maxHp=30,mp=0,maxMp=0,x=1,attack=15,defense=5}}, 1)',
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
      'W.initWar({{name="山贼",hp=5,maxHp=5,mp=0,maxMp=0,x=0,attack=5,defense=1}}, 1)',
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
