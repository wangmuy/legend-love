## Context

当前 Web MUD 中 NPC 对话调用 `EventExecutor.startEvent()` 时返回"事件系统不可用"。原因为：
1. `event_executor.lua` 模块未在 `initWebFramework` 中加载
2. 67 个 `instruct_*` 函数中仅有 `instruct_0` 和 `instruct_1` 已实现
3. `GetD`/`SetD` 等 D* 数据访问函数不存在

## Goals / Non-Goals

**Goals:**
- 所有 1018 个 oldevent 脚本在 Web MUD 中不经修改即可加载执行
- 67 个 `instruct_*` 函数全部有 Web MUD 版实现（no-op 或最小必要实现）
- `GetD`/`SetD` 操作 `JY.D{sceneId}` 运行时 Lua 表（非扫描 JSON）
- `dataCache` 重命名为 `initDataSource`，明确其"只读初始数据源"角色
- 完成 3 个游戏流程测试（软体娃娃、店小二、南贤）

**Non-Goals:**
- newevent 系统（未使用）
- 战斗事件
- 1018 个 event 逐一测试
- 像素级动画/音效（no-op）

## Architecture Decision Records

### ADR-001: instruct 桩函数通过 rawset 统一注册

- **Context**: `async_globals.lua` 在事件执行时会安装 `instruct_*` 替换函数。Web MUD 需要自己的版本。
- **Decision**: 在 `initWebFramework` 中通过 `rawset(_G, "instruct_N", ...)` 注册所有桩函数。`async_globals` 安装时会跳过已有函数。
- **Consequences**: 与 `async_globals.lua` 兼容，不冲突。

### ADR-002: Game Flow Testing 替代单元测试

- **Context**: 测试 oldevent 的最佳方式不是 mock 每个函数，而是执行完整的游戏流程。
- **Decision**: 采用 Game Flow Testing 方法——以玩家身份执行完整操作序列，验证终端输出。
- **Consequences**: 测试更真实，但执行时间更长。

### ADR-003: D* 数据按场景加载到 JY.D，而非实时扫描 JSON

- **Context**: 原版 `GetD/SetD` 操作 `JY.D{sceneId}` Lua 运行时表，数据来自二进制文件的一次性加载。Web MUD 的 `dataCache.events` 有 20000 条 JSON 记录。每次 `GetD` 线性扫描 20000 条数据性能差，且不遵循原版模式。
- **Decision**: 首次访问某场景时，从 `initDataSource.events` 将该场景所有事件拷贝到 `JY.D{sceneId}` Lua 表。此后 `GetD/SetD` 直接操作 `JY.D{sceneId}`。`initDataSource` 是只读的初始数据源，运行时 `JY.*` 是唯一的状态源。
- **Consequences**: 与存档机制一致——加载存档时从 IndexedDB 恢复 `JY.*`，不经过 `initDataSource`。`initDataSource` 在所有 `initGameState()` 完成后不再被修改。
- **dataCache 重命名**: `_G.dataCache` → `_G.initDataSource`，强调其只读、仅初始化时使用的角色。

## D* 事件数据格式

```lua
-- dataCache.events: 20000 条记录
-- [sceneId, layer, x, y, eventType, ...]
-- eventType: 1=对话, 2=物品, 3=路过, 5=跳转, ...
-- 对于 type=1 (对话) 的 event:
--   [sceneId, layer, x, y, 1, eventScriptId, talkId, itemId, ...]

function GetD(sceneId, eventId, field)
    local events = dataCache.events  -- 20000 条
    for _, evt in ipairs(events) do
        if evt[1] == sceneId and evt[2] == layer and ... then
            return evt[field]
        end
    end
    return 0
end
```

## instruct 函数分类

| 类别 | 函数 | 策略 |
|------|------|------|
| 显示 | 0(清屏), 1(对话) | ✅ 已有实现 |
| 动画/音效 | 27, 67 | no-op |
| 状态修改 | 3(事件), 2(出入口), 40(方向) | 更新 JY 数据 |
| 菜单 | 13 | MenuAsync 代理 |
| 物品/金钱 | 32 | 背包操作 |
| 战斗 | 14 | ❌ Slice 5 |
| 队友 | 56 | 队伍管理 |
| 其他 | 4,5,6,7,8,9,... | no-op |

## Review Checklist

1. EventExecutor 加载后 `startEvent(691, 0, cb)` 不报"系统不可用"
2. oldevent_691.lua 完整执行无 instruct_* 报错
3. TC-01: 软体娃娃对话文本正确输出
4. TC-02: 悦来客栈店小二对话可触发
5. TC-03: 南贤对话可触发
