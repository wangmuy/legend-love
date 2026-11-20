# Tasks: port-battle-robustness

> 父 slice: `engine-portability`

## Task 1：`WarLoad` 返回布尔

**Blast Radius**：`game/script/jymain.lua`

**DoD**：
- [x] 越界分支：裸 `return` → `return false`
- [x] 成功路径末尾：加 `return true`
- [x] `JY_Error` 保持原样（纯日志，不改抛错）
- [x] 单测：`WarLoad(0)` 返回 true；`WarLoad(999999)` 返回 false
- [x] 单测：越界返回 false（`JY_Error` 是纯 Log，不断言文件内容）
- [x] 四版本全量测试零失败
- [x] 一个 commit

---

## Task 2：3 个调用点检查 `WarLoad` 返回值

**Blast Radius**：`game/framework/war_async.lua`、`game/script/battle/battle_flow_coroutines.lua`、`game/script/jymain.lua`（`instruct_58`）

**DoD**：
- [x] `war_async.WarMainCoroutine`：`WarLoad(warid)` → `if not WarLoad(warid) then ... end`
- [x] `warState.result = nil` 在**开头**就设（不等失败分支）
- [x] 失败时：`warState.status = "ended"` + `return false`
- [x] `instruct_58`（`jymain.lua:4227` 附近）：`WarLoad(...)` 检查返回值
- [x] `battle_flow_coroutines` 内的战前 reload（若有）：同上
- [x] 单测：`warState.result` 在 WarLoad 之前清空 + 失败分支行为复刻
- [x] 单测：`warState.result` 被清成 nil（不是上场的值）
- [x] 四版本全量测试零失败
- [x] 一个 commit

---

## Task 3：`WAR.Person` 扩容 26 → 40

**Blast Radius**：`game/script/jymain.lua`（`WarSetGlobal`）

**DoD**：
- [x] `for i=0,26-1` → `for i=0,40-1`
- [x] 提取常量 `WAR_PERSON_CAPACITY = 40`（避免硬编码散落）
- [x] 单测：`WAR.Person[0]` .. `WAR.Person[39]` 都是 table
- [x] 单测：`WAR.Person[40]` 是 nil（边界正确）
- [x] 正常战斗仍能添加 26 个（`PersonNum == 26`）
- [x] 四版本全量测试零失败
- [x] 一个 commit

---

## Task 4：`WarSelectTeam` / `WarSelectEnemy` 越界守卫

**Blast Radius**：`game/script/battle/battle_flow.lua`

**DoD**：
- [x] `WarSelectTeam` 添加前检查 `WAR.PersonNum >= WAR_PERSON_CAPACITY`
- [x] `WarSelectEnemy` 添加前检查同上
- [x] 越界时：`JY_Error` 记录 + 停止添加（不写到 nil 槽）
- [x] 单测：`PersonNum` 已达上限时继续调用 → 不崩、`PersonNum` 不变
- [x] 单测：越界时 `JY_Error` 被调用（或 error.txt 有记录）
- [x] 负向对照：3 组（40→26 / 删 return false / 加裸 WarLoad）全部 FAIL 实测
- [x] 四版本全量测试零失败
- [x] 一个 commit

---

## Task 5：门禁 + 全量验证

**Blast Radius**：`game/tests/gate_battle_extensibility.sh`、`openspec/project/ROBUSTNESS_AUDIT.md`

**DoD**：
- [x] `gate_battle_extensibility.sh` 新增断言：`WAR.Person` 容量 >= 40
- [x] 新增断言：`WarLoad` 源码里有 `return false` 和 `return true`
- [x] 负向对照：把 40 改回 26 → gate FAIL
- [x] 负向对照：把 `return false` 改回裸 `return` → gate FAIL
- [x] 四版本全量测试零失败（记录断言数）
- [x] 全仓 `luac5.1 -p` / `luac55 -p` 零失败
- [x] 五门禁全 PASS
- [x] 实机截图：战斗仍能正常起（`--shot --battle=4`）
- [x] 更新 `ROBUSTNESS_AUDIT.md`（把这两项从「未处理」移到「已修」）
- [x] 一个 commit
