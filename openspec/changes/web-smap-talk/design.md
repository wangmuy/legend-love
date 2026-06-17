## Context

SMAP 状态下已有 `look`/`exits`/`go`/`leave` 命令。需要增加 NPC 对话能力。金庸群侠传的 1018 个 oldevent 脚本通过 `instruct_*` 函数驱动剧情，这些函数在 Love2D 中通过图形 API 输出（对话文本、菜单、清屏等），在 Web MUD 中需要映射到文本输出。

## Goals / Non-Goals

**Goals:**
- `talk <人名>` 命令：查找场景 NPC → 获取事件 ID → 执行 oldevent
- `instruct_1(talkId, headId)` 从 dataCache.dialogues 读取对话文本并输出
- 其他常用 instruct 函数的 Web MUD 适配（instruct_0 清屏、WaitKey、ShowMenu 等）
- EventExecutor 在 Worker 环境下的兼容

**Non-Goals:**
- 所有 1018 个 oldevent 的完全兼容（只覆盖最常见的 instruct 函数）
- 物品操作（take/give — 另一个 change）
- 场景状态管理（另一个 change）

## Architecture Decision Records

### ADR-001: 用 `rawset(_G, "instruct_1", ...)` 安装 Web MUD 版 instruct 函数

- **Context**: oldevent 脚本通过全局 `instruct_*` 函数与引擎交互。Web MUD 需要替换这些函数为文本输出版本。
- **Decision**: 在 `web_game_bridge.lua` 中用 `rawset(_G, "instruct_N", ...)` 安装替换函数。
- **Alternatives Considered**: 修改框架的 `async_globals.lua` → 影响太大。直接在 Web MUD 层替换。

### ADR-002: talk 命令通过 EventExecutor 执行 oldevent

- **Context**: NPC 对话需要触发 oldevent 脚本。EventExecutor 已封装协程化的事件执行流程。
- **Decision**: `talk` 处理器调用 `EventExecutor.startEvent(eventId, flag, callback)` 执行事件。
- **Consequences**: EventExecutor 的 `oldEventExecuteCoroutine` 会自动安装 async_globals 替换，事件脚本中的 `instruct_*` 调用会被路由到我们的 Web MUD 版。

### ADR-003: WaitKey 映射为普通输入等待

- **Context**: oldevent 中用 `WaitKey()` 暂停并等待用户按键继续。Web MUD 中用户通过文本命令输入。
- **Decision**: `WaitKey()` → 显示 "按回车继续..." → 等待用户输入任意文字 + 回车。
- **Implementation**: 在协程中调用 `scheduler:waitForKey()`，用户输入任意命令后继续。

## Data Flow

```
talk 胡斐
  │
  ├─ SmapHandlers.talk("胡斐")
  │    ├─ 查找当前场景 (JY.SubScene)
  │    ├─ 在场景 NPC 列表中找 "胡斐"
  │    ├─ 获取 NPC 的 "事件编号" (scene.NPC[i]["事件编号"])
  │    └─ 调用 EventExecutor.startEvent(eventId, 0, callback)
  │
  ├─ EventExecutor.oldEventExecuteCoroutine(flag)
  │    ├─ 加载 oldevent_[eventId].lua
  │    ├─ 执行事件脚本
  │    │    ├─ instruct_1(talkId, headId) → 读 JSON → WebUI.write(对话文本)
  │    │    ├─ instruct_0() → WebUI.separator()
  │    │    ├─ WaitKey() → scheduler:waitForKey()
  │    │    └─ ShowMenu(items) → MenuAsync.ShowMenuCoroutine
  │    └─ 事件结束 → callback
  │
  └─ 回到场景，显示场景描述
```

## Decisions

### NPC → 事件 ID 查找
```lua
-- dataCache.scenes 中每个场景有 NPC 列表
local scene = getScenes()[tostring(JY.SubScene)]
local npcs = scene["NPC"]  -- { {["代号"]=70, ["事件编号"]=50}, ... }
for _, npc in ipairs(npcs) do
    if npcName == charName then
        local eventId = npc["事件编号"] or npc["触发事件"] or 0
        EventExecutor.startEvent(eventId, 0, callback)
    end
end
```

### instruct_1 对话文本输出
```lua
rawset(_G, "instruct_1", function(talkId, headId)
    -- dataCache.dialogues: { [talkId] = { [headId] = "对话文本", ... }, ... }
    local dlg = rawget(_G, "dataCache")
    local text = dlg and dlg["dialogues"] and dlg["dialogues"][tostring(talkId)]
    if text then
        WebUI.write(text)
    end
    local w = rawget(_G, "WebUI")
    if w then w.separator() end
end)
```

## Risks

- EventExecutor 的协程模式可能受 Worker 环境 metatable 影响（`_G` 的 `__index=error`）。通过 `rawget/rawset` 访问全局。
- 某些 oldevent 脚本可能使用不常见的 instruct 函数，导致事件执行中断。通过 pcall 保护 + 友好提示处理。
