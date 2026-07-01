-- web_command_engine.lua
-- Web MUD 命令解析与分发引擎

local CommandEngine = {}
local commandRegistry = {}
local g = rawget
local function w(text) local w = g(_G, "WebUI"); if w then w.write(text) end end
local function wt(text) local w = g(_G, "WebUI"); if w then w.title(text) end end

function CommandEngine.parseCommand(text)
    if not text or text == "" then return nil end
    
    local args = {}
    for token in text:gmatch("[^%s\"']+") do
        args[#args + 1] = token
    end
    
    if #args == 0 then return nil end
    
    local cmd = args[1]:lower()
    table.remove(args, 1)
    
    return { cmd = cmd, args = args, raw = text }
end

function CommandEngine.registerCommands(stateId, commands)
    commandRegistry[stateId] = commands
end

function CommandEngine.getCommands(stateId)
    return commandRegistry[stateId] or {}
end

function CommandEngine.dispatchCommand(cmd, args)
    local JY = rawget(_G, "JY")
    local stateId = JY and JY.Status or 0
    local commands = commandRegistry[stateId]
    if not commands then return false end
    
    local entry = commands[cmd]
    if not entry then return false end
    
    local ok, err = pcall(entry.handler, args)
    if not ok then
        w("命令执行失败: " .. tostring(err))
    end
    return true
end

function CommandEngine.showHelp(args)
    local JY = rawget(_G, "JY")
    local stateId = JY and JY.Status or 0
    local commands = commandRegistry[stateId]
    if not commands then
        w("当前状态无可用的命令")
        return
    end
    
    if args and #args > 0 then
        local cmd = args[1]:lower()
        local entry = commands[cmd]
        if entry then
            w(cmd .. " - " .. (entry.description or ""))
            if entry.usage then
                w("用法: " .. entry.usage)
            end
        else
            w("未知命令: " .. cmd)
        end
        return
    end
    
    w("可用命令:")
    local items = {}
    for cmd, entry in pairs(commands) do
        items[#items + 1] = string.format("  %-12s %s", cmd, entry.description or "")
    end
    table.sort(items)
    for _, item in ipairs(items) do
        w(item)
    end
end

function CommandEngine.handleChoose(args)
    local n = tonumber(args and args[1])
    if not n then
        w("用法: choose <编号>")
        return
    end
    
    local MenuAsync = rawget(_G, "MenuAsync") or (package.loaded["framework.menu_async"])
    if MenuAsync and MenuAsync.hasActiveMenu and MenuAsync.hasActiveMenu() then
        MenuAsync.closeMenu(n)
    else
        w("当前没有可选的菜单")
    end
end

-- 显示菜单（回调版本，非阻塞）
-- items: { {name="显示文本", ...}, ... }
-- callback: function(selectedIndex) — 选中时用 >0 的索引调用，ESC 时用 nil
function CommandEngine.showMenu(items, title, callback)
    if not items or #items == 0 then
        if callback then callback(nil) end
        return
    end
    
    if title then
        wt(title)
    end
    
    local menu = {}
    for i, item in ipairs(items) do
        local label = item.name or tostring(item)
        menu[i] = {string.format("%d. %s", i, label), nil, 1}
        -- 输出菜单文本（MenuAsync.ShowMenu 使用 DrawString 渲染，Web MUD 不可见）
        w(string.format("%d. %s", i, label))
    end
    w("0. 返回")
    
    local MenuAsync = rawget(_G, "MenuAsync") or (package.loaded["framework.menu_async"])
    if not MenuAsync then
        w("错误：菜单系统不可用")
        if callback then callback(nil) end
        return
    end
    
    local CC = rawget(_G, "CC")
    MenuAsync.ShowMenu(menu, #menu, 0, 0, 0, 0, 0, 0, 1,
        (CC and CC.DefaultFont) or 1,
        (rawget(_G, "C_RED")) or 0,
        (rawget(_G, "C_WHITE")) or 1,
        function(returnValue)
            if returnValue and returnValue > 0 and callback then
                callback(returnValue)
            elseif (not returnValue or returnValue == 0) and callback then
                callback(nil)
            end
        end)
end

_G.CommandEngine = CommandEngine