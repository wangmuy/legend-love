## Why

当前项目已完成事件驱动架构迁移，但缺乏系统的单元测试保障。现有测试分散在 src/ 目录下，使用简单的自定义框架，存在以下问题：

1. **全局依赖难以 Mock**：代码中直接调用 `lib.Debug()` 和 `love.*` API，测试时需要修改全局状态
2. **测试目录结构混乱**：测试文件与源码混在一起，不利于维护
3. **测试覆盖率不足**：仅测试了 3 个核心模块，大量业务逻辑缺乏测试
4. **缺乏测试工具**：没有统一的 Mock 工具和测试辅助函数

通过轻量级代码重构和测试框架改进，建立可持续的测试体系，确保事件驱动架构的稳定性和可维护性。

## What Changes

### 阶段 1：轻量级代码改进
- **封装全局依赖**：将 `lib.Debug()` 调用封装为模块内部方法，便于测试时 Mock
- **抽象时间源**：将 `love.timer.getTime()` 提取为可注入的依赖
- **整理模块依赖**：将函数内部的 `require()` 移到模块顶部，提高代码可预测性

### 阶段 2：测试目录重构
- **新建 tests/ 目录**：在 src/ 下创建专门的测试目录
- **移动现有测试**：将 `test_*.lua` 文件移动到 `src/tests/unit/`
- **创建测试工具**：新增 `test_helper.lua` 提供 Mock 工具和公共函数

### 阶段 3：改造现有测试
- **统一测试风格**：使用一致的命名和断言风格
- **提取公共逻辑**：使用 test_helper 减少重复代码
- **改进测试隔离**：确保每个测试之间状态完全重置

### 阶段 4：新增单元测试（后续 TODO）
- 为 `coroutine_scheduler.lua` 添加完整测试
- 为 `menu_state_machine.lua` 添加测试
- 为 `async_message_box.lua` 等异步模块添加测试
- 逐步提高核心业务逻辑的测试覆盖率

## Capabilities

### New Capabilities
- `test-framework`: 轻量级单元测试框架，包含测试运行器、Mock 工具和断言函数
- `test-helpers`: 测试辅助工具集，提供 Love2D API Mock、游戏数据 Mock 和模块重置功能

### Modified Capabilities
- 无（本次变更主要是代码结构改进和测试基础设施，不修改现有功能需求）

## Impact

### 受影响的文件
- `src/coroutine_scheduler.lua` - 封装 lib.Debug 调用，抽象时间源
- `src/state_machine.lua` - 检查并优化依赖
- `src/input_manager.lua` - 检查并优化依赖
- `src/menu_state_machine.lua` - 检查并优化依赖
- `src/event_bridge.lua` - 检查并优化依赖

### 新增的文件
- `src/tests/test_runner.lua` - 从根目录移动并改造
- `src/tests/test_helper.lua` - 测试工具集
- `src/tests/unit/*.lua` - 单元测试文件

### 删除的文件
- `src/test_runner.lua` - 移动到 tests/ 目录
- `src/test_state_machine.lua` - 移动到 tests/unit/
- `src/test_input_manager.lua` - 移动到 tests/unit/
- `src/test_event_bridge.lua` - 移动到 tests/unit/

### 开发工作流变化
- 运行测试：`cd src && lua tests/test_runner.lua`
- 运行单个模块测试：`cd src && lua tests/unit/test_state_machine.lua`
