// Issue4: real 圣堂 ending - select 时空机 NPC -> GAME + ending text
const { test } = require('@playwright/test');
const { waitForPageReady, waitForGameReady } = require('./helpers/setup');
const { loadTestState, loadSaveCache } = require('./helpers/walkthrough');
const { getT, cmd } = require('./helpers/term');

test('issue4 shenght finale', async ({ page }) => {
  test.setTimeout(180000);
  loadSaveCache('bridge-p10.json');
  await page.goto('/'); await waitForPageReady(page); await waitForGameReady(page); await page.waitForTimeout(2000);
  await loadTestState(page, 1); await page.waitForTimeout(1000);

  async function dump(tag, n){
    const t = await getT(page);
    console.log('=== ' + tag + ' ===');
    const lines = t.split('\n').filter(Boolean);
    for (const l of lines) console.log('   ' + l.trimEnd().substring(0,74));
    return t;
  }
  // force into 圣堂 scene 83, and show look
  await page.evaluate(async () => {
    const c='local J=rawget(_G,"JY"); J.Status=4; J.SubScene=83; local h=rawget(_G,"SmapHandlers"); if h and h.look then h.look({}) end; return "ok"';
    const r=await window.__luaEval(c); return r&&r.ok?r.result:'err';
  });
  await page.waitForTimeout(500);
  await dump('圣堂 look');

  // find 时空机/神机 entity index
  const probeEnts = await page.evaluate(async ()=>{
    const term=window.__xterm; const out=[];
    for(let y=term.buffer.active.length-1; y>=0; y--){
      const s=term.buffer.active.getLine(y)?.translateToString(true)||'';
      const m=s.match(/^(\d+)\.\s*(.*?)(\[(oldevent_)?(\d+)\])?\s*$/);
      if(m){ out.push(m[0].trimEnd().substring(0,50)); }
    }
    return out.slice(0,14);
  });
  // list ALL numbered options in reading order
  const ordered = await page.evaluate(async ()=>{
    const term=window.__xterm; const out=[];
    for(let y=0; y<term.buffer.active.length; y++){
      const s=term.buffer.active.getLine(y)?.translateToString(true)||'';
      const m=s.match(/^\s*(\d+)\.\s*(.*)$/);
      if(m) out.push(m[1] + ': ' + m[2].trimEnd().substring(0,44));
    }
    return out;
  });
  console.log('ORDERED ENTITIES:');
  for (const e of ordered.filter((x,i,a)=>a.indexOf(x)===i)) console.log('   ' + e);
  console.log('probeEnts:', probeEnts);

  // select 时空机 [oldevent_1017] - entity 1 at the start of entity list.
  // In this look it's "1. 搜索[oldevent_1017]" (end terminus). Try choose 1.
  await cmd(page, 'choose 1'); await page.waitForTimeout(1500);
  await dump('after choose1 (1017)');
  await cmd(page, 'choose 1'); await page.waitForTimeout(800);
  await dump('after choose1 #2');
  const fin = await page.evaluate(async ()=>{
    const c='local J=rawget(_G,"JY"); return "status="..tostring(J and J.Status).." gameover="..tostring(rawget(_G,"__gameOver")==true).." endingReached="..tostring(rawget(_G,"__endingReached")==true)';
    const r=await window.__luaEval(c); return r&&r.ok?r.result:'err';});
  console.log('FINALE STATE:', fin);
});