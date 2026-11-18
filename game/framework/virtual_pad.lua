-- virtual_pad.lua
-- 虚拟手柄（屏幕上的 D-pad + 按钮），逻辑层
--
-- 分层（见 openspec/changes/input-action-layer/design.md ADR-9）：
--
--   本文件     触摸点 → 按钮命中 → 产出动作事件（**纯逻辑**）
--      ▼
--   EngineAPI.render   绘制（引擎特性）
--   EngineAPI.input.getCapabilities()  能力声明
--
-- **本文件不得直接调用 love.\***：绘制必须经 EngineAPI。
-- 理由：「哪块区域算 UP」是布局与玩法逻辑，不是引擎特性；
--       「怎么画半透明圆」才是引擎特性。参考库 MobileControlsLibrary
--       把两者混在 85 行里且坐标硬编码，所以不可复用。
--
-- 布局用**锚点 + 边距**而不是屏幕比例（ADR-9）：
--   比例布局在超宽屏上会把按钮拉到手指够不到的地方；
--   引擎原生 UI（Godot 的 TouchScreenButton）会把框架绑死到具体引擎。
--   锚点 + 边距只用 4 个数字，框架无需知道屏幕尺寸就能校验合法性。

local InputActions = require("framework.input_actions")

local VirtualPad = {}

-- ---------------------------------------------------------------------------
-- 布局（可被游戏覆盖）
-- ---------------------------------------------------------------------------
-- anchor: "bottom-left" | "bottom-right" | "top-left" | "top-right"
-- ox/oy:  相对锚点的偏移（像素，负值向内）
-- r:      半径（像素）
--
-- 默认值照桌面/平板横屏：左手 D-pad、右手 A/B。

VirtualPad.DEFAULT_BUTTONS = {
    -- D-pad 四向（用菱形排布，不是四个独立圆）
    { id = "up",    action = InputActions.UP,    anchor = "bottom-left",
      ox = 150, oy = -260, r = 56, label = "▲" },
    { id = "down",  action = InputActions.DOWN,  anchor = "bottom-left",
      ox = 150, oy = -90,  r = 56, label = "▼" },
    { id = "left",  action = InputActions.LEFT,  anchor = "bottom-left",
      ox = 65,  oy = -175, r = 56, label = "◀" },
    { id = "right", action = InputActions.RIGHT, anchor = "bottom-left",
      ox = 235, oy = -175, r = 56, label = "▶" },
    -- 右手两个动作键
    { id = "accept", action = InputActions.ACCEPT, anchor = "bottom-right",
      ox = -110, oy = -230, r = 64, label = "A" },
    { id = "cancel", action = InputActions.CANCEL, anchor = "bottom-right",
      ox = -230, oy = -130, r = 56, label = "B" },
    -- 系统菜单键
    { id = "menu", action = InputActions.MENU, anchor = "top-right",
      ox = -80, oy = 80, r = 44, label = "≡" },
}

--- 平台默认值（照 mouse_menu.lua 的 platformDefaults 模式）
--
-- Android/iOS 没有物理键盘，虚拟手柄是唯一可行输入 → 默认开；
-- 桌面有键鼠，玩家不想屏幕上多两个半透明圆 → 默认关。
-- **但两者都要能在设置菜单手动开关**（Android 接蓝牙鼠标/手柄的情况真实存在）。
VirtualPad.PLATFORM_DEFAULTS = {
    Android = true,
    iOS     = true,
    Windows = false,
    Linux   = false,
    macOS   = false,
}

VirtualPad.SETTINGS_KEY = "input.virtualPad"

-- ---------------------------------------------------------------------------
-- 内部状态
-- ---------------------------------------------------------------------------
local buttons = {}          -- 生效的按钮表（带按下状态）
local enabled = false
local initialized = false

--- 计算某按钮在屏幕上的圆心（锚点 + 边距 → 绝对坐标）
--
-- 这是布局的唯一"翻译"点：所有绘制与命中都走它，保证两者永远一致。
--
-- @param button table
-- @param screenW number
-- @param screenH number
-- @return number x, y
function VirtualPad.buttonCenter(button, screenW, screenH)
    local ox = button.ox or 0
    local oy = button.oy or 0
    local x, y
    local anchor = button.anchor or "bottom-left"
    if anchor == "bottom-left" then
        x, y = ox, screenH + oy
    elseif anchor == "bottom-right" then
        x, y = screenW + ox, screenH + oy
    elseif anchor == "top-left" then
        x, y = ox, oy
    elseif anchor == "top-right" then
        x, y = screenW + ox, oy
    else
        -- 未知锚点：退回左上，且不报错（布局错误不应该崩主循环）
        x, y = ox, oy
    end
    return math.floor(x), math.floor(y)
end

--- 把一个触摸点映射成命中的按钮
--
-- 返回 nil 表示没命中任何按钮（触摸落在空白处，应穿透给游戏逻辑）。
--
-- 为什么按**距离**判命中而不是矩形：圆形按钮用距离最直观，且与绘制一致
-- （绘制是 circle("fill", ..., r)）。用矩形框会在圆角处误判。
--
-- @param tx number 触摸 x
-- @param ty number 触摸 y
-- @param screenW number
-- @param screenH number
-- @return table|nil 命中的按钮
function VirtualPad.hitTest(tx, ty, screenW, screenH)
    for _, b in ipairs(buttons) do
        local cx, cy = VirtualPad.buttonCenter(b, screenW, screenH)
        local dx, dy = tx - cx, ty - cy
        local r = b.r or 0
        if (dx * dx + dy * dy) <= (r * r) then
            return b
        end
    end
    return nil
end

--- 设置布局（游戏可覆盖 DEFAULT_BUTTONS）
-- @param list table 按钮列表
function VirtualPad.setLayout(list)
    buttons = {}
    for _, spec in ipairs(list or {}) do
        buttons[#buttons + 1] = {
            id     = spec.id,
            action = spec.action,
            anchor = spec.anchor,
            ox     = spec.ox,
            oy     = spec.oy,
            r      = spec.r or 48,
            label  = spec.label or "",
            pressed = false,
            touchId = nil,
        }
    end
    return true
end

--- 取当前布局（只读副本，供绘制用）
function VirtualPad.getLayout()
    local out = {}
    for _, b in ipairs(buttons) do
        out[#out + 1] = {
            id = b.id, action = b.action, anchor = b.anchor,
            ox = b.ox, oy = b.oy, r = b.r, label = b.label,
            pressed = b.pressed,
        }
    end
    return out
end

--- 初始化（幂等）
--
-- @param opts table { layout = 按钮列表（可选） }
function VirtualPad.init(opts)
    if initialized then return true end
    opts = opts or {}
    VirtualPad.setLayout(opts.layout or VirtualPad.DEFAULT_BUTTONS)
    enabled = false
    initialized = true
    return true
end

--- 当前是否启用
function VirtualPad.isEnabled()
    return enabled == true
end

--- 开关
function VirtualPad.setEnabled(flag)
    enabled = flag == true
    if not enabled then
        -- 关闭时清掉所有按下状态，避免重新打开时"残留按住"
        for _, b in ipairs(buttons) do
            b.pressed = false
            b.touchId = nil
        end
    end
    return true
end

-- ---------------------------------------------------------------------------
-- 触摸处理 → 动作事件
-- ---------------------------------------------------------------------------

--- 喂入当前帧的触摸列表，产出动作事件
--
-- touches 形状：{ {id=, x=, y=}, ... }  —— 由引擎侧提供（见 engine_love2d）
--
-- **一个手指只归属一个按钮**：手指 A 按住 UP 后滑到 RIGHT，仍算 UP。
-- 否则拖动会串键（按下 UP 又触发 RIGHT，玩家看到角色乱走）。
--
-- 边沿语义：只有「从未按下 → 按下」才产事件；按住期间靠重复器
-- （InputBindings.tickRepeat）连发。这与键盘的 keyRepeat 行为对齐。
--
-- @param touches table
-- @param screenW number
-- @param screenH number
-- @param now number 当前时间（秒）
-- @param emit function(action, touchId) 产出事件的回调
-- @return number 本帧产出的事件数
function VirtualPad.update(touches, screenW, screenH, now, emit)
    if not enabled then return 0 end
    if type(touches) ~= "table" then return 0 end
    if type(emit) ~= "function" then return 0 end

    local fired = 0

    -- 1) 先处理"已在按住"的手指：只更新位置，不换按钮
    local activeById = {}
    for _, b in ipairs(buttons) do
        if b.pressed and b.touchId ~= nil then
            activeById[b.touchId] = b
        end
    end

    -- 2) 逐个触摸点判定
    for _, t in ipairs(touches) do
        if t and t.id ~= nil then
            local owner = activeById[t.id]
            if owner then
                -- 手指已归属某按钮：不重新命中（防串键）
                if owner.touchId ~= t.id then
                    owner.touchId = t.id
                end
            else
                local hit = VirtualPad.hitTest(t.x, t.y, screenW, screenH)
                if hit and not hit.pressed then
                    hit.pressed = true
                    hit.touchId = t.id
                    emit(hit.action, t.id)
                    fired = fired + 1
                elseif hit and hit.pressed and hit.touchId == nil then
                    hit.touchId = t.id
                end
            end
        end
    end

    -- 3) 处理松开：本帧没有对应触摸 ID 的按钮视为已松手
    local presentIds = {}
    for _, t in ipairs(touches) do
        if t and t.id ~= nil then presentIds[t.id] = true end
    end
    for _, b in ipairs(buttons) do
        if b.pressed and b.touchId ~= nil and not presentIds[b.touchId] then
            b.pressed = false
            b.touchId = nil
        end
    end

    return fired
end

--- 清空按下状态（场景切换等）
function VirtualPad.reset()
    for _, b in ipairs(buttons) do
        b.pressed = false
        b.touchId = nil
    end
end

-- ---------------------------------------------------------------------------
-- 绘制（经 EngineAPI.render，不直接调 love.*）
-- ---------------------------------------------------------------------------

--- 每帧绘制
--
-- @param screenW number
-- @param screenH number
-- @return boolean 是否画了东西
function VirtualPad.draw(screenW, screenH)
    if not enabled then return false end
    local EngineAPI = rawget(_G, "EngineAPI")
    if not (EngineAPI and EngineAPI.render and EngineAPI.render.fillRect) then
        return false
    end

    local baseAlpha = 0.35
    local pressAlpha = 0.6

    for _, b in ipairs(buttons) do
        local cx, cy = VirtualPad.buttonCenter(b, screenW, screenH)
        local r = b.r or 48
        local alpha = b.pressed and pressAlpha or baseAlpha
        -- 用矩形近似圆形按钮：EngineAPI.render 目前只有 fillRect，
        -- 没有 drawCircle。若将来加了 drawCircle，这里换掉即可，契约不变。
        -- fillRect 的签名是 (x1, y1, x2, y2, color{table})，且是角点而非宽高。
        local color = { r = 0.2, g = 0.2, b = 0.2, a = alpha }
        local ok = pcall(EngineAPI.render.fillRect,
            cx - r, cy - r, cx + r, cy + r, color)
        if not ok then
            -- 绘制失败绝不影响输入处理：静默降级
            return false
        end
    end
    return true
end

return VirtualPad
