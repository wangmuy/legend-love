# 迁移指南

## 从阻塞式到事件驱动的迁移

### 主要变化

1. **主循环**: 从自定义循环改为Love2D标准事件循环
2. **输入处理**: 从阻塞式WaitKey改为事件驱动
3. **菜单显示**: 从阻塞式ShowMenu改为异步版本
4. **事件脚本**: 从顺序执行改为协程执行

### API变更

#### 菜单函数

**旧代码（阻塞式）:**
```lua
local result = ShowMenu(menu, 3, 0, x, y, ...)
if result == 1 then
    -- 处理选择
end
```

**新代码（异步回调）:**
```lua
MenuAsync.ShowMenu(menu, 3, 0, x, y, ..., function(result)
    if result == 1 then
        -- 处理选择
    end
end)
```

**新代码（协程同步式）:**
```lua
local result = MenuAsync.ShowMenuCoroutine(menu, 3, 0, x, y, ...)
if result == 1 then
    -- 处理选择
end
```

#### 等待按键

**旧代码:**
```lua
local key = WaitKey()
```

**新代码（协程中）:**
```lua
local key = InputAsync.WaitKey()
```

#### 对话框

**旧代码:**
```lua
local result = DrawStrBoxYesNo(-1, -1, "确定吗？", C_WHITE, CC.DefaultFont)
```

**新代码:**
```lua
AsyncDialog.getInstance():showYesNo("确定吗？", function(result)
    -- 处理结果
end, {color = C_WHITE, size = CC.DefaultFont})
```

### 事件脚本迁移

事件脚本（oldevent/目录）**无需修改**，event_coroutine.lua会自动包装instruct函数。

### 状态机使用

**注册状态:**
```lua
EventBridge.getInstance():registerState(GAME_MMAP, {
    enter = function(prevState, data) ... end,
    exit = function(nextState) ... end,
    update = function(dt) ... end,
    draw = function() ... end
})
```

**切换状态:**
```lua
EventBridge.getInstance():switchState(GAME_MMAP)
```

### 常见问题

**Q: 为什么按键没有响应？**
A: 确保在love.update中调用了EventBridge.getInstance():update(dt)

**Q: 菜单为什么不显示？**
A: 确保在love.draw中调用了MenuAsync.draw()

**Q: 事件脚本如何执行？**
A: 使用EventCoroutine.execute(eventFn, callback)

**Q: 如何调试协程？**
A: 使用CoroutineScheduler.getInstance():getAllCoroutines()查看所有协程

### 回滚方案

如需回滚到阻塞式版本：
1. 恢复main.lua为原始版本
2. 使用原有的ShowMenu、WaitKey等函数
3. 移除EventBridge.update和draw的调用

## 测试清单

- [ ] 开始菜单正常显示和选择
- [ ] 游戏主循环正常运行
- [ ] 地图移动和场景切换正常
- [ ] 事件脚本正常执行
- [ ] 对话框正常显示和响应
- [ ] 存档读档功能正常
