## Why

当前 `game/script/` 目录下的游戏脚本通过 `lib_love.lua` 间接依赖 Love2D 引擎，`jymain.lua` 中还有 3 处直接调用 `love.filesystem`。这使得后续替换引擎（如 Love2D → Godot）需要修改脚本代码。需要定义一套固定的 Lua API 接口（EngineAPI），将脚本与引擎解耦，使得替换引擎时只需为新引擎实现 EngineAPI，脚本无需修改。

## What Changes

- 定义 `EngineAPI` 接口规范（约 37 个函数，覆盖渲染/输入/音频/文件/计时等 11 个类别）
- 从 `lib_love.lua` 重构出 `engine_love2d.lua`，实现 EngineAPI 接口
- 创建 `engine_test.lua`，实现 EngineAPI 的命令行测试版本（无窗口/无音频/模拟输入）
- 修改 `jymain.lua` 中 3 处 `love.filesystem` 直接调用，改为 `EngineAPI.file.*`
- 修改 `script_loader.lua` 使用 `EngineAPI.script.load`
- 重构 `async_globals.lua` 为 EngineAPI 的标准协程适配层
- 标记 EngineAPI 中的 yieldable 函数（`waitForKey`、`sleep` 等），作为事件驱动契约
- 现有 1018 个 oldevent 脚本和 newevent 脚本**无需修改**

## Capabilities

### New Capabilities
- `engine-api-interface`: EngineAPI 接口定义，包含 render/sprite/map/input/audio/time/file/script/font/color/debug/coroutine 共 11 个模块的约 37 个函数签名
- `engine-love2d`: Love2D 引擎实现，从 lib_love.lua 重构，实现全部 EngineAPI 接口
- `engine-test`: 命令行测试引擎实现，无窗口/无音频/模拟输入，用于 CI/CD 和单元测试
- `event-driven-adapter`: 基于 EngineAPI yieldable 函数的事件驱动适配层，重构 async_globals.lua

### Modified Capabilities

无（新增能力，不修改现有 spec）

## Impact

- `game/lib_love.lua`：重构为 `engine_love2d.lua`，接口不变但内部实现改为实现 EngineAPI
- `game/script/jymain.lua`：3 处 `love.filesystem` 调用改为 `EngineAPI.file.*`
- `game/script_loader.lua`：使用 `EngineAPI.script.load` 替代 `love.filesystem.load`
- `game/async_globals.lua`：基于 EngineAPI yieldable 函数重构
- `game/config.lua`：路径配置保持，移除引擎特定设置
- 新增 `game/engine_api.lua`（接口定义）
- 新增 `game/engine_test.lua`（测试引擎）
- 新增 `game/engine_love2d.lua`（Love2D 实现）
- 所有 oldevent/newevent 脚本：无影响