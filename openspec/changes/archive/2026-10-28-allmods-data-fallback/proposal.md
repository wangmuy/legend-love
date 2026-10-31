---
status: done
created: 2026-10-16
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

MOD 间数据文件清单有增删、内容不同，现有引擎按原版假设加载。需要统一的回退加载机制：`mods/<mod>/data/` 优先 → `data/`（原版）回退，脚本同链路，fight 文件动态枚举，且未激活 MOD 时行为零回归。

## Parent Context

- Epic: `openspec/epics/2026-10-allmods-compat/epic.md`
- Slice: `openspec/changes/allmods-slice0/slice-proposal.md`（Contract B 的拥有方）
- 依赖: allmods-spike-thingpic-audit（加载点改造清单）, allmods-ini-parser（`ModIni` API）, allmods-build-pipeline（`mods/<mod>/data/` 产物，测试数据源）

## What Changes

1. **MOD 激活机制**：`game/active_mod.txt`（一行 slug，缺失/空 = 未激活）
2. **`game/framework/mod_data.lua`**（Contract B）：
   - `ModData.Active()` / `ModData.Resolve(filename)` / `ModData.FightFiles()` / `ModData.ScriptFile(relpath)`
   - 按 spike 审计报告的加载点清单，把数据/脚本加载点收敛到 `ModData.Resolve`/`ScriptFile`
   - fight 文件数从硬编码改为 `ModData.FightFiles()` 动态枚举（战斗表、遭遇表、场景入口数等下游使用点同步审计）
3. **ini 覆盖接入**：启动链路（`main.lua` 入口或 `jymain_adapter`）在默认 `CONFIG`/`CC` 加载后，若激活 MOD 则 `ModIni.Apply(ModIni.Load("mods/<mod>/data/kysmod.ini"))`
4. **存档目录隔离**（[REQ-DATA-5]）：`ModData.SaveDir()` 返回 `save/`（未激活）或 `mods/<mod>/save/`（激活）；`RewriteConstants` 把存档槽常量（`R_IDXFilename`/`R_GRPFilename`/`S_Filename`/`D_Filename` 的索引 1..3）重定向到 MOD 专属存档目录；`ModData.SeedSaveSlot(id)` 首次保存时从 `ranger.idx` 模板播种 `rN.idx`（避免读到全 0 idx 导致损坏存档）
5. **零回归保证**：未激活 MOD 时，所有 `Resolve`/`ScriptFile` 返回路径与现状逐字节一致；`lua tests/test_runner.lua` 全绿

## Scope Boundaries

### In Scope
- 激活机制、`ModData` 模块、加载点收敛、动态枚举、ini 接入
- 单元测试（回退链、动态枚举、零回归）

### Out of Scope
- MOD 端到端游玩验证 — Slice 1+
- 运行时动态切换 MOD
- 构建管线 — allmods-build-pipeline

## Capabilities

### New Capabilities
- `allmods-data`: MOD 数据回退加载与动态枚举（[REQ-DATA-1]~[REQ-DATA-4]）

## Traceability

| REQ | 说明 |
|-----|------|
| [REQ-DATA-1] | `Resolve` 回退链：`mods/<mod>/data/` 优先，缺失回退 `data/` |
| [REQ-DATA-2] | `ScriptFile` 回退链：`mods/<mod>/script/` 优先，缺失回退 `script/` |
| [REQ-DATA-3] | `FightFiles()` 动态枚举，下游战斗表/遭遇表不再硬编码文件数 |
| [REQ-DATA-4] | 未激活 MOD 零回归：路径与现状一致，测试全绿 |
| [REQ-DATA-5] | 存档目录隔离：MOD 存档写 `mods/<mod>/save/`，各 MOD 不共享/不读取彼此存档；首次保存自动播种 `rN.idx` |

## DoD

1. 无 `active_mod.txt` → `lua tests/test_runner.lua` 全绿（零回归）
2. 激活 mingdong：`Resolve` 命中 `mods/mingdong/data/` 的文件从 MOD 目录读、仅原版有的从 `data/` 读
3. `FightFiles()` 返回 mingdong 实际 fight 文件数（与 `mods/mingdong/data/` 文件数一致）
4. 激活 mingdong 后 `CONFIG`/`CC` 含 ini 覆盖值（分辨率 960x660 等，抽样断言）
5. 激活 mingdong：存档槽路径指向 `mods/mingdong/save/`；`SaveRecord(1)` 后可在该目录读到 `r1.grp/s1.grp/d1.grp/r1.idx`；`r1.idx` 与 `mods/mingdong/data/ranger.idx` 逐字节一致；两个不同 MOD 的 `SaveDir()` 互不相同

## 完成情况

- DoD 1：✅ `lua tests/test_runner.lua` → 141 tests, 141 passed（含 31 个 ModData 新测试）
- DoD 2：✅ `Resolve` 命中 MOD / 回退 `data/` 均正确（见 [tasks.md](tasks.md) 验证记录）
- DoD 3：✅ `FightFiles()` = 267（mingdong 实际数，非原版 92）
- DoD 4：✅ ini 覆盖：`CONFIG.Width=960/Height=660`、`CC.ScreenW/H=960/660`、`CC.MyThingNum=330`、`CC.MaxHP=9999`

详见 [tasks.md](tasks.md)。
