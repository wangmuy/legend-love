-- 战斗物品菜单（协程版本）
War_ThingMenuCoroutine = function()
    local scheduler = CoroutineScheduler.getInstance()
    
    WAR.ShowHead = 0
    
    -- 收集可用的战斗物品（药品和暗器）
    local thing = {}
    local thingnum = {}
    local num = 0
    
    for i = 0, CC.MyThingNum - 1 do
        local id = JY.Base["物品" .. i + 1]
        if id >= 0 then
            local thingType = JY.Thing[id]["类型"]
            if thingType == 3 or thingType == 4 then  -- 药品或暗器
                thing[num] = id
                thingnum[num] = JY.Base["物品数量" .. i + 1]
                num = num + 1
            end
        end
    end
    
    if num == 0 then
        WAR.ShowHead = 1
        return 7  -- 没有物品，继续菜单
    end
    
    -- 构建物品菜单
    local menu = {}
    for i = 0, num - 1 do
        local name = JY.Thing[thing[i]]["名称"]
        menu[i + 1] = {string.format("%s X%d", name, thingnum[i]), nil, 1, thing[i]}
    end
    
    local r = MenuAsync.ShowMenuCoroutine(menu, num, 0, CC.MainSubMenuX, CC.MainSubMenuY, 0, 0, 1, 1, CC.DefaultFont, C_ORANGE, C_WHITE)
    
    Cls()
    
    if r <= 0 then
        WAR.ShowHead = 1
        return 7  -- ESC取消，继续菜单
    end
    
    local thingId = menu[r][4]
    local thingType = JY.Thing[thingId]["类型"]
    local useResult = 0
    
    if thingType == 3 then
        -- 药品：直接对当前战斗人物使用
        local pid = WAR.Person[WAR.CurID]["人物编号"]
        
        -- 调用原版的 UseThingEffect
        if UseThingEffect(thingId, pid) == 1 then
            instruct_32(thingId, -1)  -- 减少物品数量
            useResult = 1
            WaitKey()
        end
    elseif thingType == 4 then
        -- 暗器：调用战斗暗器协程
        useResult = War_ExecuteMenuCoroutine(4, thingId)
    end
    
    WAR.ShowHead = 1
    Cls()
    
    if useResult == 1 then
        return 0  -- 使用成功，结束回合
    else
        return 7  -- 使用失败或无效果，继续菜单
    end
end
