-- instruct_async.lua
-- 事件指令的协程版本
-- 为所有 instruct_XXX 函数提供非阻塞的协程版本
-- 所有阻塞调用都被替换为异步版本

local InstructAsync = {}

local CoroutineScheduler = require("coroutine_scheduler")
local AsyncMessageBox = require("async_message_box")
local InputAsync = require("input_async")
local MenuAsync = require("menu_async")
local TalkAsync = require("talk_async")
local WarAsync = require("war_async")

-- 获取调度器实例
local function getScheduler()
    return CoroutineScheduler.getInstance()
end

-- 异步显示消息
local function ShowMessageAsync(msg, color)
    return AsyncMessageBox.ShowMessageCoroutine(-1, -1, msg, color or C_WHITE, CC.DefaultFont)
end

-- 异步显示确认框
local function ShowYesNoAsync(msg, color)
    return AsyncMessageBox.ShowYesNoCoroutine(-1, -1, msg, color or C_WHITE, CC.DefaultFont)
end

-- ============================================
-- 基础指令
-- ============================================

-- instruct_0: 清屏
function InstructAsync.instruct_0()
    Cls()
end

-- instruct_1: 对话
function InstructAsync.instruct_1(talkid, headid, flag)
    local s = ReadTalk(talkid)
    if s == nil then return end
    TalkAsync.TalkExCoroutine(s, headid, flag)
end

-- instruct_2: 得到物品
function InstructAsync.instruct_2(thingid, num)
    if JY.Thing[thingid] == nil then return end
    local str = string.format("得到物品:%s %d", JY.Thing[thingid]["名称"], num)
    ShowMessageAsync(str, C_ORANGE)
    instruct_2_sub()
end

-- instruct_3: 修改D*
function InstructAsync.instruct_3(sceneid, id, v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10)
    instruct_3(sceneid, id, v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10)
end

-- instruct_4: 是否使用物品触发
function InstructAsync.instruct_4(thingid)
    return instruct_4(thingid)
end

-- instruct_5: 选择战斗
function InstructAsync.instruct_5()
    return ShowYesNoAsync("是否与之过招(Y/N)?", C_ORANGE)
end

-- instruct_6: 战斗
function InstructAsync.instruct_6(warid, tmp, tmp2, flag)
    return WarAsync.WarMainCoroutine(warid, 1)
end

-- instruct_7: return（已废弃）
function InstructAsync.instruct_7()
    return instruct_7()
end

-- instruct_8: 改变主地图音乐
function InstructAsync.instruct_8(musicid)
    instruct_8(musicid)
end

-- instruct_9: 是否要求加入队伍
function InstructAsync.instruct_9()
    return ShowYesNoAsync("是否要求加入(Y/N)?", C_ORANGE)
end

-- instruct_10: 加入队员
function InstructAsync.instruct_10(personid)
    instruct_10(personid)
end

-- instruct_11: 是否住宿
function InstructAsync.instruct_11()
    return ShowYesNoAsync("是否住宿(Y/N)?", C_ORANGE)
end

-- instruct_12: 住宿，回复体力
function InstructAsync.instruct_12()
    for i = 0, JY.PersonNum - 1 do
        local id = JY.Person[i]["人物编号"]
        JY.Person[id]["生命"] = JY.Person[id]["生命上限"]
        JY.Person[id]["内力"] = JY.Person[id]["内力上限"]
        JY.Person[id]["体力"] = JY.Person[id]["体力上限"]
    end
end

-- instruct_13: 场景变亮
function InstructAsync.instruct_13()
    instruct_13()
end

-- instruct_14: 场景变黑
function InstructAsync.instruct_14()
    instruct_14()
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

-- instruct_16: 队伍中是否有某人
function InstructAsync.instruct_16(personid)
    return instruct_16(personid)
end

-- instruct_17: 修改场景图形
function InstructAsync.instruct_17(sceneid, level, x, y, v)
    instruct_17(sceneid, level, x, y, v)
end

-- instruct_18: 是否有某种物品
function InstructAsync.instruct_18(thingid)
    return instruct_18(thingid)
end

-- instruct_19: 改变主角位置
function InstructAsync.instruct_19(x, y)
    instruct_19(x, y)
end

-- instruct_20: 判断队伍是否满
function InstructAsync.instruct_20()
    return instruct_20()
end

-- instruct_21: 离队
function InstructAsync.instruct_21(personid)
    instruct_21(personid)
end

-- instruct_22: 内力降为0
function InstructAsync.instruct_22()
    instruct_22()
end

-- instruct_23: 设置用毒
function InstructAsync.instruct_23(personid, value)
    instruct_23(personid, value)
end

-- instruct_24: 
function InstructAsync.instruct_24()
    instruct_24()
end

-- instruct_25: 场景移动
function InstructAsync.instruct_25(x1, y1, x2, y2)
    instruct_25(x1, y1, x2, y2)
end

-- instruct_26: 增加D*编号
function InstructAsync.instruct_26(sceneid, id, v1, v2, v3)
    instruct_26(sceneid, id, v1, v2, v3)
end

-- instruct_27: 显示动画
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
        -- 在 Love2D 中，不需要手动调用 ShowScreen，让 love.draw() 自动处理
        -- ShowScreen()
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

-- instruct_28: 判断品德
function InstructAsync.instruct_28(personid, vmin, vmax)
    return instruct_28(personid, vmin, vmax)
end

-- instruct_29: 判断攻击力
function InstructAsync.instruct_29(personid, vmin, vmax)
    return instruct_29(personid, vmin, vmax)
end

-- instruct_30: 主角走动
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

-- instruct_31: 判断是否够钱
function InstructAsync.instruct_31(num)
    return instruct_31(num)
end

-- instruct_32: 增加物品
function InstructAsync.instruct_32(thingid, num)
    instruct_32(thingid, num)
end

-- instruct_33: 学会武功
function InstructAsync.instruct_33(personid, wugongid, flag)
    instruct_33(personid, wugongid, flag)
    if flag == nil or flag == 0 then
        ShowMessageAsync(string.format("%s 学会武功 %s", JY.Person[personid]["姓名"], JY.Wugong[wugongid]["名称"]), C_ORANGE)
    end
end

-- instruct_34: 资质增加
function InstructAsync.instruct_34(id, value)
    instruct_34(id, value)
end

-- instruct_35: 设置武功
function InstructAsync.instruct_35(personid, id, wugongid, wugonglevel)
    instruct_35(personid, id, wugongid, wugonglevel)
end

-- instruct_36: 判断主角性别
function InstructAsync.instruct_36(sex)
    return instruct_36(sex)
end

-- instruct_37: 增加品德
function InstructAsync.instruct_37(v)
    instruct_37(v)
end

-- instruct_38: 修改场景某层贴图
function InstructAsync.instruct_38(sceneid, level, oldpic, newpic)
    instruct_38(sceneid, level, oldpic, newpic)
end

-- instruct_39: 打开场景
function InstructAsync.instruct_39(sceneid)
    instruct_39(sceneid)
end

-- instruct_40: 改变主角方向
function InstructAsync.instruct_40(v)
    instruct_40(v)
end

-- instruct_41: 其他人员增加物品
function InstructAsync.instruct_41(personid, thingid, num)
    instruct_41(personid, thingid, num)
end

-- instruct_42: 队伍中是否有女性
function InstructAsync.instruct_42()
    return instruct_42()
end

-- instruct_43: 是否有某种物品
function InstructAsync.instruct_43(thingid)
    return instruct_43(thingid)
end

-- instruct_44: 同时显示两个动画
function InstructAsync.instruct_44(id1, startpic1, endpic1, id2, startpic2, endpic2)
    instruct_44(id1, startpic1, endpic1, id2, startpic2, endpic2)
end

-- instruct_45: 增加轻功
function InstructAsync.instruct_45(id, value)
    instruct_45(id, value)
end

-- instruct_46: 增加内力
function InstructAsync.instruct_46(id, value)
    instruct_46(id, value)
end

-- instruct_47: 
function InstructAsync.instruct_47(id, value)
    instruct_47(id, value)
end

-- instruct_48: 增加生命
function InstructAsync.instruct_48(id, value)
    instruct_48(id, value)
end

-- instruct_49: 设置内力属性
function InstructAsync.instruct_49(personid, value)
    instruct_49(personid, value)
end

-- instruct_50: 判断是否有5种物品
function InstructAsync.instruct_50(id1, id2, id3, id4, id5)
    return instruct_50(id1, id2, id3, id4, id5)
end

-- instruct_51: 问软体娃娃
function InstructAsync.instruct_51()
    instruct_51()
end

-- instruct_52: 看品德
function InstructAsync.instruct_52()
    ShowMessageAsync(string.format("你现在的品德指数为: %d", JY.Person[0]["品德"]), C_ORANGE)
end

-- instruct_53: 看声望
function InstructAsync.instruct_53()
    ShowMessageAsync(string.format("你现在的声望指数为: %d", JY.Person[0]["声望"]), C_ORANGE)
end

-- instruct_54: 开放其他场景
function InstructAsync.instruct_54()
    instruct_54()
end

-- instruct_55: 判断D*编号的触发事件
function InstructAsync.instruct_55(id, num)
    return instruct_55(id, num)
end

-- instruct_56: 增加声望
function InstructAsync.instruct_56(v)
    instruct_56(v)
end

-- instruct_57: 高昌迷宫劈门
function InstructAsync.instruct_57()
    instruct_57()
end

-- instruct_58: 武道大会比武
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
            
            if WarAsync.WarMainCoroutine(warnum + startwar, 0) == true then
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

-- instruct_59: 全体队员离队
function InstructAsync.instruct_59()
    instruct_59()
end

-- instruct_60: 判断D*图片
function InstructAsync.instruct_60(sceneid, id, num)
    return instruct_60(sceneid, id, num)
end

-- instruct_61: 判断是否放完14天书
function InstructAsync.instruct_61()
    return instruct_61()
end

-- instruct_62: 播放时空机动画
function InstructAsync.instruct_62(id1, startnum1, endnum1, id2, startnum2, endnum2)
    instruct_62(id1, startnum1, endnum1, id2, startnum2, endnum2)
end

-- instruct_63: 设置性别
function InstructAsync.instruct_63(personid, sex)
    instruct_63(personid, sex)
end

-- instruct_64: 小宝卖东西
function InstructAsync.instruct_64()
    local headid = 111
    
    local id = -1
    for i = 0, JY.ShopNum - 1 do
        if CC.ShopScene[i].sceneid == JY.SubScene then
            id = i
            break
        end
    end
    if id < 0 then id = 0 end
    
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

-- instruct_65: 小宝去其他客栈
function InstructAsync.instruct_65()
    instruct_65()
end

-- instruct_66: 播放音乐
function InstructAsync.instruct_66(id)
    instruct_66(id)
end

-- instruct_67: 播放音效
function InstructAsync.instruct_67(id)
    instruct_67(id)
end

-- instruct_test: 测试指令
function InstructAsync.instruct_test(s)
    ShowMessageAsync(s, C_ORANGE)
end

return InstructAsync