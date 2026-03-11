## ADDED Requirements

### Requirement: 统一状态机管理所有游戏状态
系统 SHALL 使用统一的状态机管理所有游戏状态。

#### Scenario: 状态注册
- **WHEN** 注册新状态
- **THEN** 状态被添加到状态机
- **AND** 状态处理器被保存

#### Scenario: 状态切换
- **WHEN** 切换到新状态
- **THEN** 调用旧状态的exit处理器
- **AND** 调用新状态的enter处理器
- **AND** 当前状态更新为新状态

#### Scenario: 状态更新
- **WHEN** 每帧更新
- **THEN** 调用当前状态的update处理器
- **AND** 传递delta time参数

#### Scenario: 状态渲染
- **WHEN** 每帧渲染
- **THEN** 调用当前状态的draw处理器

### Requirement: 状态支持子状态
系统 SHALL 支持状态内的子状态管理。

#### Scenario: 进入子状态
- **WHEN** 进入子状态
- **THEN** 父状态暂停
- **AND** 子状态开始更新和渲染

#### Scenario: 退出子状态
- **WHEN** 退出子状态
- **THEN** 子状态清理
- **AND** 恢复父状态

### Requirement: 状态支持数据传递
系统 SHALL 支持状态间传递数据。

#### Scenario: 状态切换传参
- **WHEN** 切换到新状态
- **THEN** 可以传递参数给新状态
- **AND** 新状态的enter处理器接收参数

#### Scenario: 状态返回传参
- **WHEN** 从状态返回
- **THEN** 可以传递返回值
- **AND** 父状态接收返回值
