-- war_async.lua
-- 战斗系统异步模块
-- 提供战斗系统的协程版本函数

local WarAsync = {}

local CoroutineScheduler = require("coroutine_scheduler")
local MenuAsync = require("menu_async")
local AsyncMessageBox = require("async_message_box")
local InputAsync = require("input_async")
local PersonStatusAsync = require("person_status_async")

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

-- 前向声明（只声明一次，避免重复）
local War_ManualCoroutine, War_AutoCoroutine, War_SettlementCoroutine
local War_AttackCoroutine, War_MoveCoroutine, SelectTargetCoroutine
local War_Manual_SubCoroutine, War_ShowFightCoroutine
local War_Fight_SubCoroutine, War_MovePersonCoroutine, War_AutoMoveCoroutine
local War_PoisonCoroutine, War_DecPoisonCoroutine, War_DoctorCoroutine
local War_ExecuteMenuCoroutine, War_Fight_ExecuteCoroutine, SelectTargetCoroutine
local War_ExecuteMenu_SubCoroutine, War_ThingMenuCoroutine, War_StatusMenuCoroutine

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
    
    -- 设置状态为战斗（在初始化完成后）
    local prevState = JY.Status
    JY.Status = GAME_WMAP
    
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
            lib.Debug("battle: person " .. p .. " next, WAR.CurID=" .. WAR.CurID)
            
            -- 每次人物行动后都让出控制权
            CoroutineScheduler.getInstance():yield("battle_person_done")
            lib.Debug("battle: after yield, p=" .. p)
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
    local pid = WAR.Person[WAR.CurID]["人物编号"]
    
    -- 菜单项：与原版顺序一致
    local menu = {
        {"移动", nil, 1},
        {"攻击", nil, 1},
        {"用毒", nil, 1},
        {"解毒", nil, 1},
        {"医疗", nil, 1},
        {"物品", nil, 1},
        {"等待", nil, 1},
        {"状态", nil, 1},
        {"休息", nil, 1},
        {"自动", nil, 1},
    }
    
    -- 检查是否可以移动
    if JY.Person[pid]["体力"] <= 5 or WAR.Person[WAR.CurID]["移动步数"] <= 0 then
        menu[1][3] = 0
    end
    
    -- 检查是否可以攻击
    local minv = War_GetMinNeiLi(pid)
    if JY.Person[pid]["内力"] < minv or JY.Person[pid]["体力"] < 10 then
        menu[2][3] = 0
    end
    
    -- 检查是否可以用毒
    if JY.Person[pid]["体力"] < 10 or JY.Person[pid]["用毒能力"] < 20 then
        menu[3][3] = 0
    end
    
    -- 检查是否可以解毒
    if JY.Person[pid]["体力"] < 10 or JY.Person[pid]["解毒能力"] < 20 then
        menu[4][3] = 0
    end
    
    -- 检查是否可以医疗
    if JY.Person[pid]["体力"] < 50 or JY.Person[pid]["医疗能力"] < 20 then
        menu[5][3] = 0
    end
    
    local r = MenuAsync.ShowMenuCoroutine(menu, 10, 0, CC.MainMenuX, CC.MainMenuY, 0, 0, 1, 0, CC.DefaultFont, C_ORANGE, C_WHITE)
    
    if r == 0 then
        return 7
    end
    
    -- 处理菜单选择
    if r == 1 then
        -- 移动
        return War_MoveCoroutine()
    elseif r == 2 then
        -- 攻击
        return War_AttackCoroutine()
    elseif r == 3 then
        -- 用毒
        return War_PoisonCoroutine()
    elseif r == 4 then
        -- 解毒
        return War_DecPoisonCoroutine()
    elseif r == 5 then
        -- 医疗
        return War_DoctorCoroutine()
    elseif r == 6 then
        -- 物品
        return War_ThingMenuCoroutine()
    elseif r == 7 then
        -- 等待（把当前人物调到队尾，稍后行动）
        War_WaitMenu()
        return 7
    elseif r == 8 then
        -- 状态
        War_StatusMenuCoroutine()
        return 7
    elseif r == 9 then
        -- 休息（结束当前人物行动）
        War_RestMenu()
        return 0
    elseif r == 10 then
        -- 自动
        War_AutoMenu()
        return 0
    end
    
    return 7
end

-- 自动移动（协程版本）
-- 替换阻塞式的 War_AutoMove 函数
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
    
    local wugongnum = 1
    for i = 1, 10 do
        if JY.Person[pid]["武功" .. i] and JY.Person[pid]["武功" .. i] > 0 then
            wugongnum = i
            break
        end
    end
    
    War_AutoMoveCoroutine(wugongnum)
    
    local wugongid = JY.Person[pid]["武功" .. wugongnum]
    local level = math.modf(JY.Person[pid]["武功等级" .. wugongnum] / 100) + 1
    local x0 = WAR.Person[WAR.CurID]["坐标X"]
    local y0 = WAR.Person[WAR.CurID]["坐标Y"]
    
    local maxnum, x, y = War_AutoCalMaxEnemy(x0, y0, wugongid, level)
    
    if x ~= nil then
        War_Fight_SubCoroutine(WAR.CurID, wugongnum, x, y)
    end
    
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

-- 选择攻击目标（在地图上选择，协程版本）
-- 返回 x, y 或 "line", direct 或 nil（取消）
local SelectAttackTargetCoroutine = function(wugong, level)
    local scheduler = CoroutineScheduler.getInstance()
    local pid = WAR.Person[WAR.CurID]["人物编号"]
    local fightscope = JY.Wugong[wugong]["攻击范围"]
    local moverange = JY.Wugong[wugong]["移动范围" .. level]
    
    local x0 = WAR.Person[WAR.CurID]["坐标X"]
    local y0 = WAR.Person[WAR.CurID]["坐标Y"]
    
    if fightscope == 0 or fightscope == 3 then
        War_CalMoveStep(WAR.CurID, moverange, 1)
    elseif fightscope == 1 then
        AsyncMessageBox.ShowMessageCoroutine(-1, -1, "请选择攻击方向", C_ORANGE, CC.DefaultFont)
    end
    
    local x, y = x0, y0
    
    WAR.DrawMode = 3
    WAR.MoveCursorX = x
    WAR.MoveCursorY = y
    
    while true do
        WAR.MoveCursorX = x
        WAR.MoveCursorY = y
        
        local key = InputAsync.WaitKeyCoroutine()
        
        local x2, y2 = x, y
        
        if key == VK_UP then
            if fightscope == 1 then
                WAR.DrawMode = nil
                WAR.MoveCursorX = nil
                WAR.MoveCursorY = nil
                return "line", 0
            else
                y2 = y - 1
            end
        elseif key == VK_DOWN then
            if fightscope == 1 then
                WAR.DrawMode = nil
                WAR.MoveCursorX = nil
                WAR.MoveCursorY = nil
                return "line", 3
            else
                y2 = y + 1
            end
        elseif key == VK_LEFT then
            if fightscope == 1 then
                WAR.DrawMode = nil
                WAR.MoveCursorX = nil
                WAR.MoveCursorY = nil
                return "line", 2
            else
                x2 = x - 1
            end
        elseif key == VK_RIGHT then
            if fightscope == 1 then
                WAR.DrawMode = nil
                WAR.MoveCursorX = nil
                WAR.MoveCursorY = nil
                return "line", 1
            else
                x2 = x + 1
            end
        elseif key == VK_SPACE or key == VK_RETURN then
            if fightscope == 2 then
                WAR.DrawMode = nil
                WAR.MoveCursorX = nil
                WAR.MoveCursorY = nil
                return x0, y0
            elseif x ~= x0 or y ~= y0 then
                WAR.DrawMode = nil
                WAR.MoveCursorX = nil
                WAR.MoveCursorY = nil
                return x, y
            end
        elseif key == VK_ESCAPE then
            WAR.DrawMode = nil
            WAR.MoveCursorX = nil
            WAR.MoveCursorY = nil
            return nil
        end
        
        if fightscope == 0 or fightscope == 3 then
            if GetWarMap(x2, y2, 3) < 128 then
                x, y = x2, y2
            end
        end
    end
end

-- 攻击选择（协程版本）
War_AttackCoroutine = function()
    local pid = WAR.Person[WAR.CurID]["人物编号"]
    
    local menu = {}
    local wugongCount = 0
    
    for i = 1, 10 do
        local wugongid = JY.Person[pid]["武功" .. i]
        if wugongid and wugongid > 0 then
            local enabled = 1
            if JY.Wugong[wugongid]["消耗内力点数"] > JY.Person[pid]["内力"] then
                enabled = 0
            end
            table.insert(menu, {JY.Wugong[wugongid]["名称"], nil, enabled, wugongid, i})
            wugongCount = wugongCount + 1
        end
    end
    
    if wugongCount == 0 then
        return 7
    end
    
    local r
    if wugongCount == 1 then
        r = 1
    else
        r = MenuAsync.ShowMenuCoroutine(menu, wugongCount, wugongCount, 
            CC.MainSubMenuX, CC.MainSubMenuY, 0, 0, 1, 1, CC.DefaultFont, C_ORANGE, C_WHITE)
    end
    
    if r == 0 then
        return 7
    end
    
    local wugongid = menu[r][4]
    local wugongnum = menu[r][5]
    local level = math.modf(JY.Person[pid]["武功等级" .. wugongnum] / 100) + 1
    local fightscope = JY.Wugong[wugongid]["攻击范围"]
    local x0 = WAR.Person[WAR.CurID]["坐标X"]
    local y0 = WAR.Person[WAR.CurID]["坐标Y"]
    
    WAR.ShowHead = 0
    
    local tx, ty = SelectAttackTargetCoroutine(wugongid, level)
    
    if tx == nil then
        WAR.ShowHead = 1
        return 7
    end
    
    CleanWarMap(4, 0)
    
    local attackX, attackY = nil, nil
    
    if fightscope == 0 then
        if War_FightSelectType0(wugongid, level, tx, ty) == false then
            WAR.ShowHead = 1
            return 7
        end
        attackX, attackY = tx, ty
    elseif fightscope == 1 then
        local direct = ty
        WAR.Person[WAR.CurID]["人方向"] = direct
        local move = JY.Wugong[wugongid]["移动范围" .. level]
        WAR.EffectXY = {}
        for i = 1, move do
            if direct == 0 then
                SetWarMap(x0, y0 - i, 4, 1)
            elseif direct == 3 then
                SetWarMap(x0, y0 + i, 4, 1)
            elseif direct == 2 then
                SetWarMap(x0 - i, y0, 4, 1)
            elseif direct == 1 then
                SetWarMap(x0 + i, y0, 4, 1)
            end
        end
        if direct == 0 then
            WAR.EffectXY[1] = {x0, y0 - 1}
            WAR.EffectXY[2] = {x0, y0 - move}
        elseif direct == 3 then
            WAR.EffectXY[1] = {x0, y0 + 1}
            WAR.EffectXY[2] = {x0, y0 + move}
        elseif direct == 2 then
            WAR.EffectXY[1] = {x0 - 1, y0}
            WAR.EffectXY[2] = {x0 - move, y0}
        elseif direct == 1 then
            WAR.EffectXY[1] = {x0 + 1, y0}
            WAR.EffectXY[2] = {x0 + move, y0}
        end
        attackX, attackY = x0, y0
    elseif fightscope == 2 then
        War_FightSelectType2(wugongid, level)
        attackX, attackY = tx, ty
    elseif fightscope == 3 then
        if War_FightSelectType3(wugongid, level, tx, ty) == false then
            WAR.ShowHead = 1
            return 7
        end
        attackX, attackY = tx, ty
    end
    
    War_Fight_ExecuteCoroutine(wugongnum, wugongid, level, attackX, attackY)
    
    WAR.ShowHead = 1
    return 0
end

-- 执行攻击伤害计算和动画（协程版本）
War_Fight_ExecuteCoroutine = function(wugongnum, wugong, level, x, y)
    local scheduler = CoroutineScheduler.getInstance()
    local pid = WAR.Person[WAR.CurID]["人物编号"]
    local fightscope = JY.Wugong[wugong]["攻击范围"]
    
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
        
        War_ShowFightCoroutine(pid, wugong, JY.Wugong[wugong]["武功类型"], level, x, y, JY.Wugong[wugong]["武功动画&音效"])
        
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

-- 执行战斗（协程版本）
-- 替换阻塞式的 War_Fight_Sub 函数
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
        
        War_ShowFightCoroutine(pid, wugong, JY.Wugong[wugong]["武功类型"], level, x, y, JY.Wugong[wugong]["武功动画&音效"])
        
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
-- 按照原版 War_SelectMove 实现
War_MoveCoroutine = function()
    local scheduler = CoroutineScheduler.getInstance()
    
    local move = WAR.Person[WAR.CurID]["移动步数"]
    lib.Debug("War_MoveCoroutine: move=" .. tostring(move))
    
    if move == nil or move <= 0 then
        AsyncMessageBox.ShowMessageCoroutine(-1, -1, "不能移动", C_WHITE, CC.DefaultFont)
        return 7
    end
    
    WAR.ShowHead = 0
    
    -- 计算移动范围
    War_CalMoveStep(WAR.CurID, move, 0)
    
    -- 获取当前位置
    local x0 = WAR.Person[WAR.CurID]["坐标X"]
    local y0 = WAR.Person[WAR.CurID]["坐标Y"]
    local x, y = x0, y0
    
    -- 设置移动选择模式（供 draw 函数使用）
    WAR.DrawMode = 1
    WAR.MoveCursorX = x
    WAR.MoveCursorY = y
    
    lib.Debug("War_MoveCoroutine: set DrawMode=1, cursor=(" .. x .. "," .. y .. ")")
    
    lib.Debug("War_MoveCoroutine: start at (" .. x .. "," .. y .. ")")
    
    -- 循环等待用户选择移动位置
    while true do
        -- 更新光标位置
        WAR.MoveCursorX = x
        WAR.MoveCursorY = y
        
        -- 等待按键（绘制由 game_states.lua 的 draw 函数处理）
        local key = InputAsync.WaitKeyCoroutine()
        
        lib.Debug("War_MoveCoroutine: key=" .. key .. " at (" .. x .. "," .. y .. ")")
        
        local x2, y2 = x, y
        
        if key == VK_UP then
            y2 = y - 1
        elseif key == VK_DOWN then
            y2 = y + 1
        elseif key == VK_LEFT then
            x2 = x - 1
        elseif key == VK_RIGHT then
            x2 = x + 1
        elseif key == VK_SPACE or key == VK_RETURN then
            -- 确认移动
            if x == x0 and y == y0 then
                -- 没有移动，返回取消
                WAR.DrawMode = nil
                WAR.MoveCursorX = nil
                WAR.MoveCursorY = nil
                return 7
            end
            
            lib.Debug("War_MoveCoroutine: confirm move to (" .. x .. "," .. y .. ")")
            WAR.DrawMode = nil
            WAR.MoveCursorX = nil
            WAR.MoveCursorY = nil
            War_MovePersonCoroutine(x, y)
            return 7
        elseif key == VK_ESCAPE then
            -- 取消
            lib.Debug("War_MoveCoroutine: cancelled")
            WAR.DrawMode = nil
            WAR.MoveCursorX = nil
            WAR.MoveCursorY = nil
            return 7
        end
        
        -- 检查新位置是否可移动（地图层3小于128表示可达）
        if GetWarMap(x2, y2, 3) < 128 then
            x, y = x2, y2
            lib.Debug("War_MoveCoroutine: move cursor to (" .. x .. "," .. y .. ")")
        end
    end
end

-- 异步移动人物（协程版本）
-- 替换阻塞式的 War_MovePerson 函数
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
    
    local wugongtype = wugongtype or 0
    
    if wugong and JY.Wugong[wugong] then
        lib.Debug(string.format("War_ShowFightCoroutine: 武功名称='%s'", JY.Wugong[wugong]["名称"] or "未知"))
    end
    
    lib.Debug(string.format("War_ShowFightCoroutine: person name=%s, direction=%d", 
        JY.Person[pid]["姓名"], WAR.Person[WAR.CurID]["人方向"]))
    
    lib.Debug(string.format("War_ShowFightCoroutine: pid=%d, wugong=%s, 原始wugongtype=%d", 
        pid, tostring(wugong), wugongtype))
    
    local fightdelay, fightframe, sounddelay
    if wugongtype >= 0 then
        lib.Debug(string.format("War_ShowFightCoroutine: checking frames for type %d", wugongtype + 1))
        for t = 1, 5 do
            local f = JY.Person[pid]["出招动画帧数" .. t]
            lib.Debug(string.format("  出招动画帧数%d = %s", t, tostring(f)))
        end
        
        fightframe = JY.Person[pid]["出招动画帧数" .. wugongtype + 1] or 0
        
        if fightframe == 0 then
            lib.Debug(string.format("War_ShowFightCoroutine: 类型 %d 无动画帧，尝试智能匹配", wugongtype))
            
            local name = wugong and JY.Wugong[wugong] and JY.Wugong[wugong]["名称"] or ""
            local preferredType = nil
            
            if name:find("刀") or name:find("刀法") then
                preferredType = 2
            elseif name:find("剑") or name:find("剑法") then
                preferredType = 1
            elseif name:find("掌") or name:find("拳") or name:find("指") then
                preferredType = 0
            elseif name:find("棍") or name:find("杖") or name:find("鞭") then
                preferredType = 3
            end
            
            if preferredType then
                local preferredFrame = JY.Person[pid]["出招动画帧数" .. preferredType + 1] or 0
                if preferredFrame > 0 then
                    lib.Debug(string.format("War_ShowFightCoroutine: 根据武功名称 '%s' 匹配类型 %d，有 %d 帧", 
                        name, preferredType, preferredFrame))
                    wugongtype = preferredType
                end
            end
            
            if JY.Person[pid]["出招动画帧数" .. wugongtype + 1] == 0 then
                for t = 0, 4 do
                    local f = JY.Person[pid]["出招动画帧数" .. t + 1] or 0
                    if f > 0 then
                        lib.Debug(string.format("War_ShowFightCoroutine: 回退使用类型 %d，有 %d 帧", t, f))
                        wugongtype = t
                        break
                    end
                end
            end
        end
        
        fightdelay = JY.Person[pid]["出招动画延迟" .. wugongtype + 1] or 0
        fightframe = JY.Person[pid]["出招动画帧数" .. wugongtype + 1] or 0
        sounddelay = JY.Person[pid]["武功音效延迟" .. wugongtype + 1] or 0
        
        lib.Debug(string.format("War_ShowFightCoroutine: 最终wugongtype=%d, fightdelay=%d, fightframe=%d", 
            wugongtype, fightdelay, fightframe))
    else
        fightdelay = 0
        fightframe = -1
        sounddelay = -1
    end
    
    lib.Debug(string.format("War_ShowFightCoroutine: fightdelay=%d, fightframe=%d, sounddelay=%d", 
        fightdelay, fightframe, sounddelay))
    
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
        
        local pic = WAR.Person[WAR.CurID]["贴图"] / 2
        
        if i < fightdelay then
            WAR.DrawMode = 4
            WAR.AnimPic = pic * 2
            WAR.AnimType = mytype
            WAR.AnimEffect = -1
        else
            starteft = starteft + 1
            WAR.DrawMode = 4
            WAR.AnimPic = pic * 2
            WAR.AnimType = mytype
            WAR.AnimEffect = starteft * 2
        end
        
        WarSetPerson()
        scheduler:waitForTime(frameTime)
    end
    
    WAR.DrawMode = nil
    WAR.AnimPic = nil
    WAR.AnimType = nil
    WAR.AnimEffect = nil
    
    WAR.Person[WAR.CurID]["贴图类型"] = 0
    WAR.Person[WAR.CurID]["贴图"] = WarCalPersonPic(WAR.CurID)
    WarSetPerson()
    
    WAR.DrawMode = 0
    scheduler:waitForTime(0.2)
    
    WAR.DrawMode = 2
    scheduler:waitForTime(0.2)
    
    -- 收集命中点数数据
    local HitXY = {}
    local HitXYNum = 0
    local x0 = WAR.Person[WAR.CurID]["坐标X"]
    local y0 = WAR.Person[WAR.CurID]["坐标Y"]
    
    for i = 0, WAR.PersonNum - 1 do
        local x1 = WAR.Person[i]["坐标X"]
        local y1 = WAR.Person[i]["坐标Y"]
        if WAR.Person[i]["死亡"] == false then
            if GetWarMap(x1, y1, 4) > 1 then
                local n = WAR.Person[i]["点数"]
                HitXY[HitXYNum] = {x1, y1, string.format("%+d", n)}
                HitXYNum = HitXYNum + 1
            end
        end
    end
    
    -- 计算命中点数显示坐标
    if HitXYNum > 0 then
        local clips = {}
        for i = 0, HitXYNum - 1 do
            local dx = HitXY[i][1] - x0
            local dy = HitXY[i][2] - y0
            local ll = string.len(HitXY[i][3])
            local w = ll * CC.DefaultFont / 2 + 1
            clips[i] = {
                x1 = CC.XScale * (dx - dy) + CC.ScreenW / 2,
                y1 = CC.YScale * (dx + dy) + CC.ScreenH / 2,
                x2 = CC.XScale * (dx - dy) + CC.ScreenW / 2 + w,
                y2 = CC.YScale * (dx + dy) + CC.ScreenH / 2 + CC.DefaultFont + 1
            }
        end
        
        -- 设置伤害数字显示数据
        WAR.HitNumbers = HitXY
        WAR.HitClips = clips
        WAR.HitNum = HitXYNum
        WAR.HitEffect = WAR.Effect
        
        -- 显示伤害数字 15 帧
        local frameTime = (CC.Frame or 50) / 1000
        for i = 1, 15 do
            WAR.HitYOffset = i * 2 + 65
            WAR.DrawMode = 5
            scheduler:waitForTime(frameTime)
        end
        
        WAR.HitNumbers = nil
        WAR.HitClips = nil
        WAR.HitNum = nil
        WAR.HitEffect = nil
        WAR.HitYOffset = nil
    end
    
    WAR.DrawMode = nil
end

-- 用毒（协程版本）
War_PoisonCoroutine = function()
    WAR.ShowHead = 0
    local r = War_ExecuteMenuCoroutine(1)
    WAR.ShowHead = 1
    return r
end

-- 解毒（协程版本）
War_DecPoisonCoroutine = function()
    WAR.ShowHead = 0
    local r = War_ExecuteMenuCoroutine(2)
    WAR.ShowHead = 1
    return r
end

-- 医疗（协程版本）
War_DoctorCoroutine = function()
    WAR.ShowHead = 0
    local r = War_ExecuteMenuCoroutine(3)
    WAR.ShowHead = 1
    return r
end

-- 执行医疗、解毒、用毒子函数（协程版本）
War_ExecuteMenu_SubCoroutine = function(x1, y1, flag, thingid)
    local scheduler = CoroutineScheduler.getInstance()
    local pid = WAR.Person[WAR.CurID]["人物编号"]
    local x0 = WAR.Person[WAR.CurID]["坐标X"]
    local y0 = WAR.Person[WAR.CurID]["坐标Y"]
    
    CleanWarMap(4, 0)
    
    WAR.Person[WAR.CurID]["人方向"] = War_Direct(x0, y0, x1, y1)
    
    SetWarMap(x1, y1, 4, 1)
    
    local emeny = GetWarMap(x1, y1, 2)
    if emeny >= 0 then
        if flag == 1 then
            if WAR.Person[WAR.CurID]["我方"] ~= WAR.Person[emeny]["我方"] then
                WAR.Person[emeny]["点数"] = War_PoisonHurt(pid, WAR.Person[emeny]["人物编号"])
                SetWarMap(x1, y1, 4, 5)
                WAR.Effect = 5
            end
        elseif flag == 2 then
            if WAR.Person[WAR.CurID]["我方"] == WAR.Person[emeny]["我方"] then
                WAR.Person[emeny]["点数"] = ExecDecPoison(pid, WAR.Person[emeny]["人物编号"])
                SetWarMap(x1, y1, 4, 6)
                WAR.Effect = 6
            end
        elseif flag == 3 then
            if WAR.Person[WAR.CurID]["我方"] == WAR.Person[emeny]["我方"] then
                WAR.Person[emeny]["点数"] = ExecDoctor(pid, WAR.Person[emeny]["人物编号"])
                SetWarMap(x1, y1, 4, 4)
                WAR.Effect = 4
            end
        elseif flag == 4 then
            if WAR.Person[WAR.CurID]["我方"] ~= WAR.Person[emeny]["我方"] then
                WAR.Person[emeny]["点数"] = War_AnqiHurt(pid, WAR.Person[emeny]["人物编号"], thingid)
                SetWarMap(x1, y1, 4, 2)
                WAR.Effect = 2
            end
        end
    end
    
    WAR.EffectXY = {}
    WAR.EffectXY[1] = {x1, y1}
    WAR.EffectXY[2] = {x1, y1}
    
    if flag == 1 then
        War_ShowFightCoroutine(pid, 0, 0, 0, x1, y1, 30)
    elseif flag == 2 then
        War_ShowFightCoroutine(pid, 0, 0, 0, x1, y1, 36)
    elseif flag == 3 then
        War_ShowFightCoroutine(pid, 0, 0, 0, x1, y1, 0)
    elseif flag == 4 then
        if emeny >= 0 then
            War_ShowFightCoroutine(pid, 0, -1, 0, x1, y1, JY.Thing[thingid]["暗器动画编号"])
        end
    end
    
    for i = 0, WAR.PersonNum - 1 do
        WAR.Person[i]["点数"] = 0
    end
    
    if flag == 4 then
        if emeny >= 0 then
            instruct_32(thingid, -1)
            return 1
        else
            return 0
        end
    else
        WAR.Person[WAR.CurID]["经验"] = WAR.Person[WAR.CurID]["经验"] + 1
        AddPersonAttrib(pid, "体力", -2)
    end
    
    return 1
end

-- 执行医疗、解毒、用毒（协程版本）
War_ExecuteMenuCoroutine = function(flag, thingid)
    local scheduler = CoroutineScheduler.getInstance()
    local pid = WAR.Person[WAR.CurID]["人物编号"]
    local step
    
    if flag == 1 then
        step = math.modf(JY.Person[pid]["用毒能力"] / 15) + 1
    elseif flag == 2 then
        step = math.modf(JY.Person[pid]["解毒能力"] / 15) + 1
    elseif flag == 3 then
        step = math.modf(JY.Person[pid]["医疗能力"] / 15) + 1
    elseif flag == 4 then
        step = math.modf(JY.Person[pid]["暗器技巧"] / 15) + 1
    end
    
    War_CalMoveStep(WAR.CurID, step, 1)
    
    local x0 = WAR.Person[WAR.CurID]["坐标X"]
    local y0 = WAR.Person[WAR.CurID]["坐标Y"]
    local x, y = x0, y0
    
    WAR.DrawMode = 1
    WAR.MoveCursorX = x
    WAR.MoveCursorY = y
    
    while true do
        WAR.MoveCursorX = x
        WAR.MoveCursorY = y
        
        local key = InputAsync.WaitKeyCoroutine()
        
        local x2, y2 = x, y
        
        if key == VK_UP then
            y2 = y - 1
        elseif key == VK_DOWN then
            y2 = y + 1
        elseif key == VK_LEFT then
            x2 = x - 1
        elseif key == VK_RIGHT then
            x2 = x + 1
        elseif key == VK_SPACE or key == VK_RETURN then
            WAR.DrawMode = nil
            WAR.MoveCursorX = nil
            WAR.MoveCursorY = nil
            return War_ExecuteMenu_SubCoroutine(x, y, flag, thingid)
        elseif key == VK_ESCAPE then
            WAR.DrawMode = nil
            WAR.MoveCursorX = nil
            WAR.MoveCursorY = nil
            return 7
        end
        
        if GetWarMap(x2, y2, 3) < 128 then
            x, y = x2, y2
        end
    end
end

-- 战斗物品菜单（协程版本）
War_ThingMenuCoroutine = function()
    local scheduler = CoroutineScheduler.getInstance()
    local ItemAsync = require("item_async")
    
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
    
    -- 使用Grid形式选择物品
    local r = ItemAsync.SelectThingByArrayAsync(thing, thingnum, num)
    
    Cls()
    
    if r < 0 then
        WAR.ShowHead = 1
        return 7  -- ESC取消，继续菜单
    end
    
    local thingType = JY.Thing[r]["类型"]
    local useResult = 0
    
    if thingType == 3 then
        -- 药品：直接对当前战斗人物使用
        local pid = WAR.Person[WAR.CurID]["人物编号"]
        
        -- 调用原版的 UseThingEffect
        if UseThingEffect(r, pid) == 1 then
            instruct_32(r, -1)  -- 减少物品数量
            useResult = 1
            WaitKey()
        end
    elseif thingType == 4 then
        -- 暗器：调用战斗暗器协程
        useResult = War_ExecuteMenuCoroutine(4, r)
    end
    
    WAR.ShowHead = 1
    Cls()
    
    if useResult == 1 then
        return 0  -- 使用成功，结束回合
    else
        return 7  -- 使用失败或无效果，继续菜单
    end
end

-- 战斗状态菜单（协程版本）
War_StatusMenuCoroutine = function()
    local scheduler = CoroutineScheduler.getInstance()
    
    WAR.ShowHead = 0
    
    -- 显示提示
    DrawStrBox(CC.MainSubMenuX, CC.MainSubMenuY, "要查阅谁的状态", C_WHITE, CC.DefaultFont)
    local nexty = CC.MainSubMenuY + CC.SingleLineHeight
    
    -- 构建队友菜单
    local menu = {}
    for i = 1, CC.TeamNum do
        menu[i] = {"", nil, 0}
        local id = JY.Base["队伍" .. i]
        if id >= 0 then
            if JY.Person[id]["生命"] > 0 then
                menu[i][1] = JY.Person[id]["姓名"]
                menu[i][3] = 1
            end
        end
    end
    
    local r = MenuAsync.ShowMenuCoroutine(menu, CC.TeamNum, 0, CC.MainSubMenuX, nexty, 0, 0, 1, 1, CC.DefaultFont, C_ORANGE, C_WHITE)
    
    if r > 0 then
        PersonStatusAsync.ShowStatusCoroutine(r)
    end
    
    WAR.ShowHead = 1
    Cls()
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
WarAsync.War_ThingMenuCoroutine = War_ThingMenuCoroutine
WarAsync.War_StatusMenuCoroutine = War_StatusMenuCoroutine

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