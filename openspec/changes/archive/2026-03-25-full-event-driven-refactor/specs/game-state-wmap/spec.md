## ADDED Requirements

### Requirement: 战斗状态注册
系统 SHALL 注册 GAME_WMAP 状态处理器到状态机。

#### Scenario: 状态注册
- **WHEN** GameStates.registerAll 执行
- **THEN** GAME_WMAP 状态处理器被注册

### Requirement: 战斗状态进入
进入 GAME_WMAP 状态时 SHALL 正确初始化战斗环境。

#### Scenario: 状态进入
- **WHEN** 切换到 GAME_WMAP 状态
- **THEN** 调用 enter 函数
- **AND** 加载战斗资源（贴图、地图数据）
- **AND** 初始化战斗变量
- **AND** 启动战斗协程

### Requirement: 战斗状态更新
GAME_WMAP 状态更新时 SHALL 执行战斗逻辑。

#### Scenario: 状态更新
- **WHEN** 状态机的 update 被调用
- **THEN** 更新战斗协程
- **AND** 处理战斗输入

### Requirement: 战斗状态渲染
GAME_WMAP 状态渲染时 SHALL 绘制战斗画面。

#### Scenario: 状态渲染
- **WHEN** 状态机的 draw 被调用
- **THEN** 绘制战斗地图
- **AND** 绘制战斗人物
- **AND** 绘制战斗特效
- **AND** 绘制战斗UI（如需要）

### Requirement: 战斗状态退出
退出 GAME_WMAP 状态时 SHALL 清理战斗资源。

#### Scenario: 战斗胜利退出
- **WHEN** 战斗胜利
- **THEN** 调用 exit 函数
- **AND** 清理战斗贴图资源
- **AND** 恢复之前的游戏状态
- **AND** 显示胜利提示

#### Scenario: 战斗失败退出
- **WHEN** 战斗失败
- **THEN** 调用 exit 函数
- **AND** 清理战斗贴图资源
- **AND** 处理失败逻辑（如游戏结束）

### Requirement: 战斗状态与JY.Status同步
GAME_WMAP 状态 SHALL 与 JY.Status 保持同步。

#### Scenario: 状态同步
- **WHEN** JY.Status 被设置为 GAME_WMAP
- **THEN** 状态机自动切换到 GAME_WMAP 状态

#### Scenario: 状态退出同步
- **WHEN** 战斗结束
- **THEN** JY.Status 被设置为之前的状态
- **AND** 状态机同步切换