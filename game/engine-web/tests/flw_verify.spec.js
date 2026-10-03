// End-to-end verify of the two reported issues:
//  A) start-menu 载入 reads persisted save after a real reload (Issue 1)
//  B) game-over no longer loops printing forever (Issue 2)
const { test, expect } = require('@playwright/test');
const { waitForPageReady, waitForGameReady } = require('./helpers/setup');
const { getT, cmd } = require('./helpers/term');

const LE = (page, code) => page.evaluate((c) => window.__luaEval(c), code);

const countOcc = (t, s) => (t.split(s).length - 1);

test('A1 start-load reads persisted save after real reload', async ({ page }) => {
  test.setTimeout(120000);
  await page.goto('/'); await waitForPageReady(page); await waitForGameReady(page); await page.waitForTimeout(1500);

  // persist a real save into slot 1 via the real bridge (-> IndexedDB)
  const w = await LE(page, `rawset(_G,"JY",rawget(_G,"JY") or {}); local JY=rawget(_G,"JY"); JY.Status=2; JY.SubScene=25; JY["主角"]=JY["主角"] or 0; local sg=rawget(_G,"saveGameState"); return "saved="..tostring(sg and sg(1))`);
  console.log('write save:', w && w.result);
  // allow the async IndexedDB write to flush before reload
  await page.waitForTimeout(1200);

  // REAL reload (fresh boot) - replicates user restarting game
  await page.reload();
  await waitForPageReady(page);
  await waitForGameReady(page);
  await page.waitForTimeout(2000);

  // diagnose: is the persisted save visible to JSBridge after reload?
  const det = await LE(page, `local lb=rawget(_G,"JSBridge"); local keys={}; if lb and lb.listSaves then keys=lb.listSaves() end; local j=lb and lb.load and lb.load("save_1"); return "keys="..tostring(type(keys)=="table" and #keys or -1).." has1="..tostring(j~=nil and j~="").." len="..tostring(type(j)=="string" and #j or 0)`);
  console.log('post-reload JSBridge:', det && det.result);

  const pre = await LE(page, `local J=rawget(_G,"JY"); return "status="..tostring(J and J.Status).." sub="..tostring(J and J.SubScene)`);
  console.log('after reload (start status):', pre && pre.result);

  // start screen choose 2 = 载入进度
  const before = await getT(page);
  await cmd(page, 'choose 2');
  await page.waitForTimeout(3500);

  const after = await getT(page);
  const st = await LE(page, `local J=rawget(_G,"JY"); return "status="..tostring(J and J.Status).." sub="..tostring(J and J.SubScene).." notif="..tostring(rawget(_G,"__gameOverNotified"))`);
  console.log('after start-load choose2:', st && st.result);

  const noSave = countOcc(after, '没有存档') + countOcc(after, '没有存檔');
  console.log('no-save messages on screen:', noSave);
  expect(noSave, 'should NOT show 没有存档').toBe(0);
  // start-menu load into a save restores Status to 2 (playing mmap)
  expect((st && st.result) || '', 'JY.Status should be 2 after load').toContain('status=2');
});

test('A2 game-over does not loop printing', async ({ page }) => {
  test.setTimeout(90000);
  await page.goto('/'); await waitForPageReady(page); await waitForGameReady(page); await page.waitForTimeout(1500);

  // begin new game so we are in a real state, then force game over via EngineAPI.app.quit
  await cmd(page, 'choose 1'); await page.waitForTimeout(1200);
  await LE(page, `local a=rawget(_G,"EngineAPI"); if a and a.app and a.app.quit then a.app.quit() end return "over"`);
  await page.waitForTimeout(400);

  const t1 = await getT(page);
  const c1 = countOcc(t1, '游戏已结束。输入 quit 退出');
  console.log('A2 first count (应=1):', c1);

  // let the 16ms game loop run for ~2s of idle; count must NOT grow
  await page.waitForTimeout(2500);
  const t2 = await getT(page);
  const c2 = countOcc(t2, '游戏已结束。输入 quit 退出');
  console.log('A2 after idle 2.5s count (应仍=1):', c2);
  expect(c2, 'game-over notice prints only ONCE, not looping').toBeLessThanOrEqual(c1);
  expect(c2, 'should print exactly once').toBe(1);
});