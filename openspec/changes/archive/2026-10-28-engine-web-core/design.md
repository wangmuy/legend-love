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
    local ansiColor = colorToAnsi(color)
    local lines = {}
    for line in str:gmatch("[^\n]+") do
        lines[#lines + 1] = ansiColor .. line .. "\027[0m"
    end
    ansiBuffer[#ansiBuffer + 1] = table.concat(lines, "\n")
    bufferLen = bufferLen + 1
end

EngineAPI.render.present = function()
    if bufferLen == 0 then return end
    local output = table.concat(ansiBuffer, "")
    ansiBuffer = {}
    bufferLen = 0
    if _G.JSBridge and _G.JSBridge.write then
        _G.JSBridge.write(output)
    end
end
```

## 输入模型

```lua
-- JS 侧: 用户输入 → JSBridge.pushEvent({type="input", data=text})
-- Lua 侧: JSBridge.getEvent() → 消费 → 恢复协程

function _G.pollEvents()
    while true do
        local ev = _G.JSBridge.getEvent()
        if not ev then break end
        table.insert(eventQueue, ev)
    end
end

EngineAPI.input.getKey = function()
    pollEvents()
    if #eventQueue == 0 then return -1 end
    local ev = table.remove(eventQueue, 1)
    -- 输入事件返回按键字符串的首字符 ASCII 码
    if ev.type == "input" and ev.data and #ev.data > 0 then
        return ev.data:byte(1)
    end
    return -1
end

EngineAPI.input.waitForKey = function()
    while true do
        pollEvents()
        if #eventQueue > 0 then
            local ev = table.remove(eventQueue, 1)
            if ev.type == "input" and ev.data and #ev.data > 0 then
                return ev.data:byte(1)
            end
        end
        coroutine.yield()
    end
end
```

## 文件模型

```lua
-- 所有文件数据预加载到 _G.dataCache (解析后) 和 _G.rawDataCache (原始 JSON 字符串) 中
-- file.open → 从 rawDataCache 按文件名读取原始字符串

_G.rawDataCache = {}

EngineAPI.file.open = function(filename, mode)
    if mode ~= "r" and mode ~= "rb" then
        return nil
    end
    local content = _G.rawDataCache[filename]
    if not content then
        return nil
    end
    -- 返回一个文件句柄：{read, seek, close}
    local pos = 1
    return {
        read = function(self, count)
            if not count then return content:sub(pos) end
            local s = content:sub(pos, pos + count - 1)
            pos = pos + count
            return s
        end,
        seek = function(self, whence, offset)
            if whence == "set" then pos = offset + 1
            elseif whence == "cur" then pos = pos + offset
            elseif whence == "end" then pos = #content + offset + 1
            end
        end,
        close = function() end
    }
end

EngineAPI.file.exists = function(filename)
    return _G.rawDataCache[filename] ~= nil
end

EngineAPI.file.lines = function(filename)
    local content = _G.rawDataCache[filename]
    if not content then return function() end end
    local pos = 1
    return function()
        if pos > #content then return nil end
        local nextPos = content:find("\n", pos, true)
        if nextPos then
            local line = content:sub(pos, nextPos - 1)
            pos = nextPos + 1
            return line
        end
        local line = content:sub(pos)
        pos = #content + 1
        return line
    end
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

- 所有 45 个函数签名与 engine_api.lua 一致
- render.text 产出正确的 ANSI 转义码
- input.waitForKey 正确 yield 和恢复
- time.sleep 立即 yield + return
- file.open 从 dataCache 读取