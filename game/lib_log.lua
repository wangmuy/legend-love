function Log(logfile, traceback, fmt, ...)
    local out
    local str = string.format("%s\n%s%s" .. fmt .. "\n\n", os.date("%H:%M:%S"),
        traceback and debug.traceback() or "", traceback and "\n" or "", ...)
    if logfile~=nil then
        out = io.open(logfile, "a+")
    end
    if out ~= nil then
        out:write(str)
        out:close()
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