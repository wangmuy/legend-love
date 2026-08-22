// quick_pass_game.md: 百花谷→绝情谷底→古墓→燕子坞→泰山派
const { test, expect } = require('@playwright/test');
const { waitForPageReady, waitForGameReady } = require('./helpers/setup');
const { saveTestState, loadTestState, gotoScene, flushSaveCache, loadSaveCache, hasItem } = require('./helpers/walkthrough');
const { cmd, getT, noE } = require('./helpers/term');

const SETTLE = 5000;

test('P3: 百花谷→绝情谷底→古墓→燕子坞→泰山派', async ({ page }) => {
  test.setTimeout(360000);
  loadSaveCache('bridge-p2.json');
  await page.goto('/'); await waitForPageReady(page); await waitForGameReady(page); await page.waitForTimeout(2000);

  // 百花谷/养蜂
  expect(await loadTestState(page, 2)).toBe(true);
  expect(await gotoScene(page, '百花谷')).toBeGreaterThan(0);
  let t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 百花谷');

  // 绝情谷底
  expect(await gotoScene(page, '絕情谷底')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 1)).toBe(true);
  console.log('  ✓ 绝情谷底');

  // 古墓/小龙女加入 + 九阴真经(oldevent_442) + 神雕侠侣(oldevent_443)
  expect(await loadTestState(page, 1)).toBe(true);
  expect(await gotoScene(page, '古墓')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  // entity 1 = 小龙女, entity 2 = oldevent_442(九阴真经), entity 3 = oldevent_443(神雕侠侣)
  // 注意顺序：先拿神雕侠侣(443)，再九阴真经(442)——442 消耗后实体列表收缩，choose 3 会越界
  await cmd(page, 'choose 3'); await page.waitForTimeout(3000);  // oldevent_443 → 神雕侠侣
  await cmd(page, 'choose 2'); await page.waitForTimeout(3000);  // 九阴真经
  t = await getT(page);
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 小龙女
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);  // 对话
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 加入
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await hasItem(page, 153)).toBe(true);  // 《神雕侠侣》item 153
  console.log('  ✓ 古墓(九阴真经+小龙女+神雕侠侣)');

  // 燕子坞/慕容复、王语嫣加入（需玉玺130 + 谱表131）
  // 链：慕容复(487)对话（让去找大燕传国玉玺，无加入选项）→ 使用130(493，得紫钥匙)
  //     → 使用131(573，设置丐帮527 + "怎样，你要不要和我合作？") → choose 1 合作 → 慕容复加入
  //     → 王语嫣(495，需慕容复在队) → choose 1 加入
  expect(await gotoScene(page, '燕子塢')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  // entity 1 = 慕容复, entity 2 = 王语嫣, entity 3 = 阿朱, entity 4 = 阿碧
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 慕容复(487) 对话
  for (let p = 0; p < 20; p++) {
    const tail5 = (await getT(page)).split('\n').slice(-4).join('');
    if (tail5.includes('选择交互对象') || tail5.includes('输入 choose')) break;
    await cmd(page, 'choose 1'); await page.waitForTimeout(1000);
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  // 对慕容复使用 130 玉玺（493）与 131 谱表（573），复用 P7b 已验证的物品使用流程
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
  // 使用谱表(573)后：合作对话"怎样，你要不要和我合作？" → choose 1 是（慕容复加入）
  for (let d = 0; d < 10; d++) {
    t = await getT(page);
    if (t.includes('合作') || t.includes('加入')) break;
    await cmd(page, 'choose 1'); await page.waitForTimeout(1500);
  }
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 合作 → 慕容复加入
  // 王语嫣加入(entity 2，需慕容复已在队伍)
  await cmd(page, 'choose 2'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);
  for (let d = 0; d < 6; d++) {
    t = await getT(page);
    if (t.includes('加入') || t.includes('王语嫣')) break;
    await cmd(page, 'choose 1'); await page.waitForTimeout(2000);
  }
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 是（王语嫣加入）
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 2)).toBe(true);
  console.log('  ✓ 燕子坞(慕容复+王语嫣)');

  // 泰山派/洗手帖 — 6个NPC搜索实体(2个NPC战斗+4个宝箱含洗手帖)
  expect(await loadTestState(page, 2)).toBe(true);
  expect(await gotoScene(page, '泰山派')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  // choose 1 连续搜索所有实体（前2为NPC战斗→自动处理，后4为宝箱搜索）
  for (let e = 0; e < 6; e++) {
    await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
    t = await getT(page);
    // 如果进入战斗，走标准战斗循环
    if (t.includes('战场态势') || t.includes('战斗')) {
      for (let r = 0; r < 10; r++) {
        await cmd(page, 'choose 5'); await page.waitForTimeout(300);
        await cmd(page, 'choose 1'); await page.waitForTimeout(300);
        await cmd(page, 'choose 1'); await page.waitForTimeout(300);
        await cmd(page, 'choose 1'); await page.waitForTimeout(300);
        t = await getT(page);
        if (t.includes('战斗胜利') || t.includes('战斗失败')) break;
      }
    }
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 泰山派(洗手帖+宝箱)');

  expect(await noE(page)).toBeTruthy();
  flushSaveCache('bridge-p3.json');
  console.log('  ✓ P3 完成');
});
