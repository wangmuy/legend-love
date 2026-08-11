// quick_pass_game.md: 苗人凤居→蝴蝶谷→程瑛→黑龙潭→一灯居→闫基居
const { test, expect } = require('@playwright/test');
const { waitForPageReady, waitForGameReady } = require('./helpers/setup');
const { saveTestState, loadTestState, gotoScene, flushSaveCache, loadSaveCache, hasItem, hasTeamMember, doBattle } = require('./helpers/walkthrough');
const { cmd, getT, noE } = require('./helpers/term');

const SETTLE = 5000;

test('P4: 苗人凤→蝴蝶谷→程瑛→黑龙潭→一灯居→闫基居', async ({ page }) => {
  test.setTimeout(900000);
  loadSaveCache('bridge-p3.json');
  await page.goto('/'); await waitForPageReady(page); await waitForGameReady(page); await page.waitForTimeout(2000);

  // 苗人凤居/退敌 — tile event extra=30 → 战斗
  expect(await loadTestState(page, 2)).toBe(true);
  expect(await gotoScene(page, '苗人鳳居')).toBeGreaterThan(0);
  let t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  // entity 3 = tile event 30 (苗人凤退敌), entity 1-2 = NPCs
  await cmd(page, 'choose 3'); await page.waitForTimeout(5000);
  t = await getT(page);
  if (t.includes('战场态势') || t.includes('战斗')) {
    t = await doBattle(page);
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  // 飞狐外传条件检查 — Entity 5=搜索(oldevent_7, 需胡斐+屠龙刀+金丝背心)
  await cmd(page, 'choose 5'); await page.waitForTimeout(3000);
  t = await getT(page);
  if (t.includes('飞狐外传') || t.includes('胡斐') || t.includes('金丝背心')) {
    console.log('  ✓ 飞狐外传条件检查');
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  // 苗人凤居二刷 — Entity 2=NPC(oldevent_866, 闯王藏宝图)
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  await cmd(page, 'choose 2'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 苗人凤居(退敌+二刷)');

  // 蝴蝶谷/铲子/胡青牛加入
  expect(await gotoScene(page, '蝴蝶谷')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  await cmd(page, 'choose 5'); await page.waitForTimeout(3000);  // 胡青牛(第5NPC)
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);  // 对话
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 是(加入)
  // NPC dialog may not show name in terminal output, just verify no error
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 蝴蝶谷(胡青牛)');

  // 恒山派
  expect(await gotoScene(page, '恒山派')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  console.log('  ✓ 恒山派');

  // 蜘蛛洞 — 玄冰碧火酒(oldevent_372, Entity 6)，用于摩天崖石破天加入
  expect(await gotoScene(page, '蜘蛛洞')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  await cmd(page, 'choose 6'); await page.waitForTimeout(3000);  // Entity 6=oldevent_372 → 玄冰碧火酒
  expect(await hasItem(page, 136)).toBe(true);  // 玄冰碧火酒(136)
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 蜘蛛洞(玄冰碧火酒)');

  // 悦来客栈/令狐冲喝酒
  expect(await gotoScene(page, '悅來客棧')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  await cmd(page, 'choose 3'); await page.waitForTimeout(3000);  // 令狐冲(第3NPC)
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);  // 对话
  // NPC dialog may not show name in terminal output, just verify no error
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 悦来客栈(令狐冲)');

  // 摩天崖 — 白龙剑(oldevent_336) + 石破天对话 + 使用玄冰碧火酒加入(oldevent_335→337)
  expect(await gotoScene(page, '摩天崖')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(2000);  // Entity 1=oldevent_336 → 白龙剑
  await cmd(page, 'choose 2'); await page.waitForTimeout(3000);  // Entity 2=石破天(oldevent_333 对话→334→335)
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 对话翻页
  // 使用玄冰碧火酒 on 石破天（menu→物品→使用→玄冰碧火酒→石破天）
  await cmd(page, 'menu'); await page.waitForTimeout(2000);
  await cmd(page, 'choose 4'); await page.waitForTimeout(2000);  // 物品
  await cmd(page, 'choose 1'); await page.waitForTimeout(2000);  // 使用
  let wineIdx = await page.evaluate(() => {
    const term = window.__xterm; if (!term) return -1;
    for (let y = term.buffer.active.length - 1; y >= 0; y--) {
      const s = term.buffer.active.getLine(y)?.translateToString(true) || '';
      const m = s.match(/^(\d+)\.\s*.*玄冰碧火酒.*$/);
      if (m) return parseInt(m[1], 10);
    }
    return -1;
  });
  if (wineIdx > 0) {
    await cmd(page, 'choose ' + wineIdx); await page.waitForTimeout(2000);
    let npcIdx = await page.evaluate(() => {
      const term = window.__xterm; if (!term) return -1;
      const total = term.buffer.active.length;
      let start = -1;
      for (let y = total - 1; y >= 0; y--)
        if (term.buffer.active.getLine(y)?.translateToString(true)?.includes('选择目标')) { start = y; break; }
      if (start === -1) return -1;
      for (let y = total - 1; y > start; y--) {
        const raw = term.buffer.active.getLine(y)?.translateToString(true) || '';
        const m = raw.match(/^(\d+)\.\s*(.*\S)\s*$/);
        if (m && m[2].includes('石破天')) return parseInt(m[1], 10);
      }
      return -1;
    });
    if (npcIdx > 0) { await cmd(page, 'choose ' + npcIdx); await page.waitForTimeout(3000); }
  }
  // 是否要求加入？→ 是
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  t = await getT(page);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await hasTeamMember(page, 38)).toBe(true);  // 石破天(38) 加入队伍
  console.log('  ✓ 摩天崖(石破天加入)');

  // 五毒教 — 苗人战斗[96]
  expect(await gotoScene(page, '五毒教')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);  // 触发战斗
  t = await getT(page);
  if (t.includes('战场态势')) {
    t = await doBattle(page);
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 五毒教');

  // 程瑛加入
  expect(await gotoScene(page, '程瑛居')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  await cmd(page, 'choose 2'); await page.waitForTimeout(3000);  // 程英(第2NPC)
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);  // 对话
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 是(加入)
  // NPC dialog may not show name in terminal output, just verify no error
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 1)).toBe(true);
  console.log('  ✓ 程瑛居(程瑛加入)');

  // 黑龙潭 — 程英破阵 + 瑛姑对话
  expect(await loadTestState(page, 1)).toBe(true);
  expect(await gotoScene(page, '黑龍潭')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  // entity 1 = tile event 416 (程英破阵, 需程英在队伍中)
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);
  // entity 2 = 瑛姑 NPC
  await cmd(page, 'choose 2'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);  // 对话
  // 瑛姑对话有多页, 连续 choose 1 跳过
  for (let d = 0; d < 10; d++) {
    await cmd(page, 'choose 1'); await page.waitForTimeout(2000);
    t = await getT(page);
    if (t.includes('手帕') || t.includes('段皇爷')) break;
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 黑龙潭(瑛姑)');

  // 一灯居
  expect(await gotoScene(page, '一燈居')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 一灯居');

  // 黑龙潭二刷 — 程英破阵后, 一灯居对话后再次访问黑龙潭触发剧情
  expect(await gotoScene(page, '黑龍潭')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  // 二刷时 tile event 指向 oldevent_434 (后门重置)
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 黑龙潭(二刷)');

  // 闫基居/七星海棠
  expect(await gotoScene(page, '閰基居')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 2)).toBe(true);
  console.log('  ✓ 闫基居');

  expect(await noE(page)).toBeTruthy();
  flushSaveCache('bridge-p4.json');
  console.log('  ✓ P4 完成');
});
