-- script_loader.lua
-- Unified Lua chunk loader that is robust across different launch cwd/source layouts.

local ScriptLoader = {}

local function tryLoveLoad(path)
    if love and love.filesystem and love.filesystem.load then
        return love.filesystem.load(path)
    end
    return nil, "love.filesystem.load unavailable"
end

local function tryNativeLoad(path)
    return loadfile(path)
end

function ScriptLoader.load(path)
    local candidates = {
        path,
        "game/" .. path,
    }

    local lastErr = nil
    for _, p in ipairs(candidates) do
        local chunk, err = tryLoveLoad(p)
        if chunk then
            return chunk
        end
        lastErr = err

        chunk, err = tryNativeLoad(p)
        if chunk then
            return chunk
        end
        lastErr = err
    end

    return nil, lastErr or ("failed to load lua chunk: " .. tostring(path))
end

return ScriptLoader

