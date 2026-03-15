-- instruct_async.lua
-- 事件指令的协程版本
-- 为所有 instruct_XXX 函数提供非阻塞的协程版本

local InstructAsync = {}

local CoroutineScheduler = require("coroutine_scheduler")
local AsyncMessageBox = require("async_message_box")
local InputAsync = require("input_async")
local MenuAsync = require("menu_async")
local TalkAsync = require("talk_async")

-- 获取调度器实例
local function getScheduler()
    return CoroutineScheduler.getInstance()
end

-- ============================================
-- 基础指令
-- ============================================

-- instruct_0: 清屏
function InstructAsync.instruct_0()
    Cls()
end

-- instruct_1: 对话（协程版本）
function InstructAsync.instruct_1(talkid, headid, flag)
    local s = ReadTalk(talkid)
    if s == nil then
        return
    end
    TalkExCoroutine(s, headid, flag)
end

-- instruct_2: 得到物品（协程版本）
function InstructAsync.instruct_2(thingid, num)
    if JY.Thing[thingid] == nil then
        return
    end
    local str = string.format("得到物品:%s %d", JY.Thing[thingid]["名称"], num)
    AsyncMessageBox.ShowMessageCoroutine(-1, -1, str, C_ORANGE, CC.DefaultFont)
    instruct_2_sub()
end

-- instruct_5: 选择战斗（协程版本）
function InstructAsync.instruct_5()
    return AsyncMessageBox.ShowYesNoCoroutine(-1, -1, "是否与之过招(Y/N)?", C_ORANGE, CC.DefaultFont)
end

-- instruct_6: 战斗（协程版本）
function InstructAsync.instruct_6(warid, tmp, tmp2, flag)
    local result = WarMainCoroutine(warid, 1)
    return result
end

-- instruct_9: 是否要求加入队伍（协程版本）
function InstructAsync.instruct_9()
    return AsyncMessageBox.ShowYesNoCoroutine(-1, -1, "是否要求加入(Y/N)?", C_ORANGE, CC.DefaultFont)
end

-- instruct_11: 是否住宿（协程版本）
function InstructAsync.instruct_11()
    return AsyncMessageBox.ShowYesNoCoroutine(-1, -1, "是否住宿(Y/N)?", C_ORANGE, CC.DefaultFont)
end

-- instruct_12: 住宿，回复体力（协程版本）
function InstructAsync.instruct_12()
    for i = 0, JY.PersonNum - 1 do
        local id = JY.Person[i]["人物编号"]
        JY.Person[id]["生命"] = JY.Person[id]["生命上限"]
        JY.Person[id]["内力"] = JY.Person[id]["内力上限"]
        JY.Person[id]["体力"] = JY.Person[id]["体力上限"]
    end
end

-- instruct_15: game over
function InstructAsync.instruct_15()
    Cls()
    lib.ShowSlow(50, 1)
    lib.LoadPicture(CC.EndFile, -1, -1)
    lib.ShowSlow(50, 0)
    InputAsync.WaitKeyCoroutine()
    JY.Status = GAME_END
    love.event.quit()
end

-- instruct_27: 显示动画（协程版本）
function InstructAsync.instruct_27(id, startpic, endpic)
    local scheduler = getScheduler()
    local old1, old2, old3
    
    if id ~= -1 then
        old1 = GetD(JY.SubScene, id, 5)
        old2 = GetD(JY.SubScene, id, 6)
        old3 = GetD(JY.SubScene, id, 7)
    end
    
    for i = startpic, endpic, 2 do
        local t1 = lib.GetTime()
        
        if id == -1 then
            JY.MyPic = i / 2
        else
            SetD(JY.SubScene, id, 5, i)
            SetD(JY.SubScene, id, 6, i)
            SetD(JY.SubScene, id, 7, i)
        end
        
        DtoSMap()
        DrawSMap()
        ShowScreen()
        
        local t2 = lib.GetTime()
        if t2 - t1 < CC.AnimationFrame then
            scheduler:waitForTime((CC.AnimationFrame - (t2 - t1)) / 1000)
        end
    end
    
    if id ~= -1 then
        SetD(JY.SubScene, id, 5, old1)
        SetD(JY.SubScene, id, 6, old2)
        SetD(JY.SubScene, id, 7, old3)
    end
end

-- instruct_30: 主角走动（协程版本）
function InstructAsync.instruct_30(x1, y1, x2, y2)
    local scheduler = getScheduler()
    
    if x1 < x2 then
        for i = x1 + 1, x2 do
            local t1 = lib.GetTime()
            instruct_30_sub(1)
            local t2 = lib.GetTime()
            if (t2 - t1) < CC.PersonMoveFrame then
                scheduler:waitForTime((CC.PersonMoveFrame - (t2 - t1)) / 1000)
            end
        end
    elseif x1 > x2 then
        for i = x2 + 1, x1 do
            local t1 = lib.GetTime()
            instruct_30_sub(2)
            local t2 = lib.GetTime()
            if (t2 - t1) < CC.PersonMoveFrame then
                scheduler:waitForTime((CC.PersonMoveFrame - (t2 - t1)) / 1000)
            end
        end
    end
    
    if y1 < y2 then
        for i = y1 + 1, y2 do
            local t1 = lib.GetTime()
            instruct_30_sub(3)
            local t2 = lib.GetTime()
            if (t2 - t1) < CC.PersonMoveFrame then
                scheduler:waitForTime((CC.PersonMoveFrame - (t2 - t1)) / 1000)
            end
        end
    elseif y1 > y2 then
        for i = y2 + 1, y1 do
            local t1 = lib.GetTime()
            instruct_30_sub(0)
            local t2 = lib.GetTime()
            if (t2 - t1) < CC.PersonMoveFrame then
                scheduler:waitForTime((CC.PersonMoveFrame - (t2 - t1)) / 1000)
            end
        end
    end
end

-- instruct_58: 武道大会比武（协程版本）
function InstructAsync.instruct_58()
    local group = 5
    local num1 = 6
    local num2 = 3
    local startwar = 102
    local flag = {}
    
    for i = 0, group - 1 do
        for j = 0, num1 - 1 do
            flag[j] = 0
        end
        
        for j = 1, num2 do
            local r
            while true do
                r = Rnd(num1)
                if flag[r] == 0 then
                    flag[r] = 1
                    break
                end
            end
            
            local warnum = r + i * num1
            WarLoad(warnum + startwar)
            
            InstructAsync.instruct_1(2854 + warnum, JY.Person[WAR.Data["敌人1"]]["头像代号"], 0)
            instruct_0()
            
            if WarMainCoroutine(warnum + startwar, 0) == true then
                instruct_0()
                instruct_13()
                TalkAsync.TalkExCoroutine("还有那位前辈肯赐教？", 0, 1)
                instruct_0()
            else
                InstructAsync.instruct_15()
                return
            end
        end
        
        if i < group - 1 then
            TalkAsync.TalkExCoroutine("少侠已连战三场，*可先休息再战．", 70, 0)
            instruct_0()
            instruct_14()
            getScheduler():waitForTime(0.3)
            
            if JY.Person[0]["受伤程度"] < 50 and JY.Person[0]["中毒程度"] <= 0 then
                JY.Person[0]["受伤程度"] = 0
                AddPersonAttrib(0, "体力", math.huge)
                AddPersonAttrib(0, "内力", math.huge)
                AddPersonAttrib(0, "生命", math.huge)
            end
            
            instruct_13()
            TalkAsync.TalkExCoroutine("我已经休息够了，*有谁要再上？", 0, 1)
            instruct_0()
        end
    end
    
    TalkAsync.TalkExCoroutine("接下来换谁？**．．．．*．．．．***没有人了吗？", 0, 1)
    instruct_0()
    TalkAsync.TalkExCoroutine("如果还没有人要出来向这位*少侠挑战，那麽这武功天下*第一之名，武林盟主之位，*就由这位少侠夺得．***．．．．．．*．．．．．．*．．．．．．*好，恭喜少侠，这武林盟主*之位就由少侠获得，而这把*"武林神杖"也由你保管．", 70, 0)
    instruct_0()
    TalkAsync.TalkExCoroutine("恭喜少侠！", 12, 0)
    instruct_0()
    TalkAsync.TalkExCoroutine("小兄弟，恭喜你！", 64, 4)
    instruct_0()
    TalkAsync.TalkExCoroutine("好，今年的武林大会到此已*圆满结束，希望明年各位武*林同道能再到我华山一游．", 19, 0)
    instruct_0()
    instruct_14()
    
    for i = 24, 72 do
        instruct_3(-2, i, 0, 0, -1, -1, -1, -1, -1, -1, -2, -2, -2)
    end
end

-- instruct_64: 小宝卖东西（协程版本）
function InstructAsync.instruct_64()
    local headid = 111
    
    local id = -1
    for i = 0, JY.ShopNum - 1 do
        if CC.ShopScene[i].sceneid == JY.SubScene then
            id = i
            break
        end
    end
    if id < 0 then
        id = 0
    end
    
    TalkAsync.TalkExCoroutine("这位小哥，看看有什麽需要*的，小宝我卖的东西价钱绝*对公道．", headid, 0)
    
    local menu = {}
    for i = 1, 5 do
        menu[i] = {}
        local thingid = JY.Shop[id]["物品" .. i]
        menu[i][1] = string.format("%-12s %5d", JY.Thing[thingid]["名称"], JY.Shop[id]["物品价格" .. i])
        menu[i][2] = nil
        if JY.Shop[id]["物品数量" .. i] > 0 then
            menu[i][3] = 1
        else
            menu[i][3] = 0
        end
    end
    
    local x1 = (CC.ScreenW - 9 * CC.DefaultFont - 2 * CC.MenuBorderPixel) / 2
    local y1 = (CC.ScreenH - 5 * CC.DefaultFont - 4 * CC.RowPixel - 2 * CC.MenuBorderPixel) / 2
    
    local r = MenuAsync.ShowMenuCoroutine(menu, 5, 0, x1, y1, 0, 0, 1, 1, CC.DefaultFont, C_ORANGE, C_WHITE)
    
    if r > 0 then
        if instruct_31(JY.Shop[id]["物品价格" .. r]) == false then
            TalkAsync.TalkExCoroutine("非常抱歉，*你身上的钱似乎不够．", headid, 0)
        else
            JY.Shop[id]["物品数量" .. r] = JY.Shop[id]["物品数量" .. r] - 1
            instruct_32(CC.MoneyID, -JY.Shop[id]["物品价格" .. r])
            instruct_32(JY.Shop[id]["物品" .. r], 1)
            TalkAsync.TalkExCoroutine("大爷买了我小宝的东西，*保证绝不後悔．", headid, 0)
        end
    end
    
    for i, v in ipairs(CC.ShopScene[id].d_leave) do
        instruct_3(-2, v, 0, -2, -1, -1, 939, -1, -1, -1, -2, -2, -2)
    end
end

-- ============================================
-- 协程版本的辅助函数
-- ============================================

-- TalkEx 协程版本
function TalkExCoroutine(s, headid, flag)
    TalkAsync.TalkExCoroutine(s, headid, flag)
end

-- WarMain 协程版本（战斗主函数）
function WarMainCoroutine(warid, isexp)
    local WarAsync = require("war_async")
    return WarAsync.WarMainCoroutine(warid, isexp)
end

return InstructAsync