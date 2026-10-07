## 为什么

场景中玩家需要能够休息恢复体力。主角的家有床，客栈提供住宿服务。在 Love2D 版本中，床通过 tile 检测或 `instruct_11()` 实现。Web MUD 需要一个统一的 `rest` 命令。

## Parent Context

- Epic: `openspec/epics/2026-06-web-mud-text-version/epic.md`
- 父 Change: `openspec/changes/slice4-smap-interaction/change-manifest.md`
- 子 Change: `openspec/changes/smap-rest-command/`
- 依赖: smap-menu-interaction（菜单驱动交互已就绪）, smap-scene-state（场景状态）

## What Changes

1. 新增 `rest` SMAP 命令
2. 场景类型为 `house` → 免费休息（主角的家）
3. 场景有 NPC 指向客栈住宿事件时 → 通过 NPC 对话触发付费住宿（oldevent_235）
4. `rest` 调用 `instruct_12()` 恢复 HP/MP/体力
5. `rest` 在客栈场景判断金钱是否足够

## Traceability

- [REQ-001]: SMAP 的 rest 命令实现
