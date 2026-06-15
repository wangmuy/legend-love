const { expect } = require('@playwright/test');

async function waitForPageReady(page) {
  // Web Worker 模式：等待 index.js 设置 window.__workerReady
  await page.waitForFunction(() => {
    return window.__workerReady === true;
  }, { timeout: 30000 });
}

async function getLuaGlobal(page, name) {
  // Lua 在 Worker 中，主线程无法直接访问。
  // 返回占位值，调用方需适配 Worker 模式。
  return { type: 'worker_mode', note: 'Lua is in Web Worker, use terminal I/O to test' };
}

async function luaEval(page, code) {
  // Lua 在 Worker 中，主线程无法直接执行 Lua 代码。
  return { __error: 'Lua is in Web Worker, cannot eval from main thread' };
}

module.exports = { waitForPageReady, getLuaGlobal, luaEval };
