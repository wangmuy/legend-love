-- lib_bit.lua
-- 跨版本提供 bit32 风格的两个操作：band（按位与）、rshift（逻辑右移）
--
-- 为什么需要：
--   * Lua 5.1 / LuaJIT  → 没有 bit32（本仓库此前用 framework/luabit.lua 兜底）
--   * Lua 5.2 / 5.3     → 自带 bit32（5.3 起标记为 deprecated，但仍在）
--   * Lua 5.4 / 5.5     → **bit32 已被移除**
-- 而 lib_Byte.lua / lib_love.lua 里 20+ 处直接调 `bit32.band` / `bit32.rshift`，
-- 且原实现只在 `_VERSION < "Lua 5.2"` 时装 luabit，导致 5.4/5.5 下
-- bit32 恒为 nil → `attempt to index a nil value (global 'bit32')`。
-- （测试没暴露这个问题，是因为 tests/test_helper.lua 的 mock 顺手装了 shim。）
--
-- 后端选择（按优先级）：
--   1. 原生 bit32 表        —— 5.2 / 5.3
--   2. 5.3+ 原生运算符 & >> —— 5.4 / 5.5（用 load 隔离，避免 5.1 解析报错）
--   3. 纯 Lua luabit        —— 5.1 / 任何拿不到上面两者的环境

local Bit = {}
Bit.backend = "?"

local function nativeBit32()
    local b = rawget(_G, "bit32")
    if type(b) == "table" and type(b.band) == "function"
        and type(b.rshift) == "function" then
        return b.band, b.rshift
    end
    return nil
end

-- 注意：`&` / `>>` 是 Lua 5.3+ 语法。直接写在源码里会让 5.1/LuaJIT 在
-- **加载本文件时**就报语法错误，所以必须用 load 在运行时编译。
-- 另外 Lua 5.1 的 `load` 只接受函数（字符串要用 loadstring），故两者都试。
local function nativeOperators()
    local loader = loadstring or load
    local chunk = loader(
        "return function(a, b) return a & b end, function(a, b) return a >> b end")
    if not chunk then return nil end
    local ok, band, rshift = pcall(chunk)
    if not ok or type(band) ~= "function" or type(rshift) ~= "function" then
        return nil
    end
    return band, rshift
end

local function pureLua()
    local ok = pcall(require, "framework.luabit")
    local b = rawget(_G, "bit")
    if not ok or type(b) ~= "table" then return nil end
    local band = b.band
    local rshift = b.brshift -- luabit 的逻辑右移叫 brshift
    if type(band) ~= "function" or type(rshift) ~= "function" then return nil end
    return band, rshift
end

local band, rshift = nativeBit32()
if band then
    Bit.backend = "bit32"
else
    band, rshift = nativeOperators()
    if band then
        Bit.backend = "operators"
    else
        band, rshift = pureLua()
        Bit.backend = band and "luabit" or "none"
    end
end

if not band then
    -- 极端情况：连 luabit 都加载不了。给出明确的错误而不是之后 20 处 nil 索引。
    error("lib_bit: 无法获得按位与/右移实现（bit32 / 原生运算符 / luabit 均不可用）")
end

--- 按位与
-- @param a number
-- @param b number
-- @return number
function Bit.band(a, b) return band(a, b) end

--- 逻辑右移
-- @param a number
-- @param n number
-- @return number
function Bit.rshift(a, n) return rshift(a, n) end

-- 兼容：保留一份可当 bit32 用的表（供 setfenv 的作用域直接引用）
Bit.api = {
    band = Bit.band,
    rshift = Bit.rshift,
}

return Bit
