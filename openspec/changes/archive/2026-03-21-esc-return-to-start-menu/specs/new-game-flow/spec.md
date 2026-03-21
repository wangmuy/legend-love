## MODIFIED Requirements

### Requirement: 新游戏流程支持返回到开始菜单
`startNewGame` 函数 SHALL 支持在属性选择阶段通过ESC键返回到开始菜单。

#### Scenario: 属性选择时按ESC返回开始菜单
- **WHEN** 用户在属性选择界面
- **AND** 用户按下ESC键
- **THEN** 系统返回到开始菜单状态
- **AND** 清理属性选择相关的资源（绘制回调等）

#### Scenario: 正常确认属性继续游戏
- **WHEN** 用户在属性选择界面
- **AND** 用户选择"是"确认属性
- **THEN** 系统继续新游戏流程
- **AND** 进入场景地图状态

## ADDED Requirements

### Requirement: 属性选择菜单启用ESC支持
属性选择菜单 SHALL 设置 `isEsc = 1`，允许用户按ESC键返回。

#### Scenario: 显示属性选择菜单
- **WHEN** 系统显示属性选择菜单
- **THEN** 菜单的 `isEsc` 参数设置为1
- **AND** 用户可以通过ESC键取消操作
