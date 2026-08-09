// tests/walkthrough-p1.spec.js
// 按 quick_pass_game.md 攻略：南贤→田伯光加入→闫基战斗→铁掌帮→段誉加入→无量山洞
// 纯用户命令，每步都模拟真实玩家操作
const { test, expect } = require('@playwright/test');
const { waitForPageReady, waitForGameReady } = require('./helpers/setup');
const { saveTestState, loadTestState, flushSaveCache, hasItem } = require('./helpers/walkthrough');
const { cmd, getT, noE } = require('./helpers/term');

const SETTLE = 2000;

// gotoScene: leave → list → 找到场景索引 → 导航
async function gotoScene(p, name) {
  await cmd(p, 'leave'); await p.waitForTimeout(500);
  await cmd(p, 'list'); await p.waitForTimeout(3000);
  const idx = await p.evaluate((n) => {
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
  if (idx > 0) { await cmd(p, 'choose ' + idx); await p.waitForTimeout(SETTLE); }
  return idx;
}

test('P1: 南贤→田伯光加入→闫基战斗→铁掌→段誉→无量', async ({ page }) => {
  test.setTimeout(600000);
  await page.goto('/'); await waitForPageReady(page); await waitForGameReady(page); await page.waitForTimeout(2000);

  // Step 1: 开局 — choose 1(重新开始) → choose 1(确认属性) → leave → 存档
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  let t = await getT(page); expect(t).toContain('生命');
  await cmd(page, 'choose 1'); await page.waitForTimeout(SETTLE);
  t = await getT(page); expect(t).toContain('软体娃娃');
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 1)).toBe(true);
  console.log('  ✓ 开局');

  // Step 2: 南贤对话 — Entity 1=搜索(柜子), Entity 2=南贤
  expect(await loadTestState(page, 1)).toBe(true);
  expect(await gotoScene(page, '南賢居')).toBeGreaterThan(0);
  await cmd(page, 'choose 2'); await page.waitForTimeout(3000);  // 南贤(entity 2)
  await cmd(page, 'choose 1'); await page.waitForTimeout(4000);  // 对话
  t = await getT(page); expect(t).toContain('南贤');
  await cmd(page, 'choose 0'); await page.waitForTimeout(1000);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 1)).toBe(true);
  console.log('  ✓ 南贤对话');

  // Step 3: 田伯光加入 — Entity 1=搜索, Entity 2=田伯光NPC → 对话 → 招人
  expect(await loadTestState(page, 1)).toBe(true);
  expect(await gotoScene(page, '田伯光居')).toBeGreaterThan(0);
  await cmd(page, 'choose 2'); await page.waitForTimeout(3000);  // 选田伯光(entity 2)
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);  // 选"对话"
  // 田伯光对话有多页，逐个跳过
  for (let d = 0; d < 10; d++) {
    await cmd(page, 'choose 1'); await page.waitForTimeout(2000);
    t = await getT(page);
    if (t.includes('要求加入') || t.includes('田伯光加入') || t.includes('田伯光')) break;
  }
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 选"是"（加入）
  t = await getT(page); expect(t).toContain('田伯光');
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  // 搜索 Entity 1（oldevent_918）→ 得鸳刀+黑血神针（用于鸳鸯岛 P8）
  await cmd(page, 'choose 1'); await page.waitForTimeout(2000);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 2)).toBe(true);
  console.log('  ✓ 田伯光加入');

  // Step 4: 唐诗山东/山洞(坐标364:279附近, scene 65) — 唐诗选辑(连城诀前置, oldevent_602)
  // 同名"山洞"场景较多，按坐标(364,279)定位，并通过 goToScene(item) 直接导航（与 gotoScene helper 一致）
  expect(await loadTestState(page, 2)).toBe(true);
  const tangGo = await page.evaluate(async () => {
    const lua = window.__luaEval; if (!lua) return false;
    const code = [
      'local bs = rawget(_G, "buildSceneList")',
      'if not bs then return "false" end',
      'local items = bs()',
      'if not items then return "false" end',
      'local target = nil',
      'for _, item in ipairs(items) do',
      '  if item.name == "山洞" and item.entry and tonumber(item.entry.mapX) == 364 and tonumber(item.entry.mapY) == 279 then target = item break end',
      'end',
      'if not target then return "false" end',
      'local gs = rawget(_G, "goToScene")',
      'if not gs then return "false" end',
      'gs(target)',
      'return "true"',
    ].join('\n');
    const r = await lua(code);
    return r && r.ok && r.result === 'true';
  });
  expect(tangGo).toBe(true);
  await page.waitForTimeout(SETTLE);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  // Entity 2=oldevent_602 → 唐诗选辑(item 160)
  await cmd(page, 'choose 2'); await page.waitForTimeout(3000);
  expect(await hasItem(page, 160)).toBe(true);  // 唐诗选辑(160)
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  // 关键：必须在此保存（含唐诗选辑160），否则 Step 5 开头的 loadTestState(2) 会回滚丢弃 160，
  // 导致连城诀链（P7b 天宁寺二刷）永远拿不到《连城诀》(146)
  expect(await saveTestState(page, 2)).toBe(true);
  console.log('  ✓ 唐诗山东(唐诗选辑)');

  // Step 5: 闫基战斗 — choose 4(瓦片事件) → 战斗 → 胜利
  expect(await loadTestState(page, 2)).toBe(true);
  expect(await gotoScene(page, '閰基居')).toBeGreaterThan(0);
  await cmd(page, 'choose 4'); await page.waitForTimeout(5000);
  t = await getT(page); expect(t).toContain('阎基');
  await cmd(page, 'look'); await page.waitForTimeout(1000);
  // 战斗：移动(choose 5→1) → 循环攻击(choose 1→1) 直到胜利
  for (let r = 0; r < 10; r++) {
    if (r === 0) { await cmd(page, 'choose 5'); await page.waitForTimeout(300);
                   await cmd(page, 'choose 1'); await page.waitForTimeout(300); }
    await cmd(page, 'choose 1'); await page.waitForTimeout(300);
    await cmd(page, 'choose 1'); await page.waitForTimeout(300);
    t = await getT(page);
    if (t.includes('战斗胜利')) break;
    if (t.includes('战斗失败')) break;
  }
  t = await getT(page); expect(t).toContain('战斗胜利');
  expect(await noE(page)).toBeTruthy();
  // 战斗结束后，用 leave 回到大地图，再重新进入场景搜索物品
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  // 重新进入闫基居，搜索获得物品（两页刀法、药材、天王保命丹）
  expect(await gotoScene(page, '閰基居')).toBeGreaterThan(0);
  await cmd(page, 'choose 1'); await page.waitForTimeout(2000);  // 两页刀法
  await cmd(page, 'choose 2'); await page.waitForTimeout(2000);  // 药材
  await cmd(page, 'choose 3'); await page.waitForTimeout(2000);  // 天王保命丹
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 3)).toBe(true);
  console.log('  ✓ 闫基战斗');

  // Step 5: 铁掌山 — 大燕族谱 + 铁掌拳谱
  expect(await loadTestState(page, 3)).toBe(true);
  await cmd(page, 'choose 1'); await page.waitForTimeout(500);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await gotoScene(page, '鐵掌山')).toBeGreaterThan(0);
  // Entity 3=oldevent_453 → 大燕皇帝世系图表
  await cmd(page, 'look'); await page.waitForTimeout(1000);
  await cmd(page, 'choose 3'); await page.waitForTimeout(3000);
  // Entity 4=oldevent_454 → 铁掌拳谱
  await cmd(page, 'choose 4'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(1000);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 4)).toBe(true);
  console.log('  ✓ 铁掌山(大燕族谱+铁掌拳谱)');

  // Step 6: 高升客栈 → 段誉加入
  expect(await loadTestState(page, 4)).toBe(true);
  await cmd(page, 'choose 1'); await page.waitForTimeout(500);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await gotoScene(page, '高昇客棧')).toBeGreaterThan(0);
  await cmd(page, 'choose 5'); await page.waitForTimeout(3000);  // 段誉(第5NPC)
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);  // 对话
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 是
  t = await getT(page); expect(t).toContain('段誉');
  await cmd(page, 'choose 0'); await page.waitForTimeout(1000);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 5)).toBe(true);
  console.log('  ✓ 段誉加入');

  // Step 7: 无量山洞 — 段誉教凌波微步
  expect(await loadTestState(page, 5)).toBe(true);
  expect(await gotoScene(page, '無量山洞')).toBeGreaterThan(0);
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 段誉NPC
  await cmd(page, 'choose 1'); await page.waitForTimeout(4000);  // 对话→凌波微步
  t = await getT(page); expect(t).toContain('段誉');
  await cmd(page, 'choose 0'); await page.waitForTimeout(1000);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 6)).toBe(true);
  console.log('  ✓ 无量山洞');

  expect(await noE(page)).toBeTruthy();
  flushSaveCache('bridge-p1.json');
  console.log('  ✓ P1 完成');
});