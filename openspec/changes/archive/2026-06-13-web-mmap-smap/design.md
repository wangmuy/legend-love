## 设计目标

实现大地图 GAME_MMAP 和场景 GAME_SMAP 的文字交互命令，让玩家能在文字界面中探索游戏世界。

## MMAP 命令处理

### list — 列出可去场景（菜单模式）

```lua
-- 从 entrances.json 获取所有场景入口，去重后按名称排序
-- 使用 CommandEngine.showMenu（回调版）弹出菜单
-- choose N → 回调获取目标 → goToScene

function MmapHandlers.list(args)
    local sceneItems = buildSceneList()
    if not sceneItems or #sceneItems == 0 then
        WebUI.write("没有可去的场景")
        return
    end
    CE.showMenu(sceneItems, "可去场景（选择序号前往）", function(idx)
        if idx and idx > 0 then
            local target = sceneItems[idx]
            if target then goToScene(target) end
        end
    end)
end
```

### go <场景名> — 传送到场景

```lua
-- 提取的进入场景逻辑
local function goToScene(target)
    JY.Base["人X1"] = target.entry.mapX
    JY.Base["人Y1"] = target.entry.mapY
    JY.SubScene = tonumber(target.sceneId)
    JY.Status = GAME_SMAP
    WebUI.write(string.format("你来到了 %s。\n", target.name))
    SmapHandlers.look({})
end

-- 构建唯一场景列表（统一供 go/list 使用）
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

function MmapHandlers.go(args)
    local targetName = args and args[1]
    if not targetName then
        -- 无参：显示场景菜单
        local sceneItems = buildSceneList()
        if not sceneItems or #sceneItems == 0 then
            WebUI.write("没有可去的场景")
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

    -- 有参：原有精确匹配/模糊匹配逻辑
    local entrances = getEntrances()
    local scenes = getScenes()
    if not entrances then
        WebUI.write("无法获取场景数据")
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
                    WebUI.write(string.format("找到多个匹配场景: %s, %s 等", found.name, name))
                    WebUI.write("请使用更精确的名称")
                    return
                end
            end
        end
    end
    
    if not found then
        WebUI.write(string.format("未找到场景: %s", targetName))
        WebUI.write("输入 list 查看所有可去场景")
        return
    end

    goToScene(found)
end
```

### look — 当前位置描述

```lua
function MmapHandlers.look(args)
    local x = JY.Base["人X1"]
    local y = JY.Base["人Y1"]
    
    WebUI.title("当前位置")
    WebUI.write(string.format("  坐标: (%d, %d)", x, y))
    
    -- 查找附近场景
    local entrances = dataCache.entrances
    local scenes = dataCache.scenes
    local nearby = {}
    
    for _, entry in ipairs(entrances) do
        local dx = (entry.mapX or 0) - x
        local dy = (entry.mapY or 0) - y
        -- 附近 50 格内的场景
        if math.abs(dx) <= 50 and math.abs(dy) <= 50 then
            local sceneId = tostring(entry.sceneId)
            local scene = scenes[sceneId]
            local name = scene and scene["名称"] or ("场景" .. sceneId)
            nearby[#nearby + 1] = string.format("  %s (%d步)", name, 
                math.floor(math.sqrt(dx*dx + dy*dy)))
        end
    end
    
    if #nearby > 0 then
        WebUI.write("附近场景：")
        for _, item in ipairs(nearby) do
            WebUI.write(item)
        end
    else
        WebUI.write("四周一片荒凉，没有什么特别的。")
    end
end
```

### where — 坐标方位

```lua
function MmapHandlers.where(args)
    local x = JY.Base["人X1"]
    local y = JY.Base["人Y1"]
    
    local direction = ""
    if y < 100 then direction = "北方"
    elseif y < 200 then direction = "中原"
    else direction = "南方" end
    
    WebUI.title("当前位置")
    WebUI.write(string.format("  坐标: (%d, %d)", x, y))
    WebUI.write(string.format("  方位: %s", direction))
    
    -- 以 (364, 284) 为中心，计算方位
    local relX = x - 364
    local relY = y - 284
    WebUI.write(string.format("  相对中心: %s%d, %s%d",
        relX >= 0 and "东" or "西", math.abs(relX),
        relY >= 0 and "南" or "北", math.abs(relY)))
end
```

## SMAP 命令处理

### look — 场景描述

```lua
function SmapHandlers.look(args)
    local sceneId = tostring(JY.SubScene or 0)
    local scenes = getScenes()
    local scene = scenes and scenes[sceneId]
    
    if not scene then
        WebUI.write("无法获取场景信息")
        return
    end
    
    local name = scene["名称"] or "未知场景"
    
    WebUI.title(name)
    WebUI.write(getSceneTemplate(scene))  -- 使用场景模板生成描述
    WebUI.separator()
    
    -- NPC 列表
    local npcs = scene["NPC"]
    if npcs and #npcs > 0 then
        local charsIndex = getCharsIndex()
        local npcNames = {}
        for _, npc in ipairs(npcs) do
            local charId = tostring(npc["代号"] or npc)
            local char = charsIndex and charsIndex[charId]
            local charName = char and char["姓名"] or ("NPC?" .. charId)
            table.insert(npcNames, charName)
        end
        WebUI.write("NPC: " .. table.concat(npcNames, ", "))
    end
    
    -- 出口
    local exits = scene["出口"]
    if exits and #exits > 0 then
        local exitDirs = {}
        for _, exit in ipairs(exits) do
            local targetSceneId = tostring(exit["目标场景"] or "")
            local targetScene = scenes and scenes[targetSceneId]
            local targetName = targetScene and targetScene["名称"] or "?"
            table.insert(exitDirs, targetName)
        end
        WebUI.write("出口: " .. table.concat(exitDirs, ", "))
    end
    
    WebUI.write("输入 exits 查看出口详情，leave 回到大地图")
end
```

### exits — 出口列表

```lua
function SmapHandlers.exits(args)
    local sceneId = tostring(JY.SubScene or 0)
    local scenes = getScenes()
    local scene = scenes and scenes[sceneId]
    
    if not scene or not scene["出口"] or #scene["出口"] == 0 then
        WebUI.write("此场景没有出口")
        return
    end
    
    WebUI.title("出口")
    for _, exit in ipairs(scene["出口"]) do
        local targetSceneId = tostring(exit["目标场景"] or "")
        local targetScene = scenes and scenes[targetSceneId]
        local targetName = targetScene and targetScene["名称"] or "场景" .. targetSceneId
        WebUI.write(string.format("%d. %s", _, targetName))
    end
end
```

### go <编号> — 离开场景

```lua
function SmapHandlers.go(args)
    local dir = args and args[1]
    if not dir then
        SmapHandlers.exits({})
        return
    end
    
    local sceneId = tostring(JY.SubScene or 0)
    local scenes = getScenes()
    local scene = scenes and scenes[sceneId]
    
    if not scene or not scene["出口"] or #scene["出口"] == 0 then
        WebUI.write("此场景没有出口")
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
                WebUI.write(string.format("进入了 %s。\n", targetScene["名称"]))
                SmapHandlers.look({})
            else
                JY.Status = GAME_MMAP
                WebUI.write("你回到了大地图。\n")
                MmapHandlers.look({})
            end
        end
        return
    end
    
    WebUI.write(string.format("未找到出口: %s", dir))
    WebUI.write("输入 exits 查看可用出口")
end
```

### leave — 离开场景回到大地图

```lua
function SmapHandlers.leave(args)
    JY.Status = GAME_MMAP
    WebUI.write("你离开了当前场景，回到了大地图。\n")
    MmapHandlers.look({})
end
```

## 场景描述模板

对于没有场景描述数据的场景，使用模板生成：

```lua
local sceneTemplates = {
    ["客栈"] = "这是一间客栈，店小二正在忙碌地招呼客人。柜台后面摆满了酒坛。",
    ["民宅"] = "一间普通的民居，屋里陈设简单但整洁。",
    ["山洞"] = "洞口阴暗潮湿，往里看去一片漆黑。",
    ["门派"] = "一座气派的大门，门匾上写着「%s」。",
    ["商店"] = "店里货架上摆满了各种商品。",
    ["树林"] = "树木茂密，阳光透过树叶洒下斑驳的光影。",
}
```

## 注册到 CommandEngine

```lua
function registerMmapSmapCommands()
    CommandEngine.registerCommands(GAME_MMAP, {
        list = { handler = MmapHandlers.list, description = "列出所有可去场景" },
        go = { handler = MmapHandlers.go, description = "go <场景名> 传送到场景" },
        look = { handler = MmapHandlers.look, description = "查看当前位置描述" },
        where = { handler = MmapHandlers.where, description = "显示当前坐标和方位" },
        help = { handler = CommandEngine.showHelp, description = "显示帮助" },
        choose = { handler = CommandEngine.handleChoose, description = "choose <编号> 选择菜单项" },
    })
    
    CommandEngine.registerCommands(GAME_SMAP, {
        look = { handler = SmapHandlers.look, description = "查看场景描述" },
        exits = { handler = SmapHandlers.exits, description = "列出出口" },
        go = { handler = SmapHandlers.go, description = "go <编号> 前往出口" },
        leave = { handler = SmapHandlers.leave, description = "离开场景回到大地图" },
        help = { handler = CommandEngine.showHelp, description = "显示帮助" },
        choose = { handler = CommandEngine.handleChoose, description = "choose <编号> 选择菜单项" },
    })
end
```