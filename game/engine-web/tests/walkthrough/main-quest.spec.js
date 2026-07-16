// tests/walkthrough/main-quest.spec.js
// 攻略式 e2e 测试 — 按 quick_pass_game.md 速通攻略顺序
// 单 test 链式执行 20 步，每 5 步打一个 checkpoint 存档
// 使用 gotoScene 自动解析场景编号，不依赖固定索引

const { test, expect } = require('@playwright/test');
const { waitForPageReady } = require('../helpers/setup');
const { saveTestState, loadTestState, gotoScene } = require('../helpers/walkthrough');

const SETTLE = 5000;

async function getText(page) {
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

async function noErrors(page) {
  return page.evaluate(() => {
    const term = window.__xterm;
    if (!term) return true;
    for (let y = 0; y < term.rows; y++) {
      if ((term.buffer.active.getLine(y)?.translateToString(true) || '').includes('[gameLoop error]')) return false;
    }
    return true;
  });
}

async function cmd(page, text) {
  const input = page.locator('#command-input');
  await input.waitFor({ state: 'visible', timeout: 5000 });
  await input.fill(text);
  await page.keyboard.press('Enter');
}

const steps = [
  // === Phase 1: 开局入门 ===
  { /* 1 */ name: '开局-选择新游戏',
    fn: async (p) => { await cmd(p, 'choose 1'); await p.waitForTimeout(3000);
      let t = await getText(p); expect(t).toContain('生命'); expect(t).toContain('攻击');
      await cmd(p, 'choose 1'); await p.waitForTimeout(SETTLE);
      t = await getText(p); expect(t).toContain('新游戏开始'); },
    save: 11 },
  { /* 2 */ name: '前往南贤居', load: 11,
    fn: async (p) => { expect(await loadTestState(p, 11)).toBe(true);
      await cmd(p, 'leave'); await p.waitForTimeout(SETTLE);
      await gotoScene(p, '南賢居'); expect(await getText(p)).toContain('南賢居'); },
    save: 12 },
  { /* 3 */ name: '与南贤对话', load: 12,
    fn: async (p) => { expect(await loadTestState(p, 12)).toBe(true);
      await cmd(p, 'choose 1'); await p.waitForTimeout(3000); await cmd(p, 'choose 1'); await p.waitForTimeout(3000);
      expect(await getText(p)).toContain('南贤'); },
    save: 13 },
  { /* 4 */ name: '田伯光加入', load: 13,
    fn: async (p) => { expect(await loadTestState(p, 13)).toBe(true);
      await cmd(p, 'leave'); await p.waitForTimeout(SETTLE);
      await gotoScene(p, '田伯光居'); expect(await getText(p)).toContain('田伯光居'); },
    save: 14 },
  { /* 5 */ name: '闫基居战斗', load: 14,
    fn: async (p) => { expect(await loadTestState(p, 14)).toBe(true);
      await cmd(p, 'leave'); await p.waitForTimeout(SETTLE);
      await gotoScene(p, '閰基居'); expect(await getText(p)).toContain('閰基居');
      await cmd(p, 'choose 4'); await p.waitForTimeout(6000);
      expect(await getText(p)).toContain('阎基'); expect(await noErrors(p)).toBeTruthy(); },
    save: 15 },
  // === Phase 2: 队友招募 ===
  { /* 6 */ name: '高升客栈-段誉加入', load: 15,
    fn: async (p) => { expect(await loadTestState(p, 15)).toBe(true);
      await cmd(p, 'leave'); await p.waitForTimeout(SETTLE);
      await gotoScene(p, '高昇客棧'); expect(await getText(p)).toContain('高昇客棧'); },
    save: 16 },
  { /* 7 */ name: '回族部落', load: 16,
    fn: async (p) => { expect(await loadTestState(p, 16)).toBe(true);
      await cmd(p, 'leave'); await p.waitForTimeout(SETTLE);
      await gotoScene(p, '回族部落'); expect(await getText(p)).toContain('回族部落'); },
    save: 17 },
  // === Phase 3: 天书收集 ===
  { /* 8 */ name: '胡斐居对话', load: 17,
    fn: async (p) => { expect(await loadTestState(p, 17)).toBe(true);
      await cmd(p, 'leave'); await p.waitForTimeout(SETTLE);
      await gotoScene(p, '胡斐居'); expect(await getText(p)).toContain('胡斐居');
      await cmd(p, 'choose 3'); await p.waitForTimeout(3000); await cmd(p, 'choose 1'); await p.waitForTimeout(3000);
      expect(await getText(p)).toContain('胡斐'); },
    save: 18 },
  { /* 9 */ name: '冰火岛', load: 18,
    fn: async (p) => { expect(await loadTestState(p, 18)).toBe(true);
      await cmd(p, 'leave'); await p.waitForTimeout(SETTLE);
      await gotoScene(p, '冰火島'); expect(await getText(p)).toContain('冰火島'); },
    save: 19 },
  { /* 10 */ name: '铁掌山', load: 19,
    fn: async (p) => { expect(await loadTestState(p, 19)).toBe(true);
      await cmd(p, 'leave'); await p.waitForTimeout(SETTLE);
      await gotoScene(p, '鐵掌山'); expect(await getText(p)).toContain('鐵掌山'); },
    save: 20 },
  { /* 11 */ name: '无量山洞', load: 20,
    fn: async (p) => { expect(await loadTestState(p, 20)).toBe(true);
      await cmd(p, 'leave'); await p.waitForTimeout(SETTLE);
      await gotoScene(p, '無量山洞'); expect(await getText(p)).toContain('無量山洞'); },
    save: 21 },
  { /* 12 */ name: '崑仑派', load: 21,
    fn: async (p) => { expect(await loadTestState(p, 21)).toBe(true);
      await cmd(p, 'leave'); await p.waitForTimeout(SETTLE);
      await gotoScene(p, '崑侖派'); expect(await getText(p)).toContain('崑侖派'); },
    save: 22 },
  { /* 13 */ name: '燕子坞', load: 22,
    fn: async (p) => { expect(await loadTestState(p, 22)).toBe(true);
      await cmd(p, 'leave'); await p.waitForTimeout(SETTLE);
      await gotoScene(p, '燕子塢'); expect(await getText(p)).toContain('燕子塢'); },
    save: 23 },
  { /* 14 */ name: '泰山派', load: 23,
    fn: async (p) => { expect(await loadTestState(p, 23)).toBe(true);
      await cmd(p, 'leave'); await p.waitForTimeout(SETTLE);
      await gotoScene(p, '泰山派'); expect(await getText(p)).toContain('泰山派'); },
    save: 24 },
  { /* 15 */ name: '苗人凤居', load: 24,
    fn: async (p) => { expect(await loadTestState(p, 24)).toBe(true);
      await cmd(p, 'leave'); await p.waitForTimeout(SETTLE);
      await gotoScene(p, '苗人鳳居'); expect(await getText(p)).toContain('苗人鳳居'); },
    save: 25 },
  { /* 16 */ name: '悦来客栈-令狐冲', load: 25,
    fn: async (p) => { expect(await loadTestState(p, 25)).toBe(true);
      await cmd(p, 'leave'); await p.waitForTimeout(SETTLE);
      await gotoScene(p, '悅來客棧'); expect(await getText(p)).toContain('悅來客棧'); },
    save: 26 },
  { /* 17 */ name: '明教分舵', load: 26,
    fn: async (p) => { expect(await loadTestState(p, 26)).toBe(true);
      await cmd(p, 'leave'); await p.waitForTimeout(SETTLE);
      await gotoScene(p, '明教分舵'); expect(await getText(p)).toContain('明教分舵'); },
    save: 27 },
  { /* 18 */ name: '光明顶', load: 27,
    fn: async (p) => { expect(await loadTestState(p, 27)).toBe(true);
      await cmd(p, 'leave'); await p.waitForTimeout(SETTLE);
      await gotoScene(p, '光明頂'); expect(await getText(p)).toContain('光明頂'); },
    save: 28 },
  { /* 19 */ name: '百花谷', load: 28,
    fn: async (p) => { expect(await loadTestState(p, 28)).toBe(true);
      await cmd(p, 'leave'); await p.waitForTimeout(SETTLE);
      await gotoScene(p, '百花谷'); expect(await getText(p)).toContain('百花谷'); },
    save: 29 },
  { /* 20 */ name: '绝情谷', load: 29,
    fn: async (p) => { expect(await loadTestState(p, 29)).toBe(true);
      await cmd(p, 'leave'); await p.waitForTimeout(SETTLE);
      await gotoScene(p, '絕情谷'); expect(await getText(p)).toContain('絕情谷'); },
    save: 30 },
];

async function runSteps(page, steps) {
  for (let i = 0; i < steps.length; i++) {
    const s = steps[i];
    await s.fn(page);
    expect(await noErrors(page)).toBeTruthy();
    if (s.save) {
      expect(await saveTestState(page, s.save)).toBe(true);
    }
    console.log(`  ✓ Step ${i + 1}: ${s.name}${s.load ? ` (loaded ${s.load})` : ''}`);
    // 每 5 步输出 checkpoint
    if ((i + 1) % 5 === 0) console.log(`    Checkpoint ${i + 1}/20`);
  }
}

test.describe('攻略主线测试', () => {
  test('20步: 开局→南贤→田伯光→闫基→高升→回族→胡斐→冰火→铁掌→无量→昆仑→燕子→泰山→苗人→悦来→明教→光明→百花→绝情', async ({ page }) => {
    test.setTimeout(600000);
    await page.goto('/'); await waitForPageReady(page); await page.waitForTimeout(3000);
    await runSteps(page, steps);
    console.log('  ✓ 全部 20 步完成');
  });
});
