# game/ 目录文件分析

本文档记录 `game/` 目录下各个文件的使用情况和作用。

---

## 入口文件

| 文件 | 使用状态 | 作用 |
|------|----------|------|
| `main.lua` | ✅ 使用中 | Love2D 主入口，定义 `love.load/update/draw/quit` 回调，加载配置和核心模块，初始化事件桥接器和游戏逻辑适配器 |
| `conf.lua` | ✅ 使用中 | Love2D 配置回调，设置窗口大小、标题、版本号、模块开关等 |

---

## 引擎层 (engine-love2d/)

| 文件 | 使用状态 | 作用 |
|------|----------|------|
| `engine_api.lua` | ✅ 使用中 | EngineAPI 接口定义（11 模块，37 个函数签名），引擎无关 |
| `engine_love2d.lua` | ✅ 使用中 | EngineAPI Love2D 实现，委托 lib_love.lua，设置 `lib` 全局变量 |
| `lib_love.lua` | ✅ 使用中 | 原始 Love2D 图形/音频封装。封装贴图加载/显示（RLE/PNG）、地图绘制、音频播放、字体渲染、按键映射等 |

---

## 引擎层 (engine-mud/)

| 文件 | 使用状态 | 作用 |
|------|----------|------|
| `engine_mud.lua` | ⚠️ 初版 | MUD 文本引擎，以 engine_test.lua 为初版，尚未实现文本交互逻辑 |

---

## 框架层 (framework/)

| 文件 | 使用状态 | 作用 |
|------|----------|------|
| `event_bridge.lua` | ✅ 使用中 | 事件桥接器，单例模式。连接新旧架构，整合状态机、输入管理器、协程调度器、异步对话框 |
| `state_machine.lua` | ✅ 使用中 | 游戏状态机，管理状态注册、切换、子状态栈和历史栈 |
| `game_states.lua` | ✅ 使用中 | 游戏状态处理器定义，实现各状态的 enter/exit/update/draw 逻辑 |
| `input_manager.lua` | ✅ 使用中 | 输入管理器，事件队列驱动的按键处理。替代阻塞式 GetKey |
| `coroutine_scheduler.lua` | ✅ 使用中 | 协程调度器，管理协程的创建/启动/恢复/yield |
| `input_async.lua` | ✅ 使用中 | 异步输入函数封装，提供 WaitKeyCoroutine 等协程版本 |
| `menu_async.lua` | ✅ 使用中 | 异步菜单模块，提供非阻塞的 ShowMenu/ShowMenu2 及其协程版本 |
| `menu_state_machine.lua` | ✅ 使用中 | 菜单状态机，管理菜单的打开/关闭/导航/选择状态和渲染 |
| `talk_async.lua` | ✅ 使用中 | 异步对话模块，提供协程版本的 TalkExCoroutine/TalkCoroutine |
| `war_async.lua` | ✅ 使用中 | 战斗系统异步模块，提供完整战斗流程的协程版本 |
| `jymain_async.lua` | ✅ 使用中 | 游戏主菜单异步版本 |
| `jymain_adapter.lua` | ✅ 使用中 | JY_Main 适配器，连接新旧架构 |
| `item_async.lua` | ✅ 使用中 | 异步物品系统 |
| `person_status_async.lua` | ✅ 使用中 | 异步人物状态显示模块 |
| `async_dialog.lua` | ✅ 使用中 | 异步对话框管理器 |
| `async_message_box.lua` | ✅ 使用中 | 异步消息框封装层 |
| `async_globals.lua` | ✅ 使用中 | 全局函数替换模块，在事件脚本执行前安装 |
| `install()` |
| `async_wrapper.lua` | ✅ 使用中 | 异步函数包装器 |
| `event_executor.lua` | ✅ 使用中 | 事件执行器，加载和执行 oldevent/*.lua 事件脚本 |

---

## 工具模块 (framework/)

| 文件 | 使用状态 | 作用 |
|------|----------|------|
| `lib_Byte.lua` | ✅ 使用中 | 二进制数据工具，提供字节序转换、16位/8位数据表读写 |
| `lib_file.lua` | ✅ 使用中 | 文件操作封装，提供跨平台的文件读写接口 |
| `lib_log.lua` | ✅ 使用中 | 日志工具，提供 Debug/Debugt/JY_Error 函数 |
| `luabit.lua` | ✅ 使用中 | LuaBit 位运算库（Lua 5.1 兼容） |
| `perf_log.lua` | ✅ 使用中 | 性能日志模块 |
| `config.lua` | ✅ 使用中 | 游戏配置文件，定义 CONFIG 表 |
| `script_loader.lua` | ✅ 使用中 | 脚本加载器，封装 love.filesystem.load 和 loadfile |

---

## 目录结构

| 目录/文件 | 说明 |
|-----------|------|
| `engine-love2d/` | Love2D 引擎实现 |
| `engine-mud/` | MUD 文本引擎（预留） |
| `framework/` | 引擎无关框架代码 |
| `script/` | 游戏脚本目录（含 jymain.lua、jyconst.lua、oldevent/ 等） |
| `data/` | 游戏数据文件目录 |
| `pic/` | 图片资源目录 |
| `sound/` | 音频资源目录 |
| `tests/` | 单元测试目录（含 engine_test.lua） |

---

## 统计

- **使用中**: 31 个 .lua 文件
- **废弃已删**: `event_coroutine.lua`、`instruct_async.lua`、`convert.lua`