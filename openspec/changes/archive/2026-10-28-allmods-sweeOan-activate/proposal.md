---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice2
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Proposal: allmods-sweeOan-activate

## Why

Slice 0/0b/0c 建立了 MOD 兼容地基（回退链、别名映射、音效回退、逐文件穷举审计、字节级覆盖）。
但地基只在 `kys-mingdong` 上做过端到端验证。**SweeOan 是剩余 MOD 清单第 1 梯队的第 1 个**，
与基线完全同形（hdgrp 115 / fight 92），是验证「地基对同形 MOD 是否零改动即通」的最佳样本。

如果 SweeOan 需要引擎改动，说明地基有遗漏；如果零改动即通，则第 1 梯队其余 2 个 MOD
（stronger、lostbook）可预期同样通过。

## What Changes

1. 构建 SweeOan 数据包到 `game/mods/SweeOan/`。
2. 用 Slice 0c 工具链做**逐文件穷举审计**与**字节级覆盖**验证。
3. 在**独立进程**中跑真实启动链路（`lib.init` → `JYMainAdapter.init` → `LoadRecord(0)`）。
4. 断言 MOD 布局常量、记录数、主角姓名、字符串纯净度。

## In Scope

- SweeOan 构建 + 审计 + 启动链路验证（见 `change-manifest.md` Contract E）
- 若发现缺陷：修复并记录（预期无）

## Out of Scope

- 其余 17 个 MOD（Slice 3-18）
- `music/*.mid` PENDING spike
- 引擎侧改动（除非审计发现真实缺陷）

## Requirements

### REQ-SWEE-1: 构建成功

`lua tools/mod_build.lua kys-SweeOan` 退出码 0，输出 `events=1018`。

### REQ-SWEE-2: 逐文件穷举归类完整

`lua tools/mod_audit.lua --mod SweeOan` → `total=334 unclassified=0 bad_evidence=0`；
且**无「必需类但未进产物」矛盾**（`IN_PRODUCT_BY_CATEGORY` 为真的类别必须全部在产物中）。

### REQ-SWEE-3: 字节级覆盖无缺口

`lua tools/format_spec.lua --mod SweeOan` → `gaps=0`（每个字节归入具名字段）。

### REQ-SWEE-4: 真实启动链路通过

独立进程 `lua tests/unit/boot_one_mod.lua SweeOan 320 200 84 93 王小石` → `RESULT SweeOan: OK`。
必须覆盖：MOD 布局常量 5 项、记录数 4 项、主角姓名、无 U+FFFD、无控制符、10 帧无报错。

### REQ-SWEE-5: MOD 独有内容确实被加载

- `CC.MMAPPicFile[1]` 指向 `mods/SweeOan/data/`
- `CC.TalkGrpFile` 指向 `mods/SweeOan/script/`
- 对话条目数 = 2977；事件脚本数 = 1018
- `JY.Person[1]/[2]` = 衛悲回/伊小深（非 pascal 人物）

### REQ-SWEE-6: 零回归

未激活时 `lua tests/test_runner.lua` 全绿；`--verify-pascal` PASS；`--all` 0 failures。
