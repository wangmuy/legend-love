## 为什么

oldevent 脚本通过 `GetD`/`SetD`/`GetS`/`SetS` 函数访问 D* 事件数据。原版 Love2D 中这些函数操作 `JY.D{sceneId}` Lua 运行时表，数据在游戏启动时从二进制文件一次性加载到内存。Web MUD 需要：

1. 将 `dataCache` 重命名为 `initDataSource`，明确其"只读初始数据源"角色
2. 首次访问某场景时，从 `initDataSource.events` 将该场景的所有事件拷贝到 `JY.D{sceneId}`
3. 此后 `GetD`/`SetD` 直接操作 `JY.D{sceneId}` Lua 表

## Parent Context

- Epic: `openspec/epics/2026-06-web-mud-text-version/epic.md`
- Slice: `openspec/changes/event-system-integration/change-manifest.md`
- 依赖: event-executor-loader

## What Changes

1. `_G.dataCache` → `_G.initDataSource`（全局重命名，影响约 70 处引用）
2. `GetD(sceneId, layer, x, y, field)` → 从 `JY.D{sceneId}` Lua 表读取
3. `SetD(...)` → 写入 `JY.D{sceneId}`
4. 首次访问时从 `initDataSource.events` 拷贝到 `JY.D{sceneId}`（延迟加载）
5. `GetS`/`SetS` → 场景格子数据（简化返回 0）

## Impact

| 文件 | 改动 |
|------|------|
| 全部 engine Lua 文件 | `dataCache` → `initDataSource` |
| `web_game_bridge.lua` | 新增 GetD/SetD/GetS/SetS |
| 测试文件 | `dataCache` → `initDataSource` |
