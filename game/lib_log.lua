local LOG_HANDLES = {}
local LAST_FLUSH_TS = {}
local FLUSH_INTERVAL = 0.5

local FileUtil = require "lib_file"

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
    local str = string.format("%s\n%s%s" .. fmt .. "\n\n", os.date("%H:%M:%S"),
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
