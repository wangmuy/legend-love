# Spec: allmods-godsdevils-activation

> Change: `allmods-godsdevils-activate` · Slice: `allmods-slice6` · Epic: `2026-10-allmods-compat`
> 对应需求：REQ-GD-1 ~ REQ-GD-8

## REQ-GD-1: 构建成功

**Given** `reference/allmods/kys-GodsDevils/` 为只读源
**When** 运行 `cd game && lua tools/mod_build.lua kys-GodsDevils`
**Then** 退出码为 0

**And** 产出以下产物：
- `game/mods/GodsDevils/data/`（219 个文件 + `kysmod.ini`）
- `game/mods/GodsDevils/script/oldevent/`（**1123** 个 `.lua`）
- `game/mods/GodsDevils/script/oldtalk.grp` + `oldtalk.idx`（4640 条）
- `game/mods/GodsDevils/save/`（**9** 个文件）
- `game/mods/GodsDevils/sound/`（78 个文件）
- `game/mods/GodsDevils/diff.md`

**And** `head/`/`item/` PNG 目录**不进产物**。

## REQ-GD-2: 逐文件穷举归类

**Given** GodsDevils 的源目录
**When** 运行 `cd game && lua tools/mod_audit.lua --mod GodsDevils`
**Then** 输出 `total=615 in_product=306 not_in_product=309 unclassified=0 bad_evidence=0`

**And** 类别分布：
| 类别 | 数 |
|------|--:|
| `REQUIRED` | 301 |
| `REQUIRED_CONVERTED` | 4 |
| `LEGACY` | 3 |
| `EDITOR_DUMP` | 279 |
| `BUILD_INPUT` | 1 |
| `PENDING` | 27 |
| **Σ** | **615** |

**And** 「必需但未进产物」矛盾数 = 0。

## REQ-GD-3: 字节级覆盖

**Given** GodsDevils 的产物二进制文件
**When** 运行 `cd game && lua tools/format_spec.lua --mod GodsDevils`
**Then** 输出 `formats=12 checked=475 gaps=0`

**And** 每个字节归入具名字段。

## REQ-GD-4: `hdgrp` 差异验证

**Given** GodsDevils 的 `hdgrp.idx` 为 **129** 条目（pascal 115）
**When** 验证引擎加载行为
**Then**：

| 检查 | 期望 |
|------|------|
| `hdgrp.idx` 大小 | 516 字节 = 129 × 4 |
| `CC.HeadPicFile[1]` | `mods/GodsDevils/data/hdgrp.idx` |
| 固定计数常量 | 全部 `nil` |
| 判定 | **内容差异** |

**And** `format_spec` 报 `gaps=0` 佐证。

## REQ-GD-5: `EDITOR_DUMP` 确认

**Given** GodsDevils 的 `head/`（79 PNG）+ `item/`（200 PNG）
**When** 检查审计归类与引擎引用
**Then**：

| 检查 | 期望 |
|------|------|
| 归类 | `EDITOR_DUMP`，`needed=false` |
| 数量 | 79 + 200 = **279** |
| 证据 | `EV_UPEDIT_DUMP`（引用 `mod_build.lua:IGNORE_DIRS`） |
| 构建器忽略 | `IGNORE_DIRS = { head=true, item=true, eft=true }` |
| 引擎引用 | `grep "head/\|item/"` → 0 命中 |
| 产物存在 | **不存在**（不复制） |

## REQ-GD-6: 真实启动链路

**Given** 独立子进程，`active_mod.txt` 内容为 `GodsDevils`
**When** 运行 `cd game && lua tests/unit/boot_one_mod.lua GodsDevils 320 200 84 93 蝦米`
**Then** 输出 `RESULT GodsDevils: OK`

**And** 16 项断言全 PASS：
- `CC.PersonSize=182` / `CC.ThingSize=190` / `CC.SceneSize=52` / `CC.WugongSize=136`
- `PersonNum=320` / `ThingNum=200` / `SceneNum=84` / `WugongNum=93`
- 主角姓名 = 蝦米
- 无 U+FFFD（0）
- 无控制符（0）
- 10 帧无报错

## REQ-GD-7: 存档验证

**Given** GodsDevils 源 `save/` 含 6 个槽文件（`d1`/`d2`/`r1`/`r2`/`s1`/`s2`）
**When** 检查产物与运行时路径
**Then**：

| 检查 | 期望 |
|------|------|
| 产物 `save/` 文件数 | 9 |
| 与源逐字节一致 | 全部一致 |
| `CC.D_Filename[1]` | `mods/GodsDevils/save/d1.grp` |
| `CC.R_GRPFilename[1]` | `mods/GodsDevils/save/r1.grp` |
| `CC.S_Filename[1]` | `mods/GodsDevils/save/s1.grp` |
| 运行 `mod_check` 后 | 仍与源一致 |
| 全量测试后 | 仍与源一致 |

## REQ-GD-8: 零回归

**Given** 本 change 完成后
**When** 运行全部门禁
**Then**：

| 门禁 | 期望 |
|------|------|
| `lua tests/test_runner.lua` | 全绿 |
| `lua tools/mod_build.lua --verify-pascal` | `mismatches=0` |
| `lua tools/mod_build.lua --all` | `0 build failures` |
| `lua tools/mod_check.lua` | 20/20 |
| `lua tools/mod_audit.lua --all` | `unclassified=0` |
| `lua tools/format_spec.lua --all` | `gaps=0` |
| 全 MOD `save/` 与源 | 一致 |
