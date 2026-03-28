-- war_async.lua
-- 战斗系统异步模块
-- 提供战斗系统的协程版本函数

local WarAsync = {}

local CoroutineScheduler = require("coroutine_scheduler")
local MenuAsync = require("menu_async")
local AsyncMessageBox = require("async_message_box")
local InputAsync = require("input_async")

-- 战斗状态
local warState = {
    warId = nil,
    isExp = 1,
    status = "idle",  -- idle, running, ended
    result = nil,     -- true=胜利, false=失败
    round = 0,
    currentPerson = 0,
}

-- 获取调度器实例
local function getScheduler()
    return CoroutineScheduler.getInstance()
end

-- 战斗主函数（协程版本）
-- @param warid: 战斗编号
-- @param isexp: 输后是否有经验
-- @return: true 战斗胜利, false 失败
function WarAsync.WarMainCoroutine(warid, isexp)
    lib.Debug(string.format("WarMainCoroutine: warid=%d, isexp=%d", warid, isexp or 1))
    
    -- 检查 CC 模块是否加载
    if not CC or not CC.WarData_S then
        lib.Debug("WarMainCoroutine: ERROR - CC.WarData_S not loaded")
        return false
    end
    
    lib.Debug("WarMainCoroutine: CC.WarDataSize=" .. tostring(CC.WarDataSize))
    
    warState.warId = warid
    warState.isExp = isexp or 1
    warState.status = "running"
    warState.result = nil
    warState.round = 0
    
    -- 初始化战斗
    lib.Debug("WarMainCoroutine: calling WarLoad")
    WarLoad(warid)
    
    lib.Debug("WarMainCoroutine: calling WarSelectTeam")
    WarSelectTeam()
    
    lib.Debug("WarMainCoroutine: calling WarSelectEnemy")
    WarSelectEnemy()
    
    lib.Debug("WarMainCoroutine: WarSelectEnemy done, WAR.PersonNum=" .. tostring(WAR.PersonNum))
    
    CleanMemory()
    lib.PicInit()
    lib.ShowSlow(50, 1)
    
    lib.Debug("WarMainCoroutine: calling WarLoadMap")
    WarLoadMap(WAR.Data["地图"])
    
    -- 设置状态为战斗
    local prevState = JY.Status
    JY.Status = GAME_WMAP
    
    -- 加载贴图文件
    lib.PicLoadFile(CC.WMAPPicFile[1], CC.WMAPPicFile[2], 0)
    lib.PicLoadFile(CC.HeadPicFile[1], CC.HeadPicFile[2], 1)
    if CC.LoadThingPic == 1 then
        lib.PicLoadFile(CC.ThingPicFile[1], CC.ThingPicFile[2], 2)
    end
    lib.PicLoadFile(CC.EffectFile[1], CC.EffectFile[2], 3)
    
    PlayMIDI(WAR.Data["音乐"])
    
    WarPersonSort()
    
    -- 加载战斗人物贴图
    for i = 0, WAR.PersonNum - 1 do
        local pid = WAR.Person[i]["人物编号"]
        lib.PicLoadFile(string.format(CC.FightPicFile[1], JY.Person[pid]["头像代号"]),
                        string.format(CC.FightPicFile[2], JY.Person[pid]["头像代号"]),
                        4 + i)
    end
    
    -- 战斗主循环
    local first = 0
    local warStatus = 0  -- 0=继续, 1=赢, 2=输
    
    while warStatus == 0 do
        -- 更新战斗人物
        for i = 0, WAR.PersonNum - 1 do
            WAR.Person[i]["贴图"] = WarCalPersonPic(i)
        end
        
        -- 计算移动步数
        for i = 0, WAR.PersonNum - 1 do
            local id = WAR.Person[i]["人物编号"]
            local move = math.modf(WAR.Person[i]["轻功"] / 15) - math.modf(JY.Person[id]["受伤程度"] / 40)
            if move < 0 then move = 0 end
            WAR.Person[i]["移动步数"] = move
        end
        
        WarSetPerson()
        
        -- 让出控制权
        CoroutineScheduler.getInstance():yield("battle_round_start")
        
        -- 每回合战斗循环
        local p = 0
        while p < WAR.PersonNum do
            WAR.Effect = 0
            
            -- 让出控制权，让渲染有机会执行
            CoroutineScheduler.getInstance():yield("battle_round")
            
            -- 处理自动战斗取消
            if WAR.AutoFight == 1 then
                local keypress = lib.GetKey()
                if keypress == VK_SPACE or keypress == VK_RETURN then
                    WAR.AutoFight = 0
                end
            end
            
            if WAR.Person[p]["死亡"] == false then
                WAR.CurID = p
                
                if first == 0 then
                    WarDrawMap(0)
                    lib.ShowSlow(50, 0)
                    first = 1
                end
                
                local r
                if WAR.Person[p]["我方"] == true then
                    if WAR.AutoFight == 0 then
                        r = War_ManualCoroutine()
                    else
                        r = War_AutoCoroutine()
                    end
                else
                    r = War_AutoCoroutine()
                end
                
                warStatus = War_isEnd()
                
                if math.abs(r) == 7 then
                    p = p - 1
                end
            end
            
            p = p + 1
            
            -- 每次人物行动后都让出控制权
            CoroutineScheduler.getInstance():yield("battle_person_done")
        end
        
        -- 回合结束处理
        if warStatus == 0 then
            War_PersonLostLife()
        end
    end
    
    -- 战斗结束
    War_SettlementCoroutine(warStatus)
    
    War_EndPersonData(warState.isExp, warStatus)
    
    -- 恢复状态
    JY.Status = prevState
    warState.status = "ended"
    warState.result = (warStatus == 1)
    
    return warState.result
end

-- 手动战斗（协程版本）
War_ManualCoroutine = function()
    local r
    while true do
        r = War_Manual_SubCoroutine()
        if math.abs(r) ~= 7 then
            break
        end
    end
    return r
end

-- 手动战斗菜单（协程版本）
War_Manual_SubCoroutine = function()
    local menu = {
        {"攻击", nil, 1},
        {"移动", nil, 1},
        {"用毒", nil, 1},
        {"解毒", nil, 1},
        {"医疗", nil, 1},
        {"物品", nil, 1},
        {"等待", nil, 1},
        {"状态", nil, 1},
        {"自动", nil, 1},
    }
    
    local pid = WAR.Person[WAR.CurID]["人物编号"]
    
    if JY.Person[pid]["内力"] < 0 or JY.Person[pid]["体力"] < 10 then
        AsyncMessageBox.ShowMessageCoroutine(-1, -1, "不能战斗", C_WHITE, CC.DefaultFont)
        return 7
    end
    
    local r = MenuAsync.ShowMenuCoroutine(menu, 9, 9, 0, 0, 0, 0, 1, 0, CC.DefaultFont, C_ORANGE, C_WHITE)
    
    if r == 0 then
        return 7
    end
    
    -- 处理菜单选择
    if r == 1 then
        -- 攻击
        return War_AttackCoroutine()
    elseif r == 2 then
        -- 移动
        return War_MoveCoroutine()
    elseif r == 6 then
        -- 物品
        War_ThingMenu()
        return 0
    elseif r == 7 then
        -- 等待
        War_WaitMenu()
        return 7
    elseif r == 8 then
        -- 状态
        War_StatusMenu()
        return 7
    elseif r == 9 then
        -- 自动
        War_AutoMenu()
        return 0
    end
end

-- 自动移动（协程版本）
-- 替换阻塞式的 War_AutoMove 函数
local War_AutoMoveCoroutine
War_AutoMoveCoroutine = function(wugongnum)
    local pid = WAR.Person[WAR.CurID]["人物编号"]
    local wugongid = JY.Person[pid]["武功" .. wugongnum]
    local level = math.modf(JY.Person[pid]["武功等级" .. wugongnum] / 100) + 1
    
    local wugongtype = JY.Wugong[wugongid]["攻击范围"]
    local movescope = JY.Wugong[wugongid]["移动范围" .. level]
    local fightscope = JY.Wugong[wugongid]["杀伤范围" .. level]
    local scope = movescope + fightscope
    
    local x, y
    local maxenemy = 0
    
    local movestep = War_CalMoveStep(WAR.CurID, WAR.Person[WAR.CurID]["移动步数"], 0)
    
    War_AutoCalMaxEnemyMap(wugongid, level)
    
    for i = 0, WAR.Person[WAR.CurID]["移动步数"] do
        local step_num = movestep[i].num
        if step_num == 0 then
            break
        end
        for j = 1, step_num do
            local xx = movestep[i].x[j]
            local yy = movestep[i].y[j]
            
            local num = 0
            if wugongtype == 0 or wugongtype == 2 or wugongtype == 3 then
                num = GetWarMap(xx, yy, 4)
            elseif wugongtype == 1 then
                local v = GetWarMap(xx, yy, 4)
                if v > 0 then
                    num = War_AutoCalMaxEnemy(xx, yy, wugongid, level)
                end
            end
            
            if num > maxenemy then
                maxenemy = num
                x = xx
                y = yy
            elseif num == maxenemy and num > 0 then
                if Rnd(3) == 0 then
                    maxenemy = num
                    x = xx
                    y = yy
                end
            end
        end
    end
    
    if maxenemy > 0 then
        War_CalMoveStep(WAR.CurID, WAR.Person[WAR.CurID]["移动步数"], 0)
        War_MovePersonCoroutine(x, y)
        return 1
    else
        x, y = War_GetCanFightEnemyXY(scope)
        
        if x == nil then
            local enemyid = War_AutoSelectEnemy()
            War_CalMoveStep(WAR.CurID, 100, 0)
            
            local minDest = math.huge
            for i = 0, (CC.WarWidth or 10) - 1 do
                for j = 0, (CC.WarHeight or 10) - 1 do
                    local dest = GetWarMap(i, j, 3)
                    if dest < 128 then
                        local dx = math.abs(i - WAR.Person[enemyid]["坐标X"])
                        local dy = math.abs(j - WAR.Person[enemyid]["坐标Y"])
                        if minDest > (dx + dy) then
                            minDest = dx + dy
                            x = i
                            y = j
                        elseif minDest == (dx + dy) then
                            if Rnd(2) == 0 then
                                x = i
                                y = j
                            end
                        end
                    end
                end
            end
        else
            local minDest = 0
        end
        
        if x and y then
            while true do
                local i = GetWarMap(x, y, 3)
                if i <= WAR.Person[WAR.CurID]["移动步数"] then
                    break
                end
                
                if GetWarMap(x - 1, y, 3) == i - 1 then
                    x = x - 1
                elseif GetWarMap(x + 1, y, 3) == i - 1 then
                    x = x + 1
                elseif GetWarMap(x, y - 1, 3) == i - 1 then
                    y = y - 1
                elseif GetWarMap(x, y + 1, 3) == i - 1 then
                    y = y + 1
                end
            end
            War_MovePersonCoroutine(x, y)
        end
    end
    
    return 0
end

-- 自动战斗（协程版本）
War_AutoCoroutine = function()
    local id = WAR.CurID
    local pid = WAR.Person[id]["人物编号"]
    
    -- 简单AI：先移动再攻击
    local wugongnum = 1
    for i = 1, 10 do
        if JY.Person[pid]["武功" .. i] and JY.Person[pid]["武功" .. i] > 0 then
            wugongnum = i
            break
        end
    end
    
    -- 自动移动
    local moveResult = War_AutoMoveCoroutine(wugongnum)
    
    -- 选择目标
    local targetId = -1
    for i = 0, WAR.PersonNum - 1 do
        if WAR.Person[i]["死亡"] == false and WAR.Person[i]["我方"] == false then
            targetId = i
            break
        end
    end
    
    if targetId < 0 then
        return 0
    end
    
    -- 执行攻击（异步版本）
    War_Fight_SubCoroutine(id, wugongnum, targetId, targetId)
    
    return 0
end

-- 战斗结算（协程版本）
War_SettlementCoroutine = function(warStatus)
    local scheduler = CoroutineScheduler.getInstance()
    
    if warStatus == 1 then
        -- 胜利
        AsyncMessageBox.ShowMessageCoroutine(-1, -1, "战斗胜利", C_WHITE, CC.DefaultFont)
        
        -- 分配经验
        for i = 0, WAR.PersonNum - 1 do
            if WAR.Person[i]["我方"] == true and WAR.Person[i]["死亡"] == false then
                local pid = WAR.Person[i]["人物编号"]
                local exp = WAR.Person[i]["经验"] or 0
                
                AddPersonAttrib(pid, "经验值", exp)
                
                -- 检查升级
                local newExp = JY.Person[pid]["经验值"]
                local levelUpExp = JY.Person[pid]["等级"] * 100
                
                if newExp >= levelUpExp then
                    JY.Person[pid]["等级"] = JY.Person[pid]["等级"] + 1
                    JY.Person[pid]["经验值"] = newExp - levelUpExp
                    AsyncMessageBox.ShowMessageCoroutine(-1, -1, 
                        JY.Person[pid]["姓名"] .. " 升级了！", C_WHITE, CC.DefaultFont)
                end
            end
        end
    else
        -- 失败
        AsyncMessageBox.ShowMessageCoroutine(-1, -1, "战斗失败", C_WHITE, CC.DefaultFont)
    end
end

-- 攻击选择（协程版本）
War_AttackCoroutine = function()
    local pid = WAR.Person[WAR.CurID]["人物编号"]
    
    -- 获取可用的武功列表
    local menu = {}
    local wugongCount = 0
    
    for i = 1, 10 do
        local wugongid = JY.Person[pid]["武功" .. i]
        if wugongid and wugongid > 0 then
            local level = JY.Person[pid]["武功等级" .. i] or 0
            table.insert(menu, {JY.Wugong[wugongid]["名称"], nil, 1, wugongid})
            wugongCount = wugongCount + 1
        end
    end
    
    if wugongCount == 0 then
        AsyncMessageBox.ShowMessageCoroutine(-1, -1, "没有可用的武功", C_WHITE, CC.DefaultFont)
        return 7
    end
    
    local r = MenuAsync.ShowMenuCoroutine(menu, wugongCount, wugongCount, 
        0, 0, 0, 0, 1, 0, CC.DefaultFont, C_ORANGE, C_WHITE)
    
    if r == 0 then
        return 7
    end
    
    local wugongid = menu[r][4]
    local wugongtype = JY.Wugong[wugongid]["类型"]
    
    -- 选择目标
    local targetId = SelectTargetCoroutine()
    if targetId < 0 then
        return 7
    end
    
    -- 执行攻击（异步版本）
    War_Fight_SubCoroutine(WAR.CurID, r - 1, targetId, targetId)
    
    return 0
end

-- 执行战斗（协程版本）
-- 替换阻塞式的 War_Fight_Sub 函数
local War_Fight_SubCoroutine
War_Fight_SubCoroutine = function(id, wugongnum, x, y)
    local scheduler = CoroutineScheduler.getInstance()
    local pid = WAR.Person[id]["人物编号"]
    local wugong = JY.Person[pid]["武功" .. wugongnum]
    local level = math.modf(JY.Person[pid]["武功等级" .. wugongnum] / 100) + 1
    
    CleanWarMap(4, 0)
    
    local fightscope = JY.Wugong[wugong]["攻击范围"]
    
    if fightscope == 0 then
        if War_FightSelectType0(wugong, level, x, y) == false then
            return 0
        end
    elseif fightscope == 1 then
        War_FightSelectType1(wugong, level, x, y)
    elseif fightscope == 2 then
        War_FightSelectType2(wugong, level, x, y)
    elseif fightscope == 3 then
        if War_FightSelectType3(wugong, level, x, y) == false then
            return 0
        end
    end
    
    local fightnum = 1
    if JY.Person[pid]["左右互搏"] == 1 then
        fightnum = 2
    end
    
    for k = 1, fightnum do
        for i = 0, (CC.WarWidth or 10) - 1 do
            for j = 0, (CC.WarHeight or 10) - 1 do
                local effect = GetWarMap(i, j, 4)
                if effect > 0 then
                    local emeny = GetWarMap(i, j, 2)
                    if emeny >= 0 then
                        if WAR.Person[WAR.CurID]["我方"] ~= WAR.Person[emeny]["我方"] then
                            if JY.Wugong[wugong]["伤害类型"] == 1 and (fightscope == 0 or fightscope == 3) then
                                WAR.Person[emeny]["点数"] = -War_WugongHurtNeili(emeny, wugong, level)
                                SetWarMap(i, j, 4, 3)
                                WAR.Effect = 3
                            else
                                WAR.Person[emeny]["点数"] = -War_WugongHurtLife(emeny, wugong, level)
                                WAR.Effect = 2
                                SetWarMap(i, j, 4, 2)
                            end
                        end
                    end
                end
            end
        end
        
        War_ShowFightCoroutine(pid, wugong, JY.Wugong[wugong]["类型"], level, x, y, JY.Wugong[wugong]["武功动画&音效"])
        
        for i = 0, WAR.PersonNum - 1 do
            WAR.Person[i]["点数"] = 0
        end
        
        WAR.Person[WAR.CurID]["经验"] = WAR.Person[WAR.CurID]["经验"] + 2
        
        if JY.Person[pid]["武功等级" .. wugongnum] < 900 then
            JY.Person[pid]["武功等级" .. wugongnum] = JY.Person[pid]["武功等级" .. wugongnum] + Rnd(2) + 1
        end
        
        if math.modf(JY.Person[pid]["武功等级" .. wugongnum] / 100) + 1 ~= level then
            level = math.modf(JY.Person[pid]["武功等级" .. wugongnum] / 100) + 1
            AsyncMessageBox.ShowMessageCoroutine(-1, -1, 
                JY.Wugong[wugong]["名称"] .. " 升为 " .. level .. " 级", C_ORANGE, CC.DefaultFont)
        end
        
        AddPersonAttrib(pid, "内力", -math.modf((level + 1) / 2) * JY.Wugong[wugong]["消耗内力点数"])
    end
    
    AddPersonAttrib(pid, "体力", -3)
    
    return 1
end

-- 选择目标（协程版本）
SelectTargetCoroutine = function()
    -- 获取敌方列表
    local targets = {}
    for i = 0, WAR.PersonNum - 1 do
        if WAR.Person[i]["死亡"] == false and WAR.Person[i]["我方"] == false then
            table.insert(targets, {JY.Person[WAR.Person[i]["人物编号"]]["姓名"], nil, 1, i})
        end
    end
    
    if #targets == 0 then
        return -1
    end
    
    if #targets == 1 then
        return targets[1][4]
    end
    
    local r = MenuAsync.ShowMenuCoroutine(targets, #targets, #targets,
        0, 0, 0, 0, 1, 0, CC.DefaultFont, C_ORANGE, C_WHITE)
    
    if r == 0 then
        return -1
    end
    
    return targets[r][4]
end

-- 移动选择（协程版本）
War_MoveCoroutine = function()
    local move = WAR.Person[WAR.CurID]["移动步数"]
    if move <= 0 then
        AsyncMessageBox.ShowMessageCoroutine(-1, -1, "不能移动", C_WHITE, CC.DefaultFont)
        return 7
    end
    
    -- 计算移动范围
    War_CalMoveStep(WAR.CurID, move, 0)
    
    -- 简化实现：显示移动范围，等待用户选择位置
    local x = WAR.Person[WAR.CurID]["坐标X"]
    local y = WAR.Person[WAR.CurID]["坐标Y"]
    
    -- 方向选择菜单
    local menu = {
        {"上", nil, 1},
        {"下", nil, 1},
        {"左", nil, 1},
        {"右", nil, 1},
        {"取消", nil, 1},
    }
    
    local r = MenuAsync.ShowMenuCoroutine(menu, 5, 5, 0, 0, 0, 0, 1, 0, CC.DefaultFont, C_ORANGE, C_WHITE)
    
    if r == 0 or r == 5 then
        return 7
    end
    
    local dx, dy = 0, 0
    if r == 1 then dy = -1
    elseif r == 2 then dy = 1
    elseif r == 3 then dx = -1
    elseif r == 4 then dx = 1
    end
    
    local newX = x + dx
    local newY = y + dy
    
    -- 检查是否可以移动
    if GetWarMap(newX, newY, 2) == 0 then
        -- 使用异步移动函数，带动画效果
        War_MovePersonCoroutine(newX, newY)
    else
        AsyncMessageBox.ShowMessageCoroutine(-1, -1, "无法移动到该位置", C_WHITE, CC.DefaultFont)
    end
    
    return 0
end

-- 异步移动人物（协程版本）
-- 替换阻塞式的 War_MovePerson 函数
local War_MovePersonCoroutine
War_MovePersonCoroutine = function(x, y)
    local scheduler = CoroutineScheduler.getInstance()
    
    local movenum = GetWarMap(x, y, 3)
    WAR.Person[WAR.CurID]["移动步数"] = WAR.Person[WAR.CurID]["移动步数"] - movenum
    
    local movetable = {}
    local cx, cy = x, y
    
    for i = movenum, 1, -1 do
        movetable[i] = {}
        movetable[i].x = cx
        movetable[i].y = cy
        
        if GetWarMap(cx - 1, cy, 3) == i - 1 then
            cx = cx - 1
            movetable[i].direct = 1
        elseif GetWarMap(cx + 1, cy, 3) == i - 1 then
            cx = cx + 1
            movetable[i].direct = 2
        elseif GetWarMap(cx, cy - 1, 3) == i - 1 then
            cy = cy - 1
            movetable[i].direct = 3
        elseif GetWarMap(cx, cy + 1, 3) == i - 1 then
            cy = cy + 1
            movetable[i].direct = 0
        end
    end
    
    local frameTime = (CC.Frame or 50) / 1000
    
    for i = 1, movenum do
        SetWarMap(WAR.Person[WAR.CurID]["坐标X"], WAR.Person[WAR.CurID]["坐标Y"], 2, -1)
        SetWarMap(WAR.Person[WAR.CurID]["坐标X"], WAR.Person[WAR.CurID]["坐标Y"], 5, -1)
        
        WAR.Person[WAR.CurID]["坐标X"] = movetable[i].x
        WAR.Person[WAR.CurID]["坐标Y"] = movetable[i].y
        WAR.Person[WAR.CurID]["人方向"] = movetable[i].direct
        WAR.Person[WAR.CurID]["贴图"] = WarCalPersonPic(WAR.CurID)
        
        SetWarMap(WAR.Person[WAR.CurID]["坐标X"], WAR.Person[WAR.CurID]["坐标Y"], 2, WAR.CurID)
        SetWarMap(WAR.Person[WAR.CurID]["坐标X"], WAR.Person[WAR.CurID]["坐标Y"], 5, WAR.Person[WAR.CurID]["贴图"])
        
        WarDrawMap(0)
        
        if i < movenum then
            scheduler:waitForTime(frameTime)
        end
    end
end

-- 显示战斗动画（协程版本）
War_ShowFightCoroutine = function(pid, wugong, wugongtype, level, x, y, eft)
    local scheduler = CoroutineScheduler.getInstance()
    
    local x0 = WAR.Person[WAR.CurID]["坐标X"]
    local y0 = WAR.Person[WAR.CurID]["坐标Y"]
    
    local fightdelay, fightframe, sounddelay
    if wugongtype >= 0 then
        fightdelay = JY.Person[pid]["出招动画延迟" .. wugongtype + 1] or 0
        fightframe = JY.Person[pid]["出招动画帧数" .. wugongtype + 1] or 0
        sounddelay = JY.Person[pid]["武功音效延迟" .. wugongtype + 1] or 0
    else
        fightdelay = 0
        fightframe = -1
        sounddelay = -1
    end
    
    local framenum = fightdelay + (CC.Effect and CC.Effect[eft] or 10) or 10
    
    local startframe = 0
    if wugongtype >= 0 then
        for i = 0, wugongtype - 1 do
            startframe = startframe + 4 * (JY.Person[pid]["出招动画帧数" .. i + 1] or 0)
        end
    end
    
    local starteft = 0
    if CC.Effect then
        for i = 0, eft - 1 do
            starteft = starteft + (CC.Effect[i] or 0)
        end
    end
    
    WAR.Person[WAR.CurID]["贴图类型"] = 0
    WAR.Person[WAR.CurID]["贴图"] = WarCalPersonPic(WAR.CurID)
    
    WarSetPerson()
    WarDrawMap(0)
    
    local frameTime = (CC.Frame or 50) / 1000
    
    for i = 0, framenum - 1 do
        local mytype
        if fightframe > 0 then
            WAR.Person[WAR.CurID]["贴图类型"] = 1
            mytype = 4 + WAR.CurID
            if i < fightframe then
                WAR.Person[WAR.CurID]["贴图"] = (startframe + WAR.Person[WAR.CurID]["人方向"] * fightframe + i) * 2
            end
        else
            WAR.Person[WAR.CurID]["贴图类型"] = 0
            WAR.Person[WAR.CurID]["贴图"] = WarCalPersonPic(WAR.CurID)
            mytype = 0
        end
        
        if i == sounddelay and JY.Wugong[wugong] then
            PlayWavAtk(JY.Wugong[wugong]["出招音效"])
        end
        if i == fightdelay then
            PlayWavE(eft)
        end
        
        WarDrawMap(0)
        scheduler:waitForTime(frameTime)
    end
    
    WAR.Person[WAR.CurID]["贴图类型"] = 0
    WAR.Person[WAR.CurID]["贴图"] = WarCalPersonPic(WAR.CurID)
end

-- 导出函数
WarAsync.War_ManualCoroutine = War_ManualCoroutine
WarAsync.War_AutoCoroutine = War_AutoCoroutine
WarAsync.War_SettlementCoroutine = War_SettlementCoroutine
WarAsync.War_AttackCoroutine = War_AttackCoroutine
WarAsync.SelectTargetCoroutine = SelectTargetCoroutine
WarAsync.War_MoveCoroutine = War_MoveCoroutine
WarAsync.War_ShowFightCoroutine = War_ShowFightCoroutine
WarAsync.War_Manual_SubCoroutine = War_Manual_SubCoroutine
WarAsync.War_MovePersonCoroutine = War_MovePersonCoroutine
WarAsync.War_Fight_SubCoroutine = War_Fight_SubCoroutine
WarAsync.War_AutoMoveCoroutine = War_AutoMoveCoroutine

-- 获取战斗状态
function WarAsync.getWarState()
    return warState
end

-- 重置战斗状态
function WarAsync.reset()
    warState = {
        warId = nil,
        isExp = 1,
        status = "idle",
        result = nil,
        round = 0,
        currentPerson = 0,
    }
end

return WarAsync