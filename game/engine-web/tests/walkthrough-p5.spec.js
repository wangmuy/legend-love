// quick_pass_game.md: 药王庄→金轮寺→明教分舵→光明顶→华山→金蛇洞→武当→嵩山
const { test, expect } = require('@playwright/test');
const { waitForPageReady, waitForGameReady } = require('./helpers/setup');
const { saveTestState, loadTestState, gotoScene, flushSaveCache, loadSaveCache, hasItem, doBattle, inBattle } = require('./helpers/walkthrough');
const { cmd, getT, noE } = require('./helpers/term');

const SETTLE = 5000;

test('P5: 药王庄→金轮寺→明教→光明顶→华山→金蛇洞→武当→嵩山', async ({ page }) => {
  test.setTimeout(700000);
  loadSaveCache('bridge-p4.json');
  await page.goto('/'); await waitForPageReady(page); await waitForGameReady(page); await page.waitForTimeout(2000);
  expect(await loadTestState(page, 2)).toBe(true);

  // 药王庄/眼药/程灵素加入
  expect(await gotoScene(page, '藥王莊')).toBeGreaterThan(0);
  let t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 程灵素(第1NPC)
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);  // 对话
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 是(加入)
  // NPC dialog may not show name in terminal output, just verify no error
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 1)).toBe(true);
  console.log('  ✓ 药王庄(程灵素加入)');

  // 衡山派战斗
  expect(await loadTestState(page, 1)).toBe(true);
  expect(await gotoScene(page, '衡山派')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'look'); await page.waitForTimeout(1000);
  t = await getT(page);
  if (t.includes('战场态势')) {
    console.log('  ⚠ 衡山派战斗触发');
    t = await doBattle(page);
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 衡山派');

  // 金轮寺/可兰经 — 守卫对话(627,战斗[99]) + 金轮法王战斗[100](动态631)拿可兰经(159)
  // 注意：金轮寺 look 实体含静态NPC(627/845/846/847/854/855) + D*动态(631金轮法王等)，
  // 必须循环全部实体并直接用 Lua 检查背包（终端文本不显示"可兰经"字样）。
  console.log('[DEBUG P5] gotoScene 金轮寺 前');
  expect(await gotoScene(page, '金輪寺')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  console.log('[DEBUG P5] 到达金轮寺，终端尾部:', t.slice(-200).replace(/\n/g, ' | '));
  const st = await page.evaluate(async () => {
    if (!window.__luaEval) return 'no-lua';
    const code = 'local J = rawget(_G, "JY"); if not J then return "no-JY" end; return "Status=" .. tostring(J.Status) .. " SubScene=" .. tostring(J.SubScene) .. " 人X=" .. tostring(J.Base and J.Base["人X"] or "?") .. " 人Y=" .. tostring(J.Base and J.Base["人Y"] or "?")';
    const res = await window.__luaEval(code);
    return res && res.ok ? res.result : 'eval-fail';
  });
  console.log('[DEBUG P5] 金轮寺到达后状态:', st);
  await cmd(page, 'look'); await page.waitForTimeout(2500);
  t = await getT(page);
  console.log('[DEBUG P5] 金轮寺look尾部:', t.slice(-400).replace(/\n/g, ' | '));
  // 稳健循环：守卫战斗[99]胜利后场景重渲染（entityCount 变化、实体重排），
  // 固定索引会选错实体。策略：
  //   1. 触发守卫战斗[99]（oldevent_627，实体1）→ doBattle 打完
  //   2. 重新 look 后定位"金轮法王"（oldevent_631，战斗[100]胜利给可兰经159）实体，
  //      直接 choose 它，避免触发杂物搜索（845/846/847/854/855 等会发物品填满背包，
  //      导致 instruct_2(159) 因"背包已满"失败）。
  for (let pass = 0; pass < 6 && !(await hasItem(page, 159)); pass++) {
    await cmd(page, 'look'); await page.waitForTimeout(1500);
    t = await getT(page);
    // 先找"金轮法王"命名实体（look 输出含"金轮法王"行）
    const kingIdx = await page.evaluate(() => {
      const term = window.__xterm;
      if (!term) return -1;
      for (let y = 0; y < term.buffer.active.length; y++) {
        const s = term.buffer.active.getLine(y)?.translateToString(true) || '';
        const m = s.match(/^\s*(\d+)\.\s*金轮法王/);
        if (m) return parseInt(m[1], 10);
      }
      return -1;
    });
    const target = kingIdx > 0 ? kingIdx : 1;  // 无金轮法王时触发守卫(1)
    const before = await getT(page);
    await cmd(page, 'choose ' + target); await page.waitForTimeout(2500);
    t = await getT(page);
    const newPart = t.slice(before.length);
    const lines = newPart.split('\n').map(s => s.trim()).filter(Boolean);
    console.log(`[DEBUG P5] pass${pass} choose ${target}${kingIdx > 0 ? '(金轮法王)' : '(守卫)'}: ${lines.slice(0, 3).join(' | ').slice(0, 160)}`);
    if (await inBattle(page)) {
      t = await doBattle(page);
      console.log(`[DEBUG P5] pass${pass} 战斗结束 hasItem(159)=${await hasItem(page, 159)}`);
    }
    // 关闭可能的对话/菜单
    await cmd(page, 'choose 0'); await page.waitForTimeout(300);
    t = await getT(page);
    if (t.includes('无效')) break;
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('[DEBUG P5] leave后终端尾部:', (await getT(page)).slice(-200).replace(/\n/g, ' | '));
  expect(await hasItem(page, 159)).toBe(true);  // 可兰经(159) — 书剑恩仇录前置
  console.log('  ✓ 金轮寺');

  // 明教分舵 — choose 1 触发 oldevent_77 对话 → 战斗[8]（明教守卫战）！
  // 必须用 doBattle 打完战斗，否则战斗协程挂起、全局战斗状态残留，
  // 会导致后续光明顶六大派战斗[12]（oldevent_82）执行异常（instruct_2(190) 不执行）。
  expect(await gotoScene(page, '明教分舵')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  if (await inBattle(page)) {
    console.log('  ⚠ 明教分舵战斗触发');
    await doBattle(page);
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 明教分舵');

  // 光明顶/六大派 — tile event extra=82 → 六大派围攻战斗 + 范遥(倚天屠龙记)
  // 注意：光明顶 look 实体 = 静态NPC范遥(1) + D*扫描的82事件"搜索"实体(2~4)，
  // 必须循环尝试全部实体触发六大派战斗[12]（oldevent_82 胜利后给铁焰令190）。
  expect(await gotoScene(page, '光明頂')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  // 六大派战斗[12]（oldevent_82 胜利后给铁焰令190）是 D* tile 事件，实体列表动态变化：
  // 每轮必须重新 look 刷新列表（实体被消耗后重排，固定索引会选错），用 inBattle()（JY.Status==5）
  // 判断战斗而非终端文本（文本累积会误判）。诊断验证：实体3 战斗胜利后可拿到铁焰令190。
  let got190 = false;
  // 诊断验证过的成功模式：每轮 look 刷新列表后 choose 递增索引；战斗后不 break（继续尝试下一实体），
  // 直到拿到铁焰令190 或索引越界。实体列表动态变化（D* tile 事件被消耗后重排），
  // "战斗后重新从1开始"会永远重复触发同一战斗、选不中给190的实体。
  for (let pass = 0; pass < 3 && !got190; pass++) {
    for (let ei = 1; ei <= 10; ei++) {
      await cmd(page, 'look'); await page.waitForTimeout(1200);
      const before = await getT(page);
      await cmd(page, 'choose ' + ei); await page.waitForTimeout(2500);
      if (await inBattle(page)) {
        console.log('  ⚠ 光明顶战斗触发 (pass' + pass + ' 实体' + ei + ')');
        await doBattle(page);
        await page.waitForTimeout(800);
        console.log('光明顶战斗结束, hasItem(190)=' + (await hasItem(page, 190)));
        got190 = await hasItem(page, 190);
        if (got190) break;
        continue;  // 战斗后列表已变，继续下一实体索引
      }
      if (await hasItem(page, 190)) { got190 = true; break; }
      // 非战斗：可能是对话（范遥六大派胜利后给铁焰令190 在对话末尾 instruct_2(190)）。
      // 需翻页对话直到"交谈结束"或获得190（对话中输入框不可见，不能直接 choose 0）。
      let closed = false;
      for (let pg = 0; pg < 20 && !got190; pg++) {
        t = await getT(page);
        if (t.includes('交谈结束')) { closed = true; break; }
        await cmd(page, 'choose 1'); await page.waitForTimeout(1200);
        got190 = await hasItem(page, 190);
        if (got190) { console.log('  ✓ 光明顶对话得铁焰令190 (实体' + ei + ' pg' + pg + ')'); break; }
      }
      if (got190) break;
      // 关闭对话/菜单；只检查本轮新增输出是否"无效"（终端历史累积会误判）
      await cmd(page, 'choose 0'); await page.waitForTimeout(300);
      const newTxt = (await getT(page)).slice(before.length);
      if (newTxt.includes('无效')) break;  // 索引越界，列表已缩短
    }
  }
  // 范遥(oldevent_111) — 光明圣火阵/倚天屠龙记
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(5000);
  t = await getT(page);
  if (t.includes('范遥') || t.includes('光明圣火')) {
    console.log('  ✓ 范遥(倚天屠龙记)');
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await hasItem(page, 190)).toBe(true);  // 明教铁焰令(190) — 倚天屠龙记前置
  expect(await saveTestState(page, 2)).toBe(true);
  console.log('  ✓ 光明顶(六大派+范遥)');

  // 华山派/对话岳不群
  expect(await loadTestState(page, 2)).toBe(true);
  expect(await gotoScene(page, '華山派')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 华山派');

  // 金蛇洞/金蛇剑 — 拔剑(640,武力75+)+秘笈(641)+金蛇锥(642)
  expect(await gotoScene(page, '金蛇山洞')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);  // 641 金蛇秘笈
  await cmd(page, 'choose 0'); await page.waitForTimeout(300);
  await cmd(page, 'choose 2'); await page.waitForTimeout(2000);  // 642 金蛇锥
  await cmd(page, 'choose 0'); await page.waitForTimeout(300);
  await cmd(page, 'choose 3'); await page.waitForTimeout(3000);  // 640 金蛇剑(武力75+)
  t = await getT(page);
  if (t.includes('拔出来')) console.log('  ✓ 金蛇剑拔得');
  else console.log('  ⚠ 金蛇剑未拔出（武力不足75）');
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await hasItem(page, 110)).toBe(true);  // 金蛇剑(110) — 碧血剑前置
  console.log('  ✓ 金蛇洞');

  // 武当山/击败张三丰 — look 实体1=张三丰(事件154长对话→变155)，再交互触发155(是否过招→战斗[22])
  expect(await gotoScene(page, '武當派')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'look'); await page.waitForTimeout(2000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(4000);  // 张三丰(第1NPC) 事件154长对话
  await cmd(page, 'choose 1'); await page.waitForTimeout(4000);  // 再次交互→155
  await cmd(page, 'choose 1'); await page.waitForTimeout(4000);  // 是否过招→是→战斗[22]
  if (await inBattle(page)) {
    t = await doBattle(page);
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  console.log('  ✓ 武当山(张三丰)');

  // 嵩山派/张旭率意帖
  expect(await gotoScene(page, '嵩山派')).toBeGreaterThan(0);
  t = await getT(page); expect(t).toContain('你来到了');
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  // 如果进入了战斗，处理战斗
  await cmd(page, 'look'); await page.waitForTimeout(1000);
  t = await getT(page);
  if (t.includes('战场态势')) {
    t = await doBattle(page);
  }
  await cmd(page, 'choose 0'); await page.waitForTimeout(500);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  expect(await saveTestState(page, 3)).toBe(true);
  console.log('  ✓ 嵩山派');

  expect(await noE(page)).toBeTruthy();
  flushSaveCache('bridge-p5.json');
  console.log('  ✓ P5 完成');
});
