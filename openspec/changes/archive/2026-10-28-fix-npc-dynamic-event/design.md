# fix-npc-dynamic-event — 设计文档

## 问题分析

### 当前行为

`smapNpcTalk` 从静态 NPC 数据读取事件 ID：

```lua
function smapNpcTalk(sceneId, ent)
    local eventId = ent.npcData["事件编号"] or ent.npcData["触发事件"] or 0
```

`ent.npcData` 来自 `scene["NPC"]`，是 `initDataSource.scenes` 中的静态数据，不会被 `instruct_3` 修改。

### 预期行为

原版游戏中，NPC 事件 ID 存储在 D* 事件表中。`instruct_3` 通过 `SetD(sceneId, 3, dIdx, 0, newEventId)` 修改 D* 事件表。NPC 交互时从 D* 事件表读取事件 ID，而非从静态数据读取。

### 修复方案

在 `smapNpcTalk` 中，先尝试从 D* 事件表 (`JY.Scene`) 查找动态事件 ID，若存在则使用动态 ID，否则回退到静态 NPC 数据。

```lua
function smapNpcTalk(sceneId, ent)
    -- 先从 D* 事件表查找动态事件 ID（instruct_3 修改后的值）
    local dIdx = ent.npcData["触发事件"] or 0
    local dynamicEventId = nil
    if dIdx > 0 then
        local JY = rawget(_G, "JY")
        if JY and JY.Scene then
            local sceneEvents = JY.Scene[tonumber(sceneId)]
            if sceneEvents then
                local evt = sceneEvents[tostring(dIdx)]
                if evt and evt[0] and evt[0] > 0 then
                    dynamicEventId = evt[0]
                end
            end
        end
    end
    local eventId = dynamicEventId or ent.npcData["事件编号"] or ent.npcData["触发事件"] or 0
```

## 验证

1. 霹雳堂孔八拉：首次对话(678) → `instruct_3` 修改事件 → 再次对话触发 686(神杖检查)
2. 回归测试：P1-P10 全部通过