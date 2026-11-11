---
status: done
parent_slice: allmods-slice9
parent_epic: 2026-10-allmods-compat
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Change Manifest: allmods-slice9

> 本 slice 将一个 MOD（kys-ptt）的端到端适配拆成 2 个 spec-driven 子 change。
> 子 change 之间通过下方 **Contracts** 传递可验证接口。

## 子 change 列表

| # | 子 change | 依赖 | 状态 |
|---|-----------|------|------|
| 1 | `allmods-ptt-activate` | Slice 0/0b/0c | [x] Implemented & verified (`verification.md`) |
| 2 | `allmods-ptt-verify` | 子 change #1 | [x] Implemented & verified (`verification.md`) |

## 执行顺序

```
allmods-ptt-activate  →  allmods-ptt-verify
    (构建+机器验证)          (内容审计+报告)
```

## Contracts

### Contract A: 构建产物契约（子 change #1 产出）

**提供方**：`allmods-ptt-activate`

**保证**：
- `game/mods/ptt/data/` 含 362 个数据文件（+ `kysmod.ini`）
- `game/mods/ptt/data/fight*.grp` 共 **162** 场战斗
- `game/mods/ptt/script/oldevent/` 含 **1229** 个事件脚本（严格 UTF-8）
- `game/mods/ptt/script/oldtalk.grp`/`.idx` 为 UTF-8 对话表（5689 条）
- `game/mods/ptt/save/` 含 **21** 个文件
- `game/mods/ptt/sound/` 含 78 个音频文件
- `game/mods/ptt/diff.md` 为数据差异报告

**消费方**：`allmods-ptt-verify`

### Contract B: 穷举审计契约（子 change #1 产出）

**提供方**：`allmods-ptt-activate`

**保证**：
- `lua tools/mod_audit.lua --mod ptt` 输出 `unclassified=0 bad_evidence=0`
- 每条记录恰属一个具名类别，`Σ(类别) = total = 596`
- 「必需但未进产物」矛盾数 = 0
- `lua tools/format_spec.lua --mod ptt` 输出 `gaps=0`

**消费方**：`allmods-ptt-verify`

### Contract C: 启动链路契约（子 change #1 产出）

**提供方**：`allmods-ptt-activate`

**保证**：
- `lua tests/unit/boot_one_mod.lua ptt 385 214 90 108 鄉民` 输出 `RESULT ptt: OK`
- 16 项断言全 PASS：布局常量（Person=182/Thing=190/Scene=52/Wugong=136）、
  记录数（385/214/90/108）、主角姓名（鄉民）、无 U+FFFD、无控制符、10 帧无报错

**消费方**：`allmods-ptt-verify`

### Contract D: `hdgrp` 差异契约（子 change #1 产出）

**提供方**：`allmods-ptt-activate`

**保证**：
- `hdgrp.idx` 为 816 字节 = **204** 条目（pascal 115）
- 引擎索引驱动加载（`PicLoadFile` 用 `idxlen/4`）
- **无固定计数依赖**
- 判定为**内容差异**
- `format_spec` 报 `gaps=0` 佐证
- 这是 Slice 5 判据的**第 5 次应用**（125/129/173/178/204）

**消费方**：`allmods-ptt-verify`

### Contract E: 记录段差异契约（子 change #1 产出）

**提供方**：`allmods-ptt-activate`

**保证**：
- 4 个记录段与基线全部不同：**Person 385**（70070=385×182）/ **Thing 214**（40660=214×190）/
  **Scene 90**（4680=90×52）/ **Wugong 108**（14688=108×136）
- 每段：段长整除记录大小 + 索引驱动（`jymain.lua` 按 `idx[k+1]-idx[k]` 推导）+
  边界记录可读（tail32 含有效 hint）+ `gaps=0`
- 判定为**内容差异**（零引擎改动）
- 统一判据（Slice 8 ADR）的**第 2 次应用**，且是**首个全段差异 MOD**

**消费方**：`allmods-ptt-verify`

### Contract F: 额外战斗契约（子 change #1 产出）

**提供方**：`allmods-ptt-activate`

**保证**：
- **70 场额外战斗**（本 epic 最多）：`fight073`、`fight104`、`fight106`、`fight108`、
  `fight110`、`fight112`、`fight114`、`fight115`、`fight117`~`129`、`fight130`~`134`、
  `fight136`~`145`、`fight150`~`154`、`fight157`、`fight169`、`fight171`、`fight175`、
  `fight177`~`182`、`fight184`~`195`、`fight197`~`202`、`fight216`
- 每场三重确认：`diff.md` 提及 + 产物 `data/fightNNN.grp` 存在 + 审计归类 `REQUIRED`/`in_product=true`
- 产物 `fight*.grp` 总数 = **162**（pascal 92 + 70）

**消费方**：`allmods-ptt-verify`

### Contract G: 存档契约（子 change #1 产出）

**提供方**：`allmods-ptt-activate`

**保证**：
- 产物 `save/` 含 21 个文件（`d1`~`d6`/`r1`~`r6`/`s1`~`s6` + `d11`/`r11`/`s11`），与源逐字节一致
- 源自带 **18 个存档槽**（本 epic 最多，pig 为 9 个）
- `CC.D_Filename[1] = mods/ptt/save/d1.grp`
- `CC.R_GRPFilename[1] = mods/ptt/save/r1.grp`
- `CC.S_Filename[1] = mods/ptt/save/s1.grp`
- 验证后产物恢复至原始状态

**消费方**：`allmods-ptt-verify`

### Contract H: 零回归契约（子 change #1 产出）

**提供方**：`allmods-ptt-activate`

**保证**：
- `lua tests/test_runner.lua` 全绿（1613/1613）
- `lua tools/mod_build.lua --verify-pascal` `mismatches=0`
- `lua tools/mod_build.lua --all` `0 build failures`
- `lua tools/mod_check.lua` 20/20
- 全量测试后全 MOD `save/` 与源一致

**消费方**：`allmods-ptt-verify`

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
| `allmods-ptt-activate` | 0 unchecked | ✅ | done |
| `allmods-ptt-verify` | 0 unchecked | ✅ | done |

## 代码改动

本 slice 唯一的代码改动：`game/tools/mod_encoding.lua` 的 `isStringField` 加固
（Slice 8 遗留项收尾）——高位字节必须成对且能在 Big5 表中解码，
与 `DecodeBig5` 能力严格镜像，剔除「裸高位测试」的假阳性。

- 对真实数据**逐字节 no-op**：重建 20 MOD 后 `ranger.str` md5 **20/20 不变**。
- 回归断言 +9（`testIsStringFieldDiscriminator` + `testRangerStrSideTableContents`），
  测试总数 **1613 → 1622**。
- 其余全部门禁通过：`--verify-pascal` `mismatches=0`、`--all` 0 failures、
  `mod_check` 20/20、`mod_audit --all` `unclassified=0`、`format_spec --all` `gaps=0`、
  全 MOD `save/` 341 文件不一致 = 0。
