---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice9
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Design: allmods-ptt-verify

## Context

ptt 是第 3 梯队收官（第 3 个）。独特之处：**4 段记录数全部异于基线**（本 epic 首个）、
**70 场额外战斗**（本 epic 最多）、**18 个源自带存档槽**（本 epic 最多）、
105 个 `eft/` PNG 的 `EDITOR_DUMP`。本 change 复核 activate 的机器验证结果，
做人工可复核的内容审计。

## ADR-001: 记录段差异的判定 = 「索引驱动 + 无固定计数 + 字节全覆盖 + 边界有效」

**Context**：ptt **4 段记录数全部异于基线**（Person 385 / Thing 214 / Scene 90 / Wugong 108
vs 320/200/84/93），是本 epic 首个全段差异 MOD。必须判定这是内容差异而非布局损坏。

**Decision**：四重判据（Slice 8 统一判据的第 2 次应用）：

| 条件 | 实测 |
|------|------|
| 段长整除记录大小 | 70070=385×182 / 40660=214×190 / 4680=90×52 / 14688=108×136 / 150=3×50，**全部整除无余数** |
| 索引驱动 | `JY.PersonNum = math.floor((idx[2]-idx[1])/CC.PersonSize)`（`jymain.lua:1747`）；Thing/Scene/Wugong 同构 |
| 无固定计数常量 | 全仓库无 `PERSON_NUM` 类常量；`CC.PersonSize` 等是**记录大小**而非**条目数** |
| 边界有效 | 末条记录（Person[384]/Thing[213]/Scene[89]/Wugong[107]）字段含有效 hint（`P0489`/`N0448`/`T0395`/`T20395`/`TD0395`/`S0088`/`W0107`）且运行时名称可读（卓不凡/高昌迷宮地圖） |
| 字节全覆盖 | `format_spec --mod ptt` → `gaps=0` |

**Alternatives**：
1. 「记录数与基线不同 → 需改引擎」—— 被索引驱动事实否定（零引擎改动即可解决）。
2. 「硬编码 320/200/84/93」—— 违反 Slice 8 负约束（`PersonNum` 必须索引推导）。
3. 「记录数相同 = 内容已加载」—— 被负约束禁止；且 ptt 记录数**不同**，此路不通。

**Consequences**：
- 4 段差异均判定为**内容差异**（+65/+14/+6/+15），零引擎改动。
- 判据可外推到第 4~5 梯队（RiverLake/Dragon/pineapple/books 的记录段差异）。

## ADR-002: `hdgrp` 204 判据的第 5 次应用

**Context**：ptt `hdgrp` 204（vs 115，+89）。需确认仍为索引驱动。

**Decision**：三重判据（Slice 5 ADR-001，第 5 次应用）：

| 条件 | 实测 |
|------|------|
| 索引驱动 | `hdgrp.idx` = 816 B = 204 × 4；`PicLoadFile` 用 `idxlen/4`（`lib_love.lua:437`） |
| 无固定计数 | `CC.HDGRPNum`/`CC.HDPicNum`/`CC.MAX_HEAD_NUM`/`CC.HDGRP`/`CC.HeadNum` 全 `nil` |
| 字节全覆盖 | `format_spec --format hdgrp --mod ptt` → `gaps=0` |

**Alternatives**：
1. 「hdgrp 条目数不同 = 结构异常」—— 已被 Slice 5/6/7/8 逐步否定（125/129/173/178 均无问题）。

**Consequences**：
- 外推链：**125 → 129 → 173 → 178 → 204**，五次一致。
- 后续所有 hdgrp ≠ 115 的 MOD 均按此判据。

## ADR-003: 「基准独有」21 项的 4 类定性 —— 新增「首次播种」

**Context**：21 项「基准独有」。前序 slice 用 3 类（回退原版 / 在 save/ / 死文件）。
ptt 的 18 个源槽只有 `.grp`，**9 个 `.idx` 源不存在** —— 这既不是「回退原版」
（引擎不会去 `data/` 读 `r1.idx`），也不是「在 save/」（源就没有），
必须新增第 4 类。

**Decision**：逐项定性：

| 性质 | 判据 | ptt 项数 |
|------|------|---------:|
| 在 save/（源自带 `.grp`） | `mods/ptt/save/<f>` 存在且与源逐字节一致 | 9（`d1`~`d3`/`r1`~`r3`/`s1`~`s3` 的 `.grp`） |
| **首次播种（源无 `.idx`）** | 源 `save/` 无 `rN.idx`/`dN.idx`/`sN.idx`；运行时 `ModData.SeedSaveSlot(id)` 从 `data/ranger.idx` 播种 | 9（对应的 `.idx`） |
| 回退原版 | `CC.ThingPicFile[1]`/`[2]` = `data/thing.idx`/`data/thing.grp`（MOD 未提供） | 2（`thing.grp`/`thing.idx`） |
| 死文件 | `CC.TempS_Filename` 仅作 `LoadSMap` 第 2 实参，引擎形参 `tmpfilename` 零使用 | 1（`allsinbk.grp`） |
| **Σ** | | **21** |

**「首次播种」机制实测**（本 change 验证）：

```
播种前 mods/ptt/save/r1.idx: false
ModData.SeedSaveSlot(1) → "mods/ptt/save/r1.idx"
播种后存在: true；与 data/ranger.idx 逐字节一致: true
```

**Alternatives**：
1. 把 9 个 `.idx` 归「回退原版」—— 错误：引擎读 `CC.R_IDXFilename[1] = mods/ptt/save/r1.idx`，
   不回退 `data/`。
2. 把 9 个 `.idx` 归「死文件」—— 错误：它们是存档必需项，`SaveRecord` 直接读它。
3. 笼统写「均在 save/ 或回退」—— 违反负约束。

**Consequences**：
- 21 项无一未解释，「首次播种」成为后续 MOD 的标准类别（与 Slice 6/7 的
  「播种槽归在 save/（首次播种）」一致，但 ptt 是**首次显式拆分 `.grp`/`.idx`**）。

## ADR-004: 154 项 MOD 独有的分类

**Context**：ptt 的 MOD 独有项达 **154 项**（本 epic 最多）。

**Decision**：按类别分解：

| 类别 | 项数 | 审计类别 |
|------|-----:|----------|
| 额外战斗（70 场 × 2） | 140 | `REQUIRED` |
| `kdef.grp`/`.idx` | 2 | `REQUIRED_CONVERTED` |
| `talk.grp`/`.idx` | 2 | `REQUIRED_CONVERTED` |
| `cloud.grp`/`.idx` | 2 | `REQUIRED` |
| `title.grp`/`.idx` | 2 | `REQUIRED` |
| `end.png`/`open.png` | 2 | `REQUIRED` |
| `ranger.str` | 1 | **构建产物**（源无此文件，故不在审计 596 内） |
| `kysmod.ini` | 1 | `BUILD_INPUT`（`in_product=true`） |
| `talkutf8.txt` | 1 | `BUILD_INPUT`（`in_product=false`，中间产物） |
| `save.zip` | 1 | `PLATFORM_ARTIFACT`（`in_product=false`，源压缩包） |
| **Σ** | **154** | |

**注**：`ranger.str` 是 `mod_build.lua:1174` 写入的**旁路字符串表**产物，
源目录不存在，故 `diff.md` 列出（产物 vs 源）而 `mod_audit` 不列（审计对象是**源文件**）。
`审计 total=596` 恰等于源文件总数 596，**每个源文件都被归类**。

**Alternatives**：
1. 把 `ranger.str` 也算进审计 —— 会破坏「审计对象 = 源文件全集」的不变式。

**Consequences**：
- 154 项全部有归属，需修复 = 0。

## ADR-005: 70 场额外战斗的判定 = 「索引驱动 + 三重证据」

**Context**：ptt 有 162 场战斗（pascal 92，**+70**，本 epic 最多）。

**Decision**：两层判据（复用 Slice 7 ADR-001，扩展到 70 场）：

**层 1：内容差异 vs 结构异常**

| 条件 | 实测 |
|------|------|
| 索引驱动 | `fightNNN.grp` 由脚本按编号引用；无固定数量常量 |
| 记录布局常量同 | `182`/`190`/`52`/`136` |
| 字节全覆盖 | `gaps=0` |
| `fight*.idx` 一致性 | `format_spec` `verifyPair` 通过 |

**层 2：70 场来自 MOD 的三重证据**

| # | 证据 | 实测 |
|---|------|------|
| 1 | `diff.md` 提及 | 140 项（70 场 × `.grp`+`.idx`） |
| 2 | 产物存在 | `fight*.grp` = 162；`comm -13 pascal ptt` = 70 |
| 3 | 审计归类 | 162 个 `fight*.grp` **全部** `REQUIRED`/`in_product=true`，其他类别 = 0 |

**Alternatives**：
1. 只判「内容差异」不证明来源 —— 无法排除「重命名/覆盖」。
2. 抽样 5 场即代表 70 场 —— 不够；本 change 用**全量 162 个**审计归类 + 抽样逐项复核。

**Consequences**：
- 70 场额外战斗有**三重独立证据 + 全量审计归类 + 5 场抽样复核**。

## ADR-006: 105 个 `eft/` PNG = `EDITOR_DUMP`（新增第 2 类副产物）

**Context**：ptt 源有 `eft/` 目录 105 个文件（`eftNNN.idx` + `eftNNN.png`）。
Slice 6（GodsDevils）已判定 `head/`/`item/` 为 `EDITOR_DUMP`。

**Decision**：判定 `eft/` 为 `EDITOR_DUMP`，4 条机器可复核证据：

| # | 证据 | 命令/事实 |
|---|------|-----------|
| 1 | 构建期忽略 | `mod_build.lua:567` `IGNORE_DIRS = { head=true, item=true, eft=true }` |
| 2 | 引擎 0 引用 | `grep -rn "eft/" game/script/jyconst.lua game/engine-love2d/*.lua game/framework/*.lua` → 无输出 |
| 3 | 产物中不存在 | `ls -d game/mods/ptt/eft` → 不存在 |
| 4 | 审计归类 | `105 项` 全为 `EDITOR_DUMP`/`in_product=false`/`needed=false` |

**Alternatives**：
1. 判定为「需要」—— 但无任何引擎引用证据（违反 Slice 6 ADR-002 负约束）。

**Consequences**：
- `eft/` 与 `head/`/`item/` 同族，均为 UPedit 编辑器副产物。

## ADR-007: PENDING 27 项的显式边界

**Context**：27 项 `PENDING` = `music/*.mid` 23 个 + `list/*.bin` 4 个。

**Decision**：显式声明为全局遗留 spike（epic `TODO.md` 已记录「MOD 音乐引用分析」），
**不用**「不确定」/「均回退原版」笼统表述：

| 项 | 数量 | 归属 |
|----|-----:|------|
| `music/*.mid` | 23 | 全局遗留 spike：C 引擎 MIDI（`.mid` + `mid.sf2`）vs Lua 引擎 `sound/game%02d.ogg`（25 槽）三重不匹配；需先做 spike 确定「需几首、编号怎么对应」 |
| `list/*.bin` | 4（`effect`/`leave`/`levelup`/`match`） | C 引擎列表数据（`.bin`），Lua 引擎无读取路径 |

`needed=nil`（区别于 `needed=false`）是审计工具的**显式设计**：未判定 ≠ 判定为不需要。

**Alternatives**：
1. 强行判 `needed=false` —— 缺乏证据（需要 spike）。
2. 留空不归类 —— 违反 `unclassified=0` 要求。

**Consequences**：
- 27 项有明确归属与后续动作（spike），不阻塞本 slice。
