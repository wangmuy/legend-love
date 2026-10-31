# Tasks: allmods-dragon-verify

> Change: `allmods-dragon-verify`（Slice 11 第二阶段：审计/证明）
> 前置：`allmods-dragon-activate` 全部任务已完成（16 章节）
> 权威来源：当前工作树 + 实测命令输出。所有任务均已实跑。

---

## Blast Radius（允许改动的路径）

| 允许 | 路径 |
|------|------|
| ✅ | `openspec/changes/allmods-dragon-verify/**` |
| ✅ | `openspec/changes/allmods-slice11/**` |
| ✅ | `openspec/epics/2026-10-allmods-compat/{epic.md,TODO.md}` |
| ✅ | `game/mods/Dragon/**`（**只读**用于验证，除 save/ 实验后已恢复） |
| ❌ | `game/engine-love2d/**` |
| ❌ | `game/engine-mud/**` |
| ❌ | `game/script/jyconst.lua` 的 `CC.*` 常量定义 |
| ❌ | `reference/allmods/**` |
| ❌ | `game/tools/**`（本 change 无工具缺陷修复） |

---

## 1. 前置：确认 activate 已完成

- [x] 1.1 `allmods-dragon-activate/tasks.md` 16 章节全部 `[x]`
- [x] 1.2 `allmods-dragon-activate/verification.md` 15 章节存在
- [x] 1.3 `allmods-dragon-activate/specs/.../spec.md` REQ-DRG-1~14 齐备

**DoD**：`grep -c '^\- \[ \]' allmods-dragon-activate/tasks.md` → `0`

---

## 2. `diff.md` 双向 set 相等（REQ-DRGV-1）

- [x] 2.1 确认 `data/` 与 `mods/Dragon/data/` 均为**单层展平**（`mod_build.lua:1057
      dataFileSet` 只 `listDir` 顶层）
- [x] 2.2 取两侧顶层文件名集合，剔除别名对（`sdx/smp/wdx/wmp` ↔
      `smap.idx/smap.grp/wmap.idx/wmap.grp`）
- [x] 2.3 与 `diff.md` 的 `- + <name>` / `- - <name>` 列表做**双向 set 相等**
- [x] 2.4 输出 `diff-only` 与 `actual-only` 双向差集，必须均为 `[]`

**实测**：
```
added:   diff=254 actual=254 equal=True   diff-only=[] actual-only=[]
removed: diff=25  actual=25  equal=True   diff-only=[] actual-only=[]
```

**DoD**：`equal=True` × 2 且双向差集为 `[]`。✅

---

## 3. MOD 独有 254 项结构分解（REQ-DRGV-2）

- [x] 3.1 fight `*.grp` = 119，fight `*.idx` = 119
- [x] 3.2 非 fight = 16，逐项列出
- [x] 3.3 Σ 复核：119 + 119 + 16 = 254

**DoD**：Σ = 254 且 16 项非 fight 全部有名有姓。✅

---

## 4. 16 项非 fight 逐字节校验（REQ-DRGV-3）

- [x] 4.1 对每一项计算源与产物的 md5 + size
- [x] 4.2 识别「源不存在 ⇒ 构建生成」项：`ranger.str`（`mod_build.lua:1174`）
- [x] 4.3 识别「源在 MOD 根目录」项：`kysmod.ini`（不在 `resource/`）
- [x] 4.4 复核 15 项字节相同 + 1 项构建生成 = 16

**实测**：
```
cloud.grp     38120B ✅      kdef.idx      4348B ✅
cloud.idx        36B ✅      name.grp    211697B ✅
end.png      490590B ✅      name.idx     16080B ✅
kdef.grp     190110B ✅      open.png    188358B ✅
kysmod.ini     1729B ✅      ranger.str  35898B —（构建生成）
talk.grp     211697B ✅      talk.idx     16080B ✅
talkutf8.txt 311989B ✅      title.grp    10050B ✅
title.idx        36B ✅      war1.sta     66030B ✅
```
`kysmod.ini` md5 `de0dd0769df2e156ce8fe4bef6d1b37c`（源 = 产物）。

**DoD**：15/15 字节一致 + 1/1 构建生成 = 16 项全解释。✅

---

## 5. `war1.sta` 双判定不矛盾（REQ-DRGV-4）

- [x] 5.1 源存在 66030B；`66030 ÷ 186 = 355` 记录（`CC.WarDataSize=186`）
- [x] 5.2 产物存在 66030B，md5 = 源
- [x] 5.3 基线不存在
- [x] 5.4 `CC.WarFile` 只指 `war.sta`（`jyconst.lua:129`）
- [x] 5.5 `grep -rn "war1" script/ framework/ engine-love2d/` → **0 命中**
- [x] 5.6 审计规则 `mod_audit.lua:189` `DEAD_FILE, needed=false`
- [x] 5.7 与 RiverLake `allsinbk.grp` 做**区别表**（前者「新增的死文件」，
      后者「回退到的死文件」）

**DoD**：五维度全部实测，两判定并列展示不冲突。✅

---

## 6. `fight101/102` 缺失优雅降级（REQ-DRGV-5，**含正对照**）

- [x] 6.1 数据引用实测：`Person` 589 条中 **588** 条有头像代号，
      max=**219**，`头像代号==101` → 1 条，`==102` → 1 条
- [x] 6.2 文件存在性：`fight101.*`/`fight102.*` → `exists=false`；
      `fight103.idx` → `exists=true`
- [x] 6.3 `FileLength` 缺失 → **-1**（`lib_love.lua:283-289`）
- [x] 6.4 `PicLoadFile` → `idxlen<0 or grplen<0 then return`（`:435`），
      `pcall=true err=nil`
- [x] 6.5 `PicFile:getPic` → `idx[picid]==nil` → `Debug` + `nil`（`:269-273`）
- [x] 6.6 `PicGetXY` → **0,0**（`:465-468`）
- [x] 6.7 **正对照**：`fight103` 存在时 `PicGetXY(4, 0/2/4/6)` →
      **33×63 / 74×67 / 74×70 / 72×69**

**修正记录**：初版用 `PicGetXY` **裸调**（未先 `PicLoadFile`）作证据，
实测抛 `lib_love.lua:462 attempt to index a nil value`（`picFileCache[fileid]` 为 `nil`）。
该错误来自**调用前置条件不满足**，与 MOD 数据无关，但**不能作为「优雅降级」证据**。
已改为「先 `PicLoadFile` 再 `PicGetXY`」并加入正对照。

**DoD**：缺失 → 0,0；存在 → 非零真实尺寸；两者 pcall 均 `true`。✅

---

## 7. `not_in_product=256` 语义纠正（REQ-DRGV-6）

- [x] 7.1 对 256 项逐项检查产物**物理存在性**
- [x] 7.2 分类：物理存在 **4** / 物理缺失 **252**
- [x] 7.3 4 项明细：`name.grp`(LEGACY)、`name.idx`(LEGACY)、
      `talkutf8.txt`(BUILD_INPUT)、`war1.sta`(DEAD_FILE)
- [x] 7.4 根因定位：`mod_audit.lua:453-462` `checkInProduct` 先查
      `IN_PRODUCT_BY_CATEGORY`（`:48`），三类均为 `false`
- [x] 7.5 判定为**语义/命名不精确**，非逻辑缺陷；本 change 不修复

**DoD**：4 + 252 = 256 且根因代码行号可复核。✅

---

## 8. `cloud/title/open/end` 无运行时消费者（REQ-DRGV-7）

- [x] 8.1 `grep -rn "cloud" --include=*.lua script/ framework/ engine-love2d/` → **0**
- [x] 8.2 `title.grp`/`title.idx` → **0**
- [x] 8.3 `open.png` → **0**
- [x] 8.4 `end.png` → **1**：`jymain.lua:4273` `lib.LoadPicture(CONFIG.PicturePath.."end.png")`
- [x] 8.5 `CONFIG.PicturePath = "pic/"`（`framework/config.lua:42`）⇒ 读的是
      **基线** `game/pic/end.png`，不是 `mods/Dragon/data/end.png`
- [x] 8.6 md5 三者对照：`pic/end.png`=`ea0d6132…`；
      `mods/Dragon/data/end.png`=`b538413b…`；源=`b538413b…`
- [x] 8.7 `CC.CloudPicFile`/`TitlePicFile`/`OpenFile`/`EndFile` 实测全 `nil`
- [x] 8.8 归类来源 = `mod_audit.lua:264-269` `BY_KIND` 兜底（非按运行时读取）
- [x] 8.9 覆盖度：`title`/`open`/`cloud` **20/20**、`end.png` **16/20**

**DoD**：4 类 0 命中，`end.png` 的 1 命中可溯源且指向基线。✅

---

## 9. `name.*` 历史兼容副本（REQ-DRGV-8）

- [x] 9.1 `name.grp` 与 `talk.grp` md5 相同 `4c41c044413860015bd626d480e36951`
- [x] 9.2 `name.idx` 与 `talk.idx` md5 相同 `1a0c74ab1dd84e8714a5b4fd1ed22488`
- [x] 9.3 `name.grp` 运行时引用 **0**；`EV_LEGACY_NAME`（`mod_audit.lua:102`）
- [x] 9.4 `talk.grp` 运行时引用 **0**，但**构建期** `mod_build.lua:916`
      提取 → `script/oldtalk.{grp,idx}`，`CC.TalkGrpFile=script/oldtalk.grp`
- [x] 9.5 判定：MOD 作者遗留副本 + 「`resource/` 一律展平复制」契约，非缺陷
- [x] 9.6 分布确认：4/20 MOD 有 `name.*`（BookCalamity / Dragon / RiverLake / pineapple）

**DoD**：md5 相等 ×2、引用数 0 ×2、构建期用途可溯源。✅

---

## 10. `kysmod.ini` 生效反向对照（REQ-DRGV-9）

- [x] 10.1 基线段（未激活）读 11 个候选常量
- [x] 10.2 激活 Dragon 后重读
- [x] 10.3 判据：只认「基线 `nil` → 激活有值」的跳变
- [x] 10.4 **修正字段名**：`CC.LIFE_HURT` → **`CC.LifeHurt`**
      （`mod_ini.lua:187` 映射 `life_hurt → CC.LifeHurt`）
- [x] 10.5 **剔除伪证据**：`CC.MoneyID` 基线已由 `jyconst.lua:435` 定义为 174，
      两侧同值无法区分 ini 注入

**实测**：
```
基线: MaxLevel=nil MaxHP=nil MaxMP=nil MaxPhysicalPower=nil MaxItemAmount=nil
      ItemBeginPic=nil MaxWeaponMatch=nil MinKnowledge=nil LifeHurt=nil ExpRate=nil
      MoneyID=174（基线已定义）
激活: MaxLevel=60 MaxHP=999 MaxMP=9999 MaxPhysicalPower=100 MaxItemAmount=200
      ItemBeginPic=4131 MaxWeaponMatch=7 MinKnowledge=80 LifeHurt=10 ExpRate=1
```

**DoD**：**10** 项 `nil → 有值` 跳变（非初稿所称 11 项含 `MoneyID`）。✅

---

## 11. 内容真实性四类证据（REQ-DRGV-10）

- [x] 11.1 记录数：Person 589 / Thing 237 / Scene 106 / Wugong 114
- [x] 11.2 边界值 8 项全部可读：
      `資`/`李卡多`、`小還丹`/`真武劍`、`胡斐居`/`西部農村`、`普通攻擊`/`閃電貂`
- [x] 11.3 `mods/Dragon/script/oldevent/*.lua` = **1087**
- [x] 11.4 `oldtalk.idx` = **4020** 条目（16080B ÷ 4）；`oldtalk.grp` **318143B**；
      4021 行；`[1]=小兄弟，到此寒天雪地，不知有何指教？`；
      `[4018]=国家兴亡，匹夫有责！兄弟，我也来帮你吧。`
- [x] 11.5 ini 常量覆盖见 §10

**DoD**：4 类证据全部直接可复核。✅

---

## 12. Scene 内容负对照（REQ-DRGV-11，第 5 次应用）

- [x] 12.1 Dragon `Scene[0]=胡斐居`、`[1]=河洛客棧`、`[2]=雪山`、
      `[50]=閰基居`、`[105]=西部農村`
- [x] 12.2 基线 `Scene[0]=胡斐居`、`[1]=河洛客棧`、`[2]=云鶴崖`、
      `[80]=絕情谷底`、`[83]=圣堂`
- [x] 12.3 对照结论：`[2]` 不同（雪山 vs 云鶴崖）⇒ **记录数相等 ≠ 内容相同**

**DoD**：至少 1 个索引内容不同，且记录数相同（106 vs 106）。✅

---

## 13. `hdgrp` 267 索引驱动（REQ-DRGV-12，第 7 次应用）

- [x] 13.1 `resource/hdgrp.idx` = 1068B
- [x] 13.2 `1068 ÷ 4` = **267**
- [x] 13.3 引擎读取方式 `lib_love.lua:437` `idxlen/4`，无固定计数常量
- [x] 13.4 外推链：125 / 129 / 173 / 178 / 204 / 252 / **267**
- [x] 13.5 `format_spec --all` 对 `hdgrp` 族 `gaps=0`

**DoD**：267 = 1068/4 且无常量约束。✅

---

## 14. 存档槽播种修正（REQ-DRGV-13）

- [x] 14.1 源 `save/` 实测：`alldef.idx`(336B)、`allsin.idx`(336B)、
      `ranger.idx`(24B)；**无** `r1~r3.idx`
- [x] 14.2 产物 `save/` 实测：上述 3 个 **+** `r1.idx`/`r2.idx`/`r3.idx` 各 24B
- [x] 14.3 播种实验：`slot0 = mods/Dragon/data/ranger.idx(24B)`；`slot1~3 size=-1`；
      `SeedSaveSlot(1..3)` 返回 mods 路径；`r1/2/3.idx == MOD ranger.idx` → `True`，
      `== baseline` → `False`
- [x] 14.4 实验后 `cp -r` 恢复 + `cmp` 校验 **27/27** 全等
- [x] 14.5 修正同步到 activate 的 `spec.md` REQ-DRG-11、`tasks.md` §11、
      `proposal.md`、`design.md` ADR-007

**DoD**：源 3 个 `.idx` / 产物 6 个 `.idx`、播种前后差异可复现、27/27 恢复。✅

---

## 15. 8 道门禁实跑（REQ-DRGV-14）

- [x] 15.1 `tests/test_runner.lua` → **1842/1842 pass**
- [x] 15.2 `mod_build --verify-pascal` → `mismatches=0`（`known-deviations=3`）
- [x] 15.3 `mod_build --all` → 20 mods / 0 build failures（退出码 1 为设计行为）
- [x] 15.4 `mod_check` → 20/20
- [x] 15.5 `mod_audit --all --evidence` → `unclassified=0` `bad_evidence=0`
      （`total=11220` `in_product=9245` `not_in_product=1975`
      `evidence checked=17 failed=0`）
- [x] 15.6 `format_spec --all` → `formats=12 checked=6773 gaps=0`
- [x] 15.7 20 MOD `save/` vs 源 → **451 文件，真实问题 0**
      （其中 430 逐字节一致；**21 项差异为设计内转换**：`ranger.grp` ×20 经
      Big5→UTF-8 + 固定宽度 hint 重写（589 个 `P####` hint 对应 589 条 Person 记录，
      真实字符串进 `data/ranger.str`），`ranger.idx` ×1（zheng）由
      `ModEncoding.RepairIdx` 按 grp 实体字节重建段边界。
      见 §15.9）
- [x] 15.8 禁改路径 `git status` → 空（`game/engine-love2d`/`game/engine-mud`/
      `reference/allmods` 三处 porcelain 输出为空；`game/script/jyconst.lua` 有 +11/−1，
      但 `git diff -U0 | grep '^[+-]\s*CC\.[A-Za-z_]+='` 为空 ⇒ 常量定义未改，
      新增内容是 `allmods-data-fallback` 的 `RewriteConstants`/`ApplyLayout` 接线）

### 15.9 门禁 7 的口径修正（重要）

**初稿错误**：`allmods-dragon-activate/verification.md` 与 `epic.md:781` 写作
「451 文件，不一致 = 0」。实测按 `mod_build` 的真实路由复算：

```
源 save/ 文件数 = 451
  逐字节一致    = 430
  差异          = 21   ← ranger.grp ×20 + ranger.idx ×1(zheng)
```

`mod_build.lua:665-670` 的 `isSaveSlotFile`（`:626-631`，正则 `^[rds]%d+%.(grp|idx)$`）
把 `save/` 按两类路由：**槽文件 → `mods/<m>/save/`**（341 个），
**模板 → `mods/<m>/data/`**（110 个）。初版比对脚本把 `ranger.*` 也当槽文件去找
`save/ranger.*`，故误得「缺失 110」。

修正后 21 项差异全部是**设计内转换**：

| 项 | 数量 | 机制 |
|----|-----:|------|
| `ranger.grp` | 20 | Big5→UTF-8，字符串区写固定宽度 hint（Dragon 实测 17646/174230 = 10.1% 字节变化），真实值进 `data/ranger.str` |
| `ranger.idx` | 1（zheng） | 源 idx 描述 138596B 文件而 grp 仅 114242B ⇒ `ModEncoding.RepairIdx` 按字节重建（`:248`）；Dragon 的 idx 一致故未修 |

`tests/unit/test_mod_resources.lua:465` `testProductSaveSlotMatchesSource`
判的就是**槽文件**（`save/` ↔ 源 `save/`），不覆盖模板类；故该测试 PASS 与
「ranger 被转换」不矛盾，但**不能据此宣称「451 全等」**。

**DoD**：8/8 达标，且每条命令可复跑；门禁 7 口径已精确到「430 全等 + 21 设计内转换」。✅

---

## 16. 产物与报告

- [x] 16.1 `reports/dragon-verify.md`（6 章节）
- [x] 16.2 `verification.md`（逐 REQ 验证结果）
- [x] 16.3 `proposal.md`（REQ-DRGV-1~8 → 扩展至 14）
- [x] 16.4 `design.md`（ADR-001~006 + ADR-004b）
- [x] 16.5 `specs/allmods-dragon-verification/spec.md`（REQ-DRGV-1~14）

**DoD**：5 个产物齐备且无 `TODO`/`TBD` 占位。✅

---

## 17. 索引与上层同步

- [x] 17.1 `allmods-slice11/change-manifest.md` 两个子 change 均 `[x]`
- [x] 17.2 `epic.md` 新增 `### Slice 11: Dragon …` 章节 + 梯队表行
- [x] 17.3 `TODO.md` 第 4 梯队 Dragon 条目 `[x]`
- [x] 17.4 `TODO.md` 新增「精度发现」待决策项（`not_in_product` 语义 +
      `cloud/title/open/end` 归类）

**DoD**：4 处索引更新完成且交叉引用一致。✅
