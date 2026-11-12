# 测试指南

本文档描述金庸群侠传 Love2D 项目的测试方法、结构和命令。

## 测试方法

项目采用纯 Lua 单元测试框架，不依赖外部测试库。

### 核心工具

| 工具 | 文件 | 用途 |
|------|------|------|
| 测试运行器 | `game/tests/test_runner.lua` | 运行所有或指定模块的测试 |
| 测试工具集 | `game/tests/test_helper.lua` | 提供断言、Mock、Spy、Stub 等工具 |
| 跨平台文件系统 | `game/framework/fs_compat.lua` | 目录/文件原语，屏蔽 Windows/Linux 差异（见「跨平台约定」） |

### 测试技术

- **断言函数**：`assertEquals`, `assertTrue`, `assertFalse`, `assertNotNil`, `assertNil`
- **Mock**：模拟 Love2D API、游戏数据（CC/JY/lib）
- **Spy/Stub**：监控和替换函数调用
- **模块重置**：确保测试间隔离

## 测试结构

```
game/tests/
├── test_runner.lua              # 测试运行器
├── test_helper.lua              # 测试工具集
└── unit/                        # 单元测试
    ├── test_state_machine.lua   # 状态机测试
    ├── test_input_manager.lua   # 输入管理器测试
    ├── test_event_bridge.lua    # 事件桥接测试
    ├── test_coroutine_scheduler.lua  # 协程调度器测试
    ├── test_byte_io.lua         # Byte I/O 测试
    ├── test_item_async.lua      # 物品系统测试
    ├── test_war_async.lua       # 战斗系统测试
    └── test_script_loader.lua   # 脚本加载器测试
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

### 前置条件

测试分两组，**非 MOD 组无需任何准备**即可跑：

| 组 | 依赖 | 说明 |
|----|------|------|
| 非 MOD 组 | 无 | 只依赖 `game/` 自身的代码与 `game/data/`（已在仓库中）|
| MOD 组 | `../reference/allmods/` + `game/mods/` | 两者都被 `.gitignore` 排除，**新克隆默认没有** |

`reference/allmods/` 是 20 个 MOD 的源数据（约 1.3 GB），获取与用法见
[MOD_20IN1_GUIDE.md](MOD_20IN1_GUIDE.md)。`game/mods/` 是构建产物，由源数据生成：

```bash
cd game && lua tools/mod_build.lua --all      # 约 2 分钟，产出 game/mods/<slug>/
```

缺这两个目录时，`test_runner.lua` 会在开头打印一段醒目的提示，列出缺失路径与
受影响的模块，其余模块照常运行（不会因为缺数据而崩在中途）。

### 运行所有测试

```bash
cd game && lua tests/test_runner.lua
```

### 运行单个模块测试

```bash
# 通过 test_runner
cd game && lua tests/test_runner.lua input_manager

# 直接运行测试文件
cd game && lua tests/unit/test_input_manager.lua
```

### 支持的 Lua 版本

三个版本下全量 2506 条断言全部通过，CI/本地任选其一：

```bash
cd game && lua5.1 tests/test_runner.lua   # 与运行时 LuaJIT 最接近
cd game && lua5.3 tests/test_runner.lua
cd game && lua5.4 tests/test_runner.lua
```

### 可用模块

`test_runner.lua <模块名>` 可单独运行下列模块（断言数合计 2506 条）：

| 模块名 | 覆盖内容 | 断言数 |
|--------|----------|--------|
| `state_machine` | 状态机 | 18 |
| `input_manager` | 输入管理器 | 38 |
| `event_bridge` | 事件桥接 | 18 |
| `coroutine_scheduler` | 协程调度器 | 12 |
| `byte_io` | Byte I/O | 38 |
| `script_loader` | 脚本加载器 | 6 |
| `item_async` | 物品系统 | 21 |
| `war_async` | 战斗系统 | 80 |
| `engine_api` | EngineAPI 接口定义 | 52 |
| `engine_test` | 测试引擎（MUD） | 18 |
| `mod_ini` | MOD ini 解析 | 81 |
| `mod_data` | MOD 数据回退 | 133 |
| `mod_encoding` | MOD 编码/布局逆向 | 55 |
| `mod_build` | MOD 构建期行为 | 52 |
| `mod_resources` | MOD 资源分类 | 739 |
| `mod_audit` | MOD 资源穷举审计 | 280 |
| `format_spec` | 数据格式字段级覆盖 | 297 |
| `mod_e2e` | MOD 无头端到端 | 37 |
| `mod_boot` | MOD 全启动链路无头验证 | 87 |
| `dialog_layout` | 对话自动换行/框宽 | 59 |
| `text_box_layout` | 单行文本框尺寸 | 102 |
| `mmap_depth` | 主地图 2.5D 遮挡关系 | 52 |
| `cloud` | 主地图飘云子系统 | 61 |

另有三个模块只在全量运行中执行（有顺序约束或依赖前面模块留下的全局状态，
未注册 `runModule` 分支）：`scene_name`（81，会 `LoadRecord` 并改 `JY` 全局）、
`font_size`（16）、`new_event`（73）。

## 跨平台约定（Windows / Linux / macOS）

测试与工具链必须在三个平台表现一致。以下约束是**强制**的，违反会让整套
MOD 相关测试在 Windows 上静默失败（历史上曾有 116 项断言因此在 Windows 上
恒失败，且报错信息全是「参考数据缺失」这类误导性文案）。

### 1. 文件系统操作一律走 `framework/fs_compat.lua`

**不要**在测试或 `tools/` 里写 `io.popen("ls ...")`、`os.execute("mkdir -p ...")`、
`io.popen("test -d ...")` 或 `find`/`md5sum`/`wc`。Windows 的 `io.popen`
走 `cmd.exe`，这些命令**全部不存在**，失败方式是安静地返回 `0`/`false`。

用 `fs_compat` 提供的原语：

| 需求 | 用法 |
|------|------|
| 目录是否存在 | `Fs.directoryExists(path)` |
| 列出条目名 | `Fs.listDirectory(path)` / `Fs.listEntries(path)`（带目录标记） |
| 列出匹配文件 | `Fs.listFiles(path, pattern)` |
| 递归列文件 | `Fs.walkFiles(path)` |
| 建/删目录 | `Fs.makeDirectory(path)` / `Fs.removeTree(path)` |
| 读/写文件 | `Fs.readFile(path)` / `Fs.writeFile(path, data)` |
| 临时目录 | `Fs.tempDir()` / `Fs.tempPath(name)` |
| 执行 POSIX 命令 | `Fs.runShell(cmd, {timeout=n})` |

### 2. 运行时（`game/framework`、`game/script`）不得直接碰文件系统

游戏必须通过 `EngineAPI.file.*`（→ `love.filesystem`），否则 `.love` 打包和
Android 下资源不可见。`fs_compat` **只**给「没有 love.filesystem」的环境用，
即单元测试与 `tools/`。

### 3. 临时文件不要写死 `/tmp`

用 `Fs.tempPath("xxx.bin")`（POSIX → `/tmp`，Windows → `%TEMP%`）。
`os.tmpname()` 在 Windows 上返回的是**当前盘符根目录**下的相对路径
（如 `\s9bk.`），会在仓库/盘符根留下垃圾文件，且清理时机不可控。

### 4. `io.open` 一律用二进制模式

`"wb"` / `"rb"`，**不要**用 `"w"` / `"r"`。Windows 文本模式会把 `\n` 改写成
`\r\n`：写 200 字节落盘 201 字节，读回时后半段整体错位。`TestHelper.mockEngineAPI`
已把 love 的 `"w"` 归一化为 `"w+b"`，但测试里直接调 `io.open` 的地方仍需自己注意。

### 5. Lua 版本

- **运行时** 是 LuaJIT（Lua 5.1 语法 + `goto` 扩展），必须保持 5.1 可解析。
- **测试** 在 Lua 5.1 / 5.3 / 5.4 下都应全绿（CI 无 lua5.3 时本地至少要过 5.3）。

因此禁止在**全仓**（含测试）使用这些 5.2+ 语法/库：

| 禁写 | 改用 |
|------|------|
| `a // b` | `math.floor(a / b)` |
| `goto continue` / `::label::` | `if ... then` 包一层，或抽成 `local function shouldSkip()` |
| `table.unpack` | `table.unpack or unpack` |
| `math.tointeger` | `if math.tointeger then ... end` 保护 |
| `"\xNN"` 十六进制转义 | 十进制 `"\NNN"`（5.1 会把 `"\xa1"` 静默解析成字面量 `"xa1"`）|
| 字符类 `[\0-\127]` | 逐字节 `for i=1,#s do s:byte(i) > 127` |

一条快捷自查（全仓 5.1 语法）：

```bash
cd game && find . -name '*.lua' -not -path './mods/*' -exec luac5.1 -p {} \;
```

### 6. 子进程传参不要带非 ASCII

Windows 的子进程参数要经过 `cmd.exe` 代码页转换（GBK ↔ UTF-8），
`"小蝦米"` 会变成 `"小蝦\uFFFD?2"`，断言凭空失败。需要传中文数据时，
改为传 slug/序号，由子进程**内部查表**（见 `tests/unit/boot_one_mod.lua`）。

### 7. 文件读写遇到非 ASCII 路径

Windows 版 PUC-Lua 的 `io.open` 按系统 ACP 解释路径，打不开 UTF-8 字面量
（MOD 源里有 `match - 复制.bin`、`不使用.png`）。`Fs.readFile` / `Fs.writeFile`
/ `Fs.fileExists` 已内置 PowerShell Unicode 桥接，只对**含非 ASCII** 的路径启用
（纯 ASCII 零开销）。所以**不要**绕开 `fs_compat` 直接 `io.open` 处理来自
`reference/allmods` 的文件名。

> 该桥接在 Windows 上会把握把子进程的 `LOCALAPPDATA` 指到临时目录，
> 避免 PowerShell 在仓库里生成 `Microsoft/ModuleAnalysisCache` 垃圾目录。

### 8. 目录列举的缓存语义

`fs_compat` 会缓存目录列举结果（11220 个文件全量遍历从分钟级降到秒级）。
任何**改动目录内容**的操作之后必须失效缓存：

- `Fs.writeFile` / `Fs.makeDirectory` / `Fs.removeTree` / `Fs.removeFile` 内部已自动失效；
- 若你用裸 `io.open`/`os.remove` 改了文件，需手动调 `Fs.invalidate(path)`；
- 跨测试切换工作目录时调 `Fs.clearCache()`。

## 测试覆盖范围

### 已覆盖模块

| 模块 | 测试重点 |
|------|----------|
| `state_machine` | 状态注册、切换、update/draw 回调 |
| `input_manager` | 按键事件队列、按键映射、disableInput 绕过 |
| `event_bridge` | 单例模式、状态注册、集成测试 |
| `byte_io` | SaveFromTable16/LoadToTable16、字节序、数据一致性 |
| `coroutine_scheduler` | 协程创建、yield/resume、waitForKey 绕过 disableInput |
| `item_async` | Grid物品选择、数组转换、药品/暗器过滤、必填字段验证 |
| `war_async` | 战斗状态初始化、移动范围计算、武功类型匹配、动画帧数、战斗地图操作、菜单返回值逻辑、用毒/解毒/医疗功能、物品菜单Grid显示、状态菜单协程版本、战败处理逻辑 |
| `mmap_depth` | 单趟按 `BuildingSort` 排序绘制（禁止改回先地形后建筑的两趟） |
| `cloud` | 60 朵云生成与字段范围、绘制坐标公式、40ms 漂移节奏、越界重生、`CC.MMapAmi` 门控、RLE + mix 公式逐位一致、云与地形滚动同步、槽位 39 上界 |

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

#### 物品系统测试场景

物品系统测试确保战斗场景中的物品选择使用Grid界面而非简单文字列表：

1. **Grid物品选择**：验证 `SelectThingByArrayAsync` 和 `SelectThingGridAsync` 函数存在
2. **数组转换**：验证 thing/thingnum 数组正确转换为 Grid items 格式
3. **药品/暗器过滤**：验证战斗物品菜单只显示类型 3（药品）和类型 4（暗器）
4. **必填字段**：验证 Grid items 包含 id, name, count, type, desc, user 字段
5. **空数组处理**：验证空物品列表返回 -1
6. **ESC取消处理**：验证 ESC 取消返回 7（继续菜单）而非 0（结束回合）

```lua
-- test_item_async.lua
function TestItemAsync.testGridDisplayNotSimpleTextMenu()
    local ItemAsync = require("item_async")
    
    -- 验证 Grid 显示函数存在（非简单文字菜单）
    local hasGridFunction = ItemAsync.SelectThingGridAsync ~= nil
    TestHelper.assertEquals(true, hasGridFunction, "ItemAsync should have SelectThingGridAsync function")
    
    local hasArrayFunction = ItemAsync.SelectThingByArrayAsync ~= nil
    TestHelper.assertEquals(true, hasArrayFunction, "ItemAsync should have SelectThingByArrayAsync function")
    
    local hasDrawFunction = ItemAsync.draw ~= nil
    TestHelper.assertEquals(true, hasDrawFunction, "ItemAsync should have draw function for Grid rendering")
end

-- test_war_async.lua
function TestWarAsync.testThingMenuFiltersMedicineAndAnqi()
    -- 验证物品过滤逻辑
    local filteredTypes = {3, 4}  -- 药品和暗器
    for i = 0, 5 do
        local thingType = JY.Thing[i]["类型"]
        for _, validType in ipairs(filteredTypes) do
            if thingType == validType then
                thing[num] = i
                thingnum[num] = 10
                num = num + 1
                break
            end
        end
    end
    
TestHelper.assertEquals(2, num, "Should filter to only medicine (3) and hidden weapon (4)")
end
```

#### 战败处理测试场景

战败处理测试确保战斗失败后根据 `isExp` 参数正确处理：

1. **游戏结束协程**：验证 `War_GameOverCoroutine` 存在
2. **isExp==1 普通战斗失败**：验证调用游戏结束流程
3. **isExp==0 练习战斗失败**：验证返回 false 继续对话

4. **返回值逻辑**：验证不同战斗类型的返回值

```lua
-- test_war_async.lua
function TestWarAsync.testGameOverCoroutineExists()
    local WarAsync = require("war_async")
    
    TestHelper.assertNotNil(WarAsync.War_GameOverCoroutine, "War_GameOverCoroutine should exist")
end

function TestWarAsync.testDefeatWithExpCallsGameOver()
    -- 普通战斗失败后应该调用游戏结束
    local isExp = 1
    local warStatus = 2  -- 失败
    
    local shouldCallGameOver = (warStatus == 2 and isExp == 1)
    TestHelper.assertEquals(true, shouldCallGameOver, "Normal battle defeat should call Game Over")
end

function TestWarAsync.testDefeatWithoutExpSkipsGameOver()
    -- 练习战斗失败后不应该调用游戏结束
    local isExp = 0
    local warStatus = 2  -- 失败
    
    local shouldSkipGameOver = (warStatus == 2 and isExp == 0)
    TestHelper.assertEquals(true, shouldSkipGameOver, "Practice battle defeat should skip Game Over")
end

function TestWarAsync.testPracticeBattleReturnsFalse()
    -- 模拟练习战斗失败后的处理逻辑
    local function simulatePracticeBattleDefeat(isExp, warStatus)
        if warStatus == 2 then
            if isExp == 0 then
                -- 练习战斗失败，返回false继续对话
                return false
            else
                -- 普通战斗失败，游戏结束
                return "game_over"
            end
        end
        return "other"
    end
    
    local result = simulatePracticeBattleDefeat(0, 2)
    TestHelper.assertEquals(false, result, "Practice battle should return false to continue dialogue")
    
    result = simulatePracticeBattleDefeat(1, 2)
    TestHelper.assertEquals("game_over", result, "Normal battle should trigger game_over")
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

1. 在 `game/tests/unit/` 创建 `test_<模块>.lua`
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

## 手动验证：主地图飘云

云子系统（`engine-love2d/lib_love.lua` 的 `Cloud*` / `DrawClouds`）除了单测，
还需要在真机上肉眼确认。下面是把「怎么才能看到云」整理出的操作手册——
云的可见性比直觉差很多，不看这节很容易以为「云没渲染」。

### 为什么出门经常看不到云

云世界是 17280×8640，屏幕只有 1024×768，60 朵云随机分布。实测：

* 单朵云落在视口内的概率 ≈ 6.7%(x) × 9.7%(y) ≈ **0.65%**，60 朵 ≈ **0.39 朵/屏**；
* 新游戏出门位置 (356,236) 原地不动：60 朵初始 **0 朵可见**，首次出现中位
  98.9s；
* 随机走动（每 0.32s 一格）：首次看到云中位 **10s**，75% 分位 28s，最慢 217s；
* 600s 长跑采样的 529 个网格点里**没有一个点完全看不到云**，但热点集中在
  `人X`、`人Y` 都较大且 `人X-人Y` 远离 0 的区域（y 方向只有约 9% 宽的世界带
  能落进视口，x 方向约 6.7%）。

**结论：云只在 `GAME_MMAP` / `GAME_FIRSTMMAP`（大地图）绘制，子场景 SMAP 没有云。**
等到云出现 ≠ 云没坏；要用下面的手段主动造场景。

### 推荐操作顺序

1. **显示坐标**：`game/script/jyconst.lua` 把 `CC.ShowXY` 改成 `1`
   （默认 0）。屏幕上会打印 `人X`/`人Y`，方便对照热点区域。
2. **进大地图**：新游戏 → 走出场景门（`GAME_SMAP → GAME_MMAP`）。
3. **持续按住 `↓` + `→`（右下对角线）**：实测最快，中位 5.7s 就看到云。
   其他方向：→ 13.7s、← 9.6s、↓ 8.1s、↑ 18.6s、左上对角线 11.9s。
4. **盯屏幕上半部分天空**：云从左侧向右飘（25～75 px/s，由 `Speedx=1..3`
   决定，40ms 一拍），半透明；过了 100 多秒会飘出左侧并在左侧重生。
5. **想确认「云只是慢」而不是「云没画」**：
   `game/script/jyconst.lua` 把 `CC.MMapAmi` 改成 `0`。云会**冻结但不会消失**，
   一直停在原位，肉眼更好确认。
6. **想验证渲染最快的方式**：临时把 `lib_love.lua` 的 `CLOUD_AMOUNT` 从 60
   改大。实测 200 → 59% 帧有云/3 朵可见；**600 → 100% 帧有云/5 朵可见**
   （加载 0.92s，`DrawClouds` 每帧 0.533ms，无性能问题）。测完**必须改回 60**——
   单测按 60 写死。

### 坑：没有调试热键

`game/main.lua:10` 只把 `keypressed` 转发给 `InputManager`，不在 keymap
（`framework/input_manager.lua`）里注册的键会被直接丢弃。想加 F1 之类必须先
改 keymap，别指望挂个回调就能用。

### 云相关的运行时取证脚本

肉眼之外的可复现取证见 [`tools/verify-cloud/`](tools/verify-cloud/README.md)：
`probe`（云在建筑之上）、`e2e`（真实启动链 + 漂移 + `MMAPAMI` 门控 + 云在主角
之上）、`scroll`（云与地形滚动一致性，含像素分析）。

> 这三个驱动早期放在 `game/tests/scratch_cloud_*` 并用相对软链引用
> `../../data` 等资源。**不要恢复那种做法**：`tools/build-love.sh` 与 CI 都用
> `7z a ./game/*` 打包，7z 会跟随软链，实测 `.love` 会从 31M 膨胀到 809M。