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
    
    warState.warId = warid
    warState.isExp = isexp or 1
    warState.status = "running"
    warState.result = nil
    warState.round = 0
    
    -- 初始化战斗
    WarLoad(warid)
    WarSelectTeam()
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
                        r = WarAsync.War_ManualCoroutine()
                    else
                        r = War_Auto()
                    end
                else
                    r = War_Auto()
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
    if warStatus == 1 then
        AsyncMessageBox.ShowMessageCoroutine(-1, -1, "战斗胜利", C_WHITE, CC.DefaultFont)
    else
        AsyncMessageBox.ShowMessageCoroutine(-1, -1, "战斗失败", C_WHITE, CC.DefaultFont)
    end
    
    War_EndPersonData(warState.isExp, warStatus)
    
    -- 恢复状态
    JY.Status = prevState
    warState.status = "ended"
    warState.result = (warStatus == 1)
    
    return warState.result
end

-- 手动战斗（协程版本）
function WarAsync.War_ManualCoroutine()
    local r
    while true do
        r = WarAsync.War_Manual_SubCoroutine()
        if math.abs(r) ~= 7 then
            break
        end
    end
    return r
end

-- 手动战斗菜单（协程版本）
function WarAsync.War_Manual_SubCoroutine()
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
        return WarAsync.War_AttackCoroutine()
    elseif r == 2 then
        -- 移动
        return WarAsync.War_MoveCoroutine()
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
    
    return 0
end

-- 攻击选择（协程版本）
function WarAsync.War_AttackCoroutine()
    -- 选择武功和目标的逻辑
    -- 简化实现，实际需要更复杂的交互
    return 0
end

-- 移动选择（协程版本）
function WarAsync.War_MoveCoroutine()
    -- 移动位置选择的逻辑
    return 0
end

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