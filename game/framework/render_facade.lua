-- render_facade.lua
-- 绘制外观层：framework 不再调用 game/script 定义的全局绘制函数
--
-- 分层（change: port-script-decoupling）：
--
--   game/framework/*.lua
--        │  调本文件
--        ▼
--   framework/render_facade.lua     ← 只转发，不含逻辑
--        │
--        ▼
--   EngineAPI.render.*              ← 引擎契约
--
-- **为什么需要这一层**（实测依据）：
--   framework 里有 87 处调用 `DrawString` / `Cls` / `ShowScreen` / `DrawBox` /
--   `DrawStrBox` 等**定义在 game/script/jymain.lua:2094-2994 的全局函数**。
--   依赖方向是 framework → script → EngineAPI，与设计意图相反。
--   后果：接新引擎时不仅要实现 EngineAPI，还要把 jymain.lua 那 2000 行搬过去。
--
-- **本文件不得**：
--   读写 JY / WAR / CC 的游戏状态（那是调用方的事）
--   包含任何业务逻辑（纯转发）
--   调 script 层的全局函数（否则等于没解耦）

local RenderFacade = {}

-- 取 EngineAPI（严格 _G 下必须用 rawget）
local function api()
    return rawget(_G, "EngineAPI")
end

-- ---------------------------------------------------------------------------
-- 基础原语（纯转发到 EngineAPI.render）
-- ---------------------------------------------------------------------------

--- 绘制文字（带阴影的 DrawString 语义）
--
-- 原版 jymain.lua:2122 的 DrawString 只是 `lib.DrawStr(x,y,str,color,size,CC.FontName)`。
-- CC.FontName 是游戏常量，所以这里由调用方传 fontname（或省略用引擎默认）。
--
-- @param x, y number
-- @param str string
-- @param color number|table 打包 int 或 {r,g,b}
-- @param size number|nil
-- @param fontName string|nil
function RenderFacade.text(x, y, str, color, size, fontName)
    local EA = api()
    if not (EA and EA.render and EA.render.text) then return end
    pcall(EA.render.text, x, y, str, color, size, fontName)
end

--- 清屏 / 设置裁剪区
--
-- 原版 Cls(x1,y1,x2,y2) 的语义是「设置裁剪区并在区域内清屏」
-- （jymain.lua:2994 的实现：先 SetClip 再按状态 FillColor）。
-- 本函数只做**设置裁剪区**这一半 —— 清屏由 clearScreen 负责。
--
-- @param x1, y1, x2, y2 number|nil 全 0 = 清除整个裁剪区
function RenderFacade.setClip(x1, y1, x2, y2)
    local EA = api()
    if not (EA and EA.render and EA.render.setClip) then return end
    pcall(EA.render.setClip, x1 or 0, y1 or 0, x2 or 0, y2 or 0)
end

--- 清屏（替代 script 层的 `Cls`）
--
-- **注意：script 的 `Cls` 不只是清屏** —— 它按 `JY.Status` 决定重绘什么
-- （主地图 / 场景 / 战斗地图 / 开场图）。那是游戏逻辑，读 JY.Status。
--
-- 所以本函数做三步：
--   1. 设置裁剪区
--   2. 调 GameHooks.clearBackground()（由游戏层注入的"按状态重绘"）
--   3. 重置裁剪区
--
-- 未注册 clearBackground 时退化为「填充黑屏」—— 保证单元测试环境不崩。
--
-- @param x1, y1, x2, y2 number|nil 全 nil 或全 0 = 整屏
function RenderFacade.clearScreen(x1, y1, x2, y2)
    x1, y1, x2, y2 = x1 or 0, y1 or 0, x2 or 0, y2 or 0

    RenderFacade.setClip(x1, y1, x2, y2)

    local okHooks, GameHooks = pcall(require, "framework.game_hooks")
    local didRedraw = false
    if okHooks and GameHooks and GameHooks.clearBackground then
        didRedraw = GameHooks.clearBackground()
    end
    if not didRedraw then
        -- 未注入：退化为黑屏（单元测试环境）
        local w, h = RenderFacade.size()
        if w > 0 and h > 0 then
            RenderFacade.fillRect(0, 0, w, h, 0)
        end
    end

    RenderFacade.setClip(0, 0, 0, 0)
    RenderFacade.present()
end

--- 填充矩形（替代 Cls 的「清屏」那一半 + lib.FillColor）
-- @param x1, y1, x2, y2 number
-- @param color number|table
function RenderFacade.fillRect(x1, y1, x2, y2, color)
    local EA = api()
    if not (EA and EA.render and EA.render.fillRect) then return end
    pcall(EA.render.fillRect, x1, y1, x2, y2, color)
end

--- 矩形边框（替代 lib.DrawRect / DrawBox 的边框部分）
function RenderFacade.rectOutline(x1, y1, x2, y2, color)
    local EA = api()
    if not (EA and EA.render and EA.render.rectOutline) then return end
    pcall(EA.render.rectOutline, x1, y1, x2, y2, color)
end

--- 带阴影的背景框（替代 DrawBox / lib.Background）
function RenderFacade.drawBackground(x1, y1, x2, y2, brightness)
    local EA = api()
    if not (EA and EA.render and EA.render.drawBackground) then return end
    pcall(EA.render.drawBackground, x1, y1, x2, y2, brightness)
end

--- 提交渲染帧（替代 ShowScreen 的「立即提交」那一半）
function RenderFacade.present()
    local EA = api()
    if not (EA and EA.render and EA.render.present) then return end
    pcall(EA.render.present)
end

--- 提交渲染帧并等待（替代 ShowScreen 的「带延迟」那一半 + lib.ShowSlow）
function RenderFacade.presentAndWait(delayMs)
    local EA = api()
    if not (EA and EA.render and EA.render.presentAndWait) then return end
    pcall(EA.render.presentAndWait, delayMs)
end

--- 取渲染尺寸（替代 CC.ScreenW/ScreenH 的读取）
-- @return number w, h
function RenderFacade.size()
    local EA = api()
    local w, h = 0, 0
    if EA and EA.render and EA.render.getWidth then
        local ok, v = pcall(EA.render.getWidth)
        if ok and type(v) == "number" then w = v end
    end
    if EA and EA.render and EA.render.getHeight then
        local ok, v = pcall(EA.render.getHeight)
        if ok and type(v) == "number" then h = v end
    end
    return w, h
end

return RenderFacade
