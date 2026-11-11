-- tools/trace_global.lua
-- 通用：游戏内全局状态时序追踪器（原 diag_mypic 的通用化版本）。
--
-- 用途：在 game/ 代码的写点插入 TRACE.log("tag") 一行调用，
-- 即可按帧时序记录目标全局变量的快照，用于定位"谁在什么时候改了 X"。
--
-- 用法（在 game/ 内被加载，如 main.lua 或需要诊断的模块里）:
--   TRACE = require "tools.trace_global"   -- 需将仓库根目录加入 package.path
--   -- 配置追踪目标（可选，默认只记时间戳+tag）:
--   TRACE.fields = {
--       MyPic = function() return JY.MyPic end,
--       dir   = function() return JY.Base["人方向"] end,
--   }
--   -- 调用点:
--   TRACE.log("startNewGame:348")
--
-- 输出: tools/trace_out.txt（仓库根目录下；每次加载清空重记）。
-- 每行: [ms] tag | caller file:line | 各 field 值
--
-- 注意: 本工具始终输出（不受 CONFIG.Debug 控制），调查完成后请移除调用点。
-- 纯 Lua 实现，不依赖 Love2D；文件写入走 stdio 相对仓库根目录。

local M = {}

-- 追踪字段: name -> function 返回当前值（惰性求值，log 时调用）
M.fields = {}

local function repoRoot()
    -- 向上找包含 tools/ 目录的祖先（最多 4 级）
    local dir = "."
    for _ = 1, 4 do
        local f = io.open(dir .. "/tools", "r")
        if f then f:close() return dir end
        f = io.open(dir .. "/.git", "r")
        if f then f:close() return dir end
        local parent = dir:match("^(.*)[/\\][^/\\]+$")
        if not parent then break end
        dir = parent
    end
    return "."
end

local path = (repoRoot() .. "/tools/trace_out.txt"):gsub("\\", "/")

local function nowMs()
    if EngineAPI and EngineAPI.time and EngineAPI.time.getTime then
        return EngineAPI.time.getTime()
    end
    return math.floor(os.clock() * 1000)
end

-- 返回调用方（TRACE.log 的上一级）的 file:line
local function callerInfo()
    local info = debug.getinfo(2, "Sl")
    if info and info.source then
        local src = info.source
        if src:sub(1, 1) == "@" then src = src:sub(2) end
        return string.format("%s:%s", src, tostring(info.currentline))
    end
    return "?"
end

-- 记录一条追踪
-- @param tag  标记（写点位置，建议 "函数:行号" 风格）
-- @param extra 可选 table，覆盖/追加本次的字段值
function M.log(tag, extra)
    local parts = { string.format("[%dms] %s | %s", nowMs(), tag, callerInfo()) }
    if extra then
        for k, v in pairs(extra) do
            parts[#parts + 1] = string.format("%s=%s", k, tostring(v))
        end
    end
    for k, fn in pairs(M.fields) do
        local ok, v = pcall(fn)
        parts[#parts + 1] = string.format("%s=%s", k, ok and tostring(v) or "?err")
    end
    local f = io.open(path, "a")
    if f then
        f:write(table.concat(parts, " | ") .. "\n")
        f:close()
    end
end

-- 会话开始：清空旧追踪文件
local f = io.open(path, "w")
if f then
    f:write("=== trace session " .. os.date("%Y-%m-%d %H:%M:%S") .. " ===\n")
    f:close()
end

return M
