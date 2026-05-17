-- script_loader.lua
-- Unified Lua chunk loader that is robust across different launch cwd/source layouts.
-- Delegates to EngineAPI.script.load for engine-independent loading.

local ScriptLoader = {}

function ScriptLoader.load(path)
    -- 优先使用 EngineAPI（支持 .love 打包和多种引擎）
    if EngineAPI and EngineAPI.script and EngineAPI.script.load then
        return EngineAPI.script.load(path)
    end
    
    -- 回退：直接使用 love.filesystem.load
    local candidates = {
        path,
        "game/" .. path,
    }
    
    local lastErr = nil
    for _, p in ipairs(candidates) do
        if love and love.filesystem and love.filesystem.load then
            local chunk, err = love.filesystem.load(p)
            if chunk then
                return chunk
            end
            lastErr = err
        end
        
        local chunk, err = loadfile(p)
        if chunk then
            return chunk
        end
        lastErr = err
    end
    
    return nil, lastErr or ("failed to load lua chunk: " .. tostring(path))
end

return ScriptLoader