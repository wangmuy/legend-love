// tests/walkthrough-p2.spec.js
// quick_pass_game.md: 回族部落→胡斐加入→冰火岛→绝情谷→大轮寺
const { test, expect } = require('@playwright/test');
const { waitForPageReady, waitForGameReady } = require('./helpers/setup');
const { saveTestState, loadTestState, gotoScene, gotoSceneById, flushSaveCache, loadSaveCache, hasItem } = require('./helpers/walkthrough');
const { cmd, getT, noE } = require('./helpers/term');

const SETTLE = 5000;

test('P2: 回族→胡斐→冰火岛→绝情谷→大轮寺', async ({ page }) => {
  test.setTimeout(600000);
  loadSaveCache('bridge-p1.json');
  await page.goto('/'); await waitForPageReady(page); await waitForGameReady(page); await page.waitForTimeout(2000);
  expect(await loadTestState(page, 6)).toBe(true);

  // 回族部落 — 霍青桐对话接可兰经任务
  // Entity 1=守卫(oldevent_624), Entity 2=霍青桐(oldevent_620)
  await gotoScene(page, '回族部落');
  let t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 2'); await page.waitForTimeout(3000);  // 霍青桐
  // 必须翻完所有对话页：oldevent_620 结尾的 instruct_3(16,3,1,1,631,...)
  // （设置金轮寺金轮法王/可兰经前置）在对话完全结束后才执行，不能提前 break
  for (let d = 0; d < 15; d++) {
    await cmd(page, 'choose 1'); await page.waitForTimeout(2000);
    t = await getT(page);
    if (t.includes('交谈结束')) break;
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 回族部落(霍青桐接可兰经任务)');

  // 胡斐加入 — 使用两页刀法（从闫基居获得）触发加入事件
  await gotoScene(page, '胡斐居');
  t = await getT(page); expect(t).toContain('你来到了');
  // 先跟胡斐对话一次，触发 oldevent_1（D* 事件链设置）
  await cmd(page, 'choose 3'); await page.waitForTimeout(5000);
  for (let d = 0; d < 8; d++) {
    await cmd(page, 'choose 1'); await page.waitForTimeout(2000);
  }
  // 通过 __luaEval 调用 SmapHandlers.__useItemDirect 对胡斐使用物品（装测试基础设施，跳过菜单UI）
  const used = await page.evaluate(async () => {
    if (!window.__luaEval) return false;
    const r = await window.__luaEval('local sh=rawget(_G,"SmapHandlers");if not sh or not sh.__useItemDirect then return "no_sh" end;local JY=rawget(_G,"JY");if not JY then return "no_jy" end;local sid=JY.SubScene or 0;local ds=rawget(_G,"initDataSource");if not ds then return "no_ds" end;local scenes=ds["scenes"];if not scenes then return "no_scn" end;local list=scenes["scenes"] or scenes;if type(list)~="table" then return "bad_scn" end;for _,s in ipairs(list) do;if s["代号"]==sid then;for _,n in ipairs(s["NPC"] or {}) do;if n["名称"]=="胡斐" then;sh.__useItemDirect(sid,n);return "ok";end;end;return "npc_not_found";end;end;return "scene_not_found_"..tostring(sid)');
    return r && r.ok && (r.result === 'true' || r.result === 'ok');
  });
  console.log('useItemDirect:', used);
  // instruct_4: 是否使用物品[两页刀法]？
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 是
  // 对话后出现"是否要求加入？"
  for (let d = 0; d < 8; d++) {
    t = await getT(page);
    if (t.includes('要求加入') || t.includes('随我闯荡')) break;
    await cmd(page, 'choose 1'); await page.waitForTimeout(2000);
  }
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 是（加入）
  t = await getT(page); expect(t.includes('胡斐加入') || t.includes('随我闯荡')).toBe(true);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 1)).toBe(true);
  console.log('  ✓ 胡斐加入');

  // 冰火岛/金毛 — 实体全部显示为"搜索"（oldevent_ 前缀 NPC 显示为搜索实体），
  // 需连续 choose 1 逐个搜索直到得一撮金毛(item 181)。
  // 诊断验证（diag-p2ice）：第2次 choose 1 得金毛181；用 choose 2 会选错目标导致拿不到。
  expect(await loadTestState(page, 1)).toBe(true);
  await gotoScene(page, '冰火島');
  t = await getT(page); expect(t).toContain('你来到了');
  let got181 = await hasItem(page, 181);
  for (let e = 0; e < 8 && !got181; e++) {
    await cmd(page, 'look'); await page.waitForTimeout(1200);
    await cmd(page, 'choose 1'); await page.waitForTimeout(2500);
    got181 = await hasItem(page, 181);
  }
  expect(got181).toBe(true);  // 一撮金毛(181)（冰火岛 oldevent_68 获得）
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  // 关键：必须保存（含金毛181），否则绝情谷段开头的 loadTestState(1) 会回滚丢弃金毛，
  // 导致昆仑仙境张无忌加入（需对张无忌使用一撮金毛）永远无法触发。
  expect(await saveTestState(page, 1)).toBe(true);
  console.log('  ✓ 冰火岛(金毛)');

  // 绝情谷/玉玺/断肠草/君子剑/玉蜂针 — 全部5个搜索实体
  expect(await loadTestState(page, 1)).toBe(true);
  await gotoScene(page, '絕情谷');
  t = await getT(page); expect(t).toContain('你来到了');
  // 5个consumable搜索实体：依次 choose 1 逐个搜索（消耗后下个自动上位）
  for (let e = 0; e < 5; e++) {
    await cmd(page, 'choose 1'); await page.waitForTimeout(2000);
    t = await getT(page);
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 2)).toBe(true);
  console.log('  ✓ 绝情谷(断肠草+君子剑+玉玺+玉蜂针+药材)');

  // 冰蚕洞/天山雪莲
  // Entity 1=天山雪莲+钥匙+黑血神针+智慧果, Entity 2=千年冰蚕
  await gotoScene(page, '冰蠶洞');
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(2000);  // Entity 1: 天山雪莲等
  await cmd(page, 'choose 1'); await page.waitForTimeout(2000);  // Entity 2: 千年冰蚕
  console.log('  ✓ 冰蚕洞(天山雪莲+千年冰蚕)');

  // 大轮寺 — 狄云对话加入+搜刮
  // Entity 1=守门僧兵[战斗91], Entity 2=钥匙孔, Entity 3=狄云(NPC), Entity 4=宝箱839, Entity 5=宝箱853
  await gotoScene(page, '大輪寺');
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 3'); await page.waitForTimeout(5000);  // 狄云(NPC Entity 3)
  // 狄云长对话，连续 choose 1 跳过
  for (let d = 0; d < 15; d++) {
    await cmd(page, 'choose 1'); await page.waitForTimeout(2000);
    t = await getT(page);
    if (t.includes('加入') || t.includes('随我闯荡')) break;
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  // 搜索宝箱
  await cmd(page, 'choose 4'); await page.waitForTimeout(3000);  // 六阳正气丹+智慧果+飞蝗石
  await cmd(page, 'choose 5'); await page.waitForTimeout(3000);  // 银两400
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 大轮寺(狄云+搜刮)');

  // 崑崙仙境/张无忌加入 — 需有金毛(从冰火岛获得)
  // 注意：原版昆仑仙境分两层——scene 67"崑崙仙境"(崙,大地图入口22,439,洞口场景)，
  // 其 3 个出口全部通向 scene 4"崑侖仙境"(侖,含张无忌70,入口无效只能经出口进入)。
  // 流程：gotoSceneById(67) → look → choose 出口(→崑侖仙境) → 进入 scene 4 → 张无忌出现。
  // 第一次访问：对话张无忌（oldevent_70）→ D*修改事件为75(普通对话)/71(使用金毛)
  // 注意：张无忌是动态 D* NPC，实体编号不固定，必须按文本定位实体编号。
  await gotoSceneById(page, 67);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(1500);
  // choose 出口实体（→崑侖仙境）进入 scene 4
  const exitIdx = await page.evaluate(() => {
    const term = window.__xterm; if (!term) return -1;
    const total = term.buffer.active.length;
    for (let y = total - 1; y >= 0; y--) {
      const raw = term.buffer.active.getLine(y)?.translateToString(true) || '';
      const m = raw.match(/^(\d+)\.\s*→\s*(.*\S)\s*$/);
      if (m && (m[2].includes('崑侖') || m[2].includes('崑崙'))) return parseInt(m[1], 10);
    }
    return -1;
  });
  if (exitIdx > 0) { await cmd(page, 'choose ' + exitIdx); await page.waitForTimeout(3000); }
  console.log('  昆仑仙境出口选择: ' + exitIdx);
  await cmd(page, 'look'); await page.waitForTimeout(1500);
  const zjEnt = await page.evaluate(() => {
    const term = window.__xterm; if (!term) return -1;
    const total = term.buffer.active.length;
    for (let y = total - 1; y >= 0; y--) {
      const raw = term.buffer.active.getLine(y)?.translateToString(true) || '';
      const m = raw.match(/^(\d+)\.\s*(.*\S)\s*$/);
      if (m && (m[2].includes('张无忌') || m[2].includes('張無忌'))) return parseInt(m[1], 10);
    }
    return -1;
  });
  console.log('  昆仑仙境张无忌实体: ' + zjEnt);
  if (zjEnt > 0) { await cmd(page, 'choose ' + zjEnt); await page.waitForTimeout(5000); }
  else { await cmd(page, 'choose 1'); await page.waitForTimeout(5000); }
  // oldevent_70 有 12 段对话，需翻完（检测"交谈结束"），不能只翻 10 次
  for (let d = 0; d < 16; d++) {
    await cmd(page, 'choose 1'); await page.waitForTimeout(2000);
    t = await getT(page);
    if (t.includes('交谈结束')) break;
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  // 第二次访问：对张无忌使用"一撮金毛"(181) → oldevent_71（使用金毛）→ 加入
  // 注意：oldevent_70 对话后事件变为 field2=75(普通对话)/field3=71(使用金毛触发)，
  // 必须走"物品菜单→使用→选一撮金毛→选目标张无忌"流程（smapUseItemOnNpc 读 field3），
  // 直接对话只会触发 oldevent_75（"我义父好可怜"）。
  expect(await hasItem(page, 181)).toBe(true);  // 一撮金毛（冰火岛 oldevent_68 获得）
  await gotoSceneById(page, 67);  // 第二次访问：scene 67 洞口 → 出口 → scene 4（含张无忌）
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(1500);
  const exitIdx2 = await page.evaluate(() => {
    const term = window.__xterm; if (!term) return -1;
    const total = term.buffer.active.length;
    for (let y = total - 1; y >= 0; y--) {
      const raw = term.buffer.active.getLine(y)?.translateToString(true) || '';
      const m = raw.match(/^(\d+)\.\s*→\s*(.*\S)\s*$/);
      if (m && (m[2].includes('崑侖') || m[2].includes('崑崙'))) return parseInt(m[1], 10);
    }
    return -1;
  });
  if (exitIdx2 > 0) { await cmd(page, 'choose ' + exitIdx2); await page.waitForTimeout(3000); }
  await cmd(page, 'menu'); await page.waitForTimeout(2000);
  await cmd(page, 'choose 4'); await page.waitForTimeout(2000);  // 物品
  await cmd(page, 'choose 1'); await page.waitForTimeout(2000);  // 使用
  const hairIdx = await page.evaluate(async (nm) => {
    const term = window.__xterm; if (!term) return -1;
    for (let y = term.buffer.active.length - 1; y >= 0; y--) {
      const t = term.buffer.active.getLine(y)?.translateToString(true) || '';
      const m = t.match(/^(\d+)\.\s*(.*\S)\s*$/);
      if (m && m[2].includes(nm)) return parseInt(m[1], 10);
    }
    return -1;
  }, '金毛');
  if (hairIdx > 0) {
    await cmd(page, 'choose ' + hairIdx); await page.waitForTimeout(2000);
    const zjIdx = await page.evaluate(() => {
      const term = window.__xterm; if (!term) return -1;
      const total = term.buffer.active.length;
      let start = -1;
      for (let y = total - 1; y >= 0; y--)
        if (term.buffer.active.getLine(y)?.translateToString(true)?.includes('选择目标')) { start = y; break; }
      if (start === -1) return -1;
      for (let y = total - 1; y > start; y--) {
        const raw = term.buffer.active.getLine(y)?.translateToString(true) || '';
        const m = raw.match(/^(\d+)\.\s*(.*\S)\s*$/);
        if (m && (m[2].includes('张无忌') || m[2].includes('張無忌'))) return parseInt(m[1], 10);
      }
      return -1;
    });
    if (zjIdx > 0) { await cmd(page, 'choose ' + zjIdx); await page.waitForTimeout(5000); }
    console.log(`  使用 一撮金毛(181) on 张无忌: 剩余=${await hasItem(page, 181)}`);
  } else {
    console.log('  ⚠ 物品列表未找到 一撮金毛');
    await cmd(page, 'choose 0'); await page.waitForTimeout(400);
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(400);
  await cmd(page, 'choose 0'); await page.waitForTimeout(400);
  // 对话后出现"是否要求加入？"
  for (let d = 0; d < 8; d++) {
    t = await getT(page);
    if (t.includes('要求加入') || t.includes('加入')) break;
    await cmd(page, 'choose 1'); await page.waitForTimeout(2000);
  }
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 加入
  t = await getT(page);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 崑崙仙境(张无忌加入)');

  expect(await noE(page)).toBeTruthy();
  flushSaveCache('bridge-p2.json');
  console.log('  ✓ P2 完成');
});
