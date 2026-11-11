---
status: done
parent_slice: allmods-slice8
parent_epic: 2026-10-allmods-compat
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Change Manifest: allmods-slice8

> 本 slice 将一个 MOD（kys-lyff）的端到端适配拆成 2 个 spec-driven 子 change。
> 子 change 之间通过下方 **Contracts** 传递可验证接口。

## 子 change 列表

| # | 子 change | 依赖 | 状态 |
|---|-----------|------|------|
| 1 | `allmods-lyff-activate` | Slice 0/0b/0c | done |
| 2 | `allmods-lyff-verify` | 子 change #1 | done |

## 执行顺序

```
allmods-lyff-activate  →  allmods-lyff-verify
    (构建+机器验证)          (内容审计+报告)
```

## Contracts

### Contract A: 构建产物契约（子 change #1 产出）

**提供方**：`allmods-lyff-activate`

**保证**：
- `game/mods/lyff/data/` 含 311 个数据文件（+ `kysmod.ini`）
- `game/mods/lyff/data/fight*.grp` 共 **138** 场战斗（92 + 46）
- `game/mods/lyff/script/oldevent/` 含 **1358** 个事件脚本（严格 UTF-8）
- `game/mods/lyff/script/oldtalk.grp`/`.idx` 为 UTF-8 对话表（**5655** 条，本 epic 最多）
- `game/mods/lyff/save/` 含 **6** 个文件
- `game/mods/lyff/sound/` 含 78 个音频文件
- `game/mods/lyff/diff.md` 为数据差异报告

**消费方**：`allmods-lyff-verify`

### Contract B: 穷举审计契约（子 change #1 产出）

**提供方**：`allmods-lyff-activate`

**保证**：
- `lua tools/mod_audit.lua --mod lyff` 输出 `unclassified=0 bad_evidence=0`
- 每条记录恰属一个具名类别，`Σ(类别) = total = 425`
- 「必需但未进产物」矛盾数 = 0
- `lua tools/format_spec.lua --mod lyff` 输出 `gaps=0`

**消费方**：`allmods-lyff-verify`

### Contract C: 启动链路契约（子 change #1 产出）

**提供方**：`allmods-lyff-activate`

**保证**：
- `lua tests/unit/boot_one_mod.lua lyff 326 200 84 93 AAA` 输出 `RESULT lyff: OK`
- 16 项断言全 PASS：布局常量（Person=182/Thing=190/Scene=52/Wugong=136）、
  记录数（**326**/200/84/93）、主角姓名（**AAA**）、无 U+FFFD、无控制符、10 帧无报错

**消费方**：`allmods-lyff-verify`

### Contract D: `hdgrp` 差异契约（子 change #1 产出）

**提供方**：`allmods-lyff-activate`

**保证**：
- `hdgrp.idx` 为 **712** 字节 = **178** 条目（pascal 115）
- 引擎索引驱动加载（`PicLoadFile` 用 `idxlen/4`）
- **无固定计数依赖**
- 判定为**内容差异**
- `format_spec` 报 `gaps=0` 佐证
- 这是 Slice 5 判据的**第 4 次应用**（前 3 次：HeavenSword 125、GodsDevils 129、pig 173）

**消费方**：`allmods-lyff-verify`

### Contract E: **PERSON 差异契约**（子 change #1 产出，**本 epic 首次**）

**提供方**：`allmods-lyff-activate`

**保证**：
- `JY.PersonNum = 326`（pascal 320，**+6 人物**）
- `ranger.grp` seg1（Person 段）= 59332 字节 = 326 × 182
- `JY.PersonNum = math.floor((idx[2]-idx[1])/CC.PersonSize)` —— **索引驱动**，无固定常量
- 额外 6 个人物位于索引 320~325
- 判定为**内容差异**，**零引擎改动**
- 这是本 epic **首次**出现非 320 人物数

**消费方**：`allmods-lyff-verify`

### Contract F: 额外战斗契约（子 change #1 产出）

**提供方**：`allmods-lyff-activate`

**保证**：
- **46 场额外战斗**（`fight030`、`fight039`/`040`、`fight110`、`fight115`~`121`、
  `fight125`/`126`/`128`~`131`/`133`~`146`/`152`~`162`/`167`/`169`/`170`/`173`）
- 每场三重确认：`diff.md` 提及 + 产物 `data/fightNNN.grp` 存在 + 审计归类 `REQUIRED`/`in_product=true`
- 产物 `fight*.grp` 总数 = **138**（pascal 92 + 46）
- 比 pig（45 场）多 `fight173`

**消费方**：`allmods-lyff-verify`

### Contract G: 存档契约（子 change #1 产出）

**提供方**：`allmods-lyff-activate`

**保证**：
- 产物 `save/` 含 6 个文件（`d11`/`d1`/`r11`/`r1`/`s11`/`s1` `.grp`），与源逐字节一致
- 源自带 3 个槽（`d1`/`r1`/`s1`），比 pig（9 个）少
- `CC.D_Filename[1] = mods/lyff/save/d1.grp`
- `CC.R_GRPFilename[1] = mods/lyff/save/r1.grp`
- `CC.S_Filename[1] = mods/lyff/save/s1.grp`
- 验证后产物恢复至原始状态

**消费方**：`allmods-lyff-verify`

### Contract H: 零回归契约（子 change #1 产出）

**提供方**：`allmods-lyff-activate`

**保证**：
- `lua tests/test_runner.lua` 全绿
- `lua tools/mod_build.lua --verify-pascal` `mismatches=0`
- `lua tools/mod_build.lua --all` `0 build failures`
- `lua tools/mod_check.lua` 20/20
- 全量测试后全 MOD `save/` 与源一致

**消费方**：`allmods-lyff-verify`

### Contract I: MOD 穷举验收契约（跨 slice，来自 Slice 0c）

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
| `allmods-lyff-activate` | done | — | done |
| `allmods-lyff-verify` | done | — | done |
