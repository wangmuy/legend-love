---
status: done
parent_epic: 2026-10-allmods-compat
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Slice Proposal: allmods-slice2 — 瑞安群侠传（kys-SweeOan）端到端

## Fit-Level Context
本 slice 评估为 vertical-slice（可测试 MVP）。若实施中范围膨胀，通过 /opsx:explore 重新评估。

## Parent Epic

[2026-10-allmods-compat](../../epics/2026-10-allmods-compat/epic.md) — Slice 2（剩余 MOD 清单第 1 梯队第 1 个）

## Slice Type

Feature

## User Story

玩家激活 MOD「瑞安群侠传」（kys-SweeOan）后，Love2D 引擎按回退链加载 SweeOan 的数据与脚本、
应用其 `kysmod.ini` 覆盖，完整跑通主菜单 → 读档 → smap 移动/进出场景 → 战斗 → 事件对话 →
存档/读档的游玩路径。

## 为什么是 SweeOan（排序依据）

`openspec/epics/2026-10-allmods-compat/TODO.md` 的剩余 MOD 清单按「与基线（kys-pascal）的数据形态距离」
排序：**hdgrp 条目数**（决定头像/贴图加载路径，是最大的适配变量）为主，**fight 数量**为辅。

SweeOan 位列**第 1 梯队（与基线完全同形）**：

| 维度 | SweeOan | pascal 基线 | 差异 |
|------|--------:|-----------:|------|
| hdgrp 条目 | 115 | 115 | **同形** |
| fight 数 | 92 | 92 | **同形** |
| `eft.grp` | 691627 B / 714 项 | 691627 B / 714 项 | 同形 |
| `warfld.grp` | 532480 B / 26 项 | 532480 B / 26 项 | 同形 |
| `cloud.grp` | 38120 B / 9 项 | 38120 B / 9 项 | 同形 |
| `title.grp` | 8179 B / 9 项 | 8179 B / 9 项 | 同形 |
| `kdef.grp` | 121214 B / 1018 项 | 121214 B / 1018 项 | 同形 |
| `talk.idx` | 2977 项 | 2977 项 | 同形（内容不同） |

**唯一差异**是 `talk.grp` 内容（151382 B vs 186513 B，条目数相同、文本不同），
属预期内的剧情差异，不涉及引擎数据形态。

## In Scope

1. **MOD 激活接线验证**：`ModData.SetActive("SweeOan")` 后，验证 Slice 0 的回退链、`ModIni` 覆盖在真实启动链路上生效。
2. **SweeOan 数据包构建**：`lua tools/mod_build.lua kys-SweeOan` 产出 `game/mods/SweeOan/{data,script,save,sound,diff.md}`。
3. **逐文件穷举审计（Slice 0c 工具链复用）**：
   - `lua tools/mod_audit.lua --mod SweeOan` → `total=334 unclassified=0`，且**无「必需但未进产物」矛盾**
   - `lua tools/format_spec.lua --mod SweeOan` → `gaps=0`（字节级无缺口）
4. **真实启动链路端到端验证**（独立进程）：
   - `lib.init` → `JYMainAdapter.init` → `LoadRecord(0)` 不报错
   - MOD 布局常量生效（`CC.PersonSize=182` 等 5 项）
   - `PersonNum/ThingNum/SceneNum/WugongNum` 与源数据一致（320/200/84/93）
   - 主角姓名正确（**王小石**）
   - 全量字符串无 U+FFFD、无控制符
5. **MOD 独有内容验证**：对话表、事件脚本、战斗数据确实来自 MOD（非静默回退原版）。
6. **原版零回归**：未激活时全量测试全绿。

## Out of Scope

- 其余 17 个 MOD（Slice 3-18）
- `music/*.mid`（27 个 PENDING 项）—— 全局遗留 spike，非本 MOD 特有
- 引擎侧代码改动（本 slice 预期**零引擎改动**，因为 SweeOan 与基线同形）

## 验收标准（DoD，机器可验证）

| # | 判据 | 命令 | 期望 |
|---|------|------|------|
| 1 | 构建成功 | `lua tools/mod_build.lua kys-SweeOan` | 退出码 0，`events=1018` |
| 2 | 逐文件归类完整 | `lua tools/mod_audit.lua --mod SweeOan` | `total=334 unclassified=0 bad_evidence=0` |
| 3 | 无「必需未进产物」矛盾 | `mod_audit.auditAll("SweeOan")` | 矛盾数 = 0 |
| 4 | 字节级无缺口 | `lua tools/format_spec.lua --mod SweeOan` | `gaps=0` |
| 5 | 产物四项检查 | `MOD_SLUG=SweeOan lua tools/mod_check_one.lua` | `STRINGS/EVENTS/SAVE=OK` |
| 6 | 真实启动链路 | `lua tests/unit/boot_one_mod.lua SweeOan 320 200 84 93 王小石` | `RESULT SweeOan: OK` |
| 7 | 无回归 | `lua tests/test_runner.lua` | 全绿 |

## 依赖

- **Slice 0**（`ModData`/`ModIni`/回退链/构建流水线）
- **Slice 0b**（`ALIAS_MAP` 把 `sdx/smp/wdx/wmp` → `smap.*`/`wmap.*`；`IGNORE_DIRS`）
- **Slice 0c**（`mod_audit.lua` 逐文件穷举 + `format_spec.lua` 字节级覆盖 + 证据链）

## 子 change 分解

| 子 change | 职责 |
|-----------|------|
| `allmods-sweeOan-activate` | 构建 SweeOan 数据包；逐文件/字节级审计；真实启动链路端到端验证 |
| `allmods-sweeOan-verify` | 审计 `diff.md`；核对 MOD 独有内容（对话/事件/战斗）确实被加载；产出验证报告；确认零回归 |
