## Context

oldevent 脚本通过 `GetD`/`SetD`/`GetS`/`SetS` 访问 D* 事件数据。原版 Love2D 中数据从二进制文件一次性加载到 `JY.D{sceneId}` Lua 运行时表，运行时全部从 `JY.D{sceneId}` 读写。

Web MUD 的 `initDataSource.events`（20000 条 JSON 记录）是初始数据源，不能直接用于运行时查询（线性扫描 20000 条太慢）。

## Decisions

### GetD/SetD 实现

```
首次 GetD(sceneId, ...) 时:
  1. 检查 JY.D[sceneId] 是否存在
  2. 不存在 → 从 initDataSource.events 中筛选 sceneId 匹配的全部事件
  3. 拷贝到 JY.D[sceneId] (Lua 数组)
  4. 返回 JY.D[sceneId][eventId][field]

后续 GetD(sceneId, ...) 时:
  1. 直接读 JY.D[sceneId][eventId][field] (已有缓存)

SetD(sceneId, eventId, field, value):
  1. 确保 JY.D[sceneId] 已加载（调用 ensureSceneDEvents）
  2. JY.D[sceneId][eventId][field] = value
```

### GetS/SetS

场景格子数据（地面图层属性）在 Web MUD 中用不到，简化为：
- `GetS(...)` → 返回 0
- `SetS(...)` → no-op

## Data Flow

```
initDataSource.events (20000条, 只读)
       │
       │ 首次 GetD(sceneId) 时
       ▼
JY.D[sceneId] = { [1] = {...}, [2] = {...}, ... }  (运行时 Lua 表)
       │
       ├── GetD(sceneId, eventId, field) → JY.D[sceneId][eventId][field]
       └── SetD(sceneId, eventId, field, val) → JY.D[sceneId][eventId][field] = val
```

## Review Checklist

1. `GetD(70, 0, 5)` 返回有效值或 0，不崩溃
2. 重复调用 `GetD(70, ...)` 只从 initDataSource 加载一次
3. `SetD(...)` 写入 JY.D 不影响 initDataSource
