---
status: done
created: 2026-10-26
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice14
---
# Tasks: allmods-dream-verify

## Blast Radius

| 路径 | 允许 | 说明 |
|------|:----:|------|
| `openspec/changes/allmods-dream-verify/**` | ✅ 写 | 本 change |
| `openspec/changes/allmods-slice14/**` | ✅ 写 | manifest 同步 |
| `openspec/epics/2026-10-allmods-compat/**` | ✅ 写 | epic 索引 |
| `game/mods/dream/**` | ⚠ 只读 | 审计对象（除 `SeedSaveSlot` 探针临时文件） |
| `game/tools/**` | ❌ 不改 | 未发现工具缺陷 |
| `game/engine-love2d/**` | ❌ 禁 | 四禁改 |
| `game/engine-mud/**` | ❌ 禁 | 四禁改 |
| `game/script/jyconst.lua` 常量 | ❌ 禁 | 四禁改 |
| `reference/allmods/**` | ❌ 禁 | 只读 |

---

## 组 1 — `diff.md` 双向集合相等（REQ-DRMV-1）

- [x] **T1.1** 解析 `diff.md`
      ▸ DoD: `added=156`，`removed=105`
- [x] **T1.2** 独立计算实测差集
      ▸ DoD: `set(data/产物data) − set(data/基线data)` = **156**；反向 = **105**
- [x] **T1.3** 集合相等（非数量相等）
      ▸ DoD: `added == 实测MOD独有` → **True**；`removed == 实测基线独有` → **True**
      ▸ DoD: 双向对称差均为 **空集**（`set()`）

## 组 2 — `removed` 105 四分法（REQ-DRMV-2）

- [x] **T2.1** 槽 `.grp` 计数
      ▸ DoD: **9**（`d1/d2/d3/r1/r2/r3/s1/s2/s3.grp`），源 `save/` 存在 **9/9**，产物 `save/` md5 一致 **9/9**
- [x] **T2.2** 槽 `.idx` 计数
      ▸ DoD: **9**，源 `save/` 存在 **0/9**（源无 idx）
- [x] **T2.3** 回退原版战斗
      ▸ DoD: `fight*.grp` **41** + `fight*.idx` **41** = **82**
- [x] **T2.4** 回退原版模板
      ▸ DoD: `thing.grp` + `thing.idx` = **2**
- [x] **T2.5** 死文件
      ▸ DoD: **3**（`alldef.idx`、`allsin.idx`、`allsinbk.grp`）
- [x] **T2.6** 闭合
      ▸ DoD: `9 + 9 + 84 + 3 + 0 = 105` ✅；`Σ分类 = removed 总数 105` → True
- [x] **T2.7** `SeedSaveSlot` 实测可用
      ▸ DoD: `SeedSaveSlot(1/2/3)` 均返回 `mods/dream/save/rN.idx`（**单返回值**，`nil` 才是失败）
      ▸ DoD: 播种产物 24B，md5 == `data/ranger.idx` → **True**
      ▸ DoD: 探针文件已清理，`save/` 恢复 27
- [x] **T2.8** 41 组被删战斗列出
      ▸ DoD: `43,46,49,50,56..65,67,68,70,71,76..83,85..88,90..93,95..99,101,102,109`

## 组 3 — `added` 156 三分拆解（REQ-DRMV-3）

- [x] **T3.1** fight `.grp` / `.idx` 分别计数
      ▸ DoD: `.grp` = **71**；`.idx` = **72**；差集 = **{23}**
- [x] **T3.2** 孤儿单列
      ▸ DoD: `142 + 1 + 13 = 156` ✅
- [x] **T3.3** 孤儿证据
      ▸ DoD: 产物 `fight23.idx` 存在 ▸ 产物 `fight23.grp` **不存在** ▸ 源同（idx 有 / grp 无）
- [x] **T3.4** 13 项非 fight 逐项溯源
      ▸ DoD: 11 项在源 `resource/`、`kysmod.ini` 在**根目录**、`ranger.str` **源中不存在**（构建生成）

## 组 4 — fight 五分类（REQ-DRMV-4）

- [x] **T4.1** md5 分 A/B
      ▸ DoD: `A=2`（同名同容）▸ `B=49`（同名异容）
- [x] **T4.2** 删除象限 E
      ▸ DoD: `E=41`，且 == `removed` 中 `fight*.grp` 条数（**两处独立计算一致**）
- [x] **T4.3** 新增 C 与零字节 D
      ▸ DoD: `C=71` ▸ `D=0`
- [x] **T4.4** 三重自洽
      ▸ DoD: `A+B+E = 92` = 基线组数 ✅
      ▸ DoD: `A+B+C = 122` = MOD 组数 ✅
      ▸ DoD: `92 − 41 + 71 = 122` ✅
- [x] **T4.5** 证明四象限失效
      ▸ DoD: `A+B = 51 ≠ 92` → 必须加 `E`

## 组 5 — 三形态跨 MOD 对照（REQ-DRMV-5）

- [x] **T5.1** books 对照 ▸ DoD: `89/3/0/86/2`，`A+B=92` 成立
- [x] **T5.2** pineapple 对照 ▸ DoD: `2/90/0/62/115`，`A+B=92` 成立
- [x] **T5.3** dream 对照 ▸ DoD: `2/49/41/71/0`，`A+B=51` **不成立**
- [x] **T5.4** 结论 ▸ DoD: 文档写明「三种模式，单一计数口径必漏项」

## 组 6 — `hdgrp` 484 有效性（REQ-DRMV-6）

- [x] **T6.1** offsets/段数 ▸ DoD: `484 offsets` / `483 段`，`offs[0]=2895`，`tail=0`
- [x] **T6.2** 段分类 ▸ DoD: `411 RLE + 72 零长 = 483`，**头异常 0**
- [x] **T6.3** 尺寸上限 ▸ DoD: `w 1..58` / `h 1..71`
- [x] **T6.4** 零长块 ▸ DoD: `(381,69)` + `(480,3)` = **72**
- [x] **T6.5** 基线对照 ▸ DoD: `115 offsets / 114 段 = PNG 2 + RLE 112 + 零长 0`，`w 13..56`
- [x] **T6.6** `eft` 反证 ▸ DoD: dream `eft` = `714 offsets / 713 段 / 零长 0`（同 MOD 同家族对照）

## 组 7 — `eft` 零改动（REQ-DRMV-7）

- [x] **T7.1** md5 三重 ▸ DoD: `md5(eft.idx)` 同 **True**；`md5(eft.grp)` 同 **True**；大小 `2856B/691627B` 相同
- [x] **T7.2** diff 缺席 ▸ DoD: `grep -E "^\s*-\s*[-+]\s*eft\." mods/dream/diff.md` **无输出**
- [x] **T7.3** 排除回退 ▸ DoD: 文档写明「diff 缺席 ⇒ 产物真实存在，非回退」
- [x] **T7.4** 源旁证 ▸ DoD: 源 `resource/eft.{idx,grp}` 与产物 md5 相同
- [x] **T7.5** 正样本表 ▸ DoD: dream 714 md5 全同 ▸ books 973 改动 ▸ pineapple 1378 ▸ mingdong 2268 ▸ BookCalamity 2857

## 组 8 — `ranger.str` 763（REQ-DRMV-8）

- [x] **T8.1** 行/注释 ▸ DoD: 总行 **770**，有效 **763**，注释 **7**
- [x] **T8.2** 分段闭合 ▸ DoD: `Person 243 + Thing 343 + Scene 82 + Wugong 95 = 763`
- [x] **T8.3** 字段闭合 ▸ DoD: `Name 513 + Nick 82 + Desc 168 = 763`
- [x] **T8.4** 唯一/重复 ▸ DoD: 唯一 **732**，重复 **31**
- [x] **T8.5** 与报告一致 ▸ DoD: `encoding-report.md` 旁路表条目 **763** == 实测 763
- [x] **T8.6** 格式确认 ▸ DoD: 逗号分隔；7 行注释（3 表头 + 4 分段标记）；**首个数据行**（第 5 行）`0000,Person,0,Name,隨小破`

## 组 9 — 存档 27 vs 31（REQ-DRMV-9）

- [x] **T9.1** 产物计数 ▸ DoD: **27**（全 `.grp`，`.idx` = **0**）
- [x] **T9.2** 源计数 ▸ DoD: **31**
- [x] **T9.3** 逐字节一致 ▸ DoD: **27/27**
- [x] **T9.4** 4 项改道逐项 md5 ▸ DoD: `alldef.grp` 同 ▸ `allsin.grp` 同 ▸ `ranger.idx` 同 ▸ `ranger.grp` **异**（编码转换，大小 132270B 不变）
- [x] **T9.5** 措辞检查 ▸ DoD: 文档**未**出现「产物 save/ 31 与源 31 逐字节一致」

## 组 10 — 8 项排名实测（REQ-DRMV-10）

- [x] **T10.1** `kdef` ▸ DoD: **4569**，排名 **1/20**，前序 `BookCalamity 1701 > mingdong 1654 > lyff 1358 > pig 1288`
- [x] **T10.2** `hdgrp` ▸ DoD: **484**，排名 **2/20**，前序 `books 696 > dream 484 > pig3dos 412 > BookCalamity 373 > awaken 353`
- [x] **T10.3** `talk` ▸ DoD: **6464**，排名 **4/20**，前序 `RiverLake 8015 > awaken 7717 > books 6655 > dream 6464`
- [x] **T10.4** `Person` ▸ DoD: **409**，排名 **7/20**，前序 `BookCalamity 800 > awaken 720 = pineapple 720 > mingdong 632 > pig3dos 607 > Dragon 589 > dream 409`
- [x] **T10.5** `fight` ▸ DoD: **122**，排名 **12/20**，前序 `BookCalamity 326 > mingdong 267 > awaken 237 > RiverLake 219 > Dragon 209 > pig3dos 180 > books 178 > ptt 162 > pineapple 154 > lyff 138 > pig 137 > dream 122`
- [x] **T10.6** `eft` 唯一 ▸ DoD: dream **714 md5 全同**，其余改动型 books 973 / pineapple 1378 / mingdong 2268 / BookCalamity 2857
- [x] **T10.7** 零字节 ▸ DoD: dream **0**，并列最少（pineapple 115 / RiverLake 44 / ptt 7 / books 2 / loving 2）
- [x] **T10.8** 记录段全异 ▸ DoD: dream **5/5**，本 epic 唯一（lyff 1 / ptt 4）
- [x] **T10.9** 措辞审计 ▸ DoD: 仅 `kdef` 为「第 1」；`hdgrp` 明确写「第 2」；`fight` 明确写「第 12」

## 组 11 — 文档

- [x] **T11.1** `proposal.md` ▸ DoD: REQ-DRMV-1~10 + In/Out Scope + Blast Radius
- [x] **T11.2** `design.md` ▸ DoD: ADR-DRMV-001~006 + 18 Negative Constraints + Checklist 10 项全 `[x]`
- [x] **T11.3** `specs/allmods-dream-verification/spec.md` ▸ DoD: 10 个 REQ，编号与 proposal 一致，各至少 1 Given/When/Then
- [x] **T11.4** `tasks.md`（本文件）▸ DoD: 0 未勾选
- [x] **T11.5** `verification.md` ▸ DoD: 每条 REQ 附实测命令 + 输出 + 结论
- [x] **T11.6** `reports/dream-verify.md` ▸ DoD: 独立报告，含 7 个独特性章节
