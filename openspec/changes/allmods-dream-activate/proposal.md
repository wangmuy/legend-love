---
status: done
created: 2026-10-26
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice14
---
# Proposal: allmods-dream-activate

> Slice 14 子 change 1/2 —— kys-dream（笑梦游记）的构建 + 机器验证 + 真实启动链路。

## 1. 背景

dream 是 epic 中 `hdgrp` **第 2 大**（484，仅次于 books 696），且携带三个
**本 epic 首次出现**的形态：

| # | 形态 | dream | 前序参照 |
|---|------|------:|----------|
| 1 | 记录段 **5/5 全异** | `409/192/122/102/6` | 基线 `320/200/84/93/3`；lyff 1 段、ptt 4 段 |
| 2 | fight **同时大量增删** | `122 = 92 − 41 删 + 71 增` | 本 epic 首个 |
| 3 | **`eft` 与基线逐字节相同** | 714 offsets / 691627B | books 973 / pineapple 1378 |

## 2. In Scope

- `mod_build.lua kys-dream` 构建产物 `game/mods/dream/`
- 穷举审计 `mod_audit --mod dream --evidence`
- 字节级覆盖 `format_spec --mod dream`
- 产物四项检查 `mod_check_one.lua`（`MOD_SLUG=dream`）
- 真实启动链路 `boot_one_mod.lua dream 409 192 122 102 隨小破`（独立进程）
- 编码转换报告（`ranger.str` 旁路表 763 条）
- 记录段判据（统一判据第 3 次应用）

## 3. Out of Scope

| 项 | 原因 |
|----|------|
| 引擎/工具改动 | 禁改；本 MOD 未发现工具缺陷 |
| `music/*.mid`（25 项）、`list/*.bin`（6 项） | epic 级遗留 spike（PENDING） |
| `fight23.idx` 孤儿（作者残留） | 流水线忠实保留，引擎不读；仅记录 |
| `new.idx`（LEGACY） | 引擎无引用；仅记录 |
| 内容审计 / `diff.md` 逐项定性 | 属 `allmods-dream-verify` |

## 4. 需求（REQ-DRM-1 ~ REQ-DRM-9）

### REQ-DRM-1 构建产物

```
data files=280（构建器口径，不含生成的 ranger.str；目录实测 281）
saves=27  sound=77  events=4569  talk=6464
```

必须声明 `280` 与 `281` 的**口径差**（`ranger.str` 是构建生成物）。

### REQ-DRM-2 穷举审计闭合

```
total=416 in_product=383 not_in_product=33 unclassified=0 bad_evidence=0
REQUIRED 378 + REQUIRED_CONVERTED 4 + LEGACY 3 + DEAD_FILE 1 + BUILD_INPUT 1 + PENDING 29
Σ = 378+4+3+1+1+29 = 416 ✅
evidence: checked=9 failed=0
```

### REQ-DRM-3 字节级覆盖

`formats=12 checked=225 gaps=0`

### REQ-DRM-4 记录段判据（统一判据第 3 次应用）

| 记录 | 段长 | 尺寸 | 商 | 余数 |
|------|-----:|-----:|---:|-----:|
| Person | 74438 | 182 | 409 | 0 |
| Thing | 36480 | 190 | 192 | 0 |
| Scene | 6344 | 52 | 122 | 0 |
| Wugong | 13872 | 136 | 102 | 0 |
| Shop | 300 | 50 | 6 | 0 |

`ranger.idx` = 24B / 6 offsets `[836, 75274, 111754, 118098, 131970, 132270]`，
末 offset `132270` == `ranger.grp` 大小，tail 0。
CC 尺寸实测全部为标准值（182/190/52/136/50），排除 MOD 自定义布局变量。

**关键**：源 `ranger.idx` **完好无损**，`RepairIdx` **未触发**
⇒ dream **不是** `RepairIdx` 案例（zheng 仍是唯一案例）。

### REQ-DRM-5 真实启动链路

```
lua tests/unit/boot_one_mod.lua dream 409 192 122 102 隨小破
→ RESULT dream: OK
```

5 个位置参数**全部为期望值**（防止「实际值 == 自身」的假通过）：

```
CC.PersonSize=182 / ThingSize=190 / SceneSize=52 / WugongSize=136
PersonNum=409 / ThingNum=192 / SceneNum=122 / WugongNum=102
主角姓名=隨小破
扫描字段=1618；U+FFFD=0；控制符=0；10 帧无报错
```

共 16 条断言全 PASS。

### REQ-DRM-6 编码转换与旁路表

```
转换字段数 1618 / 去重复用 855 / 旁路表条目 763 / 截断 0 / hint 溢出 0
分段: Person 409 / Thing 192 / Scene 122 / Wugong 102
```

`ranger.str` 实测 **763** 条（770 行 - 7 注释行），
分段 `Person 243 / Thing 343 / Scene 82 / Wugong 95 = 763`，
字段 `Name 513 / Nick 82 / Desc 168 = 763`，唯一 732 / 重复 31。

### REQ-DRM-7 `hdgrp` 484

```
hdgrp.idx=1936B → 484 offsets；hdgrp.grp=944448B；offs[0]=2895；tail=0
483 段 = 411 有效 RLE + 72 零长；头异常 0；w 1..58 / h 1..71
```

`484 offsets` ↔ `483 段`（末 offset 为哨兵）。基线 `115 offsets = 114 段`
（PNG 2 + RLE 112 + 零长 0，`w 13..56`）。

### REQ-DRM-8 `eft` 与基线逐字节相同

```
dream  eft.idx = 2856B  eft.grp = 691627B
baseline eft.idx = 2856B  eft.grp = 691627B
md5 相同：eft.idx True / eft.grp True
```

⇒ dream **完全沿用基线 eft**，未改任何特效资源。
这是 books（973，全 RLE，改动）与 pineapple（1378，改动）的**反面样本**。

### REQ-DRM-9 8 道门禁不回归

activate 完成后必须复跑并全绿（1842 测试 / `--verify-pascal` / `--all` /
`mod_check` / `mod_audit --all` / `format_spec --all` / gate 7 / gate 8）。

## 5. Blast Radius

| 路径 | 允许 | 说明 |
|------|:----:|------|
| `game/mods/dream/**` | ✅ 写 | 构建产物 |
| `openspec/changes/allmods-dream-activate/**` | ✅ 写 | 本 change |
| `openspec/changes/allmods-slice14/**` | ✅ 写 | manifest |
| `openspec/epics/2026-10-allmods-compat/**` | ✅ 写 | 索引 |
| `reference/allmods/kys-dream/**` | ⚠ 只读 | 构建输入 |
| `game/tools/**` | ❌ 不改 | 未发现工具缺陷 |
| `game/engine-love2d/**` | ❌ 禁 | 四禁改 |
| `game/engine-mud/**` | ❌ 禁 | 四禁改 |
| `game/script/jyconst.lua` 常量 | ❌ 禁 | 四禁改 |

## 6. 交付物

- `proposal.md`（本文件）
- `design.md`（ADR-DRM-001~005 + Negative Constraints + Review Checklist）
- `specs/allmods-dream-activation/spec.md`（REQ-DRM-1~9 Given/When/Then）
- `tasks.md`（Blast Radius + 机器可验证 DoD）
- `verification.md`（实测命令 + 输出 + 结论）
