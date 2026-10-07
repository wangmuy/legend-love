// quick_pass_game.md: P7 后半段天书收集 — 主角居搜刮 → 丐帮二刷《天龙八部》→ 天宁寺二刷《连城诀》
// 前置：walkthrough-p7.spec.js（P7a）已保存 bridge-p7.json slot 2（含桃花岛射雕148/黑木崖笑傲151/黑木令牌125）
const { test, expect } = require('@playwright/test');
const { waitForPageReady, waitForGameReady } = require('./helpers/setup');
const { saveTestState, loadTestState, gotoScene, gotoSceneById, flushSaveCache, loadSaveCache, hasItem, doBattle, inBattle, hasDEvent } = require('./helpers/walkthrough');
const { cmd, getT, noE } = require('./helpers/term');

const SETTLE = 5000;

test('P7b: 主角居→丐帮二刷(天龙八部)→天宁寺二刷(连城诀)', async ({ page }) => {
  test.setTimeout(1200000);
  loadSaveCache('bridge-p7.json');
  await page.goto('/'); await waitForPageReady(page); await waitForGameReady(page); await page.waitForTimeout(2000);
  expect(await loadTestState(page, 2)).toBe(true);
  let t = await getT(page);

  // 主角居/搜刮物品 — 宝箱
  expect(await gotoScene(page, '主角的家')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(2000);  // 精气丸
  await cmd(page, 'choose 1'); await page.waitForTimeout(2000);  // 人蔘
  await cmd(page, 'choose 1'); await page.waitForTimeout(2000);  // 小还丹
  await cmd(page, 'choose 1'); await page.waitForTimeout(2000);  // 银两
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 主角居');

  // ===== 《天龙八部》(147) 前置链：绝情谷玉玺(130) + 铁掌山图表(131) → 燕子坞慕容复 =====
  // 链：绝情谷401(玉玺130) → 铁掌山453(大燕图表131) → 燕子坞慕容复487对话 → 使用130(493)
  //     → 使用131(573，设置丐帮 tile14=527) → 丐帮527(问天龙八部)→528(战斗83→147)
  // P6 链中玉玺(130)可能丢失（P2 存档有但后续链未保留），此处重新获取以确保完整。
  if (!(await hasItem(page, 130))) {
    // 注意：gotoScene('絕情谷') 的 includes 匹配会先命中"絕情谷底"(scene 80, 杨过)！
    // 玉玺在 scene 22"絕情谷"——必须用 gotoSceneById(22) 精确定位。
    expect(await gotoSceneById(page, 22)).toBeGreaterThan(0);
    t = await getT(page); expect(t).toContain('你来到了');
    await cmd(page, 'look'); await page.waitForTimeout(1500);
    // 绝情谷5个搜索实体（400/401玉玺/856/857/399）：choose 触发后 look() 重建实体列表
    // （已消耗事件不再显示，未消耗的前移）——递增索引会错位（400消耗后401变实体1），
    // 必须每轮 look 后 choose 1，直到拿到玉玺130。
    for (let e = 0; e < 8 && !(await hasItem(page, 130)); e++) {
      await cmd(page, 'look'); await page.waitForTimeout(1200);
      await cmd(page, 'choose 1'); await page.waitForTimeout(2500);
    }
    await cmd(page, 'choose 0'); await page.waitForTimeout(400);
    await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
    console.log('  ✓ 绝情谷(玉玺130: ' + await hasItem(page, 130) + ')');
  }
  if (!(await hasItem(page, 131))) {
    expect(await gotoScene(page, '鐵掌山')).toBeGreaterThan(0);
    t = await getT(page); expect(t).toContain('你来到了');
    await cmd(page, 'look'); await page.waitForTimeout(1500);
    await cmd(page, 'choose 3'); await page.waitForTimeout(2500);  // oldevent_453：大燕皇帝世系图表131
    await cmd(page, 'choose 0'); await page.waitForTimeout(400);
    await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
    console.log('  ✓ 铁掌山(大燕图表131: ' + await hasItem(page, 131) + ')');
  }
  // 燕子坞：慕容复(487)对话 → 对慕容复使用130/131（smapUseItemOnNpc → 493/573 → 设置丐帮527）
  expect(await gotoScene(page, '燕子塢')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(1500);
  await cmd(page, 'choose 1'); await page.waitForTimeout(2500);  // 慕容复(487) 对话
  for (let p = 0; p < 20; p++) {
    const tail5 = (await getT(page)).split('\n').slice(-4).join('');
    if (tail5.includes('选择交互对象') || tail5.includes('输入 choose')) break;
    await cmd(page, 'choose 1'); await page.waitForTimeout(1000);
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(400);
  console.log('  燕子坞慕容复对话完成，使用玉玺/图表设置丐帮527');
  // 对慕容复使用 130 玉玺（触发 493）与 131 图表（触发 573，设置丐帮527）
  // 复用 P6 已验证的物品使用流程：menu → choose 4(物品) → choose 1(使用) → 按名选物品 → 选目标NPC
  for (const [itemId, itemName] of [[130, '大燕傳國玉璽'], [131, '大燕皇帝世系圖表']]) {
    if (!(await hasItem(page, itemId))) { console.log(`  ⚠ 物品${itemId}缺失，跳过`); continue; }
    await cmd(page, 'menu'); await page.waitForTimeout(2000);
    await cmd(page, 'choose 4'); await page.waitForTimeout(2000);  // 物品
    await cmd(page, 'choose 1'); await page.waitForTimeout(2000);  // 使用
    const itemIdx = await page.evaluate(async (nm) => {
      const term = window.__xterm; if (!term) return -1;
      for (let y = term.buffer.active.length - 1; y >= 0; y--) {
        const t = term.buffer.active.getLine(y)?.translateToString(true) || '';
        const m = t.match(/^(\d+)\.\s*(.*\S)\s*$/);
        if (m && m[2].includes(nm)) return parseInt(m[1], 10);
      }
      return -1;
    }, itemName);
    if (itemIdx > 0) {
      await cmd(page, 'choose ' + itemIdx); await page.waitForTimeout(2000);
      const npcIdx = await page.evaluate(() => {
        const term = window.__xterm; if (!term) return -1;
        const total = term.buffer.active.length;
        let start = -1;
        for (let y = total - 1; y >= 0; y--)
          if (term.buffer.active.getLine(y)?.translateToString(true)?.includes('选择目标')) { start = y; break; }
        if (start === -1) return -1;
        for (let y = total - 1; y > start; y--) {
          const raw = term.buffer.active.getLine(y)?.translateToString(true) || '';
          const m = raw.match(/^(\d+)\.\s*(.*\S)\s*$/);
          if (m && (m[2].includes('慕容复') || m[2].includes('oldevent_487'))) return parseInt(m[1], 10);
        }
        return -1;
      });
      if (npcIdx > 0) { await cmd(page, 'choose ' + npcIdx); await page.waitForTimeout(5000); }
      console.log(`  使用 ${itemName}(${itemId}) on 慕容复: 剩余=${await hasItem(page, itemId)}`);
    } else {
      console.log(`  ⚠ 物品列表未找到 ${itemName}`);
      await cmd(page, 'choose 0'); await page.waitForTimeout(400);
      await cmd(page, 'choose 0'); await page.waitForTimeout(400);
    }
    await cmd(page, 'choose 0'); await page.waitForTimeout(400);
    await cmd(page, 'choose 0'); await page.waitForTimeout(400);
  }
  // 验证丐帮527已设置（hasDEvent 不可用则跳过，直接用 hasItem 最终验证）

  // 丐帮二刷/《天龙八部》— 乔峰事件链 525→526→527→528(战斗[83]→147)
  // 需在同一实体上连续翻页对话推进（526"再一起喝酒"→527"问天龙八部"→528"准备好就挑战"），
  // 528 触发 instruct_5（是否选择战斗）→ choose 1 → 战斗[83] → 得书147。
  // 用 Lua hasItem(147) 判断；响应 __instruct5_waiting。
  expect(await gotoScene(page, '丐幫')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  let got147 = await hasItem(page, 147);
  for (let attempt = 0; attempt < 6 && !got147; attempt++) {
    await cmd(page, 'look'); await page.waitForTimeout(1500);
    for (let ei = 1; ei <= 8 && !got147; ei++) {
      await cmd(page, 'choose ' + ei); await page.waitForTimeout(2500);
      // 连续翻页：526/527 对话 + 528 的 instruct_5（是否选择战斗）
      for (let pg = 0; pg < 12 && !got147; pg++) {
        const i5 = await page.evaluate(async () => {
          if (!window.__luaEval) return false;
          const r = await window.__luaEval('return tostring(rawget(_G, "__instruct5_waiting") == true)');
          return r && r.ok && r.result === 'true';
        });
        if (i5) { console.log(`  [丐帮实体${ei} pg${pg}] instruct_5 → choose 1（接受挑战）`); await cmd(page, 'choose 1'); await page.waitForTimeout(2500); }
        for (let p = 0; p < 15 && !(await inBattle(page)); p++) await page.waitForTimeout(400);
        if (await inBattle(page)) await doBattle(page);
        got147 = await hasItem(page, 147);  // 《天龙八部》item 147
        if (got147) break;
        const tail5 = (await getT(page)).split('\n').slice(-4).join('');
        if (tail5.includes('选择交互对象') || tail5.includes('输入 choose')) break;
        await cmd(page, 'choose 1'); await page.waitForTimeout(1000);
      }
      if (got147) { console.log('  ✓ 丐帮二刷(天龙八部) 实体' + ei); break; }
      await cmd(page, 'choose 0'); await page.waitForTimeout(300);
    }
    if (got147) break;
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await hasItem(page, 147)).toBe(true);  // 《天龙八部》item 147

  // 天宁寺二刷/《连城诀》— 完整链：北丑居使用唐诗选辑(160) 触发 603 → 设置天宁寺 tile18=644 → 天宁寺掘墓得 146
  // 603/644 均为 D* 动态事件，由 look() 运行时扫描显示为"搜索"实体
  // 1. 北丑居：对 tile0 的 NPC（oldevent_15，603 所在格）使用唐诗选辑(160) 触发 603
  //    oldevent_603 开头 instruct_4(160,1,0) 询问"是否使用唐诗选辑？"——
  //    smapUseItemOnNpc 会设置 __instruct4_auto_yes 自动通过；choose 搜索路径则需手动响应询问。
  //    用物品菜单流程（与上方燕子坞使用玉玺/图表同模式）最可靠。
  expect(await hasItem(page, 160)).toBe(true);  // 唐诗选辑(160) 前置（P1 唐诗山东已获得）
  expect(await gotoScene(page, '北丑居')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(1500);
  // 物品菜单：menu → 4(物品) → 1(使用) → 唐诗选辑 → 目标 oldevent_15（tile0）
  await cmd(page, 'menu'); await page.waitForTimeout(2000);
  await cmd(page, 'choose 4'); await page.waitForTimeout(2000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(2000);
  const tsIdx = await page.evaluate(async () => {
    const term = window.__xterm; if (!term) return -1;
    for (let y = term.buffer.active.length - 1; y >= 0; y--) {
      const t = term.buffer.active.getLine(y)?.translateToString(true) || '';
      const m = t.match(/^(\d+)\.\s*(.*\S)\s*$/);
      if (m && m[2].includes('唐詩選輯')) return parseInt(m[1], 10);
    }
    return -1;
  });
  if (tsIdx > 0) {
    await cmd(page, 'choose ' + tsIdx); await page.waitForTimeout(2000);
    // 目标列表：oldevent_15（tile0，603 所在格）；找不到则选第一个场景 NPC
    const tgtIdx = await page.evaluate(async () => {
      const term = window.__xterm; if (!term) return -1;
      const total = term.buffer.active.length;
      let start = -1;
      for (let y = total - 1; y >= 0; y--)
        if (term.buffer.active.getLine(y)?.translateToString(true)?.includes('选择目标')) { start = y; break; }
      if (start === -1) return -1;
      let fallback = -1;
      for (let y = total - 1; y > start; y--) {
        const raw = term.buffer.active.getLine(y)?.translateToString(true) || '';
        const m = raw.match(/^(\d+)\.\s*(.*\S)\s*$/);
        if (m && m[2].includes('oldevent_15')) return parseInt(m[1], 10);
        if (m && fallback === -1 && !m[2].includes('队员')) fallback = parseInt(m[1], 10);
      }
      return fallback;
    });
    if (tgtIdx > 0) { await cmd(page, 'choose ' + tgtIdx); await page.waitForTimeout(5000); }
    console.log(`  北丑居使用唐詩選輯(160): 剩余=${await hasItem(page, 160)}`);
  } else {
    console.log('  ⚠ 物品列表未找到唐詩選輯');
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(400);
  await cmd(page, 'choose 0'); await page.waitForTimeout(400);
  // 若物品菜单未生效，回退：choose 搜索实体 + 响应 instruct_4 询问
  let d644 = await hasDEvent(page, 63, 644);
  for (let ei = 1; ei <= 8 && !d644; ei++) {
    await cmd(page, 'choose ' + ei); await page.waitForTimeout(2500);
    for (let p = 0; p < 15 && !d644; p++) {
      const i4 = await page.evaluate(async () => {
        if (!window.__luaEval) return false;
        const r = await window.__luaEval('return tostring(rawget(_G, "__instruct4_waiting") == true)');
        return r && r.ok && r.result === 'true';
      });
      if (i4) { console.log(`  [北丑居实体${ei}] instruct_4 → choose 1（使用唐诗选辑）`); await cmd(page, 'choose 1'); await page.waitForTimeout(2000); }
      d644 = await hasDEvent(page, 63, 644);
      if (d644) break;
      await page.waitForTimeout(500);
    }
    if (d644) { console.log('  ✓ 北丑居(唐诗选辑→天宁寺644) 实体' + ei); break; }
    await cmd(page, 'choose 0'); await page.waitForTimeout(300);
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);

  // 2. 天宁寺二刷：触发 644 掘墓得《连城诀》146
  // 用 Lua hasItem(146) 判断（累积终端文本"连城诀/得到物品"会误判）
  expect(await gotoScene(page, '天寧寺')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  let got146 = await hasItem(page, 146);
  // 注意：天宁寺二刷实体顺序 = 静态NPC 605(碑文) + D* tile17=606(各大门派战斗93) + D* tile18=644(佛像後连城诀)。
  // 606 战斗胜利后 smapEntityList 重建（644 位置前移），递增索引会错位 —— 战斗后必须重新从实体1开始。
  for (let round = 0; round < 6 && !got146; round++) {
    for (let ei = 1; ei <= 10 && !got146; ei++) {
      await cmd(page, 'choose ' + ei); await page.waitForTimeout(2500);
      for (let p = 0; p < 15 && !(await inBattle(page)); p++) await page.waitForTimeout(400);
      if (await inBattle(page)) {
        await doBattle(page);
        got146 = await hasItem(page, 146);  // 战斗后实体列表重建，跳出内层重新 look/从1开始
        break;
      }
      got146 = await hasItem(page, 146);  // 《连城诀》item 146
      if (got146) { console.log('  ✓ 天宁寺二刷(连城诀) 实体' + ei); break; }
      await cmd(page, 'choose 0'); await page.waitForTimeout(300);
    }
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await hasItem(page, 146)).toBe(true);  // 《连城诀》item 146

  expect(await noE(page)).toBeTruthy();
  flushSaveCache('bridge-p7.json');
  console.log('  ✓ P7b 完成');
});
