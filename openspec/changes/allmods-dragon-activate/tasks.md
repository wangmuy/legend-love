---
status: done
created: 2026-10-25
---

# Tasks: allmods-dragon-activate

## Blast Radius

允许写入：
- `openspec/changes/allmods-dragon-activate/**`
- `openspec/changes/allmods-slice11/**`
- `openspec/epics/2026-10-allmods-compat/**`
- `game/mods/Dragon/**`（构建产物，gitignore）
- `game/tests/**`、`game/tools/**`（仅当发现工具缺陷，须在本文件记录）

禁止写入：
- `game/engine-love2d/**`、`game/engine-mud/**`
- `game/script/jyconst.lua` 常量定义
- `reference/allmods/**`

---

## 1. 构建（REQ-DRG-1）

- [x] 1.1 `cd game && rm -f active_mod.txt && lua tools/mod_build.lua kys-Dragon`
      - DoD: 输出 `data files=458, saves=21, sound=80, events=1087, talk=4020`，退出码 0
      - 实测：`[mod_build] kys-Dragon: data files=458, saves=21, sound=80, events=1087, talk=4020` ✅
- [x] 1.2 确认 `mods/Dragon/diff.md` 已生成
      - 实测：`[mod_build] diff -> tools/../mods/Dragon/diff.md` ✅
- [x] 1.3 确认 `mods/Dragon/data/fight*.grp` = 209
      - 实测：`ls mods/Dragon/data/fight*.grp | wc -l` → 209 ✅
- [x] 1.4 确认 `mods/Dragon/save/` = 27 文件
      - 实测：27 ✅

## 2. 逐文件穷举审计（REQ-DRG-2）

- [x] 2.1 `lua tools/mod_audit.lua --mod Dragon`
      - DoD: `total=811 unclassified=0 bad_evidence=0`，`total` = 源文件数
      - 实测：`total=811 in_product=555 not_in_product=256 unclassified=0 bad_evidence=0` ✅
- [x] 2.2 源文件总数交叉核对
      - 实测：`find reference/allmods/kys-Dragon -type f | wc -l` → **811** ✅ 与 `total` 相等
- [x] 2.3 类别求和 = total
      - 实测：550 + 4 + 5 + 1 + 220 + 2 + 29 = **811** ✅
- [x] 2.4 「必需但未进产物」矛盾数 = 0
      - `needed=true` 554 项（REQUIRED 550 + REQUIRED_CONVERTED 4）全 `in_product=true` ✅
      - `not_in_product=256` = EDITOR_DUMP 220 + PENDING 29 + LEGACY 5 + DEAD_FILE 1 + BUILD_INPUT 1 ✅

## 3. 字节级格式覆盖（REQ-DRG-3）

- [x] 3.1 `lua tools/format_spec.lua --mod Dragon`
      - DoD: `gaps=0`
      - 实测：`formats=12 checked=535 gaps=0` ✅

## 4. 真实启动链路（REQ-DRG-4）

- [x] 4.1 删除 `active_mod.txt` 保证干净态
- [x] 4.2 `lua tests/unit/boot_one_mod.lua Dragon 589 237 106 114 資`（独立子进程）
      - DoD: `RESULT Dragon: OK`，16/16 PASS
      - 实测：16 PASS，`RESULT Dragon: OK`，扫描字段 2109，U+FFFD 0，控制符 0，10 帧无报错 ✅

## 5. `hdgrp` 267（REQ-DRG-5，判据第 7 次应用）

- [x] 5.1 `stat -c%s mods/Dragon/data/hdgrp.idx` → 1068 ⇒ 267 条目
      - 实测：1068 / 4 = **267** ✅（基线 115，+152）
- [x] 5.2 判据①索引驱动：`grep -n "idxlen/4" game/engine-love2d/lib_love.lua`
      - 实测：`:437 local num = idxlen/4` ✅
- [x] 5.3 判据②无固定计数常量：`grep -rn "hdgrpNum\|HDGRPNum\|HDPicNum\|MAX_HEAD" engine-love2d/ framework/ script/jyconst.lua`
      - 实测：**0 命中** ✅
- [x] 5.4 判据③`gaps=0`（见 3.1）
- [x] 5.5 记录外推链：125 / 129 / 173 / 178 / 204 / 252 / **267**，七次一致

## 6. `eft` 714 同形（REQ-DRG-6，ADR-002）

- [x] 6.1 `stat -c%s mods/Dragon/data/eft.idx` → 2856 ⇒ 714 条目
      - 实测：714 ✅（= 基线）
- [x] 6.2 `stat -c%s mods/Dragon/data/eft.grp` → 691627
      - 实测：691627 ✅（= 基线）
- [x] 6.3 `eft.idx` 偏移单调不减 + `idx[-1] == grp` 大小
      - 实测：`monotonic: True`、`last offset == grp size: True (691627)` ✅
- [x] 6.4 md5 与基线比对
      - `1c5aef33893e078ade30f6d237ec6cb1` `data/eft.grp` == `mods/Dragon/data/eft.grp` ✅
      - `35ccc7e5cc1a096e183d3ff2919f743b` `data/eft.idx` == `mods/Dragon/data/eft.idx` ✅
- [x] 6.5 运行时路径确认（关键：证明不是「回退原版」）
      - 实测：`CC.EffectFile[1] = mods/Dragon/data/eft.idx`、`CC.EffectFile[2] = mods/Dragon/data/eft.grp` ✅
      - ⇒ 路径指向 **MOD** 目录，内容是 MOD 自己的（恰好与基线相同）

## 7. eft id 上界（REQ-DRG-7）

- [x] 7.1 实测 `JY.Wugong[*]["武功动画&音效"]` 最大值
      - 实测：`WugongNum=114 eft id max=52 (CC.Effect 上界 52)`，越界条数 = 无 ✅
      - ⇒ 本 MOD **不受** `CC.Effect` 53 项截断缺陷影响（归入 13/20 不越界 MOD）

## 8. 记录段 589/237/106/114（REQ-DRG-8，判据第 4 次应用）

- [x] 8.1 读 `reference/allmods/kys-Dragon/save/ranger.idx` 原始偏移
      - 实测：`[836, 108034, 153064, 158576, 174080, 174230]`，grp = 174230
- [x] 8.2 段长整除（余数全 0）
      - Person 107198/182 = **589.000** rem 0 ✅
      - Thing 45030/190 = **237.000** rem 0 ✅
      - Scene 5512/52 = **106.000** rem 0 ✅
      - Wugong 15504/136 = **114.000** rem 0 ✅
      - Shop 150/50 = 3.000 rem 0 ✅
- [x] 8.3 Σ 段长 = grp - 首偏移
      - 107198+45030+5512+15504+150 = 173394 = 174230 - 836 ✅
- [x] 8.4 边界记录可读且非空
      - `Person[0]=資` / `Person[588]=李卡多`；`Thing[0]=小還丹` / `Thing[236]=真武劍`；
        `Scene[0]=胡斐居` / `Scene[105]=西部農村`；`Wugong[0]=普通攻擊` / `Wugong[113]=閃電貂` ✅
- [x] 8.5 Scene 用**内容**证明（记录数 +22 已异，仍须内容证据）
      - `Scene[2]` 雪山 vs 云鶴崖 ❌；`Scene[50]` 閰基居（超基线）❌；`Scene[105]` 西部農村（超基线）❌
      - `Scene[0]`/`[1]` 与基线相同（MOD 保留原版首两场景）
      - ⇒ 3/5 不同 + 2 项超基线范围 ⇒ 内容来自 MOD ✅

## 9. 额外战斗（REQ-DRG-9）

- [x] 9.1 产物 fight 计数
      - 实测：Dragon **209**，pascal **92**
- [x] 9.2 差集（新增 / 移除）
      - 实测：`diff: 119`，`removed: ['fight101.grp','fight102.grp']`
      - 校验：`92 - 2 + 119 = 209` ✅
- [x] 9.3 三重确认
      - ① `diff.md` 中 fight MOD 独有 = **119** ✅
      - ② `diff.md` set == 实测差集 set → `True` ✅
      - ③ 产物 209 全部 `REQUIRED` / `in_product=true` ✅
- [x] 9.4 每个 `.grp` 有配对 `.idx`（审计 `REQUIRED` 成对出现）

## 10. `fight101`/`fight102` 缺失容错（REQ-DRG-10，ADR-003）

- [x] 10.1 证明 MOD 数据仍引用 101/102
      - 实测：`Person 总数=589 有头像代号=217 最大=219`；`引用 101 ? true`、`引用 102 ? true` ✅
- [x] 10.2 降级链① `FileLength` 打开失败返回 -1
      - `engine-love2d/lib_love.lua:281-288` ✅
- [x] 10.3 降级链② `PicLoadFile` `if idxlen < 0 ... then return end`
      - 实测：`PicLoadFile(缺失 fight101) pcall=true err=nil` ✅
- [x] 10.4 降级链③ `PicGetXY` 返回 0
      - 实测：`PicGetXY pcall=true ret=0` ✅
- [x] 10.5 判定为 MOD 作者侧数据不一致，不复制基线文件、不篡改数据

## 11. 存档完好 + 25 项「基准独有」五分法（REQ-DRG-11）

- [x] 11.1 逐字节比对源 `save/` 与产物 `save/`
      - 实测：源 27、产物 27，`缺失/不一致: []`，`产物多余: []` ✅
- [x] 11.2 记录产物 save/ 实际构成（**修正初稿错误**）
      - 实测：21 个 `.grp` + **6 个 `.idx`**（`alldef.idx` 336B、`allsin.idx` 336B、
        `ranger.idx` 24B、`r1.idx`/`r2.idx`/`r3.idx` 24B）
      - 初稿曾声称「无 `.idx` 槽 ⇒ 无首次播种」，**该说法错误已修正**
- [x] 11.3 `diff.md`「基准独有」计数
      - 实测：**25** 项
- [x] 11.4 A 类（在 save/，源自带存档）9 项
      - `d1`~`d3`/`r1`~`r3`/`s1`~`s3` `.grp`，源↔产物逐字节一致 ✅
- [x] 11.5 B 类（首次播种）9 项
      - 运行时实测：`slot 0 = mods/Dragon/data/ranger.idx (24B)`，
        `slot 1/2/3 = mods/Dragon/save/r{1,2,3}.idx (size=-1 ⇒ 不存在)`
      - `SeedSaveSlot(1..3)` 返回 `mods/Dragon/save/r{1,2,3}.idx`，播种后 size=24
      - 逐字节：`r1/2/3.idx == MOD ranger.idx` → **True**；`== 基线 ranger.idx` → **False** ✅
      - ⇒ 播种源为 MOD 模板，非基线
- [x] 11.6 C 类（回退原版）2 项
      - `thing.{grp,idx}`；运行时 `CC.ThingPicFile[1] = data/thing.idx`、
        `[2] = data/thing.grp`（**基线**目录）✅
- [x] 11.7 D 类（死文件）1 项
      - `allsinbk.grp`；`CC.TempS_Filename = data/allsinbk.grp`，
        唯一使用点 `jymain.lua:1835` 传入 `LoadSMap`；
        `grep -c tmpfilename engine-love2d/lib_love.lua` → **1**（仅 `:890` 签名），函数体零引用 ✅
- [x] 11.8 **E 类（数据引用但资源缺失）4 项 —— 本 epic 新增第 5 类**
      - `fight101.{grp,idx}`、`fight102.{grp,idx}`
      - 证据：MOD 源无此 4 文件（基准独有），但 `Person["头像代号"]` **引用 101/102**
        （`引用 101 ? true`、`引用 102 ? true`，最大 219）
      - 与 A 区别：A 是「基准有 MOD 也有」；E 是「基准有 MOD 完全没有」
      - 与 D 区别：D 是「源有但引擎不读」；E 是「源无但数据仍引用」
      - 与 RiverLake 0 字节 fight 区别：RiverLake「文件在但内容空」；Dragon「文件根本不在」✅
- [x] 11.9 Σ = 9 + 9 + 2 + 1 + 4 = **25** ✅
- [x] 11.10 播种实验后恢复产物（`cmp` 校验 27/27 逐字节一致）
      - 实测：`src 27 prod 27 same set: True`、`byte-diff: []` ✅

## 12. `war1.sta` `DEAD_FILE`（REQ-DRG-12，ADR-005）

- [x] 12.1 文件存在且整除
      - 实测：`66030` 字节，`66030 ÷ 186 = 355` 记录（`CC.WarDataSize=186`）✅
- [x] 12.2 `CC.WarFile` 只指向 `war.sta`
      - 实测：`script/jyconst.lua:129 CC.WarFile=CONFIG.DataPath .. "war.sta"`；
        运行时 `CC.WarFile = mods/Dragon/data/war.sta` ✅
- [x] 12.3 代码零引用
      - 实测：`grep -rn "war1" script/ framework/ engine-love2d/` → **0 命中** ✅
- [x] 12.4 审计规则已标注
      - 实测：`tools/mod_audit.lua:189` `["resource/war1.sta"] = { category="DEAD_FILE", needed=false, ... }`，
        证据串「引擎只读 war.sta，war1.sta 不可达」（`:132`）✅
- [x] 12.5 与 RiverLake `allsinbk.grp` 的机制区别写入报告（design ADR-005 / verification）

## 13. `head/` 220 PNG（REQ-DRG-13，ADR-004）

- [x] 13.1 数量
      - 实测：`ls reference/allmods/kys-Dragon/head | wc -l` → **220** ✅
- [x] 13.2 构建忽略
      - 实测：`tools/mod_build.lua:567 IGNORE_DIRS = { head = true, item = true, eft = true }` ✅
- [x] 13.3 引擎零引用
      - 实测：`grep -rn 'head/\|"head"' engine-love2d/ framework/ script/` → **0 命中** ✅
- [x] 13.4 产物无 `head/`
      - 实测：`ls mods/Dragon/` → `data diff.md encoding-report.md save script sound` ✅
- [x] 13.5 审计归类
      - 实测：`EDITOR_DUMP` = **220**，全部 `in_product=false`，`topdir=head` ✅

## 14. `war.sta` 同名不同内容（ADR-006）

- [x] 14.1 尺寸与记录数
      - 源=产物 42222B（227 记录）；基线 `data/war.sta` 26040B（140 记录）✅
- [x] 14.2 结构整除（186B/记录）两处均余 0
- [x] 14.3 判为内容差异，非结构异常（与 ADR-001 同族判据）

## 15. 零回归门禁（REQ-DRG-14，已实跑）

- [x] 15.1 `cd game && lua tests/test_runner.lua` → **1842/1842**
- [x] 15.2 `lua tools/mod_build.lua --verify-pascal` → `mismatches=0`
- [x] 15.3 `lua tools/mod_build.lua --all` → `20 mods, 0 build failures`
- [x] 15.4 `lua tools/mod_check.lua` → **20/20**
- [x] 15.5 `lua tools/mod_audit.lua --all --evidence` → `unclassified=0 bad_evidence=0`，`failed=0`
- [x] 15.6 `lua tools/format_spec.lua --all` → `gaps=0`
- [x] 15.7 20 MOD `save/` vs 源 → 不一致/残留 = 0
- [x] 15.8 禁改路径零改动（`engine-love2d/` `engine-mud/` `jyconst.lua` `reference/allmods/`）

## 16. 交付物

- [x] 16.1 `proposal.md`
- [x] 16.2 `design.md`（ADR-001~006）
- [x] 16.3 `specs/allmods-dragon-activation/spec.md`（REQ-DRG-1~14）
- [x] 16.4 `tasks.md`（本文件）
- [x] 16.5 `verification.md`（门禁实跑结果，15 章节）

## 工具缺陷记录

本 slice 未发现新工具缺陷（前 10 个 slice 累计 6 个已修复）。
