-- mmap_smap_handlers.lua
-- 大地图 (MMAP) 和场景 (SMAP) 文字交互命令

local MmapHandlers = {}
local SmapHandlers = {}
local g = rawget

-- 角色管理菜单状态（声明在顶部，所有函数均可访问）
local roleMenuPhase  -- nil=非菜单状态, "main","status","bag","team","save" 等
local bagCache = {}  -- 缓存当前列表的物品/队员选择
local roleMenuSelectedItem  -- 缓存当前选择的物品

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
    if name:find("客栈") or name:find("店") then return sceneTemplates.inn end
    if name:find("居") or name:find("庄") or name:find("阁") then return sceneTemplates.house end
    if name:find("洞") then return sceneTemplates.cave end
    if name:find("派") or name:find("教") or name:find("门") then return string.format(sceneTemplates.school, name) end
    if name:find("铺") then return sceneTemplates.shop end
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

    -- 输出标题和场景名到终端（showMenu 的菜单项通过 DrawString 渲染，MUD 中不可见）
    w("可去场景（选择序号前往）")
    w("════════════════════════════════════")
    for i, item in ipairs(sceneItems) do
        w(string.format("%d. %s", i, item.name))
    end
    CE.showMenu(sceneItems, nil, function(idx)
        if idx and idx > 0 then
            local target = sceneItems[idx]
            if target then
                goToScene(target)
            end
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
        for npcIdx, npc in ipairs(npcs) do
            local charIdStr = tostring(npc["代号"] or npc)
            local npcName = npc["名称"] or "?"
            local isEventTrigger = npcName and npcName:match("^oldevent_")
            if isEventTrigger or _G.isNpcPresent(sceneId, charIdStr) then
                if isEventTrigger then
                    local eventId = npc["事件编号"] or 0
                    local eid = tonumber(eventId) or 0
                    -- eventConsumed 在 web_game_bridge.lua 已预注册（早于 setmetatable(_G)），直接访问安全
                    local eventOff = _G.eventConsumed[sceneId] and _G.eventConsumed[sceneId][tostring(eventId)]
                    if not eventOff then
                        entityIndex = entityIndex + 1
                        smapEntityList[entityIndex] = { type = "event_trigger", eventId = tonumber(eventId), charId = charIdStr, name = npcName, npcData = npc }
                        w(string.format("%d. 搜索", entityIndex))
                    end
                else
                    local char = charsIndex and charsIndex[charIdStr]
                    local displayName = npcName or (char and char["姓名"]) or ("NPC?" .. charIdStr)
                    entityIndex = entityIndex + 1
                    smapEntityList[entityIndex] = { type = "npc", charId = charIdStr, name = displayName, npcData = npc, npcIndex = npcIdx }
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
    end

    -- 格子事件列表（events.json 中 eventExtra>0 的过路触发事件，以及圣堂等场景的 eventTouch 事件）
    local cache = g(_G, "initDataSource")
    local rawEvents = cache and cache["events"]
    if rawEvents and rawEvents["events"] then
        local sceneNum = tonumber(sceneId) or 0
        for _, evt in ipairs(rawEvents["events"]) do
            if evt.sceneId == sceneNum then
                local eventId = nil
                local eventType = nil
                if evt.eventExtra and evt.eventExtra > 0 then
                    eventId = evt.eventExtra
                    eventType = "event_extra"
                elseif evt.eventTouch and evt.eventTouch > 0 then
                    eventId = evt.eventTouch
                    eventType = "event_touch"
                end
                if eventId then
                    local consumed = _G.eventConsumed[sceneId] and _G.eventConsumed[sceneId][tostring(eventId)]
                    if not consumed then
                        -- 圣堂事件：检查 D* 表是否已放置天书（tileCurrent == 4664）
                        if eventId >= 1001 and eventId <= 1014 then
                            local JY2 = g(_G, "JY")
                            local tileIdx = eventId - 990
                            local GetD = g(_G, "GetD")
                            if GetD and JY2 then
                                local tileCurrent = GetD(tonumber(sceneId), tileIdx, 5)
                                if tileCurrent == 4664 then
                                    goto continue
                                end
                            end
                        end
                        entityIndex = entityIndex + 1
                        smapEntityList[entityIndex] = { type = "event_trigger", eventId = eventId, eventType = eventType, name = "tile_event", npcData = {["事件编号"]=eventId} }
                        if eventId >= 1001 and eventId <= 1014 then
                            w(string.format("%d. 放置天书", entityIndex))
                        else
                            w(string.format("%d. 搜索", entityIndex))
                        end
                    end
                end
            end
            ::continue::
        end
    end
    
    w("输入 choose <编号> 选择交互对象")
end

-- SMAP choose 处理（由 CommandEngine 调度或 processEventQueue 调用）
function SmapHandlers.chooseInteraction(idx)
    local wUI = g(_G, "WebUI")
    if wUI then wUI.write("[DEBUG chooseInteraction] idx=" .. tostring(idx) .. " entityCount=" .. tostring(#smapEntityList)) end
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
    
    local wUI2 = g(_G, "WebUI")
    if wUI2 then wUI2.write("[DEBUG chooseInteraction] ent.type=" .. tostring(ent.type) .. " ent.name=" .. tostring(ent.name) .. " sceneId=" .. tostring(sceneId)) end
    
    if ent.type == "npc" then
        local wUI2 = g(_G, "WebUI")
        if wUI2 then wUI2.write("[DEBUG chooseInteraction] type=" .. tostring(ent.type) .. " name=" .. tostring(ent.name) .. " eventId=" .. tostring(ent.npcData and ent.npcData["事件编号"])) end
        if wUI2 then wUI2.write("[DEBUG chooseInteraction NPC] calling smapNpcTalk") end
        -- Web MUD: 直接对话，不使用子菜单（MenuAsync 菜单系统在连续交互时可能失效）
        smapNpcTalk(sceneId, ent)
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
        -- 出口：直接传送（使用 entity 的 targetSceneId，而非按 exit 索引查找）
        local targetSceneId = ent.targetSceneId
        if targetSceneId then
            local JY = g(_G, "JY")
            if not JY then JY = {}; rawset(_G, "JY", JY) end
            JY.SubScene = tonumber(targetSceneId)
            local scenes = getScenes()
            local targetScene = scenes and scenes[tostring(targetSceneId)]
            if targetScene then
                w(string.format("进入了 %s。\n", targetScene["名称"]))
                SmapHandlers.look({})
            else
                JY.Status = 2
                w("你回到了大地图。\n")
                MmapHandlers.look({})
            end
        end
    elseif ent.type == "event_trigger" then
        -- 交互对象（宝箱/柜子/书架等）：直接执行事件脚本
        local eventId = ent.eventId or (ent.npcData and (ent.npcData["事件编号"] or ent.npcData["触发事件"]) or 0)
        if tonumber(eventId) ~= 0 then
            -- 圣堂放置天书事件：不预标记 consumed，由 oldevent 脚本内的 instruct_3 处理 D* 表
            local isShenTangBook = (eventId >= 1001 and eventId <= 1014)
            if not isShenTangBook then
                _G.eventConsumed[sceneId] = _G.eventConsumed[sceneId] or {}
                _G.eventConsumed[sceneId][tostring(eventId)] = true
            end
            local EventExecutor = g(_G, "EventExecutor")
            if EventExecutor then
                if isShenTangBook then
                    w("放置天书...")
                    -- 圣堂书架：oldevent 编号 1001-1014 对应 D* 索引 11-24
                    -- 设置 JY.CurrentD 为 D* 索引（tileIndex），供 instruct_3(id=-2) 正确写入
                    local JY = g(_G, "JY")
                    if JY then JY.CurrentD = (eventId - 990) end  -- 1001→11, 1002→12, ...
                else
                    w("你打开了...")
                end
                local oldCallEventCoroutine = EventExecutor.oldCallEventCoroutine
                local ok, err = pcall(oldCallEventCoroutine, EventExecutor, tonumber(eventId))
                if not ok then
                    w("事件执行失败: " .. tostring(err))
                end
                -- 圣堂事件执行后，恢复 JY.CurrentD（由事件处理器自己管理）
                local JY2 = g(_G, "JY")
                if JY2 and isShenTangBook then
                    JY2.CurrentD = -1
                end
            end
        else
            w("里面什么都没有。")
        end
        smapEntityList = {}
        SmapHandlers.look({})
    end
end

-- NPC 对话
function smapNpcTalk(sceneId, ent)
    local wUI = g(_G, "WebUI")
    if wUI then wUI.write("[DEBUG smapNpcTalk ENTER] sceneId=" .. tostring(sceneId) .. " eventId=" .. tostring(ent.npcData["事件编号"])) end
    local eventId = ent.npcData["事件编号"] or ent.npcData["触发事件"] or 0
    local dIdx = ent.npcIndex or tonumber(ent.npcData["触发事件"] or 0)
    local staticEventId = tonumber(eventId) or 0
    -- 尝试从 D* 事件表获取动态事件 ID（instruct_3 修改后的值）
    if staticEventId > 0 then
        local GetD = g(_G, "GetD")
        if GetD then
            local sid = tonumber(sceneId)
            -- 使用事件编号作为索引（instruct_3 的写入位置）
            -- 检查顺序：field 5 → 4 → 3 → 2 → 0（与原版 D* 事件解析一致）
            local dynamicId = GetD(sid, staticEventId, 5)
            if not dynamicId or dynamicId <= 0 then
                dynamicId = GetD(sid, staticEventId, 4)
            end
            if not dynamicId or dynamicId <= 0 then
                dynamicId = GetD(sid, staticEventId, 3)
            end
            if not dynamicId or dynamicId <= 0 then
                dynamicId = GetD(sid, staticEventId, 2)
            end
            if not dynamicId or dynamicId <= 0 then
                dynamicId = GetD(sid, staticEventId, 0)
            end
            if dynamicId and dynamicId > 0 then
                eventId = dynamicId
            end
        end
        -- 直接访问 JY.D 作为备选
        local JY = g(_G, "JY")
        if JY then
            JY.D = JY.D or {}
            local sid = tonumber(sceneId)
            local sceneD = JY.D[sid]
            if sceneD then
                -- 检查事件编号索引（instruct_3 写入的位置）
                local evt = sceneD[staticEventId]
                if evt then
                    if evt[5] and evt[5] > 0 then
                        eventId = evt[5]
                    elseif evt[4] and evt[4] > 0 then
                        eventId = evt[4]
                    elseif evt[3] and evt[3] > 0 then
                        eventId = evt[3]
                    elseif evt[2] and evt[2] > 0 then
                        eventId = evt[2]
                    elseif evt[0] and evt[0] > 0 then
                        eventId = evt[0]
                    end
                end
                -- 检查 NPC D* 索引（原版游戏循环读取的位置：100+npcIndex）
                if dIdx and dIdx > 0 then
                    local dStarId = 100 + dIdx
                    local evt2 = sceneD[dStarId]
                    if evt2 then
                        if evt2[5] and evt2[5] > 0 then
                            eventId = evt2[5]
                        elseif evt2[4] and evt2[4] > 0 then
                            eventId = evt2[4]
                        elseif evt2[3] and evt2[3] > 0 then
                            eventId = evt2[3]
                        elseif evt2[2] and evt2[2] > 0 then
                            eventId = evt2[2]
                        elseif evt2[0] and evt2[0] > 0 then
                            eventId = evt2[0]
                        end
                    end
                end
            end
        end
    end
    -- 调试日志：输出事件ID解析结果
    local wUI = g(_G, "WebUI")
    if wUI then wUI.write("[DEBUG smapNpcTalk] sceneId=" .. tostring(sceneId) .. " staticEventId=" .. tostring(staticEventId) .. " resolvedEventId=" .. tostring(eventId) .. " dIdx=" .. tostring(dIdx)) end
    if tonumber(eventId) == 0 then
        w(ent.name .. " 似乎不想说话。")
        SmapHandlers.look({})
        return
    end
    w("你与 " .. ent.name .. " 交谈。")
    local EventExecutor = g(_G, "EventExecutor")
    if EventExecutor then
        -- 注意：event_executor.lua:73 会设置 JY.CurrentD = eventnum（事件编号）
        -- 因此 instruct_3 会写入 JY.D[sceneId][eventNum][field]
        -- 无需在此设置 JY.CurrentD，由 oldCallEventCoroutine 处理
        -- 在协程中执行事件，确保 instruct_11 等阻塞函数可以 yield 等待用户输入
        local scheduler = g(_G, "CoroutineScheduler")
        if scheduler and scheduler.getInstance then
            scheduler = scheduler.getInstance()
        end
        if scheduler and scheduler.create then
            -- 在协程中执行事件，后处理也放在协程内（确保 yield 恢复后再执行）
            local co = scheduler:create(function()
                -- 设置 JY.CurrentD 为 NPC 的 D* 索引，覆盖 event_executor.lua:73 的错误设置
                -- event_executor.lua:73 设置 JY.CurrentD = eventnum (678)，
                -- 但原版游戏循环从 GetD(sceneId, 100+npcIndex, 0) 读取
                -- 所以 instruct_3 写入 JY.D[76][678] 后，需要同步到 JY.D[76][100+npcIndex]
                local JY = g(_G, "JY")
                if JY then
                    JY.CurrentD = 100 + (dIdx or 0)
                end
                local ok, err = pcall(EventExecutor.oldCallEventCoroutine, tonumber(eventId))
                if not ok then w("事件执行失败: " .. tostring(err)) end
                -- 事件执行完成后，将数据从事件编号索引同步到 NPC D* 索引
                if JY and JY.D then
                    local sid = tonumber(sceneId)
                    local sceneD = JY.D[sid]
                    if sceneD then
                        local srcEvt = sceneD[staticEventId]
                        if srcEvt and dIdx and dIdx > 0 then
                            local dStarId = 100 + dIdx
                            sceneD[dStarId] = sceneD[dStarId] or {}
                            for f = 0, 10 do
                                if srcEvt[f] ~= nil then
                                    sceneD[dStarId][f] = srcEvt[f]
                                end
                            end
                        end
                    end
                end
                w("交谈结束。")
                smapEntityList = {}
                SmapHandlers.look({})
            end, "npc_talk_" .. tostring(eventId))
            scheduler:start(co, "start")
        else
            -- 回退：无协程时直接同步执行
            local ok, err = pcall(EventExecutor.oldCallEventCoroutine, tonumber(eventId))
            if not ok then w("事件执行失败: " .. tostring(err)) end
            w("交谈结束。")
            smapEntityList = {}
            SmapHandlers.look({})
        end
    else
        w("事件系统不可用。")
    end
end

-- NPC 给予（银两或物品）
function smapNpcGive(sceneId, ent)
    local JY = g(_G, "JY")
    if not JY then JY = {}; rawset(_G, "JY", JY) end
    JY.Base = JY.Base or {}

    -- 先选类型：银两 / 物品
    local CE = g(_G, "CommandEngine")
    if CE then
        CE.showMenu(
            { {name="银两"}, {name="物品"} },
            string.format("给 %s 什么？", ent.name),
            function(typeChoice)
                if not typeChoice then
                    SmapHandlers.look({})
                    return
                end
                if typeChoice == 1 then
                    smapGiveSilver(sceneId, ent)
                elseif typeChoice == 2 then
                    smapGiveItem(sceneId, ent)
                end
            end
        )
    end
end

-- 给予银两
function smapGiveSilver(sceneId, ent)
    local JY = g(_G, "JY")
    local money = JY and JY.Base and JY.Base["金钱"] or 0
    if money <= 0 then
        w("你身无分文。")
        SmapHandlers.look({})
        return
    end

    w(string.format("你身上有 %d 两银子。想给 %s 多少？", money, ent.name))
    local amounts = {}
    for _, v in ipairs({10, 50, 100, 200, 500}) do
        if money >= v then
            table.insert(amounts, {name = string.format("%d两", v), amount = v})
        end
    end
    table.insert(amounts, {name = "全部", amount = money})
    table.insert(amounts, {name = "自定义", amount = -1})

    local CE = g(_G, "CommandEngine")
    if CE then
        CE.showMenu(amounts, "选择金额", function(choice)
            if not choice then
                SmapHandlers.look({})
                return
            end
            local selected = amounts[choice]
            if not selected then
                SmapHandlers.look({})
                return
            end
            if selected.amount == -1 then
                w("输入 give <数量> 给予银两，choose 0 返回")
                local smapId = 4
                local cmds = CE.getCommands(smapId) or {}
                cmds["give"] = {
                    handler = function(args)
                        local amt = tonumber(args and args[1])
                        if not amt or amt <= 0 then
                            w("请输入有效的数量。")
                            return
                        end
                        local JY2 = g(_G, "JY")
                        local m2 = JY2 and JY2.Base and JY2.Base["金钱"] or 0
                        if amt > m2 then
                            w(string.format("你只有 %d 两银子。", m2))
                            return
                        end
                        local i32 = g(_G, "instruct_32")
                        if i32 then i32(0, 174, -amt) end
                        w(string.format("你给了 %s %d 两银子。", ent.name, amt))
                        cmds["give"] = nil
                        CE.registerCommands(smapId, cmds)
                        SmapHandlers.look({})
                    end,
                    description = "给予银两: give <数量>"
                }
                CE.registerCommands(smapId, cmds)
                return
            end
            local i32 = g(_G, "instruct_32")
            if i32 then i32(0, 174, -selected.amount) end
            w(string.format("你给了 %s %d 两银子。", ent.name, selected.amount))
            SmapHandlers.look({})
        end)
    end
end

-- 给予物品（从背包选择）
function smapGiveItem(sceneId, ent)
    local JY = g(_G, "JY")
    if not JY or not JY.Base then
        w("背包是空的。")
        SmapHandlers.look({})
        return
    end

    -- 列出背包中非零物品
    local bagItems = {}
    local bagIdx = {}
    for i = 1, 30 do
        local itemId = JY.Base["物品" .. i]
        if itemId and itemId ~= 0 then
            local qty = JY.Base["物品数量" .. i] or 1
            local name = "物品" .. itemId
            local thing = JY.Thing and JY.Thing[itemId]
            if thing and thing["名称"] then name = thing["名称"] end
            table.insert(bagItems, { slot = i, id = itemId, qty = qty, name = name })
        end
    end

    if #bagItems == 0 then
        w("背包是空的。")
        SmapHandlers.look({})
        return
    end

    local CE = g(_G, "CommandEngine")
    if CE then
        -- 用 menu 列表展示物品，供用户选择
        local menuItems = {}
        for _, bi in ipairs(bagItems) do
            table.insert(menuItems, { name = string.format("%s x%d", bi.name, bi.qty), slot = bi.slot, id = bi.id, qty = bi.qty })
        end
        CE.showMenu(menuItems, "选择要给予的物品", function(choice)
            if not choice then
                SmapHandlers.look({})
                return
            end
            local selected = menuItems[choice]
            if not selected then
                SmapHandlers.look({})
                return
            end
            -- 扣除物品
            local i32 = g(_G, "instruct_32")
            if i32 then i32(0, selected.id, -1) end
            w(string.format("你给了 %s %s。", ent.name, selected.name))
            SmapHandlers.look({})
        end)
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
    roleMenuPhase = nil  -- 场景切换时清除菜单状态
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
            roleMenuPhase = nil  -- 场景切换时清除菜单状态
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
-- Slice 6: 角色管理菜单（通过 menu 命令打开主选单）
-- roleMenuPhase/bagCache/roleMenuSelectedItem 已在文件顶部声明
-- ============================================================

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
            -- 从 JY.Thing 取物品名称（CC 不保证有物品名，JY.Thing 由 initGameState 填充）
            local thing = JY.Thing and JY.Thing[itemId]
            local name = (thing and thing["名称"]) or (CC and CC["物品" .. itemId]) or ("物品" .. itemId)
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

-- 获取物品名称（优先 JY.Thing，其次 CC，兜底显示物品ID）
local function getItemDisplayName(itemId)
    local JY = g(_G, "JY")
    local thing = JY and JY.Thing and JY.Thing[itemId]
    if thing and thing["名称"] then return thing["名称"] end
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
        w(string.format("%d. %s%s", idx, getItemDisplayName(it.id), desc))
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
        w(string.format("%d. %s [%s]", idx, getItemDisplayName(it.id), slotName))
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

-- 执行医疗（原版 ExecDoctor 简化版）
-- id1=医疗者, id2=被医疗者, 返回恢复的生命值
local function execDoctorWeb(id1, id2)
    local JY = g(_G, "JY")
    if not JY or not JY.Person then return 0 end
    local healer = JY.Person[id1]
    local patient = JY.Person[id2]
    if not healer or not patient then return 0 end
    if (healer["体力"] or 0) < 50 then
        w("体力不足，无法医疗。")
        return 0
    end
    local heal = healer["医疗能力"] or 0
    local injury = patient["受伤程度"] or 0
    if injury > heal + 20 then
        w("伤势太重，无法医疗。")
        return 0
    end
    -- 按受伤程度计算实际医疗效果
    if injury < 25 then heal = heal * 4 / 5
    elseif injury < 50 then heal = heal * 3 / 4
    elseif injury < 75 then heal = heal * 2 / 3
    else heal = heal / 2 end
    heal = math.floor(heal) + math.random(0, 4)
    -- 应用效果
    local oldHp = patient["生命"] or 0
    local maxHp = patient["生命最大值"] or oldHp
    patient["生命"] = math.min(maxHp, oldHp + heal)
    patient["受伤程度"] = math.max(0, (patient["受伤程度"] or 0) - heal)
    healer["体力"] = (healer["体力"] or 100) - 2
    local actualHeal = patient["生命"] - oldHp
    if actualHeal > 0 then
        w(string.format("%s 为 %s 医疗，生命恢复 %d 点。",
            healer["姓名"] or "?", patient["姓名"] or "?", actualHeal))
    else
        w("医疗完毕，但生命没有变化。")
    end
    return actualHeal
end

-- 执行解毒（原版 ExecDecPoison 简化版：jymain.lua:1127）
local function execDecPoisonWeb(id1, id2)
    local JY = g(_G, "JY")
    if not JY or not JY.Person then return 0 end
    local detoxer = JY.Person[id1]
    local patient = JY.Person[id2]
    if not detoxer or not patient then return 0 end
    local add = detoxer["解毒能力"] or 0
    local value = patient["中毒程度"] or 0
    if value > add + 20 then
        w("中毒太深，无法解毒。")
        return 0
    end
    add = math.floor(add / 3) + math.random(0, 9) - math.random(0, 9)
    add = math.max(0, math.min(add, value))
    patient["中毒程度"] = (patient["中毒程度"] or 0) - add
    if add > 0 then
        w(string.format("%s 为 %s 解毒，中毒程度减少 %d 点。",
            detoxer["姓名"] or "?", patient["姓名"] or "?", add))
    else
        w("解毒完毕，但中毒程度没有变化。")
    end
    return add
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
        if n == 1 then  -- 医疗（一级菜单，原版 MMenu 风格）
            local JY = g(_G, "JY")
            local healers = {}
            for i = 1, CC.TeamNum or 6 do
                local pid = JY.Base["队伍" .. i]
                if pid and pid >= 0 and JY.Person and JY.Person[pid] then
                    local p = JY.Person[pid]
                    if (p["医疗能力"] or 0) >= 20 then
                        table.insert(healers, {slot = i, pid = pid, name = p["姓名"] or "?"})
                    end
                end
            end
            if #healers == 0 then
                w("没有有医疗能力的队员。"); roleMenuPhase = nil; return true
            end
            if #healers == 1 then
                -- 自动选中，立即检查患者列表
                local patients = {}
                for i = 1, CC.TeamNum or 6 do
                    local pid = JY.Base["队伍" .. i]
                    if pid and pid >= 0 and JY.Person and JY.Person[pid] then
                        local p = JY.Person[pid]
                        table.insert(patients, {slot = i, pid = pid, p = p, name = p["姓名"] or "?"})
                    end
                end
                if #patients == 0 then
                    w("没有队员可医疗。"); roleMenuPhase = nil; return true
                end
                if #patients == 1 then
                    execDoctorWeb(healers[1].pid, patients[1].pid)
                    roleMenuPhase = nil
                    return true
                end
                roleMenuPhase = "team_heal_select_patient"
                bagCache = {healer = healers[1], patients = patients}
                w("选择要医疗的队员：")
                for idx, pt in ipairs(patients) do
                    w(string.format("%d. %s HP:%d/%d", idx, pt.name, pt.p["生命"] or 0, pt.p["生命最大值"] or 0))
                end
                w("0. 返回")
            else
                roleMenuPhase = "team_heal_select_healer"
                bagCache = healers
                w("选择医疗者：")
                for idx, h in ipairs(healers) do
                    local p = JY.Person[h.pid]
                    w(string.format("%d. %s (医疗能力:%d)", idx, h.name, p and p["医疗能力"] or 0))
                end
                w("0. 返回")
            end
        elseif n == 2 then  -- 解毒（一级菜单）
            local JY = g(_G, "JY")
            local detoxers = {}
            for i = 1, CC.TeamNum or 6 do
                local pid = JY.Base["队伍" .. i]
                if pid and pid >= 0 and JY.Person and JY.Person[pid] then
                    local p = JY.Person[pid]
                    if (p["解毒能力"] or 0) >= 20 then
                        table.insert(detoxers, {slot = i, pid = pid, name = p["姓名"] or "?"})
                    end
                end
            end
            if #detoxers == 0 then
                w("没有有解毒能力的队员。"); roleMenuPhase = nil; return true
            end
            if #detoxers == 1 then
                -- 自动选中，立即检查患者列表
                local patients = {}
                for i = 1, CC.TeamNum or 6 do
                    local pid = JY.Base["队伍" .. i]
                    if pid and pid >= 0 and JY.Person and JY.Person[pid] then
                        local p = JY.Person[pid]
                        table.insert(patients, {slot = i, pid = pid, p = p, name = p["姓名"] or "?"})
                    end
                end
                if #patients == 0 then
                    w("没有队员可解毒。"); roleMenuPhase = nil; return true
                end
                if #patients == 1 then
                    execDecPoisonWeb(detoxers[1].pid, patients[1].pid)
                    roleMenuPhase = nil
                    return true
                end
                roleMenuPhase = "team_detox_select_patient"
                bagCache = {detoxer = detoxers[1], patients = patients}
                w("选择要解毒的队员：")
                for idx, pt in ipairs(patients) do
                    w(string.format("%d. %s (中毒:%d)", idx, pt.name, pt.p["中毒程度"] or 0))
                end
                w("0. 返回")
            else
                roleMenuPhase = "team_detox_select_detoxer"
                bagCache = detoxers
                w("选择解毒者：")
                for idx, d in ipairs(detoxers) do
                    local p = JY.Person[d.pid]
                    w(string.format("%d. %s (解毒能力:%d)", idx, d.name, p and p["解毒能力"] or 0))
                end
                w("0. 返回")
            end
        elseif n == 3 then showRoleStatus(); roleMenuPhase = "status"; return true
        elseif n == 4 then showBag(); roleMenuPhase = "bag"; return true
        elseif n == 5 then showTeam(); roleMenuPhase = "team"; return true
        elseif n == 6 then showSaveMenu(); roleMenuPhase = "save"; return true
        elseif n == 0 then roleMenuPhase = nil; return true end
        -- 未识别的选择：退出菜单，让输入流向场景交互处理器
        roleMenuPhase = nil
        return false
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
        w(string.format("装备了 %s [%s]。", getItemDisplayName(item.id), slotName))
        if oldItem and oldItem > 0 then
            w(string.format("卸下了 %s。", getItemDisplayName(oldItem)))
        end
        roleMenuPhase = nil
        ws()
        showBag()
        return true
    elseif roleMenuPhase == "team" then
        if n == 0 then showRoleMenu() end
        return true
    elseif roleMenuPhase == "team_heal_select_healer" then
        if n == 0 then showTeam(); return true end
        local healer = bagCache[n]
        if not healer then w("无效选择。"); return true end
        roleMenuPhase = "team_heal_select_patient"
        bagCache = {healer}
        -- fall through to patient selection

    elseif roleMenuPhase == "team_detox_select_detoxer" then
        if n == 0 then showTeam(); return true end
        local detoxer = bagCache[n]
        if not detoxer then w("无效选择。"); return true end
        roleMenuPhase = "team_detox_select_patient"
        bagCache = {detoxer}

    elseif roleMenuPhase == "team_heal_select_patient" then
        if n ~= nil then
            -- 选了医疗者后，显示患者列表
            local healer = bagCache[1]
            if not healer then showTeam(); return true end
            if n == 0 then showTeam(); return true end
            local JY = g(_G, "JY")
            local patients = {}
            for i = 1, CC.TeamNum or 6 do
                local pid = JY.Base["队伍" .. i]
                if pid and pid >= 0 and JY.Person and JY.Person[pid] then
                    local p = JY.Person[pid]
                    table.insert(patients, {slot = i, pid = pid, p = p, name = p["姓名"] or "?"})
                end
            end
            if #patients == 0 then w("没有可医疗的队员。"); roleMenuPhase = nil; return true end
            if #patients == 1 then
                -- 只有一人，直接医疗
                execDoctorWeb(healer.pid, patients[1].pid)
                roleMenuPhase = nil
                ws()
                showTeam()
                return true
            end
            roleMenuPhase = "team_heal_select_patient"
            bagCache = {healer = healer, patients = patients}
            w("选择要医疗的队员：")
            for idx, pt in ipairs(patients) do
                w(string.format("%d. %s HP:%d/%d", idx, pt.name, pt.p["生命"] or 0, pt.p["生命最大值"] or 0))
            end
            w("0. 返回")
            return true
        else
            -- 首次进入（自动选中唯一医疗者后），显示患者列表
            local healer = bagCache[1]
            local JY = g(_G, "JY")
            local patients = {}
            for i = 1, CC.TeamNum or 6 do
                local pid = JY.Base["队伍" .. i]
                if pid and pid >= 0 and JY.Person and JY.Person[pid] then
                    local p = JY.Person[pid]
                    table.insert(patients, {slot = i, pid = pid, p = p, name = p["姓名"] or "?"})
                end
            end
            if #patients == 1 then
                execDoctorWeb(healer.pid, patients[1].pid)
                roleMenuPhase = nil
                ws()
                showTeam()
                return true
            end
            bagCache = {healer = healer, patients = patients}
            w("选择要医疗的队员：")
            for idx, pt in ipairs(patients) do
                w(string.format("%d. %s HP:%d/%d", idx, pt.name, pt.p["生命"] or 0, pt.p["生命最大值"] or 0))
            end
            w("0. 返回")
            return true
        end

    elseif roleMenuPhase == "team_detox_select_patient" then
        local detoxer = bagCache[1]
        if not detoxer then showTeam(); return true end
        if n == 0 then showTeam(); return true end
        local JY = g(_G, "JY")
        local patients = {}
        for i = 1, CC.TeamNum or 6 do
            local pid = JY.Base["队伍" .. i]
            if pid and pid >= 0 and JY.Person and JY.Person[pid] then
                local p = JY.Person[pid]
                table.insert(patients, {slot = i, pid = pid, p = p, name = p["姓名"] or "?"})
            end
        end
        if #patients == 0 then w("没有队员。"); roleMenuPhase = nil; return true end
        if #patients == 1 then
            execDecPoisonWeb(detoxer.pid, patients[1].pid)
            roleMenuPhase = nil
            ws()
            showTeam()
            return true
        end
        -- 多人：选目标（显示中毒程度）
        if n ~= nil then
            local target = patients[n]
            if not target then w("无效选择。"); return true end
            execDecPoisonWeb(detoxer.pid, target.pid)
            roleMenuPhase = nil
            ws()
            showTeam()
            return true
        end
        w("选择要解毒的队员：")
        for idx, pt in ipairs(patients) do
            w(string.format("%d. %s (中毒:%d)", idx, pt.name, pt.p["中毒程度"] or 0))
        end
        w("0. 返回")
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
-- 原版：系统/物品/武功/状态/存挡/读挡
function SmapHandlers.menu(args)
    roleMenuPhase = "main"
    ws()
    w("--- 主选单 ---")
    w("1. 医疗")
    w("2. 解毒")
    w("3. 状态")
    w("4. 物品")
    w("5. 队伍")
    w("6. 系统（存档/读档）")
    w("0. 返回")
    w("输入 choose <编号> 选择操作")
end

function MmapHandlers.menu(args)
    SmapHandlers.menu(args)
end
