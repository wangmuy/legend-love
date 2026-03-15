-- jymain_async.lua
-- 游戏主逻辑的异步版本
-- 替换 MMenu、物品系统等函数中的阻塞调用

local JyMainAsync = {}

local CoroutineScheduler = require("coroutine_scheduler")
local MenuAsync = require("menu_async")
local AsyncMessageBox = require("async_message_box")
local InputAsync = require("input_async")
local TalkAsync = require("talk_async")

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
    DrawStrBox(CC.MainSubMenuX, CC.MainSubMenuY, "要查阅谁的状态", C_WHITE, CC.DefaultFont)
    local nexty = CC.MainSubMenuY + CC.SingleLineHeight

    local r = SelectTeamMenu(CC.MainSubMenuX, nexty)
    if r > 0 then
        ShowPersonStatus(r)
    else
        Cls()
    end
end

-- 离队菜单
function JyMainAsync.Menu_PersonExit()
    DrawStrBox(CC.MainSubMenuX, CC.MainSubMenuY, "要求谁离队", C_WHITE, CC.DefaultFont)
    local nexty = CC.MainSubMenuY + CC.SingleLineHeight

    local r = SelectTeamMenu(CC.MainSubMenuX, nexty)
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

-- 医疗子菜单
function JyMainAsync.Menu_Doctor()
    DrawStrBox(CC.MainSubMenuX, CC.MainSubMenuY, "要医疗谁", C_WHITE, CC.DefaultFont)
    local nexty = CC.MainSubMenuY + CC.SingleLineHeight
    
    local r = SelectTeamMenu(CC.MainSubMenuX, nexty)
    if r > 0 then
        local id = JY.Base["队伍" .. r]
        
        if JY.Person[id]["体力"] < 10 then
            AsyncMessageBox.ShowMessageCoroutine(-1, -1, "体力不足，不能医疗", C_WHITE, CC.DefaultFont)
            Cls()
            return
        end
        
        if JY.Person[id]["受伤程度"] <= 0 and JY.Person[id]["中毒程度"] <= 0 then
            AsyncMessageBox.ShowMessageCoroutine(-1, -1, JY.Person[id]["姓名"] .. "生命正常，无需医疗", C_WHITE, CC.DefaultFont)
            Cls()
            return
        end
        
        local num = math.modf(JY.Person[id]["医疗能力"] * JY.Person[id]["生命上限"] / 100)
        if num <= 0 then num = 1 end
        
        JY.Person[id]["受伤程度"] = JY.Person[id]["受伤程度"] - num
        if JY.Person[id]["受伤程度"] < 0 then JY.Person[id]["受伤程度"] = 0 end
        
        JY.Person[id]["中毒程度"] = JY.Person[id]["中毒程度"] - num
        if JY.Person[id]["中毒程度"] < 0 then JY.Person[id]["中毒程度"] = 0 end
        
        AsyncMessageBox.ShowMessageCoroutine(-1, -1, string.format("%s 生命增加 %d", JY.Person[id]["姓名"], num), C_ORANGE, CC.DefaultFont)
        
        JY.Person[id]["体力"] = JY.Person[id]["体力"] - 10
    end
    Cls()
end

-- 解毒子菜单
function JyMainAsync.Menu_DecPoison()
    DrawStrBox(CC.MainSubMenuX, CC.MainSubMenuY, "要为谁解毒", C_WHITE, CC.DefaultFont)
    local nexty = CC.MainSubMenuY + CC.SingleLineHeight
    
    local r = SelectTeamMenu(CC.MainSubMenuX, nexty)
    if r > 0 then
        local id = JY.Base["队伍" .. r]
        
        if JY.Person[id]["中毒程度"] <= 0 then
            AsyncMessageBox.ShowMessageCoroutine(-1, -1, JY.Person[id]["姓名"] .. "没有中毒", C_WHITE, CC.DefaultFont)
            Cls()
            return
        end
        
        local num = math.modf(JY.Person[id]["解毒能力"] * JY.Person[id]["生命上限"] / 100)
        if num <= 0 then num = 1 end
        
        JY.Person[id]["中毒程度"] = JY.Person[id]["中毒程度"] - num
        if JY.Person[id]["中毒程度"] < 0 then JY.Person[id]["中毒程度"] = 0 end
        
        AsyncMessageBox.ShowMessageCoroutine(-1, -1, string.format("%s 中毒程度减少 %d", JY.Person[id]["姓名"], num), C_ORANGE, CC.DefaultFont)
    end
    Cls()
end

-- 物品子菜单
function JyMainAsync.Menu_Thing()
    local things = {}
    local num = 0
    
    for i = 0, JY.ThingNum - 1 do
        if JY.Thing[i]["数量"] > 0 then
            num = num + 1
            things[num] = {JY.Thing[i]["名称"], nil, 1, i}
        end
    end
    
    if num == 0 then
        AsyncMessageBox.ShowMessageCoroutine(-1, -1, "没有物品", C_WHITE, CC.DefaultFont)
        Cls()
        return
    end
    
    local x1 = (CC.ScreenW - 10 * CC.DefaultFont - 2 * CC.MenuBorderPixel) / 2
    local y1 = (CC.ScreenH - 10 * CC.DefaultFont - 2 * CC.MenuBorderPixel) / 2
    
    local r = MenuAsync.ShowMenuCoroutine(things, num, 0, x1, y1, 0, 0, 1, 1, CC.DefaultFont, C_ORANGE, C_WHITE)
    
    if r > 0 then
        local thingid = things[r][4]
        UseThingSelect(thingid)
    end
    
    Cls()
end

return JyMainAsync