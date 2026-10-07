// Issue3 E2E: fresh 孔八拉 (no prior dialogue, tile1 field3 unset), use 神杖 via real menu -> green key
const { test } = require('@playwright/test');
const { waitForPageReady, waitForGameReady } = require('./helpers/setup');
const { loadTestState, loadSaveCache } = require('./helpers/walkthrough');
const { getT, cmd } = require('./helpers/term');

test('issue3 menu-flash', async ({ page }) => {
  test.setTimeout(240000);
  loadSaveCache('bridge-p10.json');
  await page.goto('/'); await waitForPageReady(page); await waitForGameReady(page); await page.waitForTimeout(2000);
  await loadTestState(page, 1); await page.waitForTimeout(1200);

  async function dump(tag){
    const t = await getT(page);
    console.log('=== ' + tag + ' ===');
    for (const l of t.split('\n').filter(Boolean).slice(-12)) console.log('   ' + l.trimEnd().substring(0,76));
    return t;
  }

  // Force fresh: clear scene76 D for tile1 (孔八拉), so field3 unset. Keep 神杖 bag.
  await page.evaluate(async () => {
    const c=`
local J=rawget(_G,"JY")
J.SubScene=76; J.Status=4
J.D=J.D or {}; J.D["76"]=J.D["76"] or {}
-- force field3 unset on 孔八拉 tile1
local t1=J.D["76"][1]
if t1 and type(t1)=='table' then
  -- dict/array agnostic: set field3 to -1
  t1[3]=-1; t1["3"]=-1
end
-- ensure 神杖 in slot 4
local old=J.Base["物品4"] or 0
J.Base["物品4"]=143; J.Base["物品数量4"]=1
local h=rawget(_G,"SmapHandlers"); if h and h.look then h.look({}) end
return "old4="..tostring(old)`;
    const r=await window.__luaEval(c); return r&&r.ok?r.result:'err';
  });
  await page.waitForTimeout(400);
  await dump('scene76 ready');

  await cmd(page,'menu'); await page.waitForTimeout(400);
  await dump('menu');
  await cmd(page,'choose 4'); await page.waitForTimeout(400); // 物品
  await dump('物品');
  await cmd(page,'choose 1'); await page.waitForTimeout(400); // 使用
  await dump('使用列表');
  const zi = await page.evaluate(async ()=>{const t=window.__xterm;for(let y=t.buffer.active.length-1;y>=0;y--){const s=t.buffer.active.getLine(y)?.translateToString(true)||'';const m=s.match(/^(\d+)\.\s*神杖/);if(m)return m[1];}return '-1';});
  console.log('神杖在列表索引=',zi);
  await cmd(page,'choose '+zi); await page.waitForTimeout(500);
  await dump('选择目标');
  const ti = await page.evaluate(async ()=>{const t=window.__xterm;for(let i=t.buffer.active.length-1;i>=0;i--){const s=t.buffer.active.getLine(i)?.translateToString(true)||'';const m=s.match(/^(\d+)\.\s*孔八拉/);if(m)return m[1];}return '-1';});
  console.log('孔八拉目标索引=',ti);
  await cmd(page,'choose '+ti); await page.waitForTimeout(3000);
  await dump('after-use');
  const st=await page.evaluate(async ()=>{
    const c='local J=rawget(_G,"JY"); local gk=0; local has143=false; for i=0,40 do local id=J.Base["物品"..i]; if id==143 then has143=true end; if id==164 then gk=gk+(J.Base["物品数量"..i] or 1) end end; return "has143="..tostring(has143).." gk164="..tostring(gk)';
    const r=await window.__luaEval(c); return r&&r.ok?r.result:'err';});
  console.log('RESULT:',st);
});