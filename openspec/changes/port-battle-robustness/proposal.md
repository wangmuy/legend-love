# Change Proposal: port-battle-robustness — WarLoad 错误码 + WAR.Person 容量

> 父 slice: `engine-portability`
> 前置: `battle-extensibility` ✓

## Why

这两个问题都来自 [`openspec/project/ROBUSTNESS_AUDIT.md`](../../project/ROBUSTNESS_AUDIT.md)
的「记录但未处理」清单，且有明确的可见故障模式。

### 问题 1：`WarLoad` 越界只写日志，不返回错误码

`game/script/jymain.lua`：

```lua
function WarLoad(warid)
    WarSetGlobal()
    ...
    if n and (warid < 0 or warid >= n) then
        JY_Error("WarLoad: warid=%d out of range...")   -- 只 Log()
        return                                          -- 返回 nil
    end
    ...
end
```

**`JY_Error` 实测只是 `Log()`**（[`framework/lib_log.lua:54`](../../../game/framework/lib_log.lua)）：

```lua
function JY_Error(fmt, ...)
    local logfile = ...
    Log(logfile, false, fmt, ...)    -- 只写文件，不抛错、不终止
end
```

而 `WarMainCoroutine` **不检查返回值**：

```lua
WarLoad(warid)                        -- ← 返回 nil 也不管
WarSelectTeam()
WarSelectEnemy()
...
```

后果：`WAR.Data` 保持**上一场战斗的数据**（或初始空值）→ 战斗"假开始"：
- 地图编号是上一场的
- 敌人配置是上一场的
- `warState.result` 也保持上一个值 → 调用方读到**错误的胜负**

### 问题 2：`WAR.Person` 固定 26 槽，零余量

```lua
-- jymain.lua WarSetGlobal
WAR.Person = {}
for i = 0, 26-1 do        -- ← 硬编码 26
    WAR.Person[i] = { ... }
end
```

容量核算（实测）：

```
WarSelectTeam   最多 6   （for i=1,6 / for i=1,CC.TeamNum，CC.TeamNum=6）
WarSelectEnemy  最多 20  （for i=1,20）
合计 26 = 槽数 26           ← 零余量
```

MOD 把 `CC.TeamNum` 改成 > 6，或敌方数量 > 20 →

```lua
WAR.PersonNum = WAR.PersonNum + 1
WAR.Person[WAR.PersonNum]["人物编号"] = id     -- WAR.Person[26] 是 nil → 崩
```

---

## In Scope

### 1. `WarLoad` 返回明确错误码

- 越界 → `return false`（不是裸 `return`）
- 成功 → `return true`
- `WarMainCoroutine` 检查：false 时置 `warState.status = "ended"` /
  `warState.result = nil` 并 `return false`
- 其余 2 个调用点（`instruct_58`、`battle_flow_coroutines` 内的 reload）同步检查

### 2. `WAR.Person` 扩容 + 越界守卫

- 槽数从 26 → **40**（6 + 20 + 14 余量，MOD 友好）
- `WarSelectTeam` / `WarSelectEnemy` 加越界守卫（`WAR.PersonNum` 达到上限时
  停止添加 + `JY_Error` 记录），而不是写到 nil

---

## Out of Scope

```
✗ 动态扩容（WarSetGlobal 之外按需 new 表）→ 40 槽已足够，动态扩容复杂度不值得
✗ war.sta 的数据格式变更 → 与引擎/健壮性无关
✗ 战斗 AI 改动 → 归 battle-extensibility（已完成）
✗ 其余 24 个 lib.* 的迁移 → 归 port-native-api-*（未立项）
```

## 关键度量

| 指标 | 基线 | 目标 |
|------|------|------|
| `WarLoad` 返回值的语义 | 隐式（永远 nil） | `true`/`false` |
| `WarMainCoroutine` 检查 `WarLoad` 返回值 | 否 | 是 |
| `WAR.Person` 槽数 | 26（零余量） | 40 |
| `WAR.Person[26]` 写入 | 崩 | 被守卫拦住 + 日志 |

## 风险

| 风险 | 缓解 |
|------|------|
| `WarLoad` 改返回值会破坏既有调用方 | 逐点核实 3 个调用点；原返回 nil，新返回 true/false，`if WarLoad() then` 语义一致 |
| 26 → 40 会不会改变战斗行为 | 槽位只是容量，`WAR.PersonNum` 逻辑不变；多出的 14 个槽是未被使用的空表 |
| 越界守卫可能掩盖真实 bug | 守卫时 `JY_Error` 记录，不静默 |

## Tracking

| REQ ID | 需求 | 落点 |
|--------|------|------|
| REQ-BRB-1 | `WarLoad` 返回明确成功/失败 | specs/battle-robustness/spec.md |
| REQ-BRB-2 | `WarMainCoroutine` 检查 `WarLoad` 结果 | 同上 |
| REQ-BRB-3 | `WAR.Person` 容量 >= 40 且有越界守卫 | 同上 |
