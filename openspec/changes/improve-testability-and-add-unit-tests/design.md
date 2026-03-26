## Context

当前项目已完成从阻塞式架构到事件驱动架构的迁移，核心模块包括：

- **状态机** (`state_machine.lua`)：管理游戏状态流转
- **输入管理器** (`input_manager.lua`)：事件驱动的输入处理
- **协程调度器** (`coroutine_scheduler.lua`)：管理异步协程
- **事件桥接器** (`event_bridge.lua`)：连接新旧架构
- **异步菜单** (`menu_async.lua`, `menu_state_machine.lua`)：非阻塞菜单系统

现有测试使用简单的自定义框架，分散在 src/ 目录下，仅覆盖了 3 个核心模块。代码中存在以下可测试性问题：

1. **全局依赖硬编码**：`lib.Debug()`, `love.timer.getTime()` 等直接调用
2. **模块级状态**：单例模式使用模块级局部变量，虽然可以通过 `reset()` 清理，但依赖关系不清晰
3. **测试目录混乱**：测试文件与源码混在一起

## Goals / Non-Goals

**Goals:**
- 通过轻量级重构提升代码可测试性，不改动业务逻辑
- 建立清晰的测试目录结构
- 创建可复用的测试工具集（Mock、辅助函数）
- 改造现有测试，统一风格和标准
- 为后续全面测试覆盖打下基础

**Non-Goals:**
- 不引入外部测试框架（如 busted），保持零依赖
- 不修改业务逻辑行为
- 不追求 100% 测试覆盖率（这是阶段 4 的目标）
- 不重构整体架构（仅轻量级改进）

## Decisions

### 1. 保持自定义测试框架

**决策**：继续使用现有的简单测试框架，不引入 busted 等外部框架。

**理由**：
- 现有框架已能满足基本需求
- 避免增加外部依赖
- 项目团队熟悉当前模式

**替代方案**：引入 busted 框架，提供更丰富的断言和测试组织方式。

### 2. 使用依赖注入而非全局 Mock

**决策**：通过模块级依赖和构造函数注入，而非运行时修改全局变量。

**示例**：
```lua
-- 改进前：直接调用
function CoroutineScheduler:waitForTime(seconds)
    local startTime = love.timer.getTime()
    ...
end

-- 改进后：注入时间源
function CoroutineScheduler:init(deps)
    deps = deps or {}
    self.timeSource = deps.timeSource or love.timer.getTime
end

function CoroutineScheduler:waitForTime(seconds)
    local startTime = self.timeSource()
    ...
end
```

**理由**：
- 更清晰的依赖关系
- 测试时可以注入 Mock，无需修改全局状态
- 不破坏现有 API（通过默认参数保持兼容）

**替代方案**：运行时替换全局 `_G.love.timer.getTime`，但会污染全局状态。

### 3. 封装 lib.Debug 调用

**决策**：在每个模块中封装 `lib.Debug()` 调用为内部方法 `_debug()`。

**示例**：
```lua
function CoroutineScheduler:_debug(msg)
    if lib and lib.Debug then
        lib.Debug(msg)
    end
end

-- 使用时
self:_debug("coroutine started")
```

**理由**：
- 测试时可以轻松 Mock `_debug()` 方法
- 避免到处检查 `if lib and lib.Debug`
- 集中日志逻辑，便于后续扩展

### 4. 测试目录结构

**决策**：采用 `src/tests/` 结构，而非 `tests/` 放在根目录。

**结构**：
```
src/
├── tests/
│   ├── test_runner.lua       # 测试运行器
│   ├── test_helper.lua       # 测试工具
│   └── unit/                 # 单元测试
│       ├── test_state_machine.lua
│       ├── test_input_manager.lua
│       ├── test_event_bridge.lua
│       └── test_coroutine_scheduler.lua
```

**理由**：
- 测试代码与源码在同一目录树下，便于相对路径引用
- 符合 Lua 模块加载习惯
- 与 Love2D 项目结构兼容

**替代方案**：根目录 `tests/`，但需要更复杂的模块路径处理。

### 5. 渐进式测试添加

**决策**：阶段 4（新增测试）作为后续 TODO，不在本次变更中完成。

**理由**：
- 保持变更范围可控
- 先建立测试基础设施，再逐步添加测试
- 避免一次改动过多文件

## Risks / Trade-offs

### [风险] 重构引入回归缺陷

虽然本次重构是轻量级的，但任何代码改动都有引入缺陷的风险。

**缓解措施**：
- 改造现有测试后立即运行，确保通过
- 每个模块改动后验证游戏能正常启动
- 小步提交，便于回滚

### [风险] 依赖注入增加复杂度

为模块添加依赖注入参数可能使 API 稍微复杂。

**缓解措施**：
- 使用默认参数保持向后兼容
- 仅在必要时（如测试）传入自定义依赖
- 文档说明清楚

### [权衡] 不引入外部测试框架

**优点**：零依赖，简单，团队熟悉
**缺点**：缺少高级功能（测试套件组织、丰富的断言、覆盖率报告）

**结论**：当前阶段可接受，未来如需更复杂功能再考虑引入。

## Migration Plan

### 实施步骤

1. **阶段 1：代码改进**
   - 逐个修改核心模块，封装 `lib.Debug()` 和抽象时间源
   - 每次修改后运行现有测试验证

2. **阶段 2：目录调整**
   - 创建 `src/tests/` 目录结构
   - 移动现有测试文件
   - 更新模块引用路径

3. **阶段 3：测试改造**
   - 创建 `test_helper.lua`
   - 改造现有测试使用 helper
   - 统一测试风格

4. **验证**
   - 运行所有测试确保通过
   - 启动游戏验证基本功能正常

### 回滚策略

- 每个阶段独立提交，可单独回滚
- 保留原始测试文件备份，直到新测试稳定
- 如发现问题，优先回滚代码改动，保留目录结构调整

## Open Questions

1. **是否需要测试覆盖率工具？**
   - 当前：不需要，保持简单
   - 未来：可考虑 luacov

2. **CI/CD 集成？**
   - 当前：手动运行测试
   - 未来：GitHub Actions 自动运行

3. **异步模块的测试策略？**
   - 需要进一步探索协程测试的最佳实践
   - 可能需要专门的异步测试工具
