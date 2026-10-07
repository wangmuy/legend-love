# AGENTS.md - 金庸群侠传 Love2D 项目编码指南

本文档为 AI 智能体提供金庸群侠传 Love2D 项目的编码规范和工作指南。

## 项目概述

这是一个基于 Lua/Love2D 的经典国产 RPG 游戏《金庸群侠传》复刻版。
- **开发语言**: Lua 5.1+ (Love2D 框架)
- **支持平台**: 跨平台 (Linux, macOS, Windows)
- **文件编码**: UTF-8

## 当前任务：事件驱动架构迁移 + EngineAPI 抽象层

本项目已完成从阻塞式同步流程到事件驱动架构的迁移，并已完成 EngineAPI 抽象层的设计与实现。

**任务进度**: 参考 `openspec/changes/` 目录下的活动变更，以及 `openspec/changes/archive/` 下的已归档变更。

**架构文档**: 详见 [ARCHITECTURE.md](ARCHITECTURE.md) 和 [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)。

**EngineAPI 设计**: 详见 [ENGINE_API_DESIGN.md](ENGINE_API_DESIGN.md)（后续引擎实现与脚本事件驱动化计划）。

**文件清单**: 详见 [SRC_FILES.md](SRC_FILES.md)（game/ 目录文件分析）、[SCRIPT_FILES.md](SCRIPT_FILES.md)（script/ 脚本文件说明）和 [DATA_FILES.md](DATA_FILES.md)（data/ 目录数据文件说明）。

> **重要**: 以下文档内容以实际运行代码为准，文档可能与代码存在偏差，开发时请优先参考源码。

## EngineAPI 架构

EngineAPI 是 `game/script/` 与底层游戏引擎之间的抽象层，覆盖 11 个模块约 37 个函数。所有引擎操作通过 `EngineAPI.*` 或 `lib.*` 调用，`game/script/` 中的脚本不直接依赖任何引擎。

```
game/script/ (游戏逻辑)
    → instruct_0~67 / JY.* / CC.*
    → EngineAPI.* / lib.*

game/
├── engine-love2d/     ← Love2D 引擎实现（可整体替换）
│   ├── engine_api.lua     (接口定义)
│   ├── engine_love2d.lua  (EngineAPI 实现)
│   └── lib_love.lua       (原始 Love2D 实现)
│
├── engine-mud/        ← MUD 文本引擎（以 engine_test.lua 为初版）
│   └── engine_mud.lua
│
├── framework/         ← 引擎无关，只通过 EngineAPI 调用引擎
│   ├── 事件驱动: event_bridge / state_machine / game_states
│   ├── 异步: coroutine_scheduler / *_async / async_*
│   ├── 工具: lib_Byte / lib_file / lib_log / luabit / perf_log
│   └── config.lua / script_loader.lua / jymain_adapter.lua
│
├── script/            ← 游戏脚本（纯游戏逻辑）
│   ├── jymain.lua / jyconst.lua / jymodify.lua
│   ├── oldevent/ (1018个)
│   └── newevent/
│
├── main.lua           ← Love2D 入口（仅回调骨架）
├── conf.lua           ← Love2D 配置
└── tests/             ← 单元测试 + engine_test.lua
```

### 换引擎方式

1. 实现 `engine-xxx/engine_xxx.lua`，实现 EngineAPI 全部 37 个函数
2. 实现对应的 `main.lua` 入口（Love2D 用 `love.*` 回调，MUD 用 `main()`）
3. `framework/` 和 `script/` 完全不变

## 事件驱动架构

### 核心数据流

```
按键按下 → enqueueEvent(pressed) → 队列 → getKey() → 游戏逻辑
                                              ↑
定时器 → enqueueEvent(repeat) ────────────────┘
```

### 每帧流程

**love.update(dt)**:
1. `JYMainAdapter.update(dt)` - 游戏适配器更新
2. `EventBridge.getInstance():update(dt)` - 事件桥接器更新（包含输入管理、协程调度、状态机更新）
3. `MenuAsync.update(dt)` - 异步菜单更新

**love.draw()**:
1. `EventBridge.getInstance():draw()` - 渲染当前游戏状态
2. `MenuAsync.draw()` - 渲染活动菜单

## 文件组织结构

```
game/
├── main.lua                    # 程序入口 (Love2D 回调)
├── conf.lua                    # Love2D 配置
├── config.lua                  # 游戏配置 (CONFIG.*)
│
├── 核心模块 (事件驱动架构)
│   ├── event_bridge/           ← love2d-engine/framework/  // 已拆分
│
├── engine-love2d/              # Love2D 引擎实现
│   ├── engine_api.lua          # EngineAPI 接口定义
│   ├── engine_love2d.lua       # EngineAPI Love2D 实现
│   └── lib_love.lua            # 原始 Love2D 实现（被委托）
│
├── engine-mud/                 # MUD 文本引擎
│   └── engine_mud.lua
│
├── framework/                  # 引擎无关框架，只通过 EngineAPI 调用
│   ├── event_bridge.lua        # 事件桥接器
│   ├── state_machine.lua       # 状态机
│   ├── game_states.lua         # 游戏状态处理器
│   ├── input_manager.lua       # 输入管理器 (事件队列
│   ├── coroutine_scheduler.lua # 协程调度器
│   ├── menu_async.lua          # 异步菜单
│   ├── menu_state_machine.lua  # 菜单状态机
│   ├── talk_async.lua          # 异步对话
│   ├── war_async.lua           # 战斗系统
│   ├── jymain_async.lua        # 主菜单异步
│   ├── jymain_adapter.lua      # 游戏适配器
│   ├── person_status_async.lua # 人物状态
│   ├── item_async.lua          # 物品系统
│   ├── input_async.lua         # 异步输入
│   ├── async_dialog.lua        # 对话框管理
│   ├── async_message_box.lua   # 消息框
│   ├── async_globals.lua       # 全局函数替换
│   ├── async_wrapper.lua       # 异步包装器
│   ├── event_executor.lua      # 事件执行器
│   ├── lib_Byte.lua            # 二进制数据
│   ├── lib_file.lua            # 文件操作
│   ├── lib_log.lua             # 日志
│   ├── luabit.lua              # 位运算
│   ├── perf_log.lua            # 性能日志
│   ├── config.lua              # 游戏配置
│   └── script_loader.lua       # 脚本加载器
│
├── script/                     # 游戏脚本（纯游戏逻辑）
│   ├── jymain.lua              # 主游戏逻辑
│   ├── jyconst.lua             # 常量和游戏数据
│   ├── jymodify.lua            # 游戏修改扩展
│   ├── oldevent/               # 事件脚本 (1018个)
│   └── newevent/               # 新增事件
│
├── data/                       # 数据文件 (贴图/地图/存档)
├── pic/                        # 图片资源
├── sound/                      # 音频资源
└── tests/                      # 单元测试 + engine_test.lua
```

> **废弃文件**（不参与运行）：`event_coroutine.lua`, `instruct_async.lua`, `convert.lua`
> 完整文件清单见 [SRC_FILES.md](SRC_FILES.md)。

## 构建/运行命令

### 本地开发
```bash
# 直接运行（开发模式）
love game/

# 或使用本地构建的 .love 文件
./tools/build-love.sh
/home/woodfish/bin/love.AppImage builds/1/jylegend.love
```

### 调试输出
```
game/debug.txt
```

### CI/CD 构建
项目已配置 GitHub Actions 自动构建：
- Android APK (debug)
- Linux AppImage
- Windows ZIP
- LÖVE .love 文件

详见 `.github/workflows/build.yml`

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
- **调试**: 检查 `game/debug.txt`
- **运行测试**: `cd game && lua tests/test_runner.lua`

## 单元测试

详见 [TESTING.md](TESTING.md)。

快速命令：
```bash
cd game && lua tests/test_runner.lua              # 运行所有测试
cd game && lua tests/test_runner.lua input_manager # 运行指定模块
```

## Spec-Driven Development (MVP Multi-Scale)

本项目使用 **OpenSpec** 的 **MVP Multi-Scale Spec-Driven Development (SDD)** 系统。
当前 schema: `spec-driven-enhanced`（Blueprint 级）。

- 使用 OpenSpec，所有文档均使用中文
- 设置环境变量: `export OPENSPEC_TELEMETRY=0`

### 关键命令

| 命令 | 用途 |
|------|------|
| `/mvp:evaluate-scale` | 评估项目规模 + 引导初始化 |
| `/mvp:init-profile` | 创建 project-profile（治理规则、架构画布） |
| `/mvp:create-epic` | 创建 epic，包含垂直切片分解 |
| `/mvp:create-slice` | 创建 vertical-slice，自动搭建子 change 脚手架 |
| `/mvp:apply-slice` | 从 slice manifest 实现所有子 change |
| `/mvp:ingest` | 将外部文档摄入为 BDD shadow specs |
| `/mvp:reverse` | 从无文档代码逆向工程 spec |
| `/mvp:upgrade` | 升级项目规模（含验证门） |
| `/mvp:audit` | 扫描结构漂移（孤立条目、层级缺失） |
| `/mvp:organize` | 修复结构：合并条目或创建新容器 |
| `/opsx:explore` | 探索想法并固化为 proposal |
| `/opsx:propose` | 创建含完整产物的 change proposal |
| `/opsx:apply` | 实现 change 中的任务 |
| `/opsx:archive` | 归档已完成的 change |

### 产出物规范

| 产物 | 规范要求 |
|------|----------|
| **proposal** | 含 In Scope / Out of Scope、父上下文链接、[REQ-XXX] 跟踪 ID |
| **design** | 关键决策记作 ADR（Context/Decision/Alternatives/Consequences），含 Negative Constraints、Review Checklist |
| **specs** | 每个需求必有唯一 [REQ-XXX] ID，每个场景用 Given/When/Then 格式 |
| **tasks** | 每组任务包含 Blast Radius（允许的文件路径）和机器可验证的 DoD（Definition of Done） |

### 产物生命周期

Artifact 使用 YAML front matter 标记状态（status/created/abandoned）：

| 状态 | 含义 |
|------|------|
| `active` | 当前进行中 |
| `dormant` | 超过 60 天无活动 |
| `done` | 已完成（移至 archive/） |
| `abandoned` | 正式关闭，未完成（移至 abandoned/） |

### 目录结构

```
openspec/
├── config.yaml              # 项目配置 + schema 定义
├── WORKFLOW.md              # 完整工作流参考（zoom model、引导、操作手册）
├── project/
│   ├── profile.md            # 项目档案（治理规则、架构画布）
│   └── TODO.md               # 涌现想法跟踪
├── epics/
│   ├── <active-epic>/        # 活跃 | dormant
│   ├── archive/              # 已完成
│   └── abandoned/            # 放弃 | 废弃
├── changes/
│   ├── <active-change>/      # 活跃变更
│   ├── archive/              # 已完成
│   └── abandoned/            # 放弃 | 撤回
└── schemas/                  # schema 模板
```

### 参考文档

- `openspec/config.yaml` — 项目配置、schema 选择指南、启动检查清单
- `openspec/WORKFLOW.md` — 完整工作流定义（Front Matter、生命周期、Exploration、Triage）
- `openspec/changes/` — 活动变更和已归档变更
- `openspec/epics/` — 活动 epic

> **注意**：`openspec/config.yaml` 中的 `context` 字段包含完整的启动检查（项目引导、过时检查、TODO triage），AI 智能体应在每次会话开始时参考。