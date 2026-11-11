# Spec: allmods-pig-activation

> Change: `allmods-pig-activate` · Slice: `allmods-slice7` · Epic: `2026-10-allmods-compat`
> 对应需求：REQ-PIG-1 ~ REQ-PIG-8

## REQ-PIG-1: 构建成功

**Given** `reference/allmods/kys-pig/` 为只读源
**When** 运行 `cd game && lua tools/mod_build.lua kys-pig`
**Then** 退出码为 0

**And** 产出以下产物：
- `game/mods/pig/data/`（311 个文件 + `kysmod.ini`）
- `game/mods/pig/data/fight*.grp`（**137** 场）
- `game/mods/pig/script/oldevent/`（**1288** 个 `.lua`）
- `game/mods/pig/script/oldtalk.grp` + `oldtalk.idx`（4123 条）
- `game/mods/pig/save/`（**21** 个文件）
- `game/mods/pig/sound/`（78 个文件）
- `game/mods/pig/diff.md`

## REQ-PIG-2: 逐文件穷举归类

**Given** pig 的源目录
**When** 运行 `cd game && lua tools/mod_audit.lua --mod pig`
**Then** 输出 `total=440 in_product=410 not_in_product=30 unclassified=0 bad_evidence=0`

**And** 类别分布：
| 类别 | 数 |
|------|--:|
| `REQUIRED` | 405 |
| `REQUIRED_CONVERTED` | 4 |
| `LEGACY` | 3 |
| `BUILD_INPUT` | 1 |
| `PENDING` | 27 |
| **Σ** | **440** |

**And** 「必需但未进产物」矛盾数 = 0。

## REQ-PIG-3: 字节级覆盖

**Given** pig 的产物二进制文件
**When** 运行 `cd game && lua tools/format_spec.lua --mod pig`
**Then** 输出 `formats=12 checked=241 gaps=0`

## REQ-PIG-4: `hdgrp` 差异验证

**Given** pig 的 `hdgrp.idx` 为 **173** 条目（pascal 115）
**When** 应用 Slice 5 判据（第 3 次应用）
**Then**：

| 检查 | 期望 |
|------|------|
| `hdgrp.idx` 大小 | 692 字节 = 173 × 4 |
| `CC.HeadPicFile[1]` | `mods/pig/data/hdgrp.idx` |
| 索引驱动 | `PicLoadFile` 用 `idxlen/4` |
| 固定计数常量 | 全部 `nil` |
| 判定 | **内容差异** |

**And** `format_spec` 报 `gaps=0` 佐证。

## REQ-PIG-5: 45 场额外战斗

**Given** pig 有 137 场战斗（pascal 92）
**When** 逐场三重确认
**Then** 45 场额外战斗每场满足：

| # | 证据 | 期望 |
|---|------|------|
| 1 | `diff.md` 提及 | ≥1 次 |
| 2 | 产物 `data/fightNNN.grp` | 存在 |
| 3 | 审计归类 | `REQUIRED` + `in_product=true` |

**And** 额外战斗编号集合：
`030` `039` `040` `110` `115`~`121` `125` `126` `128`~`131` `133`~`146`
`152`~`162` `167` `169` `170`

**And** 产物 `fight*.grp` 总数 = **137**。

## REQ-PIG-6: 真实启动链路

**Given** 独立子进程，`active_mod.txt` 内容为 `pig`
**When** 运行 `cd game && lua tests/unit/boot_one_mod.lua pig 320 200 84 93 小小豬`
**Then** 输出 `RESULT pig: OK`

**And** 16 项断言全 PASS：
- `CC.PersonSize=182` / `CC.ThingSize=190` / `CC.SceneSize=52` / `CC.WugongSize=136`
- `PersonNum=320` / `ThingNum=200` / `SceneNum=84` / `WugongNum=93`
- 主角姓名 = 小小豬
- 无 U+FFFD（0）
- 无控制符（0）
- 10 帧无报错

## REQ-PIG-7: 存档验证

**Given** pig 源 `save/` 含 9 个槽文件（`d1`~`d3`/`r1`~`r3`/`s1`~`s3`）
**When** 检查产物与运行时路径
**Then**：

| 检查 | 期望 |
|------|------|
| 产物 `save/` 文件数 | 21 |
| 与源逐字节一致 | 全部一致 |
| `CC.D_Filename[1]` | `mods/pig/save/d1.grp` |
| `CC.R_GRPFilename[1]` | `mods/pig/save/r1.grp` |
| `CC.S_Filename[1]` | `mods/pig/save/s1.grp` |
| 运行 `mod_check` 后 | 仍与源一致 |
| 全量测试后 | 仍与源一致 |

## REQ-PIG-8: 零回归

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
