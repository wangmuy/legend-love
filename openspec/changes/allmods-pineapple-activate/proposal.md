---
status: done
created: 2026-10-26
---

# Proposal: allmods-pineapple-activate

> 父上下文：epic [`2026-10-allmods-compat`](../../epics/2026-10-allmods-compat/epic.md)，
> slice [`allmods-slice12`](../allmods-slice12/slice-proposal.md)。
> 姊妹 change：`allmods-pineapple-verify`（本 change 交付其全部输入）。

## 1. 为什么需要这个 change

Slice 12 的第 1 阶段：把 MOD「再破菠萝」（kys-pineapple）纳入构建流水线，
并用**可机器复跑的断言**证明「构建成功 + 启动成功 + 数据段正确 + 内容真实」。

pineapple 不是「同形 MOD 再来一遍」，它带来三个**本 epic 首次**的问题：

1. **115 个零字节 `fight*.grp` 且全部被 `Person.头像代号` 引用** —— 与 Dragon 的
   「文件缺失」是**不同的代码分支**（`FileLength=0` 不触发 `PicLoadFile` 早退），
   必须独立证明运行时如何降级。
2. **`Person 720` 在全 20 个 MOD 中排第 2**（BookCalamity 800 为第 1；awaken 亦为 720）——
   仍属极端区间，`ranger.grp` 229680B 同为第 2（BookCalamity 313242）
   为全 MOD 最大，最容易暴露「记录数整除但字段错位」。
3. **`name.*` ≠ `talk.*`（与 Dragon 相反）** —— 证明「`name.*` 是 `talk.*` 副本」
   不是跨 MOD 不变量，必须逐 MOD 实测。

## 2. In Scope

- 构建 `game/mods/pineapple/`（348 data / 30 save / 109 sound / 1068 events / 3596 talk）
- 穷举审计（`total=529 in_product=484 not_in_product=45 unclassified=0 bad_evidence=0`）
- 字节级格式覆盖（`formats=12 checked=289 gaps=0`）
- 独立进程启动链路（16/16 断言）
- 内容真实性四类证据（边界记录 / 1068 事件 / 3596 对话 / 10 项 ini 常量）
- 零字节 fight 三分支实测（OK / ZERO_BYTE / FILE_MISSING）
- 8 道门禁复跑
- `ranger.str` hint 去重取证（119 复用 / 真冲突 0）
- `verification.md` 记录全部实测命令与输出

## 3. Out of Scope

| 项 | 原因 |
|----|------|
| `diff.md` 逐项审计与报告 | 属姊妹 change `allmods-pineapple-verify` |
| 修复 `not_in_product` 语义 | 改审计工具契约 = 独立 change |
| `CC.Effect` 仅 53 项、越界 62 条的修复 | 修复点在 `script/jyconst.lua`（禁用路径）+ 需提升 `list/effect.bin` = 独立 change；本 change 只取证 |
| `music/*.mid` / `list/*.bin` | epic 级 spike |
| 引擎改动 | 四禁改路径 |

## 4. 需求

### REQ-PIN-1 构建产物

`lua tools/mod_build.lua kys-pineapple` 必须输出：

```
[mod_build] kys-pineapple: data files=348, saves=30, sound=109, events=1068, talk=3596
[mod_build] diff -> mods/pineapple/diff.md
```

产物必须含 `data/` 348 文件、`save/`、`sound/`、`script/oldevent/*.lua` 1068 个、
`script/oldtalk.{grp,idx}`、`diff.md`。

### REQ-PIN-2 穷举审计闭合

`lua tools/mod_audit.lua --mod pineapple --evidence` 必须输出：

```
total=529 in_product=484 not_in_product=45 unclassified=0 bad_evidence=0
  REQUIRED 479  REQUIRED_CONVERTED 4  LEGACY 5  BUILD_INPUT 2  PENDING 39
```

不变量：`Σ(类别) = 529 = 源文件总数`，`unclassified=0`，`bad_evidence=0`。

> ⚠ `--mod` 是**选项**而非位置参数；写成 `mod_audit.lua pineapple` 会静默审计全部 20 MOD。

### REQ-PIN-3 字节级格式覆盖

`lua tools/format_spec.lua --mod pineapple` 必须输出 `formats=12 checked=289 gaps=0`。
`gaps>0` 表示存在结构异常（非内容差异），必须为 0。

### REQ-PIN-4 独立进程启动链路

`lua tests/unit/boot_one_mod.lua pineapple 720 344 118 174 蘿卜大` 必须
**16/16 断言 PASS** 并输出 `RESULT pineapple: OK`，含：

- `CC.PersonSize=182` / `ThingSize=190` / `SceneSize=52` / `WugongSize=136`（MOD 布局）
- `PersonNum=720` / `ThingNum=344` / `SceneNum=118` / `WugongNum=174`
- `JY.Person[0]["姓名"] == "蘿卜大"`
- 扫描字段数 > 100（实测 2764）
- 全量字符串 **0 个 U+FFFD**、**0 个控制符**
- 运行时 10 帧无报错

> ⚠ 位置参数是**期望值**；缺省会期望 `nil` 并 FAIL 5 项。

### REQ-PIN-5 记录段边界整除

`ranger.idx` offsets = `[1860, 132900, 198260, 204396, 228060, 228210]`，`ranger.grp` = 229680B。

| 段 | 段长 | 记录长 | 记录数 | 余数 |
|----|-----:|-------:|-------:|-----:|
| Person | 131040 | 182 | **720** | 0 |
| Thing | 65360 | 190 | **344** | 0 |
| Scene | 6136 | 52 | **118** | 0 |
| Wugong | 23664 | 136 | **174** | 0 |
| Shop | 150 | 50 | **3** | 0 |

**五段全部异于基线**（320/200/84/93/3），须以内容证据（REQ-PIN-6）配合，
不得仅凭整除下结论。

### REQ-PIN-6 内容真实性（四类直接证据）

| 类 | 判据 |
|----|------|
| 记录边界值 | `Person[0]=蘿卜大`、`Person[719]`、`Thing[0]=小續命丹`、`Thing[343]=天書`、`Scene[0]=許昌`、`Scene[117]=暗云蒼穹`、`Wugong[0]=普通攻擊`、`Wugong[173]=兌澤化三才` |
| 事件 | `mods/pineapple/script/oldevent/*.lua` = **1068** = 构建报告 `events=1068` |
| 对话 | `oldtalk.idx` 14384B = **3596** 条目；`oldtalk.grp` 228575B = 3597 行；首行「已经满级了」可读 |
| ini 常量 | **10 项**基线为 `nil` 的常量跳变（见 REQ-PIN-7） |

### REQ-PIN-7 `kysmod.ini` 生效（反向对照）

必须给出基线态与激活态的对照，且只用**基线为 `nil`** 的常量作证据：

| 常量 | 基线 | pineapple |
|------|:----:|:---------:|
| `CC.MaxLevel` | `nil` | **99** |
| `CC.MaxHP` | `nil` | **9999** |
| `CC.MaxMP` | `nil` | **9999** |
| `CC.MaxPhysicalPower` | `nil` | **100** |
| `CC.MaxItemAmount` | `nil` | **456** |
| `CC.ItemBeginPic` | `nil` | **3753** |
| `CC.MaxWeaponMatch` | `nil` | **58** |
| `CC.MinKnowledge` | `nil` | **80** |
| `CC.LifeHurt` | `nil` | **10** |
| `CC.ExpRate` | `nil` | **1** |

`CC.MoneyID` 在 pineapple 为 **342**（基线 174，`jyconst.lua:435` 已定义）——
因基线已有值，**不能**单独作为 ini 注入证据，仅作辅助。
字段名必须是 `CC.LifeHurt`（**不是** `CC.LIFE_HURT`，后者恒 `nil`；见 `mod_ini.lua:187`）。

### REQ-PIN-8 零字节 fight 的三分支降级（**本 change 的核心新判据**）

`fight016`~`fight131` 共 **115** 个 `.grp` 与 `.idx` 均为 0 字节，
且 `Person.头像代号` 恰好引用这 115 个编号（151 个被引用代号中 115 个零字节）。

必须实测**三种代码分支**可区分：

| 代号样本 | 文件状态 | 分支 | `FileLength` | `PicLoadFile` | `PicGetXY` |
|----------|----------|------|-------------:|---------------|------------|
| 16 / 100 / 131 | grp 存在但 0B | `ZERO_BYTE` | `0` | **不早退**（`0 < 0` 假）→ `num=0` | `0,0` |
| 1 / 15 / 132 / 299 | grp 非空 | `OK` | `>0` | 正常 | **真实尺寸**（正对照） |
| （Dragon 对照组） | 文件不存在 | `FILE_MISSING` | `-1` | **早退**（`lib_love.lua:435`） | `0,0` |

判据：
- `ZERO_BYTE` 与 `FILE_MISSING` **必须走不同分支**（前者在 `getPic` 内因 `idx[picid]==nil` 返回 `nil`，
  后者在 `PicLoadFile` 就早退），故 Dragon 的结论**不可类推**。
- 必须带 `OK` 正对照，否则无法区分「降级生效」与「测量方法失效」。
- 全部 `pcall` 必须为 `true`（不得抛 Lua 错误）。

### REQ-PIN-9 `CC.Effect` 越界取证（**只取证不修复**）

`Wugong["武功动画&音效"]` 实测 **max = 83**，而 `CC.Effect` 真实键范围仅 **`0..52`（53 项）**。
越界记录 **62 条**（占 174 条武功的 35.6%），涉及 **28 个不同越界值**（53..83）。

必须证明越界时的运行时行为：

- `CC.Effect[83]` 为 `nil` ⇒ `war_async.lua:1109` 的 `or 10` 兜底生效
  ⇒ `framenum = 10`（正常值约 16）
- `war_async.lua:1126` 的累加循环 `for i=0,eft-1` 用 `CC.Effect[i] or 0`，
  越界项贡献 0 ⇒ `starteft` 停在 51 项的累加值，不抛错
- 全部 `pcall` 必须为 `true`

**本 change 不修复**（修复点在 `script/jyconst.lua` = 禁用路径，且需把
`list/effect.bin` 从 PENDING 提升为 REQUIRED = 独立 change）。结论写入
`epic/TODO.md` 的 spike 条目。

### REQ-PIN-10 `icon.png` 无运行时消费者（范围外发现）

`resource/icon.png`（9383B）在 pineapple 出现，`grep -rn "icon\.png"` 须 **0 命中**。
须与 Dragon 的 6 个同类文件（`cloud/title/open/end`）对比，说明 `BY_KIND` 兜底集合
在 pineapple 上多出第 7 个成员，并注明**不因本 change 改判定**。

### REQ-PIN-11 `name.*` ≠ `talk.*`（与 Dragon 相反）

必须实测两组 md5 并给出与 Dragon 的对照：

| MOD | `name.grp` vs `talk.grp` | `name.idx` vs `talk.idx` | 结论 |
|-----|--------------------------|--------------------------|------|
| Dragon | `4c41c044…` = `4c41c044…` | `1a0c74ab…` = `1a0c74ab…` | **副本** |
| pineapple | `d7ea262b…` ≠ `e2b3cd05…` | `793bfa54…` ≠ `53735566…` | **非副本** |

⇒ 「`name.*` 是 `talk.*` 副本」**不是跨 MOD 不变量**。

### REQ-PIN-12 `ranger.str` 的 hint 去重不产生语义冲突

`ranger.str`（648 行）由 hint 字段生成，存在 **119 处 hint 值复用**。
必须证明复用**不产生语义冲突**：

- 复用项全部解析到**同一 value** ⇒ 真冲突数 = **0**
- 去重实现为 `mod_encoding.lua:910-916` 的 `byValue[value]`
- 非字符串字段写入共享空 hint，并附 `side.__meta { rec=-1, empty=true }`
  （`mod_encoding.lua:943-957`）—— 这解释了 `0001,Person,-1,Nick,` 这类行
- `record = -1` 是**共享占位符**，不是错误记录号

⇒ 判为**设计内的去重优化**，不是工具缺陷。

### REQ-PIN-13 8 道门禁

| # | 门禁 | 判据 |
|---|------|------|
| 1 | `tests/test_runner.lua` | 1842/1842 pass |
| 2 | `mod_build --verify-pascal` | `mismatches=0` PASS |
| 3 | `mod_build --all` | `20 mods, 0 build failures`（退出码 1 属设计） |
| 4 | `mod_check.lua` | 20/20 |
| 5 | `mod_audit --all --evidence` | `unclassified=0 bad_evidence=0`，`failed=0` |
| 6 | `format_spec --all` | `gaps=0` |
| 7 | 20 MOD `save/` vs 源 | 按真实路由比对，真实问题 0 |
| 8 | 禁改路径 | `git status --porcelain` 三处为空；`jyconst.lua` 无 `CC.*=` 定义行增删 |

## 5. Blast Radius

| 路径 | 允许 | 说明 |
|------|:----:|------|
| `game/mods/pineapple/**` | ✅ 写 | 构建产物；实验后须恢复 |
| `openspec/changes/allmods-pineapple-activate/**` | ✅ 写 | 本 change 全部产物 |
| `openspec/changes/allmods-slice12/**` | ✅ 写 | slice 与 manifest |
| `openspec/epics/2026-10-allmods-compat/**` | ✅ 写 | epic.md / TODO.md 索引 |
| `game/tests/unit/boot_one_mod.lua` | ⚠ 只读 | 用位置参数调用，不改 |
| `game/tools/**` | ⚠ 仅限已记录的工具缺陷 | 本 MOD 若发现新缺陷须单列 |
| `game/engine-love2d/**` | ❌ 禁 | |
| `game/engine-mud/**` | ❌ 禁 | |
| `game/script/jyconst.lua` 常量定义 | ❌ 禁 | |
| `reference/allmods/**` | ❌ 禁（只读） | |

## 6. 关键风险

| 风险 | 缓解 |
|------|------|
| 用「记录数整除」代替「内容正确」 | REQ-PIN-6 四类直接证据 + 基线对照 |
| 把零字节 fight 当作「同 Dragon 缺失」处理 | REQ-PIN-8 三分支 + 分支判据（`FileLength` 值不同） |
| 用 `PicGetXY` 裸调作降级证据 | 必须先 `PicLoadFile`；裸调会抛 `lib_love.lua:462` |
| 把 `CC.MoneyID` 当 ini 生效证据 | 基线已定义 174，仅 `nil→有值` 的 10 项有效 |
| 误写 `CC.LIFE_HURT` | 正确字段 `CC.LifeHurt`（`mod_ini.lua:187`） |
| 把 `CC.Effect` 越界当缺陷修复 | 禁改路径；只取证，写 spike |

## 7. 交付物

| 产物 | 路径 |
|------|------|
| 构建产物 | `game/mods/pineapple/` |
| 差异清单 | `game/mods/pineapple/diff.md` |
| 规格 | `specs/allmods-pineapple-activation/spec.md` |
| 设计决策 | `design.md`（ADR-001..） |
| 任务 | `tasks.md` |
| 验证记录 | `verification.md` |
