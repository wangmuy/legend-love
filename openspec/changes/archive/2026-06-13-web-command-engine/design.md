## 设计目标

提供一个简单的命令解析引擎，将文本输入转换为可执行的游戏操作。

## parseCommand 设计

```lua
-- web_command_engine.lua

local CommandEngine = {}

-- 解析文本命令
-- "go 河洛客栈" → {cmd="go", args={"河洛客栈"}}
-- "choose 1"    → {cmd="choose", args={"1"}}
-- "look"        → {cmd="look", args={}}
-- "help list"   → {cmd="help", args={"list"}}
function CommandEngine.parseCommand(text)
    if not text or text == "" then return nil end
    
    -- 简单分词：空格分隔，支持引号
    local args = {}
    for token in text:gmatch("[^%s\"']+") or {} do
        args[#args + 1] = token
    end
    
    if #args == 0 then return nil end
    
    local cmd = args[1]:lower()
    table.remove(args, 1)
    
    return { cmd = cmd, args = args, raw = text }
end

return CommandEngine
```

## 命令注册表

```lua
-- 命令注册表：按 JY.Status 组织
local commandRegistry = {}

function CommandEngine.registerCommands(stateId, commands)
    commandRegistry[stateId] = commands
end

function CommandEngine.getCommands(stateId)
    return commandRegistry[stateId] or {}
end
```

## dispatchCommand

```lua
function CommandEngine.dispatchCommand(cmd, args)
    local JY = rawget(_G, "JY")  -- 绕过 setmetatable(_G) 保护
    local stateId = JY and JY.Status or 0
    local commands = commandRegistry[stateId]
    if not commands then return false end
    
    local entry = commands[cmd]
    if not entry then return false end
    
    local ok, err = pcall(entry.handler, args)
    if not ok then
        WebUI.write("命令执行失败: " .. tostring(err))
    end
    return true
end
```

## help 命令

```lua
function CommandEngine.showHelp()
    local stateId = JY.Status
    local commands = commandRegistry[stateId]
    if not commands then
        WebUI.write("当前状态无可用的命令")
        return
    end
    
    WebUI.write("可用命令：")
    local items = {}
    for cmd, entry in pairs(commands) do
        items[#items + 1] = string.format("  %-12s %s", cmd, entry.description)
    end
    table.sort(items)
    for _, item in ipairs(items) do
        WebUI.write(item)
    end
end
```

## choose 命令

```lua
-- choose N 命令：在有活动菜单时关闭菜单并返回 N
-- 注意：如果 processEventQueue 已经处理了 choose N（调用了 MenuAsync.closeMenu），
-- 这里的 handler 只会在没有活动菜单时被执行（兜底）
function CommandEngine.handleChoose(args)
    local n = tonumber(args[1])
    if not n then
        WebUI.write("用法: choose <编号>")
        return
    end
    
    if MenuAsync.hasActiveMenu() then
        -- 由 processEventQueue 优先处理，此处不应到达
        -- 兜底处理
        MenuAsync.closeMenu(n)
    else
        WebUI.write("当前没有可选的菜单")
    end
end
```

## WebUI 输出工具

```lua
-- 在 web_game_bridge.lua 中定义
_G.WebUI = {
    write = function(text)
        -- 直接写入 JSBridge（xterm.js 终端），带换行
        if _G.JSBridge and _G.JSBridge.write then
            _G.JSBridge.write(tostring(text) .. "\n")
        end
    end,
    
    writeLine = function(text)
        if _G.JSBridge and _G.JSBridge.write then
            _G.JSBridge.write(tostring(text))
        end
    end,
    
    separator = function()
        _G.JSBridge.write(string.rep("─", 40) .. "\n")
    end,
    
    title = function(text)
        _G.JSBridge.write("\n" .. tostring(text) .. "\n")
        _G.JSBridge.write(string.rep("═", #tostring(text)) .. "\n")
    end,
}
```
