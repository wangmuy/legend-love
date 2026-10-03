// tests/fl_issue2.spec.js
// 回归：Issue1 开始菜单“加载游戏”必须真实读档并渲染；Issue2 通关“恭喜通关”横幅只能出现一次。
const { test, expect } = require('@playwright/test');
const { waitForPageReady, waitForGameReady } = require('./helpers/setup');
const { cmd, getT } = require('./helpers/term');

const SETTLE = 1300;

test('IE21: 开始菜单 loadGame 真实读档渲染', async ({ page }) => {
  test.setTimeout(180000);
  await page.goto('/'); await waitForPageReady(page); await waitForGameReady(page); await page.waitForTimeout(2500);
  // 建档
  await cmd(page, 'choose 1'); await page.waitForTimeout(4200);
  await cmd(page, 'choose 1'); await page.waitForTimeout(SETTLE);
  await cmd(page, 'leave'); await page.waitForTimeout(SETTLE);
  await cmd(page, 'save 1'); await page.waitForTimeout(2200);
  // 确保 IndexedDB 写入已落盘（等待 put 事务提交，避免 reload 竞态）。
  // 生产反馈：保存后若立即 reload，IDB 提交有微小延迟，故这里轮询直到记录可见，
  // 保证“真实存档后 reload→载入”路径可被确定性地验证（与真实用户流程一致）。
  const durable = await page.evaluate(() => new Promise(resolve => {
    const t0 = Date.now();
    const poll = () => {
      const req = indexedDB.open('jyLegendWebMud', 1);
      req.onsuccess = () => {
        const db = req.result;
        const tx = db.transaction('saves', 'readonly');
        const st = tx.objectStore('saves');
        const r = st.get('save_1');
        r.onsuccess = () => { if (!!r.result && !!r.result.value) resolve(true);
          else if (Date.now() - t0 > 12000) resolve(false); else setTimeout(poll, 300); };
        r.onerror = () => setTimeout(poll, 300);
      };
      req.onerror = () => setTimeout(poll, 300);
    };
    setTimeout(poll, 300);
  }));
  console.log('  durable(save_1)=', durable);
  expect(durable).toBe(true);
  // 刷新回到开始菜单，选“尽快进度”
  await page.reload(); await waitForPageReady(page); await waitForGameReady(page); await page.waitForTimeout(1500);
  await cmd(page, 'choose 2');
  // 轮询终端直到出现“读取存档成功”或“没有存档”（加载重试最多耗时数秒，避免固定等待竞态）
  await page.waitForFunction(() => {
    const term = window.__xterm; if (!term) return false;
    for (let y = 0; y < term.buffer.active.length; y++) {
      const s = term.buffer.active.getLine(y)?.translateToString(true) || '';
      if (s.includes('读取存档成功') || s.includes('没有存档')) return true;
    }
    return false;
  }, { timeout: 20000 });
  await page.waitForTimeout(1200);
  const t = await getT(page);
  console.log('TERM(tail):', JSON.stringify(t.split('\n').slice(-14).join(' | ')));
  const dump = await page.evaluate(async () => {
    const code = 'local J=rawget(_G,"JY"); return "status="..tostring(J and J.Status).." scene="..tostring((J and J.Scene) or (J and J.SubScene))';
    const r = await window.__luaEval(code);
    return r && r.result;
  });
  console.log('DUMP:', JSON.stringify(dump));
  // 必须真实读档并渲染（读取成功 + 已进入地图，而非“没有存档”）；状态必须是游戏世界(2=MMAP)
  expect(t).toContain('读取存档成功');
  expect(t).toContain('当前位置');
  expect(t).not.toContain('没有存档');
  expect(dump).toContain('status=2');
  console.log('  ✓ 开始菜单 loadGame 真实读档渲染');
});

test('IE2: 通关“恭喜通关”BANNER 只出现一次', async ({ page }) => {
  test.setTimeout(180000);
  await page.goto('/'); await waitForPageReady(page); await waitForGameReady(page); await page.waitForTimeout(2500);
  await cmd(page, 'choose 1'); await page.waitForTimeout(4200);
  await cmd(page, 'choose 1'); await page.waitForTimeout(SETTLE);
  // 模拟真实终局顺序：
  //  1) finale 协程直接打印通关 BANNER（showFinalBanner #1）
  //  2) 事件结尾把 JY.Status 置为 GAME_END(7)
  //  3) 下一帧 状态机 sm:update → switchTo(GAME_END) → GAME_END.enter → EngineAPI.app.quit()（又打印一次）
  //  修复后 showFinalBanner 去重，整局只出现一次“恭喜通关”。
  const r = await page.evaluate(async () => {
    const ___ = async (code)=>{ const r=await window.__luaEval(code); return r && r.result; };
    await ___('local ea=rawget(_G,"EngineAPI").app; ea.showFinalBanner({"    ☆ 恭喜通关！游戏结束 ☆","    你已集齐十四天书，回到现实！"}); local JY=rawget(_G,"JY"); if JY then JY.Status=7 end; return "done"');
  });
  // 让后面的帧调用 processEventQueue → sm:update → GAME_END.enter → app.quit（被去重）
  await page.waitForTimeout(2500);
  const t = await getT(page);
  const count = t.split('\n').filter(l => l.includes('恭喜通关')).length;
  console.log('  count(恭喜通关)=', count);
  expect(count).toBe(1);
});