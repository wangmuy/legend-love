-- instruct_async.lua
-- 事件指令的协程版本
-- 为所有 instruct_XXX 函数提供非阻塞的协程版本

local InstructAsync = {}

local CoroutineScheduler = require("coroutine_scheduler")
local AsyncMessageBox = require("async_message_box")
local InputAsync = require("input_async")
local MenuAsync = require("menu_async")

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

-- ============================================
-- 协程版本的辅助函数
-- ============================================

-- TalkEx 协程版本
function TalkExCoroutine(s, headid, flag)
    if s == nil then
        return
    end
    
    local function processTalkString(str)
        local pos = 1
        local len = string.len(str)
        
        while pos <= len do
            local nextPage = string.find(str, "@@@", pos)
            if nextPage then
                local page = string.sub(str, pos, nextPage - 1)
                TalkPageCoroutine(page, headid, flag)
                pos = nextPage + 3
            else
                local page = string.sub(str, pos)
                TalkPageCoroutine(page, headid, flag)
                break
            end
        end
    end
    
    processTalkString(s)
    Cls()
    ShowScreen()
end

-- TalkPage 协程版本（单页对话）
function TalkPageCoroutine(text, headid, flag)
    local x, y
    local fontsize = CC.DefaultFont
    
    if flag == 5 then
        -- 屏幕下方对话框
        x = 0
        y = CC.ScreenH - fontsize - CC.RowPixel * 3
    else
        x = -1
        y = -1
    end
    
    Cls()
    
    -- 显示头像
    if headid >= 0 then
        lib.DrawHead(headid, x, y)
    end
    
    -- 显示对话文本
    DrawStrBox(x, y, text, C_WHITE, fontsize)
    ShowScreen()
    
    -- 等待按键
    InputAsync.WaitKeyCoroutine()
end

-- WarMain 协程版本（战斗主函数）
function WarMainCoroutine(warid, isexp)
    local WarAsync = require("war_async")
    return WarAsync.WarMainCoroutine(warid, isexp)
end

return InstructAsync