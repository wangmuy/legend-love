# TODO — Future Slices & Ideas

## 进度

- [x] **Slice 0c: 资源覆盖穷举审计（文件级 + 字段级）** — **完成**。把 DoD 从**抽样驱动**改为**穷举驱动**：判定范围由“源文件全集”决定，而非“人写的比对目标”。3 个子 change 全部实施并验证：
      - [x] **allmods-slice0c-file-inventory** — `tools/mod_audit.lua` 对 20 MOD 的 **11220 个源文件逐个归类**；`Σ(类别) == 11220` 且**未归类 == 0**（无兜底类别）。
            实测：`total=11220 in_product=9225 not_in_product=1995 unclassified=0 bad_evidence=0`。
            分类：REQUIRED 9145、REQUIRED_CONVERTED 80、LEGACY 68、DEAD_FILE 2、EDITOR_DUMP 1220、BUILD_INPUT 30、PLATFORM_ARTIFACT 12、PENDING 663。
            本轮发现并修复 4 个真实缺陷：`mod_check` 误扫 `_audit/`、`save/` 模板路径判定错、`resource/*.exe` 未归类、旧测试扫描范围过宽。
            [verification.md](../changes/allmods-slice0c-file-inventory/verification.md)
      - [x] **allmods-slice0c-format-spec** — `tools/format_spec.lua` 为每种二进制格式定义**无缺口字段表**；`Σ(字段区间) == 文件大小`。
            实测：`formats=12 checked=6773 gaps=0`（0 缺口 0 重叠）。
            发现 5 项真实数据特征：`war.sta` 记录数随 MOD 变化（110..438）、`dream/earth.002` 多 1 字节、RiverLake 28 个空 WAV、BookCalamity WAV 尾随 `LIST/INFO/ICMT`、3 个孤儿 fight 文件。
            [verification.md](../changes/allmods-slice0c-format-spec/verification.md)
      - [x] **allmods-slice0c-unneeded-evidence** — 每个 `needed=false` 给出**可机器校验的证据**（`code`/`strings`/`offset_table`/`format`/`external`/`manual`，附可执行 `cmd`）；产出权威文档 `MOD_RESOURCE_AUDIT.md`（11220 个机器锚点）。
            实测：`evidence: checked=17 failed=0`；1995 条未进产物记录全部有类别与证据；663 条 `PENDING` 正确用 `needed=nil` 区分。
            [verification.md](../changes/allmods-slice0c-unneeded-evidence/verification.md)
      依赖：Slice 0b（复用其 `ALIAS_MAP`/`IGNORE_DIRS` 作为判据依据）。
      Slice 2-18 应复用 `mod_audit.lua` 做本 MOD 的穷举验收。
      遗留 spike：`music/*.mid`（663 条 PENDING 的主体）—— MOD 音乐引用分析，需先做 spike 决策。

- [x] **Slice 0b: MOD 兼容地基补漏（资源类型）** — **完成**。2026-10 资源类型审计发现 Slice 0 地基存在验收漏洞（横跨 20 个 MOD），3 个子 change：
      - [x] **allmods-slice0b-smap-rename** — 构建期把 `sdx/smp/wdx/wmp` 映射为 `smap.*`/`wmap.*`。
            修复前每个 MOD 的场景地图（mingdong 4.5MB）+ 战斗地图（2.4MB）全部静默回退原版；
            修复后 20/20 MOD 产物含 `smap.*`/`wmap.*`，0 残留。运行时 `CC.SMAPPicFile` 条目数 = 4635（非原版 4129）。
            依据：`UPedit.ini` 的 `File2=resource\sdx,resource\smp,场景贴图` / `SMAPIDX=resource\sdx`。
      - [x] **allmods-slice0b-sound-fallback** — 构建期复制 `sound/`；`CC.ATKFile`/`EFile` 支持 MOD 前缀回退。
            修复前 MOD 音效全丢（mingdong 123 独有 + 52 同名被原版覆盖）；修复后 20/20 MOD 共 2002 个音效文件就绪。
      - [x] **allmods-slice0b-resource-classify** — 把「设计性回退 / 死参数 / 死文件 / 编辑器副产物」固化为 40 条可回归断言 + 权威文档（`DATA_FILES.md` §8）。
      根因：`diff.md` 是扁平集合比对，把 `+ sdx` 与 `- smap.grp` 报成两个无关增删项，看不见「改名」语义。
      验证：全量测试 364 → **449/449**；`mod_check.lua` **20/20**；`--verify-pascal` PASS；`--all` 0 failures。
      审计报告：`openspec/changes/allmods-slice0/reports/resource-type-audit.md`

- [x] **Slice 0: MOD 兼容地基（foundation）** — 完成（4 个子 change：spike / ini-parser / build-pipeline / data-fallback）
- [x] **Slice 1: 名动天下（kys-mingdong）端到端** — 完成（2 个子 change：mingdong-activate / mingdong-verify；5 个验收场景通过）
- [x] **Slice 2: 问题 MOD 专修（5 个 slice）** — 完成。对 `games.ini` 标注的 5 个问题 MOD      各建 1 个 slice，每个 slice 内按「逆向分析 → 确认修改 → 测试验证 → DoD 核实」组织 4 个 change：
      - [x] **allmods-slice-zheng（魏征传奇）** — 根因 = `save/ranger.idx` 描述的是 138596 字节存档，
            而非 114242 字节 `ranger.grp`。实现数据驱动的 `IdxIsConsistent`/`DetectLayout`/`RepairIdx`，
            构建期产出正确 idx `836,59076,97076,101444,114092,114242`。修复后 320/200/84/93，零 FFFD/控制符/空。
            DoD：`openspec/changes/allmods-zheng-dod/reports/dod.md`
      - [x] **allmods-slice-pig3dos（金庸水浒传dos版）** — 根因 = Person 无外号字段，@18 是 int16 stat；
            字符串判定由 `startsBig5Pair` 改为 `hasHighByte`。附带修复 23 个混合 ASCII+Big5 字段（此前泄漏原始 Big5 字节）。
            全 MOD 自检从 13/20 升到 20/20。DoD：`openspec/changes/allmods-pig3dos-dod/reports/dod.md`
      - [x] **allmods-slice-bookcalamity（天书劫）** — 根因 = Thing 字段内 CRLF（编辑器残留）；
            实现 `M.TrimControl` 剥离。DoD：`openspec/changes/allmods-bookcalamity-dod/reports/dod.md`
      - [x] **allmods-slice-awaken（真龙苏醒）** — 同源；特殊在于 r89 是**内部** CRLF（`七傷拳\r\n譜`）
            与 r187 孤立 `\r`，证明必须折叠而非仅剥尾。DoD：`openspec/changes/allmods-awaken-dod/reports/dod.md`
      - [x] **allmods-slice-loving（问情篇）** — 字段级零缺陷；根因 = `kysmod.ini` 的 `BEGIN_SCENE = -1`
            会让引擎索引 `JY.Scene[-1]` 崩溃。实现 `NON_NEGATIVE_KEYS` 守卫（负值不覆盖引擎默认）。
            DoD：`openspec/changes/allmods-loving-dod/reports/dod.md`
      - 全部修复**纯数据驱动**（无 MOD 名分支）；新增 `game/tests/unit/test_mod_encoding.lua`（41 断言）；
            全量测试 293 → **340/340**；`mod_check.lua` **20/20**；`--verify-pascal` PASS；`--all` 0 failures。

## 横向验证（全部 20 个 MOD）

- [x] **分辨率映射修正** — `kysmod.ini` 的 `RESOLUTIONX/Y` 不再覆盖 `CONFIG.Width/Height`；
      原版 C 引擎从不读 `kysmod.ini`，窗口固定 `1024x768`。
      报告：`openspec/changes/allmods-ini-parser/reports/resolution-mapping.md`
- [x] **全 MOD 适配自检工具** — `game/tools/mod_check.lua` + `mod_check_one.lua`；
      20/20 通过（布局 / 字符串 / 事件 / 存档 四项）。
- [x] **手动测试指南** — `openspec/changes/allmods-slice0/reports/mod-test-guide.md`；
      含 20 MOD 速查表（主角/起始场景/起始事件/独有事件数）、3 类测试路径、独有资源清单。
- [x] **修复 ASCII 字段存档覆盖 bug** — 构建期未转换（纯 ASCII）的字符串字段在写存档时
      会以原文当覆盖键并被定长字段截断（如 lyff 的 `AAA`）。新增合成键
      `!<seg>.<prefix>.<byteOffset>`（`ModData.SyntheticKey`）修复。
- [x] **确认 zheng 的布局异常根因是 idx 损坏（非源数据问题）** — 早先的"Thing 字符串在偏移 0-3/10-13"结论是      **idx 损坏造成的红鲱鱼**：zheng 的 `ranger.idx` 描述的是 138596 字节存档，而 `ranger.grp` 只有 114242 字节。
      用正确 idx 解码后 zheng 为 100% 标准布局（320/200/84/93，零 FFFD）。已由 `allmods-slice-zheng` 修复。
- [x] **修复 CP950 扩展码位缺失（构建期 bug）** — `mod_big5_trad.lua` 由 plain big5 生成，
      缺 42 个 CP950 码位（`f9xx` + `a3e1`），导致 14/20 MOD 共 87 个字符串字段出现 U+FFFD
      （如 `恒山掌門` → `�山掌門`）。追加 42 码位（13710 → 13752）后 19/20 MOD 归零。
      回归测试：`testBig5TableCoversCp950Extensions` / `testDecodeBig5Cp950Extension`。
      报告：`openspec/changes/allmods-encoding-convert/reports/encoding-reverse.md` 附录。

## 剩余 MOD slice 清单（18 个）

排序由 Slice 0 的数据差异报告（`game/mods/<mod>/diff.md`）驱动。排序依据 = 数据形态与基线
（kys-pascal）的距离：**hdgrp 条目数**（决定头像/贴图加载路径，是最大的适配变量）为主，
**fight 数量**（战斗数据规模）为辅。距离越小越先做。

> 注：Slice 1 已完成选定的 MOD 为 **kys-mingdong（名动天下）**——其 hdgrp 条目数与基线完全一致
> （115），适配风险最低；fight 数偏大（267）但不影响引擎数据形态。

### 第 1 梯队：与基线同形（hdgrp 115，fight ≈92）——最易，先做

- [x] **kys-SweeOan（瑞安群侠传）** — hdgrp 115 / fight 92，与基线完全同形
      **已完成**（Slice 2）：零引擎改动通过全部验证。构建 `events=1018`；穷举 `total=334 unclassified=0`；
      字节级 `gaps=0`；启动链路 `RESULT SweeOan: OK`（王小石/衛悲回/伊小深）。
      **本 slice 发现并修复跨 20 MOD 的数据销毁缺陷**：`mod_check_one.lua` 会删除产物 `r1.grp`。
      报告：[sweeOan-verify.md](../changes/allmods-sweeOan-verify/reports/sweeOan-verify.md)
- [x] **kys-stronger（威力加强版）** — hdgrp 115 / fight 92，与基线完全同形
      **已完成**（Slice 3）：零引擎改动通过全部验证。构建 `events=1018 talk=3727`；穷举 `total=335 unclassified=0`；
      字节级 `gaps=0`；启动链路 `RESULT stronger: OK`（韋大寶/胡斐/程靈素）。
      **本 slice 修复 2 个工具缺陷**：(1) `mod_audit.lua` 对 `kysmod.ini` 的 `in_product` 误判（+ 与代码矛盾的证据文本）；
      (2) `test_mod_boot.lua` 销毁产物 `r1.grp`（与 Slice 2 的 `mod_check_one` 同源）。
      报告：[stronger-verify.md](../changes/allmods-stronger-verify/reports/stronger-verify.md)
- [x] **kys-lostbook（失传天书-越女剑）** — hdgrp 115 / fight 97，与基线同形（内容更多）
      **已完成**（Slice 4）：零引擎改动通过全部验证，**未发现缺陷**。构建 `events=1071 talk=3181`；
      穷举 `total=342 unclassified=0`；字节级 `gaps=0`；启动链路 `RESULT lostbook: OK`（金迷/胡斐/程靈素）。
      内容差异：kdef 1071 vs 1018、fight 97 vs 92（多 5 场：`fight039`~`042`、`fight052`）、talk 3181 vs 2977。
      **补充验证「首次存档播种」路径**：源无 `r1.grp`，首次 `SaveRecord(1)` 从 `ranger.idx` 播种。
      报告：[lostbook-verify.md](../changes/allmods-lostbook-verify/reports/lostbook-verify.md)

> **第 1 梯队收官**（与基线同形 3 个 MOD 全部完成，零引擎改动）：
> SweeOan（Slice 2，发现 1 个工具缺陷）→ stronger（Slice 3，发现 2 个）→ lostbook（Slice 4，0 个）。
> 印证「同形 ≠ 零问题」：数据同形但工具链仍有缺陷，逐文件穷举 + 全量回归才能暴露。

### 第 2 梯队：hdgrp 略增（125~129）

- [x] **kys-HeavenSword（倚天剑）** — hdgrp **125** / fight 93，首个 hdgrp ≠ 115 的 MOD
      **已完成**（Slice 5）：零引擎改动通过全部验证。构建 `events=1066 talk=3315`；
      穷举 `total=335 unclassified=0`；字节级 `gaps=0`；启动链路 `RESULT HeavenSword: OK`（楊千葉/胡斐/程靈素）。
      **关键验证**：`hdgrp` 为**索引驱动**加载（`PicLoadFile` 用 `idxlen/4`，无固定计数常量），
      125 条目为内容差异 —— 判据可**外推到第 2~5 梯队全部** hdgrp ≠ 115 的 MOD。
      **本 slice 发现并修复第 4 个工具缺陷**：`mod_check_one.lua` 的 `SLOTS` 仅列 `r1.*`，
      但 `SaveRecord(1)` 还写 `d1.grp`/`s1.grp` → 销毁 20 个 MOD 的这两个槽（`r1.grp` 缺陷的第三次遗漏）。
      回归测试强化为「比对源 `save/` 全部文件」。
      报告：[heavensword-verify.md](../changes/allmods-heavensword-verify/reports/heavensword-verify.md)
- [x] ~~kys-zheng（魏征传奇）⚠ games.ini 标注"好像不太正常"~~ — hdgrp 126 / fight 92
      **已完成**：根因是 idx 损坏（非布局），见 `allmods-slice-zheng`
- [x] ~~kys-loving（问情篇）⚠ games.ini 标注"好像不太正常"~~ — hdgrp 128 / fight 107
      **已完成**：根因是 `BEGIN_SCENE = -1`，见 `allmods-slice-loving`
- [x] **kys-GodsDevils（天龙八部）** — hdgrp **129** / fight 92（含独立 item/ PNG 目录，已确认引擎不读）
      **已完成**（Slice 6，第 2 梯队收官）：零引擎改动、**零代码改动**通过全部验证。
      构建 `events=1123 talk=4640`；穷举 `total=615 unclassified=0`；字节级 `gaps=0`；
      启动链路 `RESULT GodsDevils: OK`（蝦米/胡斐/程靈素）。
      **关键验证 1**：`hdgrp` 129 差异 —— Slice 5 判据**首次外推成功**（2 个 MOD 结论一致）。
      **关键验证 2**：**279 个 `EDITOR_DUMP`** PNG（`head/` 79 + `item/` 200）有 4 条机器可复核证据
      （`IGNORE_DIRS` + 引擎 0 引用 + 打包格式 + 审计规则），产物中不存在。
      **关键验证 3**：**6 个源自带存档**（`d1`/`d2`/`r1`/`r2`/`s1`/`s2`）在全量测试后完好
      —— 缺陷 D 修复持久性验证通过。
      **本 slice 零缺陷**。
      报告：[godsdevils-verify.md](../changes/allmods-godsdevils-verify/reports/godsdevils-verify.md)

### 第 3 梯队：hdgrp 170~210

- [x] **kys-pig（小猪闯江湖）** — hdgrp **173** / fight **137**（+45 额外战斗，本 epic 目前最多）
      **已完成**（Slice 7，第 3 梯队第 1 个）：零引擎改动、**零代码改动**通过全部验证。
      构建 `events=1288 talk=4123`；穷举 `total=440 unclassified=0`；字节级 `gaps=0`；
      启动链路 `RESULT pig: OK`（小小豬/胡斐/程靈素）。
      **关键验证 1**：`hdgrp` 173 差异 —— Slice 5 判据**第 3 次应用成功**（125/129/173 结论一致）。
      **关键验证 2**：**45 场额外战斗**三重确认（`diff.md` + 产物 137 + 审计 `REQUIRED`）。
      **关键验证 3**：**9 个源自带存档**（`d1`~`d3`/`r1`~`r3`/`s1`~`s3`）全量测试后完好
      —— 缺陷 D 修复**完整性**验证通过（含 `d2`/`d3`/`r2`/`r3`/`s2`/`s3`）。
      **本 slice 零缺陷**。
      报告：[pig-verify.md](../changes/allmods-pig-verify/reports/pig-verify.md)
- [x] **kys-lyff（刘亦纷飞版）** — hdgrp **178** / fight **138**（+46 额外战斗，本 epic 最多）
      **已完成**（Slice 8，第 3 梯队第 2 个）：零引擎改动。
      构建 `events=1358 talk=5655`；穷举 `total=425 unclassified=0`；字节级 `checked=242 gaps=0`；
      启动链路 `RESULT lyff: OK`（AAA/胡斐/程靈素）。
      **关键验证 1**：本 epic **首个记录数差异 MOD**（326 人物段，`59332 = 326×182`，
      边界 `Person[325]` = 枯榮/南帝 有效）—— 判据统一原则：索引驱动 + 无固定计数 +
      字节全覆盖 + 边界有效 = 内容差异（零引擎改动），可外推第 4~5 梯队。
      **关键验证 2**：**`isStringField` 跨 MOD 工具修复**（REQ-LYF-0）：纯 ASCII 文本被
      `hasHighByte` 守卫误判为数值槽，修复 5 MOD 6 字段（lyff `AAA`、HeavenSword
      `killer-G`、GodsDevils `123`、ptt `PTT`、dream `------`×2）；重建 8 MOD；
      回归测试 +1（1612 → 1613）。
      **关键验证 3**：46 场额外战斗三重确认；`hdgrp` 178 判据**第 4 次应用**（125/129/173/178）。
      报告：[lyff-verify.md](../changes/allmods-lyff-verify/reports/lyff-verify.md)
- [x] **kys-ptt（PTT）** — hdgrp **204** / fight **162**（+70 额外战斗，本 epic 最多）
      **已完成**（Slice 9，第 3 梯队收官）：零引擎改动、**零代码改动**。
      构建 `files=362 saves=21 sound=78 events=1229 talk=5689`；穷举 `total=596 unclassified=0 bad_evidence=0`
      （= 源文件数 596）；字节级 `formats=12 checked=317 gaps=0`；
      启动链路 `RESULT ptt: OK`（鄉民/卓不凡/高昌迷宮地圖，16 断言）。
      **关键验证 1**：**本 epic 首个 4 段记录数全异 MOD**（385/214/90/108 vs 320/200/84/93，
      段长全部整除 70070=385×182 / 40660=214×190 / 4680=90×52 / 14688=108×136 / 150=3×50；
      边界 hint `P0489`/`N0448`/`T0395`/`T20395`/`TD0395`/`S0088`/`W0107` 有效）——
      统一判据**第 2 次应用**（lyff 1 段 → ptt 4 段全异）。
      **关键验证 2**：`hdgrp` 204 判据**第 5 次应用**（125/129/173/178/204 五次一致）。
      **关键验证 3**：**70 场额外战斗**三重确认（`diff.md` 140 项 + 产物 162 + 162 全 `REQUIRED`），
      Contract F 清单与实测差集**精确一致**（70/70）；抽样 5 场复核。
      **关键验证 4**：**18 个源存档槽**（本 epic 最多）21/21 逐字节一致；
      首次把「基准独有」拆为 4 类：**在 save/ 9 + 首次播种 9 + 回退原版 2 + 死文件 1 = 21**
      （9 个 `rN/dN/sN.idx` 源不存在，靠 `SeedSaveSlot` 从 `data/ranger.idx` 派生，已实测）。
      **关键验证 5**：**105 个 `eft/` PNG = `EDITOR_DUMP`**，4 条机器可复核证据。
      **关键验证 6**：收尾时把 Slice 8 的 `isStringField` 从**裸高位测试**加固为
      「高位字节须成对且全 Big5 可解码」（与 `DecodeBig5` 能力镜像），剔除
      `\xff\xff\xff\xff` / 截断 Big5 首字节等假阳性 —— 对真实数据**逐字节 no-op**
      （20/20 `ranger.str` md5 不变）；新增 9 条回归断言（测试 **1613 → 1622**）。
      **本 slice 零缺陷**。
      报告：[ptt-verify.md](../changes/allmods-ptt-verify/reports/ptt-verify.md)

### 第 4 梯队：hdgrp 250~300

- [x] **kys-RiverLake（再战江湖）** — hdgrp **252** / fight **219**（+127 额外战斗）
      **已完成**（Slice 10，第 4 梯队开场）：零引擎改动。
      构建 `files=478 saves=21 sound=170 events=1232 talk=8015`；
      穷举 `total=699 in_product=666 not_in_product=33 unclassified=0 bad_evidence=0`（= 源文件数 699）；
      字节级 `formats=12 checked=413 gaps=0`；启动链路 `RESULT RiverLake: OK`
      （茲/袁冠南/玄虛刀法/圣堂，16 断言）；记录段 325/249/84/96（段长全整除）。
      **关键验证 1**：**Scene 阴性对照首次正式化** —— Scene 段 84 = 基线 84，
      故「记录数相同」不能作内容已加载证据；改用内容证明
      （`Scene[0]=盛京`/`Scene[2]=靈鷲宮`/`Scene[83]=圣堂` vs 基线 `胡斐居`/`雲鶴崖`/`聖堂`，
      `Scene[1]` 两边均 `河洛客棧` 属 MOD 保留原版）。3/4 不同 ⇒ 内容差异。
      **关键验证 2**：`hdgrp` 252 判据**第 6 次应用**（125/129/173/178/204/252 六次一致）。
      **关键验证 3**：**127 场额外战斗**三重确认；**首次发现 44/127 为 0 字节** ——
      源↔产物 127/127 尺寸一致、源0 集合 == 产物0 集合、**34/44 被 `Person["头像代号"]` 引用**、
      `PicLoadFile` pcall=true / `PicGetXY` 返回 0（优雅降级）⇒ 保留不删（破索引语义）、不补（伪造）。
      全域 0 字节 fight：pineapple 115 / RiverLake 44 / ptt 7 / books 2 / loving 2。
      **关键验证 4**：21 项「基准独有」四类定性，**首次引入第 4 类「死文件」**：
      在 save/ 9 + 首次播种 9 + 回退原版 2（`thing.*`）+ **死文件 1（`allsinbk.grp`）** = 21。
      死文件判据 = `CC.TempS_Filename` 传入 `LoadSMap` 但 `tmpfilename` 形参**零引用**
      （`lib_love.lua:890` grep 仅 1 处命中=签名）—— 本 epic 首个
      「路径被引用 ≠ 内容被使用」样本。
      **关键验证 5（范围外缺陷，只记录不修复）**：`CC.Effect` 硬编码 53 项
      （`jyconst.lua:439`）vs **7/20 MOD** eft id 越界（RiverLake 10 / books 2 / awaken 1 /
      pineapple 62 / pig3dos 52 / mingdong 136 / BookCalamity 296）。
      权威来源 `list/effect.bin`（int16 每效果帧数表，`UPedit.ini:80`），
      `sum(effect.bin)==eft.idx` 3 MOD **精确相等**（RiverLake 921 / BookCalamity 2857 / pineapple 1378）。
      非致命（`or 10`/`or 0` 回退，`eft=69 → framenum=15/starteft=40` 不抛错）。
      不修复理由：`jyconst.lua` 禁改 + 需改 20 MOD 审计分类/构建管线，属独立 change。
      **关键验证 6**：**缺陷 F = 第 6 个工具缺陷**（已修复）。
      `test_mod_boot` 写 `mods/mingdong/save/` 仅正常结束时恢复，被中断则脏槽残留；
      runner 顺序 `mod_resources`(16) 先于 `mod_boot`(21) ⇒ 4 条假失败。
      修复 = `test_mod_resources.restoreAllProductSaves()` 自愈式按源包重建（幂等）。
      测试 **1622 → 1842**（+220 = 覆盖扩充，非新增断言）。
      **关键验证 7**：28 个 0 字节 WAV（`e72`~`e98`）原样保留，`pcall` 容错。
      报告：[riverlake-verify.md](../changes/allmods-riverlake-verify/reports/riverlake-verify.md)

- [x] **kys-Dragon（苍龙逐日）— hdgrp 267 / fight 209** ✅ Slice 11 已完成
      **构建**：`data files=458 saves=21 sound=80 events=1087 talk=4020`
      **审计**：`total=811 in_product=555 not_in_product=256 unclassified=0 bad_evidence=0`
      （REQUIRED 550 / REQUIRED_CONVERTED 4 / LEGACY 5 / DEAD_FILE 1 / EDITOR_DUMP 220 /
      BUILD_INPUT 2 / PENDING 29，Σ=811）
      **格式**：`formats=12 checked=535 gaps=0`
      **启动**：`RESULT Dragon: OK`，16/16 PASS（589/237/106/114，2109 字段，无 U+FFFD/控制符）
      **diff.md**：双向 set 相等 —— MOD 独有 **254/254**、基准独有 **25/25**，双向差集 `[]`
      **关键验证 1**：`hdgrp` **267**（`hdgrp.idx` 1068B ÷ 4），索引驱动判据第 7 次应用，
      外推链 125/129/173/178/204/252/**267**，无固定计数常量，`gaps=0`
      **关键验证 2**：`ranger.idx` offsets `[836,108034,153064,158576,174080,174230]`，
      段数 `(589,237,106,114,3)` 余数全 0，**四段全部异于基线**（判据第 4 次应用）
      **关键验证 3**：Scene 内容负对照（第 5 次应用）—— Dragon `[2]=雪山` vs 基线 `云鶴崖`，
      记录数同为 106 但内容不同 ⇒ 记录数相等 ≠ 内容相同
      **关键验证 4**：`fight101/102` **数据仍引用但资源缺失**（588/589 有头像代号，
      引用 101/102 各 1 条）—— 三级降级实测：缺失 → `PicGetXY` 全 **(0,0)**，
      正对照 `fight103` → **33×63/74×67/74×70/72×69**，两者 `pcall` 均 true。
      判为 MOD 作者侧数据不一致，不补文件、不改代号。
      （⚠ `PicGetXY` 裸调会抛 `lib_love.lua:462`，不可作降级证据）
      **关键验证 5**：`war1.sta` 双判定不矛盾 —— `66030B÷186=355` 记录，源=产物(md5 同)，
      基线不存在，`CC.WarFile` 只 `war.sta`，`grep -rn "war1"` → **0 命中**。
      「新增但不用」；与 RiverLake `allsinbk.grp`（「回退到的死文件」）本质不同。
      **关键验证 6**：`head/` **220** PNG = EDITOR_DUMP（同族第 3 次，GodsDevils 279/ptt 105）
      **关键验证 7**：`kysmod.ini` 10 项 `nil→有值`（MaxLevel 60/MaxHP 999/MaxMP 9999/
      MaxPhysicalPower 100/MaxItemAmount 200/ItemBeginPic 4131/MaxWeaponMatch 7/
      MinKnowledge 80/LifeHurt 10/ExpRate 1）。**两处修正**：`CC.LIFE_HURT` 不存在，
      正确名 `CC.LifeHurt`（`mod_ini.lua:187`）；`CC.MoneyID` 基线已定义 174，属伪证据已剔除。
      **3 条精度发现（非缺陷）**：① `not_in_product=256` ≠ 物理缺失（4 项物理存在
      `name.grp`/`name.idx`/`talkutf8.txt`/`war1.sta` + 252 真缺）；
      ② `cloud/title/open/end` 6 文件 Lua 引擎**无运行时消费者**（4 类 0 命中，
      `end.png` 唯一命中读的是基线 `pic/end.png`，md5 不同），`BY_KIND` 兜底归类；
      ③ `name.*` = `talk.*` 副本（md5 `4c41c044…`/`1a0c74ab…`）。
      **缺陷 0**（A~F 六个历史缺陷在本 MOD 未复现或已修复）。
      **唯一文档口径修正**：门禁 7「451 文件不一致 = 0」表述错误 →
      实测 **430 逐字节一致 + 21 设计内转换**（`ranger.grp`×20 Big5→UTF-8+hint、
      `ranger.idx`×1 zheng 经 `RepairIdx` 重建），**真实问题 0**。
      报告：[dragon-verify.md](../changes/allmods-dragon-verify/reports/dragon-verify.md)
- [x] kys-pineapple（再破菠萝）— hdgrp 300 / fight 154
      **已完成**（Slice 12，`allmods-pineapple-activate` + `allmods-pineapple-verify`）
      ⚠ 口径修正：`Person 720` 为全 20 MOD **第 2**（BookCalamity 800 / awaken 720），
      `ranger.grp` 229680B 亦**第 2**（BookCalamity 313242，基线 136412）；
      真正第 1 的维度是**零字节 fight 115**。
      **构建**：`data files=348, saves=30, sound=109, events=1068, talk=3596`
      **审计**：`total=529 in_product=484 not_in_product=45 unclassified=0 bad_evidence=0`
      （REQUIRED 479 / REQUIRED_CONVERTED 4 / LEGACY 5 / BUILD_INPUT 2 / PENDING 39，合计 529 = 源文件数）
      **格式**：`formats=12 checked=289 gaps=0`
      **启动**：`RESULT pineapple: OK`，16/16 PASS，2764 字段 0 损坏
      `PERSON=720 THING=344 SCENE=118 WUGONG=174 HERO=蘿卜大`
      **关键验证 1**：`ranger.idx` 偏移 `[1860,132900,198260,204396,228060,228210]`，
      `ranger.grp`=229680B，段长 `(720,344,118,174,3)` 余数全 0，**四段全部异于基线**
      （基线 320/200/84/93）。`131040/720=182` ⇒ 运行时 `CC.PersonSize=182`
      （**非** `jyconst.lua` 源码的 202，由 `ranger.idx` 段长动态推导）。
      **关键验证 2**：边界值 + 基线负对照 —— `Person[0]` 徐小俠→蘿卜大、
      `Thing[0]` 醉生梦死酒→小续命丹、`Scene[0]` 胡斐居→許昌、`Scene[2]` 云鶴崖→兵營
      （判据第 6 次应用）。**字段名坑**：`Person`/`Thing`/`Scene` 用 `名称`，
      `Wugong` 用 `名稱`；`头像代号` 在 offset **2**（非 0）。
      **关键验证 3**：**零字节 fight 115 个全部溯源为源文件 0B** ——
      `产物零字节=115 / 源中找不到=0 / 源也0B=115 / 源非0B=0`
      ⇒ `mod_build.lua` 忠实复制，**非构建缺陷**。
      三分支实测 `ZERO_BYTE 115 / OK 36 / FILE_MISSING 0`（pcall 全 true）：
      ZERO_BYTE 走 `getPic` 索引缺失（`lib_love.lua:270`，idx 表仅 1 项），
      与 Dragon `FILE_MISSING`（`FileLength=-1` → `:436` 早退 → `:264` 开文件失败）**本质不同**。
      **`fight072`（57822B）是 `fight016`~`fight131` 零字节区间内的唯一非零例外**
      （71=0B ZERO_BYTE / **72=57822B OK 79×60** / 73=0B ZERO_BYTE）⇒ 零字节非区间一刀切。
      零字节 ∩ 被引用（`头像代号` offset2，共 151 个，≤299）= **115**，未引用 = **∅**
      ⇒ 本 MOD **无 FILE_MISSING 实例**。
      **关键验证 4**：**`diff.md` 存在结构性盲区**（首个量化该盲区的 MOD）——
      只报「基线无此名」，**漏掉 90 处同名异容改写**。
      四象限：`A 同名同容 2 / B 同名异容 90 / C 独有 62 / D 零字节 115`，
      自洽 `A+B=92`（基线 fight 数）、`A+B+C=154`、`D∩B(76)+D∩C(39)=115`。
      21 条基线独有 = **18 存档槽改道 + 3 模板回退 + 0 真删除**
      （`thing.*`/`allsinbk.grp` 源中无，`ModData.Resolve` 回退基线且 EXISTS
      —— `thing.grp` 345600B / `thing.idx` 800B / `allsinbk.grp` 4128768B）。
      **不得**表述为「MOD 删除了 21 个基线文件」。
      **关键验证 5**：`CC.Effect` 项数**必须用 `pairs` 计数** —— `#CC.Effect` 返回 52，
      真实键 `0..52` = **53 项**。`武功动画&音效` max=83，越界判据 `eft>52`，
      实测 **62 条 / 28 个不同值（53..83）**，占比 62/174=**35.6%**（7/20 越界 MOD 中最严重）。
      退化**饱和**：`eft=52→framenum 7/starteft 705`，`eft=53` 与 `eft=83` **结果相同**
      （`framenum 10/starteft 712`），pcall 全 true，不崩溃。
      **不修复**：修复点在 `game/script/jyconst.lua`（四禁改路径）+ 需提升 `list/effect.bin`。
      **关键验证 6**：`kysmod.ini` 10 项 `nil→有值`（MaxLevel 99/MaxHP 9999/MaxMP 9999/
      MaxPhysicalPower 100/MaxItemAmount 456/ItemBeginPic 3753/MaxWeaponMatch 58/
      MinKnowledge 80/LifeHurt 10/ExpRate 1）。`CC.MoneyID` 174→342 属取值变化，仅辅助。
      **关键验证 7**：`name.*` **≠** `talk.*`（pineapple md5 全部不同：
      `name.grp d7ea262b…` vs `talk.grp e2b3cd05…`；尺寸 152082 vs 152098）
      ⇒ 推翻「`name.*` 是 `talk.*` 副本」的跨 MOD 不变量，**仅 Dragon 成立**。
      `ranger.str` **hint 去重是设计**：119 处复用、真冲突 **0**；
      `record=-1` 是共享空 hint 占位（`mod_encoding.lua:943-957`）。
      `Person[719]` 空名是**源数据**（源 raw `20 00 00 00 00 00 00 00 00 00`，0x20 填充）。
      `icon.png`（9383B，md5 `8e80ebb4…`）= `BY_KIND` 兜底第 7 个成员，grep 0 消费者。
      **缺陷 0**（A~F 六个历史缺陷在本 MOD 均未复现或已修复）。
      报告：[pineapple-verify.md](../changes/allmods-pineapple-verify/reports/pineapple-verify.md)

### 第 5 梯队：hdgrp 350+ 或数据异常——收尾

- [x] ~~kys-awaken（真龙苏醒）⚠ games.ini 标注"不确定正不正常"~~ — hdgrp 353 / fight 220
      **已完成**：Thing 字段内 CRLF（含内部），见 `allmods-slice-awaken`
- [x] ~~kys-pig3dos（金庸水浒传 dos 版）⚠ games.ini 标注"不可能正常"~~ — hdgrp 412 / fight 180
      **已完成**：Person @18 是 int16 stat 非字符串，见 `allmods-slice-pig3dos`
- [x] ~~kys-BookCalamity（天书劫）⚠ games.ini 标注"好像有问题"~~ — hdgrp 373 / fight 326
      **已完成**：Thing 字段内 CRLF，见 `allmods-slice-bookcalamity`
- [x] kys-dream（笑梦游记）— hdgrp 484 / fight 122，**`kdef` 4569 全 20 MOD 第 1**
      **已完成**（Slice 14）：409/192/122/102，主角「隨小破」，`RESULT dream: OK`（16 断言）。
      `kdef 4569` = **全 20 MOD 第 1**（第 2 名 BookCalamity 1701，比值 2.69×）——dream 唯一真「第 1」；
      `hdgrp 484` = **第 2**（books 696 第 1）= 411 有效 RLE + 72 零长段（块 `(381,69)(480,3)`，头异常 0）。
      **`eft` 714 与基线 md5 逐字节相同（epic 唯一零改动）**：前 13 MOD 全部改过特效。
      **fight 增删并行（epic 首个删除象限）**：`92 − 41 删 + 71 增 = 122`，
      五分类 `A 2/B 49/E 41/C 71/D 0`，`A+B+E=92` ✅ `A+B+C=122` ✅
      ⇒ **`A+B=51≠92` 使「四象限」判据失效**，必须升级五分类。
      三种形态并存：books `89/3/0/86/2`、pineapple `2/90/0/62/115`、dream `2/49/41/71/0`。
      **记录段 5/5 全异**（epic 唯一，lyff 1 / ptt 4），CC 尺寸全标准值 ⇒ 只是记录数异。
      `diff.md` 156/105 **双向集合相等**；`removed 105` = 9 槽 `.grp` 改道 + 9 槽 `.idx` **按需播种**
      + 82 战斗回退 + 2 模板 + 3 死文件 + **0 真删除**（比 books 21 项大 5 倍）。
      孤儿 `fight23.idx`（有 idx 无 grp，源侧亦然）⇒ 打破「fight 必成对」假设。
      **`RepairIdx` 未触发**（源 `ranger.idx` 24B 完好，段长全整除）——zheng 仍是唯一案例。
      产物 `save/` **27** vs 源 **31**（4 项改道 `data/`，`ranger.grp` md5 异因编码转换）；
      `ranger.str` **763** 条（Σ 分段 243+343+82+95 = Σ 字段 513+82+168 = 763）。
      **0 内容缺陷 / 0 构建缺陷 / 0 工具缺陷**。详见 `allmods-slice14`。
- [x] kys-books（天书奇侠试玩）— hdgrp 696 / fight 178，**hdgrp 条目数全 20 MOD 第 1**
      **已完成**（Slice 13）：382/200/84/100，主角「古天奇」，`RESULT books: OK`。
      `hdgrp 696` = 474 有效 RLE + 222 零长段（RLE 重复帧，头异常 0）；
      `kdef 573` = **全 20 MOD 最少**（次少 1018）；`ranger.grp 126478` **比基线更小**（第 9/20）。
      fight 四象限 `A 89/B 3/C 86/D 2` 与 pineapple（`2/90/62/115`）**互为极端**：
      books 保留基线+新增（B 占比 3.3%），pineapple 改写存量（97.8%）。
      **epic 首个 `FILE_MISSING` 被引用实例**：4 个 NPC（風清揚/石中玉/段正淳/張召重）
      头像代号指向不存在的 fight 包，源与基线均缺 ⇒ MOD 原始缺陷，运行时 `PicGetXY` 返 `0,0` 不崩溃。
      `diff.md` 184/21 **双向集合相等**；`removed 21` = 13 槽改道 save + 5 槽缺席 + 3 模板回退 + 0 真删除。
      **0 构建缺陷**，5 类 MOD 原始缺陷不修。详见 `allmods-slice13`。
      （勘误：`name.grp` 实际出现于 BookCalamity / Dragon / pineapple / RiverLake 四个 MOD，`books` 未使用；
      详见 `openspec/changes/allmods-slice0/reports/resource-type-audit.md` §2.8）

> ⚠ 5 个标注 MOD 已在 Slice 2 全部修复；`lua tools/mod_build.lua --all` 仍会列出它们为
> annotated-problematic（REQ-BUILD-4 要求如实汇总 `games.ini` 标注），但 `mod_check.lua` 已 20/20 通过。

## Slice 2：5 个「有问题」MOD 深度逆向与修复（已完成）

每个 MOD 一个 slice，slice 内按 **逆向分析 → 确认修改 → 测试验证 → DoD 核实** 四步骤组织，
按 **zheng → pig3dos → bookcalamity → awaken → loving** 顺序完成。

| MOD | 根因（逆向结论） | 修复 | 端到端证据（独立进程真实启动） |
|-----|------------------|------|--------------------------------|
| **zheng** | `ranger.idx` 损坏（`idx[6]=138596 > grp=114242`）。**grp 本身 100% 标准布局**，此前「复合布局」是 idx 损坏造成的红鲱鱼 | `M.RepairIdx` 从文件大小反推一致 idx；产物 `data/ranger.idx` 写入修复值 | 320/200/84/93，主角「小蝦米」，扫描 1417 字段，**0 U+FFFD、0 控制符**（修复前 11+3） |
| **pig3dos** | Person `@18` 是 int16 stat 而非字符串；**且跳过字段后原始字节留在 .grp 被引擎当字符串读** | 判据改 `hasHighByte`；**跳过字段写入解析为 `""` 的 hint 中和槽位** | 607/242/133/202，主角「主角」，扫描 2275 字段，**0 控制符**（修复前 565） |
| **BookCalamity** | MOD 作者把换行粘进定长字段，Thing 段残留 CRLF | `M.TrimControl` 剥离尾部 + 折叠删除**内部** CR/LF | 800/550/139/398，主角「主角」，扫描 3787 字段，**0 控制符**（修复前 1285 处真 CR/LF） |
| **awaken** | Thing 段 6 字段含控制符，r89 是**内部** CRLF（`七傷拳\r\n譜`） | 同一 `M.TrimControl` | 720/237/153/163，主角「北辰月」，扫描 2467 字段，**0 控制符**（修复前 11 处） |
| **loving** | 字段级数据干净；`kysmod.ini` 的 `BEGIN_SCENE=-1` 导致 `JY.Scene[-1]` 崩溃 | `mod_ini.lua` 新增 `NON_NEGATIVE_KEYS` 守卫（负值不覆盖引擎默认） | 320/200/84/93，主角「莫言」，扫描 1417 字段，**0 缺陷**；`-1` 被忽略、正值仍生效 |

**验证基础设施**：
- `game/tests/unit/boot_one_mod.lua`：单 MOD **独立进程**真实启动链路（`lib.init → LoadRecord(0) → 10 帧`）
- `game/tests/mod_boot_harness.lua`：共享无头 harness（bit32 polyfill + love stub + format 容错）
- `tests/test_runner.lua mod_boot`：以子进程方式为 5 个 MOD 各跑一次（85 断言）
- `game/tests/unit/test_mod_encoding.lua`：45 断言（含 `testSkippedFieldNeutralisedForAllMods`）

**新增真实 bug 修复（本轮启动链路测试发现）**：跳过字段必须中和槽位，否则
`mod_check_one.lua` 与旁路表审计都看不见的 565 个控制符会漏到引擎。影响全 20 MOD 中
7 个有跳过字段的 MOD（ptt/pineapple/dream/HeavenSword/GodsDevils/lyff/pig3dos）。

## 原版移植缺陷修复（非 MOD 兼容范畴）

- [x] **重新开始后无动画无对话、画面像挂住（6e7471f）**：用户实测反馈，重新开始
      游戏、确认属性进入后完全没有动画和对话。
      **根因**：`framework/jymain_adapter.lua:101` 会给 `_G` 装严格元表，
      `__newindex` / `__index` 一律 `error("attempt read ... undeclared variable")`。
      **关键语义容易看漏**：只有「键已存在」的赋值才被放行；对不存在的键做
      `_G.X = ...` 依然触发 `__newindex` 并抛错。
      `df7adb1` 在 `AsyncGlobals.install()` **中段**新增了
      `_G.ShowSceneNameAsyncImpl = SceneNameAsync.Show`，该键此前不存在 → 裸赋值抛错。
      **后果之所以严重，因为它是「中段崩溃」**：该行**之前**的替换已生效
      （`WaitKey`/`ShowMenu`/`ShowMenu2`/`TalkEx`/`ShowScreen`/`lib.Delay`
      全换成异步版），抛错后 `install()` 中断、调用方
      `event_executor.oldCallEventCoroutine` 随之中断，
      **`AsyncGlobals.uninstall()` 永不执行**，全局函数停在「已替换」状态，
      开场事件（691）无法推进 → 画面完全静止。
      **修复**：`async_globals.lua` 改用 `rawset` 写入；`jymain.lua` 的
      `ShowSceneName()` 改用 `rawget` 读取（未注入时安全降级为 no-op）。
      **为什么先前自测没抓到**：测试里用 `rawset` 手工注入该全局，恰好绕过严格元表，
      掩盖了 bug。现补 `withStrictG()` 辅助，装上与 `jymain_adapter` 相同的严格元表跑用例。
      **新增 5 项测试**（`test_scene_name` 73 → 81）：`install()/uninstall()` 在严格
      `_G` 下不抛错、`install()` 用 `rawset` 注入成功、未注入时 `ShowSceneName()`
      静默跳过、已注入时正确转发、源码级断言两个文件不得对该全局裸赋值。
      **负向对照（3 项全部生效）**：退回裸赋值后报
      `attempt read write to undeclared variable ShowSceneNameAsyncImpl`，
      与用户实测报错文本完全一致。
      **真机验证**（LÖVE 11.5，真实 `startNewGame` 路径，菜单精确应答「是」）：
      | 判据 | 修复后 | 撤掉修复 |
      |---|---|---|
      | `startNewGame` | OK | ★ERROR★ `attempt read write to undeclared variable` |
      | 开场对话页数 | **1** | **0** |
      | `JY.Status` | 4（`GAME_SMAP`） | 4 |
      | 场景名 | 徐小侠居 | 徐小侠居 |
      撤掉修复时开场事件完全没执行，正是用户看到的「无动画无对话」。
      **同类隐患全仓库扫描**：14 处 `_G.*` 裸赋值中，5 处目标未被 `function` 定义
      （`EngineAPI`/`lib`/`bit32`×2/注释内示例），前者均在严格元表安装前创建，无残留隐患。
      全套测试 **2115/2115/0**，`gate_run_mod.sh` = `GATE_PASS`。


- [x] **小场景名称提示未移植**：原版进小场景在屏幕顶部中间显示场景名，任意键取消；
      LÖVE 版完全看不到。
      **根因（三层）**：
      ① `Init_SMap(1)` 内 `ShowScreen()` 已被 `framework/async_globals.lua:96` 替换为**空函数**
      （事件驱动下 `love.draw` 每帧自动 present），故画了也从未上屏；
      ② `GAME_SMAP.draw` 每帧无条件 `DrawSMap(0)` **全屏重绘**，在非 `draw` 回调里画的场景名
      必被下一帧覆盖；
      ③ `WaitKey()` 在 `async_globals` 下按 `EngineAPI.coroutine.isRunning()` 分流，而该判定
      `return coroutine.running() ~= nil` 在 **LuaJIT 主线程也返回 true**（返回主线程对象 +
      `ismain=true`），导致主线程误走异步分支。
      **修复（事件驱动：状态机子状态，非标志轮询）**：
      - `framework/state_machine.lua`：新增 `getCurrentSubStateContext()`；`pushSubState` 把
        `data` 放进子状态 `context`（原先丢弃，子状态拿不到自己的数据）。
      - `framework/game_states.lua`：`GAME_SMAP` 注册 `subStates.SCENE_NAME`
        （`enter` 读名称 / `update` 消费一次按键后 `popSubState` / `draw` 调 `DrawSceneName`）；
        `GAME_SMAP.installSceneNameHook()` 在 `registerAll()` 末尾把实现注入 jymain 的钩子；
        `GameStates.pushSceneNamePrompt(name)` 是唯一入口（协程内 `waitForKey` 挂起，非协程直接返回）。
      - `script/jymain.lua`：**不再持有任何提示状态**。`GetSceneName()` 取名称，
        `DrawSceneName(name)` 绘制，`ShowSceneName()` 经可注入的
        `SetSceneNameShowHook` 转发（`script/` 不依赖 `framework/`，严格 `_G` 下也读不到
        `GameStates` 这类模块 local）。空串/纯空白视为无名称。
      - `engine-love2d/engine_love2d.lua` + `tests/engine_test.lua`：
        `isRunning()` 改用 `coroutine.running()` 的第二个返回值 `ismain` 排除主线程。
      **为什么用协程而不是标志轮询（也不是子状态，见下条）**：
      与 `person_status_async.lua` 的既有样板一致——协程 `WaitKeyCoroutine()` 挂起，
      按键事件到来时由 `CoroutineScheduler:update` 唤醒（事件驱动，非轮询）；
      绘制由模块的 `draw()` 每帧完成；`InputManager.disableInput = true` 让
      `GAME_SMAP.update` 的 `lib.GetKey()` 返回 -1，行走逻辑自然停摆，
      **不存在「同一按键既关提示又走路」**。
      **几何与原版一致**：`DrawStrBox(-1, 10, 名称, C_WHITE, CC.DefaultFont)`。
      **真机实测（LÖVE 11.5，pascal MOD，真实 `switchState(GAME_SMAP)` → `Init_SMap(1)`）**：
      `子状态=SCENE_NAME`、`携带名称=河洛客棧`、白框 `x=435..588, y=10..43`
      （公式复算 `x=438..585, y=10..37` 吻合，差异为抗锯齿与字形外延）；
      顶部中间区域亮点 `232` → 注入按键后子状态 `nil`、亮点 `0`；
      **同一按键未触发走路**（人物坐标前后均为 `0,0`）。
      **负向对照（5 项，全部生效）**：
      ① 父状态 draw 在 `DrawSMap` 之前画场景名 → FAIL「父状态 draw 内不应出现 DrawSceneName」；
      ② 子状态 draw 漏掉 `DrawSceneName` → FAIL「SCENE_NAME 子状态的 draw 必须调用 DrawSceneName」；
      ③ `state_machine` 有子状态时不再 `return` → FAIL「提示期间父状态 update 不应被调用」；
      ④ 撤掉 `GAME_INIT` 定义 → FAIL「GAME_INIT 应在 _G 中定义」；
      ⑤ 恢复裸全局 `JY_D_Valld_Num` → FAIL「不应向 _G 泄漏 JY_D_Valld_Num」。
      **测试**：新增 `tests/unit/test_scene_name.lua`（**66 项**，刻意不调用 `LoadRecord`、
      手工构造最小 `JY`，对套件运行顺序免疫）；`test_engine_test` 增 2 条断言
      （含「主线程必须 false」，植回旧实现 → `expected false, got true`）。
      **注**：`game/active_mod.txt` 残留会让 `script_loader` 4 项测试失败——环境残留，
      跑全量前须 `rm -f game/active_mod.txt`。

- [x] **场景名提示「真机从主地图进客栈仍不显示」补修**（`80b0152` + `ba8572a` 之后的新发现）：
      前两次修复都只覆盖了「场景内跳转」和「直接调 `Init_SMap(1)`」两条路径，
      **真实玩法路径漏了**。
      **根因**：LÖVE 版 `GAME_MMAP.update` 检测到 `JY.SubScene >= 0` 时只做了
      `JY.Status = newState`，随后靠 `GAME_SMAP.enter` 里的 `Init_SMap(0)` 初始化场景。
      而原版 `Game_MMap` 在同一位置调用的是 **`Init_SMap(1)`**
      （`~/project/legend-mac-orig/bin/script/jymain.lua:430`）。
      `showname` 参数在迁移中被丢掉 → 从主地图走进任何小场景都静默走 `Init_SMap(0)`，
      场景名永远不出现。
      **修复**：`GAME_MMAP.update` 改为
      `EventBridge.getInstance():switchState(newState, { showname = 1 })`，
      `GAME_SMAP.enter(prevState, data)` 接住 `data.showname` 调 `Init_SMap(showname)`。
      用 `switchTo` 的 `data` 传递而不是在 `update` 里直接调 `Init_SMap(1)`，
      避免「先画一帧无名、下一帧才有名」的闪烁；同时删掉与新流程重复的
      `JY.Status = newState`（`EventBridge:switchState` 内部会同步 `JY.Status`）。
      **真机实测（LÖVE 11.5，pascal MOD，完全走真实玩法路径）**：
      切 `GAME_MMAP` → `Cal_EnterSceneXY()` 找到「河洛客棧」外景入口 `(359,228)` →
      主角置于该格 → 让 `GAME_MMAP.update` 自己跑 `CanEnterScene(359,228)=1`
      → `当前状态=4`、`JY.SubScene=1`、`子状态=SCENE_NAME`、`携带名称=河洛客棧`、
      白框 `x=435..588, y=10..43`、顶部中间亮点 `94`（真实字形，非 tofu 的 `233`）→
      注入按键后子状态 `nil`、亮点 `0`、人物坐标前后不变（同一按键未触发走路）。
      **踩坑记录（探针环境，非产品缺陷）**：
      ① 探针目录 `/tmp/snaptest` 起初没有 `simsun.ttf`，导致中文渲染成 4 个空心方框
      （tofu），一度误判为字体缺陷——补拷字体后正常；
      ② 刚进游戏时属性分配菜单仍挂着，`GAME_MMAP.update` 第一行
      `if MenuAsync.hasActiveMenu() then return end` 会吞掉全部逻辑，
      探针须先 `MenuAsync.clear()` 才能走到进场景分支。
      **负向对照（2 项，直接复现用户报的现象）**：
      ① 撤掉 `switchState` 的 `{showname=1}` 传参 → FAIL
      「GAME_MMAP 进子场景必须 switchState(newState, { showname = 1 })」；
      ② `enter` 里把 `Init_SMap(showname)` 写死成 `Init_SMap(0)` → 3 项 FAIL
      （含「应把 showname=1 传给 Init_SMap: expected 0, got 1」）。
      **测试**：`tests/unit/test_scene_name.lua` 当时增至 **84 项**（新增 6 项覆盖真实入口：
      源码断言 `switchState(..., {showname=1})`、`enter` 读 `data.showname` 且调
      `Init_SMap(showname)`；端到端用 `Init_SMap` 桩验 `showname=1/0/nil` 三种入参）。
      `bootHeadless()` 补 `GameStates.registerAll()`——不跑这步时
      `SetSceneNameShowHook` 为 nil，`ShowSceneName` 会静默跳过，正是真机
      「什么都没有」的隐患形状，测试必须覆盖到。
      （后续协程化重构时该套件整体重写为 73 项，见下一条。）

- [x] **场景名提示再重构：子状态 → 事件驱动协程**（`df7adb1`）：
      上一条的 `SCENE_NAME` 子状态实现虽然能正常工作，但入口是
      `GameStates.pushSceneNamePrompt` 里 `rawset(_G, "SetSceneNameShowHook", ...)`
      ——**自定义全局钩子变量**，与项目既有的解耦约定不一致：`framework/` 里
      其它所有「`script/` 需要调用框架能力」的场合（`WaitKey` / `ShowMenu` /
      `TalkEx` / `DrawStrBoxWaitKey` …）都走 `AsyncGlobals.install()` **覆写全局函数**，
      而不是注入钩子变量。
      **重构**：新增 `framework/scene_name_async.lua`，完全对齐
      `person_status_async.lua` 的样板：
      ① `Show()` 起协程置 `currentName` + `InputManager.disableInput = true`；
      ② 协程内 `InputAsync.WaitKeyCoroutine()` 挂起，按键事件由
      `CoroutineScheduler:update` 唤醒（**非轮询**）；
      ③ `draw()` 每帧渲染，由 `EventBridge:draw()` 调用且**排在
      `StateMachine:draw()`（含 `DrawSMap` 全屏重绘）之后**；
      ④ 退出时清 `currentName` 并恢复 `disableInput`。
      删除 `SCENE_NAME` 子状态、`pushSceneNamePrompt`、`installSceneNameHook`、
      `rawset(_G,"SetSceneNameShowHook",nil)`；改为 `AsyncGlobals.install()` 注入
      `_G.ShowSceneNameAsyncImpl`，并在 `GAME_SMAP.enter` 的 `showname==1` 分支
      兜底再注入一次（`AsyncGlobals.install` 只在事件脚本路径触发，
      主地图进场景时可能尚未装）。`script/jymain.lua` 的 `ShowSceneName()`
      仅转发该全局，未注入时空转。
      **测试**：`tests/unit/test_scene_name.lua` 重写为 **73 项**，含源码级断言
      （`EventBridge:draw` 真正调用而非注释、且排在 `StateMachine:draw` 之后；
      `scene_name_async` 用 `WaitKeyCoroutine` 且无手工轮询循环；
      `SetSceneNameShowHook` 与 `SCENE_NAME` 均已彻底移除）。
      **负向对照（3 项，全部生效）**：
      ① 去掉 `disableInput = true` → FAIL「提示期间必须 disableInput」；
      ② 注释掉 `EventBridge:draw` 里的 `SceneNameAsync.draw()` → FAIL；
      ③ 把 `SceneNameAsync.draw()` 挪到 `StateMachine:draw()` 之前 → FAIL
      「必须在 StateMachine:draw（含 DrawSMap）之后」。

- [x] **`lib.DrawStr` 的 `size` 参数从未生效**（`262130f`）：
      `engine-love2d/lib_love.lua` 的 `getFont(fontname)` 把字号硬编码为 20，
      缓存表 `fontTbl` 也只按文件名做键；`DrawStr` 收下 `size` 却没用它。
      另有 `engine-love2d/engine_love2d.lua` 的 `EngineAPI.render.text`
      包装丢掉 `fontname`（原版 `luafun.c:25` 是 `JY_DrawStr(x,y,str,color,size,fontname)`
      六参数全传）。后果：`CC.DefaultFont` 取 16 或 24 全部失效，游戏内所有
      文字（对话/菜单/场景名框）一律 20px。
      **修复**：`getFont(fontname, size)` 的缓存键改为 `fontname..":"..size`；
      无字体名时的内置字体也按字号分表（原单例 `defaultFont` → 表）；
      `size` 缺省值收敛为具名常量 `DEFAULT_FONT_SIZE = 20`；
      `DrawStr` 透传 `size`；`EngineAPI.render.text` 补回 `fontname` 形参与透传。
      **验证**：新增 `tests/unit/test_font_size.lua`（16 项，用可观测的
      `love.graphics` 探针断言 `newFont` 收到调用方字号、不同字号建不同缓存项、
      缺省回落 20、无字体名时按字号分表，并做源码级断言）。
      **真机 LÖVE 11.5 渲染量测**（同一段「河洛客棧」，统计墨迹包围盒）：
      `size=16 → ink=290 bboxW=63 bboxH=16`；`size=20 → ink=596 bboxW=78 bboxH=19`；
      `size=24 → ink=778 bboxW=94 bboxH=23`。把 `setFont` 退回硬编码 20 后
      三者完全相同（均 `ink=596 / 78x19`），恢复后重新变成三种结果，
      确认修复真实改变了渲染输出。

- [x] **顺带修复的两个既有缺陷**（同批）：
      ① `GAME_INIT` 常量**从未定义**（`script/jyconst.lua` 游戏状态区只有 `GAME_START..GAME_END`），
      而 `SetGlobal()` 会读它；非严格模式下静默得到 `JY.Status=nil`（初始化状态丢失），
      严格 `_G` 下直接报 `attempt read read to undeclared variable GAME_INIT`。
      → 补 `GAME_INIT = -1`（不与既有 0..7 冲突）。
      ② `script/jymain.lua:98` 把 `JY.D_Valid_Num` 误写成**裸全局** `JY_D_Valld_Num`
      （既漏 `JY.` 前缀、又拼错 `Valid`），导致真正的 `JY.D_Valid_Num` 从未被初始化，
      且向 `_G` 泄漏一个无意义变量。→ 改为 `JY.D_Valid_Num=0`。

## 已完成（Slice 0/1 期间）

- [x] **存档目录隔离**：MOD 存档写 `mods/<mod>/save/`，各 MOD 不共享/不读取彼此存档；首次保存自动从
      MOD `ranger.idx` 播种 `rN.idx`；未激活 MOD 时仍用顶层 `save/`（零回归）。
      实现：`ModData.SaveDir()`/`SeedSaveSlot()`、`RewriteConstants` 存档槽重定向、构建期 `save/` 拆分。

## 已确定但暂缓的事项

- [x] **存档/定义数据布局 + 编码适配** —— ✅ **已实施完毕**（初稿标「待实施」已过时）
      **实施落点**（实测）：
      1. **布局覆盖**——`framework/mod_data.lua:398` `ModData.MOD_SIZES`
         （`Person 182 / Thing 190 / Scene 52 / Wugong 136 / Shop 50`）+
         `:416` `ModData.MOD_STRINGS`（MOD 字段偏移表）+
         `:466` `ModData.ApplyLayout(CC)` 覆盖 `CC.*Size` 与重建 `*_S` 结构表。
         **在 `script/jyconst.lua` 尾部自动调用**（`ModData.RewriteConstants` 之后）。
         实测 dream：`CC.PersonSize=182`（原版 202）、`Person_S["姓名"]` offset=8 size=10。
      2. **编码适配**——`tools/mod_encoding.lua` 构建期 Big5→UTF-8 +
         `ranger.str` 旁路表（hint 定宽字段装不下 UTF-8 时运行时回填）。
         实测 dream：主角「隨小破」正确解码，**U+FFFD = 0**、控制符 = 0
         （`boot_one_mod.lua dream ...` 16 断言全 PASS）。
      3. **存档槽重定向**——`ModData.SaveDir()` + `SeedSaveSlot()`
         （实测 dream 播种 `r1/r2/r3.idx` md5 == `data/ranger.idx`）。
      ⚠ 初稿描述的 Q3「13104 字段截断」冲突**已由 `ranger.str` 旁路表方案解决**
      （见 `allmods-encoding-convert/reports/design-D-final.md`）。
      以下为原始逆向记录（保留备查）：
      MOD 的 `save/ranger.grp` 有两个叠加问题：
      1. **布局不同**：MOD 记录大小 = Person 182 / Thing 190 / Scene 52 / Wugong 136 / Shop 50，
         而引擎 `CC.PersonSize=202`/`ThingSize=260`/`SceneSize=62`/`WugongSize=146`/`ShopSize=30`（原版布局）。
         `LoadRecord` 直接用这些常量切分 → MOD 数据全错位。**这是独立于编码的硬阻塞。**
      2. **编码为 Big5**，引擎按 UTF-8 读 → 乱码。
      **权威布局来源**：`reference/allmods/UPedit/UPedit.ini` 的 `[R_Modify]` 段（UPedit 编辑器自带定义），
      字段：Person 姓名@8+10/外号@18+10；Thing 名@2+20/名2@22+20/说明@42+30；Scene 名称@2+10；Wugong 名称@2+10。
      **全 20 个 MOD 布局一致**（段长均整除 182/190/52/136）。
      ⚠ **Q3 冲突**：名称字段仅 10~20 字节，UTF-8 只能放 3~6 汉字 → 全 20 MOD 合计 **13104 个字段会截断**。
      且记录内无空闲区可加宽字段。需用户拍板方案（见报告 §4/§6）。
      发现于 Slice 1（mingdong 无头全启动链路），不影响 Slice 1 的 5 个验收场景。
- [x] 44 个历史"活跃"changes 的归档清理 —— ✅ **已完成零断链归档**
      **实测现状（2026-10-28 执行）**：`openspec/changes/` 活跃目录原 **128** 个，
      其中 `status: done` **87** 个（原记录「44 个」已过时，翻倍）。
      **执行策略（零断链）**：全仓扫描 `**/*.md` + `*.lua` + `*.sh` + `*.yml` + `*.json`
      的 `changes/<name>/` 引用，按是否被引用二分：
      - **68 个零引用 → 已归档**至 `openspec/changes/archive/2026-10-28-<name>/`
        （含 37 个历史非 allmods + 31 个 allmods）。
      - **19 个被引用 → 保留活跃**（归档会断链）：`allmods-*-verify`/`-dod`/`slice0c-*`/
        `allmods-ini-parser`（被 `game/framework/mod_ini.lua` 代码注释引用）、
        `slice-event-system-integration`/`web-worker-engine`（被 web-mud epic 引用）。
      **验证**：
      1. **断链数 = 0**（全仓 `changes/<name>/` 引用逐个 `os.path.isdir` 校验，含 archive 日期前缀回退）。
      2. 活跃 changes 128 → **59**；archive 8 → **76**。
      3. **8 门禁归档后复跑全绿**：1842/1842 测试、`--verify-pascal` PASS、
         `--all` 20/0、`mod_check` 20/20、`mod_audit` `unclassified=0 bad_evidence=0`、
         `format_spec` `gaps=0`。
      **说明**：`openspec` CLI 在本环境不可用（`which openspec` 无输出），
      归档按项目既有命名惯例 `<YYYY-MM-DD>-<name>/` 手工执行，内部结构原样保留。
## 字段/格式支持补全（2026-10-29 新增）

- [x] **Slice 0c 复核结论：字段级有真实注册遗漏，已补全（2026-10-28）**
      **发现**：`format_spec.lua` 初版 `FORMATS` 只注册 `ranger`，
      proposal 声明的 `save_grid`（`allsin`/`alldef`）与 `save/rN.*` **未实现**，
      导致 `save/` 的 451 个源文件中 **411 个从未做过字段级验证**。
      **进一步发现（2026-10-29）**：`allsin`/`alldef` 的**结构假设也是错的**——
      它们不是 offset 表（`verifyPair` 族），而是**定长 uint16 网格**：
      - `allsin.grp = 64×64×6×SceneNum×2`（pascal = 4,915,200 精确相等）
      - `alldef.grp = 200×11×SceneNum×2`（pascal = 440,000 精确相等）
      - 引擎证据：`lib_love.lua:898-904` `Byte.LoadToTable16` 定长直读，**不读 .idx**
      - 旧 `verifyPair` 给出的 `ok=true` 是**语义假通过**（把首 49152 B 当 header、
        末 786432 B 当"末项延伸"）
      **补全后**：`verifySaveGrid` 改用定长网格 + 两文件场景数交叉校验
      （`allsin` 24576 单元/场景 vs `alldef` 2200 单元/场景，同时凑出同整数概率极低）
      ⇒ `formats=14 checked=6838 gaps=0`，`cross_checked=40`。
      **负向对照**：字节偏差 ±1 / 半场景 / 零字节 / 错误维度公式 **全部被抓**（6/6 + 2/2）。

- [x] **`list/*.bin` 支持缺失（[REQ-LBIN-1~5]）** — change: `allmods-list-bin-support`（**已完成**）
      **现状实测**：
      1. 产物 `game/mods/pascal/data/list/` **为空**，源侧 6 个文件 → 构建器不搬
      2. 引擎侧（`script/`/`framework/`/`engine-love2d/`）对 `list/` 与 `.bin` 引用 **为 0**
      3. `CC.Effect`（`jyconst.lua:439`）硬编码 **53 项**，而 `effect.bin` 有 **64~200 项**
         （20/20 MOD 都超出）；实测 `CC.Effect[1..52]` **逐项等于** `effect.bin[1..52]`，
         `CC.Effect[0]=9` 是 Lua 索引占位、`effect.bin[0]=10` 被丢弃
      ⇒ `eft >= 53` 时 `war_async.lua:1110/1121-1123` 静默退化
      **方案**（`allmods-list-bin-support/design.md` ADR-1/2）：分类处理
      - `effect.bin` + `match.bin` → `REQUIRED`，进产物 + 运行时惰性装载（不改 `jyconst.lua`）
      - `leave.bin` + `levelup.bin` + `*.txt` → `LEGACY` + evidence（引擎零消费）
      **DoD**：`mod_audit` 的 `PENDING` **663 → 581**（仅剩音频），`list/*.bin` 无 `PENDING`
      **实测完成**（`allmods-list-bin-support/verification.md`）：
      - `effect.bin`/`match.bin` 20/20 MOD **逐字节**进 `data/`（`leave`/`levelup`/`*.txt` 不进）
      - `PENDING` 663 → **581**（`.mid 578 + .mp3 2 + .sf2 1`，`.bin` 残留 **0**）
      - `in_product` 9245 → **9285**（+40）
      - 运行时 `CC.Effect`：pascal **64** / BookCalamity **200** 项生效；未激活仍 **53** 兜底
      - **index 0 语义取证**：`sum(effect.bin 含 idx0) == eft.idx 段数` 在 **14/20** 精确成立，
        `跳 idx0` **0/20** ⇒ 数据侧的 `10` 正确、硬编码的 `9` 是原版遗留
      - 负向对照：3 项短文件→`3`；删文件→`53`；恢复→`64`
      - `format_spec.verifyBinTable` 升级为 **uint16 记录级**（奇字节显式 gap、空文件失败）
      - 全量测试 1914 → **1957**，8 门禁全绿，四禁改 **0**

- [x] **5 个 MOD 缺逐 MOD 字段/格式 DoD** — change: `allmods-permod-format-dod`（**已完成**）
      **缺口**：`awaken` / `bookcalamity` / `mingdong` / `pig3dos` / `zheng` 的 change
      集产生于 `format_spec.lua` 成形之前，grep `format_spec|字段级|格式族` 文档数 = **0**。
      功能是通的（实测 `--mod <m>` 全部 `gaps=0`），缺的是**可追溯的 DoD 留痕**。
      **已产出**：5 个子 change（`allmods-<m>-format-dod/`），各含
      逐格式表 + 原始输出 + slice0c [REQ-FMT-1~7] 追溯 + **20-MOD 横向对照**（禁只报自身数字）。
      **实测校验**：5 个 MOD 的 `--mod` 输出（awaken 342 / BookCalamity 589 /
      mingdong 831 / pig3dos 328 / zheng 197）与 spec 声明**逐字一致**；
      横向表 20 行 × 6 列数字**逐格**与库内 `verifyEverything` 实测吻合
      （`total == Σ 各 format 计数` 20/20 自洽），排名 7/2/1/8/20 全部核准。
      **修正**：横向表原未按 `total` 降序排列（`pascal 483` 排在第 17 行），已按实测重排。

- [x] **音频域（`.mid 578` / `.mp3 2` / `.sf2 1`）** — ✅ **已完成（方案改为直接播放 MIDI）**
      `openspec/changes/allmods-midi-direct-play/`（`status: done`）
      - **方案被用户质疑后推翻**：原计划 `allmods-slice15-music-ogg` 用 timidity+ffmpeg 转 41 个 ogg
        （+36 MB / 5 分钟 / 2 个外部二进制），实测 **LÖVE 11.5 原生支持 `.mid` 和 `.mp3`**
        （抽样 42/42 解码成功、42/42 真出声）⇒ 改为直接播放，成本降为 **+7.5 MB / 0 时间 / 0 依赖**
      - 原 `allmods-slice15-music-ogg` 及两个子 change 全部标记 **`abandoned`**（被取代）
      - 4 处改动：`lib_love.lua`（路径解析修正 + 扩展名探测 + 内置回退，+90/−2）、
        `mod_data.lua`（`MUSIC_DIR` + `CC.MIDIFile` 剥扩展名重定向）、
        `mod_build.lua`（`flattenMusic` 把 `<id>.mid` 重命名为 `game<id+1>.mid`）、
        `test_mod_data.lua`（+3 测试，含 2 个负向对照）
      - **兼容性（用户核心要求）**：原版 `CC.MIDIFile` 逐字节不变、25 个 ogg + 1093 个 wav 路径
        **0 处改变**；产物 `music/*.mid` **578 = 源 578（零丢失）**；被引用 id 可解析 **348/368 = 94.6%**；
        **19/20 MOD 100% 覆盖**；BookCalamity 15 MOD + 1 内置回退 + 19 静音（**未变差**）
      - **实测 5 个发现**：①LÖVE 按扩展名选解码器（mid 改名 .ogg 报 Ogg bitstream 错）；
        ②既有路径前缀 bug（`mods/...` 被误拼 `sound/mods/...`）；③`mid.sf2` 对 LÖVE 完全无效
        （3 种 cfg 写法合成 md5 全同）；④编号是 `music/<id>.mid` 非 `<id+1>`（命中 94.6% vs 90.5%，
        且有 `music/0.mid`）；⑤单编号方案会让 BookCalamity 从 16 首内置退化为 35 首全静音 ⇒ 必须内置回退
      - 门禁：G1 **1987/0**、G4 **20/20**、G5/G6 未变、G8 禁改 `CC.*=` = 0、幂等 diff = 0
      - **第二轮追加 MP3 支持**（用户要求）：LÖVE 原生解码实测出声（dream 266.72s/0.1511、
        pineapple 248.08s/0.1656）；`flattenMusic` 同时搬运 `.mid` + `.mp3`（`.sf2` 仍排除）；
        产物 `.mid` 578=578、`.mp3` 2=2、字节级 md5 一致、编号 0 冲突
      - **两处自我修正**：①「引擎无 MP3 通道」只对改动前成立（新 `MUSIC_EXTS` 已含 `.mp3`）；
        ②第一轮 id 扫描漏了 `instruct_66`（`awaken` 用了 48 个 id，0–80）
      - **踩坑**：Lua pattern 无 `|` 选择符，`"%.(mid|mp3)"` 静默匹配 0 文件 ⇒ 产物全空；
        已改白名单比较并加 `testMusicPatternHasNoLuaAlternation` 专防
      - **第三轮修 `tools/run-mod.sh` 缺陷**：旧逻辑 `[ ! -d $MODS_OUT_DIR/$slug ]`
        只看目录存在 ⇒ 新增 `music/` 产物后旧目录永远跳过重建、音频永久缺失（已实测确认）；
        改 `mod_ready()`（校验 data/ 非空 + music/ 数量 ≥ 源侧）+ `report_audio()` +
        `--list` 加 music 列；新增门禁 `game/tests/gate_run_mod.sh`（7 项，负向对照实测能 FAIL）
      - **第四轮治 libmodplug 警告**：全量实测 578 首（`load_pat` 578、`Meta` 519、
        `ends-with-note-on` 329）；证明均无害——`MMPAT_PATH_TO_CFG` 三种对照逐样本哈希
        全等 `172447810`；timidity 对账 521 首，**内容缺失 0 首**（超出段全是末音衰减拖尾）。
        `run-mod.sh` 自动设 MMPAT + 仅过滤这两类 stderr 前缀（`FUZZY_MIDI_WARN=0` 可关）；
        实测 `Dragon` 警告 10 行 → **0** 行
      - **第五轮修音质**：证 AppImage 自带 336KB `libmodplug` 完全不读音色库（128 个音色
        全指向同一鼓采样，PCM 逐字节相同）；预渲染 OGG 过零率 2215Hz vs 直放 4749Hz。
        `MUSIC_EXTS` 改 `.ogg,.mp3,.mid`；`mod_build` 加 `preservedOgg` 防重建删除；
        新增 `tools/render-music.sh`；Dragon 试点通过后已全量渲染 **578/578**（20 MOD，0 失败，约 53 分钟，476 MB）
      - ⚠ 已用用户授权解锁 `game/engine-love2d/**`（四禁改之一），其余三禁改未触碰
      - 审计数字**未变**（`PENDING` 仍 581）：`mod_audit` 统计的是 `reference/allmods/` 源侧分类，
        与产物无关；原方案预期的 `581→537` 随转码方案废弃而作废

## 开放问题（待决策）

- [x] **Spike: MOD 音乐引用分析（`music/*.mid`）** — ✅ **实测完成，已决策：不做（可选增强）**
      **报告**：`openspec/changes/allmods-spike-music-refs/reports/music-refs-audit.md`（297 行，5 REQ 全实测）
      **实测结论（推翻初稿 3 处高估）**：
      1. **`.mid` 实为 578 个文件**（各 MOD 23~84），去重后 **151** 个唯一内容；
         初稿「20/20 MOD 提供 66 个」把 **mingdong 一家的 66** 当成了全体。
      2. **真正受影响仅 3/20 MOD**，其余 **17/20 零影响**（被引用 id 全在 25 个 ogg 内）：
         - **A 类「需转换」（源有、产物无）2 个**：mingdong 26 个 id、awaken 15 个 id，
           合计 41，**去重后 34 个唯一 id**（重叠 7 个），最大 id = **81**（awaken）。
         - **B 类「源侧本就缺 `.mid`」1 个**：BookCalamity **20 个被引用 id 无源可转**
           ⇒ **MOD 原始缺陷，转换流水线无法修复**。
      3. **音色库 `mid.sf2` 仅 `pascal` 有**（19 个 MOD 无）⇒ 若转换则单一依赖点。
      4. **运行时后果**：`lib_love.lua:588` `pcall(love.audio.newSource,...)` + `:590` 仅 `Debug`
         ⇒ **缺 BGM 静默，不崩溃、不报错**。
      **决策理由**：17/20 MOD + 基线零影响 ⇒ **不阻塞 epic 的 MOD 兼容目标**；
      且方案 B 需外部 `timidity`/`fluidsynth`，与「构建期纯 Lua」约束冲突
      ⇒ 归为**可选增强脚本**（不入 `mod_build.lua` 主流程），当前不实施。
      **初稿原文（保留备查，3 处已推翻）：** 20/20 MOD 的 `music/` 提供 66 个 `<NN>.mid`（C 引擎 MIDI + `music/mid.sf2` 音色库），而 Lua 引擎期望 `sound/game%02d.ogg`（原版仅 25 个 ogg）。三重不匹配：
      1. **格式**：`.mid` → `.ogg` 需外部音源工具（timidity/fluidsynth + `mid.sf2`），破坏「构建期纯 Lua」约束。
      2. **槽位**：MOD 66 首 vs 引擎 25 槽，编号体系不同。
      3. **编号语义**：引擎 `PlayMIDI(id)` 的 `id` 来自 MOD 数据（`JY.Scene["进门音乐"]` / `WAR.Data["音乐"]`），需先确定「MOD 数据实际引用了哪些 id」才能决定转换范围。
      → 需先做 spike 确定「需几首、编号怎么对应」，再决定是否值得做。现做 = 猜。
      （音效 `sound/*.wav` 不属此列，已由 `allmods-slice0b-sound-fallback` 覆盖。）

## 开放问题（Slice 10 新增，待决策）

- [x] **Spike: `list/effect.bin` → `CC.Effect` 运行时重建** — ✅ **实测完成**（影响 **7/20 MOD**，估计与实测一致）
      **报告**：`openspec/changes/allmods-spike-effect-table/reports/effect-table-audit.md`（331 行，5 REQ 全实测）
      **实测结论**：
      1. **越界影响面 7/20**（与初稿估计一致 ✅）：BookCalamity **296** / mingdong **136** /
         pineapple **62** / pig3dos **52** / RiverLake **10** / books **2** / awaken **1**；
         其余 **13 个（含 `pascal` 基线）`max(eft)==52`** 恰好等于 `CC.Effect` 最大索引
         ⇒ **53 项表是为原版精确设计的**，只有扩展过效果的 MOD 才越界。
      2. **运行时后果量化**：`eft>52` → `CC.Effect[eft]==nil` → `framenum` **恒退化为 10 帧**、
         `starteft` **恒停在 712** ⇒ 视觉错位但**不崩溃、无日志**（静默缺陷）。
      3. **语义链 `sum(effect.bin) == eft.idx 段数` 在 13/20（含 `pascal`）精确成立**
         （713==713）；6 个有 ±偏差（+45..−13）属 MOD 数据侧 `effect.bin`/`eft.idx` 不同步，非解析口径问题。
      4. **`CC.Effect[0]=9` vs 全部 20 MOD `effect.bin[0]=10`** ⇒ **基线既有偏差**
         （`pascal` 亦然），不修。
      5. **`list/effect.bin` 20/20 源侧都有，产物 `data/` 20/20 都没有** ⇒ 构建器未搬运。
      **推荐方案 B**（构建期搬运 + 运行时惰性装载，~35 行，不触碰四禁改）：
      方案 A「直接改 `CC.Effect` 常量」**违反四禁改**且一张表无法覆盖 5 个 MOD 的不同帧数；
      方案 C「运行时读源目录」破坏产物自包含。方案 B 零回归（13 个 MOD `effect.bin[53:]` 全 0）。
      **待用户决策**：是否实施（建议独立 change `allmods-effect-table-fallback`）。
      以下为初稿记录（保留备查）：
      `script/jyconst.lua:439` 的 `CC.Effect` 是**硬编码 53 项**字面量表
      （`[0]=9, 14, 17, ...`，sum=712），而 `framework/war_async.lua:1106/1126` 用它算
      武功动画起始帧与帧数：
      ```lua
      local framenum = fightdelay + (CC.Effect and CC.Effect[eft] or 10) or 10
      for i = 0, eft - 1 do starteft = starteft + (CC.Effect[i] or 0) end
      ```
      **权威来源**：`reference/allmods/UPedit/UPedit.ini:80` → `Effect=list\effect.bin`；
      20/20 MOD 均有 `list/effect.bin`（int16 LE，**每效果**帧数表，项数 = 效果个数）。
      **语义链已实测**：`sum(effect.bin)` == `eft.idx` 条目数（`eft.idx` 为**逐帧**偏移表）——
      RiverLake 921 / BookCalamity 2857 / pineapple 1378 **精确相等**；其余因尾部补零差 1–44。
      **越界实测**：pascal 0 条 / RiverLake 10 / books 2 / awaken 1 / pineapple 62 /
      pig3dos 52（另越自带 `effect.bin`：eft 85 vs 64 项）/ mingdong 136 / BookCalamity 296。
      **非致命**：`CC.Effect[eft]` 为 nil ⇒ `or 10`；`CC.Effect[i]` 为 nil ⇒ `or 0`。
      实测 `eft=69 → framenum=15, starteft=40`（应为 15/229），不抛错不崩溃，仅动画帧错位。
      基线 `CC.Effect[0]=9` vs `effect.bin[0]=10` 亦有 1 帧既存偏差。
      **为何暂不做**：① 修复点在 `script/jyconst.lua`（负约束禁改路径）；
      ② 需改 `framework/mod_data.lua` 的 `RewriteConstants` 按 `effect.bin` 重建 `CC.Effect`，
      并把 `list/effect.bin` 从 `PENDING`（20 MOD 各 1 项）提升为 `REQUIRED` 纳进产物 ——
      会改动 **20 个 MOD 的审计分类、构建管线与产物清单**，属**独立 change**。
      **建议做法**：单独开 `allmods-effect-table` change，先确认「`effect.bin` 是否对所有 MOD 都存在
      且项数 = wugong 最大 eft id + 1」，再决定重建策略（全量重建 vs 仅扩展尾部）。
      记录于 Slice 10（`allmods-riverlake-activate` ADR-003 / `-verify` ADR-003）。

## 开放问题（探索期遗留，已结论）

- ✅ 独立 `item/*.png`（GodsDevils）、`eft/*.png`（ptt）目录：确认为 UPedit 副产物、引擎数据源在 grp 内（见 `allmods-spike-thingpic-audit/reports/thingpic-audit.md`）
- ✅ kdef 提取对 fishedit 文本格式的依赖：已解除，`mod_build.lua` 直接解析 kdef.grp 二进制（REQ-BUILD-2）
- ✅ talk 提取：`~big5`（16 位按位取反）编码已破解，`talk_big5.lua` 码表已提交（REQ-BUILD-3）
- ✅ kys-pascal 基线：1015/1018 事件结构精确匹配，3 个已记录的原版提取器缺陷（320/655/691）见 `mod_build.lua --verify-pascal`
