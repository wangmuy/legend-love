local LOG_HANDLES = {}
local LAST_FLUSH_TS = {}
local FLUSH_INTERVAL = 0.5

local FileUtil = require "framework.lib_file"
-- 墙上时钟：EngineAPI.time.formatNow 优先，os.date 兜底
local Clock = require "framework.clock"

--- 日志行首时间戳（HH:MM:SS）
--
-- 为什么不再直接写 `os.date("%H:%M:%S")`（change: framework-io-portability）：
--   os.date 是 Lua 标准库，Godot/Unreal 上不存在 → 换引擎后**每一次日志**
--   都会抛错（日志本应是最不该崩的东西）。改走 framework/clock.lua：
--   EngineAPI.time.formatNow 优先，没有契约时退回 os.date（纯 Lua 测试环境）。
--
-- 降级策略（硬要求：日志时间戳错了不影响游戏）：
--   两者都不可用时返回 "-"，日志照常写出整行内容 —— 缺时间戳远好于崩。
-- @return string
local function timestamp()
    local s = Clock.formatNow("%H:%M:%S")
    if type(s) ~= "string" or s == "" then
        return "-"
    end
    return s
end

local function getLogHandle(logfile)
    if logfile == nil then
        return nil
    end
    local h = LOG_HANDLES[logfile]
    if h ~= nil then
        return h
    end
    h = FileUtil.open(logfile, "w")
    LOG_HANDLES[logfile] = h
    return h
end

function Log(logfile, traceback, fmt, ...)
    local out
    local str = string.format("%s\n%s%s" .. fmt .. "\n\n", timestamp(),
        traceback and debug.traceback() or "", traceback and "\n" or "", ...)
    out = getLogHandle(logfile)
    if out ~= nil then
        out:write(str)
        local now = os.clock()
        local last = LAST_FLUSH_TS[logfile] or 0
        if (now - last) >= FLUSH_INTERVAL then
            out:flush()
            LAST_FLUSH_TS[logfile] = now
        end
    else
        io.write(str)
    end
end

function Debugt(fmt, ...)
    if CONFIG and CONFIG.Debug ~= 1 then
        return
    end
    local logfile = CONFIG and CONFIG.DEBUG_FILE or nil
    Log(logfile, true, fmt, ...)
end

function Debug(fmt, ...)
    if CONFIG and CONFIG.Debug ~= 1 then
        return
    end
    local logfile = CONFIG and CONFIG.DEBUG_FILE or nil
    Log(logfile, false, fmt, ...)
end

function JY_Error(fmt, ...)
    local logfile = (CONFIG and CONFIG.ERROR_FILE) or (CONFIG and CONFIG.DEBUG_FILE) or nil
    Log(logfile, false, fmt, ...)
end
