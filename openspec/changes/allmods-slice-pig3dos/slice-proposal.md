---
status: done
created: 2026-10-18
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

`reference/allmods/games.ini` 把 MOD「金庸水浒传dos版」（`kys-pig3dos`，index 17）标注为「金庸水浒传dos版（不可能正常）」。深度审计复现了真实缺陷：

| 段 | 缺陷 |
|---|---|
| Person | 565 个控制符 + 42 个空值（外号槽位） |

**根因（已定位）**：pig3dos 的 Person 记录**没有外号字段**；`@18` 槽位是 int16 数值 stat 数组（`0700070007000a00` = 7,7,7,10），被误当字符串

**证据**：Person r0 @18 raw=`0700070007000a000000`（数值）；Person 姓名 @8 raw=`a544a8a4` → `主角`（完全正常）；全 607 条外号槽位含高位字节的记录数 = **0**

**修复**：字符串字段判定改为「含任意高位字节」（`hasHighByte`），纯数值字段自动跳过

## Parent Context

- Epic: `openspec/epics/2026-10-allmods-compat/epic.md` — 问题 MOD 专修
- Slice: `openspec/changes/allmods-slice-pig3dos/slice-proposal.md`
- 依赖: `allmods-slice0`（构建管线 + 数据回退 + 编码转换）

## What Changes

1. 复现并定位缺陷（逆向分析）。
2. 在 `game/tools/mod_encoding.lua` / `game/framework/mod_ini.lua` 实施数据驱动修复。
3. 新增/扩展单元测试断言修复生效且其它 MOD 零回归。
4. 运行全量验收（`mod_check.lua` 20/20、`--verify-pascal` PASS、全量测试全绿）。

## Requirements

### REQ-PIG3DOS-1 缺陷复现
深度审计必须从数据本身推导缺陷（不得硬编码 MOD 名）。

### REQ-PIG3DOS-2 数据驱动修复
修复逻辑只依据字节/数值判定，不得按 MOD 名分支。

### REQ-PIG3DOS-3 零回归
其余 19 个 MOD 与 kys-pascal 基线必须不受影响。

### REQ-PIG3DOS-4 端到端验证
`MOD_SLUG=pig3dos lua tools/mod_check_one.lua` 必须输出 `STRINGS=OK EVENTS=OK SAVE=OK` 且各段记录数正确。

## Impact

- 受影响文件：见 `tasks.md` 的 Blast Radius
- 破坏性变更：无（仅修复畸形数据，完好数据不触碰）
