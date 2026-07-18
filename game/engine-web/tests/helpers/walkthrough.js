// tests/helpers/walkthrough.js
// 攻略 e2e 测试存档跳转工具函数

const _bridgeCache = {};
const fs = require('fs');
const path = require('path');

async function saveTestState(page, slot) {
  // 使用 saveGameState 保存（可能存储到 luaSaveCache 和 __saveCache）
  const r = await page.evaluate(async (s) => {
    if (!window.__luaEval) return { ok: false, result: 'bridge not ready' };
    return await window.__luaEval(`return saveGameState(${s})`);
  }, slot);
  // 直接从 JY 读取数据并缓存到 _bridgeCache（绕过 JSBridge.load 的问题）
  // 使用 encodeSimpleJSON 而非 _G.JSON.encode，因为自定义编码器已处理大表
  const data = await page.evaluate(async (s) => {
    if (!window.__luaEval) return null;
    const code = 'local J = rawget(_G, "JY"); if not J then return "{}" end; local d = {base=J.Base, persons=J.Person, things=J.Thing, scenes=J.Scene, wugongs=J.Wugong, shops=J.Shop, status=J.Status, subScene=J.SubScene, mmapMusic=J.MmapMusic, currentD=J.CurrentD}; local encode = rawget(_G, "encodeSimpleJSON"); if not encode then return "{}" end; local ok, json = pcall(encode, d); return ok and json or "{}"';
    const r2 = await window.__luaEval(code);
    return r2 && r2.ok && r2.result !== '{}' ? r2.result : null;
  }, slot);
  if (data) {
    _bridgeCache[slot] = data;
    console.log(`[saveTestState] slot ${slot}: cached ${data.length} bytes`);
  } else {
    console.log(`[saveTestState] slot ${slot}: FAILED to cache data`);
  }
  return r && r.ok && r.result === 'true';
}

async function loadTestState(page, slot) {
  // 先等待 initCoroutine 创建 JY（SetGlobal 会覆盖 loadGameState 设置的 JY）
  for (let t = 0; t < 20; t++) {
    const hasJY = await page.evaluate(async () => {
      if (!window.__luaEval) return false;
      const r = await window.__luaEval('return tostring(rawget(_G, "JY") ~= nil)');
      return r && r.ok && r.result === 'true';
    });
    if (hasJY) break;
    await page.waitForTimeout(50);
  }
  // 1. 先检查 luaSaveCache 中是否有数据
  const hasData = await page.evaluate(async (s) => {
    if (!window.__luaEval) return false;
    const r = await window.__luaEval(`return tostring(JSBridge.load("save_${s}") ~= nil)`);
    return r && r.ok && r.result === 'true';
  }, slot);
  if (!hasData) {
    console.log('[loadTestState] slot ' + slot + ' not in luaSaveCache');
  }
  // 也检查 __saveCache（patched loadGameState 优先读取）
  const hasCache = await page.evaluate(async (s) => {
    if (!window.__luaEval) return false;
    const r = await window.__luaEval('rawset(_G, "__saveCache", rawget(_G, "__saveCache") or {}); return tostring(rawget(_G, "__saveCache")["save_' + s + '"] ~= nil)');
    return r && r.ok && r.result === 'true';
  }, slot);
  console.log(`[loadTestState] slot ${slot}: luaSaveCache=${hasData}, __saveCache=${hasCache}`);
  // 2. 尝试直接从 luaSaveCache 加载
  let r = await page.evaluate(async (s) => {
    if (!window.__luaEval) return { ok: false };
    const result = await window.__luaEval('return loadGameState(' + s + ')');
    if (result && result.ok && result.result === 'true') {
      await window.__luaEval('local JY = rawget(_G, "JY"); if JY then JY.Status = 2 end');
      await window.__luaEval('pcall(function() if _G.MmapHandlers then _G.MmapHandlers.look({}) end end)');
    }
    return result;
  }, slot);
  if (r && r.ok && r.result === 'true') {
    await page.waitForTimeout(500);
    return true;
  }
  // 3. luaSaveCache 中无数据，从 _bridgeCache 注入并尝试 loadGameState
  const cacheJson = _bridgeCache[slot];
  if (cacheJson) {
    // 先注入到 luaSaveCache（worker 内存缓存）
    await page.evaluate(({ key, value }) => {
      if (window.__worker) {
        window.__worker.postMessage({ type: 'test_inject_save', key, value });
      }
    }, { key: 'save_' + slot, value: cacheJson });
    // 也注入到 __saveCache（Lua 全局变量，patched loadGameState 优先读取）
    const injectSaveCache = await page.evaluate(async ({ json, sn }) => {
      if (!window.__luaEval) return false;
      await window.__luaEval('rawset(_G, "__saveCache", rawget(_G, "__saveCache") or {})');
      const chunkSize = 10000;
      for (let i = 0; i < json.length; i += chunkSize) {
        const chunk = json.substring(i, i + chunkSize);
        const code = i > 0
          ? 'rawget(_G, "__saveCache")["save_' + sn + '"] = rawget(_G, "__saveCache")["save_' + sn + '"] .. [====[' + chunk + ']====]'
          : 'rawget(_G, "__saveCache")["save_' + sn + '"] = [====[' + chunk + ']====]';
        const r = await window.__luaEval(code);
        if (!r || !r.ok) return false;
      }
      return true;
    }, { json: cacheJson, sn: slot });
    await page.waitForTimeout(500);
    // 尝试 loadGameState（应优先找到 __saveCache 中的数据，直接解析绕过 JSBridge）
    r = await page.evaluate(async (s) => {
      if (!window.__luaEval) return { ok: false };
      const result = await window.__luaEval('return loadGameState(' + s + ')');
      if (result && result.ok && result.result === 'true') {
        await window.__luaEval('local JY = rawget(_G, "JY"); if JY then JY.Status = 2; if _G.MmapHandlers then pcall(_G.MmapHandlers.look, _G.MmapHandlers, {}) end end');
      }
      return result;
    }, slot);
    if (r && r.ok && r.result === 'true') {
      await page.waitForTimeout(500);
      return true;
    }
    // 如果 loadGameState 仍失败，直接解析 JSON 设置 JY
    let fallbackOk = await page.evaluate(async ({ json }) => {
      if (!window.__luaEval) return false;
      // 将 JSON 字符串存储到 Lua 全局变量（使用 rawset 绕过 __newindex=error）
      const code = 'rawset(_G, "__saveData", [[' + json + ']])';
      let r = await window.__luaEval(code);
      if (!r || !r.ok) {
        // 如果直接存储失败，分段存储并合并
        const chunkSize = 10000;
        for (let i = 0; i < json.length; i += chunkSize) {
          const chunk = json.substring(i, i + chunkSize);
          const codeChunk = i > 0
            ? 'rawset(_G, "__saveData", rawget(_G, "__saveData") .. [[' + chunk + ']])'
            : 'rawset(_G, "__saveData", [[' + chunk + ']])';
          r = await window.__luaEval(codeChunk);
          if (!r || !r.ok) return false;
        }
      }
      // 解析 JSON 并设置 JY
      const parseCode = 'local d = _G.JSON.decode(rawget(_G, "__saveData")); if d then local J = rawget(_G, "JY"); if not J then J = {}; rawset(_G, "JY", J) end; J.Base = d.base or {}; J.Person = d.persons or {}; J.Thing = d.things or {}; J.Scene = d.scenes or {}; J.Wugong = d.wugongs or {}; J.Shop = d.shops or {}; J.Status = d.status or 2; J.SubScene = d.subScene or 0; rawset(_G, "__saveData", nil) end; return tostring(d ~= nil)';
      r = await window.__luaEval(parseCode);
      return r && r.ok && r.result === 'true';
    }, { json: cacheJson });
    if (fallbackOk) {
      // 强制切换到 MMAP 状态
      await page.evaluate(async () => {
        if (!window.__luaEval) return;
        await window.__luaEval('local J = rawget(_G, "JY"); if J then J.Status = 2; J.SubScene = 0 end');
        await window.__luaEval('local sm = rawget(_G, "StateMachine"); if sm then local inst = sm.getInstance(); if inst and inst.switchTo then pcall(inst.switchTo, inst, 2) end end');
        await window.__luaEval('local mh = rawget(_G, "MmapHandlers"); if mh and mh.look then pcall(mh.look, mh, {}) end');
      });
      await page.waitForTimeout(500);
      return true;
    }
  }
  return false;
}

/**
 * 通过场景名称导航，确保在大地图 → 关对话框 → 关菜单 → 按名称排序的 list → 导航验证
 * sceneItems 按名称排序（buildSceneList 中 table.sort），顺序稳定
 */
async function gotoScene(page, sceneName, waitMs) {
  const input = page.locator('#command-input');
  await input.waitFor({ state: 'visible', timeout: 15000 });
  // 1. 确保在大地图状态（关闭可能残留的对话框/菜单）
  for (let i = 0; i < 3; i++) {
    await input.fill('choose 0'); await page.keyboard.press('Enter'); await page.waitForTimeout(100);
  }
  await input.fill('leave'); await page.keyboard.press('Enter'); await page.waitForTimeout(500);
  // 2. list 展示大地图场景列表
  await input.fill('list'); await page.keyboard.press('Enter'); await page.waitForTimeout(waitMs || 3000);

  // 3. 从最近一次"可去场景"之后搜索（sceneItems 按名称排序，顺序稳定）
  const idx = await page.evaluate((name) => {
    const term = window.__xterm;
    if (!term) return -1;
    const total = term.buffer.active.length;
    let lastList = -1;
    for (let y = total - 1; y >= 0; y--)
      if (term.buffer.active.getLine(y)?.translateToString(true)?.includes('可去场景'))
        { lastList = y; break; }
    if (lastList === -1) return -1;
    for (let y = total - 1; y > lastList; y--) {
      const raw = term.buffer.active.getLine(y)?.translateToString(true) || '';
      const m = raw.match(/^\D*(\d+)\.\s*(.*\S)\s*$/);
      if (m && m[2].includes(name)) return parseInt(m[1], 10);
    }
    return -1;
  }, sceneName);

  // 4. 导航
  if (idx > 0) {
    await input.fill('choose ' + idx);
    await page.keyboard.press('Enter');
    await page.waitForTimeout(waitMs || 5000);
  }
  return idx;
}

/** 将 _bridgeCache 写入文件（跨 spec 持久化） */
function flushSaveCache(filepath) {
  fs.writeFileSync(path.resolve(__dirname, '..', filepath), JSON.stringify(_bridgeCache), 'utf8');
}

/** 从文件读取 _bridgeCache（跨 spec 恢复） */
function loadSaveCache(filepath) {
  try {
    const data = fs.readFileSync(path.resolve(__dirname, '..', filepath), 'utf8');
    const loaded = JSON.parse(data);
    for (const [k, v] of Object.entries(loaded)) {
      _bridgeCache[k] = v;
    }
  } catch (e) {
    // file not found — first run
  }
}

module.exports = { saveTestState, loadTestState, gotoScene, flushSaveCache, loadSaveCache };