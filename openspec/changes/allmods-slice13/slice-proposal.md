---
status: active
parent_epic: 2026-10-allmods-compat
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Slice Proposal: allmods-slice13 — books（kys-books）端到端

## Fit-Level Context
本 slice 评估为 vertical-slice（可测试 MVP）。若实施中范围膨胀，通过 /opsx:explore 重新评估。

## Parent Epic

[2026-10-allmods-compat](../../epics/2026-10-allmods-compat/epic.md) — Slice 13（**最后一个 MOD**）

## Slice Type

Feature

## User Story

玩家激活 MOD「天书奇侠试玩」（kys-books）后，Love2D 引擎按回退链加载其数据与脚本、
应用其 `kysmod.ini` 覆盖，完整跑通主菜单 → 读档 → smap 移动/进出场景 →
战斗 → 事件对话 → 存档/读档的游玩路径。

## 为什么是最后一个 —— books 的排序依据

books 是第 5 梯队（hdgrp 350+ 或数据异常）的核心，且在 20 个 MOD 中两项居首：

| 维度 | books | pascal 基线 | 全 MOD 排名 | 榜首 |
|------|------:|-----------:|:-----------:|------|
| **`hdgrp` 条目** | **696** | 115 | **第 1** | books 自身 |
| **`kdef` 事件（最少）** | **573** | 1018 | **最少** | books 自身（反向第 1） |
| `talk` 条目 | 6655 | 2977 | **第 3** | RiverLake 8015 |
| `eft` 条目 | 973 | 714 | 第 4 | BookCalamity 2857 |
| `fight*.grp` | 178 | 92 | 第 7 | BookCalamity 326 |
| 零字节 fight | 2 | 0 | 第 4 | pineapple 115 |
| 记录段 | **382/200/84/100** | 320/200/84/93 | 中游 | BookCalamity 800 |
| 源文件 | **525** | — | — | — |

**`hdgrp` 696 是全部 20 个 MOD 中最多**（次席 dream 484，第三 pig3dos 412）——
判据第 9 次应用，也是本 epic 最后一个极端值验证（**上限封顶**）。

## 本 MOD 的独特之处

### ① `hdgrp` 696 —— 全 20 MOD 最多（上限封顶）

`hdgrp.idx` = 2784B → **696** 条目（2784/4），`hdgrp.grp` = **1233815B**。
外推链：114/115/125/129/173/178/204/252/267/300// **484 / 696**。

⇒ 必须验证**逐条内容有效**，不能只报「696 条」。

### ② `Wugong` 100 —— 罕见的中间值

多数 MOD 的 Wugong 为 93（基线）、96（RiverLake）、114（Dragon）。
books 的 **100** 需验证 `Wugong` 段（13600B / 136 = 100，余 0）整除
且 `CC.Wugong_S` 字段映射在 100 条记录上仍对齐（不越界、不错位）。

### ③ `fight` 分布与 pineapple 完全相反

| 象限 | books | pineapple 对照 |
|------|-----:|---------------:|
| A 同名同容 | **89** | 2 |
| B 同名异容 | **3** | 90 |
| C MOD 独有 | **86** | 62 |
| D 零字节 | **2**（`fight104`/`fight164`） | 115 |

books 是「**保留基线 + 新增增量**」型（A 89 = 92 同名的 96.7%），
pineapple 是「**改写存量**」型（B 90 = 92 同名的 97.8%）—— **两个极端**。
⇒ 强力印证：fight 分析不能只看总数 178，必须四象限。

自洽校验：`A + B = 89 + 3 = 92` = 基线 fight 数 ✅
`A + B + C = 89 + 3 + 86 = 178` = MOD fight 数 ✅

### ④ `kdef` 事件仅 573 —— 全 MOD 最少

基线 1018、pineapple 1068、dream 4569。books 的 **573** 是**全部 20 MOD 中最少**。
⇒ 需验证「事件少」是 MOD 设计（试玩版内容较少）而非构建截断。

### ⑤ `talk` 6655 —— 第 3 多

`talk.idx` = 26620B → **6655** 条目。仅次于 RiverLake 8015、awaken 7717。
对话量巨大而事件少 ⇒ 两者**不成比例**，是独立验证点。

### ⑥ 无 `name.*` 文件

`TODO.md:268` 勘误：`name.grp` 出现于 BookCalamity / Dragon / pineapple / RiverLake 四个 MOD，
**books 未使用**。`diff.md` 的 12 条非 fight 中确实**不含** `name.grp`/`name.idx`。
⇒ 需确认：无 `name.*` 时 `ranger.str` 生成是否仍正常（它依赖 `ranger.grp` 而非 `name.*`）。

### ⑦ 21 条基线独有：与 pineapple 同构

`18 存档槽改道 + 3 模板回退（thing.grp/thing.idx/allsinbk.grp）+ 0 真删除`。
再次验证 `ModData.Resolve` 回退链（判据第 2 次独立复现）。

## 关键风险与未知

| 风险 | 说明 |
|------|------|
| `hdgrp` 696 上限 | 1233815B 的 grp 是否逐条内容有效（不只条目数） |
| `Wugong` 100 中间值 | `Wugong_S` 字段映射是否错位/越界 |
| 事件仅 573 | 需证明是 MOD 设计而非构建丢失 |
| `fight` 89 同容 | 需确认不是「构建未复制」的假象（用 md5 双向验证） |
| 2 个零字节 fight | 走 ZERO_BYTE 分支，须独立实测（**不类推 pineapple**） |
| 无 `name.*` | `ranger.str` 生成是否仍正常 |

## 交付方式

拆成 2 个 spec-driven 子 change（沿用 Slice 2 定型模板）：

| # | 子 change | 职责 |
|---|-----------|------|
| 1 | `allmods-books-activate` | 构建 + 单项机器验证 + 启动链路 + 内容真实性 |
| 2 | `allmods-books-verify` | `diff.md` 逐项审计 + `hdgrp`/`Wugong` 取证 + 报告 |

`change-manifest.md` 用 Contracts 定义两者之间的可验证接口。

## In Scope

- `game/mods/books/` 构建产物（392 data / 19 save / 84 sound / 573 events / 6655 talk）
- 穷举审计、字节级格式覆盖、独立进程启动链路
- `hdgrp` 696 逐条验证（上限封顶）
- `Wugong` 100 中间值字段映射验证
- fight 四象限（`89/3/86/2`）+ 2 个零字节分支实测
- `diff.md` 双向 set 相等（184 独有 / 21 基准独有）
- 8 道门禁复跑

## Out of Scope

- 修复 `not_in_product` 语义（独立 change）
- `CC.Effect` 越界修复（epic 级 spike `allmods-effect-table`）
- `music/*.mid` / `list/*.bin` 全局遗留
- 引擎改动
