## ADDED Requirements

### Requirement: 横向菜单支持ESC键返回
当菜单的 `isEsc` 参数设置为1时，系统 SHALL 支持用户按ESC键取消菜单操作并返回特殊值。

#### Scenario: 用户按ESC键取消菜单
- **WHEN** 菜单正在显示且 `isEsc == 1`
- **AND** 用户按下ESC键
- **THEN** 菜单关闭并返回特殊值（0或特定标识）
- **AND** 调用方的协程接收到返回值并处理返回逻辑

### Requirement: ShowMenu2Coroutine支持ESC返回
`MenuAsync.ShowMenu2Coroutine` 函数 SHALL 在 `isEsc == 1` 时，支持通过ESC键取消操作并返回特殊值。

#### Scenario: 属性选择时按ESC返回
- **WHEN** 调用 `MenuAsync.ShowMenu2Coroutine` 且 `isEsc == 1`
- **AND** 菜单显示属性选择的"是/否"选项
- **AND** 用户按下ESC键
- **THEN** 函数返回特殊值（如-1）
- **AND** 调用方（startNewGame）检测到特殊值并返回到开始菜单

## MODIFIED Requirements

无（此为新功能，不涉及修改现有需求）
