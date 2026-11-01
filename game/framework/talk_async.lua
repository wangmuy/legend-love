-- talk_async.lua
-- 对话系统异步模块
--
-- 本模块只负责「对话的节奏与状态」：
--   ① 调 EngineAPI.dialog.measure 得到排版结果（进入新页时算一次，缓存）；
--   ② 维护 currentTalk 供 EventBridge:draw() 读取；
--   ③ 分页等待按键（InputAsync.WaitKeyCoroutine）。
--
-- 排版算法（换行 / 框宽 / 行高 / 锚点）不在本模块，而在：
--   引擎的 EngineAPI.dialog.measure（排版）+ framework/dialog_layout.lua（算法）。
--
-- 为什么下沉：对话框排版属于「渲染介质相关」决策。Love2D 有真实字体度量
-- （font:getWidth / getHeight）可以精确排版；mud 无图形输出；web 的字体由
-- 浏览器决定。Lua 层若自己算坐标就得读 CC.DefaultFont 这类常量，在 mud/web
-- 上纯属浪费且不反映真实排版。这与 EngineAPI 中已有的语义级调用一致：
--   M.map.drawScene(sceneId, x, y, offX, offY, playerPic)
-- Lua 只说「画这个场景」，引擎自己决定怎么画。

local TalkAsync = {}

local CoroutineScheduler = require("framework.coroutine_scheduler")
local InputAsync = require("framework.input_async")

-- 对话节奏配置（只保留与「分页/等待」相关的项，排版参数已下沉到引擎）
local talkConfig = {
    talkynum = 3,     -- 每页对话行数
}

-- 当前对话状态（供 draw 读取）
-- 结构：{ spec = { text, headId, flag }, layout = <EngineAPI.dialog.measure 返回值> }
local currentTalk = nil

-- 获取调度器实例
local function getScheduler()
    return CoroutineScheduler.getInstance()
end

-- 获取当前对话状态
function TalkAsync.getCurrentTalk()
    return currentTalk
end

--- 取引擎的 dialog 能力
--
-- mud / web 的 dialog.measure 是空实现（返回 nil），此时对话退化为
-- 「按 * 切段分页、不排版」：这些引擎本就没有图形对话框。
local function getDialog()
    if EngineAPI and EngineAPI.dialog then
        return EngineAPI.dialog
    end
    return nil
end

--- 把 layout.lines 按每页行数切成页
local function paginate(lines, perPage)
    local pages = {}
    local i = 1
    while i <= #lines do
        local page = {}
        for k = 0, perPage - 1 do
            if lines[i + k] == nil then
                break
            end
            page[k + 1] = lines[i + k]
        end
        pages[#pages + 1] = page
        i = i + perPage
    end
    if #pages == 0 then
        pages[1] = { "" }
    end
    return pages
end

--- 清除当前对话状态（含绘制状态）
--
-- 用于「协程已被打断、但 currentTalk 还挂着」的场合：最典型是事件里
-- 先 TalkEx 再开战（韦大宝「佣兵行会」），对话协程被战斗夺走焦点后
-- 再也没机会走到清空语句。不清掉的话 EventBridge:draw() 会一直把
-- 韦大宝的对话框画在战斗画面之上。
function TalkAsync.clear()
    currentTalk = nil
    local dialog = getDialog()
    if dialog and dialog.clear then
        dialog.clear()
    end
    lib.Debug("TalkAsync.clear: currentTalk cleared")
end

-- 对话显示（协程版本）
-- @param s: 对话字符串，用*分隔行
-- @param headid: 头像ID，-1表示不显示
-- @param flag: 对话框位置
function TalkAsync.TalkExCoroutine(s, headid, flag)
    lib.Debug(string.format("TalkExCoroutine: headid=%d, flag=%d", headid, flag))

    local talkynum = talkConfig.talkynum
    local dialog = getDialog()

    if flag < 0 or flag > 5 then
        flag = 0
    end

    -- 排版：进入对话时算一次，整段对话复用（每页只是从这个 layout 里取行）
    local spec = { text = s, headId = headid, flag = flag }
    local layout = nil
    if dialog and dialog.measure then
        layout = dialog.measure(spec)
    end

    -- 兜底：引擎未实现 measure（mud / web）时，退化为按 * 切段
    if not layout then
        local lines = {}
        local start = 1
        while true do
            local p = s:find("*", start, true)
            if not p then
                lines[#lines + 1] = s:sub(start)
                break
            end
            lines[#lines + 1] = s:sub(start, p - 1)
            start = p + 1
        end
        layout = { lines = lines, pages = 1, linesPerPage = talkynum }
    end

    local pages = paginate(layout.lines, layout.linesPerPage or talkynum)

    lib.GetKey()

    local InputManager = require("framework.input_manager")

    for pageIndex = 1, #pages do
        currentTalk = {
            spec = spec,
            layout = {
                -- 单页视图：换成本页的行，其余排版信息（框宽/锚点/行高）沿用整段
                width = layout.width,
                height = layout.height,
                lineHeight = layout.lineHeight,
                lines = pages[pageIndex],
                pages = #pages,
                pageIndex = pageIndex,
                linesPerPage = layout.linesPerPage,
                headId = layout.headId,
                flag = layout.flag,
                headBox = layout.headBox,
                textBox = layout.textBox,
                border = layout.border,
                lineY = layout.lineY,
                fontSize = layout.fontSize,
                showHead = layout.showHead,
            },
        }
        lib.Debug(string.format("TalkExCoroutine: page %d/%d, lines=%d",
            pageIndex, #pages, #pages[pageIndex]))

        -- 清除当前按键，防止同一按键立即触发下一页/下一个对话
        InputManager.getInstance():clearCurrentKey()
        local key = InputAsync.WaitKeyCoroutine()
        lib.Debug("TalkExCoroutine: key pressed=" .. tostring(key))
    end

    currentTalk = nil
    lib.Debug("TalkExCoroutine: finished")
end

-- 绘制对话（在draw函数中调用）
function TalkAsync.draw()
    if not currentTalk then
        return
    end

    -- 战斗/死亡/开始画面不画对话气泡。
    --
    -- currentTalk 是模块级状态，只在 TalkExCoroutine 的等键点被清空。
    -- 若战斗在对话挂起期间开始（韦大宝「佣兵行会」：TalkEx("祝你好运！")
    -- → WarMain 开战），currentTalk 会一直留着，而 EventBridge:draw()
    -- 每帧无条件调用本函数，于是对话框被反复画在战斗画面之上，
    -- 表现为「进入战斗后韦大宝的对话框没有消失」。
    if JY and JY.Status and (JY.Status == GAME_WMAP or JY.Status == GAME_DEAD
                             or JY.Status == GAME_START) then
        return
    end

    local dialog = getDialog()
    if not dialog or not dialog.draw then
        return
    end

    dialog.draw(currentTalk.spec, currentTalk.layout)
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
