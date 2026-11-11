# Spec: allmods-lyff-activation

> Change: `allmods-lyff-activate` · Slice: `allmods-slice8` · Epic: `2026-10-allmods-compat`
> 对应需求：REQ-LYFF-1 ~ REQ-LYFF-9

## REQ-LYFF-1: 构建成功

**Given** `reference/allmods/kys-lyff/` 为只读源
**When** 运行 `cd game && lua tools/mod_build.lua kys-lyff`
**Then** 退出码为 0

**And** 产出以下产物：
- `game/mods/lyff/data/`（311 个文件 + `kysmod.ini`）
- `game/mods/lyff/script/oldevent/`（**1358** 个 `.lua`）
- `game/mods/lyff/script/oldtalk.grp` + `oldtalk.idx`（5655 条）
- `game/mods/lyff/save/`（**6** 个文件）
- `game/mods/lyff/sound/`（78 个文件）
- `game/mods/lyff/diff.md`

**And** 46 场额外战斗的 `fight*.grp`/`.idx` 进入 `data/`。

## REQ-LYFF-2: 逐文件穷举归类

**Given** lyff 的源目录
**When** 运行 `cd game && lua tools/mod_audit.lua --mod lyff`
**Then** 输出 `total=425 in_product=395 not_in_product=30 unclassified=0 bad_evidence=0`

**And** 类别分布：
| 类别 | 数 |
|------|--:|
| `REQUIRED` | 390 |
| `REQUIRED_CONVERTED` | 4 |
| `LEGACY` | 3 |
| `BUILD_INPUT` | 1 |
| `PENDING` | 27 |
| **Σ** | **425** |

**And** 「必需但未进产物」矛盾数 = 0。

## REQ-LYFF-3: 字节级覆盖

**Given** lyff 的产物二进制文件
**When** 运行 `cd game && lua tools/format_spec.lua --mod lyff`
**Then** 输出 `formats=12 checked=242 gaps=0`

**And** 每个字节归入具名字段（含 326 条人物段）。

## REQ-LYFF-4: 326 人物段验证

**Given** lyff 源模板 `ranger.grp` 人物段含 326 条记录（`idx[2]-idx[1] = 59332 = 326 × 182`）
**When** 构建 + 启动
**Then**：

| 检查 | 期望 |
|------|------|
| `mod_check_one` | `PERSON=326` |
| 启动链路 `PersonNum` | 326 |
| 边界记录 `Person[325]` | 有效（姓名/外号可读） |
| 推导方式 | `(idx[2]-idx[1])/CC.PersonSize`（`jymain.lua:1747`），无固定计数 |
| 字节覆盖 | `gaps=0` |

## REQ-LYFF-5: `hdgrp` 差异验证

**Given** lyff 的 `hdgrp.idx` 为 **178** 条目（pascal 115）
**When** 验证引擎加载行为
**Then**：

| 检查 | 期望 |
|------|------|
| `hdgrp.idx` 大小 | 712 字节 = 178 × 4 |
| `CC.HeadPicFile[1]` | `mods/lyff/data/hdgrp.idx` |
| 固定计数常量 | 全部 `nil` |
| 判定 | **内容差异**（判据第 4 次应用） |

**And** `format_spec` 报 `gaps=0` 佐证。

## REQ-LYFF-6: 46 场额外战斗

**Given** lyff 的 fight 目录含 138 场（92 基线 + 46 MOD 独有）
**When** 核对产物与审计
**Then**：
- `diff.md` 列出 46 场（各 `.grp`+`.idx`，共 92 项）
- 产物 `data/fight*.grp` = **138**
- 审计归类 `REQUIRED` + `in_product=true`

## REQ-LYFF-7: 真实启动链路

**Given** 独立子进程，`active_mod.txt` 内容为 `lyff`
**When** 运行 `cd game && lua tests/unit/boot_one_mod.lua lyff 326 200 84 93 AAA`
**Then** 输出 `RESULT lyff: OK`

**And** 16 项断言全 PASS：
- `CC.PersonSize=182` / `CC.ThingSize=190` / `CC.SceneSize=52` / `CC.WugongSize=136`
- `PersonNum=326` / `ThingNum=200` / `SceneNum=84` / `WugongNum=93`
- 主角姓名 = AAA
- 无 U+FFFD（0）
- 无控制符（0）
- 10 帧无报错

## REQ-LYFF-8: 存档验证

**Given** lyff 源 `save/` 含 3 个槽文件（`d1`/`r1`/`s1`，**无 `r1.idx`**——第 3 种形态）
**When** 检查产物与运行时路径
**Then**：

| 检查 | 期望 |
|------|------|
| 产物 `save/` 文件数 | 6（`d11`/`r11`/`s11` + `d1`/`r1`/`s1`） |
| 源自带 3 个与源逐字节一致 | 全部一致（含全量测试后） |
| `CC.D_Filename[1]` | `mods/lyff/save/d1.grp` |
| `CC.R_GRPFilename[1]` | `mods/lyff/save/r1.grp` |
| `CC.R_IDXFilename[1]` | `mods/lyff/save/r1.idx`（源无，首次保存播种——Slice 6 已验证机制） |
| `CC.S_Filename[1]` | `mods/lyff/save/s1.grp` |

## REQ-LYFF-9: 零回归

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
