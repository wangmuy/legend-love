---
status: done
created: 2026-10-27
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

`script/jyconst.lua:439` 的 `CC.Effect` 是**硬编码 53 项**（索引 `0..52`，sum=**712**）字面量表，
而 `framework/war_async.lua:1110` 用它算武功动画帧数、`:1121-1123` 用它算起始帧偏移：

```lua
local framenum = fightdelay + (CC.Effect and CC.Effect[eft] or 10) or 10
...
for i = 0, eft - 1 do starteft = starteft + (CC.Effect[i] or 0) end
```

`eft` 来自武功数据字段 `武功动画&音效`。当 `eft >= 53` 时两项都会静默退化：

- `CC.Effect[eft] == nil` → `framenum` 落到 `10`（不论真实效果长多少帧）
- `starteft` 求和停在 `712`（漏加越界部分，动画起始帧错位）

**权威来源**：`reference/allmods/UPedit/UPedit.ini:80` → `Effect=list\effect.bin`。
20/20 MOD **均提供** `list/effect.bin`（int16 LE 逐效果帧数表），语义链
`sum(effect.bin) == eft.idx 条目数 - 1`（`eft.idx` 为**逐帧**偏移表）。

Slice 10 提出此 spike 时估计"影响 7/20 MOD"，但当时**未实测越界条目数与运行时后果**。
本 spike 用全 20 MOD 实测把「影响面 + 后果 + 修复可行性」量化到底，供决策。

## Parent Context

- Epic: `openspec/epics/2026-10-allmods-compat/epic.md`
- Slice: `openspec/changes/allmods-slice10/change-manifest.md`（TODO「开放问题（Slice 10 新增）」）
- 相关: `game/data/effect.bin` **不存在** ⇒ 构建器未搬运 `list/effect.bin`（实测 20/20 MOD 产物均无）
- 依赖: none（只读实测 + 数据核对，不改运行代码）

## What Changes

只读 Spike，产出报告 `reports/effect-table-audit.md`，**不改运行代码**：

1. 实测 20/20 MOD 的 `list/effect.bin`（条目数、非零项、sum）与 `eft.idx` 段数的语义链
2. 实测 `CC.Effect`（53 项）与各 MOD `effect.bin` 前 53 项的逐项差异（找口径偏差）
3. 实测运行时越界后果（复现 `war_async.lua:1110/1121-1123` 逻辑）
4. 实测越界影响面（每 MOD 有多少武功 `eft > 52`，最大值多少）
5. 给出三种修复方案的影响面与代价对比，供用户决策

## Scope Boundaries

### In Scope
- 只读：源 `list/effect.bin`、产物 `eft.idx`、`CC.Effect` 字面量、`war_async.lua` 消费点
- 实测脚本与输出留档
- 报告（含三方案对比 + 决策依据）

### Out of Scope
- 任何运行代码修改（改 `jyconst.lua` 属禁改路径「`CC.*` 常量」）
- 构建器搬运 `list/effect.bin` 的实现（属后续 change）
- MOD 端到端回归（由 8 道门禁承担）

## Capabilities

### New Capabilities
- `allmods-effect-table-audit`: `CC.Effect` 硬编码表 vs `list/effect.bin` 的全 20 MOD 实测审计 + 修复方案定界（[REQ-EFF-1]~[REQ-EFF-5]）

## Traceability

| REQ | 说明 |
|-----|------|
| [REQ-EFF-1] | 20/20 MOD 的 `effect.bin` 语义链（`sum == eft 段数`）实测成立与否逐个列出 |
| [REQ-EFF-2] | `CC.Effect` 与各 MOD `effect.bin` 前 53 项逐项对比，找出偏差并判定责任方 |
| [REQ-EFF-3] | 运行时越界后果量化（`framenum` / `starteft` 实际取值） |
| [REQ-EFF-4] | 越界影响面：每 MOD `eft > 52` 的武功条目数与 `max(eft)` |
| [REQ-EFF-5] | 三方案对比（改常量 / 构建期生成 / 运行时读 `effect.bin`）+ 推荐 + 代价 |

## DoD

1. `reports/effect-table-audit.md` 产出，五个 REQ 每个都有「实测命令 + 输出 + 结论」
2. 所有数字可复现（报告附复现脚本）
3. 越界影响面用**全 20 MOD 实测**给出，不用估计值
4. 明确指出 `effect.bin` 未进产物 `data/` 这一事实及其对方案三的影响
