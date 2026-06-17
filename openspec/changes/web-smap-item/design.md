## Context

场景中除了 NPC 还有物品。玩家需要能查看物品描述、拾取物品、将物品交给 NPC。`look` 命令需要支持带参数查看具体对象。

## Goals / Non-Goals

**Goals:**
- `take <物品名>` — 从场景拾取物品到背包
- `give <物品名> <人名>` — 将物品交给 NPC
- `look <目标>` — 查看具体 NPC 或物品的描述
- 场景物品列表显示在 `look` 输出中

**Non-Goals:**
- 背包管理 UI（Slice 6 bag 命令）
- 物品合成/使用
- 商店交易

## Architecture Decision Records

### ADR-001: 场景物品信息从 scenes.json 读取

- **Context**: 场景中可交互的物品信息在 scenes.json 中，每个场景有 items 列表。
- **Decision**: `take` 命令从 `dataCache.scenes[sceneId]["物品"]` 读取场景物品列表。
- **Consequences**: 与 Love2D 原版数据一致，无需额外数据文件。

### ADR-002: 物品拾取后通过 sceneState 标记

- **Context**: 物品被拾取后不应再次出现。
- **Decision**: 调用 `web-scene-state` 的 `updateItemCount(sceneId, itemId, -1)` 减少数量，`look` 时过滤 count=0 的物品。

## Data Flow

```
take 白酒
  ├─ 查找当前场景物品列表
  ├─ 匹配物品名称
  ├─ 检查 sceneState 中物品是否可用
  ├─ 添加到 JY.Thing 背包
  ├─ sceneState 标记为已拾取
  └─ WebUI.write("你获得了 白酒")

give 白酒 胡斐
  ├─ 检查背包中是否有白酒
  ├─ 检查场景中胡斐是否在场
  ├─ 从背包移除白酒
  ├─ 触发胡斐的对话/事件（如有）
  └─ WebUI.write("你将白酒交给了胡斐")

look 白酒
  ├─ 查找场景物品
  ├─ 输出物品描述（从 CC.ItemDesc 或 items.json 读取）
  └─ 如物品已拾取 → "这里没有白酒了"
```

## Decisions

### 场景物品查找
```lua
-- scenes.json 中的物品列表
local scene = getScenes()[tostring(JY.SubScene)]
local items = scene["物品"]  -- { {["代号"]=47, ["名称"]="白酒"}, ... }
for _, item in ipairs(items) do
    local itemData = dataCache["items"] and dataCache["items"][tostring(item["代号"])]
    local name = itemData and itemData["名称"] or item["名称"]
    -- 检查 sceneState
    if sceneState.itemAvailable(sceneId, item["代号"]) then
        -- 显示在场景中
    end
end
```

### 背包存储
背包暂存 `JY.Base["物品N"]` 和 `JY.Base["物品数量N"]`（与原版一致）。Slice 6 会完善 `bag` 命令。
