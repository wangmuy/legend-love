## Context

### 原版 `instruct_27` 工作原理

```lua
function instruct_27(id,startpic,endpic)
    for i =startpic,endpic,2 do
        if id==-1 then
            JY.MyPic=i/2;  -- 设置主角贴图
        else
            SetD(JY.SubScene,id,5,i);  -- 设置场景对象贴图
            SetD(JY.SubScene,id,6,i);
            SetD(JY.SubScene,id,7,i);
        end
        DtoSMap();      -- 更新场景数据
        DrawSMap();     -- 直接绘制场景（阻塞）
        ShowScreen();   -- 显示画面（调用 present）
        lib.Delay(...); -- 延迟（阻塞）
    end
end
```

原版流程：
1. 设置贴图 → 2. DtoSMap → 3. DrawSMap（直接绘制到屏幕）→ 4. ShowScreen（present）→ 5. Delay（阻塞等待）

### 事件驱动版问题

当前实现：
1. 设置贴图 → 2. DtoSMap → 3. waitForTime（延迟）→ 让出协程

问题：
- `DrawSMap()` 直接调用绘制，但事件驱动架构中绘制应该在 `love.draw` 中进行
- `ShowScreen()` 被替换为 `waitForTime`，不触发绘制
- `love.draw` 调用 `GAME_SMAP.draw` → `DrawSMap()`，但此时可能读取到错误的 `MyPic`

## Goals / Non-Goals

**Goals:**
- 让 `instruct_27` 的动画在事件驱动架构中正确显示
- 保持与原版相同的动画效果（22帧，每帧150ms）
- 不阻塞游戏主循环

**Non-Goals:**
- 不修改原版同步代码（保留兼容性）
- 不改变动画帧率或时长

## Decisions

### 采用纯事件驱动方案：状态驱动 + 渲染循环

**核心问题分析**:
- 原版：`instruct_27` 直接调用 `DrawSMap()` 和 `ShowScreen()`，阻塞式动画
- 事件驱动版：`DrawSMap()` 在 `love.draw` 中调用，与 `instruct_27` 执行时机不同步
- 当前问题：`waitForTime` 的 `while` 循环阻塞协程，或 `yield` 后 `love.draw` 来不及执行

**新方案**: 动画状态由 `GAME_SMAP.update` 驱动，`instruct_27` 只设置目标状态并等待完成

**实现步骤**:

1. **添加全局动画状态**:
```lua
-- JY.AnimationState 结构
JY.AnimationState = {
    active = false,      -- 是否正在播放动画
    id = -1,             -- -1=主角, 其他=场景对象ID
    currentFrame = 0,    -- 当前帧索引
    startFrame = 0,      -- 起始帧
    endFrame = 0,        -- 结束帧
    startTime = 0,       -- 开始时间
    frameDuration = 150, -- 每帧持续时间(ms)
}
```

2. **修改 `GAME_SMAP.update` 驱动动画**:
```lua
function GAME_SMAP.update(dt)
    -- 检查是否有动画需要播放
    if JY.AnimationState.active then
        local anim = JY.AnimationState
        local now = lib.GetTime()
        local elapsed = now - anim.startTime
        local frameIndex = math.floor(elapsed / anim.frameDuration)
        local i = anim.startFrame + frameIndex * 2
        
        if i > anim.endFrame then
            -- 动画结束
            anim.active = false
        else
            -- 设置当前帧贴图
            if anim.id == -1 then
                JY.MyPic = i / 2
            else
                SetD(JY.SubScene, anim.id, 5, i)
                SetD(JY.SubScene, anim.id, 6, i)
                SetD(JY.SubScene, anim.id, 7, i)
            end
            DtoSMap()
        end
    end
    
    -- ... 其他更新逻辑
end
```

3. **修改 `instruct_27` 设置动画状态并等待**:
```lua
function instruct_27(id, startpic, endpic)
    -- 设置动画状态
    JY.AnimationState = {
        active = true,
        id = id,
        startFrame = startpic,
        endFrame = endpic,
        currentFrame = startpic,
        startTime = lib.GetTime(),
        frameDuration = CC.AnimationFrame,
    }
    
    -- 计算动画总时长
    local totalFrames = (endpic - startpic) / 2 + 1
    local totalDuration = totalFrames * CC.AnimationFrame
    
    -- 等待动画完成
    local scheduler = require("coroutine_scheduler").getInstance()
    while JY.AnimationState.active do
        scheduler:yield("animation")  -- 让出协程，等待下一帧
    end
end
```

4. **修改 `CoroutineScheduler:update` 支持动画等待**:
```lua
-- 在 update 中，每帧恢复 waitingFor == "animation" 的协程
for _, id in ipairs(activeCoroutines) do
    local info = coroutines[id]
    if info and info.status == "suspended" and info.waitingFor == "animation" then
        -- 恢复协程，让它检查动画是否完成
        self:resume(id)
    end
end
```

**优势**:
- 纯事件驱动：动画更新在 `GAME_SMAP.update` 中，渲染在 `love.draw` 中
- 时序清晰：每帧先 `update` 更新动画状态，再 `draw` 渲染
- 不阻塞：协程只检查状态，不阻塞等待
- 可控：动画帧率由 `GAME_SMAP.update` 控制

**风险**:
- 需要修改 `GAME_SMAP.update`，增加动画逻辑
- **缓解**: 动画逻辑简单，只设置贴图和调用 `DtoSMap`

## Risks / Trade-offs

**风险**: 全局状态 `JY.AnimationMyPic` 可能被其他代码意外修改
- **缓解**: 动画结束后立即清除

**风险**: `DrawSMap` 在动画期间被多次调用（`instruct_27` 直接调用 + `love.draw` 调用）
- **缓解**: 使用全局状态确保两次调用使用相同的贴图

**权衡**: 全局状态 vs 参数传递
- 选择全局状态，因为 `DrawSMap` 在多处被调用，修改参数需要改动所有调用点
