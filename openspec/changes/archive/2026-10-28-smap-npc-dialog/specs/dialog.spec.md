## ADDED Requirements

### Requirement: NPC 对话 [REQ-002]

系统 SHALL 支持 NPC 对话并通过 EventExecutor 执行 oldevent。

#### Scenario: 对话执行 oldevent
- **GIVEN** NPC 有事件编号
- **WHEN** 在子菜单中选择"对话"
- **THEN** `EventExecutor.startEvent(eventId, 0, callback)` 被调用

#### Scenario: instruct_1 对话文本输出
- **WHEN** oldevent 调用 `instruct_1(talkId, headId)`
- **THEN** 从 `dataCache.dialogues` 读取文本并输出

#### Scenario: WaitKey
- **WHEN** oldevent 调用 `WaitKey()`
- **THEN** 显示"按回车继续..."并等待

#### Scenario: instruct_0 清屏替代
- **WHEN** oldevent 调用 `instruct_0()`
- **THEN** 调用 `WebUI.separator()` 输出分隔线
