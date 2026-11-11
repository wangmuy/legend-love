---
status: done
created: 2026-10-25
---

# Proposal: allmods-dragon-activate

> 父上下文：epic [`2026-10-allmods-compat`](../../epics/2026-10-allmods-compat/epic.md)，
> slice [`allmods-slice11`](../allmods-slice11/slice-proposal.md)。
>
> 本 change 把 MOD `kys-Dragon`（苍龙逐日）接入 love2d 引擎并做机器验证。

## 1. 为什么

`kys-Dragon` 是第 4 梯队第 2 个（`hdgrp` 267 / `fight` 209 / Person 589）。
它在多个维度上与前 10 个 slice **模式不同**：

1. **Person 589 = 本 epic 第 2 多**（次席 BookCalamity 800，超过 awaken 720）——
   人物段 `107198 ÷ 182 = 589` 精确整除。
2. **4 段记录数全异**（589/237/106/114 vs 基线 320/200/84/93），且 **Scene 段也异**
   （+22）—— 这与 RiverLake 的「Scene 84 = 基线 84 阴性对照」正好**互补**：
   RiverLake 证明「记录数相同 ≠ 内容相同」，Dragon 证明「记录数不同 + 内容不同」。
3. **`eft` 714 = 基线同形且 `eft.grp`/`eft.idx` 逐字节相同**（md5 一致）——
   本 epic 首个「`eft` 完全不改」的 MOD。需确认这不是「回退原版」而只是 MOD 未改该资源。
4. **eft id 上界 = 52（= 基线）** ⇒ **不**触发 RiverLake 发现的 `CC.Effect` 截断缺陷。
5. **`resource/war1.sta` = 本 epic 首个 `mod_audit` 规则显式标注的 `DEAD_FILE`**（66030B）。
6. **`fight101`/`fight102` = 基准独有**，且 **Dragon 的 Person 实际引用头像代号 101/102** ——
   本 epic 首次出现「MOD 删掉战斗贴图但数据仍引用」的情形。必须证明引擎容错。

## 2. In Scope

- 构建 `mods/Dragon/`（`mod_build.lua kys-Dragon`）。
- 逐文件穷举审计（811 = 源文件总数）+ 字节级格式覆盖（535 文件 / 12 格式族）。
- 真实启动链路（独立子进程，16 断言）。
- `hdgrp` 267（判据第 7 次应用）、`eft` 714 同形（含 md5 逐字节证明）。
- 记录段 589/237/106/114（判据第 4 次应用，4 段全异含 Scene）。
- 额外战斗三重确认（119 新增 / 2 移除 / 净 +117）。
- 存档 27/27 逐字节一致。
- `war1.sta` `DEAD_FILE` 代码级证据。
- `fight101`/`fight102` 缺失的引擎容错证据。
- 原版零回归。

## 3. Out of Scope

- Slice 12-13（pineapple / books）。
- `music/*.mid`（24 项）+ `list/*.bin`（5 项，含 `list/match - 复制.bin`）—— 全局遗留 spike。
- 引擎改动（禁改路径）。
- `CC.Effect` 修复（epic TODO 已记录）。

## 4. 需求

### REQ-DRG-1 构建
`lua tools/mod_build.lua kys-Dragon` 必须成功，产出
`data files=458 saves=21 sound=80 events=1087 talk=4020`，并生成 `mods/Dragon/diff.md`。

### REQ-DRG-2 逐文件穷举审计
`mod_audit --mod Dragon` 必须 `unclassified=0 bad_evidence=0`，且 `total` = 源文件总数 **811**，
类别求和 = `total`，「必需但未进产物」矛盾数 = 0。

### REQ-DRG-3 字节级格式覆盖
`format_spec --mod Dragon` 必须 `gaps=0`，12 个格式族覆盖 535 个文件。

### REQ-DRG-4 真实启动链路
独立子进程 `boot_one_mod.lua Dragon 589 237 106 114 資` 必须 `RESULT Dragon: OK`（16 断言），
含 `CC.PersonSize=182` 等 MOD 布局覆盖、4096 字符无 U+FFFD、无控制符、10 帧无报错。

### REQ-DRG-5 `hdgrp` 267
三判据（索引驱动 `idxlen/4` + 无固定计数常量 + `gaps=0`）成立 ⇒ 判为**内容差异**，
零引擎改动（判据第 7 次应用，外推链 125/129/173/178/204/252/**267**）。

### REQ-DRG-6 `eft` 714 同形
`eft.idx` = 714 条目、`eft.grp` = 691627B，且 `eft.idx[-1] == eft.grp` 字节数。
`eft.grp`/`eft.idx` 的 md5 与基线**完全相同** —— 必须判定为「MOD 未修改该资源」，
**不得**表述为「回退原版」（因为源文件确实存在且被复制进产物）。

### REQ-DRG-7 eft id 上界 52 —— 不触发 `CC.Effect` 截断
实测 `JY.Wugong[*]["武功动画&音效"]` 最大值 = **52**，未越 `CC.Effect`（53 项，上界 52）。
必须提供实测证据，说明本 MOD **不受** RiverLake 发现的缺陷影响。

### REQ-DRG-8 记录段 589/237/106/114
4 段全部整除（余数 0），Σ 段长 = `ranger.grp` 大小。**4 段全异**（含 Scene +22）⇒
内容差异（判据第 4 次应用）。边界记录必须可读且非空。Scene 用内容证明（非计数）。

### REQ-DRG-9 额外战斗
pascal 92 → Dragon **209**。**119 新增 + 2 移除**（`fight101`/`fight102`）＝ 净 +117。
三重确认：`diff.md` set == 实测差集、产物 209 全部 `REQUIRED`/`in_product=true`、
每个 `.grp` 有配对 `.idx`。

### REQ-DRG-10 `fight101`/`fight102` 缺失容错
Dragon 的 `Person["头像代号"]` **实际引用 101 和 102**，但 MOD 不提供这两个 `fight` 文件。
必须证明引擎优雅降级：`PicLoadFile` 因 `FileLength` 返回 -1 而提前 `return`，
`PicGetXY` 返回 0，不崩溃。

### REQ-DRG-11 存档完好 + 25 项「基准独有」五分法
源 `save/` 27 文件 → 产物 `save/` 27 文件，**逐字节 27/27 一致**，无缺失、无多余。
`diff.md`「基准独有」**25** 项按五分法定性（本 epic 新增第 5 类）：

| 类别 | 项数 |
|------|-----:|
| A 在 save/（源自带存档，逐字节一致） | 9 |
| B 首次播种（源无 `.idx`、产物有，`SeedSaveSlot`） | 9 |
| C 回退原版（`thing.*` → 基线 `data/`） | 2 |
| D 死文件（`allsinbk.grp`，`tmpfilename` 零引用） | 1 |
| **E 数据引用但资源缺失（新增）** | **4** |
| **Σ** | **25** |

E 类 = `fight101`/`fight102` 的 `.grp`+`.idx`：MOD **删掉了**这两个战斗贴图，
但 `Person["头像代号"]` **仍引用 101/102**。引擎三级降级不崩溃（见 REQ-DRG-10）。


### REQ-DRG-12 `war1.sta` `DEAD_FILE`
`resource/war1.sta`（66030B / 355 记录）必须证明为死文件：
① `CC.WarFile` 只指向 `war.sta`；② `grep -rn "war1" script/ framework/ engine-love2d/` = 0 命中；
③ 产物含 `war1.sta` 但引擎不读。

### REQ-DRG-13 `head/` 220 PNG = `EDITOR_DUMP`
220 个 `head/*.png` 必须按 `EDITOR_DUMP` 归类，证据：`IGNORE_DIRS` 含 `head=true`
（`mod_build.lua:567`）+ 引擎 0 引用 + 产物无 `head/` + 审计 220 项全 `EDITOR_DUMP`/`in_product=false`。

### REQ-DRG-14 原版零回归
测试 1842/1842 + 7 道其他门禁全通过；四类禁改路径零改动。

## 5. Blast Radius

| 路径 | 允许 | 说明 |
|------|:----:|------|
| `openspec/changes/allmods-dragon-activate/**` | ✅ 写 | 本 change artifacts |
| `openspec/epics/**`、`openspec/changes/allmods-slice11/**` | ✅ 写 | 进度 |
| `game/mods/Dragon/**` | ✅ 写 | 构建产物（gitignore） |
| `game/tests/**`、`game/tools/**` | ✅ 写 | 仅当发现工具缺陷（须记录） |
| `game/engine-love2d/**` | ❌ 禁 | 引擎 |
| `game/engine-mud/**` | ❌ 禁 | 引擎 |
| `game/script/jyconst.lua` 常量定义 | ❌ 禁 | 常量 |
| `reference/allmods/**` | ❌ 禁 | 只读参考 |

## 6. 交付物

`proposal.md` / `design.md` / `specs/allmods-dragon-activation/spec.md` / `tasks.md` / `verification.md`
