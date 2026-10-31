---
status: done
created: 2026-10-25
---

# Proposal: allmods-riverlake-verify

> 父上下文：epic [`2026-10-allmods-compat`](../../epics/2026-10-allmods-compat/epic.md)，
> slice [`allmods-slice10`](../allmods-slice10/slice-proposal.md)。
> 兄弟 change：[`allmods-riverlake-activate`](../allmods-riverlake-activate/proposal.md)（已完成）。
>
> 本 change 对 `kys-RiverLake` 的**激活结果做独立验证**：审计 `diff.md`、
> 定性「基准独有」21 项、生成报告、确认零回归。

## 1. 为什么需要这个 change

`activate` 证明了「MOD 能加载、计数正确、内容来自 MOD」。但**不能**证明：

1. 差异报告（`diff.md`）里声称的每一项差异都有合理解释；
2. 「基准独有」的 21 项到底是「MOD 不需要」还是「被构建丢了」；
3. MOD 独有 268 项是否全部被正确归类（没有漏、没有硬凑）；
4. 本 slice 的改动没有破坏前 9 个 slice 的成果。

这 4 项是**独立的验证面**，需要单独的可复核证据链。

## 2. In Scope

- 审计 `mods/RiverLake/diff.md`：MOD 独有 268 / 基准独有 21 的逐项归类。
- 21 项「基准独有」的**四类定性**（源自带存档 / 首次播种 / 回退原版 / 死文件），每项带机器可复核证据。
- 268 项 MOD 独有按类别归入 `mod_audit` 类目，确认 `unclassified=0`。
- 27 项 `PENDING` + 5 项 `LEGACY` + 1 项 `BUILD_INPUT` 的显式证据。
- 确认两项范围外发现的记录完整性（`CC.Effect` 截断、44 个空 `fight`）。
- 生成 `reports/riverlake-verify.md`。
- 零回归确认（1842/1842 + 全门禁）。

## 3. Out of Scope

- **不修复** `CC.Effect` 截断缺陷（ADR-003 已说明：`jyconst.lua` 禁改 + 需改 20 MOD 审计分类）。
- **不修复** 44 个 0 字节 `fight*.grp`（ADR-007 已说明：源既有、保留以维持索引语义）。
- **不**把 `list/effect.bin` 从 `PENDING` 提升为 `REQUIRED`（属上条修复的一部分）。
- 不实现 Slice 11+（Dragon / pineapple / books）。

## 4. 需求

### REQ-RIVV-1 `diff.md` 差异报告审计
必须逐项重算 `diff.md` 的「MOD 独有 268」与「基准独有 21」，与实际文件系统对账，
证明报告无遗漏、无虚报。

### REQ-RIVV-2 「基准独有」21 项四类定性
每项必须落入且仅落入以下一类，且带机器可复核证据：

| 类别 | 判据 |
|------|------|
| **在 save/（源自带存档）** | 源 `save/` 存在同名文件且产物逐字节一致 |
| **首次播种** | 源不存在、产物不存在，首次保存时由 `SeedSaveSlot` 从 MOD `ranger.idx` 派生 |
| **回退原版** | 源不存在、产物不存在，运行时从 `data/` 读取（`RewriteConstants` 回退链） |
| **死文件** | 常量存在但引擎从不读取该文件（须有代码级证据，如形参未使用） |

**负约束**：不得用「不确定」「待查」笼统带过；不得把「首次播种」误归为「回退原版」或「死文件」。

### REQ-RIVV-3 268 项 MOD 独有全量归类
`mod_audit --mod RiverLake` 必须 `unclassified=0 bad_evidence=0`，
且 268 项全部落入具名类别，其中 `fight` 127 项、非 fight 141 项。

### REQ-RIVV-4 `not_in_product` 33 项显式证据
`PENDING 27` + `LEGACY 5` + `BUILD_INPUT 1` = 33，每类必须有结构化证据，
且每项不得用「不需要」无证据带过。

### REQ-RIVV-5 范围外发现记录完整性
`CC.Effect` 截断与 44 个空 `fight` 两项必须在本 change 的 verification 与
`reports/riverlake-verify.md` 中都有记录，含受影响 MOD 清单与「不修复理由」。

### REQ-RIVV-6 零引擎改动 + 零回归
- `game/engine-love2d/**`、`game/engine-mud/**`、`game/script/jyconst.lua` 常量定义、
  `reference/allmods/**` **零改动**。
- 全部 8 道门禁通过，测试总数不下降。

### REQ-RIVV-7 报告产出
`reports/riverlake-verify.md` 必须包含：21 项定性表、268 项归类表、33 项未进产物表、
2 项范围外发现、门禁结果。

## 5. Blast Radius

| 路径 | 允许 | 说明 |
|------|:----:|------|
| `openspec/changes/allmods-riverlake-verify/**` | ✅ 写 | 本 change 的 artifacts |
| `openspec/changes/allmods-slice10/**` | ✅ 写 | manifest 收尾 |
| `openspec/epics/2026-10-allmods-compat/**` | ✅ 写 | epic / TODO 进度 |
| `game/tests/unit/test_mod_resources.lua` | ✅ 写 | 缺陷 F 修复（自愈重建） |
| `game/mods/RiverLake/**` | ✅ 写 | 播种测试临时产物（**须清理**） |
| `game/engine-love2d/**` | ❌ 禁 | 引擎 |
| `game/engine-mud/**` | ❌ 禁 | 引擎 |
| `game/script/jyconst.lua` 常量定义 | ❌ 禁 | 常量 |
| `reference/allmods/**` | ❌ 禁 | 只读参考 |

## 6. 交付物

| 文件 | 内容 |
|------|------|
| `proposal.md` | 本文件 |
| `design.md` | ADR-001~004（定性判据、缺陷 F、范围外记录策略、报告结构） |
| `specs/allmods-riverlake-verification/spec.md` | GWT 场景 |
| `tasks.md` | 分组任务 + Blast Radius + DoD |
| `verification.md` | 实施后逐条验证 |
| `reports/riverlake-verify.md` | 可复核报告 |
