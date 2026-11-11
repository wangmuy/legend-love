---
status: done
created: 2026-10-18
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

`reference/allmods/games.ini` 把 MOD「天书劫」（`kys-BookCalamity`，index 8）标注为「天书劫（好像有问题）」。深度审计复现了真实缺陷：

| 段 | 缺陷 |
|---|---|
| Thing | 3 个控制符（字段内 CRLF，来自编辑器换行） |

**根因（已定位）**：MOD 作者把换行粘进了定长字段，字段内出现 `0d 0a`（CRLF）

**证据**：Thing r196 物品说明 raw=`a46abf50b6c7b0eaa5c9c3a20d0a` → `大燕傳國玉璽\r\n`；r197 `大燕皇帝世襲圖表\r\n`；r212 物品名2 `廣陵散琴曲\r\n`

**修复**：构建期剥离字段内 CR/LF（`M.TrimControl`）

## Parent Context

- Epic: `openspec/epics/2026-10-allmods-compat/epic.md` — 问题 MOD 专修
- Slice: `openspec/changes/allmods-slice-bookcalamity/slice-proposal.md`
- 依赖: `allmods-slice0`（构建管线 + 数据回退 + 编码转换）

## What Changes

1. 复现并定位缺陷（逆向分析）。
2. 在 `game/tools/mod_encoding.lua` / `game/framework/mod_ini.lua` 实施数据驱动修复。
3. 新增/扩展单元测试断言修复生效且其它 MOD 零回归。
4. 运行全量验收（`mod_check.lua` 20/20、`--verify-pascal` PASS、全量测试全绿）。

## Requirements

### REQ-BOOKCALAMITY-1 缺陷复现
深度审计必须从数据本身推导缺陷（不得硬编码 MOD 名）。

### REQ-BOOKCALAMITY-2 数据驱动修复
修复逻辑只依据字节/数值判定，不得按 MOD 名分支。

### REQ-BOOKCALAMITY-3 零回归
其余 19 个 MOD 与 kys-pascal 基线必须不受影响。

### REQ-BOOKCALAMITY-4 端到端验证
`MOD_SLUG=BookCalamity lua tools/mod_check_one.lua` 必须输出 `STRINGS=OK EVENTS=OK SAVE=OK` 且各段记录数正确。

## Impact

- 受影响文件：见 `tasks.md` 的 Blast Radius
- 破坏性变更：无（仅修复畸形数据，完好数据不触碰）
