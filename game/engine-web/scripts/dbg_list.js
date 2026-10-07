// dbg_list.js — 调试：真实运行时开局后执行 list，dump 原始终端输出
const { chromium } = require('playwright');
const SETTLE = 2000;
async function getT(page) {
  return page.evaluate(() => {
    const term = window.__xterm;
    if (!term) return '';
    const lines = [];
    for (let y = 0; y < term.buffer.active.length; y++) {
      const s = term.buffer.active.getLine(y)?.translateToString(true) || '';
      if (s.trim()) lines.push(s.trimEnd());
    }
    return lines.join('\n');
  });
}
async function cmd(page, t) {
  const i = page.locator('#command-input');
  await i.waitFor({ state: 'visible', timeout: 15000 });
  await i.fill(t);
  await page.keyboard.press('Enter');
}
(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  await page.goto('http://127.0.0.1:8088/');
  await page.waitForTimeout(10000);
  await cmd(page, 'choose 1'); await page.waitForTimeout(4000);
  let t = await getT(page);
  console.log('=== after choose1 ===');
  console.log(t.slice(-800));
  await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
  t = await getT(page);
  console.log('=== after choose1 confirm ===');
  console.log(t.slice(-800));
  await cmd(page, 'leave'); await page.waitForTimeout(3000);
  t = await getT(page);
  console.log('=== after leave ===');
  console.log(t.slice(-600));
  await cmd(page, 'list'); await page.waitForTimeout(3000);
  t = await getT(page);
  console.log('=== after list ===');
  console.log(t.slice(-3000));
  await browser.close();
})().catch(e => { console.error('ERR', e.message); process.exit(2); });
