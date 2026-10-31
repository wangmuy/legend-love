---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice10
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Proposal: allmods-riverlake-activate

## Why

Slice 5~9 在 6 个 MOD 上把「`hdgrp` 差异无需引擎改动」的判据外推链推到
125/129/173/178/204，并把判据从 `hdgrp` 扩展到**记录段**（lyff 1 段、ptt 4 段）。
本 change 把 **RiverLake（kys-RiverLake）** 接入地基 —— 它是**第 4 梯队开场**，也是：

1. 本 epic **`talk` 条目最多**（8015，次席 awaken 7717），`+5038` 为最大 `talk` 增量。
2. 本 epic **`fight` 数第 2**（219，次席于 awaken 237），**+127 额外战斗**。
3. **记录段 3 段异 / 1 段（Scene）与基线相同** —— 统一判据的**阴性对照**样本。

| 维度 | RiverLake | pascal | 差异 |
|------|----------:|-------:|------|
| **`hdgrp`** | **252** | 115 | +137 头像 |
| `eft` | 921 | 714 | +207（非同形） |
| **fight** | **219** | 92 | **+127 额外战斗** |
| `kdef` 事件 | 1232 | 1018 | +214 |
| **`talk`** | **8015** | 2977 | **+5038** |
| **记录段** | **325/249/84/96** | 320/200/84/93 | Person+5 / Thing+49 / Scene 同 / Wugong+3 |

**核心验证点**：

1. `hdgrp` 252 差异（判据**第 6 次应用**）
2. `eft` 921 差异（索引驱动判据，`idx[-1] == grp 大小`）
3. **记录段 3 异 1 同** —— 统一判据**第 3 次应用**，含 **Scene 84 阴性对照**
4. **127 场额外战斗**三重确认（本 epic 第 2 多）
5. **空 WAV 容错**（28 个 0 字节 `e72`~`e98`）
6. **18 个源自带存档槽**完好

## What Changes

1. 构建 RiverLake 数据包到 `game/mods/RiverLake/`。
2. 逐文件穷举审计：每个源文件归入具名类别，无缺口。
3. 字节级格式覆盖：无缺口。
4. 真实启动链路端到端验证（独立进程）。
5. `hdgrp` / `eft` / 记录段 差异判定。
6. 额外战斗三重确认。
7. 存档与空 WAV 完整性验证。

**零引擎改动、零代码改动**（`CC.Effect` 缺陷仅记录，不修复）。

## In Scope

- `game/mods/RiverLake/**`（构建产物）
- `openspec/changes/allmods-riverlake-activate/**`

## Out of Scope

- 引擎任何改动（`engine-love2d/**` / `engine-mud/**`）
- `script/jyconst.lua` 常量定义
- `reference/allmods/**`
- `music/*.mid`（23 项 PENDING，全局遗留 spike）
- `list/*.bin`（4 项 PENDING，C 引擎列表数据）

## Requirements

### REQ-RIV-1 构建
`lua tools/mod_build.lua kys-RiverLake` 退出码 0，输出
`data files=478, saves=21, sound=170, events=1232, talk=8015`，
且 `mods/RiverLake/data/fight*.grp` = 219。

### REQ-RIV-2 逐文件穷举审计
`lua tools/mod_audit.lua --mod RiverLake` 输出
`unclassified=0 bad_evidence=0`，且 `total=699` = 源文件总数（不变量）。

### REQ-RIV-3 字节级覆盖
`lua tools/format_spec.lua --mod RiverLake` 输出 `gaps=0`。

### REQ-RIV-4 真实启动链路
`lua tests/unit/boot_one_mod.lua RiverLake 325 249 84 96 茲` 输出 `RESULT RiverLake: OK`，
16 断言全 PASS。

### REQ-RIV-5 记录段差异判定（含阴性对照）
4 段段长必须被记录尺寸整除：`59150/182=325`、`47310/190=249`、`4368/52=84`、
`13056/136=96`；`Person[324]`/`Thing[248]`/`Scene[83]`/`Wugong[95]` 边界记录可读。
**`Scene=84` 与基线相同是阴性对照**：判据必须仍能证明 Scene 段的**内容**来自 MOD，
不得因段数相同就判定「回退原版」。

### REQ-RIV-6 `hdgrp` 差异判定
`hdgrp.idx` 1008B = 252 条目（基线 115）；三重判据：索引驱动 `idxlen/4` +
引擎无固定计数常量 + `format_spec` `gaps=0` ⇒ 内容差异，零引擎改动。

### REQ-RIV-7 `eft` 差异判定（含范围外发现记录）
`eft.idx` 3684B = 921 条目（基线 714）；判据：`idx` 长度驱动 + 偏移单调不减 +
`idx[-1] == eft.grp` 字节数 ⇒ 内容差异，零引擎改动。

**同时必须记录范围外发现**：`script/jyconst.lua:439` 的 `CC.Effect` 是硬编码 **53 项**表，
而 RiverLake 的 `JY.Wugong[i]["武功动画&音效"]` 最大为 **69**（10 条越界）。

语义关系（本轮实测）：`list/effect.bin` = **每效果帧数**（项数 = 效果个数，RiverLake **70** 项）；
`eft.idx` = **逐帧**偏移表（条目数 = `sum(effect.bin)`，921）；`CC.Effect` = 53 项硬编码快照。
3 个 MOD 的 `sum(effect.bin) == eft.idx` 精确相等（RiverLake 921 / BookCalamity 2857 / pineapple 1378）。
权威来源 `reference/allmods/UPedit/UPedit.ini:80`（`Effect=list\effect.bin`）。

**7/20 MOD 越出 `CC.Effect`**（RiverLake 10 / books 2 / awaken 1 / pineapple 62 /
mingdong 136 / BookCalamity 296 / pig3dos 52），另有 pig3dos 越出自带 `effect.bin`（85 vs 64 项）。
**非致命**（`CC.Effect[eft]` 为 `nil` → 回退 10 帧，不崩溃），但属既有缺陷，
因 `jyconst.lua` 属禁改路径、修复需改 20 MOD 的审计分类与构建管线，**不在本 change 修复**，
记为 epic 级 TODO。

### REQ-RIV-8 额外战斗三重确认
`comm -13` 差集 = **127** 个 `fight*.grp`；`diff.md` 的 `+ fightNNN.grp` 条目与差集
**精确一致**；审计中 219 个 `fight*.grp` 全部 `REQUIRED` + `in_product=true`。

### REQ-RIV-9 存档完好
产物 `mods/RiverLake/save/` 21 个文件与源 `save/` **逐字节一致**；
18 个源自带存档槽（`d1`~`d6`/`d11`/`r1`~`r6`/`r11`/`s1`~`s6`/`s11`）。首次保存时
`rN.idx` 由 MOD 自己的 `data/ranger.idx` 播种（实测，非 `data/ranger.idx`）。

### REQ-RIV-10 空 WAV 容错
28 个 0 字节 `sound/e72.wav`~`e98.wav` 原样进产物，且运行时（真实启动链路 10 帧 +
`PlayWAV` 的 `pcall`）不产生错误。

### REQ-RIV-11 范围外发现记录
`verify` 必须记录 `CC.Effect` 截断缺陷：受影响 MOD 清单（**7/20**）、每个 MOD 的越界条数、
`list/effect.bin` 项数与 `eft.idx` 条目数、权威来源（`UPedit.ini:80`）、
`sum(effect.bin) == eft.idx` 的精确样本、非致命性证明、以及「不在本 change 修复」的理由与修复路径。

### REQ-RIV-12 原版零回归
`lua tests/test_runner.lua` 全绿（1622/1622），其余 19 个 MOD 的 `save/` 与
`mod_check`/`mod_audit`/`format_spec` 全量门禁不变。

## Blast Radius

| 路径 | 权限 |
|------|------|
| `game/mods/RiverLake/**` | 写（构建产物，gitignore） |
| `openspec/changes/allmods-riverlake-activate/**` | 写 |
| `game/engine-love2d/**` | **禁改** |
| `game/engine-mud/**` | **禁改** |
| `game/script/jyconst.lua` 常量定义 | **禁改** |
| `reference/allmods/**` | **禁改** |

## 依赖

- Slice 0 / 0b / 0c（回退链、别名、审计工具链）
- Slice 2~9（定型模板、5 个工具缺陷修复、`hdgrp` 判据、记录段统一判据、首次播种类别）
