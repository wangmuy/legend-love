// tests/walkthrough-p2.spec.js
// quick_pass_game.md: 回族部落→胡斐加入→冰火岛→绝情谷→大轮寺
const { test, expect } = require('@playwright/test');
const { waitForPageReady, waitForGameReady } = require('./helpers/setup');
const { saveTestState, loadTestState, gotoScene, flushSaveCache, loadSaveCache } = require('./helpers/walkthrough');
const { cmd, getT, noE } = require('./helpers/term');

const SETTLE = 5000;

test('P2: 回族→胡斐→冰火岛→绝情谷→大轮寺', async ({ page }) => {
  test.setTimeout(300000);
  loadSaveCache('bridge-p1.json');
  await page.goto('/'); await waitForPageReady(page); await waitForGameReady(page); await page.waitForTimeout(2000);
  expect(await loadTestState(page, 6)).toBe(true);

  // 无量山洞已在P1完成，从回族部落继续
  await gotoScene(page, '回族部落');
  let t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 回族部落');

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
    return r && r.ok && r.result === 'true';
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

  // 冰火岛/金毛
  expect(await loadTestState(page, 1)).toBe(true);
  await gotoScene(page, '冰火島');
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 冰火岛');

  // 绝情谷/玉玺/断肠草/君子剑/玉蜂针
  expect(await loadTestState(page, 1)).toBe(true);
  await gotoScene(page, '絕情谷');
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 2)).toBe(true);
  console.log('  ✓ 绝情谷');

  // 冰蚕洞/天山雪莲
  await gotoScene(page, '冰蠶洞');
  t = await getT(page); expect(t).toContain('你来到了');
  console.log('  ✓ 冰蚕洞');

  // 船停大轮寺东 → 大轮寺
  await gotoScene(page, '大輪寺');
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 大轮寺');

  expect(await noE(page)).toBeTruthy();
  flushSaveCache('bridge-p2.json');
  console.log('  ✓ P2 完成');
});
