// quick_pass_game.md: 神龙教→破庙→冰火岛(铁焰令)→成昆→沙漠→北丑→灵蛇→渤泥→侠客→冰火岛(屠龙刀)→回族部落(书剑)→五毒教→神龙教(鹿鼎记)→光明顶(倚天)
const { test, expect } = require('@playwright/test');
const { waitForPageReady, waitForGameReady } = require('./helpers/setup');
const { saveTestState, loadTestState, gotoScene, flushSaveCache, loadSaveCache, hasItem, hasTeamMember, doBattle, inBattle, hasDEvent } = require('./helpers/walkthrough');
const { cmd, getT, noE } = require('./helpers/term');

const SETTLE = 5000;

// 通过场景名称查找索引
async function findSceneIdx(page, name) {
  return page.evaluate((n) => {
    const term = window.__xterm; if (!term) return -1;
    const total = term.buffer.active.length;
    let lastList = -1;
    for (let y = total - 1; y >= 0; y--)
      if (term.buffer.active.getLine(y)?.translateToString(true)?.includes('可去场景'))
        { lastList = y; break; }
    if (lastList === -1) return -1;
    for (let y = total - 1; y > lastList; y--) {
      const raw = term.buffer.active.getLine(y)?.translateToString(true) || '';
      const m = raw.match(/^\D*(\d+)\.\s*(.*\S)\s*$/);
      if (m && m[2].includes(n)) return parseInt(m[1], 10);
    }
    return -1;
  }, name);
}

test('P6: 神龙教→破庙→冰火岛(铁焰令)→成昆→沙漠→北丑→灵蛇→渤泥→侠客', async ({ page }) => {
  test.setTimeout(1200000);
  loadSaveCache('bridge-p5.json');
  await page.goto('/'); await waitForPageReady(page); await waitForGameReady(page); await page.waitForTimeout(2000);
  expect(await loadTestState(page, 3)).toBe(true);

  // 神龙教《鹿鼎记》— 洪教主对话(oldevent_609)
  expect(await gotoScene(page, '神龍教')).toBeGreaterThan(0);
  let t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  // entity 1=洪教主, entity 2-3=守卫
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  // 609 有 14 段对话，必须完整翻页！否则结尾的 instruct_3(37,5,1,1,616)
  // （放置五毒教蓝凤凰）不会执行 → 五毒教无 616 → 611 未就位 → 鹿鼎记失败。
  for (let p = 0; p < 18; p++) {
    await cmd(page, 'choose 1'); await page.waitForTimeout(1200);
    t = await getT(page);
    if (t.includes('选择交互对象')) break;  // 对话结束回到实体列表
  }
  t = await getT(page);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  // 诊断：检查 JY.D[37] 状态（instruct_3 是否设置了 616）
  const d37diag = await page.evaluate(async () => {
    const lua = window.__luaEval;
    if (!lua) return 'no_lua';
    const code = 'local J = rawget(_G, "JY"); if not J then return "no_JY" end; local d37 = J.D and J.D[37]; if not d37 then return "D[37]=nil" end; local tile5 = d37[5]; if not tile5 then return "D[37][5]=nil" end; local f2 = tile5[2] or tile5["2"]; return "D[37][5][2]=" .. tostring(f2) .. " type=" .. type(tile5)';
    const r = await lua(code);
    return r && r.ok && r.result;
  });
  console.log('  [诊断] 神龙教一刷后 JY.D[37] 状态:', d37diag);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 神龙教(洪教主)');

  // 破庙/广陵散
  expect(await gotoScene(page, '破廟')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 1)).toBe(true);
  console.log('  ✓ 破庙');

  // 成昆居 — 成崑战斗(需先冰火岛用铁焰令)
  expect(await loadTestState(page, 1)).toBe(true);
  await cmd(page, 'look'); await page.waitForTimeout(1000);
  // 先前往冰火岛使用铁焰令触发谢逊对话(设定成昆居事件)
  // 当前 P5 光明顶已获得铁焰令，这里先去冰火岛触发谢逊
  // 改用 gotoScene 直接导航（findSceneIdx 依赖终端残留列表，可能返回 -1 导致整块跳过 → 假阳性）
  let iceUsed = false;
  let iceIdx2 = await gotoScene(page, '冰火島');
  if (iceIdx2 > 0) {
    t = await getT(page);
    if (t.includes('你来到了')) {
      // 使用 明教铁焰令 on 谢逊
      await cmd(page, 'menu'); await page.waitForTimeout(2000);
      await cmd(page, 'choose 4'); await page.waitForTimeout(2000);
      await cmd(page, 'choose 1'); await page.waitForTimeout(2000);
      let itemIdx = await page.evaluate(() => {
        const term = window.__xterm; if (!term) return -1;
        for (let y = term.buffer.active.length - 1; y >= 0; y--) {
          const t = term.buffer.active.getLine(y)?.translateToString(true) || '';
          const m = t.match(/^(\d+)\.\s*.*[铁鐵]焰令.*$/);  // 物品名是繁体"明教鐵焰令"
          if (m) return parseInt(m[1], 10);
        }
        return -1;
      });
      if (itemIdx > 0) {
        await cmd(page, 'choose ' + itemIdx); await page.waitForTimeout(2000);
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
            if (m && (m[2].includes('谢逊') || m[2].includes('oldevent_60'))) return parseInt(m[1], 10);
          }
          return -1;
        });
        if (npcIdx > 0) { await cmd(page, 'choose ' + npcIdx); await page.waitForTimeout(5000); }
        // 用 Lua 验证铁焰令是否被消耗（oldevent_61 执行 → 成崑居91设置）
        iceUsed = !(await hasItem(page, 190));
        if (iceUsed) console.log('  [诊断] 铁焰令已消耗（oldevent_61 执行成功）');
        else console.log('  ⚠ 铁焰令未消耗（oldevent_61 未执行）');
      }
    }
    await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  }
  if (!iceUsed) console.log('  ⚠ 冰火岛铁焰令使用失败');
  else console.log('  ✓ 冰火岛(铁焰令→谢逊)');

  // 成昆居 — 成崑战斗(oldevent_91，战斗[13]胜利给头颅191)
  // 91 事件由冰火岛铁焰令(oldevent_61)通过 instruct_3(9,0,...91) 动态放置于成崑居 tile0 field4。
  // 注意：成崑居静态 NPC（840/841/849 对话）占据实体 1-3，91 战斗实体索引靠后且每次触发后
  //       实体列表重建、索引错位 → 每轮重新 look、用 Lua hasDEvent(9,91)/hasItem(191) 判断。
  expect(await gotoScene(page, '成崑居')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  let gotHead = await hasItem(page, 191);
  if (!gotHead) {
    console.log('  [诊断] 成崑居 91 已设置:', await hasDEvent(page, 9, 91));
    for (let attempt = 0; attempt < 10 && !gotHead; attempt++) {
      await cmd(page, 'look'); await page.waitForTimeout(1200);
      for (let ei = 1; ei <= 12 && !gotHead; ei++) {
        await cmd(page, 'choose ' + ei); await page.waitForTimeout(2000);
        for (let p = 0; p < 20 && !(await inBattle(page)); p++) {
          await page.waitForTimeout(300);
        }
        if (await inBattle(page)) {
          t = await doBattle(page);
        }
        gotHead = await hasItem(page, 191);  // 头颅
        if (gotHead) { console.log('  ✓ 成昆居(成崑战斗+人头) 实体' + ei); break; }
        await cmd(page, 'choose 0'); await page.waitForTimeout(300);
      }
    }
  }
  if (!gotHead) console.log('  ⚠ 成昆居战斗未得头颅191');
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);

  // 沙漠废墟/《白马啸西风》
  expect(await gotoScene(page, '沙漠廢墟')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 沙漠废墟');

  // 北丑居
  expect(await gotoScene(page, '北丑居')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 2)).toBe(true);
  console.log('  ✓ 北丑居');

  // 灵蛇岛/紫衫龙王 — 金花婆婆战斗 + 王难姑获救
  expect(await loadTestState(page, 2)).toBe(true);
  expect(await gotoScene(page, '靈蛇島')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  // entity 1=王难姑(103), 2=oldevent_926, 3=金花婆婆(98)
  await cmd(page, 'choose 3'); await page.waitForTimeout(3000);  // 金花婆婆 → 战斗
  t = await getT(page);
  if (t.includes('战场态势') || t.includes('战斗')) { t = await doBattle(page); }
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 王难姑对话
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 灵蛇岛(金花婆婆+王难姑)');

  // 蝴蝶谷胡青牛谢恩(95) → instruct_26 #1（灵蛇岛 tile2 eventExtra 106→107）
  expect(await gotoScene(page, '蝴蝶谷')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  for (let ei = 1; ei <= 8; ei++) {
    await cmd(page, 'choose ' + ei); await page.waitForTimeout(3000);
    t = await getT(page);
    if (t.includes('多谢少侠救了内人') || t.includes('谢恩') || t.includes('报答')) break;
    await cmd(page, 'choose 0'); await page.waitForTimeout(300);
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 蝴蝶谷(胡青牛谢恩)');

  // 渤泥岛/《碧血剑》— 袁承志对话(oldevent_635 接任务，结尾 instruct_3 设置 636)
  // 注意：635 有 21 段对话，必须完整翻页才会执行结尾的 instruct_3(-2,...636,...)，
  // 否则 P6b 二刷时事件仍是 635 而非 636 → 碧血剑(156) 拿不到。
  // 关键：对话结束后（"交谈结束"）必须立即停止翻页——多余的 choose 1 会误触发 636
  // （含 instruct_5"是否与之过招"→ 战斗[101]），导致 Lua worker 繁忙、后续 gotoScene 超时。
  expect(await gotoScene(page, '浡泥島')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 袁承志（635 对话开始）
  let got156b = await hasItem(page, 156);
  for (let pg = 0; pg < 25 && !got156b; pg++) {
    // 对话结束标志（"交谈结束"或回实体列表）→ 立即停止翻页，避免误触发 636
    const tailB = (await getT(page)).split('\n').slice(-4).join('');
    if (tailB.includes('交谈结束') || tailB.includes('选择交互对象') || tailB.includes('输入 choose')) break;
    // 防御：若误入 636 的 instruct_5 询问，选 2（否）退出，不触发战斗
    const i5b = await page.evaluate(async () => {
      if (!window.__luaEval) return false;
      const r = await window.__luaEval('return tostring(rawget(_G, "__instruct5_waiting") == true)');
      return r && r.ok && r.result === 'true';
    });
    if (i5b) { await cmd(page, 'choose 2'); await page.waitForTimeout(1500); break; }
    await cmd(page, 'choose 1'); await page.waitForTimeout(1500);
  }
  // 消化排队事件，确保回到实体列表
  await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 渤泥岛(袁承志)' + (got156b ? '+碧血剑' : ''));

  // 侠客岛/《侠客行》— 龙岛主对话(oldevent_353)
  expect(await gotoScene(page, '俠客島')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  // entity 1=张三, 2=李四, 3=龙岛主, 4=木岛主
  await cmd(page, 'choose 3'); await page.waitForTimeout(3000);  // 龙岛主
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);  // 对话
  t = await getT(page);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 3)).toBe(true);
  console.log('  ✓ 侠客岛(龙岛主)');

  expect(await noE(page)).toBeTruthy();
  flushSaveCache('bridge-p6.json');
  console.log('  ✓ P6a 完成');
});

test('P6b: 冰火岛(屠龙刀)→回族(书剑)→五毒教→神龙教(鹿鼎记)→光明顶(倚天)→碧血剑→侠客行', async ({ page }) => {
  test.setTimeout(1200000);
  loadSaveCache('bridge-p6.json');
  await page.goto('/'); await waitForPageReady(page); await waitForGameReady(page); await page.waitForTimeout(2000);
  expect(await loadTestState(page, 3)).toBe(true);
  let t;

  // 冰火岛三刷 — 使用一颗头颅换屠龙刀(需已杀成崑得人头)
  // 改用 gotoScene 直接导航（findSceneIdx 依赖终端残留列表，侠客岛 leave 后可能为 -1）
  let iceOk = await gotoScene(page, '冰火島');
  if (iceOk > 0) {
    t = await getT(page);
    if (t.includes('你来到了')) {
      await cmd(page, 'menu'); await page.waitForTimeout(2000);
      await cmd(page, 'choose 4'); await page.waitForTimeout(2000);
      await cmd(page, 'choose 1'); await page.waitForTimeout(2000);
      let headIdx = await page.evaluate(() => {
        const term = window.__xterm; if (!term) return -1;
        for (let y = term.buffer.active.length - 1; y >= 0; y--) {
          const t = term.buffer.active.getLine(y)?.translateToString(true) || '';
          const m = t.match(/^(\d+)\.\s*.*[一顆颗]頭[顱颅].*$/);  // 物品名是繁体"一顆頭顱"
          if (m) return parseInt(m[1], 10);
        }
        return -1;
      });
      if (headIdx > 0) {
        await cmd(page, 'choose ' + headIdx); await page.waitForTimeout(2000);
        let npcIdx2 = await page.evaluate(() => {
          const term = window.__xterm; if (!term) return -1;
          const total = term.buffer.active.length;
          let start = -1;
          for (let y = total - 1; y >= 0; y--)
            if (term.buffer.active.getLine(y)?.translateToString(true)?.includes('选择目标')) { start = y; break; }
          if (start === -1) return -1;
          for (let y = total - 1; y > start; y--) {
            const raw = term.buffer.active.getLine(y)?.translateToString(true) || '';
            const m = raw.match(/^(\d+)\.\s*(.*\S)\s*$/);
            if (m && (m[2].includes('谢逊') || m[2].includes('oldevent_60'))) return parseInt(m[1], 10);
          }
          return -1;
        });
        if (npcIdx2 > 0) { await cmd(page, 'choose ' + npcIdx2); await page.waitForTimeout(3000); }
      }
      // Lua 验证：oldevent_65 执行后应获得屠龙刀117、设置冰火岛 tile3 eventExtra=67
      const got117 = await hasItem(page, 117);
      const headLeft = await hasItem(page, 191);
      const t3diag = await page.evaluate(async () => {
        if (!window.__luaEval) return 'NOEVAL';
        const code = 'local J = rawget(_G, "JY"); local d = J.D and J.D[J.SubScene]; if not d or not d[3] then return "tile3=nil" end; local e = d[3]; return "tile3 f2="..tostring(e[2] or e["2"] or -1).." f3="..tostring(e[3] or e["3"] or -1).." f4="..tostring(e[4] or e["4"] or -1)';
        const r = await window.__luaEval(code);
        return r && r.ok ? r.result : 'ERR';
      });
      console.log('  [诊断] 头颅后 屠龙刀117:', got117, ' 头颅191剩余:', headLeft, ' ', t3diag);
    }
    await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  }
  console.log('  ✓ 冰火岛(人头→屠龙刀)');

  // 冰火岛 tile3 eventExtra=67（65 设置）→ 触发 67 → 光明顶 tile94=109（谢逊回光明顶）
  // 注意：oldevent_67 无对话文本（只有 instruct_3），不能用终端文本判断 → 用 Lua hasDEvent(11,109) 验证；
  //       67 已在 eventNpcNames 命名（"冰火岛线索"），look 显示为命名实体，直接从终端按名定位，
  //       避免盲目 choose 1-12 在实体列表重建后索引错位。
  expect(await gotoScene(page, '冰火島')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  let gmd109 = false;
  for (let attempt = 0; attempt < 10 && !gmd109; attempt++) {
    await cmd(page, 'look'); await page.waitForTimeout(1500);
    // 从终端输出中查找"冰火岛线索"实体编号（形如 "N. 冰火岛线索"）
    const clueIdx = await page.evaluate((nm) => {
      const term = window.__xterm; if (!term) return -1;
      const total = term.buffer.active.length;
      for (let y = total - 1; y >= 0; y--) {
        const raw = term.buffer.active.getLine(y)?.translateToString(true) || '';
        const m = raw.match(/^\D*(\d+)\.\s*(.*\S)\s*$/);
        if (m && m[2].includes(nm)) return parseInt(m[1], 10);
      }
      return -1;
    }, '冰火岛线索');
    if (clueIdx > 0) {
      await cmd(page, 'choose ' + clueIdx); await page.waitForTimeout(2500);
      gmd109 = await hasDEvent(page, 11, 109);  // 光明顶 tile94=109 谢逊已放置（67 生效）
      if (gmd109) { console.log('  ✓ 冰火岛(67→光明顶谢逊) 实体#' + clueIdx); break; }
      await cmd(page, 'choose 0'); await page.waitForTimeout(300);
    }
  }
  if (!gmd109) console.log('  ⚠ 冰火岛67未触发（光明顶109未就位）');
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);

  // ===== 天书收集（P6 后半段，从桥接存档继续） =====

  // 高昌迷宫/《白马啸西风》— 沙漠废墟出口进入 scene 14，choose 3=oldevent_656
  expect(await gotoScene(page, '沙漠廢墟')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  let mazeExit = await page.evaluate(() => {
    const term = window.__xterm; if (!term) return -1;
    for (let y = term.buffer.active.length - 1; y >= 0; y--) {
      const t = term.buffer.active.getLine(y)?.translateToString(true) || '';
      const m = t.match(/^(\d+)\.\s*→\s*(.*\S)\s*$/);
      if (m && m[2].includes('高昌')) return parseInt(m[1], 10);
    }
    return -1;
  });
  if (mazeExit > 0) {
    await cmd(page, 'choose ' + mazeExit); await page.waitForTimeout(SETTLE);
    await cmd(page, 'choose 3'); await page.waitForTimeout(3000);  // oldevent_656 → 白马啸西风
    t = await getT(page);
    console.log('  ✓ 高昌迷宫(白马啸西风): ' + (t.includes('得到物品') ? '得书' : '对话完成'));
    await cmd(page, 'choose 0'); await page.waitForTimeout(500);
    await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
    expect(await hasItem(page, 149)).toBe(true);  // 《白马啸西风》item 149
  } else {
    console.log('  ⚠ 沙漠废墟无高昌迷宫出口');
    await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  }

  // 回族部落二刷/《书剑恩仇录》— 对霍青桐(oldevent_620)使用可兰经(159) → 触发 622 得书
  expect(await gotoScene(page, '回族部落')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'menu'); await page.waitForTimeout(2000);
  await cmd(page, 'choose 4'); await page.waitForTimeout(2000);  // 物品
  await cmd(page, 'choose 1'); await page.waitForTimeout(2000);  // 使用
  let koranIdx = await page.evaluate(() => {
    const term = window.__xterm; if (!term) return -1;
    for (let y = term.buffer.active.length - 1; y >= 0; y--) {
      const t = term.buffer.active.getLine(y)?.translateToString(true) || '';
      const m = t.match(/^(\d+)\.\s*.*可[兰蘭][经經].*$/);  // 物品名是繁体"可蘭經"
      if (m) return parseInt(m[1], 10);
    }
    return -1;
  });
  if (koranIdx > 0) {
    await cmd(page, 'choose ' + koranIdx); await page.waitForTimeout(2000);
    let hzqIdx = await page.evaluate(() => {
      const term = window.__xterm; if (!term) return -1;
      const total = term.buffer.active.length;
      let start = -1;
      for (let y = total - 1; y >= 0; y--)
        if (term.buffer.active.getLine(y)?.translateToString(true)?.includes('选择目标')) { start = y; break; }
      if (start === -1) return -1;
      for (let y = total - 1; y > start; y--) {
        const raw = term.buffer.active.getLine(y)?.translateToString(true) || '';
        const m = raw.match(/^(\d+)\.\s*(.*\S)\s*$/);
        if (m && (m[2].includes('oldevent_620') || m[2].includes('霍青桐'))) return parseInt(m[1], 10);
      }
      return -1;
    });
    if (hzqIdx > 0) { await cmd(page, 'choose ' + hzqIdx); await page.waitForTimeout(6000); }
  }
  t = await getT(page);
  console.log('  ✓ 回族部落二刷(书剑恩仇录): ' + (t.includes('书剑恩仇录') || t.includes('得到物品') ? '得书' : '对话完成'));
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await hasItem(page, 152)).toBe(true);  // 《书剑恩仇录》item 152

  // 五毒教二刷/蓝凤凰(oldevent_616) — 韦小宝线，为神龙教《鹿鼎记》做前置
  expect(await gotoScene(page, '五毒教')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  // 诊断：检查 save/load 后 JY.D[37] 状态
  const d37after = await page.evaluate(async () => {
    const lua = window.__luaEval;
    if (!lua) return 'no_lua';
    const code = 'local J = rawget(_G, "JY"); if not J then return "no_JY" end; local d37 = J.D and J.D[37]; if not d37 then return "D[37]=nil" end; local tile5 = d37[5]; if not tile5 then return "D[37][5]=nil" end; local f2 = tile5[2] or tile5["2"]; if not f2 then return "D[37][5][2]=nil" end; return "D[37][5][2]=" .. tostring(f2)';
    const r = await lua(code);
    return r && r.ok && r.result;
  });
  console.log('  [诊断] 五毒教二刷前 JY.D[37] 状态:', d37after);
  // 诊断：打印 smapEntityList
  const entityList = await page.evaluate(async () => {
    const lua = window.__luaEval;
    if (!lua) return 'no_lua';
    const code = 'local el = rawget(_G, "smapEntityList"); if not el then return "smapEntityList=nil" end; local parts = {}; for i, v in ipairs(el) do parts[#parts+1] = i .. "=" .. (v.name or v.type or "?") .. "(" .. (v.eventId or v.charId or "?") .. ")" end; return table.concat(parts, ", ")';
    const r = await lua(code);
    return r && r.ok && r.result;
  });
  console.log('  [诊断] 五毒教二刷前 smapEntityList:', entityList);
  // 逐个尝试实体（静态 614/618/898 + 动态 616），触发 616 战斗[98]胜利后
  // instruct_3(71,3,-2,-2,611,...) 会在神龙教(71) D* 表放置 611（洪教主战斗）。
  // 注意：不能用终端文本"韦小宝/蓝凤凰"判断——神龙教一刷(609)的对话历史已含
  // "韦小宝"字样，会导致误判提前 break，616 从未触发。改为 Lua 直接检查 JY.D[71]。
  // 616 已加入 eventNpcNames 映射 → look 显示为命名实体"蓝凤凰"（与金轮法王 631 相同模式）。
  // 直接从终端定位"蓝凤凰"实体索引并选择，避免被守卫战斗(613×5)挡住。
  let ldjReady = false;
  for (let ei = 1; ei <= 10 && !ldjReady; ei++) {
    await cmd(page, 'look'); await page.waitForTimeout(1500);
    // 从终端输出中查找"蓝凤凰"实体编号（形如 "N. 蓝凤凰"）
    const lfIdx = await page.evaluate((nm) => {
      const term = window.__xterm; if (!term) return -1;
      const total = term.buffer.active.length;
      for (let y = total - 1; y >= 0; y--) {
        const raw = term.buffer.active.getLine(y)?.translateToString(true) || '';
        const m = raw.match(/^\D*(\d+)\.\s*(.*\S)\s*$/);
        if (m && m[2].includes(nm)) return parseInt(m[1], 10);
      }
      return -1;
    }, '蓝凤凰');
    if (lfIdx > 0) {
      console.log('  定位到蓝凤凰实体#' + lfIdx);
      await cmd(page, 'choose ' + lfIdx); await page.waitForTimeout(1500);
      // 616 对话（instruct_1 不 yield，瞬间输出）后自动触发战斗[98]（instruct_6 挂起协程）。
      // 不能用终端文本判断战斗开始（getT 返回累积历史，成昆居等之前战斗的"战场态势"会误判），
      // 用 inBattle()（JY.Status==5）轮询等待战斗真正开始，再 doBattle。
      for (let p = 0; p < 20 && !(await inBattle(page)); p++) {
        await page.waitForTimeout(500);
      }
      const ib = await inBattle(page);
      // 诊断：dump choose 后状态（JY.Status + D* 覆盖源）
      const dbg = await page.evaluate(async () => {
        const lua = window.__luaEval;
        if (!lua) return 'no_lua';
        const code = [
          'local J = rawget(_G, "JY")',
          'if not J then return "no_JY" end',
          'local st = J.Status or -1',
          'local d5 = J.D and J.D[37] and J.D[37][5]',
          'local d616 = J.D and J.D[37] and J.D[37][616]',
          'local d105 = J.D and J.D[37] and J.D[37][105]',
          'local fmt = function(t) if not t then return "nil" end local p = {} for k,v in pairs(t) do p[#p+1] = tostring(k).."="..tostring(v) end return "{"..table.concat(p,",").."}" end',
          'return "Status="..tostring(st).." D37[5]="..fmt(d5).." D37[616]="..fmt(d616).." D37[105]="..fmt(d105)',
        ].join('\n');
        const r = await lua(code);
        return r && r.ok && r.result;
      });
      console.log('  [诊断] choose 后 inBattle=' + ib + ' ' + dbg);
      if (ib) {
        t = await doBattle(page);
      } else {
        console.log('  ⚠ choose ' + lfIdx + ' 后未进入战斗');
      }
      ldjReady = await hasDEvent(page, 71, 611);  // 神龙教 D* 表已放置 611（鹿鼎记战斗）
      if (ldjReady) {
        console.log('  ✓ 五毒教二刷(蓝凤凰) 实体#' + lfIdx + '（神龙教611已就位）');
        // 战斗胜利后 616 还有 14 段对话 + "是否要求加入"询问，翻页收尾避免协程挂起
        for (let p = 0; p < 22; p++) {
          t = await getT(page);
          if (t.includes('选择交互对象')) break;  // 对话结束，场景已重绘
          if (t.includes('是否要求加入')) {
            await cmd(page, 'choose 2'); await page.waitForTimeout(800);  // 拒绝加入，避免队伍变化
            continue;
          }
          await cmd(page, 'choose 1'); await page.waitForTimeout(1000);
        }
        break;
      }
    } else {
      // 未找到蓝凤凰实体：逐个尝试（守卫战斗 613×5 在前，触发后消耗）
      await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
      t = await getT(page);
      if (t.includes('战场态势') || t.includes('战斗')) {
        t = await doBattle(page);
      }
      ldjReady = await hasDEvent(page, 71, 611);
      if (ldjReady) {
        console.log('  ✓ 五毒教二刷(蓝凤凰) 实体' + ei + '（神龙教611已就位）');
        break;
      }
    }
    await cmd(page, 'choose 0'); await page.waitForTimeout(300);
  }
  if (!ldjReady) console.log('  ⚠ 五毒教二刷未触发 616（611 未就位）');
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);

  // 神龙教三刷/《鹿鼎记》— oldevent_611 战斗[95] → instruct_2(150,1) 得书
  // 611 是动态 D* 事件（五毒教二刷 616 放置于 JY.D[71][3][2]=611）。
  // 注意：不能用终端文本判断战斗（getT 返回累积历史，"战场态势"来自之前战斗会误判）；
  // 且每次触发事件后实体列表重建、索引错位——必须每轮重新 look、从 1 开始尝试，
  // 用 inBattle()（JY.Status==5）轮询等待战斗开始，再 doBattle。
  expect(await gotoScene(page, '神龍教')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  let gotLdj = false;
  for (let attempt = 0; attempt < 8 && !gotLdj; attempt++) {
    // 每轮 choose 前必须重新 look（choose 0 会退出实体列表回到场景命令模式，
    // 若不重新 look，后续 choose ei 会变成菜单选项/无效命令，永远选不中 611）。
    // 611 现在映射为命名实体"洪教主"（动态 D* 事件，与静态的 entity1 重名），
    // 优先从终端定位最后一个"洪教主"实体（动态 611 追加在静态之后）。
    await cmd(page, 'look'); await page.waitForTimeout(1200);
    const hjzIdx = await page.evaluate(() => {
      const term = window.__xterm; if (!term) return -1;
      const total = term.buffer.active.length;
      let last = -1;
      for (let y = total - 1; y >= 0; y--) {
        const raw = term.buffer.active.getLine(y)?.translateToString(true) || '';
        const m = raw.match(/^\D*(\d+)\.\s*(.*\S)\s*$/);
        if (m && m[2].includes('洪教主')) {
          const n = parseInt(m[1], 10);
          if (n > last) last = n;
        }
      }
      return last;
    });
    const startEi = hjzIdx > 1 ? hjzIdx : 1;  // 动态洪教主在静态(1)之后
    for (let ei = startEi; ei <= 15 && !gotLdj; ei++) {
      await cmd(page, 'choose ' + ei); await page.waitForTimeout(1500);
      // 611 有 6 段对话（instruct_1 不 yield，瞬间输出）后触发战斗[95]。
      for (let p = 0; p < 20 && !(await inBattle(page)); p++) {
        await page.waitForTimeout(500);
      }
      if (await inBattle(page)) {
        t = await doBattle(page);
      }
      if (await hasItem(page, 150)) {  // 《鹿鼎记》item 150
        console.log('  ✓ 神龙教三刷(鹿鼎记) 实体' + ei);
        gotLdj = true;
        break;
      }
      await cmd(page, 'choose 0'); await page.waitForTimeout(300);
    }
  }
  if (!gotLdj) console.log('  ⚠ 神龙教三刷未获得《鹿鼎记》');
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await hasItem(page, 150)).toBe(true);  // 《鹿鼎记》item 150

  // 光明顶二刷/《倚天屠龙记》— 完整链：
  //   光明顶109(谢逊) → instruct_26 #2（灵蛇岛 tile2 eventExtra 106→107→108）
  //   → 灵蛇岛触发108 → tile0 → 105（金花婆婆激将）→ 光明顶 111-116（tile94 → 115 圣火阵）
  //   → 光明顶触发115 圣火阵战斗[15] → 倚天屠龙记(155)
  expect(await gotoScene(page, '光明頂')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  // 触发谢逊(109)对话（tile94=109，由冰火岛67放置）→ instruct_26 #2 递增灵蛇岛 tile2 eventExtra。
  // 注意：不能用累积终端文本判断"谢逊"（冰火岛日志已含该词会误 break）；
  //       光明顶 D* 表有大量残留 tile 事件（六大派 83-88/90-95 等），谢逊109 实体索引约 16+，
  //       且每次触发搜索实体后实体列表重建、固定递增索引会错位 → 每轮重新 look、尝试到 25，
  //       触发战斗则 doBattle，用 Lua hasDEvent 检查灵蛇岛 D* 状态（与神龙教三刷同模式）。
  let xie108 = false;
  for (let attempt = 0; attempt < 12 && !xie108; attempt++) {
    // 每轮 choose 前必须重新 look（choose 0 会退出实体列表回到场景命令模式，
    // 若不重新 look，后续 choose ei 会变成菜单选项/无效命令，永远选不中 109）。
    // 谢逊(109) 现在是命名实体（eventNpcNames），优先从终端定位"谢逊"。
    await cmd(page, 'look'); await page.waitForTimeout(1200);
    const xsIdx = await page.evaluate(() => {
      const term = window.__xterm; if (!term) return -1;
      const total = term.buffer.active.length;
      let last = -1;
      for (let y = total - 1; y >= 0; y--) {
        const raw = term.buffer.active.getLine(y)?.translateToString(true) || '';
        const m = raw.match(/^\D*(\d+)\.\s*(.*\S)\s*$/);
        if (m && m[2].includes('谢逊')) {
          const n = parseInt(m[1], 10);
          if (n > last) last = n;
        }
      }
      return last;
    });
    const startEi = xsIdx > 1 ? xsIdx : 1;
    for (let ei = startEi; ei <= 25 && !xie108; ei++) {
      await cmd(page, 'choose ' + ei); await page.waitForTimeout(2000);
      // 可能触发六大派残留战斗（83-88）→ doBattle 打完再继续
      for (let p = 0; p < 20 && !(await inBattle(page)); p++) {
        await page.waitForTimeout(300);
      }
      if (await inBattle(page)) {
        await doBattle(page);
      }
      xie108 = await hasDEvent(page, 73, 108);  // 灵蛇岛 tile2 eventExtra 已递增到 108
      if (xie108) { console.log('  ✓ 光明顶二刷(谢逊109→灵蛇岛108) 实体' + ei); break; }
      await cmd(page, 'choose 0'); await page.waitForTimeout(300);
    }
  }
  if (!xie108) console.log('  ⚠ 光明顶二刷未触发谢逊109（灵蛇岛108未就位）');
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);

  // 灵蛇岛：触发108 → tile0=105 → 金花婆婆激将 → 光明顶 111-116
  // 两阶段：
  //   阶段1：触发 108（灵蛇岛 tile2 eventExtra，无对话纯 instruct_3）→ tile0=105（金花婆婆激将就位）。
  //         108 显示为"搜索"实体，从实体 1 开始逐个触发，用 hasDEvent(73,105) 判断（快）。
  //   阶段2：105 就位后，从终端定位"金花婆婆"命名实体（105 与静态 98 同名，取最后一个），
  //         触发后 oldevent_105 有 13 段对话，必须翻页翻完才会设置光明顶 115。
  expect(await gotoScene(page, '靈蛇島')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  // 阶段1：触发 108 → 105 就位
  let has105 = await hasDEvent(page, 73, 105);
  for (let attempt = 0; attempt < 6 && !has105; attempt++) {
    await cmd(page, 'look'); await page.waitForTimeout(1200);
    for (let ei = 1; ei <= 10 && !has105; ei++) {
      await cmd(page, 'choose ' + ei); await page.waitForTimeout(1200);
      for (let p = 0; p < 10 && !(await inBattle(page)); p++) await page.waitForTimeout(200);
      if (await inBattle(page)) await doBattle(page, 60);
      has105 = await hasDEvent(page, 73, 105);
      if (has105) { console.log('  ✓ 灵蛇岛(108→105就位) 实体' + ei); break; }
      await cmd(page, 'choose 0'); await page.waitForTimeout(200);
    }
  }
  if (!has105) console.log('  ⚠ 灵蛇岛108未触发（105未就位）');
  // 阶段2：触发 105（金花婆婆激将）→ 翻页对话 → 光明顶 115
  let gm115 = await hasDEvent(page, 11, 115);
  if (has105 && !gm115) {
    for (let attempt = 0; attempt < 6 && !gm115; attempt++) {
      await cmd(page, 'look'); await page.waitForTimeout(1200);
      // 定位"金花婆婆"实体（105 激将；静态 98 是战斗事件已消耗/不同实体，取最后一个）
      const jhIdx = await page.evaluate(() => {
        const term = window.__xterm; if (!term) return -1;
        const total = term.buffer.active.length;
        let last = -1;
        for (let y = total - 1; y >= 0; y--) {
          const raw = term.buffer.active.getLine(y)?.translateToString(true) || '';
          const m = raw.match(/^\D*(\d+)\.\s*(.*\S)\s*$/);
          if (m && m[2].includes('金花婆婆')) {
            const n = parseInt(m[1], 10);
            if (n > last) last = n;
          }
        }
        return last;
      });
      const startEi = jhIdx > 1 ? jhIdx : 1;
      for (let ei = startEi; ei <= 12 && !gm115; ei++) {
        await cmd(page, 'choose ' + ei); await page.waitForTimeout(1500);
        // 105 对话 13 段，翻页翻完（直到回到实体列表）
        for (let pg = 0; pg < 16; pg++) {
          t = await getT(page);
          const tail4 = t.split('\n').slice(-4).join('');
          if (tail4.includes('选择交互对象') || tail4.includes('输入 choose')) break;
          await cmd(page, 'choose 1'); await page.waitForTimeout(1000);
        }
        gm115 = await hasDEvent(page, 11, 115);
        if (gm115) { console.log('  ✓ 灵蛇岛(105激将→光明顶115) 实体' + ei); break; }
        await cmd(page, 'choose 0'); await page.waitForTimeout(200);
      }
    }
  }
  if (!gm115) console.log('  ⚠ 灵蛇岛未触发105激将（光明顶115未就位）');
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 灵蛇岛(108→105 金花婆婆激将)');

  // 光明顶三刷：触发115 圣火阵 → 战斗[15] → 倚天屠龙记(155)
  // oldevent_115 有 instruct_5(6,0) 询问"是否与之过招"（choose 1=是）→ 必须先确认再等战斗。
  // 注意：不能用累积终端文本判断"是否与之过招"（历史残留会误判）→ 用 Lua 检查 __instruct5_waiting；
  //       且每次触发后实体列表重建、索引错位 → 每轮重新 look、优先定位命名实体"圣火阵"(115)。
  expect(await gotoScene(page, '光明頂')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  let got155 = false;
  for (let attempt = 0; attempt < 12 && !got155; attempt++) {
    await cmd(page, 'look'); await page.waitForTimeout(1200);
    // 优先定位命名实体"圣火阵"（115，金花婆婆激将后放置 tile94）
    const shIdx = await page.evaluate(() => {
      const term = window.__xterm; if (!term) return -1;
      const total = term.buffer.active.length;
      let last = -1;
      for (let y = total - 1; y >= 0; y--) {
        const raw = term.buffer.active.getLine(y)?.translateToString(true) || '';
        const m = raw.match(/^\D*(\d+)\.\s*(.*\S)\s*$/);
        if (m && m[2].includes('圣火阵')) {
          const n = parseInt(m[1], 10);
          if (n > last) last = n;
        }
      }
      return last;
    });
    const startEi = shIdx > 1 ? shIdx : 1;
    for (let ei = startEi; ei <= 12 && !got155; ei++) {
      await cmd(page, 'choose ' + ei); await page.waitForTimeout(2000);
      // 响应 instruct_5 询问（Lua 检查 __instruct5_waiting，不依赖终端文本）
      const i5 = await page.evaluate(async () => {
        if (!window.__luaEval) return false;
        const r = await window.__luaEval('return tostring(rawget(_G, "__instruct5_waiting") == true)');
        return r && r.ok && r.result === 'true';
      });
      if (i5) {
        await cmd(page, 'choose 1'); await page.waitForTimeout(2500);
      }
      for (let p = 0; p < 20 && !(await inBattle(page)); p++) {
        await page.waitForTimeout(500);
      }
      if (await inBattle(page)) {
        t = await doBattle(page);
      }
      got155 = await hasItem(page, 155);  // 《倚天屠龙记》item 155
      if (got155) { console.log('  ✓ 光明顶二刷(倚天屠龙记) 实体' + ei); break; }
      await cmd(page, 'choose 0'); await page.waitForTimeout(300);
    }
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await hasItem(page, 155)).toBe(true);  // 《倚天屠龙记》item 155

  // 渤泥岛二刷/《碧血剑》— oldevent_636（需金蛇剑；品德80+直接得书，否则走战斗路径）
  // 当前品德约 60（<80）→ 袁承志说"仁义方面还要加强"后 instruct_5 询问"是否选择战斗"，
  // choose 1=是 → 战斗[101] → 胜利 → instruct_2(156) 得碧血剑。必须处理 instruct_5 + 战斗！
  expect(await gotoScene(page, '浡泥島')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 袁承志
  // 翻页对话 + 响应 instruct_5 询问 + doBattle，直到拿到碧血剑156
  let got156 = await hasItem(page, 156);
  for (let pg = 0; pg < 12 && !got156; pg++) {
    // 检查 instruct_5 询问（Lua 标记，不依赖累积终端文本）
    const i5 = await page.evaluate(async () => {
      if (!window.__luaEval) return false;
      const r = await window.__luaEval('return tostring(rawget(_G, "__instruct5_waiting") == true)');
      return r && r.ok && r.result === 'true';
    });
    if (i5) { await cmd(page, 'choose 1'); await page.waitForTimeout(2500); }
    for (let p = 0; p < 20 && !(await inBattle(page)); p++) await page.waitForTimeout(400);
    if (await inBattle(page)) await doBattle(page);
    got156 = await hasItem(page, 156);
    if (got156) break;
    // 翻页（对话/事件推进），回到命令模式即停
    const tail5 = (await getT(page)).split('\n').slice(-4).join('');
    if (tail5.includes('选择交互对象') || tail5.includes('输入 choose')) break;
    await cmd(page, 'choose 1'); await page.waitForTimeout(1200);
  }
  console.log('  ✓ 渤泥岛二刷(碧血剑): ' + (got156 ? '得书' : '对话完成'));
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await hasItem(page, 156)).toBe(true);  // 《碧血剑》item 156

  // 侠客岛二刷/《侠客行》— oldevent_363（需石破天在队）
  // 注意：不能用终端文本"侠客行/太玄经"判断（累积历史会误判提前 break）→ 用 Lua hasItem(154)；
  //       363 有大量对话（约 20+ 段 instruct_1），必须翻页翻完才会执行 instruct_2(154) 给书。
  expect(await gotoScene(page, '俠客島')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  console.log('  [诊断] 侠客岛二刷 石破天在队:', await hasTeamMember(page, 38));
  let got154 = await hasItem(page, 154);
  for (let ei = 1; ei <= 25 && !got154; ei++) {
    await cmd(page, 'choose ' + ei); await page.waitForTimeout(2500);
    // 翻页对话直到回到实体列表/命令模式（363 对话长，必须翻完才给书）
    for (let pg = 0; pg < 24; pg++) {
      t = await getT(page);
      const tail4 = t.split('\n').slice(-4).join('');
      if (tail4.includes('选择交互对象') || tail4.includes('输入 choose')) break;
      await cmd(page, 'choose 1'); await page.waitForTimeout(1000);
    }
    got154 = await hasItem(page, 154);  // 《侠客行》item 154
    if (got154) { console.log('  ✓ 侠客岛二刷(侠客行) 实体' + ei); break; }
    await cmd(page, 'choose 0'); await page.waitForTimeout(300);
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await hasItem(page, 154)).toBe(true);  // 《侠客行》item 154

  expect(await noE(page)).toBeTruthy();
  // P6 最终状态存 slot 2（P7 开头 loadTestState(2) 加载此槽位继续）
  expect(await saveTestState(page, 2)).toBe(true);
  flushSaveCache('bridge-p6.json');
  console.log('  ✓ P6b 完成');
});
