# 单元测试

本目录包含金庸群侠传 Love2D 项目的单元测试。

## 目录结构

```
tests/
├── test_runner.lua          # 测试运行器
├── test_helper.lua          # 测试工具集
├── README.md                # 本文件
└── unit/                    # 单元测试
    ├── test_state_machine.lua
    ├── test_input_manager.lua
    ├── test_event_bridge.lua
    └── test_coroutine_scheduler.lua
```

## 运行测试

### 运行所有测试

```bash
cd src
lua tests/test_runner.lua
```

### 运行单个模块测试

```bash
cd src
lua tests/unit/test_state_machine.lua
```

### 从 test_runner 运行特定模块

```bash
cd src
lua tests/test_runner.lua state_machine
```

可用模块：`state_machine`, `input_manager`, `event_bridge`, `coroutine_scheduler`

## 测试工具 (test_helper.lua)

### 断言函数

- `TestHelper.assertEquals(expected, actual, message)` - 相等断言
- `TestHelper.assertTrue(value, message)` - 真值断言
- `TestHelper.assertFalse(value, message)` - 假值断言
- `TestHelper.assertNotNil(value, message)` - 非 nil 断言
- `TestHelper.assertNil(value, message)` - nil 断言

### Mock 工具

#### Love2D API Mock

```lua
-- Mock 所有 Love2D API
TestHelper.mockLove()

-- 或单独 Mock
TestHelper.mockLoveTimer()
TestHelper.mockLoveGraphics()
TestHelper.mockLoveKeyboard()
```

#### 游戏数据 Mock

```lua
TestHelper.mockCC()    -- CC 配置
TestHelper.mockJY()    -- JY 游戏数据
TestHelper.mockLib()   -- lib 模块

-- 或一次性 Mock 所有
TestHelper.mockGlobals()
```

#### 模块重置

```lua
TestHelper.resetModule("module_name")      -- 重置单个模块
TestHelper.resetAllModules()                -- 重置所有测试相关模块
TestHelper.resetSingleton(module)           -- 重置单例实例
```

### Spy 和 Stub

```lua
-- Stub（替换函数，不执行原函数）
local stub = TestHelper.stub(object, "methodName", returnValue)
stub.wasCalled()           -- 检查是否被调用
stub.getCalls()            -- 获取调用记录
stub.restore()             -- 恢复原函数

-- Spy（包装函数，记录调用但执行原函数）
local spy = TestHelper.spy(object, "methodName")
spy.wasCalled()            -- 检查是否被调用
spy.wasCalledWith(arg1, arg2)  -- 检查是否以特定参数被调用
spy.callCount()            -- 获取调用次数
spy.restore()              -- 恢复原函数
```

### 测试数据工厂

```lua
-- 创建测试人物
local person = TestHelper.createTestPerson({
    ID = 1,
    姓名 = "测试人物",
    生命 = 100
})

-- 创建测试物品
local thing = TestHelper.createTestThing({
    ID = 1,
    名称 = "测试物品"
})

-- 创建测试菜单
local menu = TestHelper.createTestMenu({
    {"选项1", nil, 1},
    {"选项2", nil, 1}
})
```

### 测试生命周期

```lua
-- 测试前初始化
function setup()
    TestHelper.setup()  -- 重置计数、Mock 全局、重置模块
    -- 额外初始化...
end

-- 测试后清理
function teardown()
    TestHelper.teardown()  -- 清理全局 Mock
end
```

## 编写新测试

### 基本模板

```lua
-- test_new_module.lua
-- 新模块单元测试

local TestHelper = require("tests.test_helper")
local NewModule = require("new_module")

local TestNewModule = {}

-- 测试前重置
local function setup()
    TestHelper.setup()
    NewModule.getInstance():reset()
end

-- 测试1: 基本功能
function TestNewModule.testBasic()
    setup()
    print("\n=== Test: Basic Functionality ===")
    
    local nm = NewModule.getInstance()
    
    -- 测试代码...
    TestHelper.assertEquals(expected, actual, "Description")
end

-- 运行所有测试
function TestNewModule.runAll()
    print("\n========================================")
    print("New Module Unit Tests")
    print("========================================")
    
    TestHelper.resetCounts()
    
    TestNewModule.testBasic()
    -- 添加更多测试...
    
    return TestHelper.printSummary()
end

-- 如果直接运行此文件
if arg and arg[0]:match("test_new_module.lua$") then
    TestNewModule.runAll()
end

return TestNewModule
```

### 添加到 test_runner

在 `test_runner.lua` 中添加：

```lua
local TestNewModule = require("tests.unit.test_new_module")

-- 在 runAll() 中添加：
print("\n" .. string.rep("-", 60))
print("运行新模块测试...")
print(string.rep("-", 60))
TestHelper.resetCounts()
local nmResult = TestNewModule.runAll()
local nmStats = TestHelper.getStats()
totalStats.total = totalStats.total + nmStats.total
totalStats.passed = totalStats.passed + nmStats.passed
totalStats.failed = totalStats.failed + nmStats.failed
allPassed = allPassed and nmResult

-- 在 runModule() 中添加：
elseif moduleName == "new_module" then
    return TestNewModule.runAll()
```

## 注意事项

1. **测试隔离**：每个测试应该独立运行，使用 `setup()` 重置状态
2. **Mock 依赖**：测试时应该 Mock 外部依赖（Love2D API、全局数据）
3. **清理资源**：测试完成后使用 `teardown()` 清理
4. **命名规范**：测试函数以 `test` 开头，描述测试内容
5. **断言消息**：提供清晰的断言失败消息

## 测试覆盖率

当前测试覆盖的模块：

- ✅ state_machine.lua
- ✅ input_manager.lua
- ✅ event_bridge.lua
- ✅ coroutine_scheduler.lua

待添加测试的模块：

- menu_state_machine.lua
- menu_async.lua
- async_message_box.lua
- async_dialog.lua
- talk_async.lua
- war_async.lua
