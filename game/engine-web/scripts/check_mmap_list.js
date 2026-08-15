#!/usr/bin/env node
// check_mmap_list.js
// 复刻 mmap_smap_handlers.lua 的 buildSceneList() + MmapHandlers.list()
// 生成大地图 `list` 命令下用户看到的固定场景编号表（按名称排序，顺序稳定）。
// 用途：将每个场景的固定编号写入攻略 quick_pass_game.md 的大地图提示小节。
const path = require("path");
const fs = require("fs");

const dataDir = path.join(__dirname, "..", "data-web");

function load(name) {
    const raw = JSON.parse(fs.readFileSync(path.join(dataDir, name), "utf8"));
    return raw;
}

function getEntrances() {
    const raw = load("entrances.json");
    return raw["entrances"] || raw;
}

function getScenesIndex() {
    const raw = load("scenes.json");
    const list = raw["scenes"] || raw;
    const index = {};
    for (const scene of list) {
        index[String(scene["代号"] ?? "")] = scene;
    }
    return index;
}

// 权威复刻：直接用项目自带的 fengari 运行真实 Lua table.sort（与游戏同实现）
// 生成 Lua 代码：建 items 表 → table.sort(items, function(a,b) return a.name < b.name end)
// → 返回排序后的原始索引序列，再由 JS 按该顺序重排。
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("fengari");

function luaSortByNames(sceneItems) {
    // 用长括号字符串 [=[...]=] 安全嵌入名称（名称中不可能包含 "]=]"）
    const defs = sceneItems
        .map((it, i) => `items[${i + 1}] = {name=[=[${it.name}]=], idx=${i + 1}}`)
        .join("\n");
    const code = `
local items = {}
${defs}
table.sort(items, function(a, b) return a.name < b.name end)
local out = {}
for i = 1, #items do out[i] = items[i].idx end
return table.concat(out, ",")
`;
    const L = lauxlib.luaL_newstate();
    lualib.luaL_openlibs(L);
    const ok = lauxlib.luaL_loadstring(L, to_luastring(code));
    if (ok !== lua.LUA_OK) {
        throw new Error("luaL_loadstring failed: " + to_jsstring(lua.lua_tostring(L, -1)));
    }
    if (lua.lua_pcall(L, 0, 1, 0) !== lua.LUA_OK) {
        throw new Error("lua_pcall failed: " + to_jsstring(lua.lua_tostring(L, -1)));
    }
    const result = to_jsstring(lua.lua_tostring(L, -1));
    lua.lua_close(L);
    const order = result.split(",").map(Number);
    if (order.length !== sceneItems.length) {
        throw new Error(`fengari sort returned ${order.length} items, expected ${sceneItems.length}`);
    }
    const sorted = order.map((idx) => sceneItems[idx - 1]);
    return sorted;
}

// 复刻 buildSceneList()
function buildSceneList() {
    const entrances = getEntrances();
    const scenes = getScenesIndex();
    const sceneItems = [];
    const seenIds = {};
    for (const entry of entrances) {
        const sceneId = String(entry.sceneId);
        if (!seenIds[sceneId]) {
            seenIds[sceneId] = true;
            const scene = scenes[sceneId];
            const name = (scene && scene["名称"]) || entry.name || "场景" + sceneId;
            sceneItems.push({ name, entry, sceneId, scene });
        }
    }
    // 用 fengari 运行真实 Lua table.sort（与游戏 mmap_smap_handlers.lua 同实现、同排序结果）
    return luaSortByNames(sceneItems);
}

// 复刻 list() 的显示（同名场景追加坐标）
function renderList(sceneItems) {
    const nameCount = {};
    for (const item of sceneItems) {
        nameCount[item.name] = (nameCount[item.name] || 0) + 1;
    }
    const lines = [];
    for (let i = 0; i < sceneItems.length; i++) {
        const item = sceneItems[i];
        let displayName = item.name;
        if (nameCount[item.name] > 1) {
            displayName = `${item.name} (${item.entry.mapX ?? 0},${item.entry.mapY ?? 0})`;
        }
        lines.push(`${i + 1}. ${displayName}  [sceneId=${item.sceneId}]`);
    }
    return lines;
}

const items = buildSceneList();
const lines = renderList(items);
console.log(`共 ${items.length} 个可去场景（95 入口去重后 ${items.length} 唯一）`);
console.log("════════════════════════════════════");
for (const line of lines) console.log(line);
