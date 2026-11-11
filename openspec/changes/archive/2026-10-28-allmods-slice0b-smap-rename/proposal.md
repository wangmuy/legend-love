---
status: done
created: 2026-10-18
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

MOD 源数据用 C 引擎命名 `sdx`/`smp`/`wdx`/`wmp`，Lua 引擎读 `data/smap.idx`/`smap.grp`/`wmap.idx`/`wmap.grp`。构建管线（`tools/mod_build.lua`）只做「小写归一」，把 `sdx/smp/wdx/wmp` 原样复制，导致：

- 每个 MOD 的**场景地图贴图**（mingdong 4.5MB）和**战斗地图贴图**（mingdong 2.4MB）**完全不被读取**，静默回退原版。
- 20/20 MOD 全部受影响；这是本次资源审计中影响面最大的缺陷。

根因：`diff.md` 是扁平集合比对，把 `+ sdx` 与 `- smap.grp` 报成两个无关增删项，看不见「改名」语义；spike 报告把 `sdx≠smap` 误归为「小写归一 / 同名冲突」。

**权威依据**：`reference/allmods/UPedit/UPedit.ini` 的 `[File]` 段显式声明 `File2=resource\sdx,resource\smp,场景贴图`、`File3=resource\wdx,resource\wmp,战斗贴图`、`SMAPIDX=resource\sdx`、`SMAPGRP=resource\smp`。

## Parent Context

- Epic: `openspec/epics/2026-10-allmods-compat/epic.md`
- Slice: `openspec/changes/allmods-slice0b/slice-proposal.md`（Contract A 的拥有方）
- 前置: Slice 0（`allmods-build-pipeline` 提供 `flattenResources`/`buildDiff`，`allmods-data-fallback` 提供 `ModData.RewriteConstants` 的 `smap.*`/`wmap.*` 改写能力——已验证无需改动）

## What Changes

1. **`game/tools/mod_build.lua`** 新增 `ALIAS_MAP` 常量与 `applyAlias(rel)`：
   - `sdx → smap.idx`、`smp → smap.grp`、`wdx → wmap.idx`、`wmp → wmap.grp`
   - 在 `flattenResources()` 计算 `destRel` 时应用（仅 `kind=="data"`）
   - 若映射后目标名已存在 → 报错退出（不静默覆盖）
2. **`buildDiff()`** 新增「资源别名转换」小节；「基准独有」列表对改名对做抵消（`smap.*`/`wmap.*` 不再因别名报缺失）。
3. **单元测试**（`tests/unit/test_mod_build.lua` 新增或扩展）：断言别名映射、产物名、diff 内容。
4. **重建全部 20 MOD 产物**（`--all`）使别名生效。

## Scope Boundaries

### In Scope

- 构建期文件名别名转换（不改文件内容，内容逐字节保留）
- `diff.md` 改名对识别
- 单元测试 + 全量重建

### Out of Scope

- 引擎侧改动 — `ModData.RewriteConstants` 已能正确改写 `SMAPPicFile`/`WMAPPicFile`（审计已验证），无需改
- `smap`/`wmap` 的内容/格式转换 — 已实测 `sdx/smp` 与 `smap.*` 同格式（idx 末值 == grp 大小，20/20 自洽）
- `music/`、`sound/`、`thing` — 分属其他子 change
- 引擎对地图数据的渲染逻辑

## Capabilities

### New Capabilities

- `allmods-resource-alias`: 构建期 MOD 资源别名映射（[REQ-ALIAS-1]~[REQ-ALIAS-4]）

## Contract Adherence

完全遵守 `change-manifest.md` 的 **Contract A**：

- 使用 `UPedit.ini` 的 `[File]` 段作为权威映射来源。
- 仅对 `resource/` 来源（`kind=="data"`）应用别名；`fight/`、`save/` 不参与。
- 映射冲突（目标名已存在）报错退出，非静默覆盖。
- 不改文件内容。

无偏离。

## Traceability

| REQ | 说明 |
|-----|------|
| [REQ-ALIAS-1] | 构建期把 `sdx/smp/wdx/wmp` 映射为 `smap.idx/smap.grp/wmap.idx/wmap.grp` |
| [REQ-ALIAS-2] | 仅对 `resource/` 来源生效；`fight/`、`save/` 不参与 |
| [REQ-ALIAS-3] | 映射冲突（目标名已存在）报错退出，不静默覆盖 |
| [REQ-ALIAS-4] | `diff.md` 含「资源别名转换」小节，且改名对不在「基准独有」误报 |
| [REQ-ALIAS-5] | 运行时证明：激活 MOD 后 `CC.SMAPPicFile`/`WMAPPicFile` 指向 MOD 且条目数 = MOD 实际值 |
| [REQ-ALIAS-6] | 未激活 MOD 零回归：`tests/test_runner.lua` 全绿 |

## DoD

1. `lua tools/mod_build.lua kys-mingdong` → `mods/mingdong/data/` 含 `smap.idx`(4635 项)/`smap.grp`/`wmap.idx`(3850 项)/`wmap.grp`，**无** `sdx/smp/wdx/wmp`。
2. `lua tools/mod_build.lua --all` → 20 MOD 全部产出 `smap.*`/`wmap.*`，0 个 `sdx/smp/wdx/wmp` 残留，0 build failures。
3. `mods/mingdong/diff.md` 含「资源别名转换」小节；`smap.grp`/`smap.idx`/`wmap.grp`/`wmap.idx` **不再**出现在「基准独有」。
4. 运行时断言：激活 mingdong → `CC.SMAPPicFile[1]` 以 `mods/mingdong/data/smap.idx` 结尾；`SMAPPicFile` 条目数 = 4635（非原版 4129）。
5. 无 `active_mod.txt` → `lua tests/test_runner.lua` 全绿（零回归）。
6. `lua tools/mod_build.lua --verify-pascal` 仍 PASS。

## Impact

- **代码**：`game/tools/mod_build.lua`（`ALIAS_MAP`、`flattenResources`、`buildDiff`）
- **测试**：`game/tests/unit/test_mod_build.lua`（新增/扩展）
- **产物**：全部 20 个 `game/mods/<mod>/data/` 重建（`sdx/smp/wdx/wmp` → `smap.*`/`wmap.*`）
- **依赖**：无新增
- **风险**：低。映射表来自权威 `UPedit.ini`；20/20 MOD 已验证 `sdx/smp/wdx/wmp` 成对齐全且无 `smap`/`sdx` 并存冲突。
