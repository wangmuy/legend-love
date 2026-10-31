---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice6
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Design: allmods-godsdevils-activate

## Context

GodsDevils 是**第 2 梯队最后一个**，hdgrp 129（vs 115），kdef 1123（vs 1018），
talk 4640（vs 2977）。它也是本 epic 含**最多 `EDITOR_DUMP` 文件**的 MOD：
`head/` 79 PNG + `item/` 200 PNG = 279 个。

## ADR-001: `hdgrp` 129 差异复用 Slice 5 判据（已外推成功）

**Context**：Slice 5 建立了 `hdgrp` 差异的三重判据并声明「可外推」。本 change 是
**第一次外推验证** —— 若判据正确，GodsDevils 应同样零引擎改动。

**Decision**：直接应用 Slice 5 判据，不重新推导：

| 条件 | 判据 |
|------|------|
| 索引驱动 | `PicLoadFile` 用 `idxlen/4`（`lib_love.lua:437`） |
| 无固定计数 | `CC` 中无 `HDGRPNum` 等常量 |
| 字节全覆盖 | `format_spec --mod GodsDevils` → `gaps=0` |

**Alternatives**：
1. 为每个 MOD 重新推导 hdgrp 加载机制 —— 冗余，且 Slice 5 已证明机制相同。

**Consequences**：
- **判据外推成功**（`hdgrp` 516 字节 = 129 × 4，`gaps=0`，零引擎改动）。
- 第 3~5 梯队可继续复用。

## ADR-002: `head/`/`item/` PNG = `EDITOR_DUMP`，证据来自构建器 `IGNORE_DIRS`

**Context**：GodsDevils 含 279 个 PNG（`head/` 79 + `item/` 200）。
需证明引擎不读，且证据必须**结构化**（非「看起来像编辑器产物」）。

**Decision**：证据链：

1. **构建器显式忽略**：`game/tools/mod_build.lua:567`
   ```lua
   local IGNORE_DIRS = { head = true, item = true, eft = true }
   ```
   这三类目录**不复制到产物**。

2. **引擎无引用**：`grep -rn "head/\|item/" game/script/*.lua game/framework/*.lua`
   → **0 命中**。

3. **引擎读的是 `.grp`**：头像走 `CC.HeadPicFile`（`hdgrp.idx`/`hdgrp.grp`），
   物品走 `CC.ThingPicFile`（`thing.idx`/`thing.grp`）—— 均为打包格式，非 PNG 目录。

4. **审计规则**：`mod_audit.lua` 的 `["head|.png"]`/`["item|.png"]` 规则
   → `category="EDITOR_DUMP"`, `needed=false`, `evidence={EV_UPEDIT_DUMP}`
   （`EV_UPEDIT_DUMP` 引用 `IGNORE_DIRS` 且可被 `grep` 复核）。

**Alternatives**：
1. 只写「编辑器产物」注释 —— 不可机器验证（违反 Slice 0c 负约束）。
2. 删除这些目录 —— 不得修改 `reference/allmods/**`。

**Consequences**：
- 279 个文件有**可复核的结构化证据**。
- `needed=false` 且 `in_product=false` 由类别默认值处理。

## ADR-003: 6 个存档文件检验缺陷 D 修复的持久性

**Context**：Slice 5 修复了 `mod_check_one` 的 `SLOTS` 遗漏 `d1`/`s1` 槽。
GodsDevils 有 **6 个**源自带存档（`d1`/`d2`/`r1`/`r2`/`s1`/`s2`）——
比 Slice 5 更多，是检验修复的好案例。

**Decision**：验证：
1. 产物 9 个 save 文件（`d11`/`r11`/`s11` + `d1`/`d2`/`r1`/`r2`/`s1`/`s2`）与源逐字节一致
2. 运行 `mod_check`（调用 `mod_check_one`）后仍一致
3. 全量测试后仍一致
4. `testProductSaveSlotMatchesSource` 覆盖全部源 save 文件

**Alternatives**：
1. 只验证 `r1.grp` —— 会漏掉 `d1`/`d2`/`r2`/`s2`（Slice 5 教训）。

**Consequences**：
- 缺陷 D 修复的**持久性**被验证。
- 若修复不完整（如漏 `d2`/`s2`），本 MOD 会暴露。

## ADR-004: 测试写产物 `save/` 必须备份+恢复

**Context**：沿用 Slice 2/3/5 教训。

**Decision**：任何写入 `mods/GodsDevils/save/` 的验证都必须：备份 → 验证 → 字节级恢复。

**Consequences**：
- 验证后 `save/` 与源逐字节一致。

## Negative Constraints（负向约束）

1. **不得修改** `game/engine-love2d/**`、`game/engine-mud/**`。
2. **不得修改** `game/script/jyconst.lua` 常量定义。
3. **不得修改** `reference/allmods/**`（包括不得删除 `head/`/`item/`）。
4. **不得**把 `hdgrp` 129 差异判定为结构异常（ADR-001）。
5. **不得**把 `head/`/`item/` PNG 判为「需要」而无证据（ADR-002）。
6. **不得**在验证中破坏 GodsDevils 的 6 个源自带存档（ADR-004）。
7. **不得**用「记录数相同」作为 MOD 内容已加载的证据（fight 92 == pascal 92，无区分度）。

## Review Checklist

- [ ] 构建退出码 0，`events=1123`
- [ ] `mod_audit --mod GodsDevils` `unclassified=0`
- [ ] 「必需但未进产物」矛盾 = 0
- [ ] `format_spec --mod GodsDevils` `gaps=0`
- [ ] `hdgrp.idx` = 129 条目
- [ ] `head/`/`item/` 279 个 `EDITOR_DUMP` 有证据
- [ ] `boot_one_mod` `RESULT GodsDevils: OK`
- [ ] 6 个存档文件与源一致（含 `mod_check` 与全量测试后）
- [ ] 零引擎改动
- [ ] 零回归
