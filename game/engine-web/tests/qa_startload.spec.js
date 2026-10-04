// qa: start-menu 载入进度 shows selectable slot menu, then loads chosen slot
const { test, expect } = require('@playwright/test');
const { waitForPageReady, waitForGameReady } = require('./helpers/setup');
const { cmd, getT } = require('./helpers/term');

async function waitTerm(page, fn, ms = 20000) {
  const deadline = Date.now() + ms;
  let last = '';
  while (Date.now() < deadline) {
    last = await getT(page);
    if (fn(last)) return last;
    await page.waitForTimeout(150);
  }
  throw new Error('waitTerm timeout. Last terminal:\n' + last);
}

test('start 载入进度 -> slot menu -> choose slot -> loaded', async ({ page }) => {
  test.setTimeout(220000);
  await page.goto('/'); await waitForPageReady(page); await waitForGameReady(page); await page.waitForTimeout(2500);
  await cmd(page, 'choose 1'); await page.waitForTimeout(4300); // new game
  await cmd(page, 'choose 1'); await page.waitForTimeout(1200);
  await cmd(page, 'leave'); await page.waitForTimeout(1200);
  await cmd(page, 'save 3'); await page.waitForTimeout(4000);  // durable save slot3
  const durable = await page.evaluate(() => new Promise(res => {
    const r = indexedDB.open('jyLegendWebMud', 1);
    r.onsuccess = () => { const db = r.result; const g = db.transaction('saves','readonly').objectStore('saves').get('save_3');
      g.onsuccess = () => res(!!(g.result && g.result.value));
      g.onerror = () => res(false);
      setTimeout(() => res(false), 500); };
    r.onerror = () => res(false);
  }));
  expect(durable).toBe(true);

  await page.reload(); await waitForPageReady(page); await waitForGameReady(page); await page.waitForTimeout(1500);
  // choose 载入进度 -> should open a selectable slot menu (不直接读档)
  await cmd(page, 'choose 2');
  const t1 = await waitTerm(page, (s)=> s.includes('读取槽位3'));
  console.log('SMOKE submenu shows 读取槽位3:', t1.includes('读取槽位3'));
  expect(t1).toContain('读取槽位3');
  expect(t1).toContain('选择要读取的存档槽位');
  // choose the slot3 option (occupy slots=[3], first option is slot3)
  await cmd(page, 'choose 1');
  const t2 = await waitTerm(page, (s)=> s.includes('读取存档成功') || s.includes('没有存档'));
  await page.waitForTimeout(800);
  const finalT = await getT(page);
  console.log('after select slot ->', finalT.includes('读取存档成功（槽位3）') ? 'LOADED_SLOT3' : finalT.includes('没有存档') ? 'NO_SAVE' : 'UNKNOWN');
  expect(finalT).toContain('读取存档成功');
});