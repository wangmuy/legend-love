## ADDED Requirements

### Requirement: Love2D标准回调支持
系统 SHALL 使用Love2D标准事件回调(love.update, love.draw, love.keypressed等)替代自定义游戏循环。

#### Scenario: 游戏启动
- **WHEN** 游戏启动
- **THEN** love.load初始化游戏
- **AND** love.run使用默认实现

#### Scenario: 游戏主循环
- **WHEN** 每帧更新
- **THEN** love.update被调用处理游戏逻辑
- **AND** love.draw被调用渲染画面

### Requirement: 游戏逻辑与渲染分离
系统 SHALL 将游戏逻辑更新和画面渲染分离到不同回调中。

#### Scenario: 逻辑更新
- **WHEN** love.update被调用
- **THEN** 只执行游戏状态更新和输入处理
- **AND** 不执行任何渲染操作

#### Scenario: 画面渲染
- **WHEN** love.draw被调用
- **THEN** 只执行渲染操作
- **AND** 不修改游戏状态

### Requirement: 帧率控制
系统 SHALL 使用Love2D内置定时机制替代手动的lib.Delay()。

#### Scenario: 帧率控制
- **WHEN** 游戏运行
- **THEN** 使用love.timer.getDelta()获取帧间隔
- **AND** 保持原有游戏速度

### Requirement: 向后兼容
系统 SHALL 保持原有API行为不变，确保script/目录代码无需修改。

#### Scenario: API兼容
- **WHEN** 调用原有API(lib.DrawMMap, ShowScreen等)
- **THEN** 行为与重构前完全一致
- **AND** 事件脚本正常执行
