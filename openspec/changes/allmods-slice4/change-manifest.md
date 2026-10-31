---
status: done
parent_slice: allmods-slice4
parent_epic: 2026-10-allmods-compat
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Change Manifest: allmods-slice4

> 本 slice 将一个 MOD（kys-lostbook）的端到端适配拆成 2 个 spec-driven 子 change。
> 子 change 之间通过下方 **Contracts** 传递可验证接口。

## 子 change 列表

| # | 子 change | 依赖 | 状态 |
|---|-----------|------|------|
| 1 | `allmods-lostbook-activate` | Slice 0/0b/0c | [x] Implemented & verified (`verification.md`) |
| 2 | `allmods-lostbook-verify` | 子 change #1 | [x] Implemented & verified (`verification.md`) |

## 执行顺序

```
allmods-lostbook-activate  →  allmods-lostbook-verify
        (构建+机器验证)              (内容审计+报告)
```

## Contracts

### Contract A: 构建产物契约（子 change #1 产出）

**提供方**：`allmods-lostbook-activate`

**保证**：
- `game/mods/lostbook/data/` 含 231 个数据文件（+ `kysmod.ini`）
- `game/mods/lostbook/script/oldevent/` 含 **1071** 个事件脚本（严格 UTF-8）
- `game/mods/lostbook/script/oldtalk.grp`/`.idx` 为 UTF-8 对话表（3181 条）
- `game/mods/lostbook/save/` 含 3 个存档槽
- `game/mods/lostbook/sound/` 含 78 个音频文件
- `game/mods/lostbook/diff.md` 为数据差异报告
- **源无 `r1.grp`**（`r1` 槽为首次存档时播种），产物亦不含

**消费方**：`allmods-lostbook-verify`

### Contract B: 穷举审计契约（子 change #1 产出）

**提供方**：`allmods-lostbook-activate`

**保证**：
- `lua tools/mod_audit.lua --mod lostbook` 输出 `unclassified=0 bad_evidence=0`
- 每条记录恰属一个具名类别，`Σ(类别) = total = 342`
- 「必需但未进产物」矛盾数 = 0
- `lua tools/format_spec.lua --mod lostbook` 输出 `gaps=0`

**消费方**：`allmods-lostbook-verify`

### Contract C: 启动链路契约（子 change #1 产出）

**提供方**：`allmods-lostbook-activate`

**保证**：
- `lua tests/unit/boot_one_mod.lua lostbook 320 200 84 93 金迷` 输出 `RESULT lostbook: OK`
- 16 项断言全 PASS：布局常量（Person=182/Thing=190/Scene=52/Wugong=136）、
  记录数（320/200/84/93）、主角姓名、无 U+FFFD、无控制符、10 帧无报错

**消费方**：`allmods-lostbook-verify`

### Contract D: 存档播种契约（子 change #1 产出）

**提供方**：`allmods-lostbook-activate`

**保证**：
- lostbook 源 `save/` 无 `r1.grp`（仅 `d11/r11/s11` + `d1/s1`）
- `CC.R_GRPFilename[1] = mods/lostbook/save/r1.grp`
- 首次 `SaveRecord(1)` 从 `ranger.idx` 播种 `r1.idx`/`r1.grp`
- 字符串改写写入 `r1.ovr`，读档时覆盖表优先
- 验证后产物恢复至原始状态（无残留）

**消费方**：`allmods-lostbook-verify`

### Contract E: 零回归契约（子 change #1 产出）

**提供方**：`allmods-lostbook-activate`

**保证**：
- `lua tests/test_runner.lua` 全绿
- `lua tools/mod_build.lua --verify-pascal` `mismatches=0`
- `lua tools/mod_build.lua --all` `0 build failures`
- `lua tools/mod_check.lua` 20/20

**消费方**：`allmods-lostbook-verify`

### Contract F: MOD 穷举验收契约（跨 slice，来自 Slice 0c）

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
| `allmods-lostbook-activate` | 0 unchecked | ✅ | done |
| `allmods-lostbook-verify` | 0 unchecked | ✅ | done |
