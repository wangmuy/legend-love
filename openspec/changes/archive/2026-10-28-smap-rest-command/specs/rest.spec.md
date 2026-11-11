## ADDED Requirements

### Requirement: rest 命令 [REQ-001]

系统 SHALL 提供 `rest` 命令，使玩家在场景中休息恢复体力。

#### Scenario: 免费休息（主角的家）
- **GIVEN** 玩家在 `house` 类型场景
- **WHEN** 输入 `rest`
- **THEN** 调用 `instruct_12()` 恢复 HP/MP/体力
- **AND** 输出"你休息了一晚，体力完全恢复了。"

#### Scenario: 客栈住宿
- **GIVEN** 玩家在客栈场景
- **WHEN** 输入 `rest`
- **THEN** 检查金钱是否 ≥ 100
- **AND** 够钱则扣除并恢复，不够则提示

#### Scenario: 不可休息
- **GIVEN** 玩家在非 house/inn 场景
- **WHEN** 输入 `rest`
- **THEN** 输出"这里不是休息的地方。"
