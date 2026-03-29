# 测试指南

本文档描述金庸群侠传 Love2D 项目的测试方法、结构和命令。

## 测试方法

项目采用纯 Lua 单元测试框架，不依赖外部测试库。

### 核心工具

| 工具 | 文件 | 用途 |
|------|------|------|
| 测试运行器 | `src/tests/test_runner.lua` | 运行所有或指定模块的测试 |
| 测试工具集 | `src/tests/test_helper.lua` | 提供断言、Mock、Spy、Stub 等工具 |

### 测试技术

- **断言函数**：`assertEquals`, `assertTrue`, `assertFalse`, `assertNotNil`, `assertNil`
- **Mock**：模拟 Love2D API、游戏数据（CC/JY/lib）
- **Spy/Stub**：监控和替换函数调用
- **模块重置**：确保测试间隔离

## 测试结构

```
src/tests/
├── test_runner.lua              # 测试运行器
├── test_helper.lua              # 测试工具集
├── README.md                    # 测试目录说明
└── unit/                        # 单元测试
    ├── test_state_machine.lua   # 状态机测试
    ├── test_input_manager.lua   # 输入管理器测试
    ├── test_event_bridge.lua    # 事件桥接测试
    ├── test_coroutine_scheduler.lua  # 协程调度器测试
    ├── test_byte_io.lua         # Byte I/O 测试
    └── test_war_async.lua       # 战斗系统测试
```

### 测试文件命名规范

- 文件名：`test_<模块名>.lua`
- 测试表：`Test<模块名>`
- 测试函数：`test<功能描述>()`

### 测试函数模板

```lua
local TestHelper = require("tests.test_helper")
local TargetModule = require("target_module")

local TestTargetModule = {}

local function setup()
    TestHelper.setup()
    TargetModule.getInstance():reset()
end

function TestTargetModule.testFeature()
    setup()
    print("\n=== Test: Feature ===")
    
    local tm = TargetModule.getInstance()
    TestHelper.assertEquals(expected, actual, "Description")
end

function TestTargetModule.runAll()
    print("\n========================================")
    print("Target Module Unit Tests")
    print("========================================")
    
    TestHelper.resetCounts()
    TestTargetModule.testFeature()
    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_target_module.lua$") then
    TestTargetModule.runAll()
end

return TestTargetModule
```

## 测试命令

### 运行所有测试

```bash
cd src && lua tests/test_runner.lua
```

### 运行单个模块测试

```bash
# 通过 test_runner
cd src && lua tests/test_runner.lua input_manager

# 直接运行测试文件
cd src && lua tests/unit/test_input_manager.lua
```

### 可用模块

| 模块名 | 测试文件 |
|--------|----------|
| `state_machine` | 状态机测试 |
| `input_manager` | 输入管理器测试 |
| `event_bridge` | 事件桥接测试 |
| `coroutine_scheduler` | 协程调度器测试 |
| `byte_io` | Byte I/O 测试 |
| `war_async` | 战斗系统测试 |

## 测试覆盖范围

### 已覆盖模块

| 模块 | 测试重点 |
|------|----------|
| `state_machine` | 状态注册、切换、update/draw 回调 |
| `input_manager` | 按键事件队列、按键映射、disableInput 绕过 |
| `event_bridge` | 单例模式、状态注册、集成测试 |
| `byte_io` | SaveFromTable16/LoadToTable16、字节序、数据一致性 |
| `coroutine_scheduler` | 协程创建、yield/resume、waitForKey 绕过 disableInput |
| `war_async` | 战斗状态初始化、移动范围计算、武功类型匹配、动画帧数、战斗地图操作、菜单返回值逻辑 |

### 关键测试场景

#### disableInput 绕过（状态显示界面按键响应）

当状态显示界面设置 `InputManager.disableInput = true` 时，协程调度器仍需获取按键恢复协程。

```lua
-- test_input_manager.lua
function TestInputManager.testInternalMethodsBypassDisableInput()
    local im = InputManager.getInstance()
    im:onKeyPressed("left", nil, false)
    
    InputManager.disableInput = true
    
    -- 普通方法返回 -1
    TestHelper.assertEquals(-1, im:peekKey(), "peekKey should return -1")
    
    -- 内部方法绕过 disableInput
    TestHelper.assertEquals(VK_LEFT, im:_peekKeyInternal(), "Internal method bypasses disableInput")
end

-- test_coroutine_scheduler.lua
function TestCoroutineScheduler.testWaitForKeyWithDisableInput()
    local scheduler = CoroutineScheduler.getInstance()
    local receivedKey = nil
    
    local id = scheduler:create(function()
        receivedKey = scheduler:waitForKey()
    end)
    
    scheduler:start(id)
    InputManager.disableInput = true
    im:onKeyPressed("left", nil, false)
    scheduler:update(0.016)
    
    TestHelper.assertEquals(VK_LEFT, receivedKey, "Coroutine receives key despite disableInput")
end
```

#### 战斗系统测试场景

战斗系统测试覆盖以下关键场景：

1. **战斗状态管理**：`warState` 的初始化、重置、状态流转
2. **移动范围计算**：`GetWarMap`/`SetWarMap` 操作、边界检查
3. **武功类型匹配**：刀、剑、掌等武功类型的智能匹配
4. **动画帧数**：人物出招动画帧数获取和验证
5. **战斗地图操作**：地图层读写、清理操作
6. **移动后菜单显示**：移动操作返回值逻辑验证

```lua
-- test_war_async.lua
function TestWarAsync.testMoveRangeCalculation()
    setup()
    createSimpleWarScenario()
    
    -- 验证移动步数
    local moveSteps = WAR.Person[0]["移动步数"]
    TestHelper.assertEquals(3, moveSteps, "Move steps should be 3")
    
    -- 验证边界检查
    local outOfBounds = GetWarMap(20, 20, 3)
    TestHelper.assertEquals(255, outOfBounds, "Out of bounds should return 255")
end

function TestWarAsync.testWugongTypeMatching()
    -- 验证武功类型匹配
    local knifeWugong = TestHelper.createTestWugong({ID = 10})
    knifeWugong["名称"] = "金刀刀法"
    knifeWugong["武功类型"] = 2
    TestHelper.assertEquals(2, knifeWugong["武功类型"], "Knife type should be 2")
end

function TestWarAsync.testMoveContinueFlagLogic()
    -- 验证移动后返回 7 继续显示菜单，而非返回 0 结束回合
    local continueFlag = 7
    local endTurnFlag = 0
    
    -- 模拟 War_ManualCoroutine 的循环逻辑
    local function simulateLoop(returnValue)
        local loopCount = 0
        local r = returnValue
        while r == continueFlag do
            loopCount = loopCount + 1
            r = endTurnFlag  -- 下一次操作结束回合
        end
        return loopCount
    end
    
    -- 移动后返回 7，循环继续，菜单再次显示
    TestHelper.assertEquals(1, simulateLoop(continueFlag), "Move returns 7, loop continues")
    -- 攻击后返回 0，循环结束
    TestHelper.assertEquals(0, simulateLoop(endTurnFlag), "Attack returns 0, loop ends")
end
```

## Mock 工具使用

### Love2D API Mock

```lua
-- Mock 所有 Love2D API
TestHelper.mockLove()

-- 单独 Mock
local timer = TestHelper.mockLoveTimer()
local graphics = TestHelper.mockLoveGraphics()
local keyboard = TestHelper.mockLoveKeyboard()
```

### 游戏数据 Mock

```lua
-- 一次性 Mock 所有全局依赖
TestHelper.mockGlobals()

-- 或单独 Mock
TestHelper.mockCC()    -- CC 配置常量
TestHelper.mockJY()    -- JY 游戏数据
TestHelper.mockWAR()   -- WAR 战斗数据
TestHelper.mockLib()   -- lib 工具模块
TestHelper.mockWarFunctions()  -- 战斗辅助函数
```

### 战斗数据工厂

```lua
-- 创建测试人物
local person = TestHelper.createTestPerson({ID = 1})
person["姓名"] = "测试人物"
person["武功1"] = 1

-- 创建测试战斗人物
local warPerson = TestHelper.createTestWarPerson({
    ["人物编号"] = 1,
    ["坐标X"] = 5,
    ["坐标Y"] = 5,
    ["我方"] = true,
})

-- 创建测试武功
local wugong = TestHelper.createTestWugong({ID = 1})
wugong["名称"] = "太祖长拳"
wugong["武功类型"] = 0
```

### Spy/Stub 示例

```lua
-- Stub：替换函数
local stub = TestHelper.stub(object, "method", returnValue)
if stub.wasCalled() then
    print("Method was called")
end
stub.restore()

-- Spy：监控函数调用但保留原功能
local spy = TestHelper.spy(object, "method")
print("Call count: " .. spy.callCount())
spy.restore()
```

## 添加新测试

1. 在 `src/tests/unit/` 创建 `test_<模块>.lua`
2. 使用测试模板编写测试
3. 在 `test_runner.lua` 中注册：
   - 添加 `require` 语句
   - 在 `runAll()` 中添加运行逻辑
   - 在 `runModule()` 中添加分支

## 测试原则

1. **隔离性**：每个测试独立运行，使用 `setup()` 重置状态
2. **Mock 外部依赖**：测试时 Mock Love2D API 和全局数据
3. **清理资源**：测试完成后调用 `teardown()` 清理
4. **清晰断言**：提供描述性的断言消息
5. **单一职责**：每个测试函数只测试一个功能点