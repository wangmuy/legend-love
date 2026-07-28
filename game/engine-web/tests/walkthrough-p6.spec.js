// quick_pass_game.md: 神龙教→破庙→成昆→沙漠→北丑→灵蛇→渤泥岛→侠客岛
const { test, expect } = require('@playwright/test');
const { waitForPageReady, waitForGameReady } = require('./helpers/setup');
const { saveTestState, loadTestState, gotoScene, flushSaveCache, loadSaveCache } = require('./helpers/walkthrough');
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
  test.setTimeout(600000);
  loadSaveCache('bridge-p5.json');
  await page.goto('/'); await waitForPageReady(page); await waitForGameReady(page); await page.waitForTimeout(2000);
  expect(await loadTestState(page, 3)).toBe(true);

  // 神龙教《鹿鼎记》— 洪教主对话(oldevent_609)
  expect(await gotoScene(page, '神龍教')).toBeGreaterThan(0);
  let t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  // entity 1=洪教主, entity 2-3=守卫
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);  // 对话
  t = await getT(page);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
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
  // 先 list 并前往冰火岛使用铁焰令触发谢逊对话(设定成昆居事件)
  // 当前 P5 光明顶已获得铁焰令，这里先去冰火岛触发谢逊
  let iceIdx = await findSceneIdx(page, '冰火島');
  if (iceIdx > 0) {
    await cmd(page, 'choose ' + iceIdx); await page.waitForTimeout(SETTLE);
    let t2 = await getT(page);
    if (t2.includes('你来到了')) {
      // 使用 明教铁焰令 on 谢逊
      await cmd(page, 'menu'); await page.waitForTimeout(2000);
      await cmd(page, 'choose 4'); await page.waitForTimeout(2000);
      await cmd(page, 'choose 1'); await page.waitForTimeout(2000);
      let itemIdx = await page.evaluate(() => {
        const term = window.__xterm; if (!term) return -1;
        for (let y = term.buffer.active.length - 1; y >= 0; y--) {
          const t = term.buffer.active.getLine(y)?.translateToString(true) || '';
          const m = t.match(/^(\d+)\.\s*.*铁焰令.*$/);
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
            if (m && m[2].includes('谢逊')) return parseInt(m[1], 10);
          }
          return -1;
        });
        if (npcIdx > 0) { await cmd(page, 'choose ' + npcIdx); await page.waitForTimeout(3000); }
      }
    }
    await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  }
  console.log('  ✓ 冰火岛(铁焰令→谢逊)');

  // 成昆居 — 成崑战斗
  expect(await gotoScene(page, '成崑居')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  // 触发成崑战斗(oldevent_91)
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  t = await getT(page);
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
  // 搜索其他物品
  await cmd(page, 'choose 1'); await page.waitForTimeout(2000);
  await cmd(page, 'choose 2'); await page.waitForTimeout(2000);
  await cmd(page, 'choose 3'); await page.waitForTimeout(2000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 成昆居(成崑战斗+人头)');

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

  // 灵蛇岛/紫衫龙王
  expect(await loadTestState(page, 2)).toBe(true);
  expect(await gotoScene(page, '靈蛇島')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 灵蛇岛');

  // 渤泥岛/《碧血剑》— 袁承志对话(oldevent_635)
  expect(await gotoScene(page, '浡泥島')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);  // 对话
  t = await getT(page);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 渤泥岛(袁承志)');

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

  // 冰火岛三刷 — 使用一颗头颅换屠龙刀(需已杀成崑得人头)
  let ice2Idx = await findSceneIdx(page, '冰火島');
  if (ice2Idx > 0) {
    await cmd(page, 'choose ' + ice2Idx); await page.waitForTimeout(SETTLE);
    let t2 = await getT(page);
    if (t2.includes('你来到了')) {
      await cmd(page, 'menu'); await page.waitForTimeout(2000);
      await cmd(page, 'choose 4'); await page.waitForTimeout(2000);
      await cmd(page, 'choose 1'); await page.waitForTimeout(2000);
      let headIdx = await page.evaluate(() => {
        const term = window.__xterm; if (!term) return -1;
        for (let y = term.buffer.active.length - 1; y >= 0; y--) {
          const t = term.buffer.active.getLine(y)?.translateToString(true) || '';
          const m = t.match(/^(\d+)\.\s*.*一颗头颅.*$/);
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
            if (m && m[2].includes('谢逊')) return parseInt(m[1], 10);
          }
          return -1;
        });
        if (npcIdx2 > 0) { await cmd(page, 'choose ' + npcIdx2); await page.waitForTimeout(3000); }
      }
    }
    await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  }
  console.log('  ✓ 冰火岛(人头→屠龙刀)');

  expect(await noE(page)).toBeTruthy();
  flushSaveCache('bridge-p6.json');
  console.log('  ✓ P6 完成');
});
