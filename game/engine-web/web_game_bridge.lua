-- web_game_bridge.lua
-- Web MUD 游戏框架集成层
-- processEventQueue + 兼容函数 + 模块加载

-- WebUI 输出辅助
_G.WebUI = {}

function _G.WebUI.write(text)
    EngineAPI.render.text(0, 0, tostring(text) .. "\n")
    EngineAPI.render.present()
end

function _G.WebUI.writeLine(text)
    EngineAPI.render.text(0, 0, tostring(text))
    EngineAPI.render.present()
end

function _G.WebUI.separator()
    EngineAPI.render.text(0, 0, string.rep("─", 40) .. "\n")
    EngineAPI.render.present()
end

function _G.WebUI.title(text)
    EngineAPI.render.text(0, 0, "\n" .. tostring(text) .. "\n")
    EngineAPI.render.text(0, 0, string.rep("═", #tostring(text)) .. "\n")
    EngineAPI.render.present()
end

-- io 桩函数（浏览器环境无文件系统）
_G.io = {
    open = function() return nil end,
    lines = function() return function() return nil end end,
    input = function() end,
    output = function() end,
    tmpfile = function() return nil end,
    type = function() return nil end,
    write = function() end,
    read = function() return nil end,
}

-- 兼容函数映射
_G.Cls = function()
    EngineAPI.render.drawBackground({0, 0, 0})
end

_G.ShowScreen = function()
    EngineAPI.render.present()
end

_G.DrawString = function(x, y, str, color, size)
    EngineAPI.render.text(x, y, str, color, size)
end

_G.DrawBox = function(x1, y1, x2, y2, color)
    EngineAPI.render.text(x1, y1, string.rep("─", 20), color)
end

_G.DrawMMap = function()
end

_G.DrawSMap = function()
end

_G.DrawHead = function(x, y, headId) end
_G.DrawHeadPic = function(x, y, headId) end
_G.PlayMIDI = function() end

-- 框架模块源存储
_G.FrameworkSources = _G.FrameworkSources or {}

function _G.registerFrameworkModule(name, source)
    _G.FrameworkSources[name] = source
    package.preload[name] = function()
        local fn, err = load(source, "@" .. name)
        if not fn then
            EngineAPI.debug.log("加载模块失败 " .. name .. ": " .. tostring(err))
            return {}
        end
        local ok, result = pcall(fn)
        if not ok then
            EngineAPI.debug.log("执行模块失败 " .. name .. ": " .. tostring(err))
            return {}
        end
        return result
    end
end

-- 调试函数（在 setmetatable(_G) 之前定义，之后可调用）
function _G.__debug_coro_state()
    local cs = package.loaded["framework.coroutine_scheduler"]
    if not cs then return {} end
    local s = cs.getInstance()
    local all = s:getAllCoroutines()
    local r = {}
    for _, id in ipairs(all) do
        local info = s:getInfo(id)
        r[#r+1] = {id=id, status=info.status, waitingFor=info.waitingFor}
    end
    return r
end

-- 初始化框架
function _G.initWebFramework()
    -- 0. 先加载 config 确保 CONFIG 全局变量存在
    require("framework.config")
    
    -- 初始化 __quiet 标志（必须在 setmetatable(_G) 之前存在）
    _G.__quiet = false

    -- 1. 加载脚本模块
    local scriptList = {
        "script/jymain.lua",
        "script/jyconst.lua",
        "script/jymodify.lua",
    }
    for _, path in ipairs(scriptList) do
        local source = _G.FrameworkSources[path]
        if source then
            local fn, err = load(source, "@" .. path)
            if fn then
                local ok, result = pcall(fn)
                if ok then
                    EngineAPI.debug.log("  " .. path .. ": OK")
                else
                    EngineAPI.debug.log("  " .. path .. ": FAILED " .. tostring(result))
                end
            else
                EngineAPI.debug.log("  " .. path .. ": 编译失败 " .. tostring(err))
            end
        else
            EngineAPI.debug.log("  " .. path .. ": 未找到")
        end
    end

    -- 2. 初始化游戏适配器
    require("framework.lib_log")
    _G.EventBridge = require("framework.event_bridge")
    _G.StateMachine = require("framework.state_machine")
    _G.MenuAsync = require("framework.menu_async")
    _G.CoroutineScheduler = require("framework.coroutine_scheduler")
    _G.AsyncDialog = require("framework.async_dialog")
    local ok, err = pcall(function()
        local JYMainAdapter = require("framework.jymain_adapter")
        JYMainAdapter.init()
    end)
    if not ok then
        EngineAPI.debug.log("JYMainAdapter.init 失败: " .. tostring(err))
    end
    _G.__quiet = true
end



-- 显示状态跟踪（MUD 只需要在状态变化时重绘，无需每帧渲染）
local lastDrawState = nil

local function determineDrawState()
    local AsyncDialog = _G.AsyncDialog or (package.loaded["framework.async_dialog"])
    if AsyncDialog and AsyncDialog.getInstance():hasDialog() then
        return "dialog"
    end
    local MenuAsync = _G.MenuAsync or (package.loaded["framework.menu_async"])
    if MenuAsync and MenuAsync.hasActiveMenu and MenuAsync.hasActiveMenu() then
        return "menu"
    end
    return "idle"
end

-- processEventQueue
function processEventQueue(timestamp)
    local AsyncDialog = _G.AsyncDialog or (package.loaded["framework.async_dialog"])
    local hasDialog = AsyncDialog and AsyncDialog.getInstance():hasDialog()
    local MenuAsync = _G.MenuAsync or (package.loaded["framework.menu_async"])
    local hasMenu = MenuAsync and MenuAsync.hasActiveMenu and MenuAsync.hasActiveMenu()

    -- 1. 处理输入事件（仅当无对话框时消费事件；对话框自己通过 lib.GetKey 消费）
    if not hasDialog and _G.JSBridge and _G.JSBridge.getEventCount and _G.JSBridge.getEventCount() > 0 then
        local evt = _G.JSBridge.getEvent()
        if evt and type(evt) == "table" and evt.type == "input" then
            local text = evt.data
            if text and text ~= "" then
                local cmd, arg = text:match("^(%S+)%s*(.-)$")
                cmd = cmd and cmd:lower() or ""

                if cmd == "choose" and hasMenu then
                    local n = tonumber(arg)
                    if n then
                        MenuAsync.closeMenu(n)
                    end
                elseif rawget(_G, "CommandEngine") and rawget(_G, "CommandEngine").parseCommand then
                    local parsed = rawget(_G, "CommandEngine").parseCommand(text)
                    if parsed then
                        local handled = rawget(_G, "CommandEngine").dispatchCommand(parsed.cmd, parsed.args)
                        if not handled then
                            WebUI.write("未知命令: " .. cmd)
                            WebUI.write("当前可用命令: choose N (选择菜单项)")
                        end
                    end
                else
                    -- CommandEngine 尚未加载，但至少提示用户
                    WebUI.write("未知命令: " .. cmd)
                    WebUI.write("当前可用命令: choose N (选择菜单项)")
                end
            end
        end
    end

    -- 2. 驱动协程调度器
    if CoroutineScheduler then
        local scheduler = CoroutineScheduler.getInstance()
        if scheduler and scheduler.update then
            scheduler:update(0)
        end
    end

    -- 3. 更新状态机
    if StateMachine then
        local sm = StateMachine.getInstance()
        if sm and sm.update then
            sm:update(0)
        end
    end

    -- 4. 更新对话框（内部调用 lib.GetKey 读取事件）
    if AsyncDialog then
        AsyncDialog.getInstance():update(0)
    end

    -- 5. 更新菜单（不绘制，仅处理逻辑）
    if MenuAsync then
        MenuAsync:update(0)
    end

    -- 6. 检测状态变化，决定是否需要重绘
    local currentState = determineDrawState()
    if currentState ~= lastDrawState then
        lastDrawState = currentState
        EngineAPI.render.drawBackground(0, 0, 0, 0, 0)
        if currentState == "dialog" then
            AsyncDialog.getInstance():draw()
        end
        if currentState == "menu" then
            MenuAsync:draw()
        end
        if StateMachine then
            local sm = StateMachine.getInstance()
            if sm and sm.draw then
                sm:draw()
            end
        end
        EngineAPI.render.present()
        
        -- 对话框状态下提示用户操作
        if currentState == "dialog" then
            WebUI.write("输入 choose 1 确认，choose 2 取消")
        end
    end
end