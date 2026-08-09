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

  // 燕子坞/慕容复、王语嫣加入
  expect(await gotoScene(page, '燕子塢')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  // entity 1 = 慕容复, entity 2 = 王语嫣, entity 3 = 阿朱, entity 4 = 阿碧
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 慕容复
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);  // 对话
  t = await getT(page);
  // 慕容复对话后选择"是"加入
  for (let d = 0; d < 6; d++) {
    await cmd(page, 'choose 1'); await page.waitForTimeout(2000);
    t = await getT(page);
    if (t.includes('加入') || t.includes('慕容复')) break;
  }
  // 王语嫣加入(entity 2)
  await cmd(page, 'choose 2'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);
  for (let d = 0; d < 6; d++) {
    await cmd(page, 'choose 1'); await page.waitForTimeout(2000);
    t = await getT(page);
    if (t.includes('加入') || t.includes('王语嫣')) break;
  }
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
