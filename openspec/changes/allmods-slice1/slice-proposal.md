---
status: done
parent_epic: 2026-10-allmods-compat
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Slice Proposal: allmods-slice1 — 名动天下（kys-mingdong）端到端

## Fit-Level Context
本 slice 评估为 vertical-slice（可测试 MVP）。若实施中范围膨胀，通过 /opsx:explore 重新评估。

## Parent Epic

[2026-10-allmods-compat](../../epics/2026-10-allmods-compat/epic.md) — Slice 1

## Slice Type

Feature

## User Story

玩家激活 MOD「名动天下」（kys-mingdong）后，Love2D 引擎按回退链加载 mingdong 的数据与脚本、应用其 `kysmod.ini` 覆盖（分辨率 960x660 等），完整跑通主菜单 → 读档 → smap 移动/进出场景 → 战斗 → 事件对话 → 存档/读档的游玩路径。

## In Scope

1. **MOD 激活接线**：`game/active_mod.txt` = `mingdong`，验证 Slice 0 的 `ModData` 回退链、`ModIni` 覆盖在真实启动链路上生效。
2. **mingdong 数据包构建**：`lua tools/mod_build.lua kys-mingdong` 产出 `game/mods/mingdong/{data,script,diff.md}`。
3. **mingdong 特有差异审计与修复**：以 `game/mods/mingdong/diff.md` 为准，审计引擎加载点是否能容忍 mingdong 的数据形态（fight 267 个、hdgrp 114 条目、war.sta 309 记录、缺 `smap/wmap/thing` 回退原版）。
4. **无头端到端验证**：用 `tests/engine_test.lua`（EngineAPI 无头实现）驱动启动链路，断言：
   - 主菜单初始化不报错
   - 事件脚本从 `mods/mingdong/script/oldevent/` 加载（抽样事件对话内容与 MOD 数据一致）
   - 对话表从 `mods/mingdong/script/old_talk.lua` 加载
   - 战斗数据从 `mods/mingdong/data/fight*.grp` 加载（越界校验生效）
   - 分辨率 960x660 生效

## Out of Scope

- 其余 18 个 MOD（Slice 2-18）
- 运行时动态切换 MOD
- mingdong 数据内容本身的 bug 修复（只验证数据可用性）
- 真实图形渲染的像素级验证（用无头 EngineAPI 断言调用序列）

## Acceptance Criteria

#### Scenario: 激活后引擎按 MOD 数据启动
- **GIVEN** `game/active_mod.txt` 内容为 `mingdong`，`game/mods/mingdong/` 已构建
- **WHEN** 走启动链路（`SetGlobalConst` → `ModIni.Apply` → `ModData.RewriteConstants`）
- **THEN** `CC.MMAPPicFile` 指向 `mods/mingdong/data/`，`CC.SMAPPicFile` 回退 `data/`，
  `CONFIG.Width=960`/`Height=660`，`CC.ScreenW=960`/`ScreenH=660`

#### Scenario: mingdong 事件脚本加载
- **GIVEN** mingdong kdef 提取出 1654 个事件脚本
- **WHEN** `ScriptLoader.load("script/oldevent/oldevent_<n>.lua")` 被调用
- **THEN** 命中 `mods/mingdong/script/oldevent/oldevent_<n>.lua`（回退链生效）

#### Scenario: mingdong 对话表加载
- **GIVEN** mingdong talk 提取出 5183 条对话
- **WHEN** 读取 `mods/mingdong/script/old_talk.lua`
- **THEN** `oldtalk[1]` 为 mingdong 首条对话（非原版内容）

#### Scenario: 战斗数据动态枚举
- **GIVEN** mingdong 提供 267 个 fight 文件
- **WHEN** `ModData.FightFiles()` 被调用
- **THEN** 返回 267 个文件，`WarLoad` 对越界 warid 报错而非静默失败

#### Scenario: 原版零回归
- **GIVEN** 无 `game/active_mod.txt`
- **WHEN** 运行 `lua tests/test_runner.lua`
- **THEN** 全部测试通过

## Affected Domains

- **engine-file** — 数据/脚本回退链在真实启动链路生效
- **game-scripts** — mingdong 事件脚本与对话表加载
- **framework** — `ModData`/`ModIni` 接线
- **devops** — 无头端到端验证脚本

## DoD 验证结果（2026-10-17）

全部 Acceptance Criteria 通过：

| # | 场景 | 验证方式 | 结果 |
|---|------|----------|------|
| 1 | 激活后引擎按 MOD 数据启动 | 真实启动链路无头执行 | ✅ `CC.MMAPPicFile[2]=mods/mingdong/data/mmap.grp`、`CC.SMAPPicFile[2]=data/smap.grp`（回退）、`CONFIG.Width/Height=960/660`、`CC.ScreenW/H=960/660` |
| 2 | mingdong 事件脚本加载 | `ScriptLoader.load` + 无头 `loadfile` | ✅ 命中 `mods/mingdong/script/oldevent/` |
| 3 | mingdong 对话表加载 | `dofile` + 运行时 `oldtalk.grp`/`.idx` | ✅ `oldtalk[1]` = mingdong 首条对话（简体） |
| 4 | 战斗数据动态枚举 | `ModData.FightFiles()` + `WarLoad` 越界校验 | ✅ 267 个；`war.sta` 309 记录 |
| 5 | 原版零回归 | `lua tests/test_runner.lua`（无 `active_mod.txt`） | ✅ 252/252 |
| 6 | 存档隔离（MOD 之间不共享存档） | `ModData.SaveDir()` + `SaveRecord`/`LoadRecord` | ✅ 存档写入 `mods/mingdong/save/`；首次保存自动播种 `r1.idx`（= MOD `ranger.idx`）；不同 MOD 的 `SaveDir()` 互不相同 |

**补充端到端证据（全启动链路，`tests/unit/test_mod_boot.lua` 55/55）**：无头驱动 `lib.init` →
`JYMainAdapter.init` → `LoadRecord(0)`（读 MOD `ranger.grp`/`ranger.idx`）→ `GAME_FIRSTMMAP` → `GAME_MMAP`
→ `ReadTalk` 对话读取 → `WarLoad`/`WarLoadMap` 战斗 → `SaveRecord(1)` → `LoadRecord(1)` round-trip，60+ 帧无报错；
`JY.PersonNum=632`、`JY.ThingNum=367`、`JY.SceneNum=139`、`JY.WugongNum=220`
（MOD 真实记录布局；早期版本误用原版 `CC.*Size` 得到 569/268/116/204 并读到错位数据，
已在 `allmods-encoding-convert` 修正）。

**实施中发现并修复的运行时 bug**：`oldtalk.idx` 的 `idx[k]` 语义错误（写成「行起始偏移」），
与运行时 `GenTalkIdx`（`script/jymain.lua:3012`）的「读完该行后的偏移」不符 → `ReadTalk` 全部 off-by-one。
已在 `tools/mod_build.lua` 的 `extractTalk` 修正；验证产物 idx 与独立模拟 `GenTalkIdx` 逐字节相同。

**实施中发现并修复的第二个运行时 bug**：存档未按 MOD 隔离——所有 MOD 的存档槽都指向顶层
`save/`，导致 MOD 之间互相覆盖存档；且首次保存时 `rN.idx` 不存在 → `LoadToTable8` 返回全 0 → 损坏存档。
已修复：构建期 `save/` 拆分（模板→`data/`、用户存档→`mods/<mod>/save/`）；运行时 `ModData.SaveDir()`
+ `RewriteConstants` 重定向存档槽；`SaveRecord` 首次保存自动从 MOD `ranger.idx` 播种 `rN.idx`。

**超出本 slice 范围但已记录、并已在 `allmods-encoding-convert` 完成的发现**：MOD `ranger.grp` 的人物/物品/场景名称
为 **Big5** 编码，而引擎按 UTF-8 读取（原版 `ranger.grp` 为 UTF-8）→ 名称显示乱码。
已按方案 D（hint 占位 + 旁路字符串表 `ranger.str` + 存档覆盖表 `rN.ovr`）在构建期完成转换，
零截断、文件大小不变；同时修正了 MOD 记录布局适配。
