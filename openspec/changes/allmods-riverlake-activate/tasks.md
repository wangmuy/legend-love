# Tasks: allmods-riverlake-activate

> Slice 10 = `kys-RiverLake`（Tier 4 开场，`hdgrp` 252）。
> 全部任务已完成并复跑取证。

## 1. 构建（REQ-RIV-1）

- [x] `cd game && lua tools/mod_build.lua kys-RiverLake` → 退出码 0
- [x] 产物计数：`data files=478, saves=21, sound=170, events=1232, talk=8015`
- [x] `diff.md` 生成（`game/mods/RiverLake/diff.md`）
- [x] `game/mods/RiverLake/data/fight*.grp` = **219** 个

**Blast Radius**：`game/mods/RiverLake/**`（构建产物，`gitignore`）。
**DoD**：`events=1232` 且 `talk=8015` 且 `sound=170` 且 `fight*.grp`=219 且退出码 0。

## 2. 逐文件穷举审计（REQ-RIV-2）

- [x] `lua tools/mod_audit.lua --mod RiverLake` →
      `total=699 in_product=666 not_in_product=33 unclassified=0 bad_evidence=0`
- [x] 类别分布 Σ=699：`REQUIRED 661` / `REQUIRED_CONVERTED 4` / `LEGACY 5` /
      `BUILD_INPUT 2` / `PENDING 27`
- [x] 源文件总数实测 = **699**（= `total`，审计对象 = 源全集）
- [x] 「必需（`needed=true`）但 `in_product=false`」矛盾数 = **0**

**Blast Radius**：只读（`reference/allmods/kys-RiverLake/` + 产物）。
**DoD**：`unclassified=0 bad_evidence=0` 且 Σ(类别)=699 且矛盾数=0。

## 3. 字节级格式覆盖（REQ-RIV-3）

- [x] `lua tools/format_spec.lua --mod RiverLake` → `formats=12 checked=413 gaps=0`
- [x] 12 个格式族全部覆盖，无 "rest"-only 区间

**Blast Radius**：只读。
**DoD**：`gaps=0`。

## 4. 真实启动链路端到端（REQ-RIV-4）

- [x] `rm -f active_mod.txt && lua tests/unit/boot_one_mod.lua RiverLake 325 249 84 96 茲`
- [x] `RESULT RiverLake: OK`，**16/16 断言 PASS**：
      - `CC.PersonSize=182` / `ThingSize=190` / `SceneSize=52` / `WugongSize=136`（全 MOD 布局）
      - `PersonNum=325` / `ThingNum=249` / `SceneNum=84` / `WugongNum=96`
      - 主角姓名 = `茲`
      - 扫描字段 1577（> 100）
      - U+FFFD = 0 / 控制符 = 0
      - 运行时 10 帧无报错

**Blast Radius**：只读 + 临时 `active_mod.txt`（已清理）。
**DoD**：`RESULT RiverLake: OK` 且 16 断言全 PASS。

## 5. 记录段差异判定（REQ-RIV-5，含阴性对照）

- [x] `ranger.idx` 偏移 `[836, 59986, 107296, 111664, 124720, 124870]`，`ranger.grp` 124870B
- [x] 4 段全部整除：Person 59150/182=**325**、Thing 47310/190=**249**、
      Scene 4368/52=**84**、Wugong 13056/136=**96**、Shop 150/50=3
- [x] 对照基线 320/200/84/93 → Person +5、Thing +49、**Scene ±0**、Wugong +3
- [x] 边界记录可读：`Person[324]="袁冠南"`、`Thing[248]="玄虛刀法"`、
      `Scene[83]="圣堂"`、`Wugong[95]="玄虛刀法"`
- [x] `PersonNum` 由 `jymain.lua:1747` 索引推导，无硬编码 325
- [x] **阴性对照成立**：Scene 记录数 84 = 基线 84 ⇒ 改用**内容**证明：
      `Scene[0]` 盛京(≠胡斐居)、`Scene[1]` 河洛客棧(=)、`Scene[2]` 靈鷲宮(≠雲鶴崖)、
      `Scene[83]` 圣堂(≠聖堂) → 3/4 不同

**Blast Radius**：只读。
**DoD**：4 段整除余数=0 且 Scene 阴性对照有 3 条内容差异证据。

## 6. `hdgrp` 差异判定（REQ-RIV-6，判据第 6 次）

- [x] `hdgrp.idx` = 1008 字节 = **252** 条目（基线 115，+137）
- [x] 索引驱动：`PicLoadFile` 用 `idxlen/4`（`lib_love.lua:437`）
- [x] 无固定计数常量（`grep` 无 115/`hdgrpNum`/`HEADNUM`）
- [x] `format_spec` `gaps=0` 佐证
- [x] 判定：内容差异（判据外推链 125/129/173/178/204/**252** 六次一致）

**Blast Radius**：只读。
**DoD**：三条判据同时成立。

## 7. `eft` 差异判定 + 范围外缺陷记录（REQ-RIV-7 / REQ-RIV-11）

- [x] `eft.idx` = 3684B = **921** 条目（基线 714，+207）；`eft.grp` 1078261B
- [x] 偏移单调不减；`idx[-1] == eft.grp` 字节数（1078261 == 1078261）
- [x] `PicLoadFile` 全索引驱动 ⇒ `eft` 维度内容差异，零引擎改动
- [x] **范围外发现**：`CC.Effect`（`jyconst.lua:439`）硬编码 **53** 项
- [x] 20/20 MOD 实测 eft id 上界 → **7/20 越界**：
      RiverLake 10 / books 2 / awaken 1 / pineapple 62 / mingdong 136 /
      BookCalamity 296 / pig3dos 52
- [x] 语义关系确认：`list/effect.bin`=每效果帧数（RiverLake 70 项）；
      `eft.idx`=逐帧表（921）；3 MOD 的 `sum(effect.bin)==eft.idx` 精确相等
- [x] 权威来源：`reference/allmods/UPedit/UPedit.ini:80` → `Effect=list\effect.bin`；20/20 均有
- [x] pig3dos **另越自带 `effect.bin`**（85 vs 64 项）
- [x] 非致命性实测：`FrameN=15/StartEft=40`（`or 10` / `or 0` 回退，不崩溃）
- [x] **不修复**：`jyconst.lua` 属禁改路径；修复需改 20 MOD 审计分类 + 构建管线 ⇒ 独立 change

**Blast Radius**：只读（**未做任何代码改动**）。
**DoD**：`eft.idx` 三判据成立 + 缺陷 6 项证据齐备（清单/条数/权威来源/语义/非致命/修复路径）。

## 8. 额外战斗三重确认（REQ-RIV-8）

- [x] 产物 219 − 基线 92 = 差集 **127**
- [x] `diff.md` 提及 `fight*.grp` = 127，且 **set 逐个一致**（双向独有均为空）
- [x] `mod_audit` 中 219 个 `fight*.grp` 全部 `REQUIRED` / `in_product=true`
- [x] 配对检查：127 个 `.grp` 全部有对应 `.idx`（尺寸一致）
- [x] 抽样 5 场：`fight030`(93372B/96帧)、`fight123`(**0B**)、`fight155`(42858B/32帧)、
      `fight187`(66004B/44帧)、`fight218`(**0B**)
- [x] **0 字节发现**：44/127 为 0 字节，源/产物集合一致、127/127 尺寸相同 → ADR-007
- [x] 34/44 被 `Person[i]["头像代号"]` 实际引用（实测：文件缺失 0、0 字节 34）
- [x] 引擎优雅降级实测：`PicLoadFile` pcall=true、`PicGetXY` 返回 0（不崩溃）

**Blast Radius**：只读。
**DoD**：三重清单逐个一致 + 0 字节现象有源/产物/运行时三重证据。

## 9. 存档完好（REQ-RIV-9）

- [x] 源 `save/` 28 文件；产物 `mods/RiverLake/save/` 21 文件
- [x] 逐字节比对 **21/21 一致**（不一致 = 0）
- [x] 18 个源自带槽：`d1`~`d6`、`d11`、`r1`~`r6`、`r11`、`s1`~`s6`、`s11`
- [x] 6 个文件（`alldef.*`/`allsin.*`/`ranger.*`）转入 `data/`（非丢失）
- [x] 首次播种实测：`SeedSaveSlot(1)` → `save/r1.idx` == `mods/RiverLake/data/ranger.idx`
      （**≠** 基线 `data/ranger.idx`）；播种后清理

**Blast Radius**：`game/mods/RiverLake/save/**`（仅播种测试，已清理）。
**DoD**：21/21 逐字节一致 且 播种源为 MOD 自身 `ranger.idx`。

## 10. 空 WAV 容错（REQ-RIV-10）

- [x] 源 `sound/` 有 **28** 个 0 字节 WAV（`e72.wav`~`e98.wav`）
- [x] 产物 `sound` 计数 **170**（源 170），空文件数仍 28（原样保留）
- [x] `PlayWAV`（`lib_love.lua:602-621`）用 `pcall(love.audio.newSource, ...)` 包裹
- [x] 启动链路 10 帧无报错
- [x] 不补静音、不删除（保护「产物 = 源 + 格式转换」与音效 ID 索引）

**Blast Radius**：只读。
**DoD**：28 个空 WAV 原样进产物 且 `sound=170` 且运行不崩溃。

## 11. 原版零回归（REQ-RIV-12）

- [x] `lua tests/test_runner.lua` → **1842/1842 passed, 0 failed**
      （初版记 1622；缺陷 F 修复后为 1842，见下「代码改动汇总」）
- [x] `lua tools/mod_build.lua --verify-pascal` → `mismatches=0` PASS
- [x] `lua tools/mod_build.lua --all` → `20 mods, 0 build failures`
      （退出码 1 属既有设计：5 个 `annotated-problematic` 计入 `os.exit(1)`，
      见 `tools/mod_build.lua:1224-1226`；`build failures` 仍为 0）
- [x] `lua tools/mod_check.lua` → 20/20
- [x] `lua tools/mod_audit.lua --all` → `unclassified=0 bad_evidence=0`
- [x] `lua tools/mod_audit.lua --all --evidence` → `failed=0`
- [x] `lua tools/format_spec.lua --all` → `gaps=0`
- [x] 全 20 MOD `save/` vs 源 → **451 文件**不一致 = 0
      （初版记 341，为修复前统计口径；自愈重建后覆盖全部源 `save/` 文件）
- [x] `game/engine-love2d/**`、`game/engine-mud/**`、`game/script/jyconst.lua`、
      `reference/allmods/**` **零改动**

**Blast Radius**：只读。
**DoD**：全部门禁通过，四类禁改路径零改动。

---

## 代码改动汇总

**零引擎改动。** 「产物变化」是 `game/mods/RiverLake/**`（构建产物，gitignore）。

**唯一代码改动**：`game/tests/unit/test_mod_resources.lua` 新增
`TestModResources.restoreAllProductSaves()`（缺陷 F 修复）。
属允许路径（`game/tests/**`），**不触碰引擎/常量/参考数据**。

范围外发现两项（均只记录、不修复）：
1. `CC.Effect` 硬编码 53 项 vs 7/20 MOD eft id 越界（ADR-003）
2. 44 个 0 字节 `fight*.grp`（ADR-007）

### 缺陷 F（第 6 个工具缺陷，本轮发现并修复）

`test_mod_boot.testSaveLoadRoundTripWithMingdong` 写 `mods/mingdong/save/` 且仅在
正常结束时恢复；被中断（超时 kill / 断言抛错）后脏槽残留。runner 顺序中
`mod_resources`(16) 先于 `mod_boot`(21)，下次运行读到脏槽 → 4 条 mingdong 假失败。

修复：`test_mod_resources` 新增自愈式重建（按源包逐字节恢复 + 删除残留）。
测试数 1622 → **1842**（+220）为**覆盖扩充**（此前因文件缺失被 `else` 跳过的比对断言
恢复执行），非新增测试、非行为变更。
详见 verify change `design.md` ADR-002 与 `verification.md` §8。
