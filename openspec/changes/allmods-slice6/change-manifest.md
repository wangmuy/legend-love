---
status: done
parent_slice: allmods-slice6
parent_epic: 2026-10-allmods-compat
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Change Manifest: allmods-slice6

> 本 slice 将一个 MOD（kys-GodsDevils）的端到端适配拆成 2 个 spec-driven 子 change。
> 子 change 之间通过下方 **Contracts** 传递可验证接口。

## 子 change 列表

| # | 子 change | 依赖 | 状态 |
|---|-----------|------|------|
| 1 | `allmods-godsdevils-activate` | Slice 0/0b/0c | [x] Implemented & verified (`verification.md`) |
| 2 | `allmods-godsdevils-verify` | 子 change #1 | [x] Implemented & verified (`verification.md`) |

## 执行顺序

```
allmods-godsdevils-activate  →  allmods-godsdevils-verify
       (构建+机器验证)                (内容审计+报告)
```

## Contracts

### Contract A: 构建产物契约（子 change #1 产出）

**提供方**：`allmods-godsdevils-activate`

**保证**：
- `game/mods/GodsDevils/data/` 含 219 个数据文件（+ `kysmod.ini`）
- `game/mods/GodsDevils/script/oldevent/` 含 **1123** 个事件脚本（严格 UTF-8）
- `game/mods/GodsDevils/script/oldtalk.grp`/`.idx` 为 UTF-8 对话表（4640 条）
- `game/mods/GodsDevils/save/` 含 **9** 个文件（`d11`/`r11`/`s11` + `d1`/`d2`/`r1`/`r2`/`s1`/`s2`）
- `game/mods/GodsDevils/sound/` 含 78 个音频文件
- `game/mods/GodsDevils/diff.md` 为数据差异报告
- `head/`/`item/` PNG 目录**不进产物**（`EDITOR_DUMP`）

**消费方**：`allmods-godsdevils-verify`

### Contract B: 穷举审计契约（子 change #1 产出）

**提供方**：`allmods-godsdevils-activate`

**保证**：
- `lua tools/mod_audit.lua --mod GodsDevils` 输出 `unclassified=0 bad_evidence=0`
- 每条记录恰属一个具名类别，`Σ(类别) = total = 615`
- 「必需但未进产物」矛盾数 = 0
- `lua tools/format_spec.lua --mod GodsDevils` 输出 `gaps=0`

**消费方**：`allmods-godsdevils-verify`

### Contract C: 启动链路契约（子 change #1 产出）

**提供方**：`allmods-godsdevils-activate`

**保证**：
- `lua tests/unit/boot_one_mod.lua GodsDevils 320 200 84 93 蝦米` 输出 `RESULT GodsDevils: OK`
- 16 项断言全 PASS：布局常量（Person=182/Thing=190/Scene=52/Wugong=136）、
  记录数（320/200/84/93）、主角姓名、无 U+FFFD、无控制符、10 帧无报错

**消费方**：`allmods-godsdevils-verify`

### Contract D: `hdgrp` 差异契约（子 change #1 产出）

**提供方**：`allmods-godsdevils-activate`

**保证**：
- `hdgrp.idx` 为 516 字节 = **129** 条目（pascal 115）
- 引擎索引驱动加载（`PicLoadFile` 用 `idxlen/4`）
- **无固定计数依赖**
- 判定为**内容差异**
- `format_spec` 报 `gaps=0` 佐证

**消费方**：`allmods-godsdevils-verify`

### Contract E: EDITOR_DUMP 契约（子 change #1 产出）

**提供方**：`allmods-godsdevils-activate`

**保证**：
- `head/`（79 PNG）+ `item/`（200 PNG）= **279** 个文件归类为 `EDITOR_DUMP`
- 引擎**不读**这两个目录（`grep` 无引用）
- `Σ(EDITOR_DUMP) = 279`

**消费方**：`allmods-godsdevils-verify`

### Contract F: 存档契约（子 change #1 产出）

**提供方**：`allmods-godsdevils-activate`

**保证**：
- 产物 `save/` 含 9 个文件，与源逐字节一致
- `CC.D_Filename[1] = mods/GodsDevils/save/d1.grp`
- `CC.R_GRPFilename[1] = mods/GodsDevils/save/r1.grp`
- `CC.S_Filename[1] = mods/GodsDevils/save/s1.grp`
- 验证后产物恢复至原始状态

**消费方**：`allmods-godsdevils-verify`

### Contract G: 零回归契约（子 change #1 产出）

**提供方**：`allmods-godsdevils-activate`

**保证**：
- `lua tests/test_runner.lua` 全绿
- `lua tools/mod_build.lua --verify-pascal` `mismatches=0`
- `lua tools/mod_build.lua --all` `0 build failures`
- `lua tools/mod_check.lua` 20/20
- 全量测试后全 MOD `save/` 与源一致

**消费方**：`allmods-godsdevils-verify`

### Contract H: MOD 穷举验收契约（跨 slice，来自 Slice 0c）

**提供方**：Slice 0c（`allmods-slice0c-*`）

**保证**：每个 MOD 的**每个源文件**都被归类，且：
- 不需要的文件有结构化证据（6 种证据种类）
- 需要的文件被字节级格式规范覆盖（`format_spec.lua`）

**消费方**：本 slice 的两个子 change

## 验证策略

每个子 change 的 `verification.md` 必须含：
1. REQ 追溯矩阵
2. 实测命令与输出
3. Blast Radius 合规检查
4. 偏差记录

## 状态汇总

| 子 change | tasks | verification | status |
|-----------|-------|--------------|--------|
| `allmods-godsdevils-activate` | 0 unchecked | ✅ | done |
| `allmods-godsdevils-verify` | 0 unchecked | ✅ | done |
