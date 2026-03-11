# 金庸群侠传 Love2D 事件驱动架构文档

## 架构概述

本项目采用完全事件驱动的架构，替代原有的阻塞式代码，实现流畅的游戏体验。

## 核心模块

### 1. 协程调度器 (coroutine_scheduler.lua)
- 管理所有协程的创建、启动、暂停和恢复
- 提供等待按键、等待时间等功能
- 支持协程错误处理和状态查询

### 2. 状态机 (state_machine.lua)
- 统一管理游戏状态（主地图、场景、菜单等）
- 支持子状态嵌套
- 支持状态间数据传递

### 3. 输入管理器 (input_manager.lua)
- 集中处理所有键盘输入
- 支持输入缓冲和按键重复
- 提供消费模式和非消费模式

### 4. 异步对话框 (async_dialog.lua)
- 非阻塞的对话框显示
- 支持确认、输入、选择等对话框类型
- 支持对话框堆叠和动画

### 5. 异步菜单 (menu_async.lua)
- 非阻塞的ShowMenu/ShowMenu2
- 支持菜单嵌套和动画
- 提供协程版本供同步调用

### 6. 事件协程 (event_coroutine.lua)
- 包装事件脚本为协程执行
- 支持事件暂停和恢复
- 自动包装instruct_XXX函数

### 7. 事件桥接 (event_bridge.lua)
- 集成所有模块
- 提供统一的update/draw入口
- 向后兼容原有API

## 主循环

```lua
function love.update(dt)
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
AsyncDialog.getInstance():showYesNo("确定吗？", function(result)
    if result then
        -- 用户选择是
    end
end)
```

### 等待按键
```lua
local key = InputAsync.WaitKey()
```

## 文件结构

```
src/
├── main.lua                    # 主入口
├── coroutine_scheduler.lua     # 协程调度器
├── state_machine.lua           # 状态机
├── input_manager.lua           # 输入管理器
├── input_async.lua             # 异步输入函数
├── async_dialog.lua            # 异步对话框
├── menu_state_machine.lua      # 菜单状态机
├── menu_async.lua              # 异步菜单
├── event_coroutine.lua         # 事件协程
├── event_bridge.lua            # 事件桥接
└── game_states.lua             # 游戏状态定义
```

## 注意事项

1. 所有阻塞式代码已重构为非阻塞
2. 原有script/目录代码无需修改
3. 协程调度器自动管理协程生命周期
4. 输入管理器每帧自动重置按键状态
