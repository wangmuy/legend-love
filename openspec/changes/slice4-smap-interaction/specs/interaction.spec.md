## ADDED Requirements

### Requirement: SMAP 菜单驱动交互 [REQ-001]

系统 SHALL 在 SMAP 状态下使用菜单驱动交互模式：`look` 输出 NPC/物品/出口的编号列表，`choose N` 做级联菜单选择。

#### Scenario: look 显示编号列表
- **Given** 玩家处于 SMAP 状态
- **WHEN** 输入 `look`
- **THEN** 输出格式为 `"N. <NPC名>"` / `"N. <物品名>"` / `"N. → <出口名>"`
- **AND** 末尾显示 `"输入 choose <编号> 选择交互对象"`

#### Scenario: choose N 选择 NPC 弹出子菜单
- **Given** `look` 已显示编号列表
- **WHEN** 输入 `choose N` 且 N 对应一个 NPC
- **THEN** 弹出子菜单包含"对话"、"查看"、"给予物品"

#### Scenario: choose N 选择物品弹出子菜单
- **Given** `look` 已显示编号列表  
- **WHEN** 输入 `choose N` 且 N 对应一个物品
- **THEN** 弹出子菜单包含"拾取"、"查看"

#### Scenario: choose N 选择出口直接传送
- **Given** `look` 已显示编号列表
- **WHEN** 输入 `choose N` 且 N 对应一个出口
- **THEN** 直接传送到出口目标场景

### Requirement: NPC 对话 [REQ-002]

系统 SHALL 支持通过子菜单"对话"触发 NPC 的 oldevent 事件。

#### Scenario: 对话触发 oldevent
- **Given** NPC 有事件编号
- **WHEN** 在 NPC 子菜单中选择"对话"
- **THEN** 调用 `EventExecutor.startEvent(eventId, 0, callback)`

#### Scenario: 对话文本输出
- **WHEN** oldevent 脚本调用 `instruct_1(talkId, headId)`
- **THEN** 从 `dataCache.dialogues` 读取文本并通过 `WebUI.write` 输出

#### Scenario: 等待用户输入
- **WHEN** oldevent 脚本调用 `WaitKey()`
- **THEN** 显示"按回车继续..."并等待用户输入

### Requirement: 场景状态管理 [REQ-003]

系统 SHALL 提供场景动态状态管理，NPC 离场或物品拾取后在 `look` 中不可见。

#### Scenario: NPC 离场后不可见
- **GIVEN** 调用 `setNpcPresent(sceneId, charId, false)`
- **WHEN** 同场景 `look` 输出
- **THEN** 该 NPC 不显示在列表中

#### Scenario: 物品拾取后不可用
- **GIVEN** 调用 `setItemCount(sceneId, itemId, 0)`
- **WHEN** 调用 `itemAvailable(sceneId, itemId)`
- **THEN** 返回 `false`
