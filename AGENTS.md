# AGENTS.md - 金庸群侠传 Love2D 项目编码指南

本文档为 AI 智能体提供金庸群侠传 Love2D 项目的编码规范和工作指南。

## 项目概述

这是一个基于 Lua/Love2D 的经典国产 RPG 游戏《金庸群侠传》复刻版。
- **开发语言**: Lua 5.1+ (Love2D 框架)
- **支持平台**: 跨平台 (Linux, macOS, Windows)
- **文件编码**: UTF-8

## 当前任务：事件驱动架构迁移

本项目已完成从阻塞式同步流程到事件驱动架构的迁移。

**任务进度**: 参考 `openspec/changes/` 目录下的活动变更，以及 `openspec/changes/archive/` 下的已归档变更。

**架构文档**: 详见 [ARCHITECTURE.md](ARCHITECTURE.md) 和 [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)。

**文件清单**: 详见 [SRC_FILES.md](SRC_FILES.md)（src/ 目录文件分析）、[SCRIPT_FILES.md](SCRIPT_FILES.md)（script/ 脚本文件说明）和 [DATA_FILES.md](DATA_FILES.md)（data/ 目录数据文件说明）。

> **重要**: 以下文档内容以实际运行代码为准，文档可能与代码存在偏差，开发时请优先参考源码。

## 事件驱动架构

### 核心数据流

```
按键按下 → enqueueEvent(pressed) → 队列 → getKey() → 游戏逻辑
                                              ↑
定时器 → enqueueEvent(repeat) ────────────────┘
```

### 每帧流程

**love.update(dt)**:
1. `InputManager.update(dt)` - 处理按键重复
2. `CoroutineScheduler.update(dt)` - 恢复挂起的协程
3. `StateMachine.update(dt)` - 更新当前游戏状态

**love.draw()**:
1. `StateMachine.draw()` - 渲染当前状态
2. `MenuAsync.draw()` - 渲染活动菜单

## 文件组织结构

```
src/
├── main.lua                    # 程序入口
├── conf.lua                    # Love2D 配置
├── config.lua                  # 游戏配置 (CONFIG.*)
│
├── 核心模块 (事件驱动架构)
│   ├── event_bridge.lua        # 事件桥接器
│   ├── state_machine.lua       # 状态机
│   ├── game_states.lua         # 游戏状态处理器
│   ├── input_manager.lua       # 输入管理器 (事件队列)
│   ├── coroutine_scheduler.lua # 协程调度器
│   ├── menu_async.lua          # 异步菜单
│   ├── menu_state_machine.lua  # 菜单状态机
│   ├── talk_async.lua          # 异步对话
│   ├── war_async.lua           # 战斗系统
│   ├── jymain_async.lua        # 主菜单异步
│   └── jymain_adapter.lua      # 游戏适配器
│
├── 异步辅助模块
│   ├── input_async.lua         # 异步输入
│   ├── person_status_async.lua # 人物状态
│   ├── item_async.lua          # 物品系统
│   ├── async_dialog.lua        # 对话框管理
│   ├── async_message_box.lua   # 消息框
│   ├── async_globals.lua       # 全局函数替换
│   └── async_wrapper.lua       # 异步包装器
│
├── 事件执行
│   └── event_executor.lua      # 事件执行器
│
├── 工具模块
│   ├── lib_love.lua            # 图形/音频封装 (lib.*)
│   ├── lib_Byte.lua            # 二进制数据工具
│   ├── lib_log.lua             # 日志工具
│   └── luabit.lua              # 位运算库 (Lua 5.1 兼容)
│
├── 游戏逻辑
│   └── script/
│       ├── jymain.lua          # 主游戏逻辑
│       ├── jyconst.lua         # 常量和游戏数据
│       ├── jymodify.lua        # 游戏修改扩展
│       ├── oldevent/           # 事件脚本 (1018个)
│       └── newevent/           # 新增事件
│
├── data/                       # 数据文件 (贴图/地图/存档)
├── pic/                        # 图片资源
├── sound/                      # 音频资源
└── tests/                      # 单元测试
```

> 完整文件清单见 [SRC_FILES.md](SRC_FILES.md)。

## 构建/运行命令

```bash
love src/
# 调试输出: src/debug.txt
```

## 代码风格规范

### 命名规范

- **全局常量**: `UPPER_CASE` (例如: `VK_ESCAPE`, `GAME_MMAP`)
- **配置项**: `CONFIG.*` 前缀
- **游戏常量**: `CC.*` 前缀
- **游戏状态**: `JY.*` 前缀
- **函数名**: 公共函数 `CamelCase`，局部函数 `camelCase`

### 错误处理

- 使用 `lib.Debug()` 输出调试信息 (`CONFIG.Debug=1` 时写入 debug.txt)
- 对可能失败的操作使用 `pcall()`

### 缩进规范

- 使用 4 个空格缩进
- 行长度保持合理 (<120 字符)

### 协程开发注意事项 (war_async.lua)

`war_async.lua` 使用 local 函数定义协程，必须在文件开头添加前向声明：

```lua
-- 前向声明（只声明一次，避免重复）
local War_ManualCoroutine, War_AutoCoroutine, War_SettlementCoroutine
local War_AttackCoroutine, War_MoveCoroutine, SelectTargetCoroutine
-- ... 其他协程函数名
```

**添加新协程函数时**：
1. 先在前向声明行添加函数名
2. 再使用 `FunctionName = function()` 语法定义
3. 切勿使用 `local function FunctionName()` 语法（会导致声明顺序问题）

**错误示例**：
```lua
-- 错误：缺少前向声明
NewCoroutine = function()  -- 运行时报错：attempt read write to undeclared variable
    ...
end
```

**正确示例**：
```lua
-- 正确：先声明后定义
local NewCoroutine  -- 添加到前向声明
-- ...
NewCoroutine = function()
    ...
end
```

## 原版实现参考

```lua
-- 原版阻塞式循环
function JY_Main()
    while true do
        if JY.Status == GAME_MMAP then Game_MMap()
        elseif JY.Status == GAME_SMAP then Game_SMap() end
    end
end

-- 原版阻塞式按键等待
function WaitKey()
    while true do
        local key = lib.GetKey()
        if key ~= -1 then return key end
        lib.Delay(10)
    end
end
```

**屏幕状态**: `GAME_START`, `GAME_MMAP`, `GAME_SMAP`, `GAME_WMAP`, `GAME_END`

## 常见任务

- **添加 NPC 对话**: 在 `script/oldevent/` 创建文件
- **修改游戏数据**: 编辑 `script/jyconst.lua`
- **调试**: 检查 `src/debug.txt`
- **运行测试**: `cd src && lua tests/test_runner.lua`

## 单元测试

详见 [TESTING.md](TESTING.md)。

快速命令：
```bash
cd src && lua tests/test_runner.lua              # 运行所有测试
cd src && lua tests/test_runner.lua input_manager # 运行指定模块
```

## Spec 驱动开发

- 使用 OpenSpec，所有文档均使用中文
- 设置环境变量: `export OPENSPEC_TELEMETRY=0`