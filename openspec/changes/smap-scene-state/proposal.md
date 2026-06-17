## 为什么

NPC 对话和物品拾取会改变场景状态。如果不跟踪这些状态，`look` 会显示已经不存在的 NPC 和物品。场景状态需要在游戏会话期间持续有效。

## Parent Context

- Epic: `openspec/epics/2026-06-web-mud-text-version/epic.md`
- Slice 4: `openspec/changes/slice4-smap-interaction/change-manifest.md`
- 依赖: `smap-menu-interaction`, `smap-npc-dialog`

## What Changes

1. `_G.sceneState` 表管理场景动态状态
2. `setNpcPresent` / `isNpcPresent` — NPC 在场/离场
3. `setItemCount` / `getItemCount` / `itemAvailable` — 物品可用数量
4. `look` 输出过滤已离场 NPC 和已拾取物品
5. 惰性初始化：首次访问时创建场景状态

## Capabilities

- `scene-state-table`: `_G.sceneState` 全局表
- `scene-state-npc`: NPC 状态 API
- `scene-state-item`: 物品状态 API
- `scene-state-filter`: `look` 输出过滤
