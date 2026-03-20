-- jymain_async.lua
-- 游戏主逻辑的异步版本
-- 替换 MMenu、物品系统等函数中的阻塞调用
-- 更新日期: 2026-03-18
-- 变更: 添加异步物品系统支持

local JyMainAsync = {}

local CoroutineScheduler = require("coroutine_scheduler")
local MenuAsync = require("menu_async")
local AsyncMessageBox = require("async_message_box")
local InputAsync = require("input_async")
local TalkAsync = require("talk_async")
local ItemAsync = require("item_async")
local PersonStatusAsync = require("person_status_async")

-- ============================================
-- 主菜单系统
-- ============================================

-- 主菜单（协程版本）
function JyMainAsync.MMenuCoroutine()
    local menu = {
        {"医疗", nil, 1},
        {"解毒", nil, 1},
        {"物品", nil, 1},
        {"状态", nil, 1},
        {"离队", nil, 1},
        {"系统", nil, 1},
    }
    
    if JY.Status == GAME_SMAP then
        menu[5][3] = 0
        menu[6][3] = 0
    end
    
    local r = MenuAsync.ShowMenuCoroutine(menu, 6, 0, CC.MainMenuX, CC.MainMenuY, 0, 0, 1, 1, CC.DefaultFont, C_ORANGE, C_WHITE)
    
    -- 根据选择执行对应功能
    if r == 1 then
        JyMainAsync.Menu_Doctor()
    elseif r == 2 then
        JyMainAsync.Menu_DecPoison()
    elseif r == 3 then
        JyMainAsync.Menu_Thing()
    elseif r == 4 then
        JyMainAsync.Menu_Status()
    elseif r == 5 then
        JyMainAsync.Menu_PersonExit()
    elseif r == 6 then
        JyMainAsync.Menu_System()
    end
    -- r == 0 表示 ESC 退出，不执行任何操作
end

-- 系统子菜单
function JyMainAsync.Menu_System()
    local menu = {
        {"读取进度", nil, 1},
        {"保存进度", nil, 1},
        {"离开游戏", nil, 1},
    }
    
    local r = MenuAsync.ShowMenuCoroutine(menu, 3, 0, CC.MainSubMenuX, CC.MainSubMenuY, 0, 0, 1, 1, CC.DefaultFont, C_ORANGE, C_WHITE)
    
    if r == 0 then
        return 0
    elseif r < 0 then
        return 1
    elseif r == 1 then
        JyMainAsync.Menu_ReadRecord()
        return 1
    elseif r == 2 then
        JyMainAsync.Menu_SaveRecord()
        return 0
    elseif r == 3 then
        JyMainAsync.Menu_Exit()
        return 1
    end
    return 0
end

-- 离开菜单
function JyMainAsync.Menu_Exit()
    Cls()
    if AsyncMessageBox.ShowYesNoCoroutine(-1, -1, "是否真的要离开游戏？", C_WHITE, CC.DefaultFont) == true then
        JY.Status = GAME_END
    end
end

-- 保存进度
function JyMainAsync.Menu_SaveRecord()
    local menu = {
        {"进度一", nil, 1},
        {"进度二", nil, 1},
        {"进度三", nil, 1},
    }
    
    local r = MenuAsync.ShowMenuCoroutine(menu, 3, 0, CC.MainSubMenuX2, CC.MainSubMenuY, 0, 0, 1, 1, CC.DefaultFont, C_ORANGE, C_WHITE)
    
    if r > 0 then
        DrawStrBox(CC.MainSubMenuX2, CC.MainSubMenuY, "请稍候......", C_WHITE, CC.DefaultFont)
        -- 在 Love2D 中，不需要手动调用 ShowScreen，让 love.draw() 自动处理
        -- ShowScreen()
        SaveRecord(r)
        Cls(CC.MainSubMenuX2, CC.MainSubMenuY, CC.ScreenW, CC.ScreenH)
    end
end

-- 读取进度
function JyMainAsync.Menu_ReadRecord()
    local menu = {
        {"进度一", nil, 1},
        {"进度二", nil, 1},
        {"进度三", nil, 1},
    }
    
    local r = MenuAsync.ShowMenuCoroutine(menu, 3, 0, CC.MainSubMenuX2, CC.MainSubMenuY, 0, 0, 1, 1, CC.DefaultFont, C_ORANGE, C_WHITE)
    
    if r > 0 then
        DrawStrBox(CC.MainSubMenuX2, CC.MainSubMenuY, "请稍候......", C_WHITE, CC.DefaultFont)
        -- 在 Love2D 中，不需要手动调用 ShowScreen，让 love.draw() 自动处理
        -- ShowScreen()
        LoadRecord(r)
        JY.Status = GAME_FIRSTMMAP
    end
end

-- 状态子菜单
function JyMainAsync.Menu_Status()
    if lib and lib.Debug then
        lib.Debug("JyMainAsync.Menu_Status: started")
    end
    
    DrawStrBox(CC.MainSubMenuX, CC.MainSubMenuY, "要查阅谁的状态", C_WHITE, CC.DefaultFont)
    local nexty = CC.MainSubMenuY + CC.SingleLineHeight

    if lib and lib.Debug then
        lib.Debug("JyMainAsync.Menu_Status: calling SelectTeamMenuAsync")
    end
    local r = JyMainAsync.SelectTeamMenuAsync(CC.MainSubMenuX, nexty)
    if lib and lib.Debug then
        lib.Debug("JyMainAsync.Menu_Status: SelectTeamMenuAsync returned r=" .. tostring(r))
    end
    
    if r > 0 then
        if lib and lib.Debug then
            lib.Debug("JyMainAsync.Menu_Status: calling PersonStatusAsync.ShowStatusCoroutine")
        end
        -- 使用 PersonStatusAsync 显示状态
        PersonStatusAsync.ShowStatusCoroutine(r)
        if lib and lib.Debug then
            lib.Debug("JyMainAsync.Menu_Status: PersonStatusAsync.ShowStatusCoroutine returned")
        end
    else
        Cls()
    end
    
    if lib and lib.Debug then
        lib.Debug("JyMainAsync.Menu_Status: ended")
    end
end

-- 离队菜单
function JyMainAsync.Menu_PersonExit()
    DrawStrBox(CC.MainSubMenuX, CC.MainSubMenuY, "要求谁离队", C_WHITE, CC.DefaultFont)
    local nexty = CC.MainSubMenuY + CC.SingleLineHeight

    local r = JyMainAsync.SelectTeamMenuAsync(CC.MainSubMenuX, nexty)
    if r == 1 then
        AsyncMessageBox.ShowMessageCoroutine(-1, -1, "抱歉！没有你游戏进行不下去", C_WHITE, CC.DefaultFont)
    elseif r > 1 then
        local personid = JY.Base["队伍" .. r]
        for i, v in ipairs(CC.PersonExit) do
            if personid == v[1] then
                local AsyncGlobals = require("async_globals")
                AsyncGlobals.install()
                oldCallEvent(v[2])
                AsyncGlobals.uninstall()
            end
        end
        
        if AsyncMessageBox.ShowYesNoCoroutine(-1, -1, JY.Person[personid]["姓名"] .. "要离队吗？", C_WHITE, CC.DefaultFont) == true then
            instruct_21(personid)
        end
    end
    Cls()
end

-- 异步版本的选择队友菜单（简单版本，只显示人名）
-- x, y: 菜单位置
-- 返回选择的队伍位置（1-6），0表示取消
function JyMainAsync.SelectTeamMenuAsync(x, y)
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
    return MenuAsync.ShowMenuCoroutine(menu, CC.TeamNum, 0, x, y, 0, 0, 1, 1, CC.DefaultFont, C_ORANGE, C_WHITE)
end

-- 异步版本的选择队友菜单（带能力值显示）
-- title: 标题字符串
-- abilityKey: 能力值字段名（如"医疗能力"），如果为nil则只显示姓名
-- minAbility: 最小能力值要求，如果为nil则显示所有
-- 当前菜单标题（用于draw函数绘制）
local currentMenuTitle = nil

function JyMainAsync.SelectTeamMemberWithAbilityAsync(title, abilityKey, minAbility)
    -- 设置当前菜单标题
    currentMenuTitle = {
        title = title,
        abilityKey = abilityKey,
        x = CC.MainSubMenuX,
        y = CC.MainSubMenuY
    }
    
    -- 计算菜单起始位置（留出空间显示标题）
    local startY = CC.MainSubMenuY + CC.SingleLineHeight
    if abilityKey then
        startY = startY + CC.SingleLineHeight  -- 再留出能力标题的空间
    end
    
    -- 构建菜单
    local menu = {}
    for i = 1, CC.TeamNum do
        menu[i] = {"", nil, 0}
        local id = JY.Base["队伍" .. i]
        if id >= 0 then
            local shouldShow = true
            
            -- 检查最小能力值要求
            if minAbility and abilityKey then
                if JY.Person[id][abilityKey] < minAbility then
                    shouldShow = false
                end
            end
            
            -- 检查生命是否大于0
            if JY.Person[id]["生命"] <= 0 then
                shouldShow = false
            end
            
            if shouldShow then
                if abilityKey then
                    -- 显示姓名和能力值
                    menu[i][1] = string.format("%-10s%4d", JY.Person[id]["姓名"], JY.Person[id][abilityKey])
                else
                    -- 只显示姓名
                    menu[i][1] = JY.Person[id]["姓名"]
                end
                menu[i][3] = 1
            end
        end
    end
    
    -- 显示菜单（使用回调确保标题和菜单一起清除）
    local result = nil
    local CoroutineScheduler = require("coroutine_scheduler")
    local scheduler = CoroutineScheduler.getInstance()
    local menuClosed = false
    
    MenuAsync.ShowMenu(menu, CC.TeamNum, 0, CC.MainSubMenuX, startY, 0, 0, 1, 1, CC.DefaultFont, C_ORANGE, C_WHITE, function(returnValue)
        result = returnValue
        menuClosed = true
        -- 菜单关闭时立即清除标题
        currentMenuTitle = nil
    end)
    
    -- 等待菜单关闭
    while not menuClosed do
        scheduler:yield("menu")
    end
    
    return result
end

-- 绘制菜单标题（在EventBridge.draw中调用）
function JyMainAsync.drawMenuTitle()
    if currentMenuTitle then
        -- 绘制主标题
        DrawStrBox(currentMenuTitle.x, currentMenuTitle.y, currentMenuTitle.title, C_WHITE, CC.DefaultFont)
        
        -- 如果有能力标题，绘制它
        if currentMenuTitle.abilityKey then
            local nexty = currentMenuTitle.y + CC.SingleLineHeight
            DrawStrBox(currentMenuTitle.x, nexty, currentMenuTitle.abilityKey, C_ORANGE, CC.DefaultFont)
        end
    end
end

-- 医疗子菜单
function JyMainAsync.Menu_Doctor()
    -- 第一级：选择使用医术的人（显示医疗能力，只显示医疗能力>=20的人）
    local r1 = JyMainAsync.SelectTeamMemberWithAbilityAsync("谁要使用医术", "医疗能力", 20)
    if r1 <= 0 then
        Cls()
        return
    end
    
    local id1 = JY.Base["队伍" .. r1]
    
    -- 检查体力
    if JY.Person[id1]["体力"] < 50 then
        AsyncMessageBox.ShowMessageCoroutine(-1, -1, "体力不足，不能医疗", C_WHITE, CC.DefaultFont)
        Cls()
        return
    end
    
    -- 清除屏幕区域
    Cls(CC.MainSubMenuX, CC.MainSubMenuY, CC.ScreenW, CC.ScreenH)
    
    -- 第二级：选择要医治的人（显示生命值）
    local r2 = JyMainAsync.SelectTeamMemberWithLifeAsync("要医治谁")
    if r2 <= 0 then
        Cls()
        return
    end
    
    local id2 = JY.Base["队伍" .. r2]
    
    -- 执行医疗
    local oldLife = JY.Person[id2]["生命"]
    local num = JyMainAsync.ExecDoctorAsync(id1, id2)
    -- 强制显示结果（即使num为0也显示）
    local newLife = JY.Person[id2]["生命"]
    AsyncMessageBox.ShowMessageCoroutine(-1, -1, string.format("%s 生命 %d -> %d (增加 %d)", 
        JY.Person[id2]["姓名"], oldLife, newLife, num), C_ORANGE, CC.DefaultFont)
    
    Cls()
end

-- 异步版本的选择队友菜单（显示生命值）
function JyMainAsync.SelectTeamMemberWithLifeAsync(title)
    -- 设置当前菜单标题
    currentMenuTitle = {
        title = title,
        abilityKey = nil,
        x = CC.MainSubMenuX,
        y = CC.MainSubMenuY
    }
    
    -- 计算菜单起始位置
    local startY = CC.MainSubMenuY + CC.SingleLineHeight
    
    -- 构建菜单（显示姓名和生命值）
    local menu = {}
    for i = 1, CC.TeamNum do
        menu[i] = {"", nil, 0}
        local id = JY.Base["队伍" .. i]
        if id >= 0 then
            -- 显示姓名和生命/生命最大值
            menu[i][1] = string.format("%-10s%4d/%4d", JY.Person[id]["姓名"], JY.Person[id]["生命"], JY.Person[id]["生命最大值"])
            menu[i][3] = 1
        end
    end
    
    -- 显示菜单（使用回调确保标题和菜单一起清除）
    local result = nil
    local CoroutineScheduler = require("coroutine_scheduler")
    local scheduler = CoroutineScheduler.getInstance()
    local menuClosed = false
    
    MenuAsync.ShowMenu(menu, CC.TeamNum, 0, CC.MainSubMenuX, startY, 0, 0, 1, 1, CC.DefaultFont, C_ORANGE, C_WHITE, function(returnValue)
        result = returnValue
        menuClosed = true
        -- 菜单关闭时立即清除标题
        currentMenuTitle = nil
    end)
    
    -- 等待菜单关闭
    while not menuClosed do
        scheduler:yield("menu")
    end
    
    return result
end

-- 执行医疗（异步版本）
-- id1: 医疗者ID, id2: 被医疗者ID
-- 返回增加的生命值
function JyMainAsync.ExecDoctorAsync(id1, id2)
    -- 检查医疗者体力
    if CONFIG and CONFIG.Debug == 1 then
        Debug(string.format("ExecDoctorAsync: id1=%d, 体力=%d, 医疗能力=%d", id1, JY.Person[id1]["体力"], JY.Person[id1]["医疗能力"]))
        Debug(string.format("ExecDoctorAsync: id2=%d, 受伤程度=%d, 生命=%d", id2, JY.Person[id2]["受伤程度"], JY.Person[id2]["生命"]))
    end
    
    if JY.Person[id1]["体力"] < 50 then
        if CONFIG and CONFIG.Debug == 1 then
            Debug("ExecDoctorAsync: 体力不足，返回0")
        end
        return 0
    end
    
    local add = JY.Person[id1]["医疗能力"]
    local value = JY.Person[id2]["受伤程度"]
    
    -- 检查受伤程度是否太高
    if value > add + 20 then
        if CONFIG and CONFIG.Debug == 1 then
            Debug(string.format("ExecDoctorAsync: 受伤程度太高(%d > %d)，返回0", value, add + 20))
        end
        return 0
    end
    
    -- 根据受伤程度计算实际医疗能力
    if value < 25 then
        add = add * 4 / 5
    elseif value < 50 then
        add = add * 3 / 4
    elseif value < 75 then
        add = add * 2 / 3
    else
        add = add / 2
    end
    
    add = math.modf(add) + Rnd(5)
    
    -- 减少受伤程度
    AddPersonAttrib(id2, "受伤程度", -add)
    
    -- 增加生命（并返回增加的值）
    local lifeAdded = AddPersonAttrib(id2, "生命", add)
    
    -- 医疗者消耗体力
    if lifeAdded > 0 then
        JY.Person[id1]["体力"] = JY.Person[id1]["体力"] - 2
    end
    
    return lifeAdded
end

-- 解毒子菜单
function JyMainAsync.Menu_DecPoison()
    -- 第一级：选择帮人解毒的人（显示解毒能力，只显示解毒能力>=20的人）
    local r1 = JyMainAsync.SelectTeamMemberWithAbilityAsync("谁要帮人解毒", "解毒能力", 20)
    if r1 <= 0 then
        Cls()
        return
    end
    
    local id1 = JY.Base["队伍" .. r1]
    
    -- 清除屏幕区域
    Cls(CC.MainSubMenuX, CC.MainSubMenuY, CC.ScreenW, CC.ScreenH)
    
    -- 第二级：选择要解毒的人（显示中毒程度）
    local r2 = JyMainAsync.SelectTeamMemberWithPoisonAsync("替谁解毒")
    if r2 <= 0 then
        Cls()
        return
    end
    
    local id2 = JY.Base["队伍" .. r2]
    
    -- 执行解毒
    local oldPoison = JY.Person[id2]["中毒程度"]
    local num = JyMainAsync.ExecDecPoisonAsync(id1, id2)
    -- 强制显示结果（即使num为0也显示）
    local newPoison = JY.Person[id2]["中毒程度"]
    AsyncMessageBox.ShowMessageCoroutine(-1, -1, string.format("%s 中毒 %d -> %d (减少 %d)", 
        JY.Person[id2]["姓名"], oldPoison, newPoison, num), C_ORANGE, CC.DefaultFont)
    
    Cls()
end

-- 异步版本的选择队友菜单（显示中毒程度）
function JyMainAsync.SelectTeamMemberWithPoisonAsync(title)
    -- 设置当前菜单标题
    currentMenuTitle = {
        title = title,
        abilityKey = "中毒程度",
        x = CC.MainSubMenuX,
        y = CC.MainSubMenuY
    }
    
    -- 计算菜单起始位置（留出空间显示标题和副标题）
    local startY = CC.MainSubMenuY + CC.SingleLineHeight * 2
    
    -- 构建菜单（显示姓名和中毒程度）
    local menu = {}
    for i = 1, CC.TeamNum do
        menu[i] = {"", nil, 0}
        local id = JY.Base["队伍" .. i]
        if id >= 0 then
            -- 显示姓名和中毒程度
            menu[i][1] = string.format("%-10s%5d", JY.Person[id]["姓名"], JY.Person[id]["中毒程度"])
            menu[i][3] = 1
        end
    end
    
    -- 显示菜单（使用回调确保标题和菜单一起清除）
    local result = nil
    local CoroutineScheduler = require("coroutine_scheduler")
    local scheduler = CoroutineScheduler.getInstance()
    local menuClosed = false
    
    MenuAsync.ShowMenu(menu, CC.TeamNum, 0, CC.MainSubMenuX, startY, 0, 0, 1, 1, CC.DefaultFont, C_ORANGE, C_WHITE, function(returnValue)
        result = returnValue
        menuClosed = true
        -- 菜单关闭时立即清除标题
        currentMenuTitle = nil
    end)
    
    -- 等待菜单关闭
    while not menuClosed do
        scheduler:yield("menu")
    end
    
    return result
end

-- 执行解毒（异步版本）
-- id1: 解毒者ID, id2: 被解毒者ID
-- 返回减少的中毒程度
function JyMainAsync.ExecDecPoisonAsync(id1, id2)
    local add = JY.Person[id1]["解毒能力"]
    local value = JY.Person[id2]["中毒程度"]
    
    -- 检查中毒程度是否太高
    if value > add + 20 then
        return 0
    end
    
    -- 计算解毒效果（使用Rnd随机数）
    add = limitX(math.modf(add / 3) + Rnd(10) - Rnd(10), 0, value)
    
    -- 减少中毒程度（使用AddPersonAttrib）
    local num = -AddPersonAttrib(id2, "中毒程度", -add)
    
    return num
end

-- 导入物品异步模块
local ItemAsync = require("item_async")

-- 物品子菜单
function JyMainAsync.Menu_Thing()
    -- 使用异步物品选择菜单
    local thingId = ItemAsync.SelectThingAsync()
    
    if thingId >= 0 then
        -- 使用选中的物品
        local success = ItemAsync.UseThingAsync(thingId)
        if success then
            -- 使用成功，减少物品数量（如果需要）
            -- 注意：某些物品（如装备）不会减少数量
            -- 实际减少数量的逻辑在 UseThingAsync 中处理
        end
    end
    
    Cls()
end

return JyMainAsync