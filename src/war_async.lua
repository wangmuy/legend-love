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

-- 前向声明内部函数
local War_ManualCoroutine
local War_AutoCoroutine
local War_SettlementCoroutine
local War_AttackCoroutine
local War_MoveCoroutine
local SelectTargetCoroutine
local War_Manual_SubCoroutine
local War_ShowFightCoroutine

-- 战斗主函数（协程版本）
-- @param warid: 战斗编号
-- @param isexp: 输后是否有经验
-- @return: true 战斗胜利, false 失败
function WarAsync.WarMainCoroutine(warid, isexp)
    lib.Debug(string.format("WarMainCoroutine: warid=%d, isexp=%d", warid, isexp or 1))
    
    warState.warId = warid
    warState.isExp = isexp or 1
    warState.status = "running"
    warState.result = nil
    warState.round = 0
    
    -- 初始化战斗
    lib.Debug("WarMainCoroutine: calling WarLoad")
    local ok, err = pcall(function() WarLoad(warid) end)
    if not ok then
        lib.Debug("WarMainCoroutine: WarLoad failed: " .. tostring(err))
        return false
    end
    
    lib.Debug("WarMainCoroutine: calling WarSelectTeam")
    WarSelectTeam()
    
    lib.Debug("WarMainCoroutine: calling WarSelectEnemy")
    WarSelectEnemy()
    
    CleanMemory()
    lib.PicInit()
    lib.ShowSlow(50, 1)
    
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
        
        -- 每回合战斗循环
        local p = 0
        while p < WAR.PersonNum do
            WAR.Effect = 0
            
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

-- 自动战斗（协程版本）
War_AutoCoroutine = function()
    local id = WAR.CurID
    local pid = WAR.Person[id]["人物编号"]
    
    -- 简单AI：选择第一个敌人攻击
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
    
    -- 选择第一个武功
    local wugongnum = 0
    for i = 1, 10 do
        if JY.Person[pid]["武功" .. i] and JY.Person[pid]["武功" .. i] > 0 then
            wugongnum = i - 1
            break
        end
    end
    
    War_Fight_Sub(id, wugongnum, targetId, targetId)
    
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
    
    -- 执行攻击
    War_Fight_Sub(WAR.CurID, r - 1, targetId, targetId)
    
    return 0
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
    
    -- 简化实现：显示移动范围，等待用户选择位置
    local x = WAR.Person[WAR.CurID]["x"]
    local y = WAR.Person[WAR.CurID]["y"]
    
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
        SetWarMap(x, y, 2, 0)
        SetWarMap(newX, newY, 2, WAR.CurID)
        WAR.Person[WAR.CurID]["x"] = newX
        WAR.Person[WAR.CurID]["y"] = newY
    end
    
    return 0
end

-- 显示战斗动画（协程版本）
War_ShowFightCoroutine = function(pid, wugong, wugongtype, level, x, y, eft)
    local scheduler = CoroutineScheduler.getInstance()
    
    -- 播放武功动画
    local animFrames = 5
    for i = 1, animFrames do
        WarDrawMap(0)
        scheduler:waitForTime(0.05)
    end
    
    -- 显示效果
    if eft >= 0 then
        for i = 1, 3 do
            WarDrawMap(0)
            scheduler:waitForTime(0.03)
        end
    end
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