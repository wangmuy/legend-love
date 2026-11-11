---
status: done
created: 2026-10-16
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

Slice 0 交付了 `ModData`（回退链）与 `ModIni`（ini 覆盖）两个模块并各自通过单元测试，但尚未在**真实启动链路**上验证二者协同：`SetGlobalConst()` 构建的 `CC.*` 路径常量是否被正确重定向、ini 覆盖是否在引擎使用前生效、事件/对话/战斗是否真的从 `mods/mingdong/` 加载。本 change 把二者接到启动链路并提供无头端到端验证。

## Parent Context

- Epic: `openspec/epics/2026-10-allmods-compat/epic.md` — Slice 1
- Slice: `openspec/changes/allmods-slice1/slice-proposal.md`（Contract D 的拥有方）
- 依赖: `allmods-slice0` 全部 4 个 change（`ModData`/`ModIni`/构建管线/审计报告）

## What Changes

1. **激活入口**：`game/active_mod.txt`（内容 `mingdong`）——真实启动时读取。
2. **启动链路接线核对**：确认 `lib_love.lua` → `SetGlobalConst()` → `ModData.RewriteConstants` → `JYMainAdapter.initCoroutine` 的 `ModData.LoadIni` 顺序正确；修复发现的问题。
3. **mingdong 数据包构建**：`lua tools/mod_build.lua kys-mingdong`。
4. **无头端到端验证**：`game/tests/unit/test_mod_e2e.lua`（37 断言）+ `game/tests/unit/test_mod_boot.lua`
   （55 断言，全启动链路），用 `tests/engine_test.lua` 的 EngineAPI，断言：
   - `SetGlobalConst` 后 `CC.*` 路径按回退链重定向
   - ini 覆盖生效（960x660、MyThingNum=330、MaxHP=9999）
   - `ScriptLoader.load` 命中 mingdong 事件脚本
   - `oldtalk[1]` 为 mingdong 对话；运行时 `oldtalk.grp`/`.idx` 与 `ReadTalk` 语义一致
   - `ModData.FightFiles()` = 267；`WarLoad` 越界报错
   - 全启动链路：`lib.init` → `JYMainAdapter.init` → `LoadRecord(0)` → `GAME_FIRSTMMAP` → `GAME_MMAP`
     → `ReadTalk` 对话读取 → `WarLoad`/`WarLoadMap` 战斗 → `SaveRecord(1)` → `LoadRecord(1)` round-trip
   - 存档隔离：`SaveDir()` = `mods/mingdong/save/`；`SaveRecord(1)` 自动播种 `r1.idx`（= MOD `ranger.idx`）；
     不同 MOD 的 `SaveDir()` 互不相同；未激活时 = `save/`
5. 注册到 `test_runner.lua`（模块名 `mod_e2e` / `mod_boot`）。

## Scope Boundaries

### In Scope
- 启动链路接线核对与修复、mingdong 构建、无头 E2E 验证脚本、测试注册

### Out of Scope
- mingdong 数据内容 bug 修复
- 真实图形渲染验证（无头断言调用序列即可）
- 其余 18 个 MOD

## Capabilities

### New Capabilities
- `allmods-mingdong-e2e`: 名动天下激活与无头端到端验证（[REQ-MD-1]~[REQ-MD-4]）

## Traceability

| REQ | 说明 |
|-----|------|
| [REQ-MD-1] | 激活 mingdong 后启动链路完成 `CC.*` 路径重定向与 ini 覆盖 |
| [REQ-MD-2] | 事件脚本经 `ScriptLoader` 回退链命中 `mods/mingdong/script/oldevent/` |
| [REQ-MD-3] | 对话表从 `mods/mingdong/script/old_talk.lua` 加载，内容为 mingdong 数据 |
| [REQ-MD-4] | 战斗文件动态枚举（267）+ `WarLoad` 越界校验 |

## DoD

1. `lua tests/test_runner.lua mod_e2e` 全绿。
2. 无 `active_mod.txt` → `lua tests/test_runner.lua` 全绿（零回归）。
3. `lua tools/mod_build.lua kys-mingdong` 四产物齐备（events=1654、talk=5183）。

## 完成情况（2026-10-17）

全部任务完成，DoD 通过：

- **激活入口**：`game/active_mod.txt`（一行 slug）；`.gitignore` 忽略 `game/mods/` 与 `game/active_mod.txt`（构建产物 + 运行时状态）。
- **启动链路无头验证**：`dofile("script/jyconst.lua")` + `SetGlobalConst()` + `ModData.LoadIni()` 后：
  `CC.MMAPPicFile[2]=mods/mingdong/data/mmap.grp`、`CC.SMAPPicFile[2]=data/smap.grp`（回退）、
  `CC.TalkGrpFile=mods/mingdong/script/oldtalk.grp`、`CONFIG.Width=960`、`CC.MyThingNum=330`、`CC.MaxHP=9999`。
- **对话运行时产物**：`mod_build.lua` 新增 `oldtalk.grp`（UTF-8 文本 + CRLF）+ `oldtalk.idx`（4 字节小端偏移），
  与运行时 `ReadTalk`（`script/jymain.lua:3067`）读取 `CC.TalkGrpFile`/`TalkIdxFile` 的语义一致。
  mingdong 产出 5183 条，`ReadTalk(0..2)` 正确返回 mingdong 对话。
- **繁→简**：`tools/talk_big5.lua` 由 Big5→繁体 UTF-8 改为 Big5→**简体** UTF-8（OpenCC `t2s`），
  匹配原版运行时语言（`script/oldtalk.grp` 与 `script/oldevent/*.lua` 均为简体）。
- **talk 终止符修复**：`0x00` 约定优先，无尾 `0x00` 时用 `0xff` 约定并去 1 个杂散尾字节；
  mingdong `?` 从 828 降至 43，pascal 从 14 降至 1。
- **无头端到端测试**：`game/tests/unit/test_mod_e2e.lua`（37 断言）覆盖路径重定向 + ini 覆盖 + 事件回退 +
  对话表 + 运行时 `oldtalk.grp` + fight 枚举 + 零回归；`game/tests/unit/test_mod_boot.lua`（55 断言）覆盖
  全启动链路（`lib.init` → `JYMainAdapter.init` → `LoadRecord(0)` → `GAME_FIRSTMMAP` → `GAME_MMAP`）。
- **对话 idx 语义修复**：`oldtalk.idx` 的 `idx[k]` 改为「读完第 k 行后的字节偏移」，
  与运行时 `GenTalkIdx`（`script/jymain.lua:3012`）完全一致，修复原先的行起始偏移导致的 `ReadTalk` off-by-one。
  验证：独立模拟 `GenTalkIdx` 生成的 idx 与产物逐字节相同（pascal 2977、mingdong 5183）。

验证记录：

- `lua tests/test_runner.lua mod_e2e` → **37 tests, 37 passed, 0 failed**
- `lua tests/test_runner.lua mod_boot` → **55 tests, 55 passed, 0 failed**
- `lua tests/test_runner.lua`（无 `active_mod.txt`）→ **252 tests, 252 passed, 0 failed**
- `lua tools/mod_build.lua kys-mingdong` → data files=572, saves=27, events=1654, talk=5183
