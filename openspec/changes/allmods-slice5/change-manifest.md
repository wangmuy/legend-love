---
status: done
parent_slice: allmods-slice5
parent_epic: 2026-10-allmods-compat
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Change Manifest: allmods-slice5

> 本 slice 将一个 MOD（kys-HeavenSword）的端到端适配拆成 2 个 spec-driven 子 change。
> 子 change 之间通过下方 **Contracts** 传递可验证接口。

## 子 change 列表

| # | 子 change | 依赖 | 状态 |
|---|-----------|------|------|
| 1 | `allmods-heavensword-activate` | Slice 0/0b/0c | [x] Implemented & verified (`verification.md`) |
| 2 | `allmods-heavensword-verify` | 子 change #1 | [x] Implemented & verified (`verification.md`) |

## 执行顺序

```
allmods-heavensword-activate  →  allmods-heavensword-verify
       (构建+机器验证)                 (内容审计+报告)
```

## Contracts

### Contract A: 构建产物契约（子 change #1 产出）

**提供方**：`allmods-heavensword-activate`

**保证**：
- `game/mods/HeavenSword/data/` 含 223 个数据文件（+ `kysmod.ini`）
- `game/mods/HeavenSword/script/oldevent/` 含 **1066** 个事件脚本（严格 UTF-8）
- `game/mods/HeavenSword/script/oldtalk.grp`/`.idx` 为 UTF-8 对话表（3315 条）
- `game/mods/HeavenSword/save/` 含 4 个文件（`d11`/`r11`/`s11` + `r1.idx`）
- `game/mods/HeavenSword/sound/` 含 78 个音频文件
- `game/mods/HeavenSword/diff.md` 为数据差异报告
- **源有 `r1.idx`（= `ranger.idx` 副本）但无 `r1.grp`**

**消费方**：`allmods-heavensword-verify`

### Contract B: 穷举审计契约（子 change #1 产出）

**提供方**：`allmods-heavensword-activate`

**保证**：
- `lua tools/mod_audit.lua --mod HeavenSword` 输出 `unclassified=0 bad_evidence=0`
- 每条记录恰属一个具名类别，`Σ(类别) = total = 335`
- 「必需但未进产物」矛盾数 = 0
- `lua tools/format_spec.lua --mod HeavenSword` 输出 `gaps=0`

**消费方**：`allmods-heavensword-verify`

### Contract C: 启动链路契约（子 change #1 产出）

**提供方**：`allmods-heavensword-activate`

**保证**：
- `lua tests/unit/boot_one_mod.lua HeavenSword 320 200 84 93 楊千葉` 输出 `RESULT HeavenSword: OK`
- 16 项断言全 PASS：布局常量（Person=182/Thing=190/Scene=52/Wugong=136）、
  记录数（320/200/84/93）、主角姓名、无 U+FFFD、无控制符、10 帧无报错

**消费方**：`allmods-heavensword-verify`

### Contract D: `hdgrp` 差异契约（子 change #1 产出）

**提供方**：`allmods-heavensword-activate`

**保证**：
- `hdgrp.idx` 为 500 字节 = **125** 条目（pascal 为 115）
- 引擎通过 `CC.HeadPicFile[1] = mods/HeavenSword/data/hdgrp.idx` 索引驱动加载
- **无固定计数依赖**（无 `CC.HDGRPNum` 之类常量）
- 判定为**内容差异**（更多头像），非结构异常
- `format_spec` 报 `gaps=0` 佐证

**消费方**：`allmods-heavensword-verify`

### Contract E: 存档契约（子 change #1 产出）

**提供方**：`allmods-heavensword-activate`

**保证**：
- 源 `save/` 含 `r1.idx`（24 字节，与 `ranger.idx` **字节相同**）但**无** `r1.grp`
- `CC.R_GRPFilename[1] = mods/HeavenSword/save/r1.grp`
- 首次 `SaveRecord(1)` 播种 `r1.grp`（源 `r1.idx` 保留）
- 字符串改写写入 `r1.ovr`，读档时覆盖表优先
- 验证后产物恢复至原始状态（无残留）

**消费方**：`allmods-heavensword-verify`

### Contract F: 零回归契约（子 change #1 产出）

**提供方**：`allmods-heavensword-activate`

**保证**：
- `lua tests/test_runner.lua` 全绿
- `lua tools/mod_build.lua --verify-pascal` `mismatches=0`
- `lua tools/mod_build.lua --all` `0 build failures`
- `lua tools/mod_check.lua` 20/20

**消费方**：`allmods-heavensword-verify`

### Contract G: MOD 穷举验收契约（跨 slice，来自 Slice 0c）

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
| `allmods-heavensword-activate` | 0 unchecked | ✅ | done |
| `allmods-heavensword-verify` | 0 unchecked | ✅ | done |
