## Context

NPC 对话通过 oldevent 脚本驱动。`instruct_1` 输出对话文本，`instruct_0` 清屏，`WaitKey` 等待用户输入。

## Decisions

### `instruct_1(talkId, headId)`
```lua
local dc = rawget(_G, "dataCache")
local dlg = dc and dc["dialogues"]
local text = dlg and dlg[tostring(talkId)]
if type(text) == "table" then text = text[tostring(headId or 1)] end
if text then WebUI.write(tostring(text)) end
```

### `instruct_0()`
调用 `WebUI.separator()` 输出分隔线替代清屏。

### `WaitKey()`
显示 "按回车继续..."，调用 `scheduler:waitForKey()` 等待输入。

### NPC 对话流程
```
子菜单"对话"
  → smapNpcTalk(sceneId, ent)
    → NPC 有事件编号？ → EventExecutor.startEvent(eventId, 0, callback)
    → NPC 无事件编号？ → "似乎不想说话"
    → 事件完成后 → 回到场景 look
```

## Tests

- `instruct_0()` 不抛异常
- `dataCache.dialogues` 可访问
- NPC 有事件编号 → EventExecutor 被调用
