## 设计目标

让 Love2D 的 framework/*.lua 在 Web 环境中不经修改运行。输入适配方案：`choose N` 直接调用 `MenuAsync.closeMenu(N)` 关闭当前菜单，游戏命令通过 CommandEngine 按 JY.Status 分发。

## 输入处理方案

关键点：Love2D 的菜单是用 `MenuStateMachine:handleInput()` 配合 `lib.GetKey()` 做的上下键 + 回车选择。Web MUD 没有按键，菜单选择和其他命令分开处理：

**菜单选择**：`choose N` → `MenuAsync.closeMenu(N)`，不走 handleInput/lib.GetKey 流程。

```
用户输入 "choose 1"
  → MenuAsync.hasActiveMenu() == true
  → MenuAsync.closeMenu(1)
    → MenuStateMachine:doCloseMenu()
      → callback(1)
        → ShowMenuCoroutine 返回 1
```

`closeMenu(N)` 是 framework 已有的公共 API，适用于任何菜单（包括子菜单——每次 `ShowMenuCoroutine` 注册独立回调，`closeMenu` 关闭当前活动菜单）。

**游戏命令**：`look`/`go`/`list` 等 → `CommandEngine.dispatchCommand(cmd, args)`，完全不经过 WaitKey。

## processEventQueue 实现

```lua
function processEventQueue(timestamp)
    local AsyncDialog = _G.AsyncDialog or (package.loaded["framework.async_dialog"])
    local hasDialog = AsyncDialog and AsyncDialog.getInstance():hasDialog()
    local MenuAsync = _G.MenuAsync or (package.loaded["framework.menu_async"])
    local hasMenu = MenuAsync and MenuAsync.hasActiveMenu and MenuAsync.hasActiveMenu()

    -- 1. 从 JSBridge 拉取输入事件（仅当无对话框时消费）
    if not hasDialog and JSBridge and JSBridge.getEventCount and JSBridge.getEventCount() > 0 then
        local evt = JSBridge.getEvent()
        if evt and type(evt) == "table" and evt.type == "input" then
            local text = evt.data
            if text and text ~= "" then
                local cmd, arg = text:match("^(%S+)%s*(.-)$")
                cmd = cmd and cmd:lower() or ""

                if cmd == "choose" and hasMenu then
                    -- 菜单选择：直接关闭菜单
                    local n = tonumber(arg)
                    if n then MenuAsync.closeMenu(n) end
                else
                    -- 游戏命令：通过 CommandEngine 分发
                    local CE = rawget(_G, "CommandEngine")
                    if CE and CE.dispatchCommand then
                        local parsed = CE.parseCommand(text)
                        if parsed then
                            if not CE.dispatchCommand(parsed.cmd, parsed.args) then
                                JSBridge.write("未知命令: " .. cmd .. "\n")
                                JSBridge.write("输入 help 查看可用命令\n")
                            end
                        end
                    else
                        JSBridge.write("未知命令: " .. cmd .. "\n")
                        JSBridge.write("当前可用命令: choose N (选择菜单项)\n")
                    end
                end
            end
        end
    end

    -- 2. 驱动协程调度器（恢复挂起的协程）
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
        if currentState == "idle" or currentState == "menu" then
            -- idle/menu 状态不清屏，保留之前的文字
        else
            EngineAPI.render.drawBackground(0, 0, 0, 0, 0)
        end
        if currentState == "dialog" then AsyncDialog.getInstance():draw() end
        if currentState == "menu" then MenuAsync:draw() end
        if StateMachine then
            local sm = StateMachine.getInstance()
            if sm and sm.draw then sm:draw() end
        end
        EngineAPI.render.present()

        -- 对话框状态下提示用户操作
        if currentState == "dialog" then
            WebUI.write("输入 choose 1 确认，choose 2 取消")
        end
    end
end
```

## framework 模块加载策略

```lua
-- web_game_bridge.lua — 框架模块加载器

local frameworkModules = {
    "framework.coroutine_scheduler",
    "framework.state_machine",
    "framework.game_states",
    "framework.event_bridge",
    "framework.event_executor",
    "framework.menu_async",
    "framework.menu_state_machine",
    "framework.async_dialog",
    "framework.async_message_box",
    "framework.async_globals",
    "framework.async_wrapper",
    "framework.input_async",
    "framework.jymain_adapter",
    "framework.jymain_async",
    "framework.talk_async",
    "framework.war_async",
    "framework.item_async",
    "framework.person_status_async",
    "framework.perf_log",
    "framework.lib_file",
    "framework.lib_Byte",
    "framework.lib_log",
    "framework.luabit",
    "framework.config",
    "framework.script_loader",
}

local scriptModules = {
    "script/jymain.lua",
    "script/jyconst.lua",
    "script/jymodify.lua",
}

function loadWebFramework()
    -- 1. 建立 package.preload 映射
    -- framework/*.lua 从 dataCache 或独立加载
    for _, name in ipairs(frameworkModules) do
        local source = loadModuleSource(name)
        if source then
            package.preload[name] = function()
                local fn = load(source, "@" .. name)
                return fn()
            end
        end
    end
    
    -- 2. 加载脚本模块
    for _, path in ipairs(scriptModules) do
        local source = loadScriptSource(path)
        if source then
            local fn = load(source, "@" .. path)
            fn()
        end
    end
    
    -- 3. 初始化游戏适配器
    local JYMainAdapter = require("framework.jymain_adapter")
    JYMainAdapter.init()
end
```

## 兼容函数映射

Love2D 游戏中常用的函数需要映射到 EngineAPI 的 ANSI 输出：

```lua
-- 在 engine_web.lua 或 web_game_bridge.lua 中
_G.Cls = function()
    EngineAPI.render.drawBackground({0, 0, 0})
end

_G.ShowScreen = function()
    EngineAPI.render.present()
end

_G.DrawString = function(x, y, str, color, size)
    EngineAPI.render.text(x, y, str, color, size)
end

_G.DrawBox = function(x, y, w, h, color)
    -- 终端模式下简化为文字框
    EngineAPI.render.rectOutline(x, y, w, h, color)
end

_G.DrawMMap = function() end  -- MUD 中不渲染
_G.DrawSMap = function() end  -- MUD 中不渲染
_G.DrawHead = function() end
_G.DrawHeadPic = function() end
_G.PlayMIDI = function() end
```

## 开始菜单和属性选择

开始菜单在 Love2D 中通过 `MenuAsync.ShowMenuCoroutine()` 显示图形菜单。在 Web MUD 中：

```
系统就绪后显示:
重新开始
载入进度
离开游戏

> choose 1

属性选择:
生命:47/47  内力:38/38  体力:100/100
攻击:28  防御:26  轻功:28  资质:80
拳掌:31  御剑:24  耍刀:29  特殊:29  暗器:29
医疗:30  用毒:27  解毒:23  抗毒:26
内力性质:阳性  生命增长:6

(菜单隐含，choose 1=是 choose 2=否)
> choose 1

新游戏开始！你来到了金庸群侠传的世界。
当前位置
════════════
坐标: (364, 284)
附近场景：
  主角的家 (49步)
  ...
```

### 属性选择实现

覆盖 `JYMainAdapter.startNewGame`（通过 `package.loaded["framework.jymain_adapter"]` 获取模块表），在协程内执行属性选择循环：

```lua
-- generateWebAttrs() — 与原版 generateRandomAttributes 一致的属性生成
-- 属性范围：攻击/防御/轻功等 21-30，内力最大值 21-40，生命增长 3-7
-- 资质分层：<20% 30-64, 20-70% 60-79, >70% 75-94

while not satisfied do
    generateWebAttrs()
    -- 用 WebUI.write 显示属性文本
    WebUI.write("输入 choose 1 (是) 或 choose 2 (否)，choose 0 返回开始菜单")
    -- 调用 MenuAsync.ShowMenu2Coroutine({"是","否"}, ...) 等待用户选择
    -- 协程 yield 期间，用户通过 choose N 交互
    if ok == 1 then satisfied = true
    elseif ok == 0 then return  -- choose 0 返回开始菜单
end
```

### 载入进度覆写

Web MUD 无 R*.idx/grp 二进制存档文件，`JYMainAdapter.loadGame` 被覆写为显示提示并返回开始菜单：

```lua
startNewGameAdapter.loadGame = function()
    WebUI.write("没有存档，请选择「重新开始」开始新游戏\n")
    WebUI.write("输入 choose 1 返回开始菜单\n")
    MenuAsync.ShowMenuCoroutine({"返回开始菜单"}, ...)
    EventBridge.getInstance():switchState(GAME_START)
    -- 直接 return，由 showStartMenuCoroutine 的 while true 循环重新显示菜单
end
```

### 开始菜单覆写（loop 模式）

`showStartMenuCoroutine` 被覆写为 `while true` 循环，确保 ESC（choose 0）重新显示开始菜单，而非递归调用：

```lua
startNewGameAdapter.showStartMenuCoroutine = function()
    while true do
        local menu = {
            {"重新开始", nil, 1},
            {"载入进度", nil, 1},
            {"离开游戏", nil, 1},
        }
        local menuReturn = MenuAsync.ShowMenuCoroutine(menu, 3, ...)
        if menuReturn == 1 then
            startNewGameAdapter.startNewGame(0)
        elseif menuReturn == 2 then
            startNewGameAdapter.loadGame()
        elseif menuReturn == 3 then
            if JY then JY.Status = GAME_END end
            break
        end
        -- menuReturn == 0 (ESC): 循环继续，重新显示菜单
    end
end
```

### 排版修复

1. **xterm.js `\n` 不归零**：默认 `\n`（LF）只下移光标不回到列 0，导致后续输出累积缩进。修复：`convertEol: true` 使 `\n` 等价于 `\r\n`。
2. **WebUI.title / WebUI.separator 使用 render 缓冲**：和 `WebUI.write` 输出路径不一致。修复：全部改用 `JSBridge.write` 直接写入终端。
3. **idle 状态清屏**：drawBackground 在状态从 menu→idle 时清除屏幕，擦除了之前输出的文字。修复：跳过 idle 状态的 drawBackground。

## lib 桩函数（game_states 兼容）

`game_states.lua` 的 MMAP/SMAP 状态处理器调用 `lib.*` 函数加载贴图数据和读取地图数据。这些函数在 MUD 环境中无意义，但必须存在以避免 nil 调用错误：

| lib 函数 | 桩函数行为 | 调用来源 |
|----------|-----------|----------|
| `LoadMMap(...)` | 无操作 | `Init_MMap()` |
| `GetMMap(x, y, flag)` | 返回 0 | `game_states.lua` GAME_MMAP update |
| `UnloadMMap()` | 无操作 | `game_states.lua` GAME_MMAP exit |
| `PicLoadFile(...)` | 无操作 | `Init_MMap()`, `Init_SMap()` |
| `GetS(id, x, y, level)` | 返回 -1（无事件） | `game_states.lua` GAME_SMAP update |
| `SetS(id, x, y, level, v)` | 无操作 | `game_states.lua` GAME_SMAP update |
| `GetD(sceneId, id, i)` | 返回 0 | `game_states.lua` GAME_SMAP update |
| `SetD(sceneId, id, i, v)` | 无操作 | `game_states.lua` GAME_SMAP update |

这些桩函数在 `engine_web.lua` 的 `lib` 表中直接定义。

## game_states 覆写

由于 `game_states.lua` 的 MMAP/SMAP 处理器是为 Love2D 渲染设计的（每帧调用 `DrawMMap`/`DrawSMap`、`GetS`/`GetMMap` 等），在 MUD 中这些处理器被替换为无操作：

```lua
local noop = { enter = function() end, exit = function() end, update = function() end, draw = function() end }
EventBridge.getInstance():registerState(GAME_MMAP, noop)
EventBridge.getInstance():registerState(GAME_SMAP, noop)
EventBridge.getInstance():registerState(GAME_FIRSTMMAP, noop)
```

MUD 的 MMAP/SMAP 交互完全通过 `CommandEngine` 命令处理器处理，不依赖 `game_states` 的渲染/更新循环。

## Init_MMap / Init_SMap 覆写

`jymain.lua` 的 `Init_MMap` 和 `Init_SMap` 在 `game_states` 的 enter 中被调用，用于加载贴图文件。在 MUD 中它们被覆写为仅设置状态变量，不加载任何文件：

```lua
_G.Init_MMap = function()
    JY.EnterSceneXY = nil
    JY.oldMMapX = -1; JY.oldMMapY = -1
end

_G.Init_SMap = function(showname)
    JY.oldSMapX = -1; JY.oldSMapY = -1
    JY.SubSceneX = 0; JY.SubSceneY = 0
    JY.OldDPass = -1; JY.D_Valid = nil
end
```
