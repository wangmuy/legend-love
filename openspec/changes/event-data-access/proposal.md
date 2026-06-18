## 为什么

oldevent 脚本通过 `GetD`/`SetD`/`GetS`/`SetS` 函数访问 D* 事件数据。这些函数在原版 Love2D 中从二进制 `R*.idx/grp` 文件读取。Web MUD 已将数据提取为 `dataCache.events`（20000 条 JSON），需要提供对应的访问函数。

## Parent Context

- Epic: `openspec/epics/2026-06-web-mud-text-version/epic.md`
- Slice: `openspec/changes/event-system-integration/change-manifest.md`
- 依赖: event-executor-loader

## What Changes

1. `GetD(sceneId, layer, x, y, field)` → 从 `dataCache.events` 线性查找
2. `SetD(...)` → 写入 JY.Scene 运行时数据（不持久化）
3. `GetS(sceneId, x, y, field)` → 场景格子数据（简化返回 0）
4. `SetS(...)` → 写入运行时场景状态

## Impact

| 文件 | 改动 |
|------|------|
| `web_game_bridge.lua` | 新增 GetD/SetD/GetS/SetS |
