## 为什么

场景中除了 NPC 还有物品——客栈里的酒、民居里的药物、商店里的商品。玩家需要能拾取、查看和使用这些物品。同时需要能将物品交给 NPC 以推动剧情。

## Parent Context

- Epic: `openspec/epics/2026-06-web-mud-text-version/epic.md`
- Slice 4: `openspec/changes/slice4-smap-interaction/change-manifest.md`
- 依赖：web-smap-talk（NPC 对话先行，物品交互可能触发对话事件）

## What Changes

1. 新增 `take <物品名>` SMAP 命令
2. 新增 `give <物品名> <人名>` SMAP 命令
3. `look <目标>` 查看物品或 NPC 描述（已有 `look` 无参行为不变）
4. 场景物品列表：`look` 中显示可交互物品
5. 物品拾取后从场景状态中移除（通过 web-scene-state）
6. `give` 将背包物品交给 NPC，可能触发事件

## Scope Boundaries

### In Scope
- `take` 命令：查找并拾取场景物品
- `give` 命令：将物品交给指定 NPC
- `look <目标>` 查看具体对象
- 场景物品列表显示
- 物品交互中的基本条件判断（物品是否存在、NPC 是否在场）

### Out of Scope
- 背包管理（Slice 6）
- 物品合成/使用
- 商店交易

## Impact

| 文件 | 改动 |
|------|------|
| `mmap_smap_handlers.lua` | 新增 take/give/look 处理器 |
| `web_command_engine.lua` | SMAP 注册表添加 take/give |
| `tests/` | 新增物品交互 E2E 测试 |
