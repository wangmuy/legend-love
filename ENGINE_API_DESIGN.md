# EngineAPI 设计文档 — 后续工作与脚本事件驱动化计划

## 背景

EngineAPI 是 `game/script/` 与底层游戏引擎之间的抽象层，覆盖 render/sprite/map/input/audio/time/file/script/font/color/debug/coroutine 共 11 个模块。当前 OpenSpec 变更（`engine-api-abstraction-layer`）已完成接口定义、Love2D 实现、测试引擎和事件驱动适配层的实现。

本文档记录该变更完成后，后续需要推进的工作。

---

## 一、后续引擎实现

### 1.1 engine_godot.lua

在 Godot 中实现 EngineAPI 接口，使游戏脚本无需修改即可在 Godot 引擎上运行。

```
EngineAPI.render.text       →  Godot Label / draw_string
EngineAPI.render.fillRect   →  draw_rect
EngineAPI.sprite.draw       →  draw_texture / Sprite2D
EngineAPI.map.drawMain      →  等距 TileMap 渲染
EngineAPI.input.waitForKey  →  Input.is_action_just_pressed
EngineAPI.audio.playMusic   →  AudioStreamPlayer
```

### 1.2 其他引擎

EngineAPI 接口定义后，任何引擎只要实现这 37 个函数即可运行游戏脚本。

---

## 二、脚本事件驱动化

### 2.1 现状

当前脚本的执行模型是"阻塞式外观，协程式内里"：

```
oldevent 脚本 (看起来是顺序阻塞的)
    → instruct_1() → TalkEx() → WaitKey()
    → async_globals 拦截 → coroutine.yield()
    → CoroutineScheduler 恢复 → 返回按键值
    → instruct_0() → Cls()
```

这种模式工作正常，但脚本本身并不是事件驱动的——它们被写成顺序执行的代码，依赖框架在底层做协程拦截。

### 2.2 目标：纯事件驱动脚本

纯事件驱动脚本不再有"阻塞等待"的概念，而是注册事件处理器：

```lua
-- 当前风格（顺序阻塞外观）
function oldevent_42()
    instruct_1(137, 3, 0)  -- 显示对话，等待按键
    instruct_0()            -- 清屏
end

-- 事件驱动风格（注册处理器）
function oldevent_42()
    events.onTalkEnd = function()
        events.onKeyPress = function(key)
            -- 处理按键
        end
    end
    showDialogue(137, 3, 0)  -- 触发对话，不等待
end
```

### 2.3 迁移策略

由于 oldevent 有 1018 个脚本，不可能一次性全部改写。采用渐进式策略：

| 阶段 | 内容 | 工作量 |
|------|------|--------|
| 第一阶段 | EngineAPI 定义 yieldable 函数契约（当前变更已完成） | 已完成 |
| 第二阶段 | 新脚本（newevent）支持事件驱动写法 | 低 |
| 第三阶段 | 提供工具将 oldevent 脚本批量转换为事件驱动 | 高 |
| 第四阶段 | 按模块逐步迁移 oldevent 脚本 | 极高（1018 个） |

### 2.4 新脚本的事件驱动写法

新脚本可以直接使用 EngineAPI 的 yieldable 函数，看起来是顺序的，但本质是非阻塞的：

```lua
-- 新风格脚本（推荐）
function newSceneEvent(flag)
    local key = EngineAPI.input.waitForKey()  -- yield，不阻塞
    EngineAPI.time.sleep(500)                  -- yield，不阻塞
    local result = EngineAPI.menu.show(items, 3, ...)  -- yield，不阻塞
end
```

如果需要纯事件驱动风格（回调注册）：

```lua
-- 纯事件驱动风格（可选）
function newSceneEvent(flag)
    local dialog = EngineAPI.dialogue.open(text, headId)
    dialog.onPageEnd = function()
        dialog.close()
        EngineAPI.menu.show(items, 3, ..., function(result)
            -- 处理菜单选择
        end)
    end
end
```

### 2.5 oldevent 脚本的迁移路径

oldevent 脚本短期内不需要修改。长期来看，可以：

1. **保持现状**：1018 个脚本通过 async_globals 适配层继续工作
2. **按需迁移**：当需要修改某个 oldevent 脚本时，顺便改为事件驱动风格
3. **批量转换**：开发转换工具，将 `instruct_N(...)` 调用序列自动转为事件驱动形式

---

## 三、yieldable 函数完整列表

以下函数调用时，当前协程可能 yield：

| 函数 | yield 条件 |
|------|-----------|
| `EngineAPI.input.waitForKey()` | 等待用户按键 |
| `EngineAPI.time.sleep(ms)` | 等待时间流逝 |
| `EngineAPI.render.presentAndWait(delay)` | 帧同步等待 |
| `EngineAPI.menu.show(...)` | 等待用户选择 |
| `EngineAPI.dialogue.show(...)` | 等待用户翻页 |
| `EngineAPI.script.load(path)` | 可选异步加载 |

以下函数不会 yield（入队后立即返回）：

| 函数 | 说明 |
|------|------|
| `EngineAPI.render.text()` | 入渲染队列，立即返回 |
| `EngineAPI.sprite.draw()` | 入渲染队列，立即返回 |
| `EngineAPI.audio.playMusic()` | 触发即忘 |
| `EngineAPI.file.open()` | 同步 I/O |
| `EngineAPI.debug.log()` | 立即输出 |