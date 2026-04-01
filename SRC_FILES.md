# src/ 目录文件分析

本文档记录 `src/` 直接目录下各个文件的使用情况和作用。

---

## 入口文件

| 文件 | 使用状态 | 作用 |
|------|----------|------|
| `main.lua` | ✅ 使用中 | Love2D 主入口，定义 `love.load/update/draw/quit` 回调，加载配置和核心模块，初始化事件桥接器和游戏逻辑适配器 |
| `conf.lua` | ✅ 使用中 | Love2D 配置回调，设置窗口大小、标题、版本号、模块开关等 |

---

## 核心模块（事件驱动架构）

| 文件 | 使用状态 | 作用 |
|------|----------|------|
| `event_bridge.lua` | ✅ 使用中 | 事件桥接器，单例模式。连接新旧架构，整合状态机、输入管理器、协程调度器、异步对话框。提供 `update/draw` 统一调用入口，注册 Love2D 按键回调 |
| `state_machine.lua` | ✅ 使用中 | 游戏状态机，管理 GAME_MMAP/GAME_SMAP/GAME_WMAP 等状态的注册、切换、子状态栈和历史栈 |
| `game_states.lua` | ✅ 使用中 | 游戏状态处理器定义，实现各状态（GAME_START, GAME_MMAP, GAME_SMAP, GAME_WMAP, GAME_END, GAME_DEAD, GAME_FIRSTMMAP, GAME_FIRSTSMAP）的 enter/exit/update/draw 逻辑 |
| `input_manager.lua` | ✅ 使用中 | 输入管理器，事件队列驱动的按键处理。替代阻塞式 GetKey，支持按键重复、按键状态查询、disableInput 标志 |
| `coroutine_scheduler.lua` | ✅ 使用中 | 协程调度器，管理协程的创建/启动/恢复/yield。提供 waitForKey/waitForTime/waitForCondition 等阻塞式协程API |
| `menu_async.lua` | ✅ 使用中 | 异步菜单模块，提供非阻塞的 ShowMenu/ShowMenu2 及其协程版本，依赖 menu_state_machine |
| `menu_state_machine.lua` | ✅ 使用中 | 菜单状态机，管理菜单的打开/关闭/导航/选择状态和渲染 |
| `talk_async.lua` | ✅ 使用中 | 异步对话模块，提供协程版本的 TalkExCoroutine/TalkCoroutine，支持分页对话显示 |
| `war_async.lua` | ✅ 使用中 | 战斗系统异步模块，提供完整战斗流程的协程版本（WarMainCoroutine、手动/自动战斗、攻击、移动、用毒、解毒、医疗、物品等） |
| `jymain_async.lua` | ✅ 使用中 | 游戏主菜单异步版本，实现 MMenuCoroutine（主菜单）、系统子菜单、医疗/解毒/物品/状态/离队等功能 |
| `jymain_adapter.lua` | ✅ 使用中 | JY_Main 适配器，连接新旧架构。负责游戏初始化流程、开始菜单、新游戏属性选择、存档读取 |

---

## 异步辅助模块

| 文件 | 使用状态 | 作用 |
|------|----------|------|
| `input_async.lua` | ✅ 使用中 | 异步输入函数封装，提供 WaitKeyCoroutine、WaitKeyTimeout、WaitForKey 等协程版本输入函数 |
| `person_status_async.lua` | ✅ 使用中 | 异步人物状态显示模块，在 draw 中渲染状态面板，协程中等待按键翻页/切换人物 |
| `item_async.lua` | ✅ 使用中 | 异步物品系统，提供物品分类选择（Grid 形式）、物品使用（剧情/装备/秘籍/药品/暗器）的协程版本 |
| `async_dialog.lua` | ✅ 使用中 | 异步对话框管理器，支持 YesNo/Input/Select/Message 四种对话框类型，带堆栈管理 |
| `async_message_box.lua` | ✅ 使用中 | 异步消息框封装层，提供 ShowMessageCoroutine/ShowYesNoCoroutine 便捷函数 |
| `async_globals.lua` | ✅ 使用中 | 全局函数替换模块，在事件脚本执行前安装，将阻塞函数（WaitKey/ShowMenu/TalkEx/lib.Delay 等）替换为异步版本 |
| `async_wrapper.lua` | ✅ 使用中 | 异步函数包装器，提供全局可用的异步函数集合 |

---

## 事件执行模块

| 文件 | 使用状态 | 作用 |
|------|----------|------|
| `event_executor.lua` | ✅ 使用中 | 事件执行器，提供协程版本的事件执行入口（EventExecuteCoroutine/EventExecuteSync），负责加载和执行 oldevent/*.lua 事件脚本 |
| `event_coroutine.lua` | ⚠️ 未使用 | 事件脚本协程执行器（旧版），提供 instruct 函数包装。已被 event_executor.lua 替代，当前无文件引用 |
| `instruct_async.lua` | ⚠️ 未使用 | 事件指令的协程版本，为所有 instruct_XXX 函数提供非阻塞版本。当前无文件引用，功能已被 async_globals.lua + event_executor.lua 的组合替代 |
| `instruct_async.lua` | ⚠️ 未使用 | 事件指令的协程版本，为所有 instruct_XXX 函数提供非阻塞版本。当前无文件引用，功能已被 async_globals.lua + event_executor.lua 的组合替代 |

---

## 工具模块

| 文件 | 使用状态 | 作用 |
|------|----------|------|
| `lib_love.lua` | ✅ 使用中 | Love2D 图形/音频封装库。封装贴图加载/显示（RLE/PNG）、地图绘制（DrawMMap/DrawSMap/DrawWarMap）、音频播放、字体渲染、按键映射等 |
| `lib_Byte.lua` | ✅ 使用中 | 二进制数据工具，提供字节序转换（byte2sshortl/byte2uintl 等）、16位/8位数据表读写、Byte 数组操作 |
| `lib_log.lua` | ✅ 使用中 | 日志工具，提供 Debug/Debugt/JY_Error 函数，输出到 debug.txt |
| `luabit.lua` | ✅ 使用中 | LuaBit 位运算库（Lua 5.1 兼容），提供 band/bor/bxor/bnot/brshift/blshift 等位操作。在 Lua 5.2+ 环境下不需要 |
| `config.lua` | ✅ 使用中 | 游戏配置文件，定义 CONFIG 表（分辨率、路径、音量、缓存、刷新方式等） |
| `convert.lua` | ❌ 未使用 | 数据格式转换工具，将原版 Big5 编码的 R3.grp/R3.idx 数据文件转换为 UTF-8 格式。仅用于一次性数据迁移，运行时不需要 |

---

## 目录结构

| 目录/文件 | 说明 |
|-----------|------|
| `data/` | 游戏数据文件目录 |
| `pic/` | 贴图资源目录 |
| `sound/` | 音频资源目录 |
| `script/` | 游戏脚本目录（含 jymain.lua、jyconst.lua、oldevent/ 等） |
| `tests/` | 单元测试目录 |
| `simsun.ttf` | 宋体字体文件 |
| `debug.txt` | 运行时调试日志输出文件 |

---

## 统计

- **使用中**: 26 个文件
- **未使用**: 3 个文件（`event_coroutine.lua`、`instruct_async.lua`、`convert.lua`）
- **总计**: 29 个 .lua 文件
