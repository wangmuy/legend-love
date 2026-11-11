---
status: done
parent_epic: 2026-10-allmods-compat
---
# Change Manifest: allmods-slice1 — 名动天下端到端

## Change Assignments

### Change: allmods-mingdong-activate

- **Repository**: this repo
- **Scope**: fullstack（framework 接线 + 无头验证脚手架）
- **Responsibility**: 把 Slice 0 的 `ModData`/`ModIni` 接到真实启动链路；提供 `game/active_mod.txt` 激活入口；构建 mingdong 数据包；新增无头端到端验证脚本（`tests/unit/test_mod_e2e.lua`）驱动 `SetGlobalConst` → ini 覆盖 → 路径回退 → 脚本/对话/战斗加载
- **Depends On**: allmods-slice0（全部 4 个 change）
- **Status**: [x] Done

### Change: allmods-mingdong-verify

- **Repository**: this repo
- **Scope**: infra（验证 + 报告）
- **Responsibility**: 审计 `game/mods/mingdong/diff.md`，逐条核对引擎加载点对 mingdong 数据形态的容忍度；核对事件脚本/对话内容与 MOD 数据一致；产出验证报告 `reports/mingdong-verify.md`；确认原版零回归
- **Depends On**: allmods-mingdong-activate
- **Status**: [x] Done

## Shared Contract Stubs

### Contract D: 无头端到端验证入口

```
# allmods-mingdong-activate 拥有；allmods-mingdong-verify 消费
lua tests/test_runner.lua mod_e2e        # 单模块（37 断言）
lua tests/test_runner.lua mod_boot       # 全启动链路单模块（55 断言）
lua tests/test_runner.lua                # 全量（252 断言）

# 验证脚本契约：
#   * 用 tests/engine_test.lua 作为无头 EngineAPI（无显示器）
#   * 设置 game/active_mod.txt = mingdong（测试内用 ModData.SetActive，避免污染工作树）
#   * 断言：路径回退、ini 覆盖、事件/对话/战斗加载
#   * mod_boot 额外真实执行 lib.init → JYMainAdapter.init → LoadRecord(0) → GAME_FIRSTMMAP → GAME_MMAP
#     → ReadTalk 对话读取 → WarLoad/WarLoadMap 战斗 → SaveRecord(1) → LoadRecord(1) round-trip
#     → 存档目录隔离（SaveDir=mods/mingdong/save/，首次保存自动播种 r1.idx）
```

**Contract D 状态**: [x] Fulfilled（`test_mod_e2e.lua` 37/37 + `test_mod_boot.lua` 55/55）

## Integration Test Plan

1. **零回归**：无 `active_mod.txt` → `lua tests/test_runner.lua` 全绿。
2. **激活接线**：模拟启动链路后，`CC.MMAPPicFile` 指向 `mods/mingdong/data/`、`CC.SMAPPicFile` 回退 `data/`、`CONFIG.Width=960`。
3. **脚本回退**：`ScriptLoader.load("script/oldevent/oldevent_0.lua")` 命中 `mods/mingdong/script/oldevent/`。
4. **对话表**：`dofile("mods/mingdong/script/old_talk.lua")` 后 `oldtalk[1]` 为 mingdong 内容。
5. **战斗枚举**：`ModData.FightFiles()` = 267；`WarLoad` 越界报错。
6. **原版零回归复跑**：移除激活后全绿。
7. **全启动链路**：`lua tests/test_runner.lua mod_boot` → `lib.init` → `JYMainAdapter.init` → `LoadRecord(0)` → `GAME_MMAP` → `ReadTalk` → `WarLoad`/`WarLoadMap` → `SaveRecord`/`LoadRecord` round-trip 全 OK。
8. **对话 idx 语义**：产物 `oldtalk.idx` 与独立模拟 `GenTalkIdx` 逐字节相同。
9. **存档隔离**：激活 mingdong 后 `CC.R_IDXFilename[1]`=`mods/mingdong/save/r1.idx`；`SaveRecord(1)` 自动播种 `r1.idx`（内容 = MOD `ranger.idx`）并写入 `r1.grp/s1.grp/d1.grp`；不同 MOD 的 `SaveDir()` 互不相同；未激活时 `SaveDir()="save/"`。
