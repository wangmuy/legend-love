## ADDED Requirements

### Requirement: 战斗主循环异步执行
战斗系统 SHALL 使用协程执行战斗主循环，不阻塞 Love2D 事件循环。

#### Scenario: 战斗开始
- **WHEN** 调用 WarMain 开始战斗
- **THEN** 系统创建战斗协程并启动
- **AND** 状态机切换到 GAME_WMAP 状态

#### Scenario: 战斗进行中
- **WHEN** 战斗协程正在执行
- **THEN** Love2D 事件循环继续运行
- **AND** 战斗画面正常渲染

#### Scenario: 战斗结束
- **WHEN** 战斗协程执行完毕
- **THEN** 系统清理战斗资源
- **AND** 状态机切换回之前的状态

### Requirement: 战斗菜单异步
战斗中的所有菜单（攻击、移动、物品、等待等）SHALL 使用异步菜单系统。

#### Scenario: 选择攻击目标
- **WHEN** 玩家选择攻击指令
- **THEN** 显示攻击范围选择
- **AND** 等待玩家选择目标（不阻塞）

#### Scenario: 使用物品
- **WHEN** 玩家选择物品指令
- **THEN** 显示物品选择菜单（异步）
- **AND** 选择后执行物品效果

### Requirement: 战斗动画异步
战斗动画（攻击特效、移动动画等）SHALL 不阻塞游戏循环。

#### Scenario: 播放攻击动画
- **WHEN** 执行攻击动作
- **THEN** 播放攻击特效动画
- **AND** 动画期间游戏保持响应

#### Scenario: 多人战斗动画
- **WHEN** 多个战斗单位同时行动
- **THEN** 动画按顺序播放（不阻塞）
- **AND** 每个动画完成后触发下一个

### Requirement: 自动战斗支持取消
自动战斗模式 SHALL 支持玩家随时取消。

#### Scenario: 取消自动战斗
- **WHEN** 自动战斗进行中
- **AND** 玩家按下空格或回车
- **THEN** 切换回手动战斗模式