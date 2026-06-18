## Context

67 个 `instruct_*` 函数是 oldevent 脚本与游戏引擎的接口。在 Love2D 中，它们操作像素级渲染、音效、输入等。在 Web MUD 中，需要映射到文本输出或 no-op。

## Decisions

### 统一注册模式

所有 `instruct_*` 通过 `rawset(_G, "instruct_N", func)` 在 `initWebFramework` 中注册。

```lua
-- 通用 stub 生成器
for i = 0, 66 do
    if not rawget(_G, "instruct_" .. i) then
        rawset(_G, "instruct_" .. i, function(...)
            EngineAPI.debug.log("instruct_" .. i .. " 未实现")
        end)
    end
end
```

### 分类实现

**P0 — 直接影响游戏流程的（oldevent_691 用到）**：
```lua
rawset(_G, "instruct_27", function() end)  -- 动画 no-op
rawset(_G, "instruct_67", function() end)  -- 音效 no-op
rawset(_G, "instruct_40", function(dir)
    local JY = rawget(_G, "JY")
    if JY then JY.Base["人方向"] = dir end
end)
```

**P1 — 影响场景状态的**：
```lua
rawset(_G, "instruct_3", function(...) 
    -- 修改场景事件: sceneId, eventId, layer, x, y, type, ...
    -- 更新 JY.Scene[sceneId] 事件表
end)
```

**P2 — 其他**：no-op + debug.log

## Review Checklist

1. `instruct_27()` 调用不崩溃
2. `instruct_40(0)` 设置 `JY.Base["人方向"] = 0`
3. 调用任何未显式实现的 `instruct_*` → debug.log 提示
4. oldevent_691.lua 完整执行不报错
