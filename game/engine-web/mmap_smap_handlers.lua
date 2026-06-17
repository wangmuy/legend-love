-- mmap_smap_handlers.lua
-- 大地图 (MMAP) 和场景 (SMAP) 文字交互命令

local MmapHandlers = {}
local SmapHandlers = {}
local g = rawget

local function w(text) local w = g(_G, "WebUI"); if w then w.write(text) end end
local function wt(text) local w = g(_G, "WebUI"); if w then w.title(text) end end
local function ws() local w = g(_G, "WebUI"); if w then w.separator() end end

-- 场景描述模板
local sceneTemplates = {
    inn = "这是一间客栈，店小二正在忙碌地招呼客人。柜台后面摆满了酒坛。",
    house = "一间普通的民居，屋里陈设简单但整洁。",
    cave = "洞口阴暗潮湿，往里看去一片漆黑。",
    school = "一座气派的大门，门匾上写着「%s」。",
    shop = "店里货架上摆满了各种商品。",
    forest = "树木茂密，阳光透过树叶洒下斑驳的光影。",
}

local function getSceneTemplate(scene)
    local stype = scene["类型"] or ""
    local name = scene["名称"] or ""
    local template = sceneTemplates[stype]
    if template then
        if stype == "school" then
            return string.format(template, name)
        end
        return template
    end
    if name:find("客栈") then return sceneTemplates.inn end
    if name:find("居") or name:find("庄") or name:find("阁") then return sceneTemplates.house end
    if name:find("洞") then return sceneTemplates.cave end
    if name:find("派") or name:find("教") or name:find("门") then return string.format(sceneTemplates.school, name) end
    if name:find("店") or name:find("铺") then return sceneTemplates.shop end
    if name:find("林") or name:find("岛") or name:find("崖") then return sceneTemplates.forest end
    return "这是一个普通的场景，似乎没有什么特别之处。"
end

local function getEntrances()
    local cache = g(_G, "dataCache")
    if not cache then return nil end
    local raw = cache["entrances"]
    if not raw then return nil end
    local list = raw["entrances"] or raw
    if type(list) ~= "table" then return nil end
    return list
end

local function getScenes()
    local cache = g(_G, "dataCache")
    if not cache then return nil end
    local raw = cache["scenes"]
    if not raw then return nil end
    local list = raw["scenes"] or raw
    if type(list) ~= "table" then return nil end
    local index = {}
    for _, scene in ipairs(list) do
        local sid = tostring(scene["代号"] or "")
        index[sid] = scene
    end
    return index
end

local function goToScene(target)
    local JY = g(_G, "JY")
    if not JY then JY = {}; rawset(_G, "JY", JY) end
    if not JY.Base then JY.Base = {} end
    JY.Base["人X1"] = target.entry.mapX
    JY.Base["人Y1"] = target.entry.mapY
    if not JY.Base["人X1"] then JY.Base["人X1"] = 0 end
    JY.SubScene = tonumber(target.sceneId)
    JY.Status = 4  -- GAME_SMAP

    w(string.format("你来到了 %s。\n", target.name))
    SmapHandlers.look({})
end

local function buildSceneList()
    local entrances = getEntrances()
    local scenes = getScenes()
    if not entrances then return nil end

    local sceneItems = {}
    local seenIds = {}
    for _, entry in ipairs(entrances) do
        local sceneId = tostring(entry.sceneId)
        if not seenIds[sceneId] then
            seenIds[sceneId] = true
            local scene = scenes and scenes[sceneId]
            local name = scene and scene["名称"] or (entry.name or "场景" .. sceneId)
            table.insert(sceneItems, {name=name, entry=entry, sceneId=sceneId, scene=scene})
        end
    end
    table.sort(sceneItems, function(a, b) return a.name < b.name end)
    return sceneItems
end

function MmapHandlers.list(args)
    local sceneItems = buildSceneList()
    if not sceneItems or #sceneItems == 0 then
        w("没有可去的场景")
        return
    end

    local CE = g(_G, "CommandEngine")
    if not CE then
        w("错误：命令引擎不可用")
        return
    end

    CE.showMenu(sceneItems, "可去场景（选择序号前往）", function(idx)
        if idx and idx > 0 then
            local target = sceneItems[idx]
            if target then goToScene(target) end
        end
    end)
end

function MmapHandlers.go(args)
    local targetName = args and args[1]
    if not targetName then
        local sceneItems = buildSceneList()
        if not sceneItems or #sceneItems == 0 then
            w("没有可去的场景")
            return
        end

        local CE = g(_G, "CommandEngine")
        if not CE then
            w("错误：命令引擎不可用")
            return
        end

        CE.showMenu(sceneItems, "可去场景（选择序号前往）", function(idx)
            if idx and idx > 0 then
                local target = sceneItems[idx]
                if target then goToScene(target) end
            end
        end)
        return
    end

    local entrances = getEntrances()
    local scenes = getScenes()
    if not entrances then
        w("无法获取场景数据")
        return
    end
    
    local found = nil
    for _, entry in ipairs(entrances) do
        local sceneId = tostring(entry.sceneId)
        local scene = scenes and scenes[sceneId]
        local name = scene and scene["名称"] or (entry.name or "")
        if name == targetName then
            found = {entry=entry, name=name, sceneId=sceneId, scene=scene}
            break
        end
    end
    
    if not found then
        for _, entry in ipairs(entrances) do
            local sceneId = tostring(entry.sceneId)
            local scene = scenes and scenes[sceneId]
            local name = scene and scene["名称"] or (entry.name or "")
            if name:find(targetName, 1, true) then
                if not found then
                    found = {entry=entry, name=name, sceneId=sceneId, scene=scene}
                else
                    w(string.format("找到多个匹配场景: %s, %s 等", found.name, name))
                    w("请使用更精确的名称")
                    return
                end
            end
        end
    end
    
    if not found then
        w(string.format("未找到场景: %s", targetName))
        w("输入 list 查看所有可去场景")
        return
    end

    goToScene(found)
end

function MmapHandlers.look(args)
    local JY = g(_G, "JY")
    if not JY then JY = {}; rawset(_G, "JY", JY) end
    if not JY.Base then JY.Base = {} end
    local x = JY.Base["人X1"] or 0
    local y = JY.Base["人Y1"] or 0
    
    -- 方位信息（原 where 的内容）
    local direction = ""
    if y < 100 then direction = "北方"
    elseif y < 200 then direction = "中原"
    else direction = "南方" end
    
    local relX = x - 364
    local relY = y - 284
    
    wt("当前位置")
    w(string.format("坐标: (%d, %d)", x, y))
    w(string.format("方位: %s", direction))
    w(string.format("相对中心: %s%d, %s%d",
        relX >= 0 and "东" or "西", math.abs(relX),
        relY >= 0 and "南" or "北", math.abs(relY)))
    ws()
    
    local entrances = getEntrances()
    if not entrances then return end
    
    local scenes = getScenes()
    local nearby = {}
    
    for _, entry in ipairs(entrances) do
        local dx = (entry.mapX or 0) - x
        local dy = (entry.mapY or 0) - y
        local dist = math.floor(math.sqrt(dx*dx + dy*dy))
        if dist <= 50 and dist > 0 then
            local sceneId = tostring(entry.sceneId)
            local scene = scenes and scenes[sceneId]
            local name = scene and scene["名称"] or (entry.name or "场景" .. sceneId)
            table.insert(nearby, string.format("  %s (%d步)", name, dist))
        end
    end
    
    if #nearby > 0 then
        table.sort(nearby)
        w("附近场景：")
        for _, item in ipairs(nearby) do
            w(item)
        end
    else
        w("四周一片荒凉，没有什么特别的。")
    end
    w("输入 list 查看可去场景，quit 退出游戏")
end

function MmapHandlers.quit(args)
    local AsyncDialog = g(_G, "AsyncDialog")
    if not AsyncDialog then
        w("错误：对话框系统不可用")
        return
    end
    w("确定退出吗？未保存的进度将丢失。输入 choose 1 确认，choose 2 取消")
    AsyncDialog.getInstance():showYesNo("确定退出吗？未保存的进度将丢失。", function(confirmed)
        if confirmed then
            local returnFn = g(_G, "returnToStartMenu")
            if returnFn then returnFn() end
        else
            -- 取消退出：重新显示大地图信息和提示
            w("已取消。")
            MmapHandlers.look({})
        end
    end)
end

function MmapHandlers.where(args)
    local JY = g(_G, "JY")
    if not JY then JY = {}; rawset(_G, "JY", JY) end
    if not JY.Base then JY.Base = {} end
    local x = JY.Base["人X1"] or 0
    local y = JY.Base["人Y1"] or 0
    
    local direction = ""
    if y < 100 then direction = "北方"
    elseif y < 200 then direction = "中原"
    else direction = "南方" end
    
    wt("当前位置")
    w(string.format("坐标: (%d, %d)", x, y))
    w(string.format("方位: %s", direction))
    
    local relX = x - 364
    local relY = y - 284
    w(string.format("相对中心: %s%d, %s%d",
        relX >= 0 and "东" or "西", math.abs(relX),
        relY >= 0 and "南" or "北", math.abs(relY)))
end

local function getCharsIndex()
    local cache = g(_G, "dataCache")
    if not cache then return nil end
    local raw = cache["chars"]
    if not raw then return nil end
    local list = raw["chars"] or raw
    if type(list) ~= "table" then return nil end
    local index = {}
    for _, char in ipairs(list) do
        local cid = tostring(char["代号"] or "")
        index[cid] = char
    end
    return index
end

-- SMAP 命令

function SmapHandlers.look(args)
    local targetName = args and args[1]
    local JY = g(_G, "JY")
    if not JY then JY = {}; rawset(_G, "JY", JY) end
    local sceneId = tostring(JY.SubScene or 0)
    local scenes = getScenes()
    local scene = scenes and scenes[sceneId]
    
    if not scene then
        w("无法获取场景信息")
        return
    end

    -- 有参 look：查看具体对象（NPC 或物品）
    if targetName then
        local charsIndex = getCharsIndex()
        local npcs = scene["NPC"]
        if npcs then
            for _, npc in ipairs(npcs) do
                local charId = tostring(npc["代号"] or npc)
                local char = charsIndex and charsIndex[charId]
                local charName = char and char["姓名"]
                if charName == targetName then
                    if not _G.isNpcPresent(sceneId, charId) then
                        w(charName .. " 不在这里。")
                        return
                    end
                    w("你看着 " .. charName .. "。")
                    if char and char["描述"] then
                        w(char["描述"])
                    else
                        w("看起来是个普通人。")
                    end
                    return
                end
            end
        end
        local items = scene["物品"]
        if items then
            for _, item in ipairs(items) do
                local itemId = tostring(item["代号"] or "")
                local itemName = getItemName(itemId) or item["名称"]
                if itemName == targetName then
                    if not _G.itemAvailable(sceneId, itemId) then
                        w(itemName .. " 已经被拿走了。")
                        return
                    end
                    w("你看着 " .. itemName .. "。")
                    local itemsData = g(_G, "dataCache")
                    if itemsData then
                        local itemDef = itemsData["items"] and itemsData["items"][itemId]
                        if itemDef and itemDef["描述"] then
                            w(itemDef["描述"])
                        else
                            w("看起来是个普通的物品。")
                        end
                    end
                    return
                end
            end
        end
        w("这里没有叫 " .. targetName .. " 的。")
        return
    end

    -- 无参 look：场景总体描述
    local name = scene["名称"] or "未知场景"
    
    wt(name)
    w(getSceneTemplate(scene))
    ws()
    
    -- NPC 列表（过滤已离场）
    local hasVisibleNpc = false
    local npcs = scene["NPC"]
    if npcs and #npcs > 0 then
        local charsIndex = getCharsIndex()
        local npcNames = {}
        for _, npc in ipairs(npcs) do
            local charId = tostring(npc["代号"] or npc)
            if _G.isNpcPresent(sceneId, charId) then
                local char = charsIndex and charsIndex[charId]
                local charName = char and char["姓名"] or ("NPC?" .. charId)
                table.insert(npcNames, charName)
                hasVisibleNpc = true
            end
        end
        if #npcNames > 0 then
            w("NPC: " .. table.concat(npcNames, ", "))
        end
    end
    if not hasVisibleNpc then
        w("这里空无一人。")
    end
    
    -- 物品列表（过滤已拾取）
    local items = scene["物品"]
    if items and #items > 0 then
        local itemNames = {}
        for _, item in ipairs(items) do
            local itemId = tostring(item["代号"] or "")
            if _G.itemAvailable(sceneId, itemId) then
                local itemName = getItemName(itemId) or item["名称"]
                if itemName then table.insert(itemNames, itemName) end
            end
        end
        if #itemNames > 0 then
            w("物品: " .. table.concat(itemNames, ", "))
        end
    end
    
    local exits = scene["出口"]
    if exits and #exits > 0 then
        local exitDirs = {}
        for _, exit in ipairs(exits) do
            local targetSceneId = tostring(exit["目标场景"] or "")
            local targetScene = scenes and scenes[targetSceneId]
            local targetName = targetScene and targetScene["名称"] or "?"
            table.insert(exitDirs, targetName)
        end
        w("出口: " .. table.concat(exitDirs, ", "))
    end
    
    w("输入 exits 查看出口详情，leave 回到大地图，talk 与 NPC 对话")
end

function SmapHandlers.exits(args)
    local JY = g(_G, "JY")
    if not JY then JY = {}; rawset(_G, "JY", JY) end
    local sceneId = tostring(JY.SubScene or 0)
    local scenes = getScenes()
    local scene = scenes and scenes[sceneId]
    
    if not scene or not scene["出口"] or #scene["出口"] == 0 then
        w("此场景没有出口")
        return
    end
    
    wt("出口")
    for _, exit in ipairs(scene["出口"]) do
        local targetSceneId = tostring(exit["目标场景"] or "")
        local targetScene = scenes and scenes[targetSceneId]
        local targetName = targetScene and targetScene["名称"] or "场景" .. targetSceneId
        w(string.format("%d. %s", _, targetName))
    end
end

function SmapHandlers.leave(args)
    local JY = g(_G, "JY")
    if not JY then JY = {}; rawset(_G, "JY", JY) end
    JY.Status = 2  -- GAME_MMAP
    w("你离开了当前场景，回到了大地图。\n")
    MmapHandlers.look({})
end

function SmapHandlers.go(args)
    local dir = args and args[1]
    if not dir then
        SmapHandlers.exits({})
        return
    end
    
    local JY = g(_G, "JY")
    if not JY then JY = {}; rawset(_G, "JY", JY) end
    local sceneId = tostring(JY.SubScene or 0)
    local scenes = getScenes()
    local scene = scenes and scenes[sceneId]
    
    if not scene or not scene["出口"] or #scene["出口"] == 0 then
        w("此场景没有出口")
        return
    end
    
    local n = tonumber(dir)
    if n and n >= 1 and n <= #scene["出口"] then
        local exit = scene["出口"][n]
        local targetSceneId = exit["目标场景"]
        if targetSceneId then
            JY.SubScene = targetSceneId
            local targetScene = scenes and scenes[tostring(targetSceneId)]
            if targetScene then
                w(string.format("进入了 %s。\n", targetScene["名称"]))
                SmapHandlers.look({})
            else
                JY.Status = 2  -- GAME_MMAP
                w("你回到了大地图。\n")
                MmapHandlers.look({})
            end
        end
        return
    end
    
    w(string.format("未找到出口: %s", dir))
    w("输入 exits 查看可用出口")
end

-- ============================================================
-- Slice 4: 场景交互
-- ============================================================

-- 场景状态（供所有子 change 使用）
local sceneState = {}
local function getSceneState(sceneId)
    local ss = g(_G, "sceneState")
    if not ss then ss = {}; rawset(_G, "sceneState", ss) end
    if not ss[sceneId] then ss[sceneId] = { npc = {}, items = {} } end
    return ss[sceneId]
end

function _G.setNpcPresent(sceneId, charId, present)
    local s = getSceneState(sceneId)
    s.npc[tostring(charId)] = { present = present }
end

function _G.isNpcPresent(sceneId, charId)
    local s = getSceneState(sceneId)
    local state = s.npc[tostring(charId)]
    return state == nil or state.present
end

function _G.setItemCount(sceneId, itemId, count)
    local s = getSceneState(sceneId)
    s.items[tostring(itemId)] = { count = count }
end

function _G.getItemCount(sceneId, itemId)
    local s = getSceneState(sceneId)
    local state = s.items[tostring(itemId)]
    return state and state.count or 1
end

function _G.itemAvailable(sceneId, itemId)
    return _G.getItemCount(sceneId, itemId) > 0
end

-- 查找角色名称（从 dataCache.chars）
local function getCharName(charId)
    local cache = g(_G, "dataCache")
    if not cache then return nil end
    local chars = cache["chars"]
    if not chars then return nil end
    local list = chars["chars"] or chars
    if type(list) ~= "table" then return nil end
    for _, c in ipairs(list) do
        if type(c) == "table" and tostring(c["代号"]) == tostring(charId) then
            return c["姓名"]
        end
    end
    return nil
end

-- 查找物品名称（从 dataCache.items）
local function getItemName(itemId)
    local cache = g(_G, "dataCache")
    if not cache then return nil end
    local items = cache["items"]
    if not items then return nil end
    local list = items["items"] or items
    if type(list) ~= "table" then return nil end
    for _, it in ipairs(list) do
        if type(it) == "table" and tostring(it["代号"]) == tostring(itemId) then
            return it["名称"]
        end
    end
    return nil
end

-- talk 命令
function SmapHandlers.talk(args)
    local targetName = args and args[1]
    if not targetName then
        w("用法: talk <NPC名>")
        return
    end

    local JY = g(_G, "JY")
    if not JY then JY = {}; rawset(_G, "JY", JY) end
    local sceneId = tostring(JY.SubScene or 0)
    local scenes = g(_G, "getScenes")
    if not scenes then scenes = getScenes end
    local scene = scenes and scenes(sceneId)

    if not scene then
        w("无法获取场景信息")
        return
    end

    local npcs = scene["NPC"]
    if not npcs or #npcs == 0 then
        w("此场景没有可以对话的 NPC")
        return
    end

    -- 查找 NPC
    for _, npc in ipairs(npcs) do
        local charId = tostring(npc["代号"] or "")
        local charName = getCharName(charId)
        if charName == targetName then
            -- 检查状态
            if not _G.isNpcPresent(sceneId, charId) then
                w(charName .. " 不在这里。")
                return
            end
            -- 获取事件 ID
            local eventId = npc["事件编号"] or npc["触发事件"] or 0
            if tonumber(eventId) == 0 then
                w(charName .. " 似乎不想说话。")
                return
            end
            -- 执行事件
            w("你与 " .. charName .. " 交谈。")
            local EventExecutor = g(_G, "EventExecutor")
            if EventExecutor then
                EventExecutor.startEvent(tonumber(eventId), 0, function()
                    w("交谈结束。")
                    SmapHandlers.look({})
                end)
            end
            return
        end
    end

    w("这里没有叫 " .. targetName .. " 的 NPC。")
end

-- take 命令
function SmapHandlers.take(args)
    local itemName = args and args[1]
    if not itemName then
        w("用法: take <物品名>")
        return
    end

    local JY = g(_G, "JY")
    if not JY then JY = {}; rawset(_G, "JY", JY) end
    local sceneId = tostring(JY.SubScene or 0)
    local scenes = g(_G, "getScenes")
    if not scenes then scenes = getScenes end
    local scene = scenes and scenes(sceneId)

    if not scene then
        w("无法获取场景信息")
        return
    end

    local items = scene["物品"]
    if not items or #items == 0 then
        w("此场景没有可拾取的物品")
        return
    end

    for _, item in ipairs(items) do
        local itemId = tostring(item["代号"] or "")
        local name = getItemName(itemId) or item["名称"]
        if name == itemName then
            if not _G.itemAvailable(sceneId, itemId) then
                w(name .. " 已经被拿走了。")
                return
            end
            -- 添加到背包
            JY.Base = JY.Base or {}
            for i = 1, 30 do
                if not JY.Base["物品" .. i] or JY.Base["物品" .. i] == 0 then
                    JY.Base["物品" .. i] = tonumber(itemId) or 0
                    JY.Base["物品数量" .. i] = 1
                    break
                end
            end
            _G.setItemCount(sceneId, itemId, 0)
            w("你获得了 " .. name .. "。")
            return
        end
    end

    w("这里没有叫 " .. itemName .. " 的物品。")
end

-- give 命令
function SmapHandlers.give(args)
    local itemName = args and args[1]
    local npcName = args and args[2]
    if not itemName or not npcName then
        w("用法: give <物品名> <NPC名>")
        return
    end

    local JY = g(_G, "JY")
    if not JY then JY = {}; rawset(_G, "JY", JY) end
    local sceneId = tostring(JY.SubScene or 0)

    -- 查找背包中的物品
    local foundSlot = nil
    JY.Base = JY.Base or {}
    for i = 1, 30 do
        local id = JY.Base["物品" .. i]
        if id and id ~= 0 then
            local name = getItemName(tostring(id))
            if name == itemName then
                foundSlot = i
                break
            end
        end
    end

    if not foundSlot then
        w("你身上没有 " .. itemName .. "。")
        return
    end

    -- 检查 NPC
    local scenes = g(_G, "getScenes")
    if not scenes then scenes = getScenes end
    local scene = scenes and scenes(sceneId)
    local foundNpc = false
    if scene and scene["NPC"] then
        for _, npc in ipairs(scene["NPC"]) do
            local charId = tostring(npc["代号"] or "")
            if getCharName(charId) == npcName and _G.isNpcPresent(sceneId, charId) then
                foundNpc = true
                break
            end
        end
    end

    if not foundNpc then
        w("这里没有叫 " .. npcName .. " 的 NPC。")
        return
    end

    -- 从背包移除
    JY.Base["物品" .. foundSlot] = 0
    JY.Base["物品数量" .. foundSlot] = 0
    w("你将 " .. itemName .. " 交给了 " .. npcName .. "。")
end

rawset(_G, "MmapHandlers", MmapHandlers)
rawset(_G, "SmapHandlers", SmapHandlers)
