## 1. 根因分析
Traceability: [REQ-002]

- [x] 1.1 确认 `instruct_9` → `ShowYesNoCoroutine` → `AsyncDialog.showYesNoCoroutine` → `scheduler:yield("dialog")` 完整调用链
  Blast Radius: `["game/framework/async_dialog.lua", "game/framework/async_message_box.lua", "game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [x] 文档化 yield/resume 时序：processEventQueue 中 dialog update → coroutine scheduler → state machine
    - [x] 确认 `hasDialog` 标记在对话框生命周期中的正确性：closeDialog 后 currentDialog=nil, hasDialog=false

- [x] 1.2 确认 `lib.GetKey()` 与 `processEventQueue` 的事件竞争条件
  Blast Radius: `["game/engine-web/engine_web.lua", "game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [x] 确认 `lib.GetKey()` → `EngineAPI.input.getKey()` → `JSBridge.getEvent()` 与 `processEventQueue` 消费同一事件队列
    - [x] 确认 `hasDialog=true` 时 `processEventQueue` 步骤 1 正确跳过，事件由 AsyncDialog.update 消费

## 2. 修复实现
Traceability: [REQ-002]

- [x] 2.1 修复 `AsyncDialog.handleInput` 事件读取机制
  Blast Radius: `["game/framework/async_dialog.lua"]`
  DoD:
    - [x] 方案 B：`processEventQueue` 中 dialog update 放在 coroutine scheduler 之前执行
    - [x] `choose 1` → `GetKey()` 返回 13(Enter) → `closeDialog(1)` → `instruct_9` 返回 true

- [x] 2.2 确保 `processEventQueue` 中 dialog update 始终在 coroutine scheduler 之前
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [x] 执行顺序：dialog update → coroutine scheduler → state machine
    - [x] 删除残留的旧 dialog update 调用

## 3. 验证
Traceability: [REQ-WT-001]

- [x] 3.1 田伯光加入 NPC 对话验证
  Blast Radius: `["game/engine-web/tests/walkthrough-p1.spec.js"]`
  DoD:
    - [x] `choose 2` 选田伯光（entity 2）→ `choose 1` 对话 → `choose 1` 是 → 加入队伍
    - [x] 战后存档 JY.Status=2

- [x] 3.2 段誉加入 NPC 对话验证
  Blast Radius: `["game/engine-web/tests/walkthrough-p1.spec.js"]`
  DoD:
    - [x] 高升客栈 `choose 5` 选段誉 → `choose 1` 对话 → `choose 1` 是 → 加入队伍

- [x] 3.3 胡斐加入 NPC 对话验证
  Blast Radius: `["game/engine-web/tests/walkthrough-p2.spec.js"]`
  DoD:
    - [x] 胡斐居 `choose 3` 选胡斐（entity 3）→ `choose 1` 对话 → `choose 1` 是 → 加入队伍

- [x] 3.4 回归测试 P1-P9 全部通过
  Blast Radius: `["game/engine-web/tests/walkthrough-p*.spec.js"]`
  DoD:
    - [x] `npx playwright test tests/walkthrough-p1.spec.js` 通过 (3.9m)
    - [x] `npx playwright test tests/walkthrough-p2.spec.js` 通过 (2.4m)
    - [x] `npx playwright test tests/walkthrough-p3.spec.js` 通过 (2.4m)
    - [x] P4-P9 全部通过