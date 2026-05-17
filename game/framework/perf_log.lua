local PerfLog = {}

local FileUtil = require "framework.lib_file"
local logfile = "perf.txt"
local initialized = false

local function now()
    if love and love.timer and love.timer.getTime then
        return love.timer.getTime()
    end
    return os.clock()
end

local function writeLine(line)
    local f = FileUtil.open(logfile, "a")
    if not f then
        return
    end
    f:write(line .. "\n")
    f:close()
end

function PerfLog.init()
    if initialized then
        return
    end
    local f = FileUtil.open(logfile, "w")
    if f then
        f:write(string.format("=== perf session %s ===\n", os.date("%Y-%m-%d %H:%M:%S")))
        f:close()
    end
    initialized = true
end

function PerfLog.mark(tag, detail)
    if not initialized then
        PerfLog.init()
    end
    if detail ~= nil then
        writeLine(string.format("[%0.3f] %s | %s", now(), tostring(tag), tostring(detail)))
    else
        writeLine(string.format("[%0.3f] %s", now(), tostring(tag)))
    end
end

function PerfLog.begin(name)
    return { name = name, t0 = now() }
end

function PerfLog.finish(token, detail)
    if not token then
        return
    end
    local dtMs = (now() - token.t0) * 1000
    if detail ~= nil then
        writeLine(string.format("[%0.3f] %s took %.1f ms | %s", now(), token.name, dtMs, tostring(detail)))
    else
        writeLine(string.format("[%0.3f] %s took %.1f ms", now(), token.name, dtMs))
    end
end

return PerfLog
