---
status: done
created: 2026-10-26
---

# Spec: allmods-pineapple-activation

> Change: `allmods-pineapple-activate`　|　Slice 12（第 4 梯队第 3 个）
> MOD：`kys-pineapple`（再破菠萝）→ 产物 `game/mods/pineapple/`
> 所有判据必须可在 `game/` 下用命令复跑。

---

## REQ-PIN-1 构建产物

**Given** 源包 `reference/allmods/kys-pineapple` 完整存在
**When** 执行 `cd game && rm -f active_mod.txt && lua tools/mod_build.lua kys-pineapple`
**Then** 输出必须逐字为：

```
[mod_build] kys-pineapple: data files=348, saves=30, sound=109, events=1068, talk=3596
[mod_build] diff -> mods/pineapple/diff.md
```

且产物满足：

| 项 | 值 |
|----|----|
| `mods/pineapple/data/` 文件数 | 348 |
| `mods/pineapple/save/` | 30（源 `save/` 全量 30 个） |
| `mods/pineapple/sound/` | 109 |
| `mods/pineapple/script/oldevent/*.lua` | 1068 |
| `mods/pineapple/script/oldtalk.idx` | 14384B |
| `mods/pineapple/script/oldtalk.grp` | 228575B |
| `mods/pineapple/diff.md` | 存在 |

**场景 1.1：构建可重入**
**Given** 已存在 `mods/pineapple/`
**When** 重复执行构建
**Then** 输出与首次相同（`data files=348 … talk=3596`），产物逐字节不变。

---

## REQ-PIN-2 穷举审计闭合

**Given** 构建完成
**When** 执行 `lua tools/mod_audit.lua --mod pineapple --evidence`
**Then** 输出必须为：

```
total=529 in_product=484 not_in_product=45 unclassified=0 bad_evidence=0
  REQUIRED             479
  REQUIRED_CONVERTED     4
  LEGACY                 5
  BUILD_INPUT            2
  PENDING               39
evidence: checked=10 failed=0
```

**场景 2.1：类别求和闭合**
**Given** 上述输出
**Then** `479 + 4 + 5 + 2 + 39 = 529`，且 `529` = 源包 `resource/` 文件总数
（`find reference/allmods/kys-pineapple -type f | wc -l`）。

**场景 2.2：`unclassified` 与 `bad_evidence` 均为 0**
**Given** 审计输出
**Then** 两者必须为 `0`；非 0 表示存在未归类文件组合或证据缺失。

---

## REQ-PIN-3 字节级格式覆盖

**Given** 构建完成
**When** 执行 `lua tools/format_spec.lua --mod pineapple`
**Then** 输出 `formats=12 checked=289 gaps=0`。

**场景 3.1：`gaps` 必须为 0**
**Given** 上述输出
**Then** `gaps=0` 表示所有被检文件的段结构符合格式规范；
`gaps>0` 说明存在结构异常（区别于「内容差异」）。

---

## REQ-PIN-4 独立进程启动链路

**Given** 已构建 `mods/pineapple/`
**When** 执行 `lua tests/unit/boot_one_mod.lua pineapple 720 344 118 174 蘿卜大`
**Then** 必须输出 **16 条 `[PASS]`、0 条 `[FAIL]`**，末行 `RESULT pineapple: OK`，含：

| # | 断言 | 期望 |
|---|------|------|
| 1 | `lib.init` | 无报错 |
| 2 | `JYMainAdapter.init` | 无报错 |
| 3 | `CC.PersonSize` | 182 |
| 4 | `CC.ThingSize` | 190 |
| 5 | `CC.SceneSize` | 52 |
| 6 | `CC.WugongSize` | 136 |
| 7 | `LoadRecord(0)` | 无报错 |
| 8 | `PersonNum` | 720 |
| 9 | `ThingNum` | 344 |
| 10 | `SceneNum` | 118 |
| 11 | `WugongNum` | 174 |
| 12 | `JY.Person[0]["姓名"]` | 蘿卜大 |
| 13 | 扫描字段数 | > 100（实测 **2764**） |
| 14 | 全量字符串 U+FFFD 数 | 0 |
| 15 | 全量字符串控制符数 | 0 |
| 16 | 运行时 10 帧 | 无报错 |

**场景 4.1：缺省期望值会假失败**
**Given** 执行 `lua tests/unit/boot_one_mod.lua pineapple`（不带期望值）
**Then** 会输出 `RESULT pineapple: FAIL (5)`（`PersonNum` 等期望 `nil`）
⇒ 调用时**必须**提供 5 个位置参数，否则该结果不可作为证据。

**场景 4.2：单 MOD 适配自检**
**Given** 执行 `MOD_SLUG=pineapple lua tools/mod_check_one.lua`
**Then** 输出：

```
PERSON=720  THING=344  SCENE=118  WUGONG=174
HERO=蘿卜大  STRINGS=OK  EVENTS=OK  SAVE=OK
```

---

## REQ-PIN-5 记录段边界整除

**Given** `mods/pineapple/data/ranger.idx` 与 `ranger.grp`
**When** 解析 idx 的 6 个小端 uint32
**Then** offsets 必须为 `[1860, 132900, 198260, 204396, 228060, 228210]`，grp = 229680B，且：

| 段 | 段长 | 记录长 | 记录数 | 余数 |
|----|-----:|-------:|-------:|-----:|
| Person | 131040 | 182 | 720 | 0 |
| Thing | 65360 | 190 | 344 | 0 |
| Scene | 6136 | 52 | 118 | 0 |
| Wugong | 23664 | 136 | 174 | 0 |
| Shop | 150 | 50 | 3 | 0 |

**场景 5.1：五段全部异于基线**
**Given** 基线 `data/ranger.idx` 对应 `320/200/84/93/3`
**Then** pineapple 的 `(720, 344, 118, 174, 3)` 中**前四段全部不同**
⇒ 该判据（段数差异）已足以证明「加载了 MOD 数据」，但仍须 REQ-PIN-6 的内容证据佐证。

---

## REQ-PIN-6 内容真实性（四类直接证据）

### 场景 6.1：记录边界值

**Given** `LoadRecord(0)` 已完成
**Then** 下列字段值必须精确匹配：

| 段 | 索引 | 字段 | 期望值 |
|----|-----:|------|--------|
| Person | 0 | 姓名 | `蘿卜大` |
| Person | 719 | 姓名 | `""`（空，**源数据本身为 `0x20` 空格填充**） |
| Thing | 0 | 名称 | `小續命丹` |
| Thing | 343 | 名称 | `天書` |
| Scene | 0 | 名称 | `許昌` |
| Scene | 1 | 名称 | `兵營` |
| Scene | 2 | 名称 | `兵營` |
| Scene | 117 | 名称 | `暗云蒼穹` |
| Wugong | 0 | 名称 | `普通攻擊` |
| Wugong | 173 | 名称 | `兌澤化三才` |

**负对照**：基线 `Person[0] = 徐小俠`、`Scene[0] = 胡斐居`、`Scene[2] = 云鶴崖`
⇒ pineapple 的 `Scene[0] = 許昌` 与基线不同，证明内容确实来自 MOD。

### 场景 6.2：事件数与构建报告一致

**Given** `mods/pineapple/script/oldevent/`
**Then** `ls mods/pineapple/script/oldevent/*.lua | wc -l` = **1068**，与构建报告
`events=1068` 完全一致。

### 场景 6.3：对话条目可读

**Given** `mods/pineapple/script/oldtalk.{idx,grp}`
**Then**：

- `oldtalk.idx` = 14384B → **3596** 条目（`14384 / 4`）
- `oldtalk.grp` = 228575B → **3597** 行（含末尾空行）
- 首条目文本可读：`已经满级了`
- 末条目文本可读：`不要打岔，这是送你回去的咒语，一起念，qui…`

且 3596 = 构建报告 `talk=3596`。

### 场景 6.4：全量字符串无损坏

**Given** `boot_one_mod.lua` 的全量扫描
**Then** 扫描 2764 个字符串字段，`U+FFFD` 计数 = 0、控制符计数 = 0。

---

## REQ-PIN-7 `kysmod.ini` 生效（反向对照）

**Given** 同一份代码，分别在不激活 MOD 与激活 pineapple 两种状态下启动
**When** 读取下列常量
**Then** 必须观察到 **10 项** `nil → 有值` 跳变：

| 常量 | 基线 | pineapple |
|------|:----:|:---------:|
| `CC.MaxLevel` | `nil` | 99 |
| `CC.MaxHP` | `nil` | 9999 |
| `CC.MaxMP` | `nil` | 9999 |
| `CC.MaxPhysicalPower` | `nil` | 100 |
| `CC.MaxItemAmount` | `nil` | 456 |
| `CC.ItemBeginPic` | `nil` | 3753 |
| `CC.MaxWeaponMatch` | `nil` | 58 |
| `CC.MinKnowledge` | `nil` | 80 |
| `CC.LifeHurt` | `nil` | 10 |
| `CC.ExpRate` | `nil` | 1 |

**场景 7.1：字段名必须是 `CC.LifeHurt`**
**Given** `framework/mod_ini.lua:187` 映射 `life_hurt → {"CC","LifeHurt"}`
**Then** `CC.LIFE_HURT` 恒为 `nil`，**不得**用作证据。

**场景 7.2：`CC.MoneyID` 是辅助证据而非主证据**
**Given** 基线 `jyconst.lua:435` 已定义 `CC.MoneyID=174`
**Then** pineapple 的 `CC.MoneyID=342`（值变）可作辅助，但**基线非 `nil`**，
不能单独证明「ini 被注入」。主证据是上表 10 项 `nil → 有值`。

---

## REQ-PIN-8 零字节 fight 的三分支降级

**Given** `mods/pineapple/data/fight016`~`fight131` 区间内共 **115** 个 `.grp` 与对应 `.idx` 均为 0 字节
（区间内唯一例外为 `fight072`，其 `grp` = 57822B 正常非空）
**And** `Person.头像代号` 引用其中 **115** 个编号（被引用代号共 **151** 个，范围 1..299）
**And** 零字节集合 ⊆ 被引用集合（`零字节 ∩ 被引用 = 115`，`零字节 − 被引用 = ∅`），
即 115 个零字节包全部被引用；被引用共 151 个，差额 36 为 `OK` 包，
且被引用代号全部 ≤299 ⇒ 本 MOD 无 `FILE_MISSING` 实例（引用的 fight 包全部存在）
**When** 对代表性代号依次执行 `PicLoadFile` → `PicGetXY(4, 0)`
**Then** 必须能区分三种分支：

| 代号样本 | 文件状态 | 分支判定 | `FileLength` | `PicLoadFile` | `PicGetXY(4,0)` |
|----------|----------|----------|-------------:|---------------|-----------------|
| 16 / 71 / 100 / 131 | grp 存在但 0B | `ZERO_BYTE` | `0` | **不早退**、`num = 0` | `0, 0` |
| 1 / 15 / 72 / 132 / 299 | grp 非空 | `OK`（正对照） | `> 0` | 正常 | **真实尺寸**（124×67、23×47、79×60、41×65、23×50） |
| 500（人造）/ Dragon `fight101` | 文件不存在 | `FILE_MISSING` | `-1` | **早退**（`lib_love.lua:435`） | `0, 0` |

> `fight072` 是区间内的**非零例外**，恰好充当 `ZERO_BYTE` 判定的**边界负对照**：
> 同一编号段内既有 0B 也有 57822B，证明「零字节」不是按编号区间一刀切，

**场景 8.1：`ZERO_BYTE` 与 `FILE_MISSING` 必须走不同分支**
**Given** `lib_love.lua:435` 的条件是 `if idxlen < 0 or grplen < 0 then return end`
**Then** 当 `grplen == 0` 时条件为**假**，`PicLoadFile` **不会**早退，
`num = idxlen/4 = 0`，`pic_file.idx[1] = 0` 之后循环不执行，`idx` 表只有一项；
随后 `getPic` 能**成功打开** 0 字节 grp，但因 `idx[picid] == nil` 返回 `nil`（`:270-273`）。
⇒ 该路径与 Dragon 的「`PicLoadFile` 一级早退」**本质不同**，Dragon 的结论不可类推。

**场景 8.2：必须带 `OK` 正对照**
**Given** 仅测缺失/空文件时 `PicGetXY` 返回 `0,0`
**Then** 无法区分「降级生效」与「测量方法本身失效」
⇒ 必须同时对非空 grp 代号（如 1）实测出**非零**尺寸。

**场景 8.3：不得裸调 `PicGetXY`**
**Given** 未先 `PicLoadFile` 时 `picFileCache[fileid]` 为 `nil`
**Then** `PicGetXY` 会在 `lib_love.lua:462` 抛 `attempt to index a nil value`
⇒ 该错误源于调用前置条件不满足，**不得**作为降级证据。

**场景 8.4：全部调用 `pcall` 为 `true`**
**Given** 对所有 151 个被引用代号逐个 `pcall(PicLoadFile)` + `pcall(PicGetXY)`
**Then** 抛错计数必须为 **0**。

---

## REQ-PIN-9 `CC.Effect` 越界取证（只取证不修复）

**Given** `Wugong` 的 `武功动画&音效` 字段（`CC.Wugong_S` offset 36）
**When** 统计 0..173 号记录的该字段值
**Then** **max = 83**，而 `CC.Effect` 真实键范围仅覆盖索引 **`0..52`（53 项）**。
⇒ 项数必须用 `pairs` 计数；`#CC.Effect` 返回 52 **不可**当作项数（显式 `[0]` 键使 `#` 语义不确定）。
⇒ 越界判据为 `eft > 52`，实测 **62 条记录 / 28 个不同越界值（53..83）**。
越界记录 **63** 条，涉及 **29** 个不同越界值（>51）。

**场景 9.1：`framenum` 走 `or 10` 兜底**
**Given** `framework/war_async.lua:1109`
`local framenum = fightdelay + (CC.Effect and CC.Effect[eft] or 10) or 10`
**Then** `eft=83` 时 `CC.Effect[83] == nil` ⇒ `framenum = 10`；
对照 `eft=51` 时 `CC.Effect[51]` 有值 ⇒ `framenum = 16`。
⇒ 越界不报错，只**缩短特效帧数**。

**场景 9.2：`starteft` 累加不报错**
**Given** `framework/war_async.lua:1126` `for i = 0, eft - 1 do starteft = starteft + (CC.Effect[i] or 0) end`
**Then** `eft=83` 时循环跑到 82，索引 52..82 全为 `nil` 贡献 `0`
⇒ `starteft = 712`（= `sum(CC.Effect[0..52])`），`eft=52` 时 `starteft = 705`（= `sum(0..51)`）。
⇒ `eft=53` 与 `eft=83` 结果**完全相同**，说明是饱和降级而非线性退化。
两者 `pcall` 均为 `true`。

**场景 9.3：本 change 不修复**
**Given** 修复点在 `game/script/jyconst.lua`（禁用路径），且需把
`list/effect.bin`（PENDING 39 项之一）提升为 REQUIRED 才能重建该表
**Then** 本 change **只取证**，结论记入 `epic/TODO.md` 的 spike 条目
（与 RiverLake 已记录的 `allmods-effect-table` 同一条目）。

---

## REQ-PIN-10 `icon.png` 无运行时消费者（范围外发现）

**Given** `mods/pineapple/data/icon.png`（9383B，与源 md5 相同）
**When** `grep -rn "icon\.png" --include=*.lua script/ framework/ engine-love2d/ tests/`
**Then** 命中数必须为 **0**。

**场景 10.1：归类来源是 `BY_KIND` 兜底**
**Given** `tools/mod_audit.lua:264-269` 的 `BY_KIND`
（`resource|.grp` / `resource|.idx` / `resource|.png` → `REQUIRED`）
**Then** `icon.png` 被标 `REQUIRED` 是**兜底**结果，非按运行时读取判定。

**场景 10.2：不因本 change 改判定**
**Given** Dragon 的同类集合为 6 个（`cloud.{grp,idx}`、`title.{grp,idx}`、`open.png`、`end.png`）
**Then** pineapple 多出第 7 个（`icon.png`）。
改判定会牵动 20 个 MOD 的 `REQUIRED` 计数 ⇒ 列为独立 change，
本 change 仅在 `verification.md` 记录。

---

## REQ-PIN-11 `name.*` ≠ `talk.*`（与 Dragon 相反）

**Given** `mods/pineapple/data/{name,talk}.{grp,idx}`
**When** 计算 md5
**Then** 必须为：

| 文件 | md5 |
|------|-----|
| `name.grp` | `d7ea262bf2a2e5ddfdce8bfd9bd070d3` |
| `talk.grp` | `e2b3cd0585243c555dab401acd958d30` |
| `name.idx` | `793bfa542b4a4d294c09939f6220a92c` |
| `talk.idx` | `537355667856c0d5767d236f27bb7129` |

**场景 11.1：与 Dragon 对照**
**Given** Dragon 的 `name.grp` 与 `talk.grp` md5 **相同**（`4c41c044…`）、
`name.idx` 与 `talk.idx` md5 **相同**（`1a0c74ab…`）
**Then** pineapple 四者**两两不同**，且大小也不同（`name.grp` 152082B vs `talk.grp` 152098B）
⇒ 「`name.*` 是 `talk.*` 副本」**不是跨 MOD 不变量**，必须逐 MOD 实测。

**场景 11.2：`name.*` 仍无运行时消费者**
**Given** `grep -rn "name\.grp" --include=*.lua script/ framework/ engine-love2d/` → 0
**Then** 无论是否副本，`name.*` 的审计类别均为 `LEGACY`。

---

## REQ-PIN-12 `ranger.str` 的 hint 去重不产生语义冲突

**Given** `mods/pineapple/data/ranger.grp` 经 UTF-8 转换后，字符串字段被替换为
固定宽度 hint（`P%04d` / `N%04d` / …），真实值写入 `ranger.str`
**When** 统计同一 hint 被多条记录复用的情况
**Then** 复用条目 **119** 处，但**真冲突数 = 0**
（即同一 hint 在所有复用处指向的值完全相同）。

**场景 12.1：去重是设计行为**
**Given** `tools/mod_encoding.lua:910-916` 的 `byValue[value]` 去重
（同值复用同一 index，`report.dedup` 计数）
**Then** 复用 = 同一字符串被多条记录共享，属正常压缩，不是索引错乱。

**场景 12.2：`record=-1` 是「空字符串占位」**
**Given** `ranger.str` 中出现 `0001,Person,-1,Nick,`
**Then** 这是 `mod_encoding.lua:943-957` 为非字符串字段写入的**共享空 hint**
（`side.__meta` 标记 `rec = -1, empty = true`），解析为 `""`。
⇒ 不是索引错误。

**场景 12.3：`Person[719]` 名字为空是源数据特征**
**Given** 源 `kys-pineapple/save/ranger.grp` 的 `Person[719]` 姓名字段原始字节为
`20 00 00 00 00 00 00 00 00 00`（`0x20` 空格 + 零填充）
**Then** 转换后为空串是**忠实还原**，不是缺陷。

---

## REQ-PIN-13 8 道门禁

| # | 门禁 | 命令 | 判据 |
|---|------|------|------|
| 1 | 单元测试 | `lua tests/test_runner.lua` | `1842/1842` pass，失败 0 |
| 2 | 原版基线 | `lua tools/mod_build.lua --verify-pascal` | `events=1018, mismatches=0, known-deviations=3` PASS |
| 3 | 全量构建 | `lua tools/mod_build.lua --all` | `20 mods, 0 build failures`；退出码 1 属设计（`mod_build.lua:1222-1224`） |
| 4 | 产物自检 | `lua tools/mod_check.lua` | `20 MOD, 通过 20, 失败 0` |
| 5 | 全量审计 | `lua tools/mod_audit.lua --all --evidence` | `unclassified=0 bad_evidence=0`，`evidence failed=0` |
| 6 | 全量格式 | `lua tools/format_spec.lua --all` | `gaps=0` |
| 7 | 存档一致 | 20 MOD `save/` vs 源（按 `isSaveSlotFile` 真实路由） | 真实问题 0（`ranger.*` 属设计内转换） |
| 8 | 禁改路径 | `git status --porcelain -- game/engine-love2d game/engine-mud reference/allmods` | 输出为空 |

**场景 13.1：门禁 7 的口径**
**Given** `mod_build.lua:665-670` 把源 `save/` 按 `isSaveSlotFile`（`:626-631`）分两类：
槽文件 → `mods/<m>/save/`，模板（`ranger.*`/`alldef.*`/`allsin.*`）→ `mods/<m>/data/`
**Then** 比对必须按真实路由查找目标文件，
不得笼统宣称「451 文件全等」（Slice 11 已修正此错误表述）。

---

## Out of Scope

| 项 | 原因 |
|----|------|
| `diff.md` 逐项审计与报告 | 属 `allmods-pineapple-verify` |
| 修复 `not_in_product` 语义 | 改工具契约 = 独立 change |
| 修复 `CC.Effect` 仅 53 项、越界 62 条 | 禁改路径 + 需提升 `list/effect.bin` = 独立 change |
| 把 `icon.png` 改判为 `LEGACY` | 影响 6 项 × 20 MOD 计数 = 独立 change |
| 为零字节 fight 生成占位图 | 引擎已优雅降级，改动会偏离源数据 |
| `music/*.mid` / `list/*.bin` | epic 级 spike |
| Slice 13（books） | 下一个 slice |
