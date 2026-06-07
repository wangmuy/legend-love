# 架构：领域画布

## 有界上下文

| 领域 | 职责 | 主要文件 | 依赖 |
|------|------|----------|------|
| **engine-render** | 文字渲染、图形绘制、清屏 | `engine_api.lua`、`engine_love2d.lua`、`lib_love.lua` | Love2D graphics |
| **engine-sprite** | 贴图加载、绘制、动画 | `engine_api.lua`、`engine_love2d.lua`、`lib_love.lua` | Love2D graphics、RLE 数据 |
| **engine-map** | 地图瓦片渲染（主地图/场景/世界） | `engine_api.lua`、`engine_love2d.lua`、`lib_love.lua` | Love2D graphics、二进制数据 |
| **engine-input** | 键盘输入、按键映射 | `engine_api.lua`、`engine_love2d.lua`、`lib_love.lua` | Love2D 事件系统 |
| **engine-audio** | 音乐和音效 | `engine_api.lua`、`engine_love2d.lua`、`lib_love.lua` | Love2D audio |
| **engine-file** | 文件 I/O 抽象 | `engine_api.lua`、`engine_love2d.lua` | Love2D filesystem |
| **engine-font** | 字体加载和管理 | `engine_api.lua`、`engine_love2d.lua`、`lib_love.lua` | Love2D 字体系统 |
| **engine-color** | 颜色管理 | `engine_api.lua` | 无（纯表） |
| **engine-debug** | 调试/跟踪输出 | `engine_api.lua`、`lib_log.lua` | Love2D / stdout |
| **event-bridge** | 事件中枢，连接所有模块 | `event_bridge.lua` | 状态机、输入管理器、协程调度器、异步对话框 |
| **state-machine** | 游戏状态管理 | `state_machine.lua`、`game_states.lua` | 无（纯框架） |
| **input-manager** | 输入事件队列 | `input_manager.lua` | Love2D 键盘事件 |
| **coroutine** | 异步协程调度 | `coroutine_scheduler.lua` | 无（纯框架） |
| **async-menu** | 非阻塞菜单系统 | `menu_async.lua`、`menu_state_machine.lua` | 事件桥接、协程调度器、输入管理器 |
| **async-dialogue** | 非阻塞对话/消息框 | `talk_async.lua`、`async_dialog.lua`、`async_message_box.lua` | 事件桥接、协程调度器 |
| **async-battle** | 非阻塞战斗系统 | `war_async.lua` | 事件桥接、异步菜单、异步物品 |
| **async-item** | 非阻塞物品系统 | `item_async.lua` | 事件桥接、异步菜单 |
| **async-person** | 人物状态展示 | `person_status_async.lua` | 事件桥接 |
| **async-main** | 主菜单和游戏流程 | `jymain_async.lua` | 事件桥接、异步菜单 |
| **event-executor** | 旧版事件脚本执行 | `event_executor.lua`、`async_globals.lua` | 协程调度器、脚本加载器 |
| **game-scripts** | 旧版游戏脚本 | `script/jymain.lua`、`script/jyconst.lua`、`script/jymodify.lua` | EngineAPI、lib 全局变量 |
| **legacy-events** | 1018 个旧版事件脚本 | `script/oldevent/*.lua` | 全局 instruct_* 函数 |
| **binary-data** | 二进制文件 I/O | `lib_Byte.lua`、`lib_file.lua` | Love2D filesystem |
| **testing** | 单元测试基础设施 | `tests/test_runner.lua`、`tests/test_helper.lua`、`tests/unit/*.lua` | 框架模块（Mock） |
| **devops** | CI/CD 和构建工具 | `.github/workflows/`、`.github/actions/`、`tools/` | GitHub Actions、7z |

## 数据流拓扑

### 运行时（游戏）

```
love.keypressed()
  → InputManager:onKeyPressed()         [input-manager]
    → EventBridge:update()               [event-bridge]
      → StateMachine:update()            [state-machine]
        → GameState.update()             [如 GAME_MMAP]
          → CoroutineScheduler:update()  [coroutine]
            → 恢复等待中的协程
              → 异步封装收到按键 [async-*]
                → 游戏逻辑继续执行

love.update(dt)
  → JYMainAdapter:update(dt)            [async-main]
  → EventBridge.getInstance():update(dt) [event-bridge]
  → MenuAsync:update(dt)                [async-menu]

love.draw()
  → EventBridge.getInstance():draw()    [event-bridge]
  → MenuAsync:draw()                    [async-menu]

事件脚本执行：
EventExecutor.startEvent(id)
  → async_globals 安装全局替换
  → ScriptLoader.load("oldevent/oldevent_X.lua")
  → 在协程中执行
    → instruct_N(...) 调用异步封装
    → 协程在阻塞操作处 yield
    → CoroutineScheduler 恢复
```

### 构建（DevOps）

```
git push / workflow_dispatch
  → GitHub Actions: Build LÖVE
    → build-love：7z 打包 game/ → .love
    → build-android：.love → APK（debug 签名）
    → build-linux：.love → AppImage
    → build-windows：.love → ZIP
  → 构建产物上传
```

## 集成点

| 点 | 协议 | 参与者 |
|----|------|--------|
| EngineAPI ↔ Framework | 直接 Lua 函数调用 | `engine_api.lua`、通过 `lib` 全局的框架模块 |
| Framework ↔ Script | 全局函数调用 | 框架导出 `instruct_*`、`ShowMenu` 等 |
| 旧版事件 ↔ Framework | 动态 `loadstring` | `event_executor.lua` 加载 `oldevent/*.lua` |
| 输入 → Framework | 事件队列（表） | `input_manager.lua` 按键入队 → 由异步封装消费 |
| 状态机 → 调用者 | 回调表 | 每个状态的 `{enter, exit, update, draw}` |

## 全局约束

| 约束 | 详情 |
|------|------|
| 单线程 | 所有 Lua 代码在 Love2D 主线程上运行 |
| 帧绑定 | `update(dt)` 和 `draw()` 各自在一帧内完成 |
| 60 FPS 目标 | Love2D 默认，开启垂直同步 |
| 无并行执行 | 协程是协作式的，非抢占式 |
| 内存：约 200 MB | 游戏资源（地图、贴图、音频）按需加载 |