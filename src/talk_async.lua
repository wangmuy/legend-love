-- talk_async.lua
-- 对话系统异步模块
-- 提供对话显示的协程版本函数

local TalkAsync = {}

local CoroutineScheduler = require("coroutine_scheduler")
local InputAsync = require("input_async")

-- 对话框配置
local talkConfig = {
    picw = 100,       -- 最大头像图片宽
    pich = 100,       -- 最大头像图片高
    talkxnum = 12,    -- 对话一行字数
    talkynum = 3,     -- 对话行数
    dx = 2,
    dy = 2,
}

-- 获取调度器实例
local function getScheduler()
    return CoroutineScheduler.getInstance()
end

-- 计算对话框位置配置
local function getTalkPosition(flag)
    local picw = talkConfig.picw
    local pich = talkConfig.pich
    local dx = talkConfig.dx
    local dy = talkConfig.dy
    local boxpicw = picw + 10
    local boxpich = pich + 10
    local boxtalkw = 12 * CC.DefaultFont + 10
    local boxtalkh = boxpich
    
    local xy = {
        [0] = {
            headx = dx, heady = dy,
            talkx = dx + boxpicw + 2, talky = dy,
            showhead = 1
        },
        {
            headx = CC.ScreenW - 1 - dx - boxpicw, heady = CC.ScreenH - dy - boxpich,
            talkx = CC.ScreenW - 1 - dx - boxpicw - boxtalkw - 2, talky = CC.ScreenH - dy - boxpich,
            showhead = 1
        },
        {
            headx = dx, heady = dy,
            talkx = dx + boxpicw + 2, talky = dy,
            showhead = 0
        },
        {
            headx = CC.ScreenW - 1 - dx - boxpicw, heady = CC.ScreenH - dy - boxpich,
            talkx = CC.ScreenW - 1 - dx - boxpicw - boxtalkw - 2, talky = CC.ScreenH - dy - boxpich,
            showhead = 1
        },
        {
            headx = CC.ScreenW - 1 - dx - boxpicw, heady = dy,
            talkx = CC.ScreenW - 1 - dx - boxpicw - boxtalkw - 2, talky = dy,
            showhead = 1
        },
        {
            headx = dx, heady = CC.ScreenH - dy - boxpich,
            talkx = dx + boxpicw + 2, talky = CC.ScreenH - dy - boxpich,
            showhead = 1
        },
    }
    
    if flag < 0 or flag > 5 then
        flag = 0
    end
    
    return xy[flag], boxtalkw, boxtalkh
end

-- 生成分行字符串
local function GenTalkString(s, linelen)
    local newstr = ""
    local len = string.len(s)
    local start = 1
    
    while start <= len do
        local endp = start + linelen - 1
        if endp > len then
            endp = len
        end
        newstr = newstr .. string.sub(s, start, endp) .. "*"
        start = endp + 1
    end
    
    return newstr
end

-- 当前对话状态（用于在draw中绘制）
local currentTalk = nil

-- 获取当前对话状态
function TalkAsync.getCurrentTalk()
    return currentTalk
end

-- 对话显示（协程版本）
-- @param s: 对话字符串，用*分隔行
-- @param headid: 头像ID，-1表示不显示
-- @param flag: 对话框位置
function TalkAsync.TalkExCoroutine(s, headid, flag)
    lib.Debug(string.format("TalkExCoroutine: headid=%d, flag=%d", headid, flag))
    
    local picw = talkConfig.picw
    local pich = talkConfig.pich
    local talkynum = talkConfig.talkynum
    local talkBorder = (pich - talkynum * CC.DefaultFont) / (talkynum + 1)
    
    local xy, boxtalkw, boxtalkh = getTalkPosition(flag)
    
    if xy.showhead == 0 then
        headid = -1
    end
    
    -- 自动分行
    if string.find(s, "*") == nil then
        s = GenTalkString(s, 12)
    end
    
    lib.GetKey()
    
    local startp = 1
    local endp
    local dy = 0
    local lines = {}  -- 存储当前页要显示的行
    
    while true do
        if dy == 0 then
            lines = {}  -- 清空行列表
            lib.Debug("TalkExCoroutine: starting new page")
        end
        
        endp = string.find(s, "*", startp)
        
        if endp == nil then
            -- 最后一行
            table.insert(lines, string.sub(s, startp))
            lib.Debug("TalkExCoroutine: last line, lines count=" .. #lines)
            
            -- 设置当前对话状态，让draw函数绘制
            currentTalk = {
                headid = headid,
                flag = flag,
                lines = lines,
                xy = xy,
                boxtalkw = boxtalkw,
                boxtalkh = boxtalkh,
                picw = picw,
                pich = pich,
                talkBorder = talkBorder,
            }
            lib.Debug("TalkExCoroutine: waiting for key (last page)")
            InputAsync.WaitKeyCoroutine()
            lib.Debug("TalkExCoroutine: key pressed, clearing currentTalk")
            currentTalk = nil  -- 清除对话状态
            break
        else
            table.insert(lines, string.sub(s, startp, endp - 1))
        end
        
        dy = dy + 1
        startp = endp + 1
        
        if dy >= talkynum then
            lib.Debug("TalkExCoroutine: page full, lines count=" .. #lines)
            -- 设置当前对话状态，让draw函数绘制
            currentTalk = {
                headid = headid,
                flag = flag,
                lines = lines,
                xy = xy,
                boxtalkw = boxtalkw,
                boxtalkh = boxtalkh,
                picw = picw,
                pich = pich,
                talkBorder = talkBorder,
            }
            lib.Debug("TalkExCoroutine: waiting for key (page full)")
            InputAsync.WaitKeyCoroutine()
            lib.Debug("TalkExCoroutine: key pressed, resetting dy")
            dy = 0
            currentTalk = nil  -- 清除当前页，准备下一页
        end
    end
    
    currentTalk = nil
    lib.Debug("TalkExCoroutine: finished")
end

-- 绘制对话（在draw函数中调用）
function TalkAsync.draw()
    if not currentTalk then
        return
    end
    
    lib.Debug("TalkAsync.draw: drawing talk with headid=" .. tostring(currentTalk.headid))
    
    local talk = currentTalk
    local xy = talk.xy
    local picw = talk.picw
    local pich = talk.pich
    local talkBorder = talk.talkBorder
    local headid = talk.headid
    
    -- 显示头像
    if headid >= 0 then
        local boxpicw = picw + 10
        local boxpich = pich + 10
        DrawBox(xy.headx, xy.heady, xy.headx + boxpicw, xy.heady + boxpich, C_WHITE)
        
        local w, h = lib.PicGetXY(1, headid * 2)
        local x = (picw - w) / 2
        local y = (pich - h) / 2
        lib.PicLoadCache(1, headid * 2, xy.headx + 5 + x, xy.heady + 5 + y, 1)
    end
    
    -- 绘制对话框
    DrawBox(xy.talkx, xy.talky, xy.talkx + talk.boxtalkw, xy.talky + talk.boxtalkh, C_WHITE)
    
    -- 绘制文字
    for i, line in ipairs(talk.lines) do
        DrawString(xy.talkx + 5, xy.talky + 5 + talkBorder + (i-1) * (CC.DefaultFont + talkBorder),
                   line, C_WHITE, CC.DefaultFont)
    end
end

-- 简单版本对话（协程版本）
function TalkAsync.TalkCoroutine(s, personid)
    local flag
    if personid == 0 then
        flag = 1
    else
        flag = 0
    end
    TalkAsync.TalkExCoroutine(s, JY.Person[personid]["头像代号"], flag)
end

return TalkAsync