local LOG_HANDLES = {}

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
        out:flush()
    else
        io.write(str)
    end
end

function Debugt(fmt, ...)
    local logfile = CONFIG and CONFIG.DEBUG_FILE or nil
    Log(logfile, true, fmt, ...)
end

function Debug(fmt, ...)
    local logfile = CONFIG and CONFIG.DEBUG_FILE or nil
    Log(logfile, false, fmt, ...)
end

function JY_Error(fmt, ...)
    local logfile = CONFIG and CONFIG.DEBUG_FILE or nil
    Log(logfile, false, fmt, ...)
end
