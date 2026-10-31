# Spec: allmods-heavensword-activation

> Change: `allmods-heavensword-activate` · Slice: `allmods-slice5` · Epic: `2026-10-allmods-compat`
> 对应需求：REQ-HS-1 ~ REQ-HS-7

## REQ-HS-1: 构建成功

**Given** `reference/allmods/kys-HeavenSword/` 为只读源
**When** 运行 `cd game && lua tools/mod_build.lua kys-HeavenSword`
**Then** 退出码为 0

**And** 产出以下产物：
- `game/mods/HeavenSword/data/`（223 个文件 + `kysmod.ini`）
- `game/mods/HeavenSword/script/oldevent/`（**1066** 个 `.lua`）
- `game/mods/HeavenSword/script/oldtalk.grp` + `oldtalk.idx`（3315 条）
- `game/mods/HeavenSword/save/`（`d11.grp`/`r11.grp`/`s11.grp` + `r1.idx`）
- `game/mods/HeavenSword/sound/`（78 个文件）
- `game/mods/HeavenSword/diff.md`

## REQ-HS-2: 逐文件穷举归类

**Given** HeavenSword 的源目录
**When** 运行 `cd game && lua tools/mod_audit.lua --mod HeavenSword`
**Then** 输出 `total=335 in_product=305 not_in_product=30 unclassified=0 bad_evidence=0`

**And** 类别分布：
| 类别 | 数 |
|------|--:|
| `REQUIRED` | 300 |
| `REQUIRED_CONVERTED` | 4 |
| `LEGACY` | 3 |
| `BUILD_INPUT` | 1 |
| `PENDING` | 27 |
| **Σ** | **335** |

**And** 「必需但未进产物」矛盾数 = 0。

## REQ-HS-3: 字节级覆盖

**Given** HeavenSword 的产物二进制文件
**When** 运行 `cd game && lua tools/format_spec.lua --mod HeavenSword`
**Then** 输出 `formats=12 checked=197 gaps=0`

**And** 每个字节归入具名字段。

## REQ-HS-4: `hdgrp` 差异验证

**Given** HeavenSword 的 `hdgrp.idx` 为 **125** 条目（pascal 为 115）
**When** 验证引擎加载行为
**Then**：

| 检查 | 期望 |
|------|------|
| `hdgrp.idx` 大小 | 500 字节 = 125 × 4 |
| `CC.HeadPicFile[1]` | `mods/HeavenSword/data/hdgrp.idx` |
| 固定计数常量（`HDGRPNum`/`HDPicNum`/`MAX_HEAD_NUM`/`HDGRP`/`HeadNum`） | 全部 `nil`（不存在） |
| `PicLoadFile` 条目数来源 | `idxlen/4`（文件大小推导） |
| 判定 | **内容差异**，非结构异常 |

**And** `format_spec --mod HeavenSword` 报 `gaps=0` 佐证。

## REQ-HS-5: 真实启动链路

**Given** 独立子进程，`active_mod.txt` 内容为 `HeavenSword`
**When** 运行 `cd game && lua tests/unit/boot_one_mod.lua HeavenSword 320 200 84 93 楊千葉`
**Then** 输出 `RESULT HeavenSword: OK`

**And** 16 项断言全 PASS：
- `CC.PersonSize=182` / `CC.ThingSize=190` / `CC.SceneSize=52` / `CC.WugongSize=136`
- `PersonNum=320` / `ThingNum=200` / `SceneNum=84` / `WugongNum=93`
- 主角姓名 = 楊千葉
- 无 U+FFFD（0）
- 无控制符（0）
- 10 帧无报错

## REQ-HS-6: 存档验证

**Given** HeavenSword 源 `save/` 含 `r1.idx`（24 字节，与 `ranger.idx` md5 相同）但**无** `r1.grp`
**When** 首次 `SaveRecord(1)`
**Then**：

| 检查 | 期望 |
|------|------|
| 存档前 `r1.grp` | 不存在 |
| 存档前 `r1.idx` | 存在（源提供） |
| `CC.R_GRPFilename[1]` | `mods/HeavenSword/save/r1.grp` |
| 存档后 `r1.grp` | 存在（播种） |
| 存档后 `r1.idx` | 存在（保留源文件） |
| 存档后 `r1.ovr` | 存在（字符串改写） |
| `LoadRecord(1)` 回读 | 姓名正确 |
| 验证后产物 | 恢复至原始状态（`r1.grp` 删除，`r1.idx` 复原） |

## REQ-HS-7: 零回归

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
