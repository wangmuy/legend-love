-- input_bindings.lua
-- 输入绑定表 + 向量机制（framework 侧，引擎无关）
--
-- 分层（见 openspec/changes/input-action-layer/design.md）：
--
--   引擎实现  →  只吐【物理事件】+ 回答 getAxis/getCapabilities
--        ▼
--   本文件    →  物理事件 → 语义动作（映射）  +  轴 → 向量（组合）
--        ▼
--   input_manager.actionQueue  →  消费方
--
-- 为什么映射住 framework 而不是引擎（ADR-2）：
--   ① 映射是产品行为（「上 = W 键」），不该散落在 20 个引擎实现里
--   ② 引擎侧做不了跨设备语义降级（「鼠标左键 = ui.accept」是框架知识）
--   ③ Godot 的 InputMap / Unreal 的 MappingContext 格式互不兼容，
--      framework 若依赖它们反而失去可移植性
--
-- 为什么向量由游戏自声明（ADR-4）：
--   move/aim 是 Hades 类双摇杆玩法的惯例，不是输入语义。三大外部引擎
--   （SDL/Godot/Unreal）都不提供 getMoveVector/getAimVector，它们都让开发者
--   从自己命名的动作组合出向量。框架只内置跨游戏通用的 ui.cursor。

local InputActions = require("framework.input_actions")

local InputBindings = {}

-- ---------------------------------------------------------------------------
-- 默认绑定表：物理输入 → 语义动作
-- ---------------------------------------------------------------------------
-- 结构：{ key = {...}, mouse = {...}, pad = {...} }
-- 每条映射的值是动作名（字符串）。
local defaultBindings = {
    key = {
        -- 确认/推进（金庸里 SPACE 与 RETURN 等价）
        space    = InputActions.ACCEPT,
        [" "]    = InputActions.ACCEPT,
        ["return"] = InputActions.ACCEPT,
        -- 取消/返回
        escape   = InputActions.CANCEL,
        -- 导航
        up       = InputActions.UP,
        down     = InputActions.DOWN,
        left     = InputActions.LEFT,
        right    = InputActions.RIGHT,
        -- 系统菜单
        menu     = InputActions.MENU,
        -- 文本编辑
        backspace = InputActions.BACKSPACE,
    },
    mouse = {
        -- 左键推进、右键取消（REQ-MS2-6 / REQ-MS2-8 的既有语义）
        [1] = InputActions.ACCEPT,
        [2] = InputActions.CANCEL,
    },
    pad = {
        a      = InputActions.ACCEPT,
        b      = InputActions.CANCEL,
        start  = InputActions.MENU,
        back   = InputActions.MENU,
        dpup   = InputActions.UP,
        dpdown = InputActions.DOWN,
        dpleft = InputActions.LEFT,
        dpright = InputActions.RIGHT,
    },
}

-- 可在运行时被 bindAction / unbind 修改，所以对外暴露的是**副本查看**，
-- 避免调用方直接改写内部表。
local function deepCopy(t)
    local out = {}
    for k, v in pairs(t) do
        if type(v) == "table" then out[k] = deepCopy(v) else out[k] = v end
    end
    return out
end

-- 生效中的绑定（init 时从 default 拷贝一份）
local activeBindings = deepCopy(defaultBindings)

--- 取默认绑定表（只读副本）
function InputBindings.getDefaultBindings()
    return deepCopy(defaultBindings)
end

--- 取当前生效的绑定表（只读副本）
function InputBindings.getBindings()
    return deepCopy(activeBindings)
end

--- 恢复成默认绑定
function InputBindings.resetBindings()
    activeBindings = deepCopy(defaultBindings)
end

--- 绑定一个物理输入到动作
--
-- @param source string "key" | "mouse" | "pad"
-- @param name   string|number 物理名（键名/按钮号/手柄按钮名）
-- @param action string 动作名（ui.* 或游戏私有 <game>.*）
-- @return boolean
function InputBindings.bindAction(source, name, action)
    if type(source) ~= "string" or name == nil then return false end
    if type(action) ~= "string" or action == "" then return false end
    if not activeBindings[source] then activeBindings[source] = {} end
    activeBindings[source][name] = action
    return true
end

--- 解除一条绑定
function InputBindings.unbind(source, name)
    if type(source) ~= "string" or not activeBindings[source] then return false end
    activeBindings[source][name] = nil
    return true
end

--- 查一个物理输入对应的动作
-- @return string|nil
function InputBindings.resolve(source, name)
    if type(source) ~= "string" or name == nil then return nil end
    local m = activeBindings[source]
    if not m then return nil end
    return m[name]
end

--- 反查用的「键名 → SDL keycode」表
--
-- **为什么不直接用 `input_manager` 的 `baseKeyMap`**：它是那个模块的
-- local 变量，不可跨模块访问。这里复制一份是**有意的重复** ——
-- 两份必须同步，所以下方门禁会断言两边键集合一致（防漂移）。
local _reverseKeyMap = {
    ["escape"] = 27,
    [" "] = 32,
    ["space"] = 32,
    ["return"] = 13,
    ["backspace"] = 8,
    ["up"] = 1073741906,
    ["down"] = 1073741905,
    ["left"] = 1073741904,
    ["right"] = 1073741903,
}

local function baseKeyMapForReverse()
    return _reverseKeyMap
end

--- 把 **SDL keycode** 反查成动作名（按键重复用）
--
-- 为什么需要它：`InputManager:update` 的按键重复逻辑手上只有 `gameKey`
-- （SDL keycode 整数，来自 `baseKeyMap`），但要往**动作队列**发 repeat。
-- 没有反向映射就只能发键队列的 repeat → 迁移到动作队列的消费方
-- （菜单长按连翻、状态页长按翻页）会静默失效。
--
-- 与 `resolveKey` 的关系：`resolveKey` 是「LÖVE 键名字符串 → 动作」，
-- 本函数是「SDL keycode 整数 → 动作」。两者查的是**同一张绑定表**，
-- 只是查表键不同：
--
-- ```lua
--   baseKeyMap["up"] = 1073741906      -- LÖVE 键名 → SDL keycode
--   activeBindings.key["up"] = "ui.up" -- LÖVE 键名 → 动作
--   ─────────────────────────────────────────────────────
--   actionForKeyCode(1073741906) = "ui.up"   ← 本函数（两步合一）
-- ```
--
-- **不缓存**：绑定表可以通过 `bind()` 在运行时改（设置界面/测试），
-- 缓存会让改动不生效。这个函数只在「按键重复」路径调用（有 keyRepeatTimers
-- 时每帧每键一次，实测最多同时 1~2 个键），开销可忽略。
--
-- @param keyCode number SDL keycode
-- @return string|nil 动作名
function InputBindings.actionForKeyCode(keyCode)
    if type(keyCode) ~= "number" then return nil end

    -- 反查：keyCode → LÖVE 键名（可能多个键名映到同一码，如 " " 与 "space"）
    local keyName = nil
    for name, code in pairs(baseKeyMapForReverse()) do
        if code == keyCode then keyName = name; break end
    end
    if not keyName then return nil end

    return InputBindings.resolve("key", keyName)
end

--- 把「键名」解析成动作（含文本输入降级）
--
-- 除了查表，还处理两类**规则型**映射（不适合写进静态表）：
--   ① 单字符可打印键 → ui.text（携 char）
--   ② 其余未绑定键 → nil（不产生动作）
--
-- 这是修复「输入框打不出字」的关键：baseKeyMap 白名单只认 9 个键，
-- 本函数让任意可打印字符都能产出 ui.text（design.md REQ-IAL-3b）。
--
-- @param keyName string LÖVE 键名（"a" / "space" / "backspace" ...）
-- @return action|nil, char|nil
function InputBindings.resolveKey(keyName)
    local action = InputBindings.resolve("key", keyName)
    if action then return action, nil end

    -- 单字符且可打印（ASCII 32..126）→ ui.text
    if type(keyName) == "string" and #keyName == 1 then
        local b = keyName:byte(1)
        if b and b >= 32 and b <= 126 then
            return InputActions.TEXT, keyName
        end
    end
    return nil, nil
end

-- ---------------------------------------------------------------------------
-- 向量机制（每帧状态读，不进事件队列 —— ADR-5）
-- ---------------------------------------------------------------------------

-- 向量声明：id -> { x = {轴名...}, y = {轴名...} }
--
-- 为什么轴用**列表**而不是单个名字：将来可以「左摇杆 + 方向键」叠加成
-- 同一个向量（取绝对值大的那个）。当前实现只取第一个轴。
local vectorSpecs = {}

--- 声明一个向量
--
-- 用法：
--   defineVector("ui.cursor", { x = {"leftx"}, y = {"lefty"} })
--   defineVector("steer", { x = {"leftx"} })          -- 单轴，y 省略
--
-- @param id string 向量 id（ui.* 或游戏私有）
-- @param spec table { x = {轴名}, y = {轴名}（可选） }
-- @return boolean
function InputBindings.defineVector(id, spec)
    if type(id) ~= "string" or id == "" then return false end
    if type(spec) ~= "table" then return false end
    local function normalizeAxes(v)
        if type(v) == "string" then return { v } end
        if type(v) == "table" then return v end
        return nil
    end
    local x = normalizeAxes(spec.x)
    local y = normalizeAxes(spec.y)
    if not x and not y then return false end
    vectorSpecs[id] = { x = x, y = y }
    return true
end

--- 撤销声明
function InputBindings.undefineVector(id)
    vectorSpecs[id] = nil
end

--- 列出已声明的向量 id
function InputBindings.listVectors()
    local out = {}
    for id in pairs(vectorSpecs) do out[#out + 1] = id end
    table.sort(out)
    return out
end

--- 读一个轴（经 EngineAPI.input.getAxis；缺失时返回 0）
local function readAxis(name)
    local EngineAPI = rawget(_G, "EngineAPI")
    if not (EngineAPI and EngineAPI.input and EngineAPI.input.getAxis) then return 0 end
    local ok, v = pcall(EngineAPI.input.getAxis, name)
    if not ok or type(v) ~= "number" then return 0 end
    return v
end

-- 取一组轴里绝对值最大的那个（当前实现只认第一个轴，接口留着叠加）
local function readAxes(axes)
    if not axes or #axes == 0 then return 0 end
    local best = 0
    for _, name in ipairs(axes) do
        local v = readAxis(name)
        if math.abs(v) > math.abs(best) then best = v end
    end
    return best
end

--- 读一个向量
--
-- 返回 { x, y, magnitude, angle }，未声明时返回 nil。
--
-- 为什么同时给 magnitude 与 angle（design.md ADR-4）：
--   Hades 式方向性移动需要 angle；飞行/分量控制需要 x,y；
--   赛车单轴转向需要带符号的 magnitude；菜单光标需要 angle + magnitude。
--   三个量足以覆盖，且不预设任何玩法。
--
-- @param id string
-- @return table|nil
function InputBindings.getVector(id)
    local spec = vectorSpecs[id]
    if not spec then return nil end
    local x = 0
    local y = 0
    if spec.x then x = readAxes(spec.x) end
    if spec.y then y = readAxes(spec.y) end
    local magnitude = math.sqrt(x * x + y * y)
    local angle = 0
    if magnitude > 0 then
        -- Lua 5.1/5.2 有 math.atan2；Lua 5.3+ 移除了它，改用 math.atan(y, x)。
        -- 实测 5.5 报 "attempt to call a nil value (field 'atan2')"，
        -- 所以必须做版本兼容，否则 5.3/5.4/5.5 三版全挂。
        if math.atan2 then
            angle = math.atan2(y, x)
        else
            angle = math.atan(y, x)
        end
    end
    return { x = x, y = y, magnitude = magnitude, angle = angle }
end

-- 内置唯一向量：ui.cursor（菜单光标，跨游戏通用）
InputBindings.defineVector(InputActions.CURSOR, { x = { "leftx" }, y = { "lefty" } })

-- ---------------------------------------------------------------------------
-- 摇杆派生离散事件：迟滞 + 独立重复器（ADR-6）
-- ---------------------------------------------------------------------------

InputBindings.PRESS_THRESHOLD   = 0.35   -- 推过这个值算「按下」
InputBindings.RELEASE_THRESHOLD = 0.25   -- 回到这个值以下才算「松开」
InputBindings.REPEAT_DELAY       = 0.3   -- 模拟量派生事件的首次重复延迟（秒）
InputBindings.REPEAT_INTERVAL    = 0.04  -- 重复间隔（秒）

--- 迟滞判定：该轴这一帧是否应该产生「按下」边沿
--
-- 用法（调用方自己保存 prevState）：
--   local pressed, fire = InputBindings.axisToDiscrete(value, prevState)
--   if fire then enqueueAction(...) end
--
-- 为什么需要迟滞（design.md ADR-6）：单阈值在 0.29 附近抖动会反复产生/撤销
-- 事件，菜单里表现为选中项疯狂跳。
--
-- @param value number 轴当前值（-1..1 或 0..1）
-- @param wasPressed boolean 上一帧是否处于「按下」态
-- @return boolean isPressed 本帧状态（供下一帧回传）
-- @return boolean fire 本帧是否产生边沿
function InputBindings.axisToDiscrete(value, wasPressed)
    local mag = math.abs(tonumber(value) or 0)
    if wasPressed then
        -- 已在按下态：只有回到释放阈值以下才脱离
        if mag <= InputBindings.RELEASE_THRESHOLD then
            return false, false
        end
        return true, false
    end
    -- 未按下：推过按下阈值才产生边沿
    if mag >= InputBindings.PRESS_THRESHOLD then
        return true, true
    end
    return false, false
end

-- 模拟量派生的重复计时器：key -> { pressedTime, lastRepeat, count }
local repeatTimers = {}

--- 推进模拟量派生的重复（每帧调一次）
--
-- **独立于 keyRepeatEnabled**（ADR-6）：键盘按住只走一格是既有手感，
-- 打开全局重复会改变它，是回归风险。摇杆在菜单里本来就该像 D-pad 一样连发。
--
-- @param key string 区分不同轴的键（如 "leftx"）
-- @param isPressed boolean 当前是否处于按下态
-- @param now number 当前时间（秒）
-- @return number 本帧应额外派生的重复次数（0 或 1）
function InputBindings.tickRepeat(key, isPressed, now)
    if not isPressed then
        repeatTimers[key] = nil
        return 0
    end
    local t = repeatTimers[key]
    if not t then
        repeatTimers[key] = { pressedTime = now, lastRepeat = now, count = 0 }
        return 0
    end
    local should = false
    if t.count == 0 then
        should = (now - t.pressedTime) >= InputBindings.REPEAT_DELAY
    else
        should = (now - t.lastRepeat) >= InputBindings.REPEAT_INTERVAL
    end
    if should then
        t.count = t.count + 1
        t.lastRepeat = now
        return 1
    end
    return 0
end

--- 清空重复计时器（场景切换等）
function InputBindings.clearRepeatState()
    repeatTimers = {}
end

return InputBindings
