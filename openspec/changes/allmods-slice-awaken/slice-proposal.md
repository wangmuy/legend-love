---
status: done
created: 2026-10-18
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

`reference/allmods/games.ini` 把 MOD「真龙苏醒」（`kys-awaken`，index 11）标注为「真龙苏醒（不确定正不正常）」。深度审计复现了真实缺陷：

| 段 | 缺陷 |
|---|---|
| Thing | 6 个控制符（字段内 CRLF） |

**根因（已定位）**：同 BookCalamity：作者把换行粘进了定长字段

**证据**：Thing r88 物品名/名2 raw=`b6b7c0b1a473afabb4780d0a` → `須彌山神掌\r\n`；r89 raw=`a443b6cbaeb10d0ac3d0` → `七傷拳\r\n譜`（**内部** CRLF）；r110 `五毒秘傳\r\n`；r187 物品说明 `…醫書\r`

**修复**：构建期折叠字段内 CR/LF（`M.TrimControl`）

## Parent Context

- Epic: `openspec/epics/2026-10-allmods-compat/epic.md` — 问题 MOD 专修
- Slice: `openspec/changes/allmods-slice-awaken/slice-proposal.md`
- 依赖: `allmods-slice0`（构建管线 + 数据回退 + 编码转换）

## What Changes

1. 复现并定位缺陷（逆向分析）。
2. 在 `game/tools/mod_encoding.lua` / `game/framework/mod_ini.lua` 实施数据驱动修复。
3. 新增/扩展单元测试断言修复生效且其它 MOD 零回归。
4. 运行全量验收（`mod_check.lua` 20/20、`--verify-pascal` PASS、全量测试全绿）。

## Requirements

### REQ-AWAKEN-1 缺陷复现
深度审计必须从数据本身推导缺陷（不得硬编码 MOD 名）。

### REQ-AWAKEN-2 数据驱动修复
修复逻辑只依据字节/数值判定，不得按 MOD 名分支。

### REQ-AWAKEN-3 零回归
其余 19 个 MOD 与 kys-pascal 基线必须不受影响。

### REQ-AWAKEN-4 端到端验证
`MOD_SLUG=awaken lua tools/mod_check_one.lua` 必须输出 `STRINGS=OK EVENTS=OK SAVE=OK` 且各段记录数正确。

## Impact

- 受影响文件：见 `tasks.md` 的 Blast Radius
- 破坏性变更：无（仅修复畸形数据，完好数据不触碰）
