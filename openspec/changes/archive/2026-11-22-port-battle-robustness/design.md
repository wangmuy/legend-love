# Design: port-battle-robustness

## Context

两个缺陷都来自 `openspec/project/ROBUSTNESS_AUDIT.md` 的「记录但未处理」清单。
共同根因：**「信任上游数据的合法性」**——原版从 C 移植，数据都是内置常量；
现在是 Lua + MOD 体系，数据可被改坏。

---

## ADR-BRB-001：`WarLoad` 用布尔返回值，不改抛错语义

### Context

```lua
function WarLoad(warid)
    WarSetGlobal()
    ...
    if n and (warid < 0 or warid >= n) then
        JY_Error("WarLoad: warid=%d out of range...")
        return                                  -- 裸 return = nil
    end
    local data = Byte.create(CC.WarDataSize)
    Byte.loadfile(data, CC.WarFile, warid*CC.WarDataSize, CC.WarDataSize)
    LoadData(WAR.Data, CC.WarData_S, data)
end
```

`JY_Error` 实测只是 `Log()`（`framework/lib_log.lua:54`），**不抛错**。
调用方 `WarMainCoroutine` 不检查返回值。

### Decision

`WarLoad` 返回 `true`/`false`：

```lua
function WarLoad(warid)
    WarSetGlobal()
    local okMod, ModData = pcall(require, "framework.mod_data")
    if okMod and ModData and ModData.WarRecordCount then
        local n = ModData.WarRecordCount(CC.WarFile, CC.WarDataSize)
        if n and (warid < 0 or warid >= n) then
            JY_Error(...)
            return false                    -- ← 明确失败
        end
    end
    ...
    return true                             -- ← 明确成功
end
```

**为什么是布尔而不是"抛错"**：

| 方案 | 问题 |
|------|------|
| A. `error(...)` 抛错 | `WarMainCoroutine` 在协程里跑，错误会被 `CoroutineScheduler` 静默吞掉（只写 error.txt）→ 玩家永久卡在战斗画面。这正是 `ebf81af` 那个 bug 的形态 |
| B. 返回错误字符串 | 调用方要区分 `nil` / `""` / `"msg"`，比布尔难用 |
| **C. 返回布尔（采纳）** | 与既有 `LoadRecord` 的风格一致（它已返回 true/false） |

**为什么不改 `JY_Error` 让它抛错**：`JY_Error` 有 4 处调用，其中
`GetDataFromStruct` 的 key-not-found 是**热路径**（每帧可能触发），
抛错会直接崩游戏。保持它是纯日志。

### Consequences

- 3 个调用点都要检查返回值
- `LoadRecord` 的成功路径不变（它已经返回 true/false）

---

## ADR-BRB-002：`WarMainCoroutine` 加载失败时"干净退出"

### Context

```lua
WarLoad(warid)          -- ← 不管返回值
WarSelectTeam()
WarSelectEnemy()
...
JY.Status = GAME_WMAP
```

若 `WarLoad` 失败，`WAR.Data` 是**上一场的残留**（`WarSetGlobal` 只重置
`WAR.Person` 等，不清 `WAR.Data`）→ 战斗会用错的地图/敌人继续跑，
且 `warState.result` 保持上个值。

### Decision

```lua
warState.warId = warid
warState.status = "running"
warState.result = nil                       -- ← 先清空，避免读到上个值

if not WarLoad(warid) then
    warState.status = "ended"
    warState.result = nil                  -- ← 明确"没有结果"
    return false
end
```

**关键**：`warState.result = nil` 要在**最开头**就设，而不是等失败分支。
这样即使后续任何地方失败，调用方也不会读到上一场的胜负。

### Consequences

- 调用方（`async_globals` 的 `WarMain` 包装器）拿到 `false` 时
  会走"战斗异常结束"分支（已有该分支，见 `war_async.lua` 的注释）
- `warState.result == nil` 需要调用方能处理 —— 检查现有代码是否假设
  它必然 `true`/`false`

---

## ADR-BRB-003：26 → 40 槽，静态扩容而非动态

### Decision

```lua
-- jymain.lua WarSetGlobal
local WAR_PERSON_CAPACITY = 40
WAR.Person = {}
for i = 0, WAR_PERSON_CAPACITY - 1 do
    WAR.Person[i] = { ... }
end
```

并在 `WarSelectTeam` / `WarSelectEnemy` 加守卫：

```lua
if WAR.PersonNum >= WAR_PERSON_CAPACITY then
    JY_Error("WarSelectEnemy: WAR.PersonNum 已达上限 %d", WAR_PERSON_CAPACITY)
    return                              -- 停止添加
end
```

### Alternatives

| 方案 | 否决理由 |
|------|---------|
| A. 动态扩容（按需 `WAR.Person[n] = {...}`） | 战斗里对 `WAR.Person[i]` 的遍历假设 `0..PersonNum-1` 连续；动态扩容要改所有遍历点，风险大 |
| B. 保持 26 但加守卫 | MOD 想加人到被硬拦，不满足"MOD 友好" |
| **C. 静态 40（采纳）** | 容量一次给够（6+20+14），逻辑零改动，守卫兜住极端情况 |

**为什么是 40**：6 我方 + 20 敌方 = 26 是原版上限；40 留 14 个余量，
够 MOD 把 `CC.TeamNum` 提到 10、敌方提到 25 这类合理改动。

### Consequences

- `WarSetGlobal` 每次战斗都新建 40 个表（原来 26）→ 内存 +14 个空表，可忽略
- 遍历 `for i=0,WAR.PersonNum-1` 的地方不受影响（`PersonNum` 才是循环上界）

---

## Negative Constraints

```
✗ 不得把 JY_Error 改成抛错（GetDataFromStruct 的热路径会崩）
✗ 不得用动态扩容（会破坏所有 `for i=0,PersonNum-1` 的连续假设）
✗ 不得让守卫视而不见（必须 JY_Error 记录，不能静默截断）
✗ 不得改变 WarLoad 成功时的行为（返回值之外零差异）
✗ 不得在 warState.result 上引入新语义（nil 已表示"无结果"）
```

## Review Checklist

```
[ ] WarLoad 越界返回 false，成功返回 true
[ ] 3 个调用点都检查了返回值
[ ] WarMainCoroutine 在加载失败时 warState.status="ended" / result=nil
[ ] WAR.Person 有 0..39 共 40 个槽
[ ] WarSelectTeam/Enemy 越界时停止 + 日志，不崩
[ ] 正常战斗仍能添加 26 个（容量扩大不改变流程）
[ ] 四版本 Lua 全量测试零失败
[ ] 实机截图：战斗仍能正常起
```
