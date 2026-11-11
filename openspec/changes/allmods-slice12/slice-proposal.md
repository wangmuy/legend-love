---
status: active
parent_epic: 2026-10-allmods-compat
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Slice Proposal: allmods-slice12 — pineapple（kys-pineapple）端到端

## Fit-Level Context
本 slice 评估为 vertical-slice（可测试 MVP）。若实施中范围膨胀，通过 /opsx:explore 重新评估。

## Parent Epic

[2026-10-allmods-compat](../../epics/2026-10-allmods-compat/epic.md) — Slice 12（**第 4 梯队第 3 个**）

## Slice Type

Feature

## User Story

玩家激活 MOD「再破菠萝」（kys-pineapple）后，Love2D 引擎按回退链加载其数据与脚本、
应用其 `kysmod.ini` 覆盖，完整跑通主菜单 → 读档 → smap 移动/进出场景 →
战斗 → 事件对话 → 存档/读档的游玩路径。

## 为什么是 pineapple（排序依据）

第 4 梯队的第 3 个 —— 梯队内按 `hdgrp` 条目数升序
（RiverLake 252 → Dragon 267 → **pineapple 300** → books 696）。

### 在 20 个 MOD 中的排名（实测）

| 维度 | pineapple | pascal 基线 | 全 MOD 排名 | 榜首 |
|------|----------:|-----------:|:-----------:|------|
| **`hdgrp` 条目** | **300** | 115 | **第 6** | books 696 |
| **`fight*.grp`** | **154** | 92 | 第 9 | BookCalamity 326 |
| **零字节 `fight*.grp`** | **115** | 0 | **第 1** | pineapple 自身 |
| `eft` 条目 | 1378 | 714 | **第 3** | BookCalamity 2857 |
| `talk` 条目 | 3596 | 2977 | 第 15 | RiverLake 8015 |
| `kdef` 事件 | 1068 | 1018 | 第 15 | dream 4569 |
| 记录段 | **720/344/118/174** | 320/200/84/93 | **Person 第 2** | BookCalamity 800 |
| `ranger.grp` 字节 | 229680 | 136412 | **第 2** | BookCalamity 313242 |

> **口径修正（实测）**：本节初稿称「Person 720 是全 20 MOD 最多、`ranger.grp` 字节第 1」，
> 实测**不成立**。全 MOD `PERSON=` 实测排序：
> `BookCalamity 800 / pineapple 720 / awaken 720 / mingdong 632 / pig3dos 607 / Dragon 589 / ...`；
> `ranger.grp` 字节：`BookCalamity 313242 / pineapple 229680 / mingdong 223688 / ...`；
> 基线 `data/ranger.grp` = **136412**（段0 = 64640），非 114242。
> pineapple 确为**第 2**。仍属极端区间（次席），Person_S 字段映射照样被推到高压值，
> 但**不得**声称「第 1 / 最多」。

**唯一真正第 1 的维度是零字节 fight（115）**，见下节 ①。

## 本 MOD 的独特之处（决定本 slice 的必要性）

### ① 115 个零字节 `fight*.grp` —— 与被引用数据正面对撞（**本 epic 首次**）

`fight016`~`fight131` 区间内共 **115** 个 `.grp` **和** `.idx` 为 0 字节
（**区间内唯一例外 `fight072`，其 `grp` = 57822B 正常非空** —— 见下方边界负对照）。
而 `Person` 的 `头像代号`（offset **2**，非 0）**引用集合包含零字节集合**：
`零字节 ∩ 被引用 = 115`，`零字节 − 被引用 = ∅`（115 个零字节包全部被引用），
被引用共 **151** 个、差额 **36** 为正常 `OK` 包（与三分支实测 `OK=36` 吻合），
被引用代号全部 ≤299 ⇒ 本 MOD **无 `FILE_MISSING` 实例**。

> **边界负对照**：`code 71 = 0B ZERO_BYTE` / **`code 72 = 57822B → OK 79×60`** / `code 73 = 0B ZERO_BYTE`。
> 证明零字节**不是**「区间一刀切」，必须逐文件判定。

这与 Dragon 的 `fight101/102` **缺失**是**不同的降级分支**：

| | Dragon `fight101` | pineapple `fight016`~`131` |
|---|---|---|
| 文件 | **不存在** | **存在但 0 字节** |
| `FileLength` | `-1` | `0` |
| `PicLoadFile` | **早退**（`lib_love.lua:435` `idxlen<0 or grplen<0`） | **不早退**（`0 < 0` 为假），`num = 0` |
| `idx` 表 | 空 | 空（`pic_file.idx[1]=0`，`num=0` 不填循环） |
| `getPic` | grp 打不开 → `nil`（`:264-267`） | grp **打得开**（0B 文件存在）→ `idx[picid]==nil` → `nil`（`:270-273`） |
| `PicGetXY` | `0,0,0,0` | `0,0,0,0` |
| 判定 | 资源**缺失** | 资源**存在但为空**（占位包） |

两者最终都返回 `0,0`，但**代码路径不同**（一个在 `PicLoadFile` 早退，一个进到 `getPic` 内查索引失败）。
因此 Dragon 的结论**不能**直接套用到 pineapple —— 必须独立实测。

### ② `Person 720` —— 记录段极值

`ranger.idx` offsets = `[1860, 132900, 198260, 204396, 228060, 228210]`，grp = 229680B。

```
段长   = (131040, 65360, 6136, 23664, 150)
÷ 记录长 = (720, 344, 118, 174, 3)     余数全 0
Σ = 226350    grp = 229680（头部 1860B + 尾部 1470B）
```

**前四段全部异于基线**（Person 320→720、Thing 200→344、Scene 84→118、Wugong 93→174）；
第五段 Shop 两者皆 150B / 3 条，**相同**，不计入「异于基线」。
基线 offsets = `[836, 65476, 117476, 122684, 136262, 136412]`，seglens = `[64640, 52000, 5208, 13578, 150]`。

### ③ `icon.png` —— 新增的「无消费者」文件（**Dragon 未出现**）

`resource/icon.png`（9383B）在本 MOD 出现，`grep -rn "icon.png"` **0 命中**。
Dragon 的 6 个同类文件（`cloud/title/open/end`）不含 `icon.png`，
故 Baseline 的 `BY_KIND` 兜底集合在 pineapple 上多了第 7 个成员。

### ④ `name.*` **不等于** `talk.*`（与 Dragon 相反）

Dragon：`name.grp` 与 `talk.grp` md5 **相同**（`4c41c044…`）。
pineapple：

```
d7ea262bf2a2e5ddfdce8bfd9bd070d3  name.grp   ≠ e2b3cd0585243c555dab401acd958d30  talk.grp
793bfa542b4a4d294c09939f6220a92c  name.idx   ≠ 537355667856c0d5767d236f27bb7129  talk.idx
```

两侧大小也不同（`name.grp` 152082B vs `talk.grp` 152098B）。
⇒ **「`name.*` 是 `talk.*` 副本」这一结论只在 Dragon 成立，不是跨 MOD 不变量**。
必须逐 MOD 实测。

### ⑤ 90 个同名但内容不同的 fight（**Dragon 也有同类，非 pineapple 独有**）

pineapple：与基线共有的 92 个 `fight*.grp` 中，**A 同容 2 / B 异容 90**，MOD 独有 62。
对照 Dragon（已实测）：同名共有 90 → **A 同容 52 / B 异容 38**，独有 119。

> **口径修正**：初稿称「Dragon 为 0」，实测**错误**。Dragon 有 38 个同名异容。
> pineapple 的 **B 占比（90/92 = 97.8%）远高于 Dragon（38/90 = 42.2%）**，
> 用「占比」而非「有无」才能区分两者。pineapple 是「**改写存量**」型，
> Dragon 是「**新增为主**」型（独有 119 > 异容 38）。

**并且**：`diff.md` 只报「基线无此名」，**这 90 处异容不进入 `diff.md`** ——
这是本 slice 首个量化的 `diff.md` 结构性盲区。

### ⑥ `hdgrp` 300（判据第 8 次应用）

`hdgrp.idx` = 1200B → **300**。外推链：125/129/173/178/204/252/267/**300**。

## 关键风险与未知

| 风险 | 说明 |
|------|------|
| 零字节 fight 的运行时行为 | 需证明走的是 `getPic` 内索引失败，**不是** `PicLoadFile` 早退（与 Dragon 不同分支） |
| Person 720 的字段错位 | 记录数整除不代表字段对；须扫全量字符串（2764 字段）与边界值 |
| 90 个改写 fight | 需证明这些是内容升级而非构建污染（与源逐字节比） |
| `icon.png` 归类 | 与 Dragon 的 6 个同类文件是否应同判 |

## 交付方式

拆成 2 个 spec-driven 子 change（沿用 Slice 2 定型模板）：

| # | 子 change | 职责 |
|---|-----------|------|
| 1 | `allmods-pineapple-activate` | 构建 + 单项机器验证 + 启动链路 + 内容真实性 |
| 2 | `allmods-pineapple-verify` | `diff.md` 逐项审计 + 零字节 fight 分支取证 + 报告 |

`change-manifest.md` 用 Contracts 定义两者之间的可验证接口。

## In Scope

- `game/mods/pineapple/` 构建产物（348 data / 30 save / 109 sound / 1068 events / 3596 talk）
- 穷举审计、字节级格式覆盖、独立进程启动链路
- 零字节 fight 的三分支实测（OK / ZERO_BYTE / FILE_MISSING）
- `diff.md` 双向 set 相等（140 独有 / 21 基准独有）
- 内容真实性：边界记录 + 1087→1068 事件 + 3596 对话 + 10 项 ini 常量
- 8 道门禁复跑

## Out of Scope

- Slice 13（books）
- 修复 `not_in_product` 语义（独立 change）
- `CC.Effect` 仅 53 项、越界 62 条（属 epic 级 spike `allmods-effect-table`）
- `music/*.mid` / `list/*.bin` 全局遗留
- 引擎改动

## 与 TODO.md 既有记录的交叉引用

`TODO.md:198` 已记录「全域 0 字节 fight：pineapple 115 / RiverLake 44 / ptt 7 / books 2 / loving 2」，
本 slice 是该记录的**首个深度取证**（RiverLake 的 44 个未做分支区分）。
`TODO.md:206` 记录 pineapple **eft id 越界 62 条**（`eft > 52`），本 slice 已确认
触发 `CC.Effect` 越界降级（`or 10` / `or 0` 兜底），但退化**饱和**、不崩溃
（属 epic 级 spike `allmods-effect-table`，本 slice 只取证不修复）。
