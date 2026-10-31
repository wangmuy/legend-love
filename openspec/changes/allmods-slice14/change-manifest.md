---
status: done
parent_slice: allmods-slice14
parent_epic: 2026-10-allmods-compat
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Change Manifest: allmods-slice14

> 本 slice 将一个 MOD（kys-dream 笑梦游记）的端到端适配拆成 2 个 spec-driven 子 change。
> 子 change 之间通过下方 **Contracts** 传递可验证接口。

## 子 change 列表

| # | 子 change | 依赖 | 状态 |
|---|-----------|------|------|
| 1 | `allmods-dream-activate` | Slice 0/0b/0c | [x] done |
| 2 | `allmods-dream-verify` | 子 change #1 | [x] done |

## 执行顺序

```
allmods-dream-activate  →  allmods-dream-verify
    (构建+机器验证)            (内容审计+报告)
```

## Contracts

### Contract A：构建产物

`activate` 必须产出 `game/mods/dream/` 并满足：

| 项 | 值 |
|----|----|
| `data files` | 280（构建器口径，**不含**生成的 `ranger.str`；目录实测 **281**） |
| `saves` | 27（产物 `save/` 实测 27 个槽 `.grp`；源 `save/` 为 31，另 4 个改道 `data/`） |
| `sound` | 77 |
| `events` | 4569 |
| `talk` | 6464 |
| `fight*.grp` | 122（+ 1 孤儿 `fight23.idx` = 245 个 fight 文件） |
| `hdgrp` 条目 | 484（`hdgrp.idx` 1936B） |
| 记录段 | 409 / 192 / 122 / 102 / 6 |

**消费方**：`verify` 的全部审计与报告。

### Contract B：穷举审计

`lua tools/mod_audit.lua --mod dream` 必须输出：

```
total=416 in_product=383 not_in_product=33 unclassified=0 bad_evidence=0
```

且 Σ(类别) = 416 = 源文件总数（不变量：审计对象 = 源文件全集）。

类别分布：`REQUIRED 378 / REQUIRED_CONVERTED 4 / LEGACY 3 / DEAD_FILE 1 / BUILD_INPUT 1 / PENDING 29`。

**消费方**：`verify` 的 §diff 审计与 not_in_product 分类。

### Contract C：字节级覆盖

`lua tools/format_spec.lua --mod dream` 必须输出 `formats=12 checked=225 gaps=0`。

**消费方**：`verify` 判定「内容差异 vs 结构异常」。

### Contract D：启动链路

`lua tests/unit/boot_one_mod.lua dream 409 192 122 102 隨小破` 必须输出 `RESULT dream: OK`
（16 断言全 PASS；扫描字段 1618，U+FFFD = 0，控制符 = 0，10 帧无报错）。

**消费方**：`verify` 的端到端结论。

### Contract E：记录段 / `hdgrp` / idx 修复判据

| 项 | 实测 | 判据 | 结论 |
|----|------|------|------|
| `hdgrp` | 484（`hdgrp.idx` 1936B） | 索引驱动 `idxlen/4` + 无固定计数常量 + `gaps=0` | 内容差异（**第 7 次应用**） |
| Person 409 | 74438/182 | 整除 + 边界记录可读（`Person[408]`=我是倉庫） | 内容差异 |
| Thing 192 | 36480/190 | 整除 + 边界记录可读（`Thing[191]`=降龍十八掌） | 内容差异 |
| Scene 122 | 6344/52 | 整除 + 边界记录可读（`Scene[121]`=主角居） | 内容差异 |
| Wugong 102 | 13872/136 | 整除 + 边界记录可读（`Wugong[101]`=蛤蟆功） | 内容差异 |
| Shop 6 | 300/50 | 整除 | 内容差异 |
| 源 `ranger.idx` | **完好**（24B，offsets `[836,75274,111754,118098,131970,132270]`，5 段长全部整除） | 无需修复；`RepairIdx` **未触发**（`encoding-report.md` 无 `idxRepaired`） | **无修复（勘误）** |
| `eft` | **714**（`eft.idx` 2856B / `eft.grp` 691627B，offs `offs[0]=77`，713 段全 RLE、零 0） | `md5(eft.idx)` 与 `md5(eft.grp)` **均与基线相同** + `diff.md` 中无 `eft.` 条目（排除回退假象） | **零改动（epic 唯一）** |
| `kdef.grp` | 206286B，末 offset 206274 ⇒ **12B 尾部残留** | 源侧 `md5` **完全相同** ⇒ 忠实搬运 | **非截断（不修）** |
| `ranger.str` | **763** 条（770 行 − 7 注释行；首个数据行为第 5 行） | 分段 `Person 243 + Thing 343 + Scene 82 + Wugong 95 = 763`；字段 `Name 513 + Nick 82 + Desc 168 = 763`；与 `encoding-report.md` 旁路表 763 一致 | **一致** |
| `diff.md` | `added 156` / `removed 105` | **双向对称差均为空集**（集合相等，非数量相等） | **集合相等** |

> **勘误（实测修正）**：本 manifest 初稿称「源 `ranger.idx` 损坏，5 段长全不可整除，
> 构建期 `RepairIdx` 修复，为 zheng 之后第 2 案例」——**实测为误**。
> dream 源 `save/ranger.idx` 为 24B / 6 offsets，段长 `[74438, 36480, 6344, 13872, 300]`
> **全部整除**（182/190/52/136/50），末 offset `132270` == `ranger.grp` 大小，**完好无损**。
> `mod_build` 日志与 `encoding-report.md` 均无 `RepairIdx` 触发记录。
> ⇒ dream **不是** `RepairIdx` 案例；zheng 仍是唯一案例。

记录段判据为**统一判据第 3 次应用**（lyff 1 段 → ptt 4 段 → dream 5/5 段全异），
且 CC 尺寸实测全部为标准值（182/190/52/136/50），排除 MOD 自定义布局变量。

**消费方**：`verify` 的 ADR-001 / ADR-004。

### Contract F：71 场额外战斗清单

`mods/dream/diff.md` 的 `+ fightNNN.grp` 条目必须为 **71 对（142 文件）**，
源 `reference/allmods/kys-dream/fight/`（245 文件）与产物 `data/`（245 文件）1:1 对应，
抽样（`fight023`/`fight316`/`fight479`）源==产物字节一致，
且审计中全部 `fight*.grp` 为 `REQUIRED` + `in_product=true`。

**实测补充（四象限，含删除象限）**：

```
基线 92 组 = A 2（同名同容）+ B 49（同名异容）+ E 41（被删除，回退原版）
MOD 122 组 = A 2 + B 49 + C 71（MOD 独有）
自洽：A+B+E = 2+49+41 = 92 ✅    A+B+C = 2+49+71 = 122 ✅
92 − 41 + 71 = 122 ✅
D（零字节）= 0
```

> dream 是 **三分法结构**（保留 2 + 改写 49 + 删除 41 + 新增 71），
> 与 books（保留 89 + 改写 3 + 新增 86 + 零字节 2）和
> pineapple（保留 2 + 改写 90 + 新增 62 + 零字节 115）**三者互不相同**。
> ⇒ 四象限必须**扩展为「保留/改写/删除/新增/零字节」五分类**，共 20 个 MOD 的
> fight 形态已出现三种不同模式，任何单一计数口径都会漏项。

**消费方**：`verify` 的 §额外战斗三重确认。

### Contract G：基准独有 105 项逐项定性

`verify` 必须把 `diff.md` 的「基准独有 105 项」**逐项**归入 4 类之一，且 Σ=105：

| 类别 | 预期项数 | 内容 |
|------|---------:|------|
| 在 `save/`（源提供，字节一致） | 9 | `d1`/`d2`/`d3`/`r1`/`r2`/`r3`/`s1`/`s2`/`s3` 的 `.grp` |
| 首次播种（`.idx` 源不存在） | 9 | 同上 9 槽的 `.idx`（`SeedSaveSlot` 从 `ranger.idx` 播种） |
| 回退原版 | 84 | `thing.grp`/`thing.idx` + 41 场被删基线战斗（82 文件） |
| 死文件 | 3 | `alldef.idx`/`allsin.idx`/`allsinbk.grp` |

**消费方**：`verify` 的 ADR-001。

### Contract H：存档完整性

产物 `save/` **27** 文件，源 `save/` **31** 文件；27 个槽 `.grp`
（d/r/s × {1,2,3,4,5,6,7,9,11} —— **源缺 8 号槽**，作者删除）**逐字节一致 27/27**。

源 `save/` 多出的 4 个（`alldef.grp`/`allsin.grp`/`ranger.grp`/`ranger.idx`）
被**改道到产物 `data/`**：前 3 个 md5 相同，`ranger.grp` 因 UTF-8 编码转换而不同
（大小均为 132270B）。无 `save.zip`。

> **勘误（实测修正）**：初稿写「产物 `save/` 31 文件与源 31 文件逐字节一致」——**实测为误**。
> 产物 `save/` 实测 **27** 个文件（全为槽 `.grp`，无 `.idx`），源 `save/` 为 31。
> 差额 4 个是改道 `data/`，不是「逐字节一致」。

**消费方**：`verify` 的 ADR-003。

## 验证策略

每个子 change 的 `verification.md` 必须含：
1. REQ 追溯矩阵
2. 实测命令与输出
3. Blast Radius 合规检查
4. 偏差记录

## 状态汇总

| 子 change | tasks | verification | status |
|-----------|-------|--------------|--------|
| `allmods-dream-activate` | [x] 39/39 | [x] PASS / 9 REQ | done |
| `allmods-dream-verify` | [x] 61/61 | [x] PASS / 10 REQ | done |

合计：**100 个 task 全勾**，**19 个 REQ 全 PASS**，**0 内容缺陷 / 0 构建缺陷 / 0 工具缺陷**。

| 交付物 | 行数 | 内容 |
|--------|-----:|------|
| `allmods-dream-activate/proposal.md` | 158 | REQ-DRM-1~9 + In/Out Scope + Blast Radius |
| `allmods-dream-activate/design.md` | 229 | ADR-DRM-001~005 + 15 NC + Checklist 11 |
| `allmods-dream-activate/specs/.../spec.md` | 218 | 9 个 REQ Given/When/Then |
| `allmods-dream-activate/tasks.md` | 121 | 39 项全 `[x]` |
| `allmods-dream-activate/verification.md` | 326 | 9 REQ 实测 + 4 项偏差记录 |
| `allmods-dream-verify/proposal.md` | 203 | REQ-DRMV-1~10 + In/Out Scope + Blast Radius |
| `allmods-dream-verify/design.md` | 284 | ADR-DRMV-001~006 + 18 NC + Checklist 10 |
| `allmods-dream-verify/specs/.../spec.md` | 288 | 10 个 REQ Given/When/Then |
| `allmods-dream-verify/tasks.md` | 142 | 61 项全 `[x]` |
| `allmods-dream-verify/verification.md` | 434 | 10 REQ 实测 + 4 项偏差记录 |
| `allmods-dream-verify/reports/dream-verify.md` | 316 | 独立报告，7 个独特性章节 |
