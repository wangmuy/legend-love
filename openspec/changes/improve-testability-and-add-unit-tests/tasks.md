## 1. 轻量级代码改进

### 1.1 封装 lib.Debug 调用

- [x] 1.1.1 在 coroutine_scheduler.lua 中添加 _debug() 方法并替换所有 lib.Debug 调用
- [x] 1.1.2 在 menu_state_machine.lua 中添加 _debug() 方法并替换所有 lib.Debug 调用
- [x] 1.1.3 在 menu_async.lua 中添加 _debug() 方法并替换所有 lib.Debug 调用
- [x] 1.1.4 在 event_bridge.lua 中添加 _debug() 方法并替换所有 lib.Debug 调用
- [x] 1.1.5 运行现有测试验证改动

### 1.2 抽象时间源依赖

- [x] 1.2.1 在 coroutine_scheduler.lua 的 init() 中添加 timeSource 参数注入
- [x] 1.2.2 修改 waitForTime() 使用 self.timeSource 替代 love.timer.getTime
- [x] 1.2.3 运行现有测试验证改动

### 1.3 整理模块依赖

- [x] 1.3.1 检查 coroutine_scheduler.lua 中的 require 调用，将函数内的 require 移到模块顶部
- [x] 1.3.2 检查 menu_state_machine.lua 中的 require 调用
- [x] 1.3.3 检查 event_bridge.lua 中的 require 调用
- [x] 1.3.4 运行现有测试验证改动

## 2. 测试目录结构调整

### 2.1 创建测试目录结构

- [x] 2.1.1 创建 src/tests/ 目录
- [x] 2.1.2 创建 src/tests/unit/ 目录
- [x] 2.1.3 验证目录结构正确

### 2.2 移动现有测试文件

- [x] 2.2.1 将 src/test_runner.lua 移动到 src/tests/test_runner.lua
- [x] 2.2.2 将 src/test_state_machine.lua 移动到 src/tests/unit/test_state_machine.lua
- [x] 2.2.3 将 src/test_input_manager.lua 移动到 src/tests/unit/test_input_manager.lua
- [x] 2.2.4 将 src/test_event_bridge.lua 移动到 src/tests/unit/test_event_bridge.lua
- [x] 2.2.5 更新 test_runner.lua 中的 require 路径
- [x] 2.2.6 更新各测试文件中的 require 路径
- [x] 2.2.7 运行测试验证路径正确

### 2.3 清理旧文件

- [x] 2.3.1 删除 src/test_runner.lua（已移动）
- [x] 2.3.2 删除 src/test_state_machine.lua（已移动）
- [x] 2.3.3 删除 src/test_input_manager.lua（已移动）
- [x] 2.3.4 删除 src/test_event_bridge.lua（已移动）
- [x] 2.3.5 运行测试确保没有遗留引用

## 3. 创建测试工具集

### 3.1 创建 test_helper.lua

- [x] 3.1.1 创建 src/tests/test_helper.lua 文件框架
- [x] 3.1.2 实现 Love2D API Mock 功能（mockLoveTimer, mockLoveGraphics, mockLoveKeyboard, mockLove）
- [x] 3.1.3 实现游戏数据 Mock 功能（mockCC, mockJY, mockLib）
- [x] 3.1.4 实现模块重置工具（resetModule, resetAllModules, resetSingleton）
- [x] 3.1.5 实现 Spy 和 Stub 工具（stub, spy, wasCalled, wasCalledWith）
- [x] 3.1.6 实现测试数据工厂（createTestPerson, createTestThing, createTestMenu）
- [x] 3.1.7 添加断言函数（assertEquals, assertTrue, assertFalse）

### 3.2 改造现有测试

- [x] 3.2.1 改造 test_state_machine.lua 使用 test_helper
- [x] 3.2.2 改造 test_input_manager.lua 使用 test_helper
- [x] 3.2.3 改造 test_event_bridge.lua 使用 test_helper
- [x] 3.2.4 统一测试风格和命名规范
- [x] 3.2.5 运行所有测试验证通过

### 3.3 更新 test_runner.lua

- [x] 3.3.1 添加 test_helper 导入
- [x] 3.3.2 改进测试输出格式
- [x] 3.3.3 添加测试统计信息
- [x] 3.3.4 验证 test_runner 可以正常运行所有测试

## 4. 验证和文档

### 4.1 功能验证

- [x] 4.1.1 运行完整测试套件，确保所有测试通过
- [x] 4.1.2 启动游戏验证基本功能正常
- [x] 4.1.3 检查是否有遗漏的全局依赖

### 4.2 文档更新

- [x] 4.2.1 更新 AGENTS.md 添加测试运行说明
- [x] 4.2.2 在 tests/ 目录添加 README.md 说明测试结构
- [x] 4.2.3 添加测试编写指南

## 5. 后续 TODO（阶段 4）

### 5.1 新增核心模块测试

- [ ] 5.1.1 创建 test_coroutine_scheduler.lua
- [ ] 5.1.2 创建 test_menu_state_machine.lua
- [ ] 5.1.3 创建 test_async_message_box.lua
- [ ] 5.1.4 创建 test_async_dialog.lua

### 5.2 新增异步模块测试

- [ ] 5.2.1 创建 test_menu_async.lua
- [ ] 5.2.2 创建 test_talk_async.lua
- [ ] 5.2.3 创建 test_war_async.lua（简化版）

### 5.3 提高测试覆盖率

- [ ] 5.3.1 为核心业务逻辑添加测试
- [ ] 5.3.2 为工具函数添加测试
- [ ] 5.3.3 评估是否需要集成测试

### 5.4 CI/CD 集成

- [ ] 5.4.1 研究 luacov 覆盖率工具
- [ ] 5.4.2 配置 GitHub Actions 自动运行测试
- [ ] 5.4.3 添加测试覆盖率报告
