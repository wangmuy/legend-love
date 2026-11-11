# Design: allmods-ptt-activate

## Context

ptt 是第 3 梯队收官 MOD，也是本 epic 第一个同时触发三类差异的 MOD：
`hdgrp` 条目差异（204）、**4 段记录数全异**（385/214/90/108）、+70 额外战斗。
本 change 验证三类差异全部属于「内容差异」，零引擎改动、零代码改动。

## ADR-001: `hdgrp` 204 差异 —— 判据第 5 次应用

- **Context**：`hdgrp.idx` = 816 字节 = 204 条目（pascal 115）。
- **Decision**：复用 Slice 5 三重判据：
  1. 索引驱动：`PicLoadFile` 用 `local num = idxlen/4`（`lib_love.lua:437`）；
  2. 无固定计数：全仓库无 `HDGRPNum`/`HDPicNum` 类常量；
  3. 字节全覆盖：`format_spec --mod ptt` → `gaps=0`。
- **Alternatives**：(a) 截断到 115 条 —— 丢弃 MOD 内容，违背目标；(b) 引擎加常量 —— 违反零引擎改动约束。
- **Consequences**：判定为内容差异（更多头像），零引擎改动。
  外推链：125（HeavenSword）→ 129（GodsDevils）→ 173（pig）→ 178（lyff）→ **204（ptt）**，结论一致。

## ADR-002: 4 段记录数全异 —— 统一判据第 2 次应用

- **Context**：ptt 的 Person 385 / Thing 214 / Scene 90 / Wugong 108 与基线 320/200/84/93 全异
  （lyff 仅 Person 段差异，是第 1 次应用）。
- **Decision**：复用 Slice 8 统一判据（四重）：
  1. 索引驱动：`JY.PersonNum = (idx[2]-idx[1])/CC.PersonSize`（`jymain.lua:1747`），其余段同理；
  2. 无固定计数：全仓库无 `PERSON_NUM`/`THING_NUM` 类常量；
  3. 字节全覆盖：`gaps=0`；
  4. 边界有效：末条记录 tail32 含有效 hint（`P0489`/`T0395`/`S0088`/`W0107`），可正常读出。
- **实测**：Person 70070=385×182、Thing 40660=214×190、Scene 4680=90×52、
  Wugong 14688=108×136、Shop 150=3×50 —— 全部整除，无余数。
- **Alternatives**：(a) 按基线 320 条截断 —— 丢失 65 个人物等 MOD 内容；(b) 引擎按最大段长预分配 —— 违反零引擎改动。
- **Consequences**：判定为内容差异，零引擎改动。统一判据外推至第 4~5 梯队（dream 484 头像等）。

## ADR-003: 70 场额外战斗 = 三重确认

- **Context**：ptt 战斗 162 场（pascal 92），+70 为本 epic 目前最多。
- **Decision**：每场战斗必须三重确认：
  1. `diff.md` 提及（`+ fightNNN.grp`/`+ fightNNN.idx`）；
  2. 产物 `data/fightNNN.grp` 实际存在；
  3. 审计归类 `REQUIRED`/`in_product=true`。
- **Alternatives**：只数总数 —— 无法区分「新增战斗」与「改名战斗」。
- **Consequences**：70 场全部通过三重确认（抽样 `fight104` 全链一致）。

## ADR-004: 18 个源自带存档 —— 缺陷 D 修复的更强检验

- **Context**：ptt 源自带 18 个存档槽（`d1`~`d6`/`r1`~`r6`/`s1`~`s6`），本 epic 最多（pig 为 9 个）。
  Slice 5 缺陷 D（`mod_check_one` 的 `SLOTS` 遗漏 `d1.grp`/`s1.grp`）若仍有遗漏，
  更多槽位会更快暴露。
- **Decision**：验证前记录产物 `save/` 全部 21 个文件的 md5；跑 `mod_check_one` + 全量测试后
  逐一比对，必须逐字节一致。
- **Alternatives**：只查 `r1.grp` —— Slice 2/3/5 已三次证明单槽检查会漏。
- **Consequences**：21/21 逐字节一致，缺陷 D 修复持久性再次验证通过。

## Negative Constraints（负向约束）

- 不得修改 `game/engine-love2d/**`、`game/engine-mud/**`、`game/script/jyconst.lua` 常量定义、`reference/allmods/**`。
- 不得把 `hdgrp` 204 / 4 段记录数差异 / 70 场战斗判定为结构异常（ADR-001/002/003）。
- 不得用「记录数相同」作为 MOD 内容已加载的证据（ptt 与基线全不同，反而必须用非基线值证明）。
- 不得把 `eft/` PNG 判为「需要」而无证据（`EDITOR_DUMP`，证据链见 verify ADR-003）。

## Review Checklist

- [x] `hdgrp` 204 三重判据全部机器可验证
- [x] 4 段记录数四重判据全部机器可验证（含 tail32 边界检查）
- [x] 70 场战斗三重确认（抽样 + 总数）
- [x] 21 个产物存档逐字节一致
- [x] 零引擎改动（git diff 无 engine 路径）
- [x] 回归测试全绿
