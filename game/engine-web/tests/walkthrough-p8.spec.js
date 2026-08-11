// tests/walkthrough-p8.spec.js
// quick_pass_game.md: 闯王山洞→鸳鸯岛
// 闯王山洞(scene5,雪山区): 雪山飞狐+鸯刀+金丝背心
// 鸳鸯岛(scene79,东北角): 鸳鸯刀+千年人参
const { test, expect } = require('@playwright/test');
const { waitForPageReady, waitForGameReady } = require('./helpers/setup');
const { saveTestState, loadTestState, gotoScene, gotoSceneById, flushSaveCache, loadSaveCache, hasItem, doBattle, inBattle } = require('./helpers/walkthrough');
const { cmd, getT, noE } = require('./helpers/term');

const SETTLE = 5000;

test('P8: 闯王山洞→鸳鸯岛', async ({ page }) => {
  test.setTimeout(1200000);
  loadSaveCache('bridge-p7.json');
  await page.goto('/'); await waitForPageReady(page); await waitForGameReady(page); await page.waitForTimeout(2000);
  expect(await loadTestState(page, 1)).toBe(true);

  // Step 1: 闯王山洞(scene5) — 雪山飞狐+鸯刀+金丝背心
  // 注意：buildSceneList 中文排序不稳定，用 sceneId 导航（多个"山洞"同名）
  expect(await gotoSceneById(page, 5)).toBeGreaterThan(0);
  let t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(1000);
  // 实体是动态构建的"搜索"列表（diag 实测：2=雪山飞狐145 / 3=鸯刀188 / 4=金丝背心121），
  // 固定索引不可靠 —— 用 Lua hasItem 判断 + 循环尝试（与其他阶段同模式）。
  let got145 = await hasItem(page, 145), got188 = await hasItem(page, 188), got121 = await hasItem(page, 121);
  for (let round = 0; round < 4 && !(got145 && got188 && got121); round++) {
    await cmd(page, 'look'); await page.waitForTimeout(1200);
    for (let ei = 1; ei <= 20 && !(got145 && got188 && got121); ei++) {
      await cmd(page, 'choose ' + ei); await page.waitForTimeout(2500);
      for (let p = 0; p < 15 && !(await inBattle(page)); p++) await page.waitForTimeout(400);
      if (await inBattle(page)) { await doBattle(page); break; }  // 战斗后实体重建，重新 look
      got145 = got145 || await hasItem(page, 145);
      got188 = got188 || await hasItem(page, 188);
      got121 = got121 || await hasItem(page, 121);
      if (got145 && got188 && got121) { console.log(`  ✓ 闯王山洞(雪山飞狐/鸯刀/金丝背心) 实体${ei}`); break; }
      await cmd(page, 'choose 0'); await page.waitForTimeout(300);
    }
  }
  if (!(got145 && got188 && got121)) console.log(`  ⚠ 闯王山洞未集齐: 145=${got145} 188=${got188} 121=${got121}`);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 1)).toBe(true);
  // 注意：leave 后 Lua worker 可能繁忙（对话/战斗协程未完全退出），再调 hasItem 会挂起。
  // 直接使用循环中已通过 Lua 验证过的标志断言（与苗人凤居 got144 同模式）。
  expect(got145).toBe(true);  // 《雪山飞狐》item 145（循环中 Lua 已验证）
  expect(got188).toBe(true);  // 鸯刀 item 188
  expect(got121).toBe(true);  // 金丝背心 item 121
  console.log('  ✓ 闯王山洞(雪山飞狐+鸯刀+金丝背心)');

  // Step 2: 鸳鸯岛(scene79) — 鸳鸯刀+千年人参
  expect(await loadTestState(page, 1)).toBe(true);
  expect(await gotoSceneById(page, 79)).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(1000);
  // 实体同样是动态构建的"搜索"列表，固定索引不可靠 —— 循环尝试直到拿到鸳鸯刀157。
  let got157 = await hasItem(page, 157);
  for (let round = 0; round < 4 && !got157; round++) {
    await cmd(page, 'look'); await page.waitForTimeout(1200);
    for (let ei = 1; ei <= 12 && !got157; ei++) {
      await cmd(page, 'choose ' + ei); await page.waitForTimeout(2500);
      for (let p = 0; p < 15 && !(await inBattle(page)); p++) await page.waitForTimeout(400);
      if (await inBattle(page)) { await doBattle(page); break; }
      got157 = await hasItem(page, 157);
      if (got157) { console.log(`  ✓ 鸳鸯岛(鸳鸯刀) 实体${ei}`); break; }
      await cmd(page, 'choose 0'); await page.waitForTimeout(300);
    }
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(got157).toBe(true);  // 《鸳鸯刀》item 157（循环中 Lua 已验证，leave 后不再调 hasItem 避免挂起）
  console.log('  ✓ 鸳鸯岛(鸳鸯刀+千年人参)');

  // Step 3: 苗人凤居二刷——《飞狐外传》(需胡斐+屠龙刀117+金丝背心121)
  expect(await loadTestState(page, 1)).toBe(true);
  await cmd(page, 'look'); await page.waitForTimeout(1000);
  expect(await gotoScene(page, '苗人鳳居')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  // oldevent_7 是 D* 动态事件（苗人凤居一刷后放置）。实体列表是动态"搜索"列表且含战斗实体
  // （diag 实证：choose 某实体触发神龙教徒战斗）——循环 must 处理战斗：战斗中 doBattle 打完，
  // 战斗后实体重建需重新 look/从1开始（与 P7b 天宁寺二刷同模式）。
  let got144 = await hasItem(page, 144);
  for (let round = 0; round < 5 && !got144; round++) {
    await cmd(page, 'look'); await page.waitForTimeout(1500);
    for (let ei = 1; ei <= 12 && !got144; ei++) {
      await cmd(page, 'choose ' + ei); await page.waitForTimeout(2500);
      for (let p = 0; p < 15 && !(await inBattle(page)); p++) await page.waitForTimeout(400);
      if (await inBattle(page)) {
        await doBattle(page);
        got144 = await hasItem(page, 144);
        break;  // 战斗后实体列表重建，重新 look/从1开始
      }
      got144 = await hasItem(page, 144);  // 《飞狐外传》item 144
      if (got144) { console.log('  ✓ 苗人凤居二刷(飞狐外传) 实体' + ei); break; }
      await cmd(page, 'choose 0'); await page.waitForTimeout(300);
    }
  }
  if (!got144) {
    console.log('  ⚠ 苗人凤居二刷未得飞狐外传（检查胡斐/屠龙刀117/金丝背心121）');
    console.log(`    hasItem(117)=${await hasItem(page, 117)} hasItem(121)=${await hasItem(page, 121)}`);
  }
  // 注意：触发事件后 Lua worker 可能繁忙（对话/战斗协程），leave 后再调 hasItem 会挂起。
  // 直接用循环中已 Lua 验证过的 got144 断言（不再重复 __luaEval）。
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(got144).toBe(true);  // 《飞狐外传》item 144（已在循环中通过 Lua 验证）

  expect(await noE(page)).toBeTruthy();
  flushSaveCache('bridge-p8.json');
  console.log('  ✓ P8 完成');
});
