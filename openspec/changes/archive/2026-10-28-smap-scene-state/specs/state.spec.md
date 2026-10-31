## ADDED Requirements

### Requirement: sceneState API [REQ-003]

系统 SHALL 提供场景动态状态管理 API。

#### Scenario: 惰性初始化
- **WHEN** 首次调用 `getSceneState(sceneId)`
- **THEN** 创建 `{npc={}, items={}}` 并返回

#### Scenario: NPC 状态
- **WHEN** 调用 `setNpcPresent(id, false)`
- **THEN** `isNpcPresent(id)` 返回 `false`
- **WHEN** 未调用 `setNpcPresent`
- **THEN** `isNpcPresent(id)` 默认返回 `true`

#### Scenario: 物品状态
- **WHEN** 调用 `setItemCount(id, 0)`
- **THEN** `itemAvailable(id)` 返回 `false`

#### Scenario: look 过滤
- **GIVEN** `isNpcPresent(id)` 返回 `false` 或 `itemAvailable(id)` 返回 `false`
- **WHEN** 同场景 `look`
- **THEN** 对应的 NPC/物品不显示在列表中
