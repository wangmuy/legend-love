---
status: done
parent_epic: 2026-10-allmods-compat
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Slice Proposal: allmods-slice0 — MOD 兼容地基（foundation）

## Fit-Level Context
本 slice 评估为 vertical-slice（可测试 MVP）。若实施中范围膨胀，通过 /opsx:explore 重新评估。

## Parent Epic

[2026-10-allmods-compat](../../epics/2026-10-allmods-compat/epic.md) — Slice 0

## Slice Type

Infrastructure

## User Story

系统可以一条 `lua tools/mod_build.lua <mod>` 命令，把 `reference/allmods/` 下任意 MOD 接入 Love2D 引擎（数据拍平 + 构建期提取 + 回退加载 + ini 覆盖），并产出数据差异报告驱动剩余 18 个 MOD slice 的排序。

## In Scope

1. **Spike: `LoadThingPic=0` 审计** — 验证物品图在 smap 路径下的渲染链路（`thing.grp` 条目 ↔ 场景渲染），枚举硬编码数据假设（条目数、文件清单），产出审计报告，为数据弹性改造定界。
2. **kysmod.ini 解析器** — 解析 `[system]`/`[constant]` 等段，键名映射表（含 typo 键名如 `SCENCEAMI`），映射为 `CONFIG.*`/`CC.*` 覆盖；容忍缺失段/缺失键；19 个 MOD 的 ini 全部解析成功。
3. **数据合并 + 回退加载** — 数据加载点收敛到统一入口：`mods/<mod>/data/<file>` 优先 → `data/<file>`（原版）回退；脚本加载同链路（`mods/<mod>/script/` → `script/`）；fight 文件数动态枚举（不硬编码）；MOD 激活机制（不激活 = 零回归）。
4. **构建期内容管线** — `tools/mod_build.lua <mod>`：
   - `resource/ + fight/ + save/` 拍平 → `game/mods/<mod>/data/`（小写归一）
   - `kdef.grp` → `game/mods/<mod>/script/oldevent/*.lua`（改造 `convertkdef2.lua` + `tools/extract_*.lua`，解决对 fishedit 文本格式的依赖）
   - `talk.grp` → `game/mods/<mod>/script/old_talk.lua`
   - 产出 `game/mods/<mod>/diff.md`（相对原版的文件增删、hdgrp 条目数、fight 数量、ini 差异）
   - 忽略 `head/`、`item/`、`eft/` 等编辑器副产物（epic 已验证结论 #3）
5. **数据差异报告** — 19 个 MOD 全部跑一遍管线，产出排序（按差异量递增）写入 epic TODO.md。

## Out of Scope

- 任何具体 MOD 的端到端游玩（Slice 1 mingdong 及后续 slice）
- 运行时动态切换 MOD（每次启动一个 MOD，构建期/激活文件决定）
- 独立 PNG 目录（head/ item/ eft/）支持 — 已验证为编辑器副产物，引擎不读
- MOD 数据本身的内容 bug 修复（只验证数据可用性，不改 MOD 内容）
- CI/CD 集成 mod_build 管线（本 slice 手动执行）

## Acceptance Criteria

#### Scenario: 原版零回归
- **GIVEN** 未激活任何 MOD（`game/active_mod.txt` 不存在或为空）
- **WHEN** 运行 `lua tests/test_runner.lua`
- **THEN** 全部测试通过，行为与 epic 开始前完全一致

#### Scenario: 单 MOD 管线
- **GIVEN** `reference/allmods/kys-mingdong/` 数据完整
- **WHEN** 运行 `lua tools/mod_build.lua kys-mingdong`
- **THEN** 产出 `game/mods/mingdong/data/`、`game/mods/mingdong/script/oldevent/`（事件数 = kdef 条目数）、`game/mods/mingdong/script/old_talk.lua`、`game/mods/mingdong/diff.md`

#### Scenario: 19 MOD 差异报告
- **GIVEN** `reference/allmods/` 下 19 个 MOD（不含 kys-pascal 原版）
- **WHEN** 逐一执行管线的数据差异步骤
- **THEN** 产出 19 个 `mods/<mod>/diff.md`；排序结果（差异量递增）写入 epic TODO.md

#### Scenario: ini 解析容错
- **GIVEN** 19 个 MOD 的 `kysmod.ini`（含缺失段、缺失键、typo 键名如 `SCENCEAMI`）
- **WHEN** 用 ini 解析器逐一解析
- **THEN** 全部成功；未知/typo 键进入 `unknown` 警告列表而非报错；已知键正确映射到 `CONFIG`/`CC`

#### Scenario: 回退链
- **GIVEN** 激活某 MOD，且 `mods/<mod>/data/` 缺少 `data/` 中存在的一些文件
- **WHEN** 引擎加载这些文件
- **THEN** 缺失文件自动回退到 `data/<file>`；fight 文件数 = `mods/<mod>/data/` 实际数量（动态枚举，非原版硬编码值）

## Affected Domains

- **engine-sprite** / **engine-map** / **engine-file** — 数据加载点收敛到统一回退入口，fight/hdgrp 动态枚举
- **game-scripts** — `script_loader` 回退链（`mods/<mod>/script/` → `script/`）、`CONFIG`/`CC` 覆盖注入
- **legacy-events** — 每 MOD 的 `oldevent/*.lua` 加载路径
- **devops** — `tools/mod_build.lua` 构建管线

## DoD 验证结果（2026-10-17）

4 个子 change 全部完成（`allmods-spike-thingpic-audit` / `allmods-ini-parser` / `allmods-build-pipeline` / `allmods-data-fallback`）：

| # | 场景 | 验证方式 | 结果 |
|---|------|----------|------|
| 1 | 原版零回归 | `lua tests/test_runner.lua`（无 `active_mod.txt`） | ✅ 221/221 |
| 2 | 单 MOD 管线 | `lua tools/mod_build.lua kys-mingdong` | ✅ data=599、events=1654、talk=5183、diff.md |
| 3 | 19 MOD 差异报告 | `lua tools/mod_build.lua --all` | ✅ 20 mods、0 build failures、5 annotated-problematic；排序写入 TODO.md |
| 4 | ini 解析容错 | `test_mod_ini.lua`（73 断言，覆盖 19 MOD 真实 ini） | ✅ 全绿 |
| 5 | 回退链 | `test_mod_data.lua`（31 断言） | ✅ `Resolve` 优先 MOD、缺失回退；`FightFiles()`=267 |

**pascal 基线验证**：`lua tools/mod_build.lua --verify-pascal` → **PASS**（events=1018, mismatches=0, 3 known-deviations）。
