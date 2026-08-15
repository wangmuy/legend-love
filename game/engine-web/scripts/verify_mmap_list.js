// verify_mmap_list.js
// 真实运行时验证：连接测试服务器（8088），等待游戏就绪后直接调用
// 真实的 MmapHandlers.list({})（与用户输入 `list` 走同一代码路径），
// 抓取终端输出，与 check_mmap_list.js 的静态编号逐项对比。
const { chromium } = require('playwright');
const { execSync } = require('child_process');
const path = require('path');

async function getLastLines(page, n) {
  return page.evaluate((n) => {
    const term = window.__xterm;
    if (!term) return [];
    const total = term.buffer.active.length;
    const out = [];
    for (let y = Math.max(0, total - n); y < total; y++) {
      const s = term.buffer.active.getLine(y)?.translateToString(true) || '';
      if (s.trim()) out.push(s.trimEnd());
    }
    return out;
  }, n);
}

async function luaEval(page, code) {
  return page.evaluate(async (c) => {
    if (!window.__luaEval) return { ok: false, error: 'no __luaEval' };
    return await window.__luaEval(c);
  }, code);
}

async function waitGameReady(page) {
  for (let t = 0; t < 120; t++) {
    const r = await luaEval(page, 'return tostring(rawget(_G, "JY") ~= nil and rawget(_G, "MmapHandlers") ~= nil)');
    if (r && r.ok && r.result === 'true') return true;
    await page.waitForTimeout(500);
  }
  return false;
}

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  await page.goto('http://127.0.0.1:8088/');
  const ready = await waitGameReady(page);
  if (!ready) { console.error('❌ 游戏未就绪'); await browser.close(); process.exit(2); }

  // 直接调用真实 list（与用户输入 list 相同的处理路径）
  const r = await luaEval(page, 'local mh = rawget(_G, "MmapHandlers"); if mh and mh.list then mh.list({}) return "called" else return "no handler" end');
  console.log('list 调用:', r && r.result);
  await page.waitForTimeout(2000);

  const lines = await getLastLines(page, 320);
  // 从 "可去场景（选择序号前往）" 标题开始收集；w() 输出的列表为严格递增 1..N，
  // showMenu 随后追加的菜单段编号会回退（再次出现 1. 或 0. 返回），只取第一段递增列表。
  const startIdx = lines.findIndex(l => l.includes('可去场景'));
  const runtime = [];
  if (startIdx >= 0) {
    let expect = 1;
    for (const l of lines.slice(startIdx + 1)) {
      const m = l.match(/^(\d+)\.\s+(.+)$/);
      if (!m) { if (runtime.length) break; continue; }
      const idx = parseInt(m[1], 10);
      if (idx === expect) {
        runtime.push({ idx, label: m[2].trim() });
        expect++;
      } else {
        break; // showMenu 菜单段开始（编号回退）或列表结束
      }
    }
  }
  console.log(`运行时捕获列表项: ${runtime.length}`);
  if (!runtime.length) {
    console.log('--- 终端最后 30 行 ---');
    console.log(lines.slice(-30).join('\n'));
  }

  // 静态编号
  const staticOut = execSync('node check_mmap_list.js', { cwd: __dirname, encoding: 'utf8' });
  const stat = [];
  for (const l of staticOut.split('\n')) {
    const m = l.match(/^(\d+)\.\s+(.+?)\s+\[sceneId=(\d+)\]$/);
    if (m) stat.push({ idx: parseInt(m[1], 10), label: m[2].trim(), sceneId: m[3] });
  }
  console.log(`静态编号: ${stat.length}`);

  let mismatch = 0;
  const maxLen = Math.max(runtime.length, stat.length);
  for (let i = 0; i < maxLen; i++) {
    const rr = runtime[i];
    const ss = stat[i];
    const rl = rr ? `${rr.idx}. ${rr.label}` : '(缺)';
    const sl = ss ? `${ss.idx}. ${ss.label} [sceneId=${ss.sceneId}]` : '(缺)';
    if (!(rr && ss && rr.idx === ss.idx && rr.label === ss.label)) {
      mismatch++;
      console.log(`✗ 第${i + 1}项 运行时="${rl}" 静态="${sl}"`);
    }
  }
  if (mismatch === 0 && runtime.length === stat.length && runtime.length > 0) {
    console.log('✅ 运行时 list 输出与静态编号完全一致（用户看到的编号=静态编号表）');
  } else {
    console.log(`❌ 不一致 ${mismatch} 处（运行时 ${runtime.length} / 静态 ${stat.length}）`);
  }
  await browser.close();
  process.exit(mismatch === 0 && runtime.length === stat.length && runtime.length > 0 ? 0 : 1);
})().catch(e => { console.error('ERR', e.message); process.exit(2); });
