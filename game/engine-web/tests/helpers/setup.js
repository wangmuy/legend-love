const { expect } = require('@playwright/test');

async function waitForPageReady(page) {
  // Web Worker 模式：等待 index.js 设置 window.__workerReady
  await page.waitForFunction(() => {
    return window.__workerReady === true;
  }, { timeout: 30000 });
}

async function getLuaGlobal(page, name) {
  // 通过 Worker 的 lua_eval 通道获取 Lua 全局变量
  const result = await page.evaluate(async (n) => {
    if (!window.__luaEval) return { type: 'worker_not_ready' };
    const r = await window.__luaEval('return ' + n);
    return r;
  }, name);
  return result;
}

async function luaEval(page, code) {
  // 通过 Worker 的 lua_eval 通道执行 Lua 代码
  const result = await page.evaluate(async (c) => {
    if (!window.__luaEval) return { __error: 'worker not ready' };
    const r = await window.__luaEval(c);
    return r;
  }, code);
  return result;
}

module.exports = { waitForPageReady, getLuaGlobal, luaEval };
