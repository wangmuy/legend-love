## Why

当前代码使用阻塞式循环（ShowMenu、WaitKey等）处理用户输入，这与Love2D的事件驱动架构不兼容。阻塞式循环会阻止love.update和love.draw的正常执行，导致无法充分利用Love2D的渲染和事件系统。为了彻底解决这个问题，需要将所有阻塞式代码重构为非阻塞的事件驱动代码。

## What Changes

- **完全重构主循环**: 移除所有阻塞式while循环，改为Love2D标准的事件驱动模式
- **重写菜单系统**: 将ShowMenu、ShowMenu2等函数改为状态机模式，支持非阻塞渲染
- **重写输入等待**: 将WaitKey、GetKey等函数改为事件驱动，移除lib.Delay阻塞
- **重构对话框系统**: 将所有对话框（DrawStrBoxYesNo、ShowPersonStatus等）改为非阻塞式
- **重写游戏状态机**: 使用统一的状态机管理所有游戏状态（菜单、地图、战斗、对话框等）
- **重构事件脚本**: 将oldevent中的阻塞式事件处理改为协程或回调模式
- **添加帧率控制**: 使用Love2D的定时器替代手动的lib.Delay
- **保持向后兼容**: 确保script/目录下的游戏逻辑代码无需修改

## Capabilities

### New Capabilities
- `event-driven-menu`: 事件驱动菜单系统，支持非阻塞渲染和输入
- `non-blocking-dialog`: 非阻塞对话框系统，支持异步交互
- `coroutine-events`: 基于协程的事件脚本执行系统
- `unified-state-machine`: 统一的游戏状态机，管理所有游戏状态
- `async-input`: 异步输入处理系统，替代WaitKey阻塞调用

### Modified Capabilities
- (无 - 此重构改变实现方式，不改变游戏功能需求)

## Impact

- **修改文件**: main.lua, lib_love.lua, script/jymain.lua中所有阻塞式函数
- **不修改文件**: script/oldevent/和script/newevent/目录下的游戏逻辑脚本
- **依赖**: 需要Love2D 11.x版本支持
- **风险**: 重构工作量大，需要全面测试确保行为一致性
- **工作量**: 预计需要重写20+个阻塞式函数，涉及约2000行代码
