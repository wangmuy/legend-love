-- script_loader.lua
-- Unified Lua chunk loader that delegates to EngineAPI.script.load.
-- EngineAPI.script.load handles .love archive support and path resolution.

local ScriptLoader = {}

function ScriptLoader.load(path)
    if EngineAPI and EngineAPI.script and EngineAPI.script.load then
        return EngineAPI.script.load(path)
    end
    
    -- EngineAPI 不可用时回退到 loadfile
    local chunk, err = loadfile(path)
    if chunk then
        return chunk
    end
    return loadfile("game/" .. path), err
end

return ScriptLoader