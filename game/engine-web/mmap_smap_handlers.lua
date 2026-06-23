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
    local cache = g(_G, "initDataSource")
    if not cache then return nil end
    local raw = cache["entrances"]
    if not raw then return nil end
    local list = raw["entrances"] or raw
    if type(list) ~= "table" then return nil end
    return list
end

local function getScenes()
    local cache = g(_G, "initDataSource")
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
    local cache = g(_G, "initDataSource")
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
-- 场景交互对象列表（由 look 填充，供 choose 使用）
local smapEntityList = {}

function SmapHandlers.look(args)
    local JY = g(_G, "JY")
    if not JY then JY = {}; rawset(_G, "JY", JY) end
    local sceneId = tostring(JY.SubScene or 0)
    local scenes = getScenes()
    local scene = scenes and scenes[sceneId]
    
    if not scene then
        w("无法获取场景信息")
        return
    end

    local name = scene["名称"] or "未知场景"
    
    wt(name)
    w(getSceneTemplate(scene))
    ws()
    
    -- 构建交互对象列表（NPC → 物品 → 出口）
    local entityIndex = 0
    smapEntityList = {}
    
    -- NPC 列表 + 交互对象（宝箱/柜子等 oldevent 触发器）
    local npcs = scene["NPC"]
    if npcs and #npcs > 0 then
        local charsIndex = getCharsIndex()
        for _, npc in ipairs(npcs) do
            local charIdStr = tostring(npc["代号"] or npc)
            local npcName = npc["名称"] or "?"
            local isEventTrigger = npcName and npcName:match("^oldevent_")
            if isEventTrigger or _G.isNpcPresent(sceneId, charIdStr) then
                if isEventTrigger then
                    -- 交互对象（宝箱/柜子等），检查是否已被触发
                    -- 优先检查 D* 数据（instruct_3/SetD 标记），其次 eventConsumed 后备
                    -- 注意：必须用 rawget 访问 _G，因为 setmetatable(_G, {__index=error})
                    local eventId = npc["事件编号"] or 0
                    local eid = tonumber(eventId) or 0
                    local eventOff = false
                    local ec = rawget(_G, "eventConsumed")
                    if ec then
                        ec = ec[sceneId] and ec[sceneId][tostring(eventId)]
                    end
                    if ec then
                        eventOff = true
                    else
                        local GetD = rawget(_G, "GetD")
                        if GetD then
                            local ok, val = pcall(GetD, sceneId, eid, 7)
                            if ok and tonumber(val) ~= 0 then eventOff = true end
                        end
                    end
                    if not eventOff then
                        entityIndex = entityIndex + 1
                        smapEntityList[entityIndex] = { type = "event_trigger", eventId = tonumber(eventId), charId = charIdStr, name = npcName, npcData = npc }
                        w(string.format("%d. 搜索", entityIndex))
                    end
                else
                    local char = charsIndex and charsIndex[charIdStr]
                    local displayName = npcName or (char and char["姓名"]) or ("NPC?" .. charIdStr)
                    entityIndex = entityIndex + 1
                    smapEntityList[entityIndex] = { type = "npc", charId = charIdStr, name = displayName, npcData = npc }
                    w(string.format("%d. %s", entityIndex, displayName))
                end
            end
        end
    end
    
    -- 物品列表
    local items = scene["物品"]
    if items and #items > 0 then
        for _, item in ipairs(items) do
            local itemIdStr = tostring(item["代号"] or "")
            if _G.itemAvailable(sceneId, itemIdStr) then
                local itemName = getItemName(itemIdStr) or item["名称"]
                entityIndex = entityIndex + 1
                smapEntityList[entityIndex] = { type = "item", itemId = itemIdStr, name = itemName }
                w(string.format("%d. %s", entityIndex, itemName))
            end
        end
    end
    
    -- 出口列表
    local exits = scene["出口"]
    if exits and #exits > 0 then
        for _, exit in ipairs(exits) do
            local targetSceneId = tostring(exit["目标场景"] or "")
            local targetScene = scenes and scenes[targetSceneId]
            local targetName = targetScene and targetScene["名称"] or "?"
            entityIndex = entityIndex + 1
            smapEntityList[entityIndex] = { type = "exit", targetSceneId = targetSceneId, name = targetName }
            w(string.format("%d. → %s", entityIndex, targetName))
        end
    end
    
    if entityIndex == 0 then
        w("这里什么都没有。")
        return
    end
    
    w("输入 choose <编号> 选择交互对象")
end

-- SMAP choose 处理（由 CommandEngine 调度或 processEventQueue 调用）
function SmapHandlers.chooseInteraction(idx)
    if idx < 1 or idx > #smapEntityList then
        w("无效的选择。")
        return
    end
    
    local ent = smapEntityList[idx]
    if not ent then
        w("无效的选择。")
        return
    end
    
    local JY = g(_G, "JY")
    if not JY then JY = {}; rawset(_G, "JY", JY) end
    local sceneId = tostring(JY.SubScene or 0)
    
    if ent.type == "npc" then
        -- NPC 子菜单（与原版一致：对话，可查看人物信息，如有事件则触发）
        local CE = g(_G, "CommandEngine")
        if CE then
            CE.showMenu(
                { {name="对话"}, {name="查看"} },
                ent.name,
                function(actionIdx)
                    if actionIdx == 1 then
                        -- 对话
                        smapNpcTalk(sceneId, ent)
                    elseif actionIdx == 2 then
                        -- 查看（仅显示人物基本信息，不添加原版没有的交互）
                        local charsIndex = getCharsIndex()
                        local char = charsIndex and charsIndex[ent.charId]
                        if char then
                            w(ent.name)
                            if char["描述"] then w(char["描述"]) end
                        end
                        SmapHandlers.look({})
                    end
                end
            )
        end
    elseif ent.type == "item" then
        -- 物品子菜单
        local CE = g(_G, "CommandEngine")
        if CE then
            CE.showMenu(
                { {name="拾取"}, {name="查看"} },
                ent.name,
                function(actionIdx)
                    if actionIdx == 1 then
                        smapTakeItem(sceneId, ent)
                    elseif actionIdx == 2 then
                        local itemsData = g(_G, "initDataSource")
                        if itemsData then
                            local itemDef = itemsData["items"] and itemsData["items"][ent.itemId]
                            if itemDef and itemDef["描述"] then
                                w(ent.name .. " - " .. itemDef["描述"])
                            end
                        end
                        SmapHandlers.look({})
                    end
                end
            )
        end
    elseif ent.type == "exit" then
        -- 出口：直接传送
        SmapHandlers.go({tostring(idx)})
    elseif ent.type == "event_trigger" then
        -- 交互对象（宝箱/柜子等）：直接执行事件脚本
        local eventId = ent.eventId or (ent.npcData and (ent.npcData["事件编号"] or ent.npcData["触发事件"]) or 0)
        if tonumber(eventId) ~= 0 then
            -- 标记为已触发（注意：必须用 rawget/rawset 访问 _G，绕过 __index/__newindex）
            local ec = rawget(_G, "eventConsumed")
            if not ec then ec = {}; rawset(_G, "eventConsumed", ec) end
            ec[sceneId] = ec[sceneId] or {}
            ec[sceneId][tostring(eventId)] = true
            local JY = g(_G, "JY")
            if JY then JY.CurrentD = tonumber(eventId) end
            local EventExecutor = g(_G, "EventExecutor")
            if EventExecutor then
                w("你打开了...")
                local ok, err = pcall(EventExecutor.oldCallEventCoroutine, tonumber(eventId))
                if not ok then
                    w("事件执行失败: " .. tostring(err))
                end
            end
            if JY then JY.CurrentD = -1 end
        else
            w("里面什么都没有。")
        end
        smapEntityList = {}
        SmapHandlers.look({})
    end
end

-- NPC 对话
function smapNpcTalk(sceneId, ent)
    local eventId = ent.npcData["事件编号"] or ent.npcData["触发事件"] or 0
    if tonumber(eventId) == 0 then
        w(ent.name .. " 似乎不想说话。")
        SmapHandlers.look({})
        return
    end
    w("你与 " .. ent.name .. " 交谈。")
    local EventExecutor = g(_G, "EventExecutor")
    if EventExecutor then
        -- 必须在调用前设置 JY.CurrentD，因为 instruct_3 等函数用它标记事件状态
        local JY = g(_G, "JY")
        if JY then JY.CurrentD = tonumber(eventId) end
        local ok, err = pcall(EventExecutor.oldCallEventCoroutine, tonumber(eventId))
        if not ok then
            w("事件执行失败: " .. tostring(err))
        end
        if JY then JY.CurrentD = -1 end
        w("交谈结束。")
        smapEntityList = {}
        SmapHandlers.look({})
    else
        w("事件系统不可用。")
    end
end

-- 拾取物品
function smapTakeItem(sceneId, ent)
    if not _G.itemAvailable(sceneId, ent.itemId) then
        w(ent.name .. " 已经被拿走了。")
        return
    end
    local JY = g(_G, "JY")
    if not JY then JY = {}; rawset(_G, "JY", JY) end
    JY.Base = JY.Base or {}
    for i = 1, 30 do
        if not JY.Base["物品" .. i] or JY.Base["物品" .. i] == 0 then
            JY.Base["物品" .. i] = tonumber(ent.itemId) or 0
            JY.Base["物品数量" .. i] = 1
            break
        end
    end
    _G.setItemCount(sceneId, ent.itemId, 0)
    w("你获得了 " .. ent.name .. "。")
    smapEntityList = {}
    SmapHandlers.look({})
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
    
    -- 自动存档到槽位 0
    local saveGameState = g(_G, "saveGameState")
    if saveGameState then pcall(saveGameState, 0) end
    
    -- 离开场景时恢复到该场景在世界地图上的入口坐标
    local sceneId = tostring(JY.SubScene or 0)
    local entrances = getEntrances()
    if entrances then
        for _, entry in ipairs(entrances) do
            if tostring(entry.sceneId) == sceneId then
                if JY.Base then
                    JY.Base["人X1"] = entry.mapX or JY.Base["人X1"]
                    JY.Base["人Y1"] = entry.mapY or JY.Base["人Y1"]
                end
                break
            end
        end
    end
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
            -- 自动存档到槽位 0
            local saveGameState = g(_G, "saveGameState")
            if saveGameState then pcall(saveGameState, 0) end
            
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

-- 查找角色名称（从 initDataSource.chars）
local function getCharName(charId)
    local cache = g(_G, "initDataSource")
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

-- 查找物品名称（从 initDataSource.items）
local function getItemName(itemId)
    local cache = g(_G, "initDataSource")
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
    local sceneIndex = getScenes()
    local scene = sceneIndex and sceneIndex[sceneId]

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
        local charName = npc["名称"] or getCharName(charId)
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
    local sceneIndex = getScenes()
    local scene = sceneIndex and sceneIndex[sceneId]

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
    local scene = scenes and scenes[sceneId]
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

function SmapHandlers.rest(args)
    local JY = g(_G, "JY")
    if not JY then JY = {}; rawset(_G, "JY", JY) end
    JY.Base = JY.Base or {}
    JY.Person = JY.Person or {}
    JY.Person[0] = JY.Person[0] or {}
    local scenes = getScenes()
    local sceneId = tostring(JY.SubScene or 0)
    local scene = scenes and scenes[sceneId]
    local sceneType = scene and scene["类型"] or ""
    if sceneType == "house" then
        local i12 = g(_G, "instruct_12")
        if i12 then i12() end
    elseif sceneType == "inn" then
        local i31 = g(_G, "instruct_31")
        local money = rawget(_G, "JY") and rawget(_G, "JY").Base and rawget(_G, "JY").Base["金钱"] or 0
        if money >= 100 then
            if i31 then i31(0, 100, 1) end
            local i12 = g(_G, "instruct_12")
            if i12 then i12() end
            w("你付了100两住了一晚。")
        else
            w("住一晚要100两，你钱不够。")
        end
    else
        w("这里不是休息的地方。")
    end
end

rawset(_G, "MmapHandlers", MmapHandlers)
rawset(_G, "SmapHandlers", SmapHandlers)

-- ============================================================
-- Slice 6: 角色管理菜单（通过 look → choose N 访问）
-- ============================================================
local roleMenuPhase
local bagCache = {}   -- 缓存当前列表的物品/队员选择
local roleMenuSelectedItem  -- 缓存当前选择的物品 = nil  -- nil=不在菜单中, "main","status","bag","team","save"

-- 显示角色管理主菜单
local function showRoleMenu()
    ws()
    w("--- 角色管理 ---")
    w("1. 查看状态")
    w("2. 背包")
    w("3. 队伍")
    w("4. 存档")
    w("0. 返回")
    roleMenuPhase = "main"
    w("输入 choose <编号> 选择操作")
end

-- 显示角色状态
local function showRoleStatus()
    local JY = g(_G, "JY")
    if not JY then w("游戏未开始"); return end
    local P0 = JY.Person and JY.Person[0]
    if not P0 then w("没有角色数据"); return end
    
    wt("角色状态")
    w(string.format("%s  Lv.%d", P0["姓名"] or "?", P0["等级"] or 1))
    w(string.format("生命:%d/%d  内力:%d/%d  体力:%d/%d",
        P0["生命"] or 0, P0["生命最大值"] or 0,
        P0["内力"] or 0, P0["内力最大值"] or 0,
        P0["体力"] or 0, 100))
    w(string.format("攻击:%d  防御:%d  轻功:%d  资质:%d",
        P0["攻击力"] or 0, P0["防御力"] or 0,
        P0["轻功"] or 0, P0["资质"] or 0))
    w(string.format("医疗:%d  用毒:%d  解毒:%d",
        P0["医疗能力"] or 0, P0["用毒能力"] or 0, P0["解毒能力"] or 0))
    
    -- 武功
    local hasWugong = false
    for i = 1, 10 do
        local wid = P0["武功" .. i]
        if wid and wid ~= 0 then
            if not hasWugong then w("武功:"); hasWugong = true end
            local wuLevel = P0["武功等级" .. i] or 0
            local CC = g(_G, "CC")
            local wuName = CC and CC["武功" .. wid] or ("武功" .. wid)
            w(string.format("  %d. %s (Lv.%d)", i, wuName, wuLevel))
        end
    end
    if not hasWugong then w("武功: 无") end
    
    -- 装备
    local weapon = P0["武器"] or 0
    local armor = P0["防具"] or 0
    local itemName = function(id) return (CC and CC["物品" .. id]) or ("物品" .. id) end
    w(string.format("装备: 武器=%s  防具=%s", weapon > 0 and itemName(weapon) or "无", armor > 0 and itemName(armor) or "无"))
    
    -- 品德/声望/经验
    w(string.format("品德:%d  声望:%d  经验:%d", P0["品德"] or 0, P0["声望"] or 0, P0["经验"] or 0))
    
    roleMenuPhase = nil
    ws()
    w("1. 查看队员  0. 返回")
    roleMenuPhase = "status"
end

-- 显示背包
local function showBag()
    local JY = g(_G, "JY")
    if not JY or not JY.Base then w("背包: 空"); return end
    wt("背包")
    local count = 0
    for i = 1, 30 do
        local itemId = JY.Base["物品" .. i]
        if itemId and itemId ~= 0 then
            count = count + 1
            local qty = JY.Base["物品数量" .. i] or 1
            local CC = g(_G, "CC")
            local name = CC and CC["物品" .. itemId] or ("物品" .. itemId)
            w(string.format("%d. %s x%d", count, name, qty))
        end
    end
    if count == 0 then w("背包是空的") end
    roleMenuPhase = nil
    ws()
    w("1. 使用物品")
    w("2. 装备物品")
    w("0. 返回")
    roleMenuPhase = "bag"
end

-- 获取物品定义
local function getItemDef(itemId)
    local JY = g(_G, "JY")
    return JY and JY.Thing and JY.Thing[itemId]
end

-- 获取人物姓名
local function getPersonName(pid)
    local JY = g(_G, "JY")
    local p = JY and JY.Person and JY.Person[pid]
    return (p and p["姓名"]) or "?" 
end

-- 获取 CC 物品名
local function getCCItemName(itemId)
    local CC = g(_G, "CC")
    return (CC and CC["物品" .. itemId]) or ("物品" .. itemId)
end

-- 列出背包中指定类型的物品
local function filterBagItems(filterFn)
    local JY = g(_G, "JY")
    if not JY or not JY.Base then return {} end
    local result = {}
    for i = 1, 30 do
        local itemId = JY.Base["物品" .. i]
        if itemId and itemId ~= 0 and filterFn(itemId) then
            table.insert(result, {slot = i, id = itemId, qty = JY.Base["物品数量" .. i] or 1})
        end
    end
    return result
end

-- 列出可使用的物品（药品/暗器类）
local function showUsableItems()
    local items = filterBagItems(function(id)
        local def = getItemDef(id)
        return def and (def["类型"] == 3 or def["类型"] == 4)
    end)
    if #items == 0 then w("没有可使用的物品。"); return nil end
    w("选择要使用的物品：")
    bagCache = {}
    for idx, it in ipairs(items) do
        table.insert(bagCache, it)
        local def = getItemDef(it.id)
        local desc = ""
        if def["加生命"] and def["加生命"] > 0 then desc = desc .. " +生命" .. def["加生命"] end
        if def["加内力"] and def["加内力"] > 0 then desc = desc .. " +内力" .. def["加内力"] end
        if def["加体力"] and def["加体力"] > 0 then desc = desc .. " +体力" .. def["加体力"] end
        w(string.format("%d. %s%s", idx, getCCItemName(it.id), desc))
    end
    w("0. 返回")
    return items
end

-- 列出可装备的物品（武器/防具）
local function showEquipableItems()
    local items = filterBagItems(function(id)
        local def = getItemDef(id)
        return def and def["装备类型"] ~= nil and def["装备类型"] >= 0
    end)
    if #items == 0 then w("没有可装备的物品。"); return nil end
    w("选择要装备的物品：")
    bagCache = {}
    for idx, it in ipairs(items) do
        table.insert(bagCache, it)
        local def = getItemDef(it.id)
        local slotName = (def["装备类型"] == 0) and "武器" or "防具"
        w(string.format("%d. %s [%s]", idx, getCCItemName(it.id), slotName))
    end
    w("0. 返回")
    return items
end

-- 列出队伍成员
local function showTeamTargets()
    local JY = g(_G, "JY")
    if not JY then return nil end
    local members = {}
    local idx = 0
    for i = 1, CC.TeamNum or 6 do
        local pid = JY.Base["队伍" .. i]
        if pid and pid >= 0 and JY.Person and JY.Person[pid] then
            idx = idx + 1
            local p = JY.Person[pid]
            table.insert(members, {slot = i, pid = pid, p = p})
            w(string.format("%d. %s HP:%d/%d MP:%d/%d",
                idx, p["姓名"] or "?", p["生命"] or 0, p["生命最大值"] or 0,
                p["内力"] or 0, p["内力最大值"] or 0))
        end
    end
    if #members == 0 then w("队伍为空"); return nil end
    w("0. 返回")
    return members
end

-- 执行物品使用效果
local function applyItemEffect(target, itemId)
    local def = getItemDef(itemId)
    if not def then return end
    local p = target.p
    local hpHeal = def["加生命"] or 0
    local mpHeal = def["加内力"] or 0
    local stHeal = def["加体力"] or 0
    if hpHeal > 0 then
        local old = p["生命"] or 0
        local maxHp = p["生命最大值"] or old
        p["生命"] = math.min(maxHp, old + hpHeal)
        w(string.format("%s 生命恢复 %d 点。", target.name or "?", p["生命"] - old))
    end
    if mpHeal > 0 then
        local old = p["内力"] or 0
        local maxMp = p["内力最大值"] or old
        p["内力"] = math.min(maxMp, old + mpHeal)
        w(string.format("%s 内力恢复 %d 点。", target.name or "?", p["内力"] - old))
    end
    if stHeal > 0 then
        local old = p["体力"] or 100
        p["体力"] = math.min(100, old + stHeal)
        w(string.format("%s 体力恢复 %d 点。", target.name or "?", p["体力"] - old))
    end
end

-- 显示队伍
local function showTeam()
    local JY = g(_G, "JY")
    if not JY then return end
    wt("队伍")
    local memberCount = 0
    for i = 1, CC.TeamNum or 6 do
        local pid = JY.Base["队伍" .. i]
        if pid and pid >= 0 and JY.Person and JY.Person[pid] then
            memberCount = memberCount + 1
            local p = JY.Person[pid]
            w(string.format("%d. %s HP:%d/%d MP:%d/%d Lv.%d",
                memberCount, p["姓名"] or "?", p["生命"] or 0, p["生命最大值"] or 0,
                p["内力"] or 0, p["内力最大值"] or 0, p["等级"] or 1))
        end
    end
    if memberCount == 0 then w("队伍为空") end
    roleMenuPhase = nil
    ws()
    w("1. 医疗/解毒")
    w("0. 返回")
    roleMenuPhase = "team"
end

-- 存档菜单
local function showSaveMenu()
    ws()
    w("--- 存档管理 ---")
    w("1. 存到槽位1")
    w("2. 存到槽位2")
    w("3. 存到槽位3")
    w("4. 读取槽位1")
    w("5. 读取槽位2")
    w("6. 读取槽位3")
    w("0. 返回")
    roleMenuPhase = "save"
    w("输入 choose <编号> 选择操作")
end

-- 执行存档
local function doSave(slot)
    local saveGameState = g(_G, "saveGameState")
    if not saveGameState then w("存档系统不可用"); return end
    local ok = saveGameState(slot)
    if ok then w(string.format("已保存到槽位%d。", slot)) else w("保存失败。") end
end

-- 执行读档
local function doLoad(slot)
    local loadGameState = g(_G, "loadGameState")
    if not loadGameState then w("读档系统不可用"); return end
    w(string.format("正在读取槽位%d...", slot))
    local ok = loadGameState(slot)
    if ok then
        w("读取完成。")
        local JY = g(_G, "JY")
        if JY then
            if JY.Status == 2 then local ml = g(_G, "MmapHandlers"); if ml and ml.look then ml.look({}) end
            elseif JY.Status == 4 then local sl = g(_G, "SmapHandlers"); if sl and sl.look then sl.look({}) end end
        end
    else
        w("读取失败。")
    end
end

-- 处理角色管理 choose N（返回 true=已处理, false=未处理）
function RoleMenu_handleChoose(n)
    if roleMenuPhase == "main" then
        if n == 1 then showRoleStatus()
        elseif n == 2 then showBag()
        elseif n == 3 then showTeam()
        elseif n == 4 then showSaveMenu()
        elseif n == 0 then roleMenuPhase = nil; return false end
        return true
    elseif roleMenuPhase == "status" then
        if n == 0 then showRoleMenu()
        elseif n == 1 then
            showTeam()
            roleMenuPhase = "team"
        end
        return true
    elseif roleMenuPhase == "bag" then
        if n == 0 then showRoleMenu()
        elseif n == 1 then  -- 使用物品
            roleMenuPhase = "bag_use_select_item"
            bagCache = {}
            if not showUsableItems() then roleMenuPhase = nil end
        elseif n == 2 then  -- 装备物品
            roleMenuPhase = "bag_equip_select_item"
            bagCache = {}
            if not showEquipableItems() then roleMenuPhase = nil end
        end
        return true
    elseif roleMenuPhase == "bag_use_select_item" then
        if n == 0 then showBag(); return true end
        local item = bagCache[n]
        if not item then w("无效选择。"); return true end
        roleMenuPhase = "bag_use_select_target"
        roleMenuSelectedItem = item
        w("选择目标：")
        showTeamTargets()
        return true
    elseif roleMenuPhase == "bag_use_select_target" then
        if n == 0 then showBag(); return true end
        local members = {}
        local JY = g(_G, "JY")
        for i = 1, CC.TeamNum or 6 do
            local pid = JY.Base["队伍" .. i]
            if pid and pid >= 0 and JY.Person and JY.Person[pid] then
                table.insert(members, {slot = i, pid = pid, p = JY.Person[pid], name = JY.Person[pid]["姓名"]})
            end
        end
        local target = members[n]
        if not target then w("无效目标。"); return true end
        -- 执行使用
        applyItemEffect(target, roleMenuSelectedItem.id)
        -- 消耗物品
        JY.Base["物品" .. roleMenuSelectedItem.slot] = 0
        JY.Base["物品数量" .. roleMenuSelectedItem.slot] = 0
        roleMenuSelectedItem = nil
        roleMenuPhase = nil
        ws()
        showBag()
        return true
    elseif roleMenuPhase == "bag_equip_select_item" then
        if n == 0 then showBag(); return true end
        local item = bagCache[n]
        if not item then w("无效选择。"); return true end
        local def = getItemDef(item.id)
        if not def then w("无法装备此物品。"); return true end
        local JY = g(_G, "JY")
        local p0 = JY.Person and JY.Person[0]
        if not p0 then w("角色数据异常。"); return true end
        local slotName = (def["装备类型"] == 0) and "武器" or "防具"
        local equipSlot = (def["装备类型"] == 0) and "武器" or "防具"
        local oldItem = p0[equipSlot] or 0
        -- 装备新物品
        p0[equipSlot] = item.id
        JY.Base["物品" .. item.slot] = oldItem
        JY.Base["物品数量" .. item.slot] = (oldItem > 0) and 1 or 0
        w(string.format("装备了 %s [%s]。", getCCItemName(item.id), slotName))
        if oldItem and oldItem > 0 then
            w(string.format("卸下了 %s。", getCCItemName(oldItem)))
        end
        roleMenuPhase = nil
        ws()
        showBag()
        return true
    elseif roleMenuPhase == "team" then
        if n == 0 then showRoleMenu()
        elseif n == 1 then  -- 医疗/解毒
            roleMenuPhase = "team_heal_select_item"
            bagCache = {}
            w("选择药品：")
            if not showUsableItems() then roleMenuPhase = nil end
        end
        return true
    elseif roleMenuPhase == "team_heal_select_item" then
        if n == 0 then showTeam(); return true end
        local item = bagCache[n]
        if not item then w("无效选择。"); return true end
        roleMenuPhase = "team_heal_select_target"
        roleMenuSelectedItem = item
        w("选择目标队员：")
        showTeamTargets()
        return true
    elseif roleMenuPhase == "team_heal_select_target" then
        if n == 0 then showTeam(); return true end
        local members = {}
        local JY = g(_G, "JY")
        for i = 1, CC.TeamNum or 6 do
            local pid = JY.Base["队伍" .. i]
            if pid and pid >= 0 and JY.Person and JY.Person[pid] then
                table.insert(members, {slot = i, pid = pid, p = JY.Person[pid], name = JY.Person[pid]["姓名"]})
            end
        end
        local target = members[n]
        if not target then w("无效目标。"); return true end
        applyItemEffect(target, roleMenuSelectedItem.id)
        -- 消耗物品
        JY.Base["物品" .. roleMenuSelectedItem.slot] = 0
        JY.Base["物品数量" .. roleMenuSelectedItem.slot] = 0
        roleMenuSelectedItem = nil
        roleMenuPhase = nil
        ws()
        showTeam()
        return true
    elseif roleMenuPhase == "save" then
        if n >= 1 and n <= 3 then doSave(n)
        elseif n >= 4 and n <= 6 then doLoad(n - 3)
        elseif n == 0 then showRoleMenu() end
        return true
    end
    return false
end

-- 在 look 输出后追加角色管理菜单入口（原版 ESC 主菜单的文字替代）
-- 原版游戏按 ESC 打开主选单：系统/物品/武功/状态/存挡/读挡
local function appendRoleMenuEntry()
    ws()
    w("输入 menu 打开主选单（系统/物品/武功/状态/存挡）")
end

-- 覆写 SmapHandlers.look 以追加角色管理菜单
local _origSmapLook = SmapHandlers.look
SmapHandlers.look = function(args)
    _origSmapLook(args)
    appendRoleMenuEntry()
end

-- menu 命令：原版 ESC 主选单的文字替代
-- 显示：系统/物品/武功/状态/存挡/读挡
function SmapHandlers.menu(args)
    roleMenuPhase = "main"
    ws()
    w("--- 主选单 ---")
    w("1. 状态")
    w("2. 物品")
    w("3. 武功")
    w("4. 系统（存档/读档）")
    w("0. 返回")
    w("输入 choose <编号> 选择操作")
end

function MmapHandlers.menu(args)
    SmapHandlers.menu(args)
end
