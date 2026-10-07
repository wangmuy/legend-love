## 为什么

SMAP 场景交互需要统一的菜单驱动模式——玩家 `look` 后看到编号列表，`choose N` 做选择。与 MMAP 的 `list` → `choose N` 交互一致，降低用户学习成本。

## Parent Context

- Epic: `openspec/epics/2026-06-web-mud-text-version/epic.md`
- Slice 4: `openspec/changes/slice4-smap-interaction/change-manifest.md`

## What Changes

1. `SmapHandlers.look` 输出编号列表（NPC/物品/出口），替代独立 `talk`/`take`/`give` 命令
2. `SmapHandlers.chooseInteraction` 处理 `choose N` 路由
3. `smapEntityList` 本地表存储当前场景交互对象

### 交互流程
```
> look
1. 胡斐
2. 白酒
3. → 明教地道
输入 choose <编号> 选择交互对象

> choose 1
胡斐:
  1. 对话
  2. 查看
  3. 给予物品

> choose 3
白酒:
  1. 拾取
  2. 查看
```

## Capabilities

- `smap-menu-look`: 增强的 `look` 命令输出编号列表
- `smap-choose-interaction`: `choose N` 路由到 NPC/物品/出口子菜单
- `smap-entity-list`: 场景实体列表管理

## Traceability
- [REQ-001]: SMAP 菜单驱动交互 (slice4)
