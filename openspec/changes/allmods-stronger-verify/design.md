---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice3
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Design: allmods-stronger-verify

## Context

stronger 与 pascal 结构完全同形（唯一差异：`talk.grp` 3727 vs 2977）。
本 change 的审计**发现了审计工具自身的一个误判**：`kysmod.ini` 被报为 `in_product=false`，
但它实际被构建器复制到 `data/`。

## ADR-001: `in_product` 不能用类别级一刀切

**Context**：`mod_audit.lua` 原用 `IN_PRODUCT_BY_CATEGORY[category]` 判定是否进产物。
`BUILD_INPUT` 类别下有两种文件：

| 文件 | 是否进产物 | 原因 |
|------|-----------|------|
| `kysmod.ini` | **是** | `mod_build.lua:879-882` 复制到 `data/` |
| `cc/*.txt` | **否** | 仅供构建期 Big5 转换器使用 |

**Decision**：引入 **per-rule `in_product` 覆盖**。规则未声明时回退到类别默认值。

```lua
-- checkInProduct
if rule.in_product == false then return false end
if rule.in_product ~= true and not M.IN_PRODUCT_BY_CATEGORY[rule.category] then
    return false
end
```

**Alternatives**：
1. 把 `BUILD_INPUT` 类别改为 `true` —— **错误**：会让 `cc/*.txt` 也变成「矛盾」
   （类别声明在产物中但实际不在），实测产生 4 个矛盾。
2. 把 `kysmod.ini` 单列一个新类别（如 `SHIPPED_BUILD_INPUT`）—— 可行，但类别枚举膨胀；
   且语义上它确实还是「构建输入」。
3. per-rule 覆盖 —— **采用**。最小改动，语义清晰。

**Consequences**：
- `BUILD_INPUT` 类别默认 `false`（多数情形正确）。
- `kysmod.ini` 规则显式 `in_product=true`。
- 测试需按新语义更新（`testNoRequiredFileMissingFromProduct` 需读 per-rule 覆盖）。

## ADR-002: 根级文件的产物候选路径

**Context**：`kysmod.ini` 位于 MOD **根目录**，`splitPath` 返回 `topdir=""`。
原 `productCandidates` 没有处理 `topdir==""` 的分支，返回空候选列表，
导致即使 `in_product=true` 也找不到文件。

**Decision**：新增分支——根级文件映射到 `mods/<mod>/data/<filename>`。

**Alternatives**：
1. 硬编码 `kysmod.ini` → `data/kysmod.ini` —— 不如通用分支清晰。

**Consequences**：
- 未来若有其他根级文件被复制到 `data/`，自动生效。

## ADR-003: 证据文本必须与代码事实一致

**Context**：原 `EV_BUILD_INPUT` 的 text 写「kysmod.ini 由构建期解析为 CONFIG/CC 覆盖，
**不进入产物**」，且 ref 指向 `framework/mod_ini.lua`。但事实是构建器**确实**把它复制到 `data/`。

**Decision**：修正证据 text 与 ref：
- ref 改为 `game/tools/mod_build.lua`（复制行为所在）
- cmd 改为 `grep -n 'kysmod' tools/mod_build.lua`
- text 明确「构建器复制到 data/（mod_build.lua:879-882）；引擎不读」

**Alternatives**：
1. 保留原文本 —— **错误**：证据与代码矛盾，违反 REQ-EVID 的「证据必须可复核」。

**Consequences**：
- 证据可被 `grep` 复核。
- `runEvidence` 实际执行该 cmd 并断言含 `kysmod`。

## ADR-004: 用派生断言替代硬编码计数

**Context**：测试原硬编码 `1995`（未进产物）、`9145`（REQUIRED）、`663`（PENDING）。
`in_product` 语义修正后这些数字漂移，导致 35 个失败。

**Decision**：把断言改为**从审计结果派生**：

```lua
local expNotInProduct = 0
for _, r in ipairs(a.recs) do if not r.in_product then expNotInProduct = expNotInProduct + 1 end end
TestHelper.assertEquals(expNotInProduct, n, ...)
```

**Alternatives**：
1. 手工更新为 `1975`/`9145`/`663` —— 可行但下次改动又会漂移。
2. 派生断言 —— **采用**。既验证「计数与记录一致」，又不锁定具体数字。

**Consequences**：
- 测试更稳健。
- 新增 `testKysmodIniIsBuildInputButShipped` / `testCcDictsAreBuildInputAndNotShipped`
  锁定语义（一个 `true`，一个 `false`）。

## ADR-005: 测试写产物 `save/` 必须备份+恢复

**Context**：本 change 再次发现 `test_mod_boot.lua` 也会销毁 mingdong 的 `r1.grp`
（`os.execute("rm -f mods/mingdong/save/r1.grp ...")` + `SaveRecord(1)`）。
这是与 `mod_check_one.lua` 同源的缺陷。

**Decision**：在 `test_mod_boot.lua` 中同样实施备份 + 恢复，并新增
`testProductSavesNotDestroyedByTests`（在 `runAll` **末位**执行，断言全部 MOD 的
`r1.grp` 与源逐字节一致）。

**Alternatives**：
1. 让测试写到临时目录 —— `SaveDir()` 由 `ModData` 决定，不易注入；且测试目的正是
   验证 MOD 存档隔离（必须走真实路径）。

**Consequences**：
- 测试不再破坏产物。
- 末位断言可捕获任何未来引入的同类缺陷。

## Negative Constraints（负向约束）

1. **不得修改** `game/engine-love2d/**`、`game/engine-mud/**`。
2. **不得修改** `game/script/jyconst.lua` 常量定义。
3. **不得修改** `reference/allmods/**`。
4. **不得**用类别级一刀切判定 `in_product`（ADR-001）。
5. **不得**保留与代码事实矛盾的证据文本（ADR-003）。
6. **不得**用「均回退原版」这类笼统表述（REQ-STRV-2）。
7. **不得**硬编码会漂移的计数（ADR-004）。

## Review Checklist

- [ ] 21 项基准独有全部有判定
- [ ] MOD 独有内容用非基线值证明
- [ ] `kysmod.ini` `in_product=true`（20/20）
- [ ] `cc/*.txt` `in_product=false`
- [ ] 矛盾数 = 0
- [ ] 证据文本与代码一致且可 `grep` 复核
- [ ] 零引擎改动
- [ ] 零回归
- [ ] 测试不破坏产物 `save/`
