---
parent_epic: 2026-10-allmods-compat
status: done
---
# Change Manifest: allmods-slice2 — 瑞安群侠传端到端

## Change Assignments

### Change: allmods-sweeOan-activate

- **Repository**: this repo
- **Scope**: fullstack（构建流水线 + 审计工具链 + 无头启动验证）
- **Responsibility**: 构建 SweeOan 数据包（`mod_build.lua kys-SweeOan`）；用 Slice 0c 工具链做逐文件穷举审计（`mod_audit`）与字节级覆盖（`format_spec`）；在独立进程中跑真实启动链路（`boot_one_mod.lua`）并断言 MOD 布局常量、记录数、主角姓名、字符串纯净度
- **Depends On**: allmods-slice0（全部 4 个 change）、allmods-slice0b（全部 3 个 change）、allmods-slice0c（全部 3 个 change）
- **Status**: [x] Implemented & verified (verification.md)

### Change: allmods-sweeOan-verify

- **Repository**: this repo
- **Scope**: infra（验证 + 报告）
- **Responsibility**: 审计 `game/mods/SweeOan/diff.md`，逐条核对引擎加载点对 SweeOan 数据形态的容忍度；核对 MOD 独有内容（对话 `oldtalk`、事件 `oldevent_*`、战斗 `fight*`）确实来自 MOD 而非静默回退；产出验证报告 `reports/sweeOan-verify.md`；确认原版零回归
- **Depends On**: allmods-sweeOan-activate
- **Status**: [x] Implemented & verified (verification.md)

## Shared Contract Stubs

### Contract E: MOD 穷举验收契约

```
# allmods-sweeOan-activate 拥有；allmods-sweeOan-verify 消费
lua tools/mod_build.lua kys-SweeOan           # 构建
lua tools/mod_audit.lua --mod SweeOan         # 逐文件穷举
lua tools/format_spec.lua --mod SweeOan       # 字节级覆盖
MOD_SLUG=SweeOan lua tools/mod_check_one.lua  # 产物四项检查
lua tests/unit/boot_one_mod.lua SweeOan 320 200 84 93 王小石   # 真实启动链路
```

**契约要点**：
- `mod_audit --mod <slug>` 必须 `unclassified=0`，且**无「必需类但未进产物」矛盾**。
- `format_spec --mod <slug>` 必须 `gaps=0`（每个字节归入具名字段）。
- `boot_one_mod.lua` 在**独立进程**运行（真实启动是「一次进程一个 MOD」）。
- 期望值（320/200/84/93/王小石）来自 MOD 源数据，不是硬编码常量。

**Contract E 状态**: [x] Fulfilled（6 条命令全部实测通过）

## Integration Test Plan

1. **零回归**：无 `active_mod.txt` → `lua tests/test_runner.lua` 全绿。
2. **构建**：`lua tools/mod_build.lua kys-SweeOan` → `data files=220, saves=6, sound=78, events=1018, talk=2977`。
3. **逐文件归类**：`lua tools/mod_audit.lua --mod SweeOan` → `total=334 in_product=302 not_in_product=32 unclassified=0 bad_evidence=0`。
4. **字节级覆盖**：`lua tools/format_spec.lua --mod SweeOan` → `formats=12 checked=196 gaps=0`。
5. **产物四项检查**：`MOD_SLUG=SweeOan lua tools/mod_check_one.lua` → `STRINGS=OK EVENTS=OK SAVE=OK`，`HERO=王小石`。
6. **真实启动链路**：`boot_one_mod.lua SweeOan 320 200 84 93 王小石` → `RESULT SweeOan: OK`（16 项断言）。
7. **MOD 独有内容**：`oldtalk` 条目数 = 2977；`oldevent_*.lua` = 1018 个；`JY.Person[1]/[2]` = 衛悲回/伊小深（非 pascal 人物）。
8. **资源路径**：`CC.MMAPPicFile[1]` = `mods/SweeOan/data/mmap.idx`；`CC.TalkGrpFile` = `mods/SweeOan/script/oldtalk.grp`；`CC.WarFile` = `mods/SweeOan/data/war.sta`。
9. **原版零回归复跑**：移除激活后全绿。

## Blast Radius（允许改动路径）

- `openspec/changes/allmods-slice2/**`
- `openspec/changes/allmods-sweeOan-*/**`
- `openspec/epics/2026-10-allmods-compat/{epic.md,TODO.md}`
- `game/mods/SweeOan/**`（构建产物）
- `game/tests/**`（仅当需要新增断言时）

**负向约束**（不可改）：

- `game/engine-love2d/**`、`game/engine-mud/**`
- `game/script/jyconst.lua` 常量定义
- `reference/allmods/**`

> 预期本 slice **零引擎改动**：SweeOan 与基线同形（hdgrp 115 / fight 92 / 全部格式尺寸一致）。
