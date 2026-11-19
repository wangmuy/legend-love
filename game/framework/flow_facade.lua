-- flow_facade.lua
-- 流程外观层：framework 不再调用 game/script 定义的全局流程函数
--
-- 分层（change: port-script-decoupling）：
--
--   game/framework/*.lua
--        │  调本文件
--        ▼
--   framework/flow_facade.lua      ← 转发到**既有 framework 模块**
--        │
--        ▼
--   menu_async / input_async / talk_async / async_message_box
--
-- **为什么不直接转发到 EngineAPI**：
--   ShowMenu / WaitKey / TalkEx 是**语义级**函数（"开菜单"、"等一个键"），
--   它们各自有一整套 framework 实现（菜单状态机、协程调度、对话排版）。
--   这些实现的归属本来就是 framework，只是**函数名恰好定义在 script 层**。
--   所以本层转发到 framework 模块，而不是转发到引擎契约。
--
-- **本文件不得**：读写 JY / WAR / CC、包含业务逻辑、调 script 全局。

local FlowFacade = {}

local function api()
    return rawget(_G, "EngineAPI")
end

-- ---------------------------------------------------------------------------
-- 菜单
-- ---------------------------------------------------------------------------

--- 开菜单（协程版，阻塞直到关闭并返回选择）
--
-- 转发到 framework/menu_async 的 ShowMenuCoroutine。
-- script 层 jymain.lua 的 ShowMenu 是它的薄包装（见 Task 5）。
--
-- @param items table 菜单项数组
-- @param numItem number 项数
-- @param numShow number 显示项数（0 = 全部）
-- @param x1, y1 number 位置
-- @param x2, y2 number 尺寸（都 0 = 自动定宽）
-- @param isBox number 0/1 是否画框
-- @param isEsc number 0/1 ESC 是否可关
-- @param size number 字号
-- @param color, selectColor number|table
-- @param align string|nil "left" | "center"
-- @return number 选项下标（0 = ESC 取消）
function FlowFacade.showMenu(items, numItem, numShow, x1, y1, x2, y2,
                              isBox, isEsc, size, color, selectColor, align)
    local ok, MenuAsync = pcall(require, "framework.menu_async")
    if not ok or not MenuAsync or not MenuAsync.ShowMenuCoroutine then return 0 end
    local ok2, r = pcall(MenuAsync.ShowMenuCoroutine,
        items, numItem, numShow, x1, y1, x2, y2, isBox, isEsc,
        size, color, selectColor, align)
    if ok2 and type(r) == "number" then return r end
    return 0
end

--- 开横向菜单（协程版）
-- @return number
function FlowFacade.showMenu2(items, numItem, numShow, x1, y1, x2, y2,
                               isBox, isEsc, size, color, selectColor)
    local ok, MenuAsync = pcall(require, "framework.menu_async")
    if not ok or not MenuAsync or not MenuAsync.ShowMenu2Coroutine then return 0 end
    local ok2, r = pcall(MenuAsync.ShowMenu2Coroutine,
        items, numItem, numShow, x1, y1, x2, y2, isBox, isEsc,
        size, color, selectColor)
    if ok2 and type(r) == "number" then return r end
    return 0
end

-- ---------------------------------------------------------------------------
-- 输入
-- ---------------------------------------------------------------------------

--- 等一个按键（协程版，阻塞直到有键）
--
-- 转发到 framework/input_async 的 WaitKey。
-- @return number VK 码
function FlowFacade.waitKey()
    local ok, InputAsync = pcall(require, "framework.input_async")
    if not ok or not InputAsync or not InputAsync.WaitKey then return -1 end
    local ok2, r = pcall(InputAsync.WaitKey)
    if ok2 and type(r) == "number" then return r end
    return -1
end

-- ---------------------------------------------------------------------------
-- 对话
-- ---------------------------------------------------------------------------

--- 对话（协程版）
--
-- 转发到 framework/talk_async 的 TalkEx。
-- @param text string|number 文本或文本编号
-- @param headId number 头像代号
-- @param flag number 标志
function FlowFacade.talkEx(text, headId, flag)
    local ok, TalkAsync = pcall(require, "framework.talk_async")
    if not ok or not TalkAsync then return end
    -- talk_async 只导出 TalkExCoroutine（没有 TalkEx）
    if not TalkAsync.TalkExCoroutine then return end
    pcall(TalkAsync.TalkExCoroutine, text, headId, flag)
end

-- ---------------------------------------------------------------------------
-- 消息框（语义级）
-- ---------------------------------------------------------------------------

--- 显示消息并等按键（协程版）
-- @return number
function FlowFacade.drawStrBoxWaitKey(str, color, size)
    local ok, AMB = pcall(require, "framework.async_message_box")
    if not ok or not AMB or not AMB.ShowMessageCoroutine then return 0 end
    local ok2, r = pcall(AMB.ShowMessageCoroutine, -1, -1, str, color, size)
    if ok2 and type(r) == "number" then return r end
    return 0
end

--- 显示是/否框（协程版）
-- @return number 1 = 是，0 = 否
function FlowFacade.drawStrBoxYesNo(x, y, str, color, size)
    local ok, AMB = pcall(require, "framework.async_message_box")
    if not ok or not AMB or not AMB.ShowYesNoCoroutine then return 0 end
    local ok2, r = pcall(AMB.ShowYesNoCoroutine, x, y, str, color, size)
    if ok2 and type(r) == "number" then return r end
    return 0
end

return FlowFacade
