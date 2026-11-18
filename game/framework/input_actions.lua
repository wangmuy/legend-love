-- input_actions.lua
-- 输入动作常量（framework 通用层）
--
-- 分层（见 openspec/changes/input-action-layer/design.md ADR-1）：
--
--   第一层 framework 通用  "ui.*"      ← 本文件定义，框架拥有并负责映射
--   第二层 游戏私有        "<game>.*"  ← 游戏在 script/input_actions.lua 注册
--
-- **本文件不得出现任何游戏词汇**（如金庸的 Y/N）。原因：framework 要能复用到
-- 仙剑、白金英雄坛说等任意游戏，通用层一旦有金庸词汇就不可复用了。
--
-- 为什么确认动作用的动词是 accept 而非 confirm（ADR-2）：
--   金庸里 Y 表达的是「语义上的『是』」（对「要不要当帮主」答是），
--   而 SPACE/RETURN 表达的是「推进 / 确认当前选中」。框架层若叫 confirm，
--   两者会被混淆；accept 保持中立，且对齐 Godot 内建的 ui_accept / ui_cancel。
--   所以 Y/N 不属于本文件，而是游戏层动作 jy.y / jy.n。

local InputActions = {}

-- ---------------------------------------------------------------------------
-- 10 个通用动作
-- ---------------------------------------------------------------------------
-- 前 9 个是离散动作（进事件队列），ui.cursor 是内置向量（每帧状态读）。

InputActions.UP        = "ui.up"
InputActions.DOWN      = "ui.down"
InputActions.LEFT      = "ui.left"
InputActions.RIGHT     = "ui.right"
InputActions.ACCEPT    = "ui.accept"
InputActions.CANCEL    = "ui.cancel"
InputActions.MENU      = "ui.menu"
InputActions.TEXT      = "ui.text"
InputActions.BACKSPACE = "ui.backspace"
InputActions.CURSOR    = "ui.cursor"      -- 向量，不是事件

--- 全部通用动作（含向量名），按声明顺序
InputActions.ALL = {
    InputActions.UP, InputActions.DOWN, InputActions.LEFT, InputActions.RIGHT,
    InputActions.ACCEPT, InputActions.CANCEL, InputActions.MENU,
    InputActions.TEXT, InputActions.BACKSPACE,
    InputActions.CURSOR,
}

--- 进事件队列的离散动作（不含 ui.cursor）
InputActions.DISCRETE = {
    InputActions.UP, InputActions.DOWN, InputActions.LEFT, InputActions.RIGHT,
    InputActions.ACCEPT, InputActions.CANCEL, InputActions.MENU,
    InputActions.TEXT, InputActions.BACKSPACE,
}

-- ---------------------------------------------------------------------------
-- 合法的 source（设备来源，ADR-3 / ADR-7）
-- ---------------------------------------------------------------------------
InputActions.SOURCES = {
    key = true, mouse = true, pad = true, touch = true, vr = true,
    -- compat：迁移期由 enqueueKeyEvent 的兼容 wrapper 产生，不应出现在新代码里
    compat = true,
}

--- 事件结构约定（仅文档，不做校验）
--
-- {
--   action   = "ui.accept",          -- 语义动作名（本文件或游戏层注册的）
--   source   = "key"|"mouse"|"pad"|"touch"|"vr"|"compat",
--   value    = 0..1 | nil,           -- 模拟量（摇杆派生事件带力度）
--   char     = "a" | nil,            -- 仅 action == ui.text
--   position = {x=, y=} | nil,       -- 指针类（鼠标/触摸/VR 射线命中点）
--   index    = 1|2|nil,              -- 手柄编号 / 触摸 ID / 左右手
--   ray      = {origin=, dir=} | nil,-- 仅 source == "vr"（留槽，不实现）
--   time     = number,
-- }
InputActions.EVENT_KEYS = {
    "action", "source", "value", "char", "position", "index", "ray", "time",
}

-- ---------------------------------------------------------------------------
-- 宽松名称匹配
-- ---------------------------------------------------------------------------

-- 别名表：把历史写法与常见变体归一到动作名。
-- 只收录「语义等价」的写法，不做模糊匹配 —— 模糊匹配会掩盖拼写错误。
local ALIASES = {
    ["up"] = InputActions.UP, ["down"] = InputActions.DOWN,
    ["left"] = InputActions.LEFT, ["right"] = InputActions.RIGHT,
    ["accept"] = InputActions.ACCEPT, ["confirm"] = InputActions.ACCEPT,
    ["ok"] = InputActions.ACCEPT, ["space"] = InputActions.ACCEPT,
    ["return"] = InputActions.ACCEPT, ["enter"] = InputActions.ACCEPT,
    ["cancel"] = InputActions.CANCEL, ["esc"] = InputActions.CANCEL,
    ["escape"] = InputActions.CANCEL, ["back"] = InputActions.CANCEL,
    ["menu"] = InputActions.MENU, ["pause"] = InputActions.MENU,
    ["text"] = InputActions.TEXT, ["char"] = InputActions.TEXT,
    ["backspace"] = InputActions.BACKSPACE, ["delete"] = InputActions.BACKSPACE,
    ["cursor"] = InputActions.CURSOR,
}

--- 把任意写法归一成标准动作名
--
-- 接受：
--   "ui.accept" / "sp.ACE"（已带前缀的返回小写化结果）
--   "accept" / "SPACE" / "escape"（别名表命中）
--
-- 游戏私有动作（带非 ui 前缀，如 "jy.y"）原样返回小写化结果。
--
-- @param name string
-- @return string|nil 归一后的动作名；nil 表示非法输入
function InputActions.normalizeName(name)
    if type(name) ~= "string" then return nil end
    local trimmed = name:match("^%s*(.-)%s*$")
    if trimmed == "" then return nil end
    local lower = trimmed:lower()

    if ALIASES[lower] then
        return ALIASES[lower]
    end

    -- 已带命名空间前缀的（含 "ui." 与游戏层 "<game>."）：原样返回
    if lower:match("^%a[%w_]*%.[%w_]+$") then
        return lower
    end

    return nil
end

--- 是否 framework 通用层动作（"ui." 前缀）
function InputActions.isFrameworkAction(name)
    if type(name) ~= "string" then return false end
    return name:sub(1, 3) == "ui."
end

--- 是否合法的 source
function InputActions.isValidSource(source)
    return type(source) == "string" and InputActions.SOURCES[source] == true
end

return InputActions
