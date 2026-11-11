-- script_loader.lua
-- Unified Lua chunk loader that delegates to EngineAPI.script.load.
-- EngineAPI.script.load handles .love archive support and path resolution.
--
-- MOD 回退链（REQ-DATA-2）：加载前先经 ModData.ScriptFile 解析，
-- 使 `mods/<mod>/script/<rel>` 优先、缺失时回退 `script/<rel>`。
-- 未激活 MOD 时 ModData.ScriptFile 原样返回路径（零回归）。

local ScriptLoader = {}

-- 尝试 MOD 优先解析；ModData 不可用或未激活时返回原路径
local function modResolve(path)
    local ok, ModData = pcall(require, "framework.mod_data")
    if not ok or not ModData or not ModData.ScriptFile then
        return path
    end
    local ok2, resolved = pcall(ModData.ScriptFile, path)
    if ok2 and type(resolved) == "string" then
        return resolved
    end
    return path
end

function ScriptLoader.load(path)
    local resolved = modResolve(path)
    if EngineAPI and EngineAPI.script and EngineAPI.script.load then
        return EngineAPI.script.load(resolved)
    end

    -- EngineAPI 不可用时回退到 loadfile
    local chunk, err = loadfile(resolved)
    if chunk then
        return chunk
    end
    return loadfile("game/" .. resolved), err
end

return ScriptLoader
