// tests/walkthrough-p1.spec.js
// 按 quick_pass_game.md 攻略：南贤→田伯光加入→闫基战斗→铁掌帮→段誉加入→无量山洞
// 纯用户命令，每步都模拟真实玩家操作
const { test, expect } = require('@playwright/test');
const { waitForPageReady } = require('./helpers/setup');
const { saveTestState, loadTestState, flushSaveCache } = require('./helpers/walkthrough');
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
  test.setTimeout(300000);
  await page.goto('/'); await waitForPageReady(page); await page.waitForTimeout(3000);

  // Step 1: 开局 — choose 1(重新开始) → choose 1(确认属性) → leave → 存档
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  let t = await getT(page); expect(t).toContain('生命');
  await cmd(page, 'choose 1'); await page.waitForTimeout(SETTLE);
  t = await getT(page); expect(t).toContain('新游戏开始');
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 11)).toBe(true);
  console.log('  ✓ 开局');

  // Step 2: 南贤对话 — Entity 1=搜索(柜子), Entity 2=南贤
  expect(await loadTestState(page, 11)).toBe(true);
  expect(await gotoScene(page, '南賢居')).toBeGreaterThan(0);
  await cmd(page, 'choose 2'); await page.waitForTimeout(3000);  // 南贤(entity 2)
  await cmd(page, 'choose 1'); await page.waitForTimeout(4000);  // 对话
  t = await getT(page); expect(t).toContain('南贤');
  await cmd(page, 'choose 0'); await page.waitForTimeout(1000);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 11)).toBe(true);
  console.log('  ✓ 南贤对话');

  // Step 3: 田伯光加入 — Entity 1=搜索, Entity 2=田伯光NPC → 对话 → 招人
  expect(await loadTestState(page, 11)).toBe(true);
  expect(await gotoScene(page, '田伯光居')).toBeGreaterThan(0);
  await cmd(page, 'choose 2'); await page.waitForTimeout(3000);  // 选田伯光(entity 2)
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);  // 选"对话"
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 选"是"（加入）
  t = await getT(page); expect(t).toContain('田伯光');
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 12)).toBe(true);
  console.log('  ✓ 田伯光加入');

  // Step 4: 闫基战斗 — choose 4(瓦片事件) → 战斗 → 胜利
  expect(await loadTestState(page, 12)).toBe(true);
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
  // 战斗结束后，用 look 确认状态，然后 leave 回到大地图
  await cmd(page, 'look'); await page.waitForTimeout(1000);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  expect(await saveTestState(page, 13)).toBe(true);
  console.log('  ✓ 闫基战斗');

  // Step 5: 铁掌山
  expect(await loadTestState(page, 13)).toBe(true);
  await cmd(page, 'choose 1'); await page.waitForTimeout(500);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await gotoScene(page, '鐵掌山')).toBeGreaterThan(0);
  await cmd(page, 'choose 0'); await page.waitForTimeout(1000);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 14)).toBe(true);
  console.log('  ✓ 铁掌山');

  // Step 6: 高升客栈 → 段誉加入
  expect(await loadTestState(page, 14)).toBe(true);
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
  expect(await saveTestState(page, 15)).toBe(true);
  console.log('  ✓ 段誉加入');

  // Step 7: 无量山洞 — 段誉教凌波微步
  expect(await loadTestState(page, 15)).toBe(true);
  expect(await gotoScene(page, '無量山洞')).toBeGreaterThan(0);
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 段誉NPC
  await cmd(page, 'choose 1'); await page.waitForTimeout(4000);  // 对话→凌波微步
  t = await getT(page); expect(t).toContain('段誉');
  await cmd(page, 'choose 0'); await page.waitForTimeout(1000);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 16)).toBe(true);
  console.log('  ✓ 无量山洞');

  expect(await noE(page)).toBeTruthy();
  flushSaveCache('bridge-p1.json');
  console.log('  ✓ P1 完成');
});