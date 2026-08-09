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

    -- 重置战斗上下文（防止上一场战斗的相位残留导致新战斗卡死，
    -- 例如上一场在 select_item 退出，新战斗 look() 会从 select_teammate 重新开始）
    wmapContext.phase = nil
    wmapContext.selectedTeammate = nil
    wmapContext.selectedAction = nil
    wmapContext.selectedMartial = nil
    wmapContext.selectedItem = nil
    wmapContext.validTargets = {}
    
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
    -- 注意：原版队伍字段名是 JY.Base["队伍"..i]（见 jymain.lua），不是"队友/队员"
    local base = JY.Base or {}
    for i = 1, 6 do
        local pid = base["队伍" .. i] or base["队友" .. i] or base["队员" .. i]
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
                    attack = p["攻击力"] or 25,
                    defense = p["防御力"] or 10,
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
            attack = (p0 and p0["攻击力"]) or 25,
            defense = (p0 and p0["防御力"]) or 10,
            x = 0,
        })
    end
    
    JY.War.acted = {}
    JY.Status = 5  -- GAME_WMAP
end

-- 计算伤害
local function calcDamage(attacker, defender, power, isMartial)
    local atk = (attacker and attacker.attack) or 25
    local baseDmg = math.floor(atk * (power or 30) / 100)
    local def = 0
    if defender and defender.defense then def = defender.defense end
    local dmg = math.max(1, baseDmg - math.floor(def / 4) + math.random(0, 10))
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
        if idx == 0 or idx == nil then
            -- 退出物品菜单 → 结束本回合（doBattle 用 choose 0 退出）
            w("放弃使用物品。")
            wmapContext.phase = nil
            WmapHandlers.afterAction()
            return
        end
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
        -- 只列出存活敌人（原版战斗不能选择已死目标）
        if (en.hp or 0) > 0 then
            idx = idx + 1
            local dist = war.distance or 5
            local canReach = inRange(0, dist)  -- 简化: 默认范围
            local mark = canReach and "✅" or "❌"
            w(string.format("  %d. %s (HP:%d/%d, 距离:%d步) %s", idx, en.name or "?", en.hp or 0, en.maxHp or 0, dist, mark))
            table.insert(wmapContext.validTargets, {type = "enemy", index = i, isEnemy = true})
        end
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
    for i = 1, 200 do  -- 原版 CC.MyThingNum=200，背包容量
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
    -- 跳过已死目标（防御性：若目标已被击败则结束回合）
    if (en.hp or 0) <= 0 then
        w("目标已被击败。")
        WmapHandlers.afterAction()
        return
    end
    
    local dist = war.distance or 5
    if dist > 1 then
        w("距离太远，无法攻击！")
        WmapHandlers.afterAction()
        return
    end
    
    local dmg = calcDamage(tm, en, 150, false)
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
    
    local power = 150 + math.random(0, 30)
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
        -- 检查是否由 instruct_6 触发（脚本战斗），由 oldevent 脚本处理后续
        if rawget(_G, "__warFromInstruct6") then
            -- 原版战斗胜利后发放经验并升级（jymain.lua:4552 War_AddPersonLevel），
            -- 否则主角武力无法成长（如金蛇剑需武力75+）。
            WmapHandlers.grantExpAndLevelUp(war)
            rawset(_G, "__warComplete", true)
            rawset(_G, "__warResult", true)
            return
        end
        -- 自由战斗（非脚本触发），设置奖励和 MMAP
        local JY = rawget(_G, "JY")
        local P0 = JY.Person and JY.Person[0]
        if P0 then
            local expGain = 10 + math.random(20) + (#war.enemies * 5)
            local goldGain = 5 + math.random(15) + (#war.enemies * 3)
            P0["经验"] = (P0["经验"] or 0) + expGain
            JY.Base = JY.Base or {}
            JY.Base["金钱"] = (JY.Base["金钱"] or 0) + goldGain
            w(string.format("获得 %d 经验，%d 金钱！", expGain, goldGain))
        end
        wmapContext.phase = nil
        JY.Status = 2  -- GAME_MMAP
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
        -- 检查是否由 instruct_6 触发（脚本战斗），由 oldevent 脚本处理后续
        if rawget(_G, "__warFromInstruct6") then
            rawset(_G, "__warComplete", true)
            rawset(_G, "__warResult", false)
            return
        end
        rawget(_G, "JY").Status = 2  -- GAME_MMAP
        return
    end
    
    war.turn = 0
    war.round = (war.round or 1) + 1
    w("")
    w("===== 我方回合 =====")
    WmapHandlers.look({})
end

-- 战斗胜利后发放经验并升级（简化版升级机制）
-- 原版参考：jymain.lua:4539-4572 War_End（经验=WAR.Data["经验"]/存活人数）+ jymain.lua:4578 War_AddPersonLevel。
-- 简化：经验 = 战斗经验(原版 war.sta 值)×5，发放给所有队友（含主角 pid=0，
--      initWar 用 pid~=0 过滤了主角，必须按 JY.Base["队伍"..i] 遍历才能覆盖主角），
--      保证主角能升级；升级时属性增长按原版公式，cleveradd 取资质基础值（不随机）。
function WmapHandlers.grantExpAndLevelUp(war)
    local JY = rawget(_G, "JY")
    if not JY or not JY.Person then return end
    local expBase = (war and war.exp) or 0
    if expBase <= 0 then expBase = 10 end
    local expGain = math.floor(expBase * 5)
    -- 按队伍表发放经验（含主角 pid=0，initWar 的 teammates 过滤了主角）
    local base = JY.Base or {}
    local granted = false
    for i = 1, 6 do
        local pid = base["队伍" .. i] or base["队友" .. i] or base["队员" .. i]
        if pid then
            local p = JY.Person[pid]
            if p then
                p["经验"] = (p["经验"] or 0) + expGain
                WmapHandlers.levelUpPerson(pid)
                granted = true
            end
        end
    end
    -- 兜底：队伍表为空时，遍历 war.teammates 和主角
    if not granted then
        local p0 = JY.Person[0]
        if p0 then
            p0["经验"] = (p0["经验"] or 0) + expGain
            WmapHandlers.levelUpPerson(0)
        end
    end
    w(string.format("战斗胜利！获得 %d 经验。", expGain))
end

-- 人物升级（按原版 jymain.lua:4578 War_AddPersonLevel 公式）
-- 资质→cleveradd 基础值：<30→2, <50→3, <70→4, <90→5, 否则6；简化版直接取基础值保证确定性。
function WmapHandlers.levelUpPerson(pid)
    local JY = rawget(_G, "JY")
    local CC = rawget(_G, "CC")
    local p = JY and JY.Person and JY.Person[pid]
    if not p then return false end
    local Rnd = rawget(_G, "Rnd") or function(i) return math.random(i) - 1 end
    local tmplevel = p["等级"] or 1
    if CC and CC.Level and tmplevel >= CC.Level then return false end
    if not (CC and CC.Exp) then return false end
    if (p["经验"] or 0) < (CC.Exp[tmplevel] or 99999999) then return false end
    -- 计算可升几级
    while true do
        if CC.Level and tmplevel >= CC.Level then break end
        if (p["经验"] or 0) >= (CC.Exp[tmplevel] or 99999999) then
            tmplevel = tmplevel + 1
        else
            break
        end
    end
    local leveladd = tmplevel - (p["等级"] or 1)
    if leveladd <= 0 then return false end
    p["等级"] = tmplevel
    -- 生命最大值 += (生命增长 + Rnd(3)) * leveladd * 3
    p["生命最大值"] = (p["生命最大值"] or 50) + ((p["生命增长"] or 5) + Rnd(3)) * leveladd * 3
    p["生命"] = p["生命最大值"]
    p["体力"] = (CC and CC.PersonAttribMax and CC.PersonAttribMax["体力"]) or 100
    p["受伤程度"] = 0
    p["中毒程度"] = 0
    -- cleveradd 按资质（简化：取基础值，不随机）
    local cleveradd
    local zz = p["资质"] or 50
    if zz < 30 then cleveradd = 2
    elseif zz < 50 then cleveradd = 3
    elseif zz < 70 then cleveradd = 4
    elseif zz < 90 then cleveradd = 5
    else cleveradd = 6 end
    -- 内力最大值 += (9 - cleveradd) * leveladd * 4
    p["内力最大值"] = (p["内力最大值"] or 30) + (9 - cleveradd) * leveladd * 4
    p["内力"] = p["内力最大值"]
    p["攻击力"] = (p["攻击力"] or 0) + cleveradd * leveladd
    p["防御力"] = (p["防御力"] or 0) + cleveradd * leveladd
    p["轻功"] = (p["轻功"] or 0) + cleveradd * leveladd
    -- 各项技能（原版：>=20 时 +Rnd(3)）
    if (p["医疗能力"] or 0) >= 20 then p["医疗能力"] = p["医疗能力"] + Rnd(3) end
    if (p["用毒能力"] or 0) >= 20 then p["用毒能力"] = p["用毒能力"] + Rnd(3) end
    if (p["解毒能力"] or 0) >= 20 then p["解毒能力"] = p["解毒能力"] + Rnd(3) end
    if (p["拳掌功夫"] or 0) >= 20 then p["拳掌功夫"] = p["拳掌功夫"] + Rnd(3) end
    if (p["御剑能力"] or 0) >= 20 then p["御剑能力"] = p["御剑能力"] + Rnd(3) end
    if (p["耍刀技巧"] or 0) >= 20 then p["耍刀技巧"] = p["耍刀技巧"] + Rnd(3) end
    if (p["暗器技巧"] or 0) >= 20 then p["暗器技巧"] = p["暗器技巧"] + Rnd(3) end
    return true
end

rawset(_G, "WmapHandlers", WmapHandlers)

-- 导出当前战斗相位（供测试/doBattle 通过 Lua 直接读取，避免依赖终端文本窗口）
WmapHandlers.getPhase = function()
    return wmapContext and wmapContext.phase
end
WmapHandlers.getDistance = function()
    local war = rawget(_G, "JY") and rawget(_G, "JY").War
    return war and war.distance or nil
end
