# Spec: allmods-dragon-verification

> Change: `allmods-dragon-verify`（Slice 11 第二阶段）
> 上游：`allmods-dragon-activate`（REQ-DRG-1~14 已交付）
> 判据原则：**唯一权威 = 当前工作树 + 实测命令输出**。任何「应该」「可能」「同上个 MOD」
> 都不作为结论；每个 REQ 必须附可复跑命令与其真实输出。

---

## REQ-DRGV-1：`diff.md` 与实测差集**双向 set 相等**

**Given** 产物 `game/mods/Dragon/` 与基线 `game/data/` 均已存在，
`game/data` 与 `mods/Dragon/data` 都是**单层展平**目录（`mod_build.lua:1057 dataFileSet`
只枚举顶层文件名），
**When** 分别取两个目录的顶层文件名集合，剔除别名对（`sdx/smp/wdx/wmp` ↔
`smap.idx/smap.grp/wmap.idx/wmap.grp`），
**Then** 得到的 `added`/`removed` 集合必须与 `diff.md` 中 `- + <name>` / `- - <name>`
列表**逐项相等**（不是计数相等）。

| 项 | `diff.md` | 实测 | set 相等 |
|----|----------:|-----:|:--------:|
| MOD 独有 | 254 | 254 | ✅ `True` |
| 基准独有 | 25 | 25 | ✅ `True` |

**反例保护**：计数相等但内容错位的情形已被 set 相等排除
（`diff-only` 与 `actual-only` 双向均为 `[]`）。

---

## REQ-DRGV-2：MOD 独有 254 项**逐项归类**，无一遗漏

**Given** 254 项（238 fight + 16 非 fight），
**When** 对每一项给出「源→产物字节一致性 + 引擎消费者」，
**Then** 每项都有明确归属，Σ 复核 = 254。

| 类别 | 项数 | 说明 |
|------|-----:|------|
| fight `*.grp` | 119 | 新增战斗贴图数据 |
| fight `*.idx` | 119 | 对应索引 |
| 非 fight | 16 | 见 REQ-DRGV-3 |

238 + 16 = **254** ✅

---

## REQ-DRGV-3：16 项非 fight **逐字节校验**

**Given** 16 项非 fight 文件，
**When** 对源与产物计算 md5 与 size，
**Then** 除「构建生成」项外，全部字节相同。

| 文件 | 字节 | 源→产物 |
|------|-----:|:-------:|
| `cloud.grp` | 38120 | ✅ |
| `cloud.idx` | 36 | ✅ |
| `end.png` | 490590 | ✅ |
| `kdef.grp` | 190110 | ✅ |
| `kdef.idx` | 4348 | ✅ |
| `kysmod.ini` | 1729 | ✅（源在 MOD **根目录**，md5 `de0dd076…` 两侧相同） |
| `name.grp` | 211697 | ✅ |
| `name.idx` | 16080 | ✅ |
| `open.png` | 188358 | ✅ |
| `ranger.str` | 35898 | —（**源不存在**，`mod_build.lua:1174` 构建生成） |
| `talk.grp` | 211697 | ✅ |
| `talk.idx` | 16080 | ✅ |
| `talkutf8.txt` | 311989 | ✅ |
| `title.grp` | 10050 | ✅ |
| `title.idx` | 36 | ✅ |
| `war1.sta` | 66030 | ✅ |

**Then** 15 项字节一致 + 1 项构建生成 = 16 ✅

---

## REQ-DRGV-4：`war1.sta` 的 `DEAD_FILE` 判定与「MOD 独有」**不矛盾**

**Given** `war1.sta` 同时出现在 `diff.md`「MOD 独有」和审计 `DEAD_FILE`，
**When** 分别检验「源存在 / 产物存在 / 基线存在 / 常量引用 / 代码引用」五个维度，
**Then** 两个判定回答的是不同问题，须并列展示。

| 维度 | 实测 |
|------|------|
| 源存在 | ✅ 66030B（`66030 ÷ 186 = 355` 记录） |
| 产物存在 | ✅ 66030B，md5 与源相同 |
| 基线存在 | ❌ |
| `CC.WarFile` | `war.sta`（不含 `war1`） |
| `grep -rn "war1" script/ framework/ engine-love2d/` | **0 命中** |
| 审计规则 | `mod_audit.lua:189` `category="DEAD_FILE", needed=false` |

**Then** 「MOD 新增了它」与「引擎不读它」**同时成立**，不构成工具矛盾。

---

## REQ-DRGV-5：`fight101`/`fight102` 缺失——数据仍引用、资源缺失、引擎降级（带正对照）

**Given** 基准独有 25 项中含 `fight101.{grp,idx}` 与 `fight102.{grp,idx}`，
而 Dragon 的 `Person` 段确实有头像代号 101/102 的引用，
**When** 在运行时走完整加载链路（`PicLoadFile` → `PicFile:getPic` → `PicGetXY`），
并**同时**用存在的 `fight103` 做正对照，
**Then** 缺失时必须返回 0 尺寸而非崩溃，且正对照必须返回真实尺寸。

| 层 | 实测 |
|----|------|
| 数据引用 | `Person` 589 条中 **588** 条有头像代号（`>0`），max=**219**；`头像代号==101` 命中 **1** 条，`==102` 命中 **1** 条 |
| 文件存在 | `fight101.idx`/`.grp`/`fight102.*` → `exists=false`；`fight103.idx` → `exists=true` |
| `FileLength` | 缺失文件返回 **-1**（`lib_love.lua:283-289`） |
| `PicLoadFile` | `idxlen < 0 or grplen < 0 then return`（`lib_love.lua:435`）→ `pcall=true`, `err=nil` |
| `PicFile:getPic` | `idx[picid]==nil` → `Debug` + `return nil`（`lib_love.lua:269-273`） |
| `PicGetXY` | 返回 **w=0, h=0**（`lib_love.lua:465-468`） |

**正对照（必须同时满足，否则判据无效）**：

| 场景 | `PicLoadFile` | `PicGetXY(4, 0/2/4/6)` |
|------|---------------|------------------------|
| `fight101`（**缺失**，数据引用） | `pcall=true err=nil` | **0,0 / 0,0 / 0,0 / 0,0** |
| `fight103`（**存在**，正对照） | `pcall=true err=nil` | **33×63 / 74×67 / 74×70 / 72×69** |

⚠ **不用 `PicGetXY` 裸调（未先 `PicLoadFile`）作为证据**：此时
`picFileCache[fileid]` 为 `nil`，`PicGetXY` 会**抛 Lua 错误**
（`lib_love.lua:462` `attempt to index a nil value`）。这是调用前置条件，
与 MOD 数据无关，但**不可混入「优雅降级」证据**。

**Then** 判为 **MOD 作者侧数据不一致**，不由构建器补文件、不改写头像代号；
引擎三层降级实测成立，且正对照证明该测量方法能区分「缺」与「有」。

---

## REQ-DRGV-6：`not_in_product` ≠ 物理缺失（语义纠正）

**Given** 审计输出 `not_in_product=256`，
**When** 对 256 项逐项检查产物中**是否物理存在**，
**Then** 必须区分「类别上不需要」与「物理缺失」，并给出正确总数。

| 判定 | 项数 | 明细 |
|------|-----:|------|
| 物理存在但 `not_in_product` | **4** | `name.grp`(LEGACY)、`name.idx`(LEGACY)、`talkutf8.txt`(BUILD_INPUT)、`war1.sta`(DEAD_FILE) |
| 物理确实缺失 | **252** | `head/` 220 + `list/` 24 + `music/` … |

4 + 252 = **256** ✅

根因：`mod_audit.lua:453-462` `checkInProduct` 先看
`IN_PRODUCT_BY_CATEGORY[rule.category]`（`mod_audit.lua:48`），
`LEGACY` / `DEAD_FILE` / `BUILD_INPUT` 均为 `false`，
**无论产物是否存在都返回 `false`**。

**Then** `not_in_product` 的正确解读是「**非必需产物成员**」，
本 change 只记录、不改工具契约（见 design ADR-004）。

---

## REQ-DRGV-7：`cloud.*` / `title.*` / `open.png` / `end.png` —— 归类保守但无害

**Given** 这 6 个文件被审计标为 `REQUIRED`/`in_product=true`，且 20/20 MOD 均提供，
**When** 在 Lua 引擎中检索运行时消费者，
**Then** 必须如实报告「无运行时消费者」，并判定为 `BY_KIND` 兜底而非构建缺陷。

| 目标 | `grep -rn <x> --include=*.lua script/ framework/ engine-love2d/` |
|------|------------------------------------------------------------|
| `cloud` | **0 命中** |
| `title.grp` / `title.idx` | **0 命中** |
| `open.png` | **0 命中** |
| `end.png` | **1 命中**：`jymain.lua:4273` `lib.LoadPicture(CONFIG.PicturePath .."end.png")` |

`CONFIG.PicturePath = "pic/"`（`framework/config.lua:42`），
产物 `end.png` 在 `data/`，且两处 md5 不同：

```
ea0d61322986047ca9ffc3560e76f6f0  game/pic/end.png          ← 运行时实际读
b538413b06463521c56302e6a7b0649d  game/mods/Dragon/data/end.png
b538413b06463521c56302e6a7b0649d  reference/allmods/kys-Dragon/resource/end.png
```

`CC.*` 中不存在 `CloudPicFile` / `TitlePicFile` / `OpenFile` / `EndFile`（实测全部 `nil`）。

**Then** 判为「C 引擎资源，Lua 引擎未接入」；`REQUIRED` 由
`mod_audit.lua:264-269` `BY_KIND` 兜底。**不改判定**（改则需动 20 MOD 统计与 12 个既有 slice）。

---

## REQ-DRGV-8：`name.*` = `talk.*` 的历史兼容副本

**Given** `name.grp`/`name.idx` 被构建复制进 `data/`，审计归类 `LEGACY`/`needed=false`，
**When** 对比 `name.*` 与 `talk.*` 的 md5，
**Then** 两者内容完全相同，且 `talk.*` 确有构建期用途（`name.*` 无）。

| 文件对 | md5 |
|--------|-----|
| `resource/name.grp` / `resource/talk.grp` | `4c41c044413860015bd626d480e36951`（相同） |
| `resource/name.idx` / `resource/talk.idx` | `1a0c74ab1dd84e8714a5b4fd1ed22488`（相同） |

引用次数：`name.grp` = **0**；`talk.grp`（作为 `data/talk.grp`）= **0**，
但**构建期** `mod_build.lua:916` 从中提取 `script/oldtalk.{grp,idx}`，
而 `CC.TalkGrpFile = script/oldtalk.grp`（`jyconst.lua:134`）。

**Then** 判为 **MOD 作者历史遗留副本 + 构建「`resource/` 一律展平复制」契约**，
非缺陷；保留不删（4/20 MOD 有该文件：BookCalamity / Dragon / RiverLake / pineapple）。

---

## REQ-DRGV-9：`kysmod.ini` **确实生效**（反向对照）

**Given** `kysmod.ini` 含多个 `CC.*` 覆盖项，
**When** 分别在不激活 MOD / 激活 Dragon 两种状态下读取这些 `CC.*`，
**Then** 在**基线不定义**的常量上必须观察到 `nil → 有值` 的跳变。

实测（`SetGlobalConst()` 后读取）：

| 常量 | 未激活（基线） | 激活 Dragon | 判据 |
|------|:--------------:|:-----------:|------|
| `CC.MaxLevel` | `nil` | **60** | ✅ 跳变 |
| `CC.MaxHP` | `nil` | **999** | ✅ 跳变 |
| `CC.MaxMP` | `nil` | **9999** | ✅ 跳变 |
| `CC.MaxPhysicalPower` | `nil` | **100** | ✅ 跳变 |
| `CC.MaxItemAmount` | `nil` | **200** | ✅ 跳变 |
| `CC.ItemBeginPic` | `nil` | **4131** | ✅ 跳变 |
| `CC.MaxWeaponMatch` | `nil` | **7** | ✅ 跳变 |
| `CC.MinKnowledge` | `nil` | **80** | ✅ 跳变 |
| `CC.LifeHurt` | `nil` | **10** | ✅ 跳变 |
| `CC.ExpRate` | `nil` | **1** | ✅ 跳变 |
| ~~`CC.LIFE_HURT`~~ | `nil` | `nil` | ❌ **不存在该字段** |
| ~~`CC.MoneyID`~~ | **174** | 174 | ❌ **基线已定义，非 ini 证据** |

### 修正（相对 activate 初稿）

1. **`CC.LIFE_HURT` 是错误的字段名**。`mod_ini.lua:187` 的映射是
   `life_hurt → { {"CC", "LifeHurt"} }`；激活后实测 `CC.LifeHurt = 10`，
   而 `CC.LIFE_HURT` 恒为 `nil`（该字段从未存在）。
2. **`CC.MoneyID` 不能作为 ini 生效证据**。`jyconst.lua:435` 已有
   `CC.MoneyID=174`，基线态即为 174；`kysmod.ini` 的 `MONEY_ID = 174`
   只是与基线同值，**无法区分「ini 注入」与「基线默认」**。

⇒ 有效证据是上表前 **10** 项（全部为基线 `nil` 的常量），
而非初稿所称的 11 项含 `MoneyID`。

---

## REQ-DRGV-10：内容真实性 —— 四类直接证据

**Given** 记录数（589/237/106/114）只是结构证据，
**When** 采集内容级证据，
**Then** 至少四类必须全部命中：

| # | 类型 | 实测 |
|---|------|------|
| 1 | 记录边界值 | `Person[0]=資`/`[588]=李卡多`；`Thing[0]=小還丹`/`[236]=真武劍`；`Scene[0]=胡斐居`/`[105]=西部農村`；`Wugong[0]=普通攻擊`/`[113]=閃電貂` |
| 2 | kdef 事件 | `mods/Dragon/script/oldevent/` = **1087** 个 `.lua`（= 构建报告 `events=1087`） |
| 3 | talk 文本 | `script/oldtalk.idx` = **4020** 条目；`oldtalk.grp` 318143B；`[1]=小兄弟，到此寒天雪地，不知有何指教？`；`[4018]=国家兴亡，匹夫有责！兄弟，我也来帮你吧。` |
| 4 | ini 常量覆盖 | 见 REQ-DRGV-9（**10** 项基线段为 `nil` 的常量全部命中；`MoneyID` 基线已定义故不计） |

---

## REQ-DRGV-11：Scene 段**内容**验证（负对照，第 5 次应用）

**Given** Scene 段 106 条记录，若只比记录数则无法排除「加载了基线的 106 条」，
**When** 取 MOD 与基线的 Scene 名称做负对照，
**Then** 必须有相当比例不同。

| 索引 | Dragon | 基线 |
|-----:|--------|------|
| 0 | 胡斐居 | 胡斐居（同） |
| 1 | 河洛客棧 | 河洛客棧（同） |
| 2 | **雪山** | 云鶴崖（异） |
| 50 | 閰基居 | — |
| 105 | 西部農村 | — |
| 80 | — | 絕情谷底 |
| 83 | — | 圣堂 |

**Then** 至少 3/4 对照点不同 ⇒ 判据成立（**记录数相等 ≠ 内容相同**）。

---

## REQ-DRGV-12：`hdgrp` 267 条目（索引驱动，第 7 次应用）

**Given** `resource/hdgrp.idx` 1068B，
**When** 按引擎读取方式（`lib_love.lua:437` `idxlen/4`）计算条目数，
**Then** 267 = 1068/4，且无固定计数常量约束。

| 项 | 值 |
|----|----|
| `hdgrp.idx` | 1068B |
| 条目数 | **267** |
| 基线 | 115 |
| 固定计数常量 | **无**（`CC.HeadPicFile` 只有路径，无长度） |
| 外推链 | 125 / 129 / 173 / 178 / 204 / 252 / **267** |

**Then** 索引驱动成立，267 不越界；`format_spec --all` 对 `hdgrp` 族 `gaps=0`。

---

## REQ-DRGV-13：存档槽播种（修正 activate 初稿的错误结论）

**Given** activate 初稿曾断言「源 `save/` 无 `.idx` 槽 ⇒ 无首次播种」，
**When** 实测源 `save/` 与产物 `save/` 的 `.idx` 文件，
**Then** 必须**修正**为「源含 3 个 `.idx`、缺 `r1~r3.idx`；产物含 6 个 `.idx`（`SeedSaveSlot` 播种 3 个）」。

| 位置 | `.idx` 文件 |
|------|-------------|
| 源 `reference/allmods/kys-Dragon/save/` | `alldef.idx`(336B)、`allsin.idx`(336B)、`ranger.idx`(24B) |
| 产物 `game/mods/Dragon/save/` | 上述 3 个 **+** `r1.idx`(24B)、`r2.idx`(24B)、`r3.idx`(24B) |

播种实证：

```
slot 0 = mods/Dragon/data/ranger.idx (24B)；slot 1~3 size = -1（播种前）
SeedSaveSlot(1..3) → 返回 mods 路径
r1/r2/r3.idx == MOD ranger.idx  → True
r1/r2/r3.idx == baseline         → False
```

实验后已用 `cp -r` 恢复并 `cmp` 校验 **27/27**。

**Then** 修正结论已同步到 `allmods-dragon-activate` 的
`spec.md` REQ-DRG-11、`tasks.md` §11、`proposal.md`、`design.md` ADR-007。

---

## REQ-DRGV-14：8 道门禁全绿（实跑）

**Given** 前 10 个 slice 已固定的 8 道门禁，
**When** 全部实跑，
**Then** 每道门禁的判定值必须达到阈值，且可复跑。

| # | 门禁 | 阈值 | 实测 |
|---|------|------|------|
| 1 | `tests/test_runner.lua` | 全绿 | **1842/1842 pass**（连跑两次幂等） |
| 2 | `mod_build --verify-pascal` | `mismatches=0` | **0**（`known-deviations=3`） |
| 3 | `mod_build --all` | 20 mods / 0 build failures | **20 / 0**（5 项 `annotated-problematic` 为已知） |
| 4 | `mod_check` | 20/20 | **20/20** |
| 5 | `mod_audit --all --evidence` | `unclassified=0`, `bad_evidence=0` | **0 / 0**（`total=11220`, `in_product=9245`, `not_in_product=1975`, `evidence checked=17 failed=0`） |
| 6 | `format_spec --all` | `gaps=0` | **`formats=12 checked=6773 gaps=0`** |
| 7 | 20 MOD `save/` vs 源 | 0 问题 | **451 文件 0 问题** |
| 8 | 禁改路径 `git status` | 空 | **空** |

**注**：`mod_build --all` 退出码 1 是**设计行为**（`mod_build.lua:1224-1226`），
不作为失败判据。

---

## 非需求（Out of Scope，本 change 明确不做）

| 项 | 原因 |
|----|------|
| 修复 `not_in_product` 语义 | 需改 `mod_audit` 契约 + 同步 12 个既有 slice 口径（REQ-DRGV-6 / ADR-004） |
| 把 `cloud/title/open/end` 改判 `LEGACY` | 同上（REQ-DRGV-7 / ADR-004b） |
| 补 `fight101/102` 文件或改头像代号 | MOD 作者侧数据不一致，引擎已优雅降级（REQ-DRGV-5） |
| 删除 `data/name.*` / `data/war1.sta` | 保留「产物 = 源 + 转换」可追溯性（REQ-DRGV-8 / ADR-006） |
| 修复 `CC.Effect` 53 项截断 | 属 epic 级 spike（`allmods-effect-table`），Dragon 的 eft id max=52 未触发 |
