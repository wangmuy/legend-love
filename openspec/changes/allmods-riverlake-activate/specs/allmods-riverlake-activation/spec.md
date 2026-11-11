# Spec: allmods-riverlake-activation

> 需求 ID 前缀 `REQ-RIV-`。每个场景使用 Given / When / Then。

## REQ-RIV-1：构建 RiverLake 数据包

**Given** 源目录 `reference/allmods/kys-RiverLake/` 存在（`fight/`/`list/`/`music/`/`resource/`/`save/`/`script/`/`sound/` 共 699 文件）
**When** 执行 `cd game && lua tools/mod_build.lua kys-RiverLake`
**Then** 退出码 0，且输出：

```
[mod_build] kys-RiverLake: data files=478, saves=21, sound=170, events=1232, talk=8015
[mod_build] diff -> tools/../mods/RiverLake/diff.md
```

**And** `game/mods/RiverLake/data/fight*.grp` 恰好 **219** 个。

---

## REQ-RIV-2：逐文件穷举审计（审计对象 = 源文件全集）

**Given** 源目录共 699 个文件
**When** 执行 `lua tools/mod_audit.lua --mod RiverLake`
**Then** 输出 `total=699 in_product=666 not_in_product=33 unclassified=0 bad_evidence=0`

**And** 类别分布 Σ = 699：

| 类别 | 条数 |
|------|-----:|
| `REQUIRED` | 661 |
| `REQUIRED_CONVERTED` | 4 |
| `LEGACY` | 5 |
| `BUILD_INPUT` | 2 |
| `PENDING` | 27 |

**And**「必需（`needed=true`）但 `in_product=false`」矛盾数 = **0**
（即 `REQUIRED`/`REQUIRED_CONVERTED` 的 665 项全部进产物）。

**And** 不得出现 OTHER/UNKNOWN 兜底类别。

---

## REQ-RIV-3：字节级格式覆盖无缺口

**Given** RiverLake 产物已构建
**When** 执行 `lua tools/format_spec.lua --mod RiverLake`
**Then** 输出 `formats=12 checked=413 gaps=0`

**And** 每个字节归入具名字段，无 "rest"-only 区间；`hdgrp`/`eft`/`warfld`/`cloud`/`title`/
`mmap`/`fight*`/`talk`/`kdef`/`ranger`/`war.sta`/`earth.002` 共 12 个格式族全部覆盖。

---

## REQ-RIV-4：真实启动链路端到端（独立进程）

**Given** `game/active_mod.txt` 内容为 `RiverLake`（或已清理后由 `boot_one_mod.lua` 显式设置）
**When** 执行 `cd game && lua tests/unit/boot_one_mod.lua RiverLake 325 249 84 96 茲`
**Then** 输出 `RESULT RiverLake: OK`，且以下 16 条断言全部 PASS：

| 断言 | 期望 |
|------|------|
| `lib.init` | 无报错 |
| `JYMainAdapter.init` | 无报错 |
| `CC.PersonSize` | 182（MOD 布局，非陈旧常量 202） |
| `CC.ThingSize` | 190 |
| `CC.SceneSize` | 52 |
| `CC.WugongSize` | 136 |
| `LoadRecord(0)` | 无报错 |
| `PersonNum` | 325 |
| `ThingNum` | 249 |
| `SceneNum` | 84 |
| `WugongNum` | 96 |
| 主角姓名 | 茲 |
| 扫描字段数 | > 100 |
| 全量字符串 U+FFFD | 0 |
| 全量字符串控制符 | 0 |
| 运行时 10 帧 | 无报错 |

---

## REQ-RIV-5：记录段差异判定（含 Scene 阴性对照）

**Given** `ranger.idx` 偏移 `[836, 59986, 107296, 111664, 124720, 124870]`，`ranger.grp` 124870 字节
**When** 用 `CC.*Size`（182/190/52/136/50）除各段段长
**Then** 4 段全部**整除、余数为 0**：

| 段 | 段长 | ÷ 记录尺寸 | 记录数 | 基线 | 差异 |
|----|-----:|-----------:|-------:|-----:|-----:|
| Person | 59150 | 182 | **325** | 320 | +5 |
| Thing | 47310 | 190 | **249** | 200 | +49 |
| Scene | 4368 | 52 | **84** | 84 | **0（同）** |
| Wugong | 13056 | 136 | **96** | 93 | +3 |
| Shop | 150 | 50 | 3 | 3 | 0 |

**And** 边界记录可读且非空：`Person[324]="袁冠南"`、`Thing[248]="玄虛刀法"`、
`Scene[83]="圣堂"`、`Wugong[95]="玄虛刀法"`。

**And** 引擎无固定计数常量（`PersonNum` 由 `jymain.lua:1747` 的
`math.floor((idx[2]-idx[1])/CC.PersonSize)` 推导）。

**And（阴性对照，关键）** `Scene` 段记录数 **84 = 基线 84**，因此
**不得**用「记录数」证明内容已加载，必须用**内容**证据：

| 记录 | RiverLake | pascal |
|------|-----------|--------|
| `Scene[0]` | **盛京** | 胡斐居 |
| `Scene[1]` | 河洛客棧 | 河洛客棧 |
| `Scene[2]` | **靈鷲宮** | 雲鶴崖 |
| `Scene[83]` | **圣堂** | 聖堂 |

4 个抽样中 3 个不同 ⇒ Scene 段内容来自 MOD，**非回退原版**。

⇒ 结论：**内容差异**（统一判据第 3 次应用），零引擎改动。

---

## REQ-RIV-6：`hdgrp` 差异判定（判据第 6 次应用）

**Given** `hdgrp.idx` 1008 字节
**When** 计算 `条目数 = idx 字节数 / 4`
**Then** **252** 条目（基线 115，+137）

**And** 三重判据同时成立：

1. **索引驱动**：条目数 = `idxlen/4`，`PicLoadFile`（`lib_love.lua:423-451`）按此加载。
2. **无固定计数常量**：`grep -rn '115\|hdgrpNum\|HEADNUM' engine-love2d/ script/jyconst.lua` 无硬编码。
3. **字节层无缺口**：`format_spec --mod RiverLake` → `gaps=0`。

⇒ 结论：**内容差异**，零引擎改动。外推链 **125/129/173/178/204/252** 六次一致。

---

## REQ-RIV-7：`eft` 差异判定 + 范围外发现

**Given** `eft.idx` 3684 字节、`eft.grp` 1078261 字节
**When** 计算条目数并检查偏移闭合
**Then** **921** 条目（基线 714，+207），且：

| 检查 | 结果 |
|------|------|
| 条目数 = `idxlen/4` | 921 |
| 偏移单调不减 | ✅ |
| `idx[-1] == eft.grp` 字节数 | 1078261 == 1078261 ✅ |

⇒ `eft.idx` 维度：**内容差异**，零引擎改动。

**And（范围外发现，必须记录）** `script/jyconst.lua:439` 的 `CC.Effect` 是**硬编码 53 项**表
（`[0]=9,14,17,...`，sum=712），而 `eft.idx` 是**逐帧**索引（条目数 = 各效果帧数之和），
efe id 的实际使用范围随 MOD 变化。

**语义关系（本轮实测确认）**：

| 文件 | 语义 | RiverLake | pascal |
|------|------|----------:|-------:|
| `list/effect.bin` | **每个效果**的帧数（int16 序列），长度 = 效果个数 | **70** 项 | 64 项 |
| `eft.idx` | **逐帧**偏移表，条目数 = `sum(effect.bin)` | 921 | 714 |
| `CC.Effect` | 硬编码 53 项快照（= `effect.bin[0..52]`，且 `[0]` 被改成 9） | — | — |

3 个 MOD 的 `sum(effect.bin) == eft.idx 条目数` **精确相等**（RiverLake 921 / BookCalamity 2857 / pineapple 1378），
其余 MOD 因 `effect.bin` 尾部补零条目而差 1–44。`CC.Effect[0]=9` 而 `effect.bin[0]=10`
（差 1）已是基线既存偏差。

**权威来源**：`reference/allmods/UPedit/UPedit.ini:80` → `Effect=list\effect.bin`；
20/20 MOD 均有该文件。

实测各 MOD 的 `JY.Wugong[i]["武功动画&音效"]`（= eft id）与两张表的上界关系：

| MOD | wugong 数 | eft id 最大 | `>52`（越 `CC.Effect`） | `>= len(effect.bin)`（越 MOD 自己的表） | `eft.idx` |
|-----|----------:|------------:|------------------------:|----------------------------------------:|----------:|
| pascal（基线） | 93 | 52 | **0** | 0 | 714 |
| Dragon | 114 | 52 | 0 | 0 | 714 |
| dream | 102 | 52 | 0 | 0 | 714 |
| GodsDevils / HeavenSword / lostbook / loving / lyff / pig / stronger / SweeOan / zheng / ptt | 93–108 | 52 | 0 | 0 | 714 |
| **RiverLake** | 96 | **69** | **10** | 0（70 项） | 921 |
| books | 100 | 55 | 2 | 0（64 项） | 973 |
| awaken | 163 | 53 | 1 | 0（64 项） | 727 |
| **pineapple** | 174 | **83** | **62** | 0（84 项） | 1378 |
| **mingdong** | 220 | **168** | **136** | 0（200 项） | 2268 |
| **BookCalamity** | 398 | **198** | **296** | 0（200 项） | 2857 |
| **pig3dos** | 202 | **85** | **52** | **21（仅 64 项）** | 714 |

⇒ **7/20 MOD 越出 `CC.Effect` 的 53 项上界**：`RiverLake` / `books` / `awaken` / `pineapple` /
`mingdong` / `BookCalamity` / `pig3dos`。
⇒ **1/20 MOD（pig3dos）连 MOD 自带的 `effect.bin` 都越界**（eft id 85 vs 64 项），
是 pig3dos 数据本身的既有问题（该 MOD 已在 `annotated-problematic` 名单内）。

**非致命性证明**（`framework/war_async.lua:1106`, `1124-1128`）：

```lua
local framenum = fightdelay + (CC.Effect and CC.Effect[eft] or 10) or 10
for i = 0, eft - 1 do starteft = starteft + (CC.Effect[i] or 0) end
```

`CC.Effect[eft]` 为 `nil` ⇒ 回退 `10` 帧；`CC.Effect[i]` 为 `nil` ⇒ `+0`。
两者都有 `or` 保护，**不抛错、不崩溃**，仅导致武功动画起始帧/帧数错位。

**And** 本 change **不修复**该缺陷，理由：`CC.Effect` 定义于 `script/jyconst.lua`
（**负约束禁改路径**）。修复方案需在 `framework/mod_data.lua` 的 `RewriteConstants` 里
按 `list/effect.bin` 重建 `CC.Effect`，并把 `list/effect.bin` 从 `PENDING` 提升为
`REQUIRED` 进产物 —— 这会改动 20 个 MOD 的审计分类与构建管线，属**独立 change**，
不在本 slice 的 Blast Radius 内。记为 epic 级 TODO 条目。

---

## REQ-RIV-8：127 场额外战斗三重确认

**Given** 产物 `fight*.grp` = 219，基线 pascal = 92
**When** 计算差集 `comm -13 <pascal 清单> <RiverLake 清单>`
**Then** 差集 = **127** 个文件

**And** 三重确认**逐个文件名一致**：

| # | 证据 | 期望 |
|---|------|------|
| 1 | `mods/RiverLake/diff.md` 的 `+ fightNNN.grp` 条目 | 127 条，文件名与差集一一对应 |
| 2 | 产物差集 | 127 个 |
| 3 | `mod_audit` 中 219 个 `fight*.grp` | 全部 `REQUIRED` 且 `in_product=true` |

**And** 抽样 5 场（首、中、尾、两个边界）验证 `fight*.grp` + `fight*.idx` 成对存在且非空。

⇒ +127 是引擎按索引加载的真实内容（本 epic 第 2 多，次于 awaken +145）。

---

## REQ-RIV-9：存档完好（18 个源自带槽）

**Given** 源 `save/` 28 文件、产物 `mods/RiverLake/save/` 21 文件
**When** 逐字节比对
**Then** **21/21 完全一致**

**And** 18 个源自带存档槽：`d1`~`d6`、`d11`、`r1`~`r6`、`r11`、`s1`~`s6`、`s11`（全部 `.grp`）。

**And** 首次保存时 `rN.idx` 由 **MOD 自己的** `data/ranger.idx` 播种（实测
`SeedSaveSlot(1) -> mods/RiverLake/save/r1.idx`，内容 == `mods/RiverLake/data/ranger.idx`，
**≠** `data/ranger.idx`）；播种后清理，产物目录不残留 `.idx`。

---

## REQ-RIV-10：空 WAV 容错

**Given** 源 `sound/` 有 28 个 **0 字节** WAV（`e72.wav`~`e98.wav`）
**When** 构建并运行
**Then**

1. 28 个空文件**原样**进产物（产物 `sound` 计数 170 包含它们，空文件数仍为 28）。
2. `PlayWAV`（`lib_love.lua:602-621`）用 `pcall(love.audio.newSource, ...)` 包裹，
   `success` 为假时静默跳过 ⇒ 不中断。
3. 真实启动链路 10 帧无报错。

**And** 不补静音 WAV、不删除空文件（会破坏「产物 = 源 + 格式转换」不变式与音效 ID 索引）。

---

## REQ-RIV-11：范围外发现记录

**Given** REQ-RIV-7 发现的 `CC.Effect` 截断缺陷
**When** 生成 `verification.md` / `reports/riverlake-verify.md`
**Then** 必须包含：

1. 受影响 MOD 清单 = **7/20**（`RiverLake` / `books` / `awaken` / `pineapple` /
   `mingdong` / `BookCalamity` / `pig3dos`），且 pig3dos **另越 MOD 自带 `effect.bin`**（85 vs 64 项）
2. 每个 MOD 的越界条数、eft id 最大值、`effect.bin` 项数、`eft.idx` 条目数
3. 权威来源 `list/effect.bin` + `UPedit.ini:80` 证据；`sum(effect.bin) == eft.idx` 的 3 个精确样本
4. 非致命性证明（`or 10` / `or 0` 回退，不崩溃）
5. 「不在本 change 修复」的理由（`jyconst.lua` 禁改 + 需改 20 MOD 的审计分类与构建管线）
6. 修复路径建议（`mod_data.RewriteConstants` 由 `list/effect.bin` 重建 `CC.Effect`）

---

## REQ-RIV-12：原版零回归

**Given** 全部改动已完成
**When** 执行全量门禁
**Then** 全部通过：

| 门禁 | 期望 |
|------|------|
| `lua tests/test_runner.lua` | 1622/1622 |
| `lua tools/mod_build.lua --verify-pascal` | `mismatches=0`，PASS |
| `lua tools/mod_build.lua --all` | `20 mods, 0 build failures` |
| `lua tools/mod_check.lua` | 20/20 |
| `lua tools/mod_audit.lua --all` | `unclassified=0 bad_evidence=0` |
| `lua tools/mod_audit.lua --all --evidence` | `failed=0` |
| `lua tools/format_spec.lua --all` | `gaps=0` |
| 全 20 MOD `save/` vs 源 | 341 文件不一致 = 0 |

**And** `game/engine-love2d/**`、`game/engine-mud/**`、`game/script/jyconst.lua` 常量定义、
`reference/allmods/**` **零改动**。
