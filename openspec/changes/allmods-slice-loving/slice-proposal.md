---
status: done
created: 2026-10-18
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

`reference/allmods/games.ini` 把 MOD「问情篇」（`kys-loving`，index 10）标注为「问情篇（好像不太正常）」。深度审计复现了真实缺陷：

| 段 | 缺陷 |
|---|---|
| Person/Thing/Scene/Wugong | 字段级零缺陷（0 FFFD / 0 控制符 / 0 空值） |
| kysmod.ini | `BEGIN_SCENE = -1` / `BEGIN_EVENT = -1`（作者声明「不指定」） |

**根因（已定位）**：字段数据本身完好；异常在 ini 的负值索引——引擎会直接用 `CC.NewGameSceneID` 索引 `JY.Scene[]`，`-1` 会崩溃

**证据**：loving `kysmod.ini` 第 33/35 行：`BEGIN_EVENT = -1`、`BEGIN_SCENE = -1`；引擎 `jymain_adapter.lua:346` 无条件 `JY.SubScene = CC.NewGameSceneID` 后立即 `JY.Scene[JY.SubScene]["名称"]`

**修复**：ini 映射对「负数表示未设置」的索引键保持引擎默认值（不覆盖）

## Parent Context

- Epic: `openspec/epics/2026-10-allmods-compat/epic.md` — 问题 MOD 专修
- Slice: `openspec/changes/allmods-slice-loving/slice-proposal.md`
- 依赖: `allmods-slice0`（构建管线 + 数据回退 + 编码转换）

## What Changes

1. 复现并定位缺陷（逆向分析）。
2. 在 `game/tools/mod_encoding.lua` / `game/framework/mod_ini.lua` 实施数据驱动修复。
3. 新增/扩展单元测试断言修复生效且其它 MOD 零回归。
4. 运行全量验收（`mod_check.lua` 20/20、`--verify-pascal` PASS、全量测试全绿）。

## Requirements

### REQ-LOVING-1 缺陷复现
深度审计必须从数据本身推导缺陷（不得硬编码 MOD 名）。

### REQ-LOVING-2 数据驱动修复
修复逻辑只依据字节/数值判定，不得按 MOD 名分支。

### REQ-LOVING-3 零回归
其余 19 个 MOD 与 kys-pascal 基线必须不受影响。

### REQ-LOVING-4 端到端验证
`MOD_SLUG=loving lua tools/mod_check_one.lua` 必须输出 `STRINGS=OK EVENTS=OK SAVE=OK` 且各段记录数正确。

## Impact

- 受影响文件：见 `tasks.md` 的 Blast Radius
- 破坏性变更：无（仅修复畸形数据，完好数据不触碰）
