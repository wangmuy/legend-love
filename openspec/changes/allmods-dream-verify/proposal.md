---
status: done
created: 2026-10-26
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice14
---
# Proposal: allmods-dream-verify

> Slice 14 子 change 2/2 —— 对 dream 构建产物做**逐项真实性审计**，
> 重点取证 dream 的三个独特性：`kdef` 全 MOD 第 1、fight 增删并行、
> `eft` 零改动。

## 1. 背景

`allmods-dream-activate` 解决了「能构建、能启动、数字对」。本 change 解决
「**内容真的是 MOD 作者的意图**」。

dream 在四处与前面 13 个 MOD 显著不同：

| 差异点 | dream | 前序参照 |
|--------|------:|----------|
| `kdef` 事件 | **4569**（全 20 MOD **第 1**） | BookCalamity 1701 / pascal 1018 |
| `hdgrp` | **484**（第 2） | books 696 / pig3dos 412 |
| fight 形态 | **增删并行**（`92 − 41 + 71 = 122`） | books 保留+增；pineapple 全改写 |
| `eft` | **md5 与基线全同（零改动）** | books 973 / pineapple 1378 改动 |
| 记录段 | **5/5 全异** | lyff 1 段 / ptt 4 段 |

## 2. In Scope

- `diff.md` **双向集合相等**验证（`added 156` / `removed 105`）
- `removed 105` 精确四分法（9 槽 grp + 9 槽 idx + 84 回退 + 3 死文件 + 0 真删除）
- `added 156` 拆解（71 组 fight 配对 × 2 = 142 + 孤儿 `fight23.idx` 1 + 13 非 fight）
- **fight 五分类**（保留 2 / 改写 49 / 删除 41 / 新增 71 / 零字节 0）
- `hdgrp` 484 逐条内容有效性（411 RLE + 72 零长，头异常 0）
- `eft` 零改动的三重证明（md5 + diff 缺席 + 大小相同）
- `ranger.str` 763 条侧表完整性
- 存档完整性（产物 27 / 源 31，改道 4 项）
- 8 项排名实测
- `reports/dream-verify.md` 独立报告

## 3. Out of Scope

| 项 | 原因 |
|----|------|
| 修复 41 场被删战斗 | 是 MOD 作者设计（回退原版），非缺陷 |
| `fight23.idx` 孤儿清理 | 流水线忠实保留，引擎不读；仅记录 |
| `new.idx`（LEGACY）清理 | 引擎无引用；仅记录 |
| `kdef.grp` 尾部 12B 残留 | 源侧本有（md5 全同），忠实搬运 |
| `music/*.mid` / `list/*.bin` | epic 级遗留 spike（PENDING 29） |
| 引擎/工具改动 | 禁改；本 MOD 未发现工具缺陷 |

## 4. 需求（REQ-DRMV-1 ~ REQ-DRMV-10）

### REQ-DRMV-1 `diff.md` 双向 set 相等

```
diff.md added=156  removed=105
实测 MOD 独有=156  实测基线独有=105
add == 实测? True    rem == 实测? True
```

不得以数量相等代替集合相等。

### REQ-DRMV-2 `removed` 105 的四分法闭合

```
9（槽 .grp，源提供且产物 save/ 一致）
+ 9（槽 .idx，源不存在，SeedSaveSlot 播种）
+ 84（41 场基线战斗 × 2 = 82 + thing.grp/idx = 2）
+ 3（死文件 alldef.idx / allsin.idx / allsinbk.grp）
+ 0（真删除）
= 105 ✅
```

### REQ-DRMV-3 `added` 156 的拆解

```
142（71 组 fight 配对 × 2：.grp + .idx）
+ 1（孤儿 fight23.idx：有 idx 无 grp，作者残留）
+ 13（非 fight）
= 156 ✅
```

**必须显式识别孤儿 `fight23.idx`**：fight `.grp` 组数为 **71**，但 `.idx` 组数为 **72**，
差集恰为 `{23}`（`fight23.idx` 存在，`fight23.grp` 不存在，源侧亦然）。
若不单列，`71×2=142` 会与 `added` 的 fight 条目数 `143` 冲突。

13 项非 fight 必须逐项溯源：

| 文件 | 源侧 |
|------|------|
| `cloud.grp` / `cloud.idx` | `resource/` |
| `icon.png` | `resource/` |
| `kdef.grp` / `kdef.idx` | `resource/` |
| `kysmod.ini` | **根目录** |
| `new.idx` | `resource/`（LEGACY） |
| `open.png` | `resource/` |
| `ranger.str` | **源中不存在（构建生成）** |
| `talk.grp` / `talk.idx` | `resource/` |
| `title.grp` / `title.idx` | `resource/` |

### REQ-DRMV-4 fight **五分类**（含删除象限）

```
A 保留（同名同容）  = 2
B 改写（同名异容）  = 49
E 删除（基线有 MOD 无）= 41
C 新增（MOD 独有）  = 71
D 零字节           = 0

自洽：A + B + E = 2 + 49 + 41 = 92  = 基线组数  ✅
      A + B + C = 2 + 49 + 71 = 122 = MOD 组数   ✅
      92 − 41 + 71 = 122 ✅
```

**必须扩展为五分类**：dream 下 `A + B = 51 ≠ 92`，「四象限」框架不足。

### REQ-DRMV-5 三种 fight 形态的跨 MOD 对照

| MOD | 形态 | A | B | E(删) | C(增) | D(零) |
|-----|------|---:|---:|---:|---:|---:|
| books | 保留 + 新增增量 | 89 | 3 | **0** | 86 | 2 |
| pineapple | 几乎全改写 | 2 | 90 | **0** | 62 | 115 |
| **dream** | **增删并行** | 2 | 49 | **41** | 71 | 0 |

⇒ 任何单一计数口径都会漏项；必须五分类。

### REQ-DRMV-6 `hdgrp` 484 内容有效性

- `484 offsets` / `483 段`（末 offset 为哨兵）
- `411 RLE + 72 零长 = 483`，**头异常 0**
- `w 1..58` / `h 1..71`（上限封顶）
- 零长块 `(381, 69) (480, 3)` = 72
- 基线 `115 offsets / 114 段 = PNG 2 + RLE 112 + 零长 0`

### REQ-DRMV-7 `eft` 零改动的三重证明

1. `md5(eft.idx)` 与基线**相同**（2856B）
2. `md5(eft.grp)` 与基线**相同**（691627B）
3. `eft.*` **不在** `diff.md` 的 `added`/`removed`

⇒ 产物真实存在（非回退），内容与基线完全相同。
dream 是 epic 中 `eft` 零改动的**正样本**。

### REQ-DRMV-8 `ranger.str` 763 条完整性

```
770 行 / 763 有效 / 7 注释
分段 Person 243 / Thing 343 / Scene 82 / Wugong 95 = 763
字段 Name 513 / Nick 82 / Desc 168 = 763
唯一 732 / 重复 31
```

且必须与 `encoding-report.md` 的「旁路表条目 763」一致。

### REQ-DRMV-9 存档 `save/` 27 vs 源 31

```
产物 save/ = 27（全槽 .grp，无 .idx）
源   save/ = 31（27 槽 + alldef.grp + allsin.grp + ranger.grp + ranger.idx）
27/27 逐字节一致
4 项改道 data/：alldef/allsin/ranger.idx md5 同；ranger.grp 因编码转换而异（大小同）
```

不得把 `save/` 27 与源 31 写成「逐字节一致」。

### REQ-DRMV-10 8 项排名必须逐项实测

| 断言 | 实测值 | 排名 |
|------|-------:|-----:|
| `kdef` **第 1** | 4569 | **1/20** |
| `hdgrp` **第 2** | 484 | **2/20** |
| `talk` 第 4 | 6464 | **4/20** |
| `Person` 第 7 | 409 | **7/20** |
| `fight` 第 12 | 122 | **12/20** |
| `eft` 与基线相同 | 714 | — |
| 零字节 fight | 0 | 20/20（并列最少） |
| 记录段全异 | 5/5 | 本 epic 唯一 |

> **规则**：任何「第 1 / 最多」断言必须与全部 20 个 MOD 实测比对。

## 5. Blast Radius

| 路径 | 允许 | 说明 |
|------|:----:|------|
| `openspec/changes/allmods-dream-verify/**` | ✅ 写 | 本 change |
| `openspec/changes/allmods-slice14/**` | ✅ 写 | manifest 同步 |
| `openspec/epics/2026-10-allmods-compat/**` | ✅ 写 | epic 索引 |
| `game/mods/dream/**` | ⚠ 只读 | 审计对象 |
| `game/tools/**` | ❌ 不改 | 未发现工具缺陷 |
| `game/engine-love2d/**` | ❌ 禁 | 四禁改 |
| `game/engine-mud/**` | ❌ 禁 | 四禁改 |
| `game/script/jyconst.lua` 常量 | ❌ 禁 | 四禁改 |
| `reference/allmods/**` | ❌ 禁 | 只读 |

## 6. 交付物

- `proposal.md`（本文件）
- `design.md`（ADR-DRMV-001~006 + Negative Constraints + Review Checklist）
- `specs/allmods-dream-verification/spec.md`（REQ-DRMV-1~10 Given/When/Then）
- `tasks.md`（Blast Radius + 机器可验证 DoD）
- `verification.md`（实测命令 + 输出 + 结论）
- `reports/dream-verify.md`（独立审计报告，7 个独特性章节）
