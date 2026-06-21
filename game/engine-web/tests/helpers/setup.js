const { expect } = require('@playwright/test');

async function waitForPageReady(page) {
  // Web Worker 模式：等待 index.js 设置 window.__workerReady
  await page.waitForFunction(() => {
    return window.__workerReady === true;
  }, { timeout: 30000 });
}

async function getLuaGlobal(page, name) {
  const result = await page.evaluate(async (n) => {
    if (!window.__luaEval) return { type: 'worker_not_ready' };
    const r = await window.__luaEval('return ' + n);
    return r;
  }, name);
  return result;
}

async function luaEval(page, code) {
  const result = await page.evaluate(async (c) => {
    if (!window.__luaEval) return { __error: 'worker not ready' };
    const r = await window.__luaEval(c);
    return r;
  }, code);
  return result;
}

async function waitForGameReady(page) {
  await page.waitForFunction(() => {
    const term = window.__xterm;
    if (!term) return false;
    for (let y = 0; y < term.buffer.active.length; y++) {
      const text = term.buffer.active.getLine(y)?.translateToString(true) || '';
      if (text.includes('输入 choose 1 开始新游戏')) return true;
    }
    return false;
  }, { timeout: 60000 });
}

module.exports = { waitForPageReady, getLuaGlobal, luaEval, waitForGameReady };
