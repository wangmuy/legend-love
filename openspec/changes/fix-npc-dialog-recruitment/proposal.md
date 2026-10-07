## 为什么

现有 NPC 对话/招人系统（`instruct_9`）已实现 `AsyncDialog.showYesNoCoroutine`，但对话框与协程调度器的执行顺序存在竞态条件：`processEventQueue` 中协程调度器在对话框 `update` 之前强行恢复协程，导致 `ShowYesNoCoroutine` 在对话框未关闭时返回 `nil`，`instruct_9` 走 `false` 分支触发战斗而非招募。

## 变更内容

- `game/framework/async_dialog.lua` — 修复 `handleInput` 事件读取机制
- `game/engine-web/web_game_bridge.lua` — 确保 `processEventQueue` 中 dialog update 始终在 coroutine scheduler 之前
- `game/engine-web/tests/walkthrough-p1.spec.js` — 验证田伯光/段誉 NPC 招募
- `game/engine-web/tests/walkthrough-p2.spec.js` — 验证胡斐 NPC 招募

## 能力

### 新增能力
- NPC 对话后 `instruct_9` 对话框正确返回用户选择（是/否）
- 田伯光、段誉、胡斐等 NPC 可通过对话招募入队，不走战斗分支

### 修改的能力
- AsyncDialog 的输入读取机制

## 影响

- 修复 `instruct_9` 返回值正确性，影响所有使用 `instruct_9` 的 oldevent 脚本
- 修复后 P1-P9 回归测试全部通过