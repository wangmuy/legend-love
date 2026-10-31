# Dragon（苍龙逐日）验证报告

> Change: `allmods-dragon-verify`　|　Slice 11　|　第 4 梯队第 2 个
> MOD 源：`reference/allmods/kys-Dragon`　产物：`game/mods/Dragon`
> 所有数字均由本工作树实测，命令从 `game/` 执行，运行前 `rm -f active_mod.txt`。

---

## 1. 结论摘要

| 维度 | 结论 |
|------|------|
| 构建 | ✅ `data=458 saves=21 sound=80 events=1087 talk=4020` |
| 审计 | ✅ `total=811 in_product=555 not_in_product=256 unclassified=0 bad_evidence=0` |
| 格式 | ✅ `formats=12 checked=535 gaps=0` |
| 启动 | ✅ `RESULT Dragon: OK`，16/16 断言 PASS |
| 记录段 | ✅ `589 / 237 / 106 / 114`（Person 182B / Thing 190B / Scene 52B / Wugong 136B） |
| 内容真实性 | ✅ 四类直接证据全命中（边界值 / 1087 事件 / 4020 对话 / 10 项 ini 常量） |
| `diff.md` | ✅ 双向 set 相等（`254/254`、`25/25`） |
| 8 道门禁 | ✅ 8/8（门禁 7 口径已修正，见 §6.7） |
| 缺陷 | **0**（新增 3 条「精度发现」，均不属缺陷） |

**一句话**：Dragon 是第 4 梯队中数据规模最大、`hdgrp` 条目最多（267）、
唯一删除战斗贴图（`fight101/102`）的 MOD；构建、审计、格式、启动、内容五方面全部通过，
无工具缺陷。

---

## 2. 与基线的结构性差异

### 2.1 三层规模对照

| 层 | 基线（pascal） | Dragon | 变化 |
|----|---------------:|-------:|------|
| `resource/` 源文件总数 | — | **811** | — |
| 构建产物 `data/` 文件数 | — | **458** | — |
| `save/` | 21 | **21** | 同 |
| `sound/` | — | **80** | — |
| 事件（`kdef` 提取） | 1018 | **1087** | +69 |
| 对话（`talk` 提取） | — | **4020** | — |
| `hdgrp` 条目 | 115 | **267** | **+152** |
| `eft` 条目 | 714 | **714** | 0（md5 同） |
| `fight*.grp` | 92 | **209** | **+117**（+119 −2） |
| 记录段 | 320/200/84/93 | **589/237/106/114** | 全面扩张 |

### 2.2 `hdgrp` 267 —— 索引驱动判据（第 7 次应用）

```
resource/hdgrp.idx = 1068B  →  1068 / 4 = 267
engine-love2d/lib_love.lua:437   local num = idxlen/4
```

无固定计数常量（`CC.HeadPicFile` 只有路径，无长度）。
外推链：**125 → 129 → 173 → 178 → 204 → 252 → 267**，
每次都在不改进代码的前提下被索引自然容纳。

`format_spec --all` 对 `hdgrp` 族 `gaps=0`。

### 2.3 `ranger.idx` 段边界

```
offsets = [836, 108034, 153064, 158576, 174080, 174230]
段长    = (107198, 45030, 5512, 15504, 150)
÷ 记录长 = (589, 237, 106, 114, 3)      余数全 0
Σ = 173394    grp = 174230（尾部 836B 头部 + 1470B 尾部）
```

**四段全部与基线不同**（判据第 4 次应用），故不能靠「段长整除」判断
「加载了 MOD 数据」，必须有内容证据（见 §3）。

---

## 3. 内容真实性（四类直接证据）

记录数正确只是**结构**证据。前 10 个 slice 的教训是：结构对了内容也可能没加载。

### 3.1 记录边界值（8 项）

| 段 | 首记录 | 末记录 |
|----|--------|--------|
| Person | `資`（天下奇男子） | `李卡多` |
| Thing | `小還丹` | `真武劍` |
| Scene | `胡斐居` | `西部農村` |
| Wugong | `普通攻擊` | `閃電貂` |

### 3.2 事件（`kdef` 提取）

```
$ ls mods/Dragon/script/oldevent/*.lua | wc -l
1087
```

与构建报告 `events=1087` **完全一致**。

### 3.3 对话（`talk` 提取）

```
oldtalk.idx = 16080B → 4020 条目（= 构建报告 talk=4020）
oldtalk.grp = 318143B → 4021 行
  [1]    = 小兄弟，到此寒天雪地，不知有何指教？
  [4018] = 国家兴亡，匹夫有责！兄弟，我也来帮你吧。
```

### 3.4 Scene 内容负对照（第 5 次应用）

| 索引 | Dragon | 基线 | 判 |
|-----:|--------|------|----|
| 0 | 胡斐居 | 胡斐居 | 同 |
| 1 | 河洛客棧 | 河洛客棧 | 同 |
| 2 | **雪山** | 云鶴崖 | **异** ✅ |
| 50 | 閰基居 | — | — |
| 105 | 西部農村 | — | — |
| 80 | — | 絕情谷底 | — |
| 83 | — | 圣堂 | — |

**Scene 记录数 106 = 106，但内容不同** ⇒ 记录数相等 ≠ 内容相同。

---

## 4. `kysmod.ini` 常量覆盖（反向对照）

基线态这些 `CC.*` **根本不存在**，激活后才出现：

| 常量 | 基线 | 激活 Dragon |
|------|:----:|:-----------:|
| `CC.MaxLevel` | `nil` | **60** |
| `CC.MaxHP` | `nil` | **999** |
| `CC.MaxMP` | `nil` | **9999** |
| `CC.MaxPhysicalPower` | `nil` | **100** |
| `CC.MaxItemAmount` | `nil` | **200** |
| `CC.ItemBeginPic` | `nil` | **4131** |
| `CC.MaxWeaponMatch` | `nil` | **7** |
| `CC.MinKnowledge` | `nil` | **80** |
| `CC.LifeHurt` | `nil` | **10** |
| `CC.ExpRate` | `nil` | **1** |

**10 项 `nil → 有值`** ⇒ ini 确实被 `framework/mod_ini.lua` 解析并注入，
不是「默认值恰好相同」。

### 两处修正

| 初稿 | 实测 |
|------|------|
| `CC.LIFE_HURT = 10` | 该字段**不存在**（恒 `nil`）；正确名 **`CC.LifeHurt`**，映射见 `mod_ini.lua:187` |
| 把 `CC.MoneyID` 计入证据 | `jyconst.lua:435` 基线已定义 `=174`，两侧同值 ⇒ **伪证据**，已剔除 |

`CC.BEGIN_SCENE` / `Sx` / `Sy` 未被映射（实测 `nil`），属 ini 有键但映射表未覆盖。

---

## 5. `diff.md` 逐项审计

### 5.1 双向 set 相等（非计数相等）

```
added:   diff=254 actual=254 equal=True   diff-only=[] actual-only=[]
removed: diff=25  actual=25  equal=True   diff-only=[] actual-only=[]
```

**248 项之外无遗漏，也无多余**。判据用 set 而非 count，排除「两项错位、总数相同」。

### 5.2 MOD 独有 254 的结构

| 类别 | 项数 |
|------|-----:|
| `fight*.grp` | 119 |
| `fight*.idx` | 119 |
| 非 fight | **16** |
| **Σ** | **254** |

### 5.3 16 项非 fight 逐项

| 文件 | 字节 | 源→产物 | 引擎消费者（实测） | 审计类别 |
|------|-----:|:-------:|--------------------|----------|
| `cloud.grp` | 38120 | ✅ | **0 命中** | REQUIRED（`BY_KIND`） |
| `cloud.idx` | 36 | ✅ | **0 命中** | REQUIRED（`BY_KIND`） |
| `title.grp` | 10050 | ✅ | **0 命中** | REQUIRED（`BY_KIND`） |
| `title.idx` | 36 | ✅ | **0 命中** | REQUIRED（`BY_KIND`） |
| `open.png` | 188358 | ✅ | **0 命中** | REQUIRED（`BY_KIND`） |
| `end.png` | 490590 | ✅ | 1 命中，但指向**基线** `pic/end.png` | REQUIRED（`BY_KIND`） |
| `kdef.grp` | 190110 | ✅ | **构建期** `mod_build.lua:893` | REQUIRED |
| `kdef.idx` | 4348 | ✅ | **构建期** 同上 | REQUIRED |
| `talk.grp` | 211697 | ✅ | **构建期** `mod_build.lua:916` | REQUIRED |
| `talk.idx` | 16080 | ✅ | **构建期** 同上 | REQUIRED |
| `talkutf8.txt` | 311989 | ✅ | 构建输入（编码探测） | BUILD_INPUT |
| `kysmod.ini` | 1729 | ✅（源在 MOD 根目录） | `framework/mod_ini.lua` | BUILD_INPUT |
| `ranger.str` | 35898 | —（**构建生成**） | `mod_data.lua:517` 旁路表 | 生成物 |
| `name.grp` | 211697 | ✅ | **0 引用** | LEGACY |
| `name.idx` | 16080 | ✅ | **0 引用** | LEGACY |
| `war1.sta` | 66030 | ✅ | **0 引用** | DEAD_FILE |

`kysmod.ini` md5 `de0dd0769df2e156ce8fe4bef6d1b37c`，源=产物。
`ranger.str` 由 `mod_build.lua:1174` `E.SerializeSideTable(enc.side)` 生成。

### 5.4 基准独有 25 的五分法

| 类 | 项数 | 明细 | 性质 |
|----|-----:|------|------|
| A | 9 | `d1~d3.grp`、`r1~r3.grp`、`s1~s3.grp` | 源无此文件，**不播种**；产物由 `test_runner` 自愈拷回，逐字节与基线一致 |
| B | 9 | 对应 `.idx` | 同上 |
| C | 2 | `thing.grp`、`thing.idx` | 基线 `data/` 专有（`CC.ThingPicFile` 回退） |
| D | 1 | `allsinbk.grp` | `tmpfilename` 形参零引用（`grep -c tmpfilename` = 1，仅签名） |
| **E** | **4** | `fight101.{grp,idx}`、`fight102.{grp,idx}` | **数据仍引用但资源缺失**（新增类） |
| **Σ** | **25** | | |

---

## 6. 三个独特之处（本 MOD 专属）

### 6.1 `fight101/102` 缺失 —— 数据仍引用、引擎优雅降级

Dragon 删除了基线的 `fight101`/`fight102`，但 `Person` 数据仍引用头像代号 101/102。

```
有头像代号: 588 / 589    max: 219
引用 101: 1 条    引用 102: 1 条

fight101.idx exists=false    fight102.idx exists=false    fight103.idx exists=true
```

**三级降级 + 正对照**：

| 场景 | `PicLoadFile` | `PicGetXY(4, 0/2/4/6)` |
|------|---------------|------------------------|
| `fight101`（缺失） | `pcall=true err=nil` | **0,0 / 0,0 / 0,0 / 0,0** |
| `fight103`（存在，正对照） | `pcall=true err=nil` | **33×63 / 74×67 / 74×70 / 72×69** |

链路：`FileLength` → `-1`（`lib_love.lua:283-289`）→ `PicLoadFile` 早退（`:435`）
→ `getPic` 返回 `nil`（`:269-273`）→ `PicGetXY` 返回 `0,0,0,0`（`:465-468`）。

**判定**：MOD 作者侧数据不一致。**不补文件、不改头像代号**。

> ⚠ 不能用 `PicGetXY` 裸调（未先 `PicLoadFile`）作证据 —— 此时
> `picFileCache[fileid]` 为 `nil`，会抛 `lib_love.lua:462 attempt to index a nil value`。
> 该错误源于**调用前置条件不满足**，与 MOD 数据无关。

### 6.2 `war1.sta` —— 两种判定不矛盾

| 维度 | 值 |
|------|-----|
| 源存在 | ✅ 66030B，`66030 ÷ 186 = 355` 记录 |
| 产物存在 | ✅ 66030B，md5 = 源 |
| 基线存在 | ❌ |
| `CC.WarFile` | `war.sta`（`jyconst.lua:129`），不含 `war1` |
| 代码引用 | `grep -rn "war1" script/ framework/ engine-love2d/` → **0** |
| 审计 | `mod_audit.lua:189` `DEAD_FILE, needed=false` |
| `diff.md` | MOD 独有 16 项之一 |

**不矛盾**：`DEAD_FILE` 回答「引擎需要读它吗？」（不需要）；
`diff.md` MOD 独有回答「它相对基线是新增的吗？」（是）。
**「新增但不用」** —— 两个判定都正确。

#### 与 RiverLake `allsinbk.grp` 必须区分

| 维度 | RiverLake `allsinbk.grp` | Dragon `war1.sta` |
|------|--------------------------|-------------------|
| 在 `diff.md` | **基准独有**（D 类） | **MOD 独有** |
| 常量 | ✅ `CC.TempS_Filename` | ❌ 无 |
| 传参 | ✅ 入 `LoadSMap` | ❌ 从不传 |
| 性质 | 「**回退到的**文件是死的」 | 「**新增的**文件是死的」 |

### 6.3 `head/` 220 PNG = EDITOR_DUMP（同族判定第 3 次）

四条机器可核验证据：

1. `tools/mod_build.lua:567` `IGNORE_DIRS = { head = true, item = true, eft = true }`
2. 引擎侧 `grep -rn "head/"` → **0 引用**
3. 产物中**无** `head/` 目录
4. 审计归类 `EDITOR_DUMP` = **220**，`evidence` 指向 `IGNORE_DIRS`

（同族：GodsDevils 279 / ptt 105 / Dragon 220）

---

## 7. 审计与「精度发现」

### 7.1 审计分类闭合

```
total=811  in_product=555  not_in_product=256  unclassified=0  bad_evidence=0
  REQUIRED 550  REQUIRED_CONVERTED 4  LEGACY 5  DEAD_FILE 1
  EDITOR_DUMP 220  BUILD_INPUT 2  PENDING 29
  Σ = 811 ✅
```

### 7.2 精度发现 ①：`not_in_product` ≠ 物理缺失

`not_in_product=256` 极易被读成「256 个文件不在产物里」。实测：

```
物理存在但 not_in_product = 4
  name.grp [LEGACY] / name.idx [LEGACY] / talkutf8.txt [BUILD_INPUT] / war1.sta [DEAD_FILE]
物理确实缺失              = 252
4 + 252 = 256 ✅
```

根因 `tools/mod_audit.lua:453-462`：

```lua
if rule.in_product == false then return false end                      -- 关卡 1
if rule.in_product ~= true and not IN_PRODUCT_BY_CATEGORY[cat] then
    return false end                                                   -- 关卡 2（类别）
for _, p in ipairs(productCandidates(...)) do ... end                   -- 关卡 3（物理）
```

`IN_PRODUCT_BY_CATEGORY`（`:48`）中 `LEGACY`/`DEAD_FILE`/`BUILD_INPUT` 均为 `false`
⇒ **关卡 2 直接否决，从未走到物理检查**。

**正确解读**：`not_in_product` = 「**非必需产物成员**」（类别否 ∪ 物理缺），
不是「产物中不存在」。判为**命名/语义不精确**，本 change **不修复**
（改则需同步 12 个既有 slice 口径 + `test_mod_audit.lua`）。

同现象存在于 BookCalamity / RiverLake / pineapple。

### 7.3 精度发现 ②：`cloud/title/open/end` 归类保守

6 个文件（`cloud.{grp,idx}`、`title.{grp,idx}`、`open.png`、`end.png`）
在 Lua 引擎中**无运行时消费者**：

```
cloud                      → 0 命中
title.grp / title.idx      → 0 命中
open.png                   → 0 命中
end.png                    → 1 命中，但读的是 CONFIG.PicturePath = "pic/" 下的基线文件
```

`CC.CloudPicFile`/`TitlePicFile`/`OpenFile`/`EndFile` 实测全 `nil`。

归类靠 `mod_audit.lua:264-269` `BY_KIND`（`resource|.grp/.idx/.png` → `REQUIRED`）
**兜底**，非按运行时读取。覆盖度 20/20（`end.png` 16/20）。

**判定**：C 引擎资源、Lua 引擎未接入；保守归类 = 多带文件 = 无害。
不改判定（改动会影响其余 19 个 MOD 的 `REQUIRED` 计数各 −6）。

### 7.4 `name.*` 是 `talk.*` 的副本

```
4c41c044413860015bd626d480e36951  name.grp = talk.grp
1a0c74ab1dd84e8714a5b4fd1ed22488  name.idx = talk.idx
```

`name.*` 运行时 **0 引用**（`EV_LEGACY_NAME`：人名来自 `ranger.grp`）；
`talk.*` 运行时也 0 引用，但**构建期** `mod_build.lua:916` 从中提取
`script/oldtalk.{grp,idx}`，而 `CC.TalkGrpFile = script/oldtalk.grp`。

**判定**：MOD 作者历史遗留副本 + 「`resource/` 一律展平复制」契约，非缺陷。
4/20 MOD 有该文件（BookCalamity / Dragon / RiverLake / pineapple）。

---

## 8. 8 道门禁

| # | 门禁 | 实测 | 判 |
|---|------|------|----|
| 1 | `tests/test_runner.lua` | **1842/1842 pass** | ✅ |
| 2 | `mod_build --verify-pascal` | `events=1018 mismatches=0 known-deviations=3` PASS | ✅ |
| 3 | `mod_build --all` | `20 mods, 0 build failures, 5 annotated-problematic`（退出码 1 属设计） | ✅ |
| 4 | `mod_check.lua` | **20 MOD，通过 20，失败 0** | ✅ |
| 5 | `mod_audit --all --evidence` | `total=11220 in_product=9245 not_in_product=1975 unclassified=0 bad_evidence=0`，`evidence checked=17 failed=0` | ✅ |
| 6 | `format_spec --all` | `formats=12 checked=6773 gaps=0` | ✅ |
| 7 | 20 MOD `save/` vs 源 | **451 文件，真实问题 0**（430 全等 + 21 设计内转换） | ✅ |
| 8 | 禁改路径 | `git status` 三处为空；`jyconst.lua` 无 `CC.*=` 定义行增删 | ✅ |

### 8.7 门禁 7 口径修正（重要）

初稿曾写「451 文件，不一致 = 0」。实测按 `mod_build` 真实路由复算：

```
源 save/ = 451
  逐字节一致 = 430
  差异       = 21   ← ranger.grp ×20 + ranger.idx ×1(zheng)
  真实问题   = 0
```

`mod_build.lua:665-670` 的 `isSaveSlotFile`（`:626-631`，`^[rds]%d+%.(grp|idx)$`）
把 `save/` 分两类：**槽文件 → `mods/<m>/save/`**（341 个），
**模板 → `mods/<m>/data/`**（110 个，含 `ranger.*`/`alldef.*`/`allsin.*`）。

21 项差异全部**设计内**：

| 项 | 数量 | 机制 | 证据 |
|----|-----:|------|------|
| `ranger.grp` | 20 | Big5→UTF-8 + 固定宽度 hint，真值进 `data/ranger.str` | Dragon：`17646/174230 = 10.1%` 字节变化；产物 **589** 个 `P####` hint = 589 条 Person 记录；源 0 个 |
| `ranger.idx` | 1（zheng） | 源 idx 描述 138596B 而 grp 仅 114242B ⇒ `ModEncoding.RepairIdx`（`:248`）重建 | 源 `(836,65992,104182,109070,138446,138596)` → 产物 `(836,59076,97076,101444,114092,114242)` |

Dragon 的 `ranger.idx` 自身一致，差异来自 `pendingIdx` 段偏移修复
（`mod_build.lua:862-877`）。

`tests/unit/test_mod_resources.lua:465` 判的是**槽文件**（341 个），
不覆盖模板类（110 个）⇒ 测试 PASS 与「ranger 被转换」不矛盾，
但**不能据此宣称「451 全等」**。

---

## 9. 缺陷与开放问题

### 9.1 本 MOD 缺陷数：**0**

Dragon 未暴露任何新的工具缺陷。前 10 个 slice 累计的 6 个工具缺陷
（A~F）在本 MOD 上均**未复现或已修复**：

| 缺陷 | 状态 |
|------|------|
| A（`format_spec` 段长误判） | 已修复，Dragon `gaps=0` |
| B（`mod_check_one` 删除产物存档） | 已修复，门禁 7 无残留 |
| C（`mod_audit` 证据缺失） | 已修复，`bad_evidence=0` |
| D（`talk` 提取行尾） | 已修复，4020 条目对得上 |
| E（`encoding` 截断） | 已修复，`ranger.str` 1057 行 |
| F（测试数 1622→1842） | 已修复，1842/1842 |

### 9.2 转入 epic 级 spike 的问题

| 问题 | 影响 | 处置 |
|------|------|------|
| `CC.Effect` 53 项截断 | 7/20 MOD | Dragon **未触发**（eft id max = 52 < 53）；已入 `TODO.md`，建议独立 change `allmods-effect-table` |
| `music/*.mid` 格式 | 20/20（Dragon 24 个 `.mid`） | 已入 `TODO.md` spike（MIDI `MThd` vs 引擎期望 OggS/RIFF） |
| `not_in_product` 语义 | 20/20 | 本报告 §7.2；已入 `TODO.md` |
| `cloud/title/open/end` 归类 | 20/20 | 本报告 §7.3；已入 `TODO.md` |

### 9.3 `PENDING` 29 项明细

```
list/effect.bin        list/leave.bin       list/levelup.bin
list/match.bin         list/match - 复制.bin
music/0.mid … music/23.mid（24 个）
```

- `list/*.bin` 5 个：`effect.bin` 见 §9.2 spike；其余 4 个 C 引擎列表，Lua 引擎未接入
- `music/*.mid` 24 个：MIDI 格式与引擎期望不符（spike）

---

## 10. 可复跑清单

```bash
cd game && rm -f active_mod.txt

# 构建
lua tools/mod_build.lua kys-Dragon    # 注意：构建器收源目录名（带 kys- 前缀）

# 审计 / 格式（注意：--mod 是选项，不是位置参数）
lua tools/mod_audit.lua --mod Dragon --evidence
lua tools/format_spec.lua --mod Dragon

# 适配自检（读环境变量 MOD_SLUG）
MOD_SLUG=Dragon lua tools/mod_check_one.lua

# 独立进程启动链路（位置参数 = 期望值，缺省则期望 nil 导致 5 项 FAIL）
lua tests/unit/boot_one_mod.lua Dragon 589 237 106 114 資

# 8 道门禁
lua tests/test_runner.lua
lua tools/mod_build.lua --verify-pascal
lua tools/mod_build.lua --all          # 全量（退出码 1 属设计）
lua tools/mod_check.lua
lua tools/mod_audit.lua --all --evidence
lua tools/format_spec.lua --all
```

### ⚠ 调用方式易错点（本次实测踩到）

| 错误写法 | 症状 | 正确写法 |
|----------|------|----------|
| `lua tools/mod_audit.lua Dragon --evidence` | 静默审计**全部 20 MOD**（输出 `total=11220`） | `--mod Dragon` |
| `lua tools/format_spec.lua Dragon` | 同上 | `--mod Dragon` |
| `lua tools/mod_check_one.lua Dragon` | `ERROR=MOD_SLUG not set` | `MOD_SLUG=Dragon lua tools/mod_check_one.lua` |
| `lua tests/unit/boot_one_mod.lua Dragon` | `RESULT Dragon: FAIL (5)`（`PersonNum 期望 nil`） | 补 5 个期望值位置参数 |
| `lua tests/boot_one_mod.lua Dragon …` | `No such file` | 路径是 `tests/unit/boot_one_mod.lua` |
| `lua tools/mod_build.lua --mod Dragon` | `BUILD FAILED: MOD 目录不存在: …/allmods/--mod` | `lua tools/mod_build.lua kys-Dragon`（构建器收带前缀的源目录名） |

单 MOD 实测（正确调用）：

```
$ lua tools/mod_audit.lua --mod Dragon --evidence
total=811 in_product=555 not_in_product=256 unclassified=0 bad_evidence=0
  REQUIRED 550  REQUIRED_CONVERTED 4  LEGACY 5  DEAD_FILE 1
  EDITOR_DUMP 220  BUILD_INPUT 2  PENDING 29
evidence: checked=12 failed=0

$ lua tools/format_spec.lua --mod Dragon
formats=12 checked=535 gaps=0

$ MOD_SLUG=Dragon lua tools/mod_check_one.lua
PERSON=589  THING=237  SCENE=106  WUGONG=114
HERO=資  STRINGS=OK  EVENTS=OK  SAVE=OK

$ lua tests/unit/boot_one_mod.lua Dragon 589 237 106 114 資
… 16/16 [PASS] …
RESULT Dragon: OK
```

`diff.md` 双向 set 相等复算：

```python
base = {n.lower() for n in os.listdir("data") if isfile}
mod  = {n.lower() for n in os.listdir("mods/Dragon/data") if isfile}
added   = mod  - base - {"sdx","smp","wdx","wmp"}
removed = base - mod  - {"smap.idx","smap.grp","wmap.idx","wmap.grp"}
# → 254 / 25，与 diff.md 逐项相等
```
