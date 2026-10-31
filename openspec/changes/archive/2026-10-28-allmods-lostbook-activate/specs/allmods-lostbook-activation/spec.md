# Spec: allmods-lostbook-activation

> Change: `allmods-lostbook-activate` · Slice: `allmods-slice4` · Epic: `2026-10-allmods-compat`
> 对应需求：REQ-LOST-1 ~ REQ-LOST-6

## REQ-LOST-1: 构建成功

**Given** `reference/allmods/kys-lostbook/` 为只读源
**When** 运行 `cd game && lua tools/mod_build.lua kys-lostbook`
**Then** 退出码为 0

**And** 产出以下产物：
- `game/mods/lostbook/data/`（231 个文件 + `kysmod.ini`）
- `game/mods/lostbook/script/oldevent/`（**1071** 个 `.lua`）
- `game/mods/lostbook/script/oldtalk.grp` + `oldtalk.idx`（3181 条）
- `game/mods/lostbook/save/`（3 个槽：`d11`/`r11`/`s11` + `d1`/`s1`）
- `game/mods/lostbook/sound/`（78 个文件）
- `game/mods/lostbook/diff.md`

## REQ-LOST-2: 逐文件穷举归类

**Given** lostbook 的源目录
**When** 运行 `cd game && lua tools/mod_audit.lua --mod lostbook`
**Then** 输出 `total=342 in_product=312 not_in_product=30 unclassified=0 bad_evidence=0`

**And** 类别分布：
| 类别 | 数 |
|------|--:|
| `REQUIRED` | 307 |
| `REQUIRED_CONVERTED` | 4 |
| `LEGACY` | 3 |
| `BUILD_INPUT` | 1 |
| `PENDING` | 27 |
| **Σ** | **342** |

**And** 「必需但未进产物」矛盾数 = 0。

## REQ-LOST-3: 字节级覆盖

**Given** lostbook 的产物二进制文件
**When** 运行 `cd game && lua tools/format_spec.lua --mod lostbook`
**Then** 输出 `formats=12 checked=201 gaps=0`

**And** 每个字节归入具名字段。

**And** kdef 条目数 = 1071、fight 数 = 97 被识别为**内容差异**（非结构异常）。

## REQ-LOST-4: 真实启动链路

**Given** 独立子进程，`active_mod.txt` 内容为 `lostbook`
**When** 运行 `cd game && lua tests/unit/boot_one_mod.lua lostbook 320 200 84 93 金迷`
**Then** 输出 `RESULT lostbook: OK`

**And** 16 项断言全 PASS：
- `CC.PersonSize=182` / `CC.ThingSize=190` / `CC.SceneSize=52` / `CC.WugongSize=136`
- `PersonNum=320` / `ThingNum=200` / `SceneNum=84` / `WugongNum=93`
- 主角姓名 = 金迷
- 无 U+FFFD（0）
- 无控制符（0）
- 10 帧无报错

## REQ-LOST-5: 存档播种

**Given** lostbook 源 `save/` **无** `r1.grp`
**When** 首次 `SaveRecord(1)`
**Then**：

| 检查 | 期望 |
|------|------|
| 存档前 `r1.grp` | 不存在 |
| `CC.R_GRPFilename[1]` | `mods/lostbook/save/r1.grp` |
| 存档后 `r1.grp` | 存在 |
| 存档后 `r1.idx` | 存在（从 `ranger.idx` 播种） |
| 存档后 `r1.ovr` | 存在（字符串改写） |
| `LoadRecord(1)` 回读 | 姓名正确 |
| 验证后产物 | 恢复至原始状态（无残留） |

## REQ-LOST-6: 零回归

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
