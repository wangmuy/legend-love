## Why

新游戏开始时，主角从躺着到坐起到站起来的动画（instruct_27）在事件驱动架构中无法显示。原版使用阻塞循环+直接绘制的方式，在事件驱动架构中需要改为异步方式。

## What Changes

- 分析原版 `instruct_27` 的工作原理
- 设计事件驱动架构下的动画显示方案
- 实现动画状态管理，让 `love.draw` 驱动动画帧
- 确保动画期间 `DrawSMap` 能正确读取动画贴图

## Capabilities

### New Capabilities
- `animation-system`: 事件驱动架构下的动画系统

### Modified Capabilities
- `event-execution`: 修改事件执行流程，支持动画显示

## Impact

- **script/jymain.lua**: 修改 `instruct_27` 函数
- **lib_love.lua**: 可能需要修改 `DrawSMap` 或添加动画支持
- **async_globals.lua**: 可能需要修改 `ShowScreen` 或 `lib.Delay`
- **game_states.lua**: 可能需要修改 `GAME_SMAP.draw` 支持动画
