## ADDED Requirements

### Requirement: GAME_WMAP状态支持
状态机 SHALL 支持 GAME_WMAP 战斗状态的注册和管理。

#### Scenario: 注册战斗状态
- **WHEN** GameStates.registerAll 执行
- **THEN** GAME_WMAP 状态处理器被正确注册

#### Scenario: 战斗状态enter处理器
- **WHEN** 进入 GAME_WMAP 状态
- **THEN** enter处理器加载战斗资源
- **AND** 初始化战斗环境

#### Scenario: 战斗状态exit处理器
- **WHEN** 退出 GAME_WMAP 状态
- **THEN** exit处理器清理战斗资源
- **AND** 恢复游戏环境

### Requirement: JY.Status自动同步
状态机 SHALL 与 JY.Status 保持自动同步。

#### Scenario: JY.Status变化触发切换
- **WHEN** JY.Status 被修改为新值
- **THEN** 状态机自动切换到对应状态
- **AND** 调用正确的enter/exit处理器

#### Scenario: 状态切换更新JY.Status
- **WHEN** 状态机切换状态
- **THEN** JY.Status 同步更新为新状态ID

### Requirement: 状态历史记录
状态机 SHALL 记录状态历史，支持返回上一状态。

#### Scenario: 记录状态历史
- **WHEN** 状态切换
- **THEN** 记录之前的状态
- **AND** 可通过 getPreviousState 获取

#### Scenario: 战斗结束返回
- **WHEN** 战斗结束
- **THEN** 返回之前的状态（主地图或场景）
- **AND** 正确恢复游戏环境