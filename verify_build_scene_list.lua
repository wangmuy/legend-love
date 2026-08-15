-- verify_build_scene_list.lua 一次性核验脚本
-- 用真实 mmap_smap_handlers.lua 的 buildSceneList() + data_loader.lua parseJSON
-- 复现 MmapHandlers.list() 的用户可见编号，与 check_mmap_list.js 输出对比
package.path = "/home/woodfish/project/legend-love/game/engine-web/?.lua;" .. package.path
local ENGINE = "/home/woodfish/project/legend-love/game/engine-web"
dofile(ENGINE .. "/data_loader.lua")

local function loadJson(path)
    local f = io.open(path, "rb")
    if not f then error("cannot open " .. path) end
    local s = f:read("*a")
    f:close()
    return parseJSON(s)
end

-- 灌入 initDataSource（与 web_game_bridge 相同结构）
local ent = loadJson(ENGINE .. "/data-web/entrances.json")
local scn = loadJson(ENGINE .. "/data-web/scenes.json")
_G.initDataSource["entrances"] = ent["entrances"] or ent
_G.initDataSource["scenes"] = scn["scenes"] or scn

-- 加载真实处理器（buildSceneList 不调用 w()，无需 WebUI stub）
dofile(ENGINE .. "/mmap_smap_handlers.lua")

local items = buildSceneList()
local nameCount = {}
for _, item in ipairs(items) do
    nameCount[item.name] = (nameCount[item.name] or 0) + 1
end
local lines = {}
for i, item in ipairs(items) do
    local dn = item.name
    if nameCount[item.name] > 1 then
        dn = string.format("%s (%d,%d)", item.name, item.entry.mapX or 0, item.entry.mapY or 0)
    end
    lines[#lines + 1] = string.format("%d. %s  [sceneId=%s]", i, dn, item.sceneId)
end
print("共 " .. #items .. " 个可去场景")
for _, l in ipairs(lines) do print(l) end
