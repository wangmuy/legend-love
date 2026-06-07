## 设计目标

`engine_web.lua` 的核心职责是把图形游戏的 EngineAPI 调用映射为终端 ANSI 输出。
文件在 Fengari 中运行，通过 `_G.JSBridge` 与 JS 交互。

## 输出模型

Love2D 帧驱动模式和终端文本模式的渲染模型不同：

```lua
-- Love2D 每帧:
--   fillRect(背景) → 无法直接映射（终端没"像素"概念）
--   text(标题)     → 映射为终端的"行追加"
--   text(选项)     → 行追加，菜单项用 ANSI 颜色区分
--   present()      → 提交缓冲区到 xterm

-- 实际输出时序：
-- 菜单打开 → 清屏 → 写入标题行 → 写入选项行 → present()
-- 用户输入 → 清屏 → 写入下一段内容 → present()
```

## ANSI 缓冲区

```lua
local ansiBuffer = {}
local bufferLen = 0

EngineAPI.render.text = function(x, y, str, color, size)
    -- x,y = 像素坐标 → 在终端模式下忽略
    -- color = {r,g,b} 0-1 → 转换为 ANSI 颜色码
    -- str → 追加到 ANSI 缓冲区
    local ansiColor = ansiColorMap(color)
    ansiBuffer[#ansiBuffer + 1] = ansiColor .. str .. "\027[0m"
    bufferLen = bufferLen + 1
end

EngineAPI.render.present = function()
    if bufferLen == 0 then return end
    local output = table.concat(ansiBuffer, "\n")
    ansiBuffer = {}
    bufferLen = 0
    if _G.JSBridge and _G.JSBridge.write then
        _G.JSBridge.write(output)
    end
end
```

## 输入模型

```lua
-- JS 侧: 用户输入 → pushEvent({type="input", key=keyCode})
-- Lua 侧: 事件队列 → 消费 → 恢复协程

local eventQueue = {}

-- 被 JS 调用的函数
function _G.pushLuaEvent(event)
    eventQueue[#eventQueue + 1] = event
end

EngineAPI.input.getKey = function()
    if #eventQueue == 0 then return -1 end
    local ev = table.remove(eventQueue, 1)
    if ev.type == "input" then
        return ev.key
    end
    return -1
end

EngineAPI.input.waitForKey = function()
    while #eventQueue == 0 do
        coroutine.yield()
    end
    local ev = table.remove(eventQueue, 1)
    return ev.key
end
```

## 文件模型

```lua
-- 所有文件数据预加载到 _G.dataCache 中
-- file.open → 从 dataCache 读取，不访问磁盘

_G.dataCache = {}

EngineAPI.file.open = function(filename, mode)
    if mode == "r" or mode == "rb" then
        local content = _G.dataCache[filename]
        if content then
            return StringReader:new(content)
        end
    end
    return nil
end
```

## 颜色映射表

```
原版颜色值                      ANSI 颜色
────────────────────────────────────────────
C_WHITE  = RGB(236,236,236)    \027[37m  白
C_ORANGE = RGB(252,148,16)     \027[33m  黄
C_GOLD   = RGB(236,200,40)     \027[93m  亮黄
C_RED    = RGB(216,20,24)      \027[31m  红
C_BLACK  = RGB(0,0,0)          \027[30m  黑
(默认)                          \027[37m  白
```

## 验证

- 所有 37 个函数签名与 engine_api.lua 一致
- render.text 产出正确的 ANSI 转义码
- input.waitForKey 正确 yield 和恢复
- time.sleep 立即 yield + return
- file.open 从 dataCache 读取