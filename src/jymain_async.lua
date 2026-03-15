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
        {"医疗", JyMainAsync.Menu_DoctorCoroutine, 1},
        {"解毒", JyMainAsync.Menu_DecPoisonCoroutine, 1},
        {"物品", JyMainAsync.Menu_ThingCoroutine, 1},
        {"状态", JyMainAsync.Menu_StatusCoroutine, 1},
        {"离队", JyMainAsync.Menu_PersonExitCoroutine, 1},
        {"系统", JyMainAsync.Menu_SystemCoroutine, 1},
    }
    
    if JY.Status == GAME_SMAP then
        menu[5][3] = 0
        menu[6][3] = 0
    end
    
    MenuAsync.ShowMenuCoroutine(menu, 6, 0, CC.MainMenuX, CC.MainMenuY, 0, 0, 1, 1, CC.DefaultFont, C_ORANGE, C_WHITE)
end

-- 系统子菜单（协程版本）
function JyMainAsync.Menu_SystemCoroutine()
    local menu = {
        {"读取进度", JyMainAsync.Menu_ReadRecordCoroutine, 1},
        {"保存进度", JyMainAsync.Menu_SaveRecordCoroutine, 1},
        {"离开游戏", JyMainAsync.Menu_ExitCoroutine, 1},
    }
    
    local r = MenuAsync.ShowMenuCoroutine(menu, 3, 0, CC.MainSubMenuX, CC.MainSubMenuY, 0, 0, 1, 1, CC.DefaultFont, C_ORANGE, C_WHITE)
    
    if r == 0 then
        return 0
    elseif r < 0 then
        return 1
    end
end

-- 离开菜单（协程版本）
function JyMainAsync.Menu_ExitCoroutine()
    Cls()
    if AsyncMessageBox.ShowYesNoCoroutine(-1, -1, "是否真的要离开游戏？", C_WHITE, CC.DefaultFont) == true then
        JY.Status = GAME_END
    end
    return 1
end

-- 保存进度（协程版本）
function JyMainAsync.Menu_SaveRecordCoroutine()
    local menu = {
        {"进度一", nil, 1},
        {"进度二", nil, 1},
        {"进度三", nil, 1},
    }
    
    local r = MenuAsync.ShowMenuCoroutine(menu, 3, 0, CC.MainSubMenuX2, CC.MainSubMenuY, 0, 0, 1, 1, CC.DefaultFont, C_ORANGE, C_WHITE)
    
    if r > 0 then
        DrawStrBox(CC.MainSubMenuX2, CC.MainSubMenuY, "请稍候......", C_WHITE, CC.DefaultFont)
        ShowScreen()
        SaveRecord(r)
        Cls(CC.MainSubMenuX2, CC.MainSubMenuY, CC.ScreenW, CC.ScreenH)
    end
    return 0
end

-- 读取进度（协程版本）
function JyMainAsync.Menu_ReadRecordCoroutine()
    local menu = {
        {"进度一", nil, 1},
        {"进度二", nil, 1},
        {"进度三", nil, 1},
    }
    
    local r = MenuAsync.ShowMenuCoroutine(menu, 3, 0, CC.MainSubMenuX2, CC.MainSubMenuY, 0, 0, 1, 1, CC.DefaultFont, C_ORANGE, C_WHITE)
    
    if r == 0 then
        return 0
    elseif r > 0 then
        DrawStrBox(CC.MainSubMenuX2, CC.MainSubMenuY, "请稍候......", C_WHITE, CC.DefaultFont)
        ShowScreen()
        LoadRecord(r)
        JY.Status = GAME_FIRSTMMAP
        return 1
    end
end

-- 状态子菜单（协程版本）
function JyMainAsync.Menu_StatusCoroutine()
    DrawStrBox(CC.MainSubMenuX, CC.MainSubMenuY, "要查阅谁的状态", C_WHITE, CC.DefaultFont)
    local nexty = CC.MainSubMenuY + CC.SingleLineHeight
    
    local r = SelectTeamMenu(CC.MainSubMenuX, nexty)
    if r > 0 then
        ShowPersonStatus(r)
        return 1
    else
        Cls()
        return 0
    end
end

-- 离队（协程版本）
function JyMainAsync.Menu_PersonExitCoroutine()
    DrawStrBox(CC.MainSubMenuX, CC.MainSubMenuY, "要求谁离队", C_WHITE, CC.DefaultFont)
    local nexty = CC.MainSubMenuY + CC.SingleLineHeight
    
    local r = SelectTeamMenu(CC.MainSubMenuX, nexty)
    
    if r == 1 then
        AsyncMessageBox.ShowMessageCoroutine(-1, -1, "抱歉！没有你游戏进行不下去", C_WHITE, CC.DefaultFont)
    elseif r > 1 then
        local personid = JY.Base["队伍" .. r]
        for i, v in ipairs(CC.PersonExit) do
            if personid == v[1] then
                AsyncMessageBox.ShowMessageCoroutine(-1, -1, "抱歉！" .. JY.Person[personid]["姓名"] .. "不能离队", C_WHITE, CC.DefaultFont)
                return 0
            end
        end
        
        if AsyncMessageBox.ShowYesNoCoroutine(-1, -1, JY.Person[personid]["姓名"] .. "要离队吗？", C_WHITE, CC.DefaultFont) == true then
            instruct_21(personid)
        end
    end
    return 0
end

-- 医疗子菜单（协程版本）
function JyMainAsync.Menu_DoctorCoroutine()
    DrawStrBox(CC.MainSubMenuX, CC.MainSubMenuY, "要医疗谁", C_WHITE, CC.DefaultFont)
    local nexty = CC.MainSubMenuY + CC.SingleLineHeight
    
    local r = SelectTeamMenu(CC.MainSubMenuX, nexty)
    if r > 0 then
        local id = JY.Base["队伍" .. r]
        local id2
        
        if JY.Person[id]["体力"] < 10 then
            AsyncMessageBox.ShowMessageCoroutine(-1, -1, "体力不足，不能医疗", C_WHITE, CC.DefaultFont)
            return 0
        end
        
        if JY.Person[id]["受伤程度"] <= 0 and JY.Person[id]["中毒程度"] <= 0 then
            AsyncMessageBox.ShowMessageCoroutine(-1, -1, JY.Person[id]["姓名"] .. "生命正常，无需医疗", C_WHITE, CC.DefaultFont)
            return 0
        end
        
        local num = math.modf(JY.Person[id]["医疗能力"] * JY.Person[id]["生命上限"] / 100)
        if num <= 0 then num = 1 end
        
        JY.Person[id]["受伤程度"] = JY.Person[id]["受伤程度"] - num
        if JY.Person[id]["受伤程度"] < 0 then JY.Person[id]["受伤程度"] = 0 end
        
        JY.Person[id]["中毒程度"] = JY.Person[id]["中毒程度"] - num
        if JY.Person[id]["中毒程度"] < 0 then JY.Person[id]["中毒程度"] = 0 end
        
        if JY.Person[id]["中毒程度"] > 0 then
            AsyncMessageBox.ShowMessageCoroutine(-1, -1, string.format("%s 中毒程度减少 %d", JY.Person[id]["姓名"], num), C_ORANGE, CC.DefaultFont)
        else
            AsyncMessageBox.ShowMessageCoroutine(-1, -1, string.format("%s 生命增加 %d", JY.Person[id]["姓名"], num), C_ORANGE, CC.DefaultFont)
        end
        
        JY.Person[id]["体力"] = JY.Person[id]["体力"] - 10
    end
    return 0
end

-- 解毒子菜单（协程版本）
function JyMainAsync.Menu_DecPoisonCoroutine()
    DrawStrBox(CC.MainSubMenuX, CC.MainSubMenuY, "要为谁解毒", C_WHITE, CC.DefaultFont)
    local nexty = CC.MainSubMenuY + CC.SingleLineHeight
    
    local r = SelectTeamMenu(CC.MainSubMenuX, nexty)
    if r > 0 then
        local id = JY.Base["队伍" .. r]
        
        if JY.Person[id]["中毒程度"] <= 0 then
            AsyncMessageBox.ShowMessageCoroutine(-1, -1, JY.Person[id]["姓名"] .. "没有中毒", C_WHITE, CC.DefaultFont)
            return 0
        end
        
        local num = math.modf(JY.Person[id]["解毒能力"] * JY.Person[id]["生命上限"] / 100)
        if num <= 0 then num = 1 end
        
        JY.Person[id]["中毒程度"] = JY.Person[id]["中毒程度"] - num
        if JY.Person[id]["中毒程度"] < 0 then JY.Person[id]["中毒程度"] = 0 end
        
        AsyncMessageBox.ShowMessageCoroutine(-1, -1, string.format("%s 中毒程度减少 %d", JY.Person[id]["姓名"], num), C_ORANGE, CC.DefaultFont)
    end
    return 0
end

-- 物品子菜单（协程版本）
function JyMainAsync.Menu_ThingCoroutine()
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
        return 0
    end
    
    local x1 = (CC.ScreenW - 10 * CC.DefaultFont - 2 * CC.MenuBorderPixel) / 2
    local y1 = (CC.ScreenH - 10 * CC.DefaultFont - 2 * CC.MenuBorderPixel) / 2
    
    local r = MenuAsync.ShowMenuCoroutine(things, num, 0, x1, y1, 0, 0, 1, 1, CC.DefaultFont, C_ORANGE, C_WHITE)
    
    if r > 0 then
        local thingid = things[r][4]
        UseThingSelect(thingid)
    end
    
    return 0
end

-- 物品使用选择（协程版本）
function JyMainAsync.UseThingSelectCoroutine(thingid)
    local thingType = JY.Thing[thingid]["类型"]
    
    if thingType == 0 then
        -- 药品，选择使用对象
        DrawStrBox(CC.MainSubMenuX, CC.MainSubMenuY, "要给谁使用", C_WHITE, CC.DefaultFont)
        local nexty = CC.MainSubMenuY + CC.SingleLineHeight
        local r = SelectTeamMenu(CC.MainSubMenuX, nexty)
        
        if r > 0 then
            local id = JY.Base["队伍" .. r]
            UseThing(id, thingid)
        end
    else
        -- 其他物品
        UseThing(0, thingid)
    end
end

return JyMainAsync