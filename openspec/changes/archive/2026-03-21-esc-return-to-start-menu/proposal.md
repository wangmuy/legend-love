## Why

在重新开始游戏的属性选择界面，用户目前无法通过ESC键返回到开始菜单。这不符合玩家的操作习惯，当用户误操作选择"重新开始"后，应该能够通过ESC键返回开始菜单重新选择，而不是强制进行属性选择或关闭游戏。

## What Changes

- **修改菜单系统**：为属性选择菜单添加ESC键支持，允许用户返回到开始菜单
- **重构新游戏流程**：将 `startNewGame` 函数改为支持中途返回的机制
- **添加状态管理**：在开始菜单和属性选择之间建立可回退的状态流转
- **保持事件驱动架构**：所有修改严格遵循事件驱动架构原则，使用协程和状态机

## Capabilities

### New Capabilities
- `menu-esc-navigation`: 支持ESC键导航和返回的菜单系统能力

### Modified Capabilities
- `new-game-flow`: 修改新游戏流程，支持从属性选择返回到开始菜单

## Impact

- **jymain_adapter.lua**: 重构 `startNewGame` 函数，添加返回机制
- **menu_state_machine.lua**: 修改ESC键处理逻辑
- **menu_async.lua**: 支持带ESC返回的菜单协程
- **event_bridge.lua**: 可能需要的全局状态管理
