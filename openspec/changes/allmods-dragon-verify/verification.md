# Verification: allmods-dragon-verify

> Change: `allmods-dragon-verify`
> 判据原则：**唯一权威 = 当前工作树 + 实测命令输出**。下列每条均为本工作树实跑结果。
> 全部命令从 `game/` 目录执行，运行前 `rm -f active_mod.txt`。

---

## 总览

| REQ | 主题 | 结论 |
|-----|------|------|
| REQ-DRGV-1 | `diff.md` 双向 set 相等 | ✅ `254/254`、`25/25`，双向差集 `[]` |
| REQ-DRGV-2 | 254 项结构分解 | ✅ `119+119+16=254` |
| REQ-DRGV-3 | 16 项非 fight 逐字节 | ✅ 15 全等 + 1 构建生成 |
| REQ-DRGV-4 | `war1.sta` 双判定不矛盾 | ✅ 五维度实测 |
| REQ-DRGV-5 | `fight101/102` 优雅降级 | ✅ 0,0 vs 正对照 33×63… |
| REQ-DRGV-6 | `not_in_product` 语义纠正 | ✅ `4 + 252 = 256` |
| REQ-DRGV-7 | `cloud/title/open/end` 无运行时消费者 | ✅ 4 类 0 命中 |
| REQ-DRGV-8 | `name.*` = `talk.*` 副本 | ✅ md5 相同 ×2 |
| REQ-DRGV-9 | `kysmod.ini` 生效反向对照 | ✅ 10 项 `nil → 有值`（**已修正字段名与伪证据**） |
| REQ-DRGV-10 | 内容真实性四类证据 | ✅ 4/4 |
| REQ-DRGV-11 | Scene 内容负对照 | ✅ `[2]` 雪山 vs 云鶴崖 |
| REQ-DRGV-12 | `hdgrp` 267 索引驱动 | ✅ `1068/4 = 267` |
| REQ-DRGV-13 | 存档槽播种修正 | ✅ 源 3 idx / 产物 6 idx |
| REQ-DRGV-14 | 8 道门禁 | ✅ 8/8（门禁 7 口径已修正） |

**14/14 全部通过**，其中 3 项在验证过程中**推翻了初稿结论**（REQ-DRGV-5/9/14）。

---

## REQ-DRGV-1：`diff.md` 双向 set 相等

```
$ python3 - <<'PY'   # 顶层文件名集合，剔除别名对
base = {n.lower() for n in os.listdir("data") if isfile}
mod  = {n.lower() for n in os.listdir("mods/Dragon/data") if isfile}
added   = mod  - base - {"sdx","smp","wdx","wmp"}
removed = base - mod  - {"smap.idx","smap.grp","wmap.idx","wmap.grp"}
PY
added:   diff=254 actual=254 equal=True   diff-only=[] actual-only=[]
removed: diff=25  actual=25  equal=True   diff-only=[] actual-only=[]
```

**结论**：双向 set 相等，非仅计数相等。✅

**关键前提**：`diff.md` 由 `mod_build.lua:1065 buildDiff` 生成，
其 `dataFileSet`（`:1057`）只 `listDir` **顶层**文件名，故比对必须同为单层集合。

---

## REQ-DRGV-2 / REQ-DRGV-3：254 项分解与 16 项非 fight 逐字节

```
=== 16 项非 fight 逐字节校验（源 vs 产物）===
  cloud.grp           38120B  ✅     name.grp           211697B  ✅
  cloud.idx              36B  ✅     name.idx            16080B  ✅
  end.png            490590B  ✅     open.png           188358B  ✅
  kdef.grp           190110B  ✅     ranger.str       源不存在（构建生成）
  kdef.idx             4348B  ✅     talk.grp           211697B  ✅
  kysmod.ini           1729B  ✅     talk.idx            16080B  ✅
  talkutf8.txt       311989B  ✅     title.grp           10050B  ✅
  title.idx              36B  ✅     war1.sta            66030B  ✅
```

`kysmod.ini` 源在 MOD **根目录**（非 `resource/`）：
`md5 de0dd0769df2e156ce8fe4bef6d1b37c` 两侧相同。
`ranger.str` 35898B 由 `mod_build.lua:1174` `E.SerializeSideTable(enc.side)` 生成。

**结论**：15 字节全等 + 1 构建生成 = 16；`119+119+16 = 254`。✅

---

## REQ-DRGV-4：`war1.sta` 双判定

```
源存在        ✅ 66030B（66030 ÷ 186 = 355 记录，CC.WarDataSize=186）
产物存在      ✅ 66030B，md5 = 源
基线存在      ❌
CC.WarFile    "war.sta"（jyconst.lua:129），不含 war1
grep -rn "war1" script/ framework/ engine-love2d/   → 0 命中
mod_audit.lua:189  category="DEAD_FILE", needed=false
```

**结论**：「新增了它」（vs 基线）与「引擎不读它」同时成立，两判定回答不同问题。✅

**必须与 RiverLake 区分**（见 design ADR-006）：

| | RiverLake `allsinbk.grp` | Dragon `war1.sta` |
|---|---|---|
| 归属 | 基准独有（D 类） | MOD 独有 |
| 常量 | ✅ `CC.TempS_Filename` | ❌ |
| 传参 | ✅ 入 `LoadSMap` | ❌ |
| 性质 | 「回退到的文件是死的」 | 「新增的文件是死的」 |

---

## REQ-DRGV-5：`fight101/102` 优雅降级（**带正对照**）

```
=== 数据引用 ===
有头像代号: 588 / 589     max: 219
引用 101: 1 条   引用 102: 1 条

=== 文件存在性 ===
mods/Dragon/data/fight101.idx exists=false
mods/Dragon/data/fight102.idx exists=false
mods/Dragon/data/fight103.idx exists=true

=== 缺失：fight101 ===
PicLoadFile pcall=true err=nil
PicGetXY(4, 0) -> w=0 h=0     PicGetXY(4, 2) -> w=0 h=0
PicGetXY(4, 4) -> w=0 h=0     PicGetXY(4, 6) -> w=0 h=0

=== 正对照：fight103（存在）===
PicLoadFile pcall=true err=nil
PicGetXY(4, 0) -> w=33 h=63   PicGetXY(4, 2) -> w=74 h=67
PicGetXY(4, 4) -> w=74 h=70   PicGetXY(4, 6) -> w=72 h=69
```

代码路径：
`FileLength` → `-1`（`lib_love.lua:283-289`）→ `PicLoadFile` 早退
（`:435` `if idxlen<0 or grplen<0 then return`）→ `PicFile:getPic` 返回 `nil`
（`:269-273`）→ `PicGetXY` 返回 `0,0,0,0`（`:465-468`）。

### ⚠ 推翻初稿：`PicGetXY` 裸调不是合法证据

初稿曾用「`PicGetXY` 直接返回 0」作降级证据。实测**未先 `PicLoadFile`** 时：

```
./engine-love2d/lib_love.lua:462: attempt to index a nil value (field '?')
stack traceback: ... in function 'PicGetXY'
```

原因：`picFileCache[fileid]` 为 `nil`（`:462` `picFileCache[fileid]:getPic(picid)`）。
这是**调用前置条件不满足**导致的 Lua 错误，与 MOD 数据无关，
**不能混入「优雅降级」证据**。已改为「先 `PicLoadFile` 再 `PicGetXY`」+ 正对照。

**结论**：缺失 → `0,0`；存在 → 真实尺寸；两者 `pcall` 均 `true`。判据成立。✅

---

## REQ-DRGV-6：`not_in_product` ≠ 物理缺失

```
not_in_product = 256
  物理存在于产物 = 4
    resource/name.grp        [LEGACY]
    resource/name.idx        [LEGACY]
    resource/talkutf8.txt    [BUILD_INPUT]
    resource/war1.sta        [DEAD_FILE]
  物理确实缺失     = 252
  4 + 252 = 256 ✅
```

根因 `tools/mod_audit.lua:453-462` `checkInProduct`：

```lua
if rule.in_product == false then return false end                    -- 关卡 1
if rule.in_product ~= true and not IN_PRODUCT_BY_CATEGORY[cat] then
    return false end                                                 -- 关卡 2（类别）
for _, p in ipairs(productCandidates(...)) do ... end                 -- 关卡 3（物理）
```

`IN_PRODUCT_BY_CATEGORY`（`:48`）中 `LEGACY`/`DEAD_FILE`/`BUILD_INPUT` 均为 `false`
⇒ **关卡 2 直接否决，从未走到物理检查**。

**结论**：`not_in_product` 实际语义 = 「**非必需产物成员**」（类别否 ∪ 物理缺）。
判为命名/语义不精确，**本 change 不修复**（改则需同步 12 个既有 slice 口径）。✅

---

## REQ-DRGV-7：`cloud/title/open/end` 无运行时消费者

```
$ grep -rn "cloud" --include=*.lua script/ framework/ engine-love2d/          → 0
$ grep -rn "title\.grp\|title\.idx" --include=*.lua script/ framework/ engine-love2d/ → 0
$ grep -rn "open\.png" --include=*.lua script/ framework/ engine-love2d/      → 0
$ grep -rn "end\.png" --include=*.lua script/ framework/ engine-love2d/       → 1
script/jymain.lua:4273:  lib.LoadPicture(CONFIG.PicturePath .."end.png",-1,-1);
```

`CONFIG.PicturePath = "pic/"`（`framework/config.lua:42`）⇒ 运行时读 **`game/pic/end.png`**：

```
ea0d61322986047ca9ffc3560e76f6f0  game/pic/end.png            ← 实际读取（基线）
b538413b06463521c56302e6a7b0649d  game/mods/Dragon/data/end.png
b538413b06463521c56302e6a7b0649d  reference/allmods/kys-Dragon/resource/end.png
```

`CC.CloudPicFile`/`CC.TitlePicFile`/`CC.OpenFile`/`CC.EndFile` 实测全部 `nil`。

覆盖度：`title.*`/`open.png`/`cloud.*` **20/20**；`end.png` **16/20**。

归类来源 = `mod_audit.lua:264-269` `BY_KIND`
（`resource|.grp` / `resource|.idx` / `resource|.png` → `REQUIRED`）**兜底**，
非按「Lua 引擎实际读取」判定。

**结论**：C 引擎资源，Lua 引擎未接入；归类保守（多带文件，无害）。
**不改判定**（见 design ADR-004b）。✅

---

## REQ-DRGV-8：`name.*` = `talk.*` 副本

```
4c41c044413860015bd626d480e36951  resource/name.grp   = resource/talk.grp
1a0c74ab1dd84e8714a5b4fd1ed22488  resource/name.idx   = resource/talk.idx
```

| 文件 | 运行时引用 | 构建期引用 |
|------|:----------:|-----------|
| `data/name.grp` | **0** | 0 |
| `data/talk.grp` | **0** | ✅ `mod_build.lua:916` 提取 → `script/oldtalk.{grp,idx}` |

`CC.TalkGrpFile = CONFIG.ScriptPath .. "oldtalk.grp"`（`jyconst.lua:134`）
指向**构建产物**，不是 `data/talk.grp`。

分布：4/20 MOD 有 `name.*`（BookCalamity / Dragon / RiverLake / pineapple）。

**结论**：MOD 作者历史遗留副本 + 「`resource/` 一律展平复制」契约，非缺陷。✅

---

## REQ-DRGV-9：`kysmod.ini` 生效（**两处修正**）

```
=== A) 未激活（基线，SetGlobalConst() 后）===
  CC.MaxLevel=nil  CC.MaxHP=nil  CC.MaxMP=nil  CC.MaxPhysicalPower=nil
  CC.MaxItemAmount=nil  CC.ItemBeginPic=nil  CC.MaxWeaponMatch=nil
  CC.MinKnowledge=nil  CC.LifeHurt=nil  CC.ExpRate=nil
  CC.MoneyID=174        ← 基线已定义（jyconst.lua:435）

=== B) 激活 Dragon ===
  CC.MaxLevel=60  CC.MaxHP=999  CC.MaxMP=9999  CC.MaxPhysicalPower=100
  CC.MaxItemAmount=200  CC.ItemBeginPic=4131  CC.MaxWeaponMatch=7
  CC.MinKnowledge=80  CC.LifeHurt=10  CC.ExpRate=1
  CC.MoneyID=174        ← 与基线同值
```

### 推翻初稿 #1：字段名错误

初稿写 `CC.LIFE_HURT = 10`。实测 `CC.LIFE_HURT` 恒为 `nil`。
正确字段是 **`CC.LifeHurt`**：`framework/mod_ini.lua:187`
`life_hurt = { {"CC", "LifeHurt"} }`。

### 推翻初稿 #2：`MoneyID` 是伪证据

`jyconst.lua:435` 已有 `CC.MoneyID=174`，基线态即 174。
`kysmod.ini` 的 `MONEY_ID = 174` 与基线**同值**，无法区分「ini 注入」与「基线默认」。

**结论**：有效证据 = **10 项** `nil → 有值`（非初稿所称 11 项含 `MoneyID`）。✅

---

## REQ-DRGV-10：内容真实性四类证据

```
Person 589  Thing 237  Scene 106  Wugong 114

Person[0]   = 資          Person[588] = 李卡多
Thing[0]    = 小還丹      Thing[236]  = 真武劍
Scene[0]    = 胡斐居      Scene[105]  = 西部農村
Wugong[0]   = 普通攻擊    Wugong[113] = 閃電貂

mods/Dragon/script/oldevent/*.lua  = 1087 个
oldtalk.idx = 16080B → 4020 条目
oldtalk.grp = 318143B → 4021 行
  [1]    = 小兄弟，到此寒天雪地，不知有何指教？
  [4018] = 国家兴亡，匹夫有责！兄弟，我也来帮你吧。
```

**结论**：4 类证据（边界值 / 事件 / 对话 / ini 常量）全部直接命中。✅

---

## REQ-DRGV-11：Scene 内容负对照

```
Scene[  0] = 胡斐居      （基线 胡斐居，同）
Scene[  1] = 河洛客棧    （基线 河洛客棧，同）
Scene[  2] = 雪山        （基线 云鶴崖，异）✅
Scene[ 50] = 閰基居
Scene[105] = 西部農村
基线 Scene[80]=絕情谷底、Scene[83]=圣堂
```

Scene 记录数 106 = 106，**记录数相等但内容不同** ⇒ 负对照判据成立（第 5 次应用）。✅

---

## REQ-DRGV-12：`hdgrp` 267

```
resource/hdgrp.idx = 1068B → 1068/4 = 267
resource/eft.idx   = 2856B → 2856/4 = 714（与基线同，md5 未变）
```

引擎读取方式 `engine-love2d/lib_love.lua:437` `local num = idxlen/4`，
`CC.HeadPicFile` 只有路径无长度常量 ⇒ 索引驱动。
外推链：125 / 129 / 173 / 178 / 204 / 252 / **267**。

`format_spec --all` 对 `hdgrp` 族 `gaps=0`（见 REQ-DRGV-14 门禁 6）。✅

---

## REQ-DRGV-13：存档槽播种

```
源 save/:   alldef.grp/.idx  allsin.grp/.idx  ranger.grp/.idx
            d1..d6,d11  r1..r6,r11  s1..s6,s11        ← 无 r1.idx/r2.idx/r3.idx
产物 save/: d1..d6,d11  r1..r6,r11  s1..s6,s11  ranger.grp  ranger.idx
```

`mod_build.lua:665-670` 按 `isSaveSlotFile`（`:626-631`，`^[rds]%d+%.(grp|idx)$`）
把 `save/` 分两类：**槽文件 → `mods/<m>/save/`**（341 个），
**模板 → `mods/<m>/data/`**（110 个，含 `ranger.*`/`alldef.*`/`allsin.*`）。

播种实证（activate 阶段）：

```
slot 0 = mods/Dragon/data/ranger.idx (24B)
slot 1~3 size = -1（播种前）
SeedSaveSlot(1..3) → 返回 mods 路径
r1/r2/r3.idx == MOD ranger.idx → True
r1/r2/r3.idx == baseline        → False
```

实验后 `cp -r` 恢复并 `cmp` 校验 27/27。

**修正**：activate 初稿曾断言「源 `save/` 无 `.idx` 槽 ⇒ 无首次播种」——**错误**。
源含 3 个 `.idx`（`alldef.idx` 336B、`allsin.idx` 336B、`ranger.idx` 24B），
缺的是 `r1~r3.idx`（由 `ModData.SeedSaveSlot` 播种）。
已同步修正 activate 的 `spec.md` REQ-DRG-11、`tasks.md` §11、`proposal.md`、
`design.md` ADR-007。✅

---

## REQ-DRGV-14：8 道门禁（逐条实跑）

### 门禁 1：单元测试

```
$ lua tests/test_runner.lua
总测试数: 1842
通过: 1842
失败: 0
✓ 所有测试通过!
```

### 门禁 2：原版基线

```
$ lua tools/mod_build.lua --verify-pascal
[mod_build] pascal baseline: events=1018, mismatches=0, known-deviations=3
  [known] event 320: 原版提取器将同目标的相邻条件渲染为 if/else（等价嵌套形式）
  [known] event 655: 原版提取器丢弃了 2 个 instruct_43 守卫（二进制中存在）
  [known] event 691: 原版提取器丢弃了重复的 instruct_27（二进制中存在）
[mod_build] pascal baseline: PASS
```

### 门禁 3：全量构建

```
$ lua tools/mod_build.lua --all
[mod_build] all: 20 mods, 0 build failures, 5 annotated-problematic
退出码 = 1
```

`mod_build.lua:1222-1224`：`if #failed > 0 or #problems > 0 then os.exit(1) end`
—— 5 项 `annotated-problematic` 来自 `games.ini` 的作者标注，
**退出码 1 属设计行为，不是失败**。

### 门禁 4：产物自检

```
$ lua tools/mod_check.lua
总计: 20 MOD, 通过 20, 失败 0
```

### 门禁 5：全量审计

```
$ lua tools/mod_audit.lua --all --evidence
total=11220 in_product=9245 not_in_product=1975 unclassified=0 bad_evidence=0
  REQUIRED 9145  REQUIRED_CONVERTED 80  LEGACY 68  DEAD_FILE 2
  EDITOR_DUMP 1220  BUILD_INPUT 30  PLATFORM_ARTIFACT 12  PENDING 663
evidence: checked=17 failed=0
```

### 门禁 6：全量格式

```
$ lua tools/format_spec.lua --all
formats=12 checked=6773 gaps=0
```

### 门禁 7：存档一致（**口径已修正**）

```
源 save/ 文件数 = 451
  逐字节一致    = 430
  差异          = 21    ← ranger.grp ×20 + ranger.idx ×1(zheng)
  真实问题      = 0
```

**初稿错误**：`epic.md:781` 与 activate `verification.md` 曾写「451 文件，不一致 = 0」。
实测 21 项差异全部是**设计内转换**：

| 项 | 数量 | 机制 | 证据 |
|----|-----:|------|------|
| `ranger.grp` | 20 | Big5→UTF-8，字符串区写固定宽度 hint，真实值进 `data/ranger.str` | Dragon：`17646/174230 = 10.1%` 字节变化；产物含 **589** 个 `P####` hint = 589 条 Person 记录；源 0 个 |
| `ranger.idx` | 1（zheng） | 源 idx 描述 138596B 而 grp 仅 114242B ⇒ `ModEncoding.RepairIdx`（`:248`）按字节重建 | zheng 源 offs `(836,65992,104182,109070,138446,138596)` → 产物 `(836,59076,97076,101444,114092,114242)` |

Dragon 的 `ranger.idx` 本身一致（`IdxIsConsistent` 通过）故未修，
其与源的差异来自 `pendingIdx` 段偏移修复路径（`mod_build.lua:862-877`）。

`tests/unit/test_mod_resources.lua:465` `testProductSaveSlotMatchesSource` 判的是
**槽文件**（`save/` ↔ 源 `save/`，341 个），不覆盖模板类（110 个）；
故该测试 PASS 与「ranger 被转换」不矛盾，但**不能据此宣称「451 全等」**。

### 门禁 8：禁改路径

```
$ git status --porcelain -- game/engine-love2d game/engine-mud reference/allmods
（空）

$ git diff -U0 -- game/script/jyconst.lua | grep -E "^[+-]\s*CC\.[A-Za-z_]+="
（空）
```

`jyconst.lua` 有 `+11/−1`，但**无任何 `CC.*=` 常量定义行被增删**；
新增内容是 `allmods-data-fallback` 的 `ModData.RewriteConstants` / `ApplyLayout`
接线（`:627-637`），属既有 change 产物。

**8/8 全绿**，其中门禁 7 口径由「不一致 = 0」精确化为「430 全等 + 21 设计内转换」。✅

---

## 偏差汇总（相对 activate 初稿）

| # | 初稿断言 | 实测 | 处理 |
|---|----------|------|------|
| 1 | `CC.LIFE_HURT = 10` 证明 ini 生效 | `CC.LIFE_HURT` 恒 `nil`；正确字段 `CC.LifeHurt = 10`（`mod_ini.lua:187`） | ✅ 已修正 spec/verification |
| 2 | `CC.MoneyID` 为 ini 生效证据 | 基线 `jyconst.lua:435` 已定义 174，两侧同值 | ✅ 已剔除，有效证据 11→**10** 项 |
| 3 | 源 `save/` 无 `.idx` ⇒ 无首次播种 | 源含 3 个 `.idx`，缺 `r1~r3.idx`（播种 3 个） | ✅ activate 已同步修正（ADR-007） |
| 4 | 门禁 7「451 文件，不一致 = 0」 | 430 全等 + 21 设计内转换，真实问题 0 | ✅ 已修正 activate/verification.md + epic.md |
| 5 | `PicGetXY` 裸调可作降级证据 | 未先 `PicLoadFile` 会抛 Lua 错误（`:462`） | ✅ 改为「先载入 + 正对照」 |

---

## 未在本次修复（Out of Scope）

| 项 | 原因 |
|----|------|
| `not_in_product` 语义/改名 | 需改 `mod_audit` 契约 + 同步 12 个既有 slice（ADR-004） |
| `cloud/title/open/end` 改判 `LEGACY` | 同上（ADR-004b） |
| `fight101/102` 补文件 / 改头像代号 | MOD 作者侧数据不一致（REQ-DRGV-5） |
| 删 `data/name.*` / `data/war1.sta` | 保留可追溯性（ADR-006） |
| `CC.Effect` 53 项截断 | epic 级 spike；Dragon eft id max=52 未触发 |

---

## 字段/格式支持复核（2026-10-29 补）

> 本节回答：**本 MOD 用到的每个字段与格式，是否都有真实的引擎/构建期消费者支持？**

### 1. 逐格式实测（当前工作树）

```
$ cd game && lua tools/format_spec.lua --mod Dragon
formats=14 checked=537 gaps=0
```

| 格式 | 族 | 本 MOD 记录数 | 消费者 |
|------|-----|--------------|--------|
| fight | `idx_grp_rle` | **209** | `lib_love.PicLoadFile` |
| sound | `wav_pcm` | **80** | `lib_love.PlayWAV` |
| png | `png_image` | 222 | `lib_love.PicLoadFile`（head/ 直接 PNG） |
| list (`*.bin`) | `bin_table` | 5 | `ModData.LoadEffectTable`（本轮修复，见 §3） |
| save 槽 | `save_slot` | 0 | `jymain.LoadRecord` |
| allsin/alldef | `grid_save` | 2 | `lib_love.LoadSMap`（定长 uint16 网格） |
| 其余单例格式 | 见 spec | 各 1 | 见 `format_spec.lua` 的 `consumer` 字段 |
| **合计** | | **537** | `gaps=0` |

### 2. 数字修正（勘误）

| 旧记录 `formats=12 checked=535` | **已过时**（当时真实值，但 `formats` 计数与 `checked` 均已被补注册改变） |
| 现值 | `formats=14 checked=537 gaps=0`（+2） |

`formats=12 → 14` 的原因：`allsin` / `alldef` 被补注册为 `grid_save` 族
（每 MOD 各 1 条记录），故 `formats` +2。`+2` 之外无变化，说明本 MOD 其余格式
**从未少验** —— 旧数字只是过时，不是缺陷。

### 3. 真实支持缺口 —— **已修复**（2026-10-29 更新）

`list/*.bin`（本 MOD 有 **5** 个）原为**引擎完全不读**，现已由
`openspec/changes/allmods-list-bin-support` **落地修复**：

| 文件 | 原状态 | 现状态 |
|------|--------|--------|
| `effect.bin` | 构建器不搬 + 引擎硬编码 53 项替代 | **进产物** `data/effect.bin` + `ModData.LoadEffectTable` 装载，`CC.Effect` 取真实条目数 |
| `match.bin` | 构建器不搬 | **进产物** `data/match.bin`（`CC.ExtraOffense` 的数据侧） |
| `leave.bin` / `levelup.bin` / `*.txt` | 不搬 | **维持不进产物**（`LEGACY`，引擎零消费，有 evidence） |

**实测证据**（详见 `allmods-list-bin-support/verification.md`）：

- `effect.bin` / `match.bin` 在 **20/20** MOD 上逐字节一致地进入 `data/`
- 运行时 `CC.Effect` 项数：pascal **64** / BookCalamity **200**（原硬编码 53）
- `mod_audit` 的 `PENDING` **663 → 581**（`.bin` 残留 **0**），`in_product` **9245 → 9285**
- 负向对照：3 项短文件→`3`、删文件→`53` 兜底、恢复→`64`（三者互斥）

⇒ 本 MOD 的 `effect.bin` 超过 53 项时，`eft >= 53` 的静默退化**已消除**。

### 4. 20 MOD 横向对照

（禁止只报自身数字）

| MOD | total | fight | sound | png | list | slots |
|-----|-------|-------|-------|-----|------|-------|
| mingdong | 831 | 267 | 201 | 338 | 4 | 0 |
| BookCalamity | 589 | 327 | 234 | 2 | 5 | 0 |
| Dragon | 537 | 209 | 80 | 222 | 5 | 0 |
| GodsDevils | 477 | 92 | 78 | 282 | 4 | 0 |
| RiverLake | 415 | 219 | 170 | 1 | 4 | 0 |
| awaken | 342 | 237 | 79 | 1 | 4 | 0 |
| pig3dos | 328 | 180 | 111 | 3 | 4 | 9 |
| ptt | 319 | 162 | 78 | 54 | 4 | 0 |
| pineapple | 300 | 154 | 109 | 3 | 4 | 9 |
| books | 295 | 178 | 84 | 2 | 4 | 6 |
| lyff | 244 | 138 | 78 | 3 | 4 | 0 |
| pig | 243 | 137 | 78 | 3 | 4 | 0 |
| dream | 227 | 123 | 77 | 2 | 4 | 0 |
| loving | 212 | 107 | 77 | 3 | 4 | 0 |
| lostbook | 203 | 97 | 78 | 3 | 4 | 0 |
| HeavenSword | 200 | 93 | 78 | 3 | 4 | 1 |
| SweeOan | 198 | 92 | 78 | 3 | 4 | 0 |
| stronger | 198 | 92 | 78 | 3 | 4 | 0 |
| zheng | 197 | 92 | 78 | 2 | 4 | 0 |

本 MOD `total=537`，在 20 个 MOD 中排 **第 3**。

### 5. 结论

| 维度 | 结论 |
|------|------|
| 字段级覆盖 | ✅ `gaps=0`，537 条记录字节全覆盖 |
| 引擎消费者 | ✅ 除 `list/*.bin` 外全部有真实消费者 |
| `list/*.bin` | ⚠ 已知缺口，由 `allmods-list-bin-support` 修复 |
| 数字准确性 | ✅ 本节已纠正旧记录 |
