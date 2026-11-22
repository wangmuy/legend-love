-- clock.lua
-- 墙上时钟（wall clock）访问点：framework 里**唯一**读「本地日期时间」的地方
--
-- 为什么需要这个模块（change: framework-io-portability）
--
--   framework 里有两处需要「本地日期时间字符串」：
--     ① framework/game_states.lua  GAME_DEAD 的死亡时间戳（存档展示用）
--     ② framework/lib_log.lua      日志行首时间戳
--   它们原来直接调 os.date(...)。os.date 是 Lua 标准库，换到 Godot/Unreal
--   之后不存在（GDScript 只能用 Time.get_datetime_dict_from_system()，
--   Unreal 只能用 FDateTime::Now()）—— 这就是「引擎能力」，必须走契约。
--
-- 方案选择：**新增契约 `EngineAPI.time.formatNow`**（任务书方案 a），
-- 而不是「用 getTimeSeconds 自己算 Y-M-D」（方案 b）。理由：
--
--   `EngineAPI.time.getTimeSeconds` 返回的是**单调计时**（LÖVE 是
--   love.timer.getTime()，MUD/Web/Test 是 os.clock()），不是 Unix 纪元秒。
--   用它自己算 Y-M-D 会得到「1970-01-01 00:00:0x」这种错到离谱的日期，
--   而且每次启动都一样 —— 存档时间戳会变成明显的假数据。
--   方案 b 在语义上不成立，所以「本地时间格式化」只能由引擎提供。
--
--   契约面只加了 1 个函数（formatNow），且 4 引擎全部显式实现、
--   有单测覆盖（test_engine_io_portability / test_engine_api）。
--
--   本模块的价值：把「契约优先 + os.date 兜底」这层收敛在一处，
--   避免两个调用点各写一遍降级逻辑；也让 framework 只有**一个**文件
--   需要知道 stdlib 兜底的存在。
--
-- 降级语义（硬要求：不得破坏现有行为）
--
--   EngineAPI.time.formatNow 存在 → 用它（换引擎后 framework 零 stdlib）
--   不存在 / 抛错 / 返回非字符串 → os.date（纯 Lua 测试环境仍能工作）
--   两者都失败 → 返回 ""（日志/存档时间戳缺失远好于崩溃）

local Clock = {}

--- 取 EngineAPI.time（严格 _G 下未声明的全局会抛错，必须 rawget）
-- @return table|nil
local function engineTime()
    local api = rawget(_G, "EngineAPI")
    if type(api) ~= "table" then return nil end
    local t = api.time
    if type(t) ~= "table" then return nil end
    return t
end

--- 当前本地时间字符串
--
-- @param fmt string|nil os.date 风格格式串，默认 "%Y-%m-%d %H:%M"
-- @return string 格式化结果；全部手段都失败时返回 ""（不抛错）
function Clock.formatNow(fmt)
    fmt = fmt or "%Y-%m-%d %H:%M"

    -- ① 引擎契约（换引擎后唯一路径）
    local t = engineTime()
    if t and type(t.formatNow) == "function" then
        local ok, s = pcall(t.formatNow, fmt)
        if ok and type(s) == "string" and s ~= "" then
            return s
        end
    end

    -- ② stdlib 兜底（纯 Lua 测试环境 / 未实现该契约的宿主）
    local ok2, s2 = pcall(os.date, fmt)
    if ok2 and type(s2) == "string" then
        return s2
    end

    -- ③ 兜底也失败：无时间戳，而不是崩
    return ""
end

--- 随机数种子（整数）
--
-- 为什么不用 `math.floor(EngineAPI.time.getTimeSeconds())`：
--   getTimeSeconds 是**进程启动以来**的秒数（LÖVE: love.timer.getTime()），
--   初始化时恒为 0.x 秒 → 取整永远得到 0 → 每次启动的随机序列完全相同，
--   「随机」形同虚设（战斗 AI / 掉落都会变得可预测）。
--   所以按**毫秒**取整：熵提高 1000 倍，仍完全由注入的时间源决定，
--   测试里 stub getTimeSeconds 后就得到确定的种子。
--
-- @return number 整数种子
function Clock.randomSeed()
    local t = engineTime()
    if t and type(t.getTimeSeconds) == "function" then
        local ok, secs = pcall(t.getTimeSeconds)
        if ok and type(secs) == "number" and secs == secs then   -- 排除 NaN
            return math.floor(secs * 1000)
        end
    end
    -- stdlib 兜底：os.time() 是纪元秒，取整即天然唯一（旧行为）
    return os.time()
end

return Clock
