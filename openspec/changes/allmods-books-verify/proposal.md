---
status: done
created: 2026-10-26
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice13
---
# Proposal: allmods-books-verify

> Slice 13 子 change 2/2 —— 对 books 的构建产物做**逐项真实性审计**，
> 并对 `hdgrp`（696，全 MOD 最多）、`Wugong`（100）、fight（含 4 个真实
> `FILE_MISSING`）做深度取证。

## 1. 背景

`allmods-books-activate` 解决了「能构建、能启动、数字对」。本 change 解决
「**内容真的是 MOD 作者的意图，而不是构建器的臆造**」。

books 在三处与前面 12 个 MOD 显著不同，必须专项取证：

| 差异点 | books | 前序 MOD 参照 |
|--------|-------|---------------|
| `hdgrp` 条目 | **696**（全 20 MOD 第 1） | dream 484 / pineapple 300 / 基线 115 |
| `kdef` 事件 | **573**（全 20 MOD 最少） | pineapple 1068 / RiverLake 最多 |
| fight 分布 | **A 89 / B 3 / C 86 / D 2** | pineapple A 2 / B 90 / C 62 / D 115（互为极端） |
| `FILE_MISSING` | **4 个被引用** | pineapple 0 / Dragon 1（未引用） |
| `ranger.grp` | **126478 < 基线 136412**（变小） | pineapple 229680（变大） |

## 2. In Scope

- `diff.md` **双向 set 相等**验证（`added`/`removed` 与实测集合逐一比对）
- `removed` 21 项精确三分法（13 槽改道 + 5 槽缺席 + 3 模板回退 + 0 真删除）
- `added` 184 项拆解（172 fight + 12 非 fight）与源侧溯源
- `hdgrp` 696 逐条内容有效性（474 非空段 `w/h` 上限封顶 + 222 零长段归属）
- `Wugong` 100 字段对齐（64 字段 / 全 nil 0 / 越界 2）
- fight **四象限**（A/B/C/D）与 pineapple 反向对照
- `FILE_MISSING` 4 实例的引用链（`Person` → 姓名 → 代码）
- `ranger.str` 957 条侧表的完整性（分段/字段/唯一值）
- `reports/books-verify.md` 独立报告

## 3. Out of Scope

| 项 | 原因 |
|----|------|
| 修复 `FILE_MISSING` / 零字节 | 改源数据或补文件 = 禁用路径 |
| `hdgrp` 222 零长段的语义解释扩展 | 已由 `format_spec.lua` 的 `idx_grp_rle` 家族定义，超出本 change |
| `CC.Effect` 越界修复 | 修复点 `script/jyconst.lua`（禁用路径）= epic spike |
| 重跑 8 门禁全量 | 属 activate 的 REQ-BK-13；verify 只复用结论 |
| 引擎/工具改动 | 禁改；本 MOD 未发现新工具缺陷 |

## 4. 需求（REQ-BKV-1 ~ REQ-BKV-10）

### REQ-BKV-1 `diff.md` 双向 set 相等

不得以数量相等代替集合相等。必须：

```
diff.md added=184  removed=21
实测 MOD 独有=184  实测基线独有=21
add == 实测? True    rem == 实测? True
```

### REQ-BKV-2 `removed` 21 的三分法闭合

```
13（槽改道 save，源 save 有且 md5 同）+ 5（槽缺席，源亦无，走回退）
+ 3（模板回退 thing.grp/idx + allsinbk.grp）+ 0（真删除）= 21
```

且必须声明 **`save/` 19 与 `removed` 18 不是同一集合**（交集分析见 spec）。

### REQ-BKV-3 `added` 184 的拆解与溯源

```
172（86 fight 组 × 2 文件）+ 12（非 fight）= 184
```

12 项非 fight 必须逐项给出源侧路径（11 项在 `resource/`，`ranger.str` 为构建生成）。

### REQ-BKV-4 `hdgrp` 696 内容有效性

- 474 非空段头全部 `w>0, h>0`，异常 **0**
- `w 1..82`、`h 1..70`（上限封顶，无异常巨值/零值）
- 222 零长段属 RLE 重复帧，`Σ=222`，分 4 块 `(215,54)/(270,2)/(273,165)/(695,1)`
- 必须与 `eft`（严格递增，零长 1）对照，证明零长是 `hdgrp` 内容特征而非格式缺陷

### REQ-BKV-5 `Wugong` 100 字段对齐

- `Wugong_S` 64 字段，**全 nil 字段数 = 0**
- `名称` 非空 **100/100**
- `武功动画&音效` 越界（`>52`）**2 条**、`max = 55`
- **不得**用 `pairs(JY.Wugong[i])`（元表返回 0 字段）

### REQ-BKV-6 fight 四象限

```
A（同名同容）= 89    B（同名异容）= 3
C（MOD 独有）  = 86    D（MOD 零字节）= 2
自洽：A+B = 92（基线组数）    A+B+C = 178（MOD 组数）
D∩B = 0    D∩C = 2
```

### REQ-BKV-7 fight 与 pineapple 的**反向**分布

```
books    : A 89 / B 3  / C 86 / D 2    （保留基线 + 新增增量）
pineapple: A 2  / B 90 / C 62 / D 115  （改写存量）
```

必须解释：books 的 B 占比 `3/92 = 3.3%`，pineapple `90/92 = 97.8%`
⇒ 分析 fight 必须用四象限，**不能用总数**（books 178 vs pineapple 154，
但两者的"改动性质"完全相反）。

### REQ-BKV-8 `FILE_MISSING` 4 实例的引用链

每个实例必须给出 `代号 → 引用者索引 → 姓名 → 缺失文件` 的完整链条，
并证明源侧与基线侧均不存在。

### REQ-BKV-9 `ranger.str` 957 条完整性

```
总 964 行 / 957 条有效
分段 Person 419 / Thing 368 / Scene 72 / Wugong 98 = 957
字段 Name 670 / Nick 119 / Desc 168 = 957
唯一值 934 / 重复 23（段内去重）
```

### REQ-BKV-10 排名断言必须逐项实测

books 涉及 5 项「全 20 MOD 第 N / 最 X」断言，**每一项都必须有实测支撑**：

| 断言 | 实测值 | 排名 | 前序实测（全 20 MOD） |
|------|-------:|-----:|------|
| `hdgrp` **第 1** | 696 | **1/20** | dream 484 / pig3dos 412 / BookCalamity 373 / awaken 353 / pineapple 300 |
| `kdef` **最少** | 573 | **20/20** | 第 2 少是 SweeOan/pascal/stronger 的 1018；最多 dream 4569 |
| `talk` 第 3 | 6655 | **3/20** | RiverLake 8015 > awaken 7717 > **books 6655** > dream 6464 > BookCalamity 5967 |
| `eft` 第 4 | 973 | **4/20** | BookCalamity 2857 > mingdong 2268 > pineapple 1378 > **books 973** > RiverLake 921 |
| `fight` 第 7 | 178 | **7/20** | BookCalamity 326 > mingdong 267 > awaken 237 > RiverLake 219 > Dragon 209 > pig3dos 180 > **books 178** |
| `Person` 第 9（**非**第 1） | 382 | **9/20** | BookCalamity 800 > awaken 720 = pineapple 720 > mingdong 632 > pig3dos 607 > Dragon 589 > ptt 385 > **books 382** |
| `ranger.grp` 第 9（**非**第 1） | 126478 | **9/20** | BookCalamity 313242 > pineapple 229680 > mingdong 223688 > awaken 207180 > pig3dos 191828 > Dragon 174230 > dream 132270 > ptt 131084 > **books 126478** |
| 零字节 fight 第 4 | 2 | **4/20** | pineapple 115 > RiverLake 44 > ptt 7 > **books 2** = loving 2 |

> **两处特别标注（防误判）**：
> - `kdef 573` 是 **20/20，即最少**——不是「第 20 名」的普通含义，而是**全 epic 最低**。
> - `Person 382` 与 `ranger.grp 126478` 都只是**第 9**，绝非最大。
>   Slice 12 曾把 pineapple 的 `Person 720`（实为第 2，与 awaken 并列）误写成第 1，
>   本 change 对每一个排名都给出手工实测的前序值。

> **规则**：任何「第 1 / 最多」断言都必须与全部 20 个 MOD 实测比对，
> 不得凭印象或凭前序 MOD 的印象外推（Slice 12 曾因此产生 8 处事实错误）。

## 5. Blast Radius

| 路径 | 允许 | 说明 |
|------|:----:|------|
| `openspec/changes/allmods-books-verify/**` | ✅ 写 | 本 change 全部产物 |
| `openspec/changes/allmods-slice13/**` | ✅ 写 | manifest 同步 |
| `openspec/epics/2026-10-allmods-compat/**` | ✅ 写 | epic 索引 |
| `game/mods/books/**` | ⚠ 只读 | 审计对象，本 change 不重构建 |
| `game/tools/**` | ⚠ 仅限已记录缺陷 | 未发现新缺陷 |
| `game/engine-love2d/**` | ❌ 禁 | 四禁改 |
| `game/engine-mud/**` | ❌ 禁 | 四禁改 |
| `game/script/jyconst.lua` 常量 | ❌ 禁 | 四禁改 |
| `reference/allmods/**` | ❌ 禁 | 只读 |

## 6. 交付物

- `proposal.md`（本文件）
- `design.md`（ADR-BKV-001~005 + Negative Constraints + Review Checklist）
- `specs/allmods-books-verification/spec.md`（REQ-BKV-1~10 Given/When/Then）
- `tasks.md`（Blast Radius + 机器可验证 DoD）
- `verification.md`（实测命令 + 输出 + 结论）
- `reports/books-verify.md`（独立审计报告，7 个独特性章节）
