## ADDED Requirements

### Requirement: 功能性 instruct 实现 [REQ-001]

系统 SHALL 提供 5 个功能性 instruct 函数的 Web MUD 实现。

#### Scenario: instruct_11 住宿询问
- **GIVEN** 玩家在客栈场景
- **WHEN** oldevent 调用 `instruct_11()`
- **THEN** 显示"是否住宿？"菜单
- **AND** 选择"是"后调用 `instruct_12()`

#### Scenario: instruct_12 恢复体力
- **WHEN** `instruct_12()` 被调用
- **THEN** `JY.Person[0]["生命"]` = 生命最大值
- **AND** `体力` = 100，`内力` = 内力最大值

#### Scenario: instruct_14 重绘场景
- **WHEN** `instruct_14()` 被调用
- **THEN** `SmapHandlers.look({})` 被调用

#### Scenario: instruct_19 移动主角
- **WHEN** `instruct_19(10, 20)` 被调用
- **THEN** `JY.Base["人X1"]` = 10
- **AND** `JY.Base["人Y1"]` = 20

#### Scenario: instruct_31 物品检查
- **GIVEN** `JY.Base["金钱"]` = 200
- **WHEN** `instruct_31(0, 100, 0)` 被调用
- **THEN** 返回 1（钱够）
- **WHEN** `instruct_31(0, 100, 1)` 被调用
- **THEN** `JY.Base["金钱"]` 减少 100
