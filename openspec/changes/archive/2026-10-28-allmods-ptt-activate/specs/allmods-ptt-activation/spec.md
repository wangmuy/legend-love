# Spec: allmods-ptt-activation

> 对应需求：REQ-PTT-1 ~ REQ-PTT-9

## REQ-PTT-1: 构建成功

**Given** `reference/allmods/kys-ptt/` 为只读源
**When** 运行 `cd game && lua tools/mod_build.lua kys-ptt`
**Then** 退出码为 0

**And** 产出以下产物：
- `game/mods/ptt/data/`（362 个文件 + `kysmod.ini`）
- `game/mods/ptt/data/fight*.grp`（**162** 场）
- `game/mods/ptt/script/oldevent/`（**1229** 个 `.lua`）
- `game/mods/ptt/script/oldtalk.grp` + `oldtalk.idx`（5689 条）
- `game/mods/ptt/save/`（**21** 个文件）
- `game/mods/ptt/sound/`（78 个文件）
- `game/mods/ptt/diff.md`

## REQ-PTT-2: 逐文件穷举归类

**Given** ptt 源目录共 596 个文件
**When** 运行 `lua tools/mod_audit.lua --mod ptt`
**Then** 输出 `total=596 in_product=459 not_in_product=137 unclassified=0 bad_evidence=0`

**And** 类别分布：REQUIRED 454 / REQUIRED_CONVERTED 4 / LEGACY 3 / EDITOR_DUMP 105 /
BUILD_INPUT 2 / PLATFORM_ARTIFACT 1 / PENDING 27，`Σ(类别) = 596`，矛盾数 = 0。

## REQ-PTT-3: 字节级覆盖

**Given** ptt 产物已构建
**When** 运行 `lua tools/format_spec.lua --mod ptt`
**Then** 输出 `formats=12 checked=317 gaps=0`

## REQ-PTT-4: `hdgrp` 差异验证

**Given** `hdgrp.idx` = 816 字节 = 204 条目（pascal 115）
**When** 应用 Slice 5 三重判据（索引驱动 + 无固定计数 + 字节全覆盖）
**Then** 判定为**内容差异**（更多头像），零引擎改动

**And** 外推链 125/129/173/178/**204** 结论一致（判据第 5 次应用）。

## REQ-PTT-5: 4 段记录数差异验证

**Given** ptt 记录段 Person 385 / Thing 214 / Scene 90 / Wugong 108（基线 320/200/84/93）
**When** 对每段应用统一判据（索引驱动 + 无固定计数 + 字节全覆盖 + 边界有效）
**Then** 4 段全部判定为**内容差异**，零引擎改动

**And** 段长整除：70070=385×182、40660=214×190、4680=90×52、14688=108×136；
边界记录 tail32 含有效 hint（`P0489`/`T0395`/`S0088`/`W0107`）。

## REQ-PTT-6: 70 场额外战斗

**Given** ptt 战斗 162 场 vs pascal 92 场
**When** 对每场额外战斗做三重确认（`diff.md` + 产物存在 + 审计 `REQUIRED`/`in_product=true`）
**Then** 70 场全部通过，产物 `fight*.grp` 总数 = 162

## REQ-PTT-7: 真实启动链路

**Given** ptt 产物已构建
**When** 独立进程运行 `lua tests/unit/boot_one_mod.lua ptt 385 214 90 108 鄉民`
**Then** 输出 `RESULT ptt: OK`，16 项断言全 PASS
（布局常量、记录数 385/214/90/108、主角「鄉民」、0 U+FFFD、0 控制符、10 帧无报错）

## REQ-PTT-8: 存档验证

**Given** 产物 `save/` 含 21 个文件
**When** 与源 `reference/allmods/kys-ptt/save/` 逐文件比对
**Then** 21/21 逐字节一致；源自带 18 个槽（`d1`~`d6`/`r1`~`r6`/`s1`~`s6`）
全部完好；运行时 `CC.D_Filename[1]`/`R_GRPFilename[1]`/`S_Filename[1]`
指向 `mods/ptt/save/`

## REQ-PTT-9: 零回归

**Given** ptt 验证完成
**When** 运行全量门禁
**Then** `test_runner` 全绿（1613/1613）、`--verify-pascal` `mismatches=0`、
`--all` `0 build failures`、`mod_check` 20/20、全 MOD `save/` 与源一致
