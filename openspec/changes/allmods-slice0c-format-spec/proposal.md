---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice0c
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Proposal: allmods-slice0c-format-spec

## Why

文件级归类回答"这个文件是否需要"，但不回答"这个文件的**每个字节**是否被解释过"。
实测现状：全项目仅对 **`smap.grp` 一个文件**做过逐字节断言；其余 8999 个产物文件
的内容正确性从未验证，源侧"哪些字节被引擎消费"更是空白。

用户标准（已确认）：**粒度定到字段级，但每个文件必须被字段完整覆盖，不能有缺口段**。

## What Changes

新增 `game/tools/format_spec.lua`，为每种二进制格式定义**无缺口的字段表**，
并提供 `verifyCoverage(path, spec)` 断言：

```
Σ(字段区间) == 文件大小    且    字段区间无重叠、无未覆盖缺口
```

覆盖的格式族（按实测 20 MOD 全集）：

| 格式族 | 文件 | 说明 |
|--------|------|------|
| `idx_grp_rle` | `hdgrp`、`mmap`、`eft`、`warfld`、`cloud`、`title`、`fight/*` | offset 表 + RLE 记录 |
| `idx_grp_text` | `talk` | offset 表 + 变长文本 |
| `idx_grp_bytecode` | `kdef` | offset 表 + int16 指令流 |
| `bare_idx_grp` | `sdx`/`smp`、`wdx`/`wmp` | 无 `.idx` 后缀的 offset 表 + RLE |
| `smap_grid` | `earth/surface/building/buildx/buildy.002` | 定长 uint16 网格 |
| `sta_table` | `war.sta` | 定长战斗表 |
| `palette` | `mmap.col` | 768 字节调色板 |
| `bin_table` | `list/*.bin` | 定长事件表 |
| `ini_kv` | `kysmod.ini` | 键值文本 |
| `ranger_seg` | `save/ranger.*`、`save/rN.*` | 6 段索引 + 段记录 |
| `save_grid` | `save/allsin.*`、`save/alldef.*` | 索引 + 定长记录 |
| `wav_pcm` | `sound/*.wav` | RIFF 块结构 |
| `png_image` | `head/*`、`item/*`、`eft/*`、`resource/*.png` | PNG 块结构 |

## In Scope

- `tools/format_spec.lua`：格式规格 + `verifyCoverage()` + `verifyAll()`
- 字段表覆盖上表全部格式族
- 每个字段标注 `needed`（引擎是否消费）+ `consumer`（消费它的引擎函数）
- `tests/unit/test_format_spec.lua`：20 MOD × 每格式覆盖断言 + 负例
- 注册进 `tests/test_runner.lua`

## Out of Scope

- 证据的完整收集（→ `allmods-slice0c-unneeded-evidence`）
- 逐**字节**语义（用户已确认粒度到字段级）
- 修复任何格式解析 bug（只验证覆盖，不改引擎）
- 字体（`.ttf`）、压缩包（`.zip`）、MIDI（`.mid`）内部结构

## Requirements

### [REQ-FMT-1] 字段表完整覆盖，无缺口

`verifyCoverage(path, spec)` 必须断言 `Σ(字段区间) == 文件大小`，且区间
两两不重叠、无未覆盖缺口。

- **GIVEN** `format_spec.verifyCoverage(".../hdgrp.grp", SPEC.hdgrp.grp)`
- **WHEN** 执行
- **THEN** 返回 `ok=true`，`gaps={}`

### [REQ-FMT-2] 缺口必须被报告

存在未覆盖区间时必须返回 `ok=false` 并列出 `[start, end)`。

- **GIVEN** 字段表故意漏掉 `[100, 200)`
- **WHEN** 执行 `verifyCoverage`
- **THEN** `ok=false`，`gaps` 含 `{start=100, end=200}`

### [REQ-FMT-3] 变长记录族（RLE / 文本 / 指令流）

对 `idx_grp_*` 与 `bare_idx_grp` 族，字段表为
`{header?, records[], tail?}`，其中 `records` 的大小由 offset 表推导：

```
records[i] = [offsets[i], offsets[i+1])       -- 含末项到文件末尾
tail       = [offsets[last], filesize)         -- 通常为空
```

- **GIVEN** `hdgrp.idx` 的 offset 表与 `hdgrp.grp`
- **WHEN** 验证
- **THEN** `Σ(records) + tail == grpsize`，且 `tail == 0`（实测 20/20 MOD）

### [REQ-FMT-4] 多段 offset 表被识别

`mmap.idx` 实测含**两段拼接**的 offset 表（3731 + 5000 项），字段表必须显式
建模为两个段，不得当作单段导致覆盖错误。

- **GIVEN** `mmap.idx`（34924 字节 = 8731 × 4）
- **WHEN** 验证
- **THEN** 规格含 `seg1`（3731 项）与 `seg2`（5000 项），覆盖完整

### [REQ-FMT-5] 每个字段标注 `needed` 与 `consumer`

- **GIVEN** 任意字段
- **WHEN** 检查
- **THEN** 含 `needed`（bool）与 `consumer`（引擎符号名或 `nil`）

### [REQ-FMT-6] 20 MOD 全覆盖

- **GIVEN** 20 个 MOD 各自的格式文件
- **WHEN** 运行 `verifyAll()`
- **THEN** 全部通过，输出 `formats=<N> checked=<M> gaps=0`

### [REQ-FMT-7] 零回归

- **GIVEN** 本 change 只新增规格与测试
- **WHEN** 运行全量测试与 `--verify-pascal`
- **THEN** 全绿 / PASS

## Impact

- **新增**：`game/tools/format_spec.lua`、`game/tests/unit/test_format_spec.lua`
- **修改**：`game/tests/test_runner.lua`
- **未触碰**：`game/engine-love2d/**`、`game/engine-mud/**`、`reference/allmods/**`、`game/mods/**`（只读）

## DoD

1. `lua tools/format_spec.lua --all` 退出码 0，输出 `gaps=0`
2. 20 MOD × 每种格式 `verifyCoverage` 全部 `ok=true`
3. 负例：故意缺口 → `ok=false` 且 `gaps` 非空
4. `test_format_spec.lua` 全绿
5. `lua tests/test_runner.lua` 全绿（无回归）
