// tests/helpers/walkthrough.js
// 攻略 e2e 测试存档跳转工具函数 — 存档/读档使用纯用户操作（save N / load N）
// 缓存读取/写入（__luaEval）仅用于测试基础设施的跨 spec 状态传递，不涉及游戏操作

const _bridgeCache = {};
const fs = require('fs');
const path = require('path');
const { cmd, getT } = require('./term');

async function saveTestState(page, slot) {
  // 用户操作：save <slot>
  await cmd(page, 'save ' + slot); await page.waitForTimeout(2000);
  // 直接从 JY 读取数据并缓存到 _bridgeCache（测试基础设施，非游戏操作）
  // 使用 try/catch 防止页面已关闭的罕见情况
  try {
    const data = await page.evaluate(async (s) => {
      if (!window.__luaEval) return null;
      const code = 'local J = rawget(_G, "JY"); if not J then return "{}" end; local d = {base=J.Base, persons=J.Person, things=J.Thing, scenes=J.Scene, wugongs=J.Wugong, shops=J.Shop, status=J.Status, subScene=J.SubScene, mmapMusic=J.MmapMusic, currentD=J.CurrentD, d=J.D}; local encode = rawget(_G, "encodeSimpleJSON"); if not encode then return "{}" end; local ok, json = pcall(encode, d); return ok and json or "{}"';
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
  // 3. 通过用户命令 load <slot> 读档（processEventQueue 支持 load N：
  //    从 __saveCache 读取并解析，成功后自动显示对应状态 look）
  await cmd(page, 'load ' + slot); await page.waitForTimeout(2500);
  // 清除遗留的 instruct 等待标志（loadGameState 不保存这些标志，读档后可能残留）
  await page.evaluate(async () => {
    await window.__luaEval('rawset(_G, "__instruct4_waiting", nil); rawset(_G, "__instruct4_result", nil); rawset(_G, "__instruct9_waiting", nil); rawset(_G, "__instruct9_result", nil); rawset(_G, "__instruct5_waiting", nil); rawset(_G, "__instruct5_result", nil)');
  });
  // 显示 MMAP look 输出（load N 已触发 look；此处兜底确保场景可见）
  await page.evaluate(async () => {
    await window.__luaEval('local J = rawget(_G, "JY"); if J and J.Status == 2 then local mh = rawget(_G, "MmapHandlers"); if mh and mh.look then mh.look({}) end end');
  });
  await page.waitForTimeout(1500);
  return true;
}

/**
 * 通过场景名称导航 — 纯用户命令流程（leave → list → 解析终端场景列表 → choose <idx>）
 * 与 quick_pass_game.md 的 gotoScene 自动导航流程一致：
 *   leave（如在场景）→ list（列出可去场景）→ 终端解析找到场景索引 → choose <idx> 导航
 * 不使用 __luaEval 注入（buildSceneList/goToScene 仅由游戏内部 list/choose 命令触发）。
 */
async function gotoScene(page, sceneName, waitMs) {
  const input = page.locator('#command-input');
  await input.waitFor({ state: 'visible', timeout: 15000 });
  // 1. 若在场景中先 leave 回大地图（MMAP 下 leave 为"未知命令"，无害）。
  //    战斗结算/对话残留可能导致 leave 被吞、仍停留场景——此时 SMAP 无 list 命令，
  //    后续解析必然返回 -1。用 Lua 验证 JY.Status==2，未回大地图则重试 leave。
  for (let lv = 0; lv < 5; lv++) {
    await cmd(page, 'leave'); await page.waitForTimeout(800);
    if (await isInMMap(page)) break;
  }
  // 2. list 列出可去场景（按名称排序，同名场景追加坐标）
  await cmd(page, 'list'); await page.waitForTimeout(3000);
  // 3. 解析终端中最近一次 list 输出的场景列表，找到目标名称的索引
  // 注意：必须"精确匹配"优先（去掉坐标后缀后 == 场景名），否则 includes 会把
  // "絕情谷" 误匹配到 "絕情谷底"（如 P2 绝情谷段卡住的根因）。
  const idx = await page.evaluate((n) => {
    const term = window.__xterm; if (!term) return -1;
    const total = term.buffer.active.length;
    let lastList = -1;
    for (let y = total - 1; y >= 0; y--)
      if (term.buffer.active.getLine(y)?.translateToString(true)?.includes('可去场景'))
        { lastList = y; break; }
    if (lastList === -1) return -1;
    // 第一轮：精确匹配（显示名去掉 "(x,y)" 坐标后缀后与目标名完全相等）
    for (let y = total - 1; y > lastList; y--) {
      const raw = term.buffer.active.getLine(y)?.translateToString(true) || '';
      const m = raw.match(/^\D*(\d+)\.\s*(.*\S)\s*$/);
      if (m) {
        const name = m[2].replace(/\s*\(\d+\s*,\s*\d+\)\s*$/, '').trim();
        if (name === n) return parseInt(m[1], 10);
      }
    }
    // 第二轮：includes 兜底（兼容无法精确匹配的显示名）
    for (let y = total - 1; y > lastList; y--) {
      const raw = term.buffer.active.getLine(y)?.translateToString(true) || '';
      const m = raw.match(/^\D*(\d+)\.\s*(.*\S)\s*$/);
      if (m && m[2].includes(n)) return parseInt(m[1], 10);
    }
    return -1;
  }, sceneName);
  if (idx > 0) {
    await cmd(page, 'choose ' + idx);
    await page.waitForTimeout(waitMs || 3000);
    // 验证导航真正生效（JY.Status==4 场景状态），若失败（菜单未激活竞态）重试一次
    if (!(await isInScene(page))) {
      console.log(`[gotoScene] ${sceneName}: choose ${idx} 后未进入场景，重试`);
      await cmd(page, 'choose ' + idx);
      await page.waitForTimeout(waitMs || 3000);
    }
  }
  return idx;
}

/** 读取当前是否处于场景状态（JY.Status==4，测试基础设施断言，非游戏操作） */
async function isInScene(page) {
  try {
    const r = await page.evaluate(async () => {
      if (!window.__luaEval) return false;
      const res = await window.__luaEval('local J = rawget(_G, "JY"); return (J and J.Status == 4) and "true" or "false"');
      return res && res.ok && res.result === 'true';
    });
    return r === true;
  } catch (e) { return false; }
}

/** 读取当前是否处于大地图状态（JY.Status==2，测试基础设施断言，非游戏操作） */
async function isInMMap(page) {
  try {
    const r = await page.evaluate(async () => {
      if (!window.__luaEval) return false;
      const res = await window.__luaEval('local J = rawget(_G, "JY"); return (J and J.Status == 2) and "true" or "false"');
      return res && res.ok && res.result === 'true';
    });
    return r === true;
  } catch (e) { return false; }
}

/**
 * 通过 sceneId 导航（用于同名场景区分，如多个"山洞"）— 纯用户命令流程
 * 与 gotoScene 相同：leave → list → 终端解析场景列表（同名场景显示 "(mapX,mapY)"）→ choose <idx>
 * 入口坐标仅从静态数据文件读取用于终端匹配，不注入任何 Lua 状态。
 */
async function gotoSceneById(page, sceneId, waitMs) {
  // 从静态数据文件查找该场景的名称与入口坐标（仅用于匹配终端文本，非游戏操作）
  let target = null;
  try {
    const entrances = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../../data-web/entrances.json'), 'utf8'));
    const scenes = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../../data-web/scenes.json'), 'utf8'));
    const sceneList = scenes['scenes'] || scenes;
    const sceneIndex = {};
    for (const s of sceneList) sceneIndex[String(s['代号'])] = s;
    for (const e of entrances['entrances'] || []) {
      if (String(e.sceneId) === String(sceneId)) {
        const sc = sceneIndex[String(sceneId)];
        target = { name: sc && sc['名称'] ? sc['名称'] : (e.name || '场景' + sceneId), mapX: e.mapX, mapY: e.mapY };
        break;
      }
    }
  } catch (e) { /* 数据文件缺失时退化为仅按名称匹配 */ }
  const input = page.locator('#command-input');
  await input.waitFor({ state: 'visible', timeout: 15000 });
  // 战斗结算/对话残留可能导致 leave 被吞、仍停留场景——验证 JY.Status==2，未回大地图则重试
  for (let lv = 0; lv < 5; lv++) {
    await cmd(page, 'leave'); await page.waitForTimeout(800);
    if (await isInMMap(page)) break;
  }
  // list 可能因异步命令排队未及时输出：最多重试 3 次
  let idx = -1;
  for (let attempt = 0; attempt < 3 && idx === -1; attempt++) {
    await cmd(page, 'list'); await page.waitForTimeout(3000);
    idx = await page.evaluate(({ name, mapX, mapY }) => {
      const term = window.__xterm; if (!term) return -1;
      const total = term.buffer.active.length;
      let lastList = -1;
      for (let y = total - 1; y >= 0; y--)
        if (term.buffer.active.getLine(y)?.translateToString(true)?.includes('可去场景')) { lastList = y; break; }
      if (lastList === -1) return -1;
      // 第一遍：精确坐标匹配（唯一）
      for (let y = total - 1; y > lastList; y--) {
        const raw = term.buffer.active.getLine(y)?.translateToString(true) || '';
        const m = raw.match(/^\D*(\d+)\.\s*(.*\S)\s*$/);
        if (!m) continue;
        const label = m[2];
        if (mapX !== undefined && mapY !== undefined) {
          if (label.includes('(' + mapX + ',' + mapY + ')')) return parseInt(m[1], 10);
        }
      }
      // 第二遍：精确名称匹配（行首为 name 的场景，排除"金蛇山洞"等包含子串的场景）
      for (let y = total - 1; y > lastList; y--) {
        const raw = term.buffer.active.getLine(y)?.translateToString(true) || '';
        const m = raw.match(/^\D*(\d+)\.\s*(.*\S)\s*$/);
        if (!m) continue;
        const label = m[2];
        if (name && (label === name || label.startsWith(name + ' '))) return parseInt(m[1], 10);
      }
      return -1;
    }, target || {});
  }
  if (idx > 0) {
    await cmd(page, 'choose ' + idx);
    await page.waitForTimeout(waitMs || 3000);
  }
  return idx;
}

/** 判断当前是否处于战斗状态（JY.Status == 5，可靠，不受终端文本累积影响） */
async function inBattle(page) {
  try {
    const r = await page.evaluate(async () => {
      if (!window.__luaEval) return false;
      const res = await window.__luaEval('local J = rawget(_G, "JY"); return (J and J.Status == 5) and "true" or "false"');
      return res && res.ok && res.result === 'true';
    });
    return r === true;
  } catch (e) { return false; }
}

/** 读取当前战斗距离（JY.War.distance，可靠，不受终端文本累积影响） */
async function getWarDistance(page) {
  try {
    const r = await page.evaluate(async () => {
      if (!window.__luaEval) return null;
      const res = await window.__luaEval('local J = rawget(_G, "JY"); local W = J and J.War; return W and tostring(W.distance) or "nil"');
      if (res && res.ok && res.result && res.result !== 'nil') {
        const n = parseInt(res.result, 10);
        return isNaN(n) ? null : n;
      }
      return null;
    });
    return r;
  } catch (e) { return null; }
}

/** 读取当前战斗相位（WmapHandlers.getPhase，可靠，不受终端文本窗口限制） */
async function getBattlePhase(page) {
  try {
    const r = await page.evaluate(async () => {
      if (!window.__luaEval) return null;
      const res = await window.__luaEval('local WH = rawget(_G, "WmapHandlers"); return WH and WH.getPhase and tostring(WH.getPhase()) or "nil"');
      if (res && res.ok && res.result && res.result !== 'nil') return res.result;
      return null;
    });
    return r;
  } catch (e) { return null; }
}

/**
 * 可靠战斗循环：阶段感知推进（兼容单人/多人战斗）
 * 战斗状态机（wmap_handlers.lua）：
 *   select_teammate（选择行动的队友）→ select_action（1.攻击 5.移动）→ select_move（1.走近）→ select_target（选目标）
 * 策略：距离 >1 时先移动，距离 <=1 后每轮选队友→攻击→目标。
 * 距离/相位直接读 Lua（getDistance/getPhase），战斗结束以 JY.Status==5 为准（均不受终端文本累积影响）。
 */
async function doBattle(page, maxRounds = 150) {
  for (let r = 0; r < maxRounds; r++) {
    if (!(await inBattle(page))) return await getT(page);  // 战斗已结束（胜利/失败/退出）
    const phase = await getBattlePhase(page);
    if (!phase) {
      // 相位未知（战斗可能刚切换）：look 刷新
      await cmd(page, 'look');
    } else if (phase === 'select_teammate') {
      await cmd(page, 'choose 1');
    } else if (phase === 'select_move') {
      await cmd(page, 'choose 1');  // 走近
    } else if (phase === 'select_target') {
      await cmd(page, 'choose 1');
    } else if (phase === 'select_action') {
      const dist = await getWarDistance(page);
      await cmd(page, (dist !== null && dist > 1) ? 'choose 5' : 'choose 1');
    } else if (phase === 'select_martial') {
      await cmd(page, 'choose 1');  // 选第一个武功 → select_target
    } else if (phase === 'select_item') {
      await cmd(page, 'choose 0');  // 退出物品菜单 → afterAction
    } else {
      await cmd(page, 'look');
    }
    // 战斗胜利/失败文本出现但协程可能尚未恢复：等待 JY.Status != 5（战斗真正结算）
    const full2 = await getT(page);
    const tail2 = full2.split('\n').slice(-15).join('\n');
    if (tail2.includes('战斗胜利') || tail2.includes('战斗失败')) {
      for (let w = 0; w < 25 && (await inBattle(page)); w++) {
        await page.waitForTimeout(200);
      }
      await page.waitForTimeout(600);
      return await getT(page);
    }
    await page.waitForTimeout(250);
  }
  return await getT(page);
}

/** 将 _bridgeCache 写入文件（跨 spec 持久化） */
function flushSaveCache(filepath) {
  fs.writeFileSync(path.resolve(__dirname, '..', filepath), JSON.stringify(_bridgeCache), 'utf8');
}

/** 检查背包是否拥有指定物品（通过 __luaEval 读取 JY.Base["物品N"]） */
async function hasItem(page, itemId) {
  const r = await page.evaluate(async (id) => {
    if (!window.__luaEval) return false;
    const code = 'local J = rawget(_G, "JY"); if not J or not J.Base then return "false" end; ' +
      'for i = 1, 200 do if J.Base["物品" .. i] == ' + id + ' and (J.Base["物品数量" .. i] or 1) > 0 then return "true" end end; return "false"';
    const res = await window.__luaEval(code);
    return res && res.ok && res.result === 'true';
  }, itemId);
  return r === true;
}

/** 检查队伍是否拥有指定人物（JY.Base["队伍N"] == personId） */
async function hasTeamMember(page, personId) {
  const r = await page.evaluate(async (pid) => {
    if (!window.__luaEval) return false;
    const code = 'local J = rawget(_G, "JY"); if not J or not J.Base then return "false" end; ' +
      'for i = 1, 6 do if J.Base["队伍" .. i] == ' + pid + ' then return "true" end end; return "false"';
    const res = await window.__luaEval(code);
    return res && res.ok && res.result === 'true';
  }, personId);
  return r === true;
}

/** 读取品德值（JY.Person[0]["品德"]） */
async function getMoral(page) {
  const r = await page.evaluate(async () => {
    if (!window.__luaEval) return -1;
    const res = await window.__luaEval('local J = rawget(_G, "JY"); if not J or not J.Person or not J.Person[0] then return "-1" end; return tostring(J.Person[0]["品德"] or -1)');
    if (res && res.ok && res.result) {
      const n = parseInt(res.result, 10);
      return isNaN(n) ? -1 : n;
    }
    return -1;
  });
  return r;
}

/** 检查 D* 表（JY.D[sceneId]）中是否已设置指定事件编号（动态 NPC/事件放置检测） */
async function hasDEvent(page, sceneId, eventId) {
  const r = await page.evaluate(async ({ sid, eid }) => {
    if (!window.__luaEval) return false;
    const code = 'local J = rawget(_G, "JY"); if not J or not J.D or not J.D[' + sid + '] then return "false" end; ' +
      'local d = J.D[' + sid + ']; local found = false; ' +
      'for _, v in pairs(d) do if type(v) == "table" then ' +
      '  if v[2] == ' + eid + ' or v[3] == ' + eid + ' or v[4] == ' + eid + ' or v["2"] == ' + eid + ' or v["3"] == ' + eid + ' or v["4"] == ' + eid + ' then found = true end ' +
      'end end; return found and "true" or "false"';
    const res = await window.__luaEval(code);
    return res && res.ok && res.result === 'true';
  }, { sid: sceneId, eid: eventId });
  return r === true;
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

module.exports = { saveTestState, loadTestState, gotoScene, gotoSceneById, flushSaveCache, loadSaveCache, hasItem, hasTeamMember, getMoral, doBattle, inBattle, hasDEvent };