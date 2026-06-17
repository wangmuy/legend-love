## 1. NPC 对话事件执行
Traceability: [REQ-002]

- [x] 1.1 `smapNpcTalk` 函数：调用 EventExecutor.startEvent
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [x] NPC 有事件编号 → startEvent(eventId, 0, callback)
    - [x] NPC 无事件编号 → "似乎不想说话"

- [ ] 1.2 事件回调回到场景 look
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [ ] 事件结束后调用 SmapHandlers.look({})

## 2. instruct 函数
Traceability: [REQ-002]

- [x] 2.1 `instruct_0()` 输出分隔线
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [x] 调用 WebUI.separator()

- [x] 2.2 `instruct_1(talkId, headId)` 对话文本输出
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [x] 从 dataCache.dialogues 读取文本

- [ ] 2.3 `WaitKey()` 等待用户输入
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [ ] 显示"按回车继续..."
    - [ ] 调用 scheduler:waitForKey()

## 3. 测试
Traceability: [REQ-002]

- [x] 3.1 instruct_0 不抛异常
- [x] 3.2 dialogues 数据可访问
- [ ] 3.3 NPC 对话流程（EventExecutor 执行）
