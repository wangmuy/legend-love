---
status: done
parent_slice: allmods-slice10
parent_epic: 2026-10-allmods-compat
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Change Manifest: allmods-slice10

> 本 slice 将一个 MOD（kys-RiverLake）的端到端适配拆成 2 个 spec-driven 子 change。
> 子 change 之间通过下方 **Contracts** 传递可验证接口。

## 子 change 列表

| # | 子 change | 依赖 | 状态 |
|---|-----------|------|------|
| 1 | `allmods-riverlake-activate` | Slice 0/0b/0c | [x] done |
| 2 | `allmods-riverlake-verify` | 子 change #1 | [x] done |

## 执行顺序

```
allmods-riverlake-activate  →  allmods-riverlake-verify
    (构建+机器验证)                (内容审计+报告)
```

## Contracts

### Contract A：构建产物

`activate` 必须产出 `game/mods/RiverLake/` 并满足：

| 项 | 值 |
|----|----|
| `data files` | 478 |
| `saves` | 21 |
| `sound` | 170 |
| `events` | 1232 |
| `talk` | 8015 |
| `fight*.grp` | 219 |
| `hdgrp` 条目 | 252 |
| `eft` 条目 | 921 |
| 记录段 | 325 / 249 / 84 / 96 |

**消费方**：`verify` 的全部审计与报告。

### Contract B：穷举审计

`lua tools/mod_audit.lua --mod RiverLake` 必须输出：

```
total=699 in_product=666 not_in_product=33 unclassified=0 bad_evidence=0
```

且 Σ(类别) = 699 = 源文件总数（不变量：审计对象 = 源文件全集）。

类别分布：`REQUIRED 661 / REQUIRED_CONVERTED 4 / LEGACY 5 / BUILD_INPUT 2 / PENDING 27`。

**消费方**：`verify` 的 §diff 审计与 not_in_product 分类。

### Contract C：字节级覆盖

`lua tools/format_spec.lua --mod RiverLake` 必须输出 `formats=12 checked=413 gaps=0`。

**消费方**：`verify` 判定「内容差异 vs 结构异常」。

### Contract D：启动链路

`lua tests/unit/boot_one_mod.lua RiverLake 325 249 84 96 茲` 必须输出 `RESULT RiverLake: OK`
（16 断言全 PASS）。

**消费方**：`verify` 的端到端结论。

### Contract E：记录段与 `hdgrp` / `eft` 判据

| 项 | 实测 | 判据 | 结论 |
|----|------|------|------|
| `hdgrp` | 252（`hdgrp.idx` 1008B） | 索引驱动 `idxlen/4` + 无固定计数常量 + `gaps=0` | 内容差异（第 6 次应用） |
| `eft` | 921（`eft.idx` 3684B） | 索引驱动 + 单调 + `idx[-1]==grp 大小` | 内容差异 |
| Person 325 | 59150/182 | 整除 + 边界记录可读 | 内容差异 |
| Thing 249 | 47310/190 | 整除 + 边界记录可读 | 内容差异 |
| Scene 84 | 4368/52 | **= 基线** | 阴性对照：段数相同 |
| Wugong 96 | 13056/136 | 整除 + 边界记录可读 | 内容差异 |

**消费方**：`verify` 的 ADR-001 / ADR-002。

### Contract F：127 场额外战斗清单

`comm -13 <pascal fight*.grp> <RiverLake fight*.grp>` 必须给出 **127** 个文件，
与 `mods/RiverLake/diff.md` 的 `+ fightNNN.grp` 条目**精确一致**，
且审计中这 219 个 `fight*.grp` 全部为 `REQUIRED` + `in_product=true`。

**消费方**：`verify` 的 §额外战斗三重确认。

### Contract G：基准独有 21 项逐项定性

`verify` 必须把 `diff.md` 的「基准独有 21 项」**逐项**归入 4 类之一，且 Σ=21：

| 类别 | 预期项数 | 内容 |
|------|---------:|------|
| 在 `save/`（源提供） | 9 | `d1.grp`/`d2.grp`/`d3.grp`/`r1.grp`/`r2.grp`/`r3.grp`/`s1.grp`/`s2.grp`/`s3.grp` |
| 首次播种（`.idx` 源不存在） | 9 | `d1.idx`/`d2.idx`/`d3.idx`/`r1.idx`/`r2.idx`/`r3.idx`/`s1.idx`/`s2.idx`/`s3.idx` |
| 回退原版 | 2 | `thing.grp`/`thing.idx` |
| 死文件 | 1 | `allsinbk.grp` |

**消费方**：`verify` 的 ADR-003。

### Contract H：空 WAV

28 个 0 字节 `sound/e72.wav`~`sound/e98.wav` 必须原样进产物（`sound` 计数 170 含它们），
且 `PlayWAV`（`lib_love.lua:602-621`）的 `pcall` 容错使运行时不报错。

**消费方**：`verify` 的 ADR-005。

## 验证策略

每个子 change 的 `verification.md` 必须含：
1. REQ 追溯矩阵
2. 实测命令与输出
3. Blast Radius 合规检查
4. 偏差记录

## 状态汇总

| 子 change | tasks | verification | status |
|-----------|-------|--------------|--------|
| `allmods-riverlake-activate` | [x] 60/60 | [x] PASS / 12 REQ | done |
| `allmods-riverlake-verify` | [x] 47/47 | [x] PASS / 7 REQ | done |

合计：**107 个 task 全勾**，**19 个 REQ 全 PASS**，0 内容缺陷 / 0 构建缺陷 / 0 工具缺陷。

> **勘误（2026-10-28 实测修正）**：本 manifest「状态汇总」初稿残留 `待实施 / pending`，
> 与顶部子 change 表（`[x] done`）自相矛盾。实测两个子 change 的 `tasks.md`
> 分别 **60/60**、**47/47** 全勾，`verification.md` 齐备，spec 中 **12 / 7** 个 REQ
> 均已 Given/When/Then 覆盖 ⇒ 实际全部完成，已按实测改写。
