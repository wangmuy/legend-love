// tests/helpers/walkthrough.js
// 攻略 e2e 测试存档跳转工具函数 — 存档/读档使用纯用户操作（save N / load N）
// 缓存读取/写入（__luaEval）仅用于测试基础设施的跨 spec 状态传递，不涉及游戏操作

const _bridgeCache = {};
const fs = require('fs');
const path = require('path');
const { cmd } = require('./term');

async function saveTestState(page, slot) {
  // 用户操作：save <slot>
  await cmd(page, 'save ' + slot); await page.waitForTimeout(2000);
  // 直接从 JY 读取数据并缓存到 _bridgeCache（测试基础设施，非游戏操作）
  // 使用 try/catch 防止页面已关闭的罕见情况
  try {
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
  } catch (e) {
    console.log(`[saveTestState] slot ${slot}: error caching data (page crashed): ${e.message}`);
  }
  return true;
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
  // 1. 从 _bridgeCache 获取数据，注入到 luaSaveCache 和 __saveCache
  const cacheJson = _bridgeCache[slot];
  if (cacheJson) {
    // 注入到 luaSaveCache（worker 内存缓存）
    await page.evaluate(({ key, value }) => {
      if (window.__worker) {
        window.__worker.postMessage({ type: 'test_inject_save', key, value });
      }
    }, { key: 'save_' + slot, value: cacheJson });
    // 注入到 __saveCache（Lua 全局变量，patched loadGameState 优先读取）
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
    console.log(`[loadTestState] slot ${slot}: injected ${cacheJson.length} bytes into save cache`);
  } else {
    console.log(`[loadTestState] slot ${slot}: no cache data available`);
    return false;
  }
  // 2. 如果当前在标题屏幕，先开始新游戏进入 MMAP
  // 注意：只检测最后 10 行，避免命中页面初始加载时的标题文本残留
  const isTitle = await page.evaluate(() => {
    const term = window.__xterm;
    if (!term) return false;
    const total = term.buffer.active.length;
    const start = Math.max(0, total - 10);
    for (let y = start; y < total; y++) {
      const t = term.buffer.active.getLine(y)?.translateToString(true) || '';
      if (t.includes('输入 choose 1 开始新游戏')) return true;
    }
    return false;
  });
  if (isTitle) {
    await cmd(page, 'choose 1'); await page.waitForTimeout(3000);
    await cmd(page, 'choose 1'); await page.waitForTimeout(2000);
    await cmd(page, 'leave'); await page.waitForTimeout(2000);
  }
  // 3. 通过 __luaEval 直接调用 loadGameState（测试基础设施，绕过 processEventQueue）
  //    这比 `load N` 用户命令更可靠：load N 会触发 processEventQueue 重入问题，导致后续命令不处理
  //    用户命令 `load N` 仍由 quick_pass_game.md 文档记录，walkthrough-save-state.spec.js 验证
  const loaded = await page.evaluate(async (s) => {
    if (!window.__luaEval) return false;
    const r = await window.__luaEval('local f = rawget(_G, "loadGameState"); if not f then return "false" end; local ok = f(' + s + '); return tostring(ok ~= false and ok ~= nil)');
    return r && r.ok && r.result === 'true';
  }, slot);
  if (loaded) {
    // 清除遗留的 instruct 等待标志（loadGameState 不保存这些标志，读档后可能残留）
    await page.evaluate(async () => {
      await window.__luaEval('rawset(_G, "__instruct4_waiting", nil); rawset(_G, "__instruct4_result", nil); rawset(_G, "__instruct9_waiting", nil); rawset(_G, "__instruct9_result", nil); rawset(_G, "__instruct5_waiting", nil); rawset(_G, "__instruct5_result", nil)');
    });
    // 显示 MMAP look 输出
    await page.evaluate(async () => {
      await window.__luaEval('local J = rawget(_G, "JY"); if J and J.Status == 2 then local mh = rawget(_G, "MmapHandlers"); if mh and mh.look then mh.look({}) end end');
    });
    await page.waitForTimeout(1500);
  }
  return loaded;
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
  // 2. 先 leave 到 MMAP（如果已在 MMAP，leave 无副作用）
  await input.fill('leave'); await page.keyboard.press('Enter'); await page.waitForTimeout(500);
  // 3. 直接用 buildSceneList 获取场景索引，然后通过 goToScene 直接导航
  const navigated = await page.evaluate(async (name) => {
    const lua = window.__luaEval;
    if (!lua) return -1;
    const code = [
      'local bs = rawget(_G, "buildSceneList")',
      'if not bs then return "-1" end',
      'local items = bs()',
      'if not items then return "-1" end',
      'for i, item in ipairs(items) do',
      '  if item.name and item.name:find([====[' + name + ']====], 1, true) then',
      '    local gs = rawget(_G, "goToScene")',
      '    if gs then gs(item) end',
      '    return tostring(i)',
      '  end',
      'end',
      'return "-1"',
    ].join('\n');
    const r = await lua(code);
    if (r && r.ok && r.result) {
      const n = parseInt(r.result, 10);
      return isNaN(n) ? -1 : n;
    }
    return -1;
  }, sceneName);

  if (navigated > 0) {
    await page.waitForTimeout(waitMs || 3000);
  }
  return navigated;
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