-- wmap_handlers.lua — 战斗系统 (Slice 5)
-- 1D 线性距离回合制战斗，菜单驱动交互

local WmapHandlers = {}

-- 当前战斗状态（choose N 的上下文）
local wmapContext = {
    phase = nil,       -- "select_teammate", "select_action", "select_target", "select_martial", "select_item", "select_move"
    selectedTeammate = nil,
    selectedAction = nil,
    selectedMartial = nil,
    selectedItem = nil,
    validTargets = {},
}

-- 辅助函数
local function w(text)
    local WebUI = rawget(_G, "WebUI")
    if WebUI then WebUI.write(tostring(text)) end
end

-- 初始化战斗
function WmapHandlers.initWar(enemies, distance)
    local JY = rawget(_G, "JY")
    if not JY then JY = {}; rawset(_G, "JY", JY) end
    local CC = rawget(_G, "CC")
    
    JY.War = {
        enemies = enemies or {},
        teammates = {},
        turn = 0,       -- 0=我方, 1=敌方
        round = 1,
        distance = distance or 5,
        warId = 0,
        acted = {},     -- 已行动的队友索引
    }
    
    -- 构建我方队伍（JY.Person 中的队伍成员）
    local base = JY.Base or {}
    for i = 1, 6 do
        local pid = base["队友" .. i] or base["队员" .. i]
        if pid and pid ~= 0 then
            local p = JY.Person and JY.Person[pid]
            if p then
                table.insert(JY.War.teammates, {
                    personId = pid,
                    name = p["姓名"] or "队友",
                    hp = p["生命"] or 50,
                    maxHp = p["生命最大值"] or 50,
                    mp = p["内力"] or 30,
                    maxMp = p["内力最大值"] or 30,
                    x = 0,
                })
            end
        end
    end
    
    -- 如果队伍为空，加入主角
    if #JY.War.teammates == 0 then
        local p0 = JY.Person and JY.Person[0]
        table.insert(JY.War.teammates, {
            personId = 0,
            name = (p0 and p0["姓名"]) or "主角",
            hp = (p0 and p0["生命"]) or 50,
            maxHp = (p0 and p0["生命最大值"]) or 50,
            mp = (p0 and p0["内力"]) or 30,
            maxMp = (p0 and p0["内力最大值"]) or 30,
            x = 0,
        })
    end
    
    JY.War.acted = {}
    JY.Status = 5  -- GAME_WMAP
end

-- 计算伤害
local function calcDamage(attacker, defender, power, isMartial)
    local baseDmg = power or 30
    local def = 0
    if defender.defense then def = defender.defense end
    local dmg = math.max(1, baseDmg - def / 2 + math.random(0, 10))
    return math.floor(dmg)
end

-- 检查攻击范围
local function inRange(wugongType, distance)
    local ranges = {
        [0] = {min=0, max=1},   -- 拳掌
        [1] = {min=0, max=2},   -- 剑
        [2] = {min=0, max=2},   -- 刀
        [3] = {min=0, max=3},   -- 特殊
        [4] = {min=1, max=4},   -- 暗器
    }
    -- 默认攻击范围 0-1
    local r = ranges[wugongType or 0] or {min=0, max=1}
    return distance >= r.min and distance <= r.max
end

-- 获取角色姓名
local function getName(p)
    if type(p) == "table" and p.name then return p.name end
    return "未知"
end

-- look: 战场态势
function WmapHandlers.look(args)
    local JY = rawget(_G, "JY")
    if not JY or not JY.War then
        w("不在战斗中。")
        return
    end
    local war = JY.War
    
    w("战场态势" .. (war.turn == 0 and "（我方回合）" or "（敌方回合）") .. ":")
    w("")
    
    -- 我方队伍
    w("我方:")
    for i, tm in ipairs(war.teammates) do
        local acted = war.acted and war.acted[i]
        local status = acted and "·" or "✓"
        w(string.format("  %d. %s HP:%d/%d MP:%d/%d 位置%d %s",
            i, tm.name or "?", tm.hp or 0, tm.maxHp or 0,
            tm.mp or 0, tm.maxMp or 0, tm.x or 0, status))
    end
    
    -- 敌方队伍
    w("敌方:")
    for i, en in ipairs(war.enemies) do
        local dist = math.abs((war.teammates[1] and war.teammates[1].x or 0) - (en.x or 0))
        w(string.format("  %d. %s HP:%d/%d 距离:%d步",
            i, en.name or "?", en.hp or 0, en.maxHp or 0, dist))
    end
    
    w(string.format("敌我距离: %d步", war.distance or 5))
    w("")
    
    if war.turn == 0 then
        -- 我方回合: 选队友
        wmapContext.phase = "select_teammate"
        wmapContext.validTargets = {}
        local available = {}
        for i, tm in ipairs(war.teammates) do
            if not (war.acted and war.acted[i]) and (tm.hp or 0) > 0 then
                table.insert(available, {index = i, name = tm.name, hp = tm.hp, maxHp = tm.maxHp})
                table.insert(wmapContext.validTargets, {type = "teammate", index = i})
            end
        end
        if #available == 0 then
            w("所有队友已行动，等待敌回合...")
            -- 自动切换到敌回合
            WmapHandlers.enemyTurn()
            return
        end
        if #available == 1 then
            -- 单人战斗自动选择
            wmapContext.selectedTeammate = available[1].index
            wmapContext.phase = "select_action"
            WmapHandlers.showActionMenu()
            return
        end
        w("选择行动的队友:")
        for _, tm in ipairs(available) do
            w(string.format("  %d. %s (HP:%d/%d)", tm.index, tm.name, tm.hp, tm.maxHp))
        end
        w("输入 choose <编号> 选择队友")
    else
        w("敌方回合，请等待...")
    end
end

-- 显示行动菜单
function WmapHandlers.showActionMenu()
    local tm = rawget(_G, "JY") and rawget(_G, "JY").War and rawget(_G, "JY").War.teammates[wmapContext.selectedTeammate]
    if not tm then return end
    w("")
    w(tm.name .. " 行动:")
    w("  1. 攻击")
    w("  2. 武功")
    w("  3. 物品")
    w("  4. 防御")
    w("  5. 移动")
    w("  6. 查看状态")
    w("输入 choose <编号> 选择行动")
end

-- choose 路由
function WmapHandlers.chooseInteraction(idx)
    local JY = rawget(_G, "JY")
    if not JY or not JY.War then
        w("不在战斗中。")
        return
    end
    
    if wmapContext.phase == "select_teammate" then
        local target = wmapContext.validTargets[idx]
        if not target or target.type ~= "teammate" then
            w("无效的选择。")
            return
        end
        wmapContext.selectedTeammate = target.index
        wmapContext.phase = "select_action"
        WmapHandlers.showActionMenu()
        
    elseif wmapContext.phase == "select_action" then
        wmapContext.selectedAction = idx
        if idx == 1 then        -- 攻击
            wmapContext.phase = "select_target"
            WmapHandlers.showTargets("attack")
        elseif idx == 2 then    -- 武功
            wmapContext.phase = "select_martial"
            WmapHandlers.showMartialArts()
        elseif idx == 3 then    -- 物品
            wmapContext.phase = "select_item"
            WmapHandlers.showItems()
        elseif idx == 4 then    -- 防御
            WmapHandlers.doDefend()
        elseif idx == 5 then    -- 移动
            wmapContext.phase = "select_move"
            w("移动: 1. 走近 2. 远离")
        elseif idx == 6 then    -- 查看状态
            wmapContext.phase = "select_target"
            WmapHandlers.showTeammateStatus()
        end
        
    elseif wmapContext.phase == "select_target" then
        local target = wmapContext.validTargets[idx]
        if not target then
            w("无效的目标。")
            return
        end
        if wmapContext.selectedAction == 1 then
            WmapHandlers.doAttack(target.index, target.isEnemy)
        elseif wmapContext.selectedAction == 2 then
            WmapHandlers.doMartial(target.index, target.isEnemy)
        end
        
    elseif wmapContext.phase == "select_martial" then
        -- 选武功 → 选目标
        wmapContext.selectedMartial = idx
        wmapContext.phase = "select_target"
        WmapHandlers.showTargets("wugong")
        
    elseif wmapContext.phase == "select_move" then
        if idx == 1 then WmapHandlers.doMove(1)
        elseif idx == 2 then WmapHandlers.doMove(-1) end
    elseif wmapContext.phase == "select_item" then
        local item = wmapContext.validTargets[idx]
        if item and item.type == "item" then
            JY.Base["物品" .. item.slot] = 0
            JY.Base["物品数量" .. item.slot] = 0
            w("使用了物品。")
            WmapHandlers.afterAction()
        end
    end
end

-- 显示目标选择
function WmapHandlers.showTargets(actionType)
    local war = rawget(_G, "JY").War
    wmapContext.validTargets = {}
    local idx = 0
    for i, en in ipairs(war.enemies) do
        idx = idx + 1
        local dist = war.distance or 5
        local canReach = inRange(0, dist)  -- 简化: 默认范围
        local mark = canReach and "✅" or "❌"
        w(string.format("  %d. %s (HP:%d/%d, 距离:%d步) %s", idx, en.name or "?", en.hp or 0, en.maxHp or 0, dist, mark))
        table.insert(wmapContext.validTargets, {type = "enemy", index = i, isEnemy = true})
    end
    w("选择目标:")
end

-- 显示武功列表
function WmapHandlers.showMartialArts()
    local JY = rawget(_G, "JY")
    local pid = JY.War.teammates[wmapContext.selectedTeammate].personId
    local p = JY.Person and JY.Person[pid]
    if not p then
        w("没有可用武功。")
        return
    end
    w("武功:")
    wmapContext.validTargets = {}
    local idx = 0
    for i = 1, 10 do
        local wid = p["武功" .. i]
        if wid and wid ~= 0 then
            idx = idx + 1
            local wugong = rawget(_G, "CC") and rawget(_G, "CC")["武功" .. wid]
            local name = wugong or ("武功" .. wid)
            local dist = JY.War.distance or 5
            local canReach = inRange(wid, dist)  -- 简化
            local mark = canReach and "✅" or "❌"
            w(string.format("  %d. %s %s", idx, name, mark))
            table.insert(wmapContext.validTargets, {type = "martial", wugongId = wid})
        end
    end
    if idx == 0 then
        w("  没有学会任何武功")
    end
    w("输入 choose <编号> 选择武功")
end

-- 显示物品列表
function WmapHandlers.showItems()
    local JY = rawget(_G, "JY")
    if not JY or not JY.Base then
        w("你没有物品。")
        return
    end
    w("物品:")
    wmapContext.validTargets = {}
    local idx = 0
    for i = 1, 30 do
        local itemId = JY.Base["物品" .. i]
        if itemId and itemId ~= 0 then
            idx = idx + 1
            local qty = JY.Base["物品数量" .. i] or 1
            w(string.format("  %d. 物品ID=%d x%d", idx, itemId, qty))
            table.insert(wmapContext.validTargets, {type = "item", slot = i, itemId = itemId, qty = qty})
        end
    end
    if idx == 0 then
        w("  背包中没有物品")
        wmapContext.phase = "select_action"
        return
    end
    w("输入 choose <编号> 使用物品")
    wmapContext.phase = "select_item"
end

-- 查看状态
function WmapHandlers.showTeammateStatus()
    local war = rawget(_G, "JY").War
    wmapContext.validTargets = {}
    local idx = 0
    for i, tm in ipairs(war.teammates) do
        idx = idx + 1
        local JY = rawget(_G, "JY")
        local p = JY.Person and JY.Person[tm.personId]
        local name = tm.name or "?"
        local atk = p and p["攻击力"] or 0
        local def = p and p["防御力"] or 0
        local spd = p and p["轻功"] or 0
        w(string.format("  %d. %s ATK:%d DEF:%d SPD:%d HP:%d/%d MP:%d/%d",
            idx, name, atk, def, spd, tm.hp or 0, tm.maxHp or 0, tm.mp or 0, tm.maxMp or 0))
        table.insert(wmapContext.validTargets, {type = "teammate", index = i})
    end
    w("输入 choose <编号> 查看详情")
end

-- 执行攻击
function WmapHandlers.doAttack(enemyIdx, isEnemy)
    local war = rawget(_G, "JY").War
    local tm = war.teammates[wmapContext.selectedTeammate]
    local en = war.enemies[enemyIdx]
    if not tm or not en then return end
    
    local dist = math.abs(tm.x - en.x)
    if dist > 1 then
        w("距离太远，无法攻击！")
        WmapHandlers.afterAction()
        return
    end
    
    local dmg = calcDamage(tm, en, 25, false)
    en.hp = (en.hp or 0) - dmg
    w(string.format("%s攻击%s！伤害 %d！", tm.name or "?", en.name or "?", dmg))
    
    if (en.hp or 0) <= 0 then
        w(string.format("%s被击败！", en.name or "?"))
    end
    
    WmapHandlers.afterAction()
end

-- 执行武功（简化）
function WmapHandlers.doMartial(enemyIdx, isEnemy)
    local war = rawget(_G, "JY").War
    local tm = war.teammates[wmapContext.selectedTeammate]
    local en = war.enemies[enemyIdx]
    if not tm or not en then return end
    
    local power = 50 + math.random(0, 20)
    local dmg = math.floor(power - (en.defense or 0) / 3 + math.random(0, 10))
    dmg = math.max(1, dmg)
    en.hp = (en.hp or 0) - dmg
    w(string.format("%s使出武功！伤害 %d！", tm.name or "?", dmg))
    
    if (en.hp or 0) <= 0 then
        w(string.format("%s被击败！", en.name or "?"))
    end
    WmapHandlers.afterAction()
end

-- 执行防御
function WmapHandlers.doDefend()
    local tm = rawget(_G, "JY").War.teammates[wmapContext.selectedTeammate]
    w((tm and tm.name or "?") .. " 进入防御状态。")
    WmapHandlers.afterAction()
end

-- 执行移动
function WmapHandlers.doMove(direction)
    local war = rawget(_G, "JY").War
    local tm = war.teammates[wmapContext.selectedTeammate]
    if not tm then return end
    local steps = 3  -- 固定步数（简化）
    local oldDist = war.distance or 5
    war.distance = math.max(1, oldDist - direction * steps)
    w(string.format("%s移动，距离 %d → %d 步。", tm.name or "?", oldDist, war.distance))
    WmapHandlers.afterAction()
end

-- 行动后处理
function WmapHandlers.afterAction()
    local war = rawget(_G, "JY").War
    if not war then return end
    
    -- 检查战斗是否结束
    local allDead = true
    for _, en in ipairs(war.enemies) do
        if (en.hp or 0) > 0 then allDead = false; break end
    end
    if allDead then
        w("战斗胜利！")
        wmapContext.phase = nil
        rawget(_G, "JY").Status = 2  -- GAME_MMAP
        local MmapHandlers = rawget(_G, "MmapHandlers")
        if MmapHandlers then MmapHandlers.look({}) end
        return
    end
    
    -- 标记已行动
    if wmapContext.selectedTeammate then
        war.acted = war.acted or {}
        war.acted[wmapContext.selectedTeammate] = true
    end
    
    -- 检查所有队友是否已行动
    local allActed = true
    for i, tm in ipairs(war.teammates) do
        if not war.acted[i] and (tm.hp or 0) > 0 then
            allActed = false
            break
        end
    end
    
    if allActed then
        WmapHandlers.enemyTurn()
    else
        -- 还有队友未行动，继续选队友
        wmapContext.phase = nil
        WmapHandlers.look({})
    end
end

-- 敌方回合（简化 AI）
function WmapHandlers.enemyTurn()
    local war = rawget(_G, "JY").War
    if not war then return end
    
    war.turn = 1
    war.acted = {}
    w("")
    w("===== 敌方回合 =====")
    
    for _, en in ipairs(war.enemies) do
        if (en.hp or 0) > 0 then
            -- AI: 走近并攻击
            if war.distance > 1 then
                war.distance = math.max(1, war.distance - 1)
            end
            local tm = war.teammates[1]
            if tm and war.distance <= 1 then
                local dmg = math.max(1, 10 + math.random(0, 10))
                tm.hp = (tm.hp or 0) - dmg
                w(string.format("%s攻击%s！伤害 %d！(HP:%d→%d)", en.name or "?", tm.name or "?", dmg, tm.hp + dmg, tm.hp))
            end
        end
    end
    
    -- 检查我方是否全灭
    local allDead = true
    for _, tm in ipairs(war.teammates) do
        if (tm.hp or 0) > 0 then allDead = false; break end
    end
    if allDead then
        w("战斗失败...")
        wmapContext.phase = nil
        rawget(_G, "JY").Status = 2  -- GAME_MMAP
        return
    end
    
    war.turn = 0
    war.round = (war.round or 1) + 1
    w("")
    w("===== 我方回合 =====")
    WmapHandlers.look({})
end

rawset(_G, "WmapHandlers", WmapHandlers)
