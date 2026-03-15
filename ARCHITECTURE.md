# 金庸群侠传 Love2D 完全事件驱动架构文档

## 架构概述

本项目采用完全事件驱动的架构，所有阻塞式代码都已改造为协程版本，实现流畅的游戏体验。

## 核心模块

### 1. 协程调度器 (coroutine_scheduler.lua)
- 管理所有协程的创建、启动、暂停和恢复
- 提供 waitForKey()、waitForTime()、waitForCondition() 等等待功能
- 支持协程错误处理和状态查询
- 每帧自动更新所有挂起的协程

### 2. 状态机 (state_machine.lua)
- 统一管理游戏状态（GAME_MMAP、GAME_SMAP、GAME_WMAP、GAME_START等）
- 支持子状态嵌套
- 支持状态间数据传递
- **自动同步 JY.Status**
- **支持状态历史记录，战斗结束后返回之前状态**

### 3. 输入管理器 (input_manager.lua)
- 集中处理所有键盘输入
- 支持输入缓冲和按键重复
- 提供消费模式和非消费模式
- 与 Love2D 事件系统集成

### 4. 异步对话框 (async_dialog.lua)
- 非阻塞的对话框显示
- 支持消息框、确认框、输入框、选择框
- **提供协程版本 showMessageCoroutine、showYesNoCoroutine**
- 支持对话框堆叠和动画

### 5. 异步菜单 (menu_async.lua + menu_state_machine.lua)
- 非阻塞的 ShowMenu/ShowMenu2
- 支持菜单嵌套和动画
- **提供协程版本 ShowMenuCoroutine、ShowMenu2Coroutine**

### 6. 对话系统 (talk_async.lua)
- 非阻塞的 TalkEx 对话显示
- 支持分页、头像显示
- 自动分行处理

### 7. 战斗系统 (war_async.lua)
- 战斗主循环改造为协程版本
- **WarMainCoroutine 战斗入口函数**
- 所有战斗菜单（攻击、移动、物品等）协程版本
- 战斗动画、自动战斗协程版本

### 8. 事件指令系统 (instruct_async.lua)
- 所有 67 个 instruct_XXX 函数的协程版本
- 替换所有阻塞调用为异步版本
- 与事件执行器集成

### 9. 事件执行器 (event_executor.lua)
- 自动在协程中执行事件脚本
- 安装异步全局函数替换
- 支持 EventExecuteSync 入口

### 10. 异步全局替换 (async_globals.lua)
- 自动检测是否在协程中
- 在协程中自动使用异步版本
- 支持安装/卸载替换

### 11. 事件桥接 (event_bridge.lua)
- 集成所有模块
- 提供统一的 update/draw 入口
- 向后兼容原有 API

### 12. 游戏状态处理器 (game_states.lua)
- 定义所有游戏状态的行为
- 包含 GAME_START、GAME_MMAP、GAME_SMAP、GAME_WMAP、GAME_FIRSTMMAP
- 状态 enter/update/draw/exit 生命周期

## 主循环

```lua
function love.update(dt)
    JYMainAdapter.update(dt)
    EventBridge.getInstance():update(dt)
    MenuAsync.update(dt)
end

function love.draw()
    EventBridge.getInstance():draw()
    MenuAsync.draw()
end
```

## 使用示例

### 在协程中使用菜单
```lua
local result = MenuAsync.ShowMenuCoroutine(menuItem, numItem, ...)
```

### 异步显示对话框
```lua
-- 回调版本
AsyncDialog.getInstance():showYesNo("确定吗？", function(result)
    if result then
        -- 用户选择是
    end
end)

-- 协程版本
local result = AsyncDialog.getInstance():showYesNoCoroutine("确定吗？")
```

### 等待按键
```lua
local key = InputAsync.WaitKeyCoroutine()
```

### 显示对话
```lua
TalkAsync.TalkExCoroutine("对话内容", headid, flag)
```

### 触发战斗
```lua
local result = WarAsync.WarMainCoroutine(warid, isexp)
```

### 执行事件
```lua
EventExecutor.startEvent(id, flag, callback)
```

## 文件结构

```
src/
├── main.lua                    # 主入口，Love2D 回调
├── config.lua                  # 游戏配置
├── conf.lua                    # Love2D 配置
│
├── lib_love.lua                # 图形/音频封装
├── lib_Byte.lua                # 二进制数据工具
├── lib_log.lua                 # 日志工具
│
├── coroutine_scheduler.lua     # 协程调度器
├── state_machine.lua           # 状态机
├── input_manager.lua           # 输入管理器
├── input_async.lua             # 异步输入函数
│
├── async_dialog.lua            # 异步对话框
├── async_message_box.lua       # 异步消息框
├── async_wrapper.lua           # 异步函数包装器
├── async_globals.lua           # 异步全局替换
│
├── menu_state_machine.lua      # 菜单状态机
├── menu_async.lua              # 异步菜单
│
├── talk_async.lua              # 异步对话系统
├── war_async.lua               # 异步战斗系统
├── instruct_async.lua          # 异步事件指令
│
├── event_executor.lua          # 事件执行器
├── event_bridge.lua            # 事件桥接
├── game_states.lua             # 游戏状态定义
│
├── jymain_adapter.lua          # 主逻辑适配器
├── jymain_async.lua            # 主逻辑异步版本
│
└── script/
    ├── jymain.lua              # 游戏主逻辑（已添加废弃警告）
    ├── jyconst.lua             # 游戏常量
    ├── jymodify.lua            # 游戏修改
    ├── oldevent/               # 旧版事件脚本
    └── newevent/               # 新版事件脚本
```

## 废弃的阻塞函数

以下函数已标记为废弃，在协程中会自动使用异步版本：

| 函数 | 替代方案 |
|------|----------|
| `DrawStrBoxWaitKey` | `AsyncMessageBox.ShowMessageCoroutine` |
| `DrawStrBoxYesNo` | `AsyncMessageBox.ShowYesNoCoroutine` |
| `WaitKey` | `InputAsync.WaitKeyCoroutine` |
| `ShowMenu` | `MenuAsync.ShowMenuCoroutine` |
| `ShowMenu2` | `MenuAsync.ShowMenu2Coroutine` |

## 注意事项

1. **所有阻塞式代码已改造为协程版本**
2. **事件脚本执行时自动安装异步全局替换**
3. **状态机自动同步 JY.Status**
4. **战斗结束后自动返回之前状态**
5. **协程调度器每帧自动更新所有挂起的协程**
6. **输入管理器每帧自动重置按键状态**