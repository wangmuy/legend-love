## Why

当前代码使用自定义的游戏循环(Game_Cycle)和阻塞式输入处理(GetKey)，这与Love2D的事件驱动架构不符。为了更好利用Love2D的特性(如love.update/love.draw回调)，提高代码可维护性和与现代Love2D版本的兼容性，需要将架构重构为事件驱动模式。

## What Changes

- **重构主循环**: 将自定义的`Game_Cycle()`循环改为Love2D标准的`love.update()`和`love.draw()`回调
- **输入处理改造**: 将阻塞式的`lib.GetKey()`改为事件驱动的`love.keypressed/keyreleased`回调
- **状态管理优化**: 使用状态机模式管理游戏状态(GAME_MMAP, GAME_SMAP等)
- **渲染分离**: 将游戏逻辑更新与渲染逻辑分离到不同回调中
- **帧率控制**: 使用Love2D内置的定时器替代手动的`lib.Delay()`帧率控制
- **保持向后兼容**: 不修改`script/`目录下的任何代码(包括oldevent/和newevent/)

## Capabilities

### New Capabilities
- `event-driven-architecture`: Love2D事件驱动架构实现，包含update/draw回调和事件处理
- `state-machine`: 游戏状态机管理，处理GAME_MMAP、GAME_SMAP等状态转换
- `input-event-handler`: 键盘输入事件处理器，替代阻塞式GetKey

### Modified Capabilities
- (无 - 此重构仅改变实现方式，不改变游戏逻辑和功能需求)

## Impact

- **修改文件**: `main.lua`, `lib_love.lua`, `script/jymain.lua`中的循环和输入相关代码
- **不修改文件**: `script/oldevent/`和`script/newevent/`目录下的所有事件脚本
- **依赖**: 需要Love2D 11.x版本支持
- **风险**: 需确保游戏逻辑和渲染效果与重构前完全一致

## 注意事项

### 测试策略

- **单元测试**: 为核心模块(状态机、输入管理器、事件桥接)编写单元测试代码，确保各组件独立工作正常
- **整体测试**: 由于游戏复杂性和UI交互特性，整体功能测试需要手动进行
- **日志调试**: 通过添加详细的日志输出与用户交流，协助定位和解决测试中发现的问题
- **测试反馈**: 用户在手动测试过程中发现问题时，通过日志文件反馈具体场景和现象
