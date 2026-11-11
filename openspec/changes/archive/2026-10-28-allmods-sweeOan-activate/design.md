---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice2
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Design: allmods-sweeOan-activate

## Context

Slice 0/0b/0c 已建立：
- `ModData` 回退链（`mods/<mod>/data/` → `data/`）
- `ALIAS_MAP`（`sdx/smp/wdx/wmp` → `smap.*`/`wmap.*`）
- 音效回退（`sound/` 复制到平级目录）
- `mod_audit.lua` 逐文件穷举（11220 文件 → 10 类别，无兜底）
- `format_spec.lua` 字节级覆盖（12 格式族，区间模型）

SweeOan 与基线同形，因此本 change 的核心问题是：**地基是否需要为 SweeOan 做任何改动？**

## ADR-001: 零引擎改动的验证策略

**Context**：SweeOan 的 hdgrp 115 / fight 92 / 全部格式尺寸与 pascal 一致。
但「同形」是基于文件尺寸的推断，不是基于运行结果的证据。

**Decision**：本 change **不预设零改动**，而是用**穷举审计 + 真实启动链路**两条独立证据链
来**证伪或确认**该推断。若审计或启动链路失败，则修复并记录；若通过，则记为
「同形 MOD 零改动通过」的数据点。

**Alternatives**：
1. 只跑启动链路（抽样）—— 被 Slice 0c 的「抽样驱动」教训否决。
2. 只跑审计（静态）—— 无法证明运行时行为。
3. 只比对文件尺寸 —— 无法发现内容级问题（如 idx 损坏、编码错误）。

**Consequences**：
- 需要两条证据链都通过才算 PASS。
- 后续第 1 梯队 MOD（stronger、lostbook）可复用同一模板。
- 若 SweeOan 通过而 stronger 失败，则「同形」推断被证伪，需重新审视排序依据。

## ADR-002: 逐文件穷举审计作为 DoD 的组成部分

**Context**：Slice 0c 之前，DoD 是「抽样驱动」（`diff.md` 只比对 `data/` 目录，
`head/`/`item/`/`eft/`/`music/`/`cc/`/`list/` 是盲区）。

**Decision**：本 change 的 DoD **强制包含**：
1. `mod_audit --mod SweeOan` → `unclassified=0`
2. **无「必需类但未进产物」矛盾**
3. `format_spec --mod SweeOan` → `gaps=0`

即：**334 个源文件全部被归类，每个进产物的字节都归属具名字段**。

**Alternatives**：
1. 只检查 `data/` 目录（旧 DoD）—— 会漏掉 `music/`（27 个 PENDING）、`list/`（4 个）等。
2. 只检查「必需」类别 —— 会漏掉「声称必需但实际没进产物」的矛盾。

**Consequences**：
- 审计时间增加（SweeOan 334 文件，全量 11220 文件）。
- 换取「每个文件都被检查到」的机器保证。

## ADR-003: 独立进程启动验证（而非同进程重载）

**Context**：`test_mod_boot.lua` 在同进程内反复重载 `jymain`/`lib` 会留下 `JY` 全局残留，
反而**不能证明真实启动路径**。

**Decision**：用 `tests/unit/boot_one_mod.lua` 在**独立进程**中运行，期望值通过命令行参数传入
（`SweeOan 320 200 84 93 王小石`），而非硬编码。

**Alternatives**：
1. 同进程 `pcall` 重载 —— 全局残留导致假阳性/假阴性。
2. 硬编码期望值 —— 修改 MOD 数据后测试不会失败。

**Consequences**：
- 每次验证启动一个新 Lua 进程（~1s 开销）。
- 期望值来自 MOD 源数据（`mod_check_one.lua` 的实测输出），可独立复核。

## Negative Constraints（负向约束）

1. **不得修改** `game/engine-love2d/**`、`game/engine-mud/**`（除非审计发现真实缺陷且经评估）。
2. **不得修改** `game/script/jyconst.lua` 的常量定义。
3. **不得修改** `reference/allmods/**`（只读参考数据）。
4. **不得**在测试中硬编码 MOD 尺寸（须从源数据推导）。
5. **不得**引入 `OTHER`/`UNKNOWN` 兜底类别。

## Review Checklist

- [ ] 构建退出码 0，`events=1018`
- [ ] `mod_audit --mod SweeOan`：`unclassified=0 bad_evidence=0`
- [ ] 「必需但未进产物」矛盾数 = 0
- [ ] `format_spec --mod SweeOan`：`gaps=0`
- [ ] `mod_check_one`：`STRINGS/EVENTS/SAVE=OK`
- [ ] `boot_one_mod`：`RESULT SweeOan: OK`
- [ ] 资源路径全部指向 `mods/SweeOan/`
- [ ] 无引擎代码改动
- [ ] 全量测试全绿
