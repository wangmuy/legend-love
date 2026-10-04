// Issue1: start menu 载入进度 loads slot1 (not "没有存档")
const { test } = require('@playwright/test');
const { waitForPageReady, waitForGameReady } = require('./helpers/setup');
const { loadTestState, loadSaveCache } = require('./helpers/walkthrough');
const { getT, cmd } = require('./helpers/term');

test('issue1 start load', async ({ page }) => {
  test.setTimeout(120000);
  loadSaveCache('bridge-p10.json');
  await page.goto('/'); await waitForPageReady(page); await waitForGameReady(page); await page.waitForTimeout(2000);
  let t = await getT(page);
  console.log('=== initial screen ===');
  for (const l of t.split('\n').filter(Boolean).slice(-6)) console.log('   ' + l.trimEnd().substring(0,70));

  // seed slot1 save into current page
  await loadTestState(page, 1); await page.waitForTimeout(600);
  const stBefore = await page.evaluate(async ()=>{const r=await window.__luaEval('return tostring(rawget(_G,"__saveCache") and rawget(_G,"__saveCache")["save_1"] ~= nil)');return r&&r.ok?r.result:'err';});
  console.log('save_1 present:', stBefore);

  // choose 2 = 载入进度 at start menu, now presents a selectable slot menu; save_1 seeded so slot1 is offered
  await cmd(page,'choose 2'); await page.waitForTimeout(2500);
  t = await getT(page);
  console.log('=== after choose 2 (slot menu) ===');
  for (const l of t.split('\n').filter(Boolean).slice(-8)) console.log('   ' + l.trimEnd().substring(0,70));
  const hasSel = t.includes('读取槽位1');
  console.log('submenu lists selectable 读取槽位1:', hasSel);
  // 选择槽位1
  if (hasSel) { await cmd(page,'choose 1'); await page.waitForTimeout(2500); }
  t = await getT(page);
  console.log('=== after select slot1 ===');
  for (const l of t.split('\n').filter(Boolean).slice(-8)) console.log('   ' + l.trimEnd().substring(0,70));
  const res = await page.evaluate(async ()=>{
    const c='local J=rawget(_G,"JY"); return "status="..tostring(J and J.Status).." sub="..tostring(J and J.SubScene)';
    const r=await window.__luaEval(c); return r&&r.ok?r.result:'err';
  });
  console.log('AFTER LOAD State:', res);
});