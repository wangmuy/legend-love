# 项目简介：金庸群侠传 Love2D

## 身份标识

| 字段 | 值 |
|------|-----|
| 产品名称 | 金庸群侠传 Lua 复刻版 |
| 内部名称 | jylegend |
| 产品 ID | wangmuy.love2d.jygame |
| UUID | e6af0e53-2cbc-44df-b952-6a9bb2fe6b86 |
| 起源 | 基于游泳的鱼的金庸群侠传 Lua 复刻版，UTF-8 编码 |
| 语言 | Lua 5.1+ |
| 框架 | LÖVE (Love2D) 11.5 |
| 平台 | Linux (AppImage), Windows (ZIP), Android (APK), .love |
| 仓库 | Private |

## 技术栈

- **运行时**: LÖVE 11.5 (Love2D)
- **语言**: Lua 5.1+（无外部 Lua 依赖，零依赖）
- **渲染**: Love2D 图形 API（SDL2 后端）
- **音频**: Love2D 音频 API
- **输入**: Love2D 键盘事件 → 内部事件队列
- **架构**: 事件驱动 + 基于协程的异步封装
- **测试**: 自研轻量级 Lua 测试框架（无 busted/luacov）
- **CI/CD**: GitHub Actions（Android APK debug、Linux AppImage、Windows ZIP）
- **构建**: 7z .love 打包，本地 build-love.sh 脚本

## 项目结构

```
game/
├── main.lua / conf.lua          # Love2D 入口
├── engine-love2d/               # EngineAPI Love2D 实现
│   ├── engine_api.lua           # 接口定义（11 模块，37 个函数）
│   ├── engine_love2d.lua        # EngineAPI → lib_love 桥接
│   └── lib_love.lua             # 原始 Love2D 图形/音频/输入封装
├── engine-mud/                  # MUD 文本引擎（初版）
│   └── engine_mud.lua
├── framework/                   # 引擎无关游戏框架
│   ├── event_bridge.lua         # 事件桥接器（单例）
│   ├── state_machine.lua        # 游戏状态机
│   ├── game_states.lua          # 状态定义
│   ├── input_manager.lua        # 输入事件队列
│   ├── coroutine_scheduler.lua  # 协程管理
│   ├── menu_async.lua           # 异步菜单系统
│   ├── war_async.lua            # 异步战斗系统
│   ├── talk_async.lua           # 异步对话系统
│   ├── item_async.lua           # 异步物品系统
│   ├── person_status_async.lua  # 异步人物状态
│   ├── async_dialog.lua         # 异步对话框
│   ├── async_message_box.lua    # 异步消息框
│   ├── async_globals.lua        # 全局函数替换
│   ├── event_executor.lua       # 事件脚本执行器
│   ├── jymain_adapter.lua       # JY_Main 适配器
│   ├── jymain_async.lua         # 主菜单异步版本
│   ├── lib_Byte.lua             # 二进制数据（RLE、字节缓冲）
│   ├── lib_file.lua             # 文件 I/O 抽象
│   ├── lib_log.lua              # 日志工具
│   ├── luabit.lua               # 位运算（Lua 5.1 兼容）
│   ├── perf_log.lua             # 性能日志
│   ├── config.lua               # CONFIG 配置表
│   └── script_loader.lua        # 脚本加载器（love.filesystem 封装）
├── script/
│   ├── jymain.lua               # 核心游戏逻辑
│   ├── jyconst.lua              # 常量和数据结构
│   ├── jymodify.lua             # 游戏修改/扩展
│   ├── oldevent/                # 1018 个旧版事件脚本
│   └── newevent/                # 新增事件脚本
├── data/ / pic/ / sound/        # 游戏资源
└── tests/
    ├── test_runner.lua          # 测试运行器
    ├── test_helper.lua          # 测试工具集（Mock、Spy、Stub）
    └── unit/                    # 10 个单元测试文件
```

## 已实现能力（来自 Spec）

| 领域 | 能力 | 状态 |
|------|------|------|
| 事件驱动 | 事件驱动架构（状态机、输入队列、协程调度器） | ✅ 已完成 |
| 事件驱动 | 所有核心游戏循环的阻塞→异步封装 | ✅ 已完成 |
| 异步菜单 | ShowMenu/ShowMenu2 协程版本 | ✅ 已完成 |
| 异步对话 | TalkExCoroutine 非阻塞对话 | ✅ 已完成 |
| 异步战斗 | 完整战斗系统协程版本（WarMainCoroutine） | ✅ 已完成 |
| 异步物品 | 基于 Grid 的物品选择、筛选、使用 | ✅ 已完成 |
| 异步人物 | 人物状态面板（支持翻页） | ✅ 已完成 |
| 引擎 API | EngineAPI 抽象层（11 模块，37 个函数） | ✅ 已完成 |
| 引擎 API | EngineAPI 的 Love2D 实现 | ✅ 已完成 |
| 引擎 API | MUD 测试引擎（初版） | ✅ 已完成 |
| 引擎 API | EngineAPI 事件驱动适配层 | ✅ 已完成 |
| CI/CD 构建 | GitHub Actions 多平台 CI/CD | ✅ 已完成 |
| CI/CD 构建 | 本地 .love 构建脚本 | ✅ 已完成 |
| CI/CD 构建 | product.env 构建配置 | ✅ 已完成 |
| CI/CD 构建 | 跨平台文件 I/O（lib_file.lua） | ✅ 已完成 |
| 测试框架 | 轻量级测试运行器 + 断言 | ✅ 已完成 |
| 测试工具 | Mock/Spy/Stub 测试工具集 | ✅ 已完成 |
| 测试工具 | Love2D API Mock、游戏数据 Mock | ✅ 已完成 |

## 进行中的变更

| 变更 | 领域 | 状态 |
|------|------|------|
| `setup-cicd-builds` | DevOps | 任务 1-7 已完成；剩余：git push、GitHub Secrets、CI 验证 |
| `improve-testability-and-add-unit-tests` | 测试 | 阶段 1-3 已完成；阶段 4（补充测试）为 TODO |

## 快速开始

```bash
# 运行游戏
love game/

# 运行测试
cd game && lua tests/test_runner.lua

# 构建 .love
./tools/build-love.sh
```

*最后自动推导：2026-06-07*