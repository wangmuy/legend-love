// quick_pass_game.md: 桃花岛→福威镖局→天宁寺→梅庄→黑木崖→丐帮→主角居→天书收集
// 注意：桃花岛《射雕英雄传》必须最先完成（紧跟 loadTestState(2) 之后），
// 前置流程（福威战斗48 + 天宁寺存档重载）会破坏战斗[76]数据、导致无法胜利
// （diag-p7th4 复现冗余重载损坏战斗76；diag-p7th17 验证直接加载→桃花岛 148=true）。
const { test, expect } = require('@playwright/test');
const { waitForPageReady, waitForGameReady } = require('./helpers/setup');
const { saveTestState, loadTestState, gotoScene, flushSaveCache, loadSaveCache, hasItem, doBattle, inBattle } = require('./helpers/walkthrough');
const { cmd, getT, noE } = require('./helpers/term');

const SETTLE = 5000;

test('P7: 桃花岛→福威→天宁→梅庄→黑木崖→丐帮→主角居→天书收集', async ({ page }) => {
  test.setTimeout(900000);
  loadSaveCache('bridge-p6.json');
  await page.goto('/'); await waitForPageReady(page); await waitForGameReady(page); await page.waitForTimeout(2000);

  expect(await loadTestState(page, 2)).toBe(true);
  let t = await getT(page);

  // ===== 桃花島/《射雕英雄传》— 最先做（diag-p7th17 验证此路径可得 148） =====
  // 黄蓉对话(oldevent_466) → tile1=469（郭靖"试试我的武功"→ instruct_5 询问是否选择战斗）
  // → choose 1=是 → 战斗[76]郭靖 → 战斗[77]黄蓉 → 得书 148。
  // 注意：此处不做任何存档重载（冗余重载会损坏战斗[76]数据，diag-p7th4 复现）。
  expect(await gotoScene(page, '桃花島')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  let got148 = await hasItem(page, 148);
  // 阶段1：黄蓉(466) 对话 → tile1=469
  if (!got148) {
    await cmd(page, 'look'); await page.waitForTimeout(1500);
    await cmd(page, 'choose 1'); await page.waitForTimeout(2500);  // 黄蓉(466)
    // 翻页对话直到回到实体列表/命令模式（466 对话长，翻完才执行结尾的 instruct_3 放置 469）
    for (let pg = 0; pg < 25 && !got148; pg++) {
      const tail5 = (await getT(page)).split('\n').slice(-4).join('');
      if (tail5.includes('选择交互对象') || tail5.includes('输入 choose')) break;
      await cmd(page, 'choose 1'); await page.waitForTimeout(1200);
    }
    await cmd(page, 'choose 0'); await page.waitForTimeout(400);
  }
  // 阶段2：定位"郭靖"(469) → instruct_5 → 战斗两场（doBattle 自动续战战斗77）
  for (let attempt = 0; attempt < 8 && !got148; attempt++) {
    await cmd(page, 'look'); await page.waitForTimeout(1500);
    const gjIdx = await page.evaluate(() => {
      const term = window.__xterm; if (!term) return -1;
      const total = term.buffer.active.length;
      let last = -1;
      for (let y = total - 1; y >= 0; y--) {
        const raw = term.buffer.active.getLine(y)?.translateToString(true) || '';
        const m = raw.match(/^\D*(\d+)\.\s*(.*\S)\s*$/);
        if (m && m[2].includes('郭靖')) {
          const n = parseInt(m[1], 10);
          if (n > last) last = n;
        }
      }
      return last;
    });
    if (gjIdx < 1) {
      // 郭靖未出现：可能 466 未触发，先再触发黄蓉
      await cmd(page, 'choose 1'); await page.waitForTimeout(2500);
      for (let pg = 0; pg < 25 && !got148; pg++) {
        const tail5 = (await getT(page)).split('\n').slice(-4).join('');
        if (tail5.includes('选择交互对象') || tail5.includes('输入 choose')) break;
        await cmd(page, 'choose 1'); await page.waitForTimeout(1200);
      }
      await cmd(page, 'choose 0'); await page.waitForTimeout(400);
      continue;
    }
    await cmd(page, 'choose ' + gjIdx); await page.waitForTimeout(2500);
    for (let pg = 0; pg < 20 && !got148; pg++) {
      const i5 = await page.evaluate(async () => {
        if (!window.__luaEval) return false;
        const r = await window.__luaEval('return tostring(rawget(_G, "__instruct5_waiting") == true)');
        return r && r.ok && r.result === 'true';
      });
      if (i5) { await cmd(page, 'choose 1'); await page.waitForTimeout(2500); }
      for (let p = 0; p < 20 && !(await inBattle(page)); p++) await page.waitForTimeout(400);
      if (await inBattle(page)) {
        t = await doBattle(page);  // doBattle 连续循环：战斗76胜利后协程自动续接战斗77
        // 若 doBattle 返回时战斗77尚未启动，等待其启动后再续战
        for (let p = 0; p < 20 && !(await inBattle(page)); p++) await page.waitForTimeout(400);
        if (await inBattle(page)) await doBattle(page);
      }
      got148 = await hasItem(page, 148);
      if (got148) { console.log('  ✓ 桃花岛(黄蓉→战斗得射雕英雄传) 郭靖实体#' + gjIdx); break; }
      const tail5 = (await getT(page)).split('\n').slice(-4).join('');
      if (tail5.includes('选择交互对象') || tail5.includes('输入 choose')) break;
      await cmd(page, 'choose 1'); await page.waitForTimeout(1200);
    }
    if (got148) break;
    await cmd(page, 'choose 0'); await page.waitForTimeout(300);
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await hasItem(page, 148)).toBe(true);  // 《射雕英雄传》item 148（品德90+或战斗[76]/[77]）
  console.log('  ✓ 桃花岛(黄蓉→战斗得射雕英雄传)');

  // 福威镖局/溪山行旅图 — 林平之对话 + 宝箱搜索
  // 注意：oldevent_286（林平之对话）中途触发战斗[48]（instruct_6(48)，敌人=林平之）。
  // 必须 doBattle 打赢，否则战斗状态残留（wmapContext.phase/JY.War）会破坏后续战斗。
  expect(await gotoScene(page, '福威鏢局')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 林平之
  // 处理对话中触发的战斗[48]
  for (let p = 0; p < 10 && !(await inBattle(page)); p++) await page.waitForTimeout(400);
  if (await inBattle(page)) { t = await doBattle(page); }
  // 战斗后继续翻页对话（286 剩余对话：青城派求助等）
  for (let pg = 0; pg < 25; pg++) {
    const tail5 = (await getT(page)).split('\n').slice(-4).join('');
    if (tail5.includes('选择交互对象') || tail5.includes('输入 choose')) break;
    await cmd(page, 'choose 1'); await page.waitForTimeout(1200);
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'choose 2'); await page.waitForTimeout(2000);  // 宝箱(银两+智慧果)
  await cmd(page, 'choose 3'); await page.waitForTimeout(2000);  // 宝箱(溪山行旅图+)
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 福威镖局');

  // 天宁寺/《连城诀》— oldevent_605
  expect(await gotoScene(page, '天寧寺')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  t = await getT(page);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 1)).toBe(true);
  console.log('  ✓ 天宁寺');

  // 梅庄/黑木令 — 完成地牢链拿黑木令牌(125)（笑傲江湖151前置，diag-p7th18 验证：
  // 梅庄 look → choose "→ 梅莊地牢"出口实体 → 地牢 choose 2(oldevent_277) → 黑木令牌125+吸星大法64）
  // 注意：不再 loadTestState(1) 重载（冗余重载会损坏后续战斗数据，diag-p7th4 复现），
  // 状态继续保存在内存中（与桃花岛段一致的做法）。
  expect(await gotoScene(page, '梅莊')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(1500);
  const exitIdx = await page.evaluate(() => {
    const term = window.__xterm; if (!term) return -1;
    const total = term.buffer.active.length;
    let last = -1;
    for (let y = total - 1; y >= 0; y--) {
      const raw = term.buffer.active.getLine(y)?.translateToString(true) || '';
      const m = raw.match(/^\D*(\d+)\.\s*(.*\S)\s*$/);
      if (m && m[2].includes('梅莊地牢')) {
        const n = parseInt(m[1], 10);
        if (n > last) last = n;
      }
    }
    return last;
  });
  if (exitIdx > 0) {
    await cmd(page, 'choose ' + exitIdx); await page.waitForTimeout(2500);  // 进入地牢(scene82)
    await cmd(page, 'look'); await page.waitForTimeout(1500);
    await cmd(page, 'choose 2'); await page.waitForTimeout(2000);  // oldevent_277：吸星大法+黑木令牌
    for (let p = 0; p < 20; p++) {
      const tail5 = (await getT(page)).split('\n').slice(-4).join('');
      if (tail5.includes('选择交互对象') || tail5.includes('输入 choose')) break;
      await cmd(page, 'choose 1'); await page.waitForTimeout(1000);
    }
    await cmd(page, 'choose 0'); await page.waitForTimeout(400);
  }
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 梅庄(黑木令牌125: ' + await hasItem(page, 125) + ')');

  // ===== 黑木崖内部/《笑傲江湖》— 紧接梅庄令牌之后执行（diag-p7th18 验证的顺序：
  // 黑木令牌125 → 黑木崖实体7 战斗 → 151 成功；若隔开守卫段/丐帮/主角居，场景26 D* 状态变化会导致失败）=====
  // 守卫(316)对话后使用黑木令牌(317)进入内部，东方不败战斗 oldevent_320 → 得书151。
  // 注意：用 Lua hasItem(151) 判断；触发战斗则 doBattle；响应 __instruct4_waiting（令牌使用确认）
  // 与 __instruct5_waiting（是否战斗）；使用令牌后重新 look 从实体1重试。
  expect(await gotoScene(page, '黑木崖')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  let got151 = await hasItem(page, 151);
  let tokenUsed = false;
  for (let attempt = 0; attempt < 10 && !got151; attempt++) {
    await cmd(page, 'look'); await page.waitForTimeout(1500);
    for (let ei = 1; ei <= 15 && !got151; ei++) {
      await cmd(page, 'choose ' + ei); await page.waitForTimeout(2500);
      // 响应 instruct_4（黑木令牌使用确认）/ instruct_5（是否战斗）
      for (let pg = 0; pg < 12 && !got151; pg++) {
        const i4 = await page.evaluate(async () => {
          if (!window.__luaEval) return false;
          const r = await window.__luaEval('return tostring(rawget(_G, "__instruct4_waiting") == true)');
          return r && r.ok && r.result === 'true';
        });
        if (i4) {
          console.log(`  [黑木崖实体${ei} pg${pg}] instruct_4 → choose 1（使用黑木令牌）`);
          await cmd(page, 'choose 1'); await page.waitForTimeout(2500);
          tokenUsed = true;
          break;  // 使用令牌后场景实体列表变化，跳出 pg 循环强制重新 look
        }
        const i5 = await page.evaluate(async () => {
          if (!window.__luaEval) return false;
          const r = await window.__luaEval('return tostring(rawget(_G, "__instruct5_waiting") == true)');
          return r && r.ok && r.result === 'true';
        });
        if (i5) { await cmd(page, 'choose 1'); await page.waitForTimeout(2500); }
        for (let p = 0; p < 15 && !(await inBattle(page)); p++) await page.waitForTimeout(400);
        if (await inBattle(page)) await doBattle(page);
        got151 = await hasItem(page, 151);  // 《笑傲江湖》item 151
        if (got151) break;
        const tail5 = (await getT(page)).split('\n').slice(-4).join('');
        if (tail5.includes('选择交互对象') || tail5.includes('输入 choose')) break;
        await cmd(page, 'choose 1'); await page.waitForTimeout(1000);
      }
      if (got151) { console.log('  ✓ 黑木崖内部(笑傲江湖) 实体' + ei); break; }
      if (tokenUsed) break;  // 令牌已使用，重新 look
      await cmd(page, 'choose 0'); await page.waitForTimeout(300);
    }
    if (got151) break;
    console.log(`  [黑木崖 attempt${attempt + 1} 完成，重新 look]`);
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await hasItem(page, 151)).toBe(true);  // 《笑傲江湖》item 151
  console.log('  ✓ 黑木崖内部(笑傲江湖)');

  // 黑木崖守卫对话(oldevent_316) — 前置对话（令牌已用，纯剧情）
  expect(await gotoScene(page, '黑木崖')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  t = await getT(page);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 黑木崖(守卫)');

  // 丐帮/《天龙八部》— 乔峰对话(oldevent_525)
  expect(await gotoScene(page, '丐幫')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  // entity 1=乔峰
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);  // 对话
  t = await getT(page);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 2)).toBe(true);
  console.log('  ✓ 丐帮(乔峰)');

  expect(await noE(page)).toBeTruthy();
  flushSaveCache('bridge-p7.json');
  console.log('  ✓ P7 前半段完成（天书收集见 walkthrough-p7b.spec.js）');
});
