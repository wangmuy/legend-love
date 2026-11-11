---
status: done
parent_epic: 2026-10-allmods-compat
---
# Change Manifest: allmods-slice0 — MOD 兼容地基

## Change Assignments

### Change: allmods-spike-thingpic-audit

- **Repository**: this repo
- **Scope**: infra（只读审计 + 报告）
- **Responsibility**: Spike。审计 `LoadThingPic=0` 物品图渲染链路：`thing.grp` 条目 ↔ smap 场景渲染的耦合点；枚举数据加载侧全部硬编码假设（hdgrp/thing 条目数、fight 文件数、数据文件清单）；产出审计报告，定界 allmods-data-fallback 需要改造的加载点清单
- **Depends On**: none
- **Status**: [x] Done

### Change: allmods-ini-parser

- **Repository**: this repo
- **Scope**: fullstack（framework 模块 + 单元测试）
- **Responsibility**: `framework/mod_ini.lua`：解析 `kysmod.ini` 的 `[system]`/`[constant]` 等段；键名映射表（含 typo 键名 `SCENCEAMI`，可配置扩展）；返回 `{CONFIG, CC, unknown}` 三表结构；缺失段/缺失键/未知键容忍（unknown 仅警告）；单元测试覆盖 19 个 MOD 的真实 ini 文件
- **Depends On**: none
- **Status**: [x] Done

### Change: allmods-build-pipeline

- **Repository**: this repo
- **Scope**: infra（构建工具）
- **Responsibility**: `tools/mod_build.lua <kys-<mod>>`：`resource/ + fight/ + save/` 拍平 → `game/mods/<mod>/data/`（小写归一、忽略 head/item/eft、拷贝 kysmod.ini）；`kdef.grp` → `game/mods/<mod>/script/oldevent/*.lua`（直接解析二进制，不依赖 fishedit 文本）；`talk.grp` → `game/mods/<mod>/script/old_talk.lua`；产出 `game/mods/<mod>/diff.md`
- **Depends On**: none
- **Status**: [x] Done

### Change: allmods-data-fallback

- **Repository**: this repo
- **Scope**: fullstack（engine + framework + 测试）
- **Responsibility**: MOD 激活机制（`game/active_mod.txt`）；统一数据加载入口 `ModData`（`mods/<mod>/data/` 优先 → `data/` 回退）；脚本加载回退链（`mods/<mod>/script/` → `script/`）；fight 文件动态枚举；调用 `ModIni` 注入 ini 覆盖；不激活 MOD 时行为零回归
- **Depends On**: allmods-spike-thingpic-audit, allmods-ini-parser
- **Status**: [x] Done

## Shared Contract Stubs

### Contract A: MOD 激活与 ini 覆盖

```
# 激活机制（每次启动一个 MOD，无运行时切换）
game/active_mod.txt               # 一行：MOD slug（如 "mingdong"）
                                  # 文件缺失或为空 = 未激活 MOD（纯原版路径，零回归）

# ini 解析器 API（allmods-ini-parser 拥有）
ModIni = {
  Load(path) → {
    CONFIG  = { ... },            -- CONFIG.* 覆盖（只含 ini 中出现的键，无空表）
    CC      = { ... },            -- CC.* 覆盖
    unknown = { ... },            -- 未知/typo/无法映射键 → 原值（警告列表，非错误）
  },
  Apply(parsed) → nil             -- 把 CONFIG/CC 覆盖应用到已加载的默认值上
}

# 键名映射表（allmods-ini-parser 内部，可配置）
-- [system] 段: SCENCEMI→分辨率等, [constant] 段: EXP_RATE/... → CC.*
-- typo 键名（如 mingdong 的 SCENCEAMI）在映射表中显式登记，不报错
```

### Contract B: 数据路径回退

```
-- ModData（allmods-data-fallback 拥有），所有数据/脚本加载点统一走此入口
ModData = {
  Active() → slug | nil          -- 读 game/active_mod.txt，缺失/空返回 nil
  Resolve(filename) → path
    -- MOD 激活 且 game/mods/<mod>/data/<filename> 存在 → 返回该路径
    -- 否则 → 返回 game/data/<filename>（原版路径，与现状逐字节一致）
  FightFiles() → { "fight000.grp", "fight001.grp", ... }
    -- 动态枚举：MOD 激活 → 列出 mods/<mod>/data/ 中 fight*.grp
    -- mods/<mod>/data/ 无 fight 文件 → 回退列出 data/
  ScriptFile(relpath) → path
    -- 同链路：mods/<mod>/script/<relpath> 存在 → 用它；否则 script/<relpath>
}

# 硬约束：现有数据加载调用点收敛到 ModData.Resolve；
# 未激活 MOD 时返回路径必须与现状完全相同（零回归由测试保证）
```

### Contract C: 构建管线输出布局

```
# allmods-build-pipeline 拥有；对下游 allmods-data-fallback 的输出契约
# <mod> = MOD slug（kys- 之后的部分，如 mingdong）；同一 MOD 的全部产物归 game/mods/<mod>/ 目录
lua tools/mod_build.lua kys-<mod>
  ├─ game/mods/<mod>/data/            # 拍平的 resource/ + fight/ + save/
  │   ├─ *.grp / *.002 / *.sta / ...  # 文件名小写归一
  │   └─ kysmod.ini                   # 从 MOD 源原样拷贝
  ├─ game/mods/<mod>/script/
  │   ├─ oldevent/oldevent_0.lua ... oldevent_<n-1>.lua    # n = kdef 条目数
  │   ├─ old_talk.lua                                     # 对话表（lua 形式，附带产物）
  │   ├─ oldtalk.grp                                      # 运行时对话文本（UTF-8 + CRLF，每行一条）
  │   └─ oldtalk.idx                                      # 运行时对话偏移表（4字节小端；idx[k]=读完第k行后的偏移）
  └─ game/mods/<mod>/diff.md          # 数据差异报告
      # 必含：文件增删清单（vs 原版 data/）、hdgrp 条目数、fight 数量、ini 差异表
# 退出码：0 = 成功；非 0 = 数据异常（stderr 说明原因，不产出半成品）
```

## Integration Test Plan

1. **零回归**：无 `active_mod.txt` → `lua tests/test_runner.lua` 全绿。
2. **管线**：`lua tools/mod_build.lua kys-mingdong` → `mods/mingdong/data/`、`mods/mingdong/script/oldevent/`（数量 = kdef 条目数）、`mods/mingdong/script/old_talk.lua`、`mods/mingdong/script/oldtalk.grp`+`.idx`、`mods/mingdong/diff.md` 五产物齐备。
3. **回退链**：激活 mingdong → 同时存在的文件从 `mods/mingdong/data/` 读、仅原版有的文件从 `data/` 读；`ModData.FightFiles()` 返回 mingdong 实际 fight 数（非原版数）。
4. **ini**：19 个 ini 全部解析成功；抽样核对覆盖值（mingdong 分辨率 960x660、GodsDevils `EXP_RATE=4`）。
5. **报告排序**：19 个 `mods/<mod>/diff.md` 产出后，按差异量排序写入 epic TODO.md。
