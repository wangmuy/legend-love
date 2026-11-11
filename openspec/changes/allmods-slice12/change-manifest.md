---
status: done
parent_slice: allmods-slice12
parent_epic: 2026-10-allmods-compat
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Change Manifest: allmods-slice12

> 本 slice 将一个 MOD（kys-pineapple / 再破菠萝）的端到端适配拆成 2 个 spec-driven 子 change。
> 子 change 之间通过下方 **Contracts** 传递可验证接口。
>
> pineapple 是第 4 梯队第 3 个 MOD、累计第 12 个。在全部 20 个 MOD 中：
> **零字节 fight 最多（115，第 1）**、**`CC.Effect` 越界最严重（62/174 = 35.6%，第 1 档）**、
> **`Person` 记录第 2（720；BookCalamity 800 为第 1，awaken 亦为 720）**、
> **`ranger.grp` 第 2（229680B；BookCalamity 313242，基线 136412）**。

## 子 change 列表

| # | 子 change | 依赖 | 状态 |
|---|-----------|------|------|
| 1 | `allmods-pineapple-activate` | Slice 0/0b/0c | [x] done |
| 2 | `allmods-pineapple-verify` | 子 change #1 | [x] done |

## 执行顺序

```
allmods-pineapple-activate  →  allmods-pineapple-verify
   (构建+启动+13 REQ 机器验证)      (diff 逐项审计+10 REQ+报告)
```

## Contracts

### Contract A：构建产物

`activate` 必须产出 `game/mods/pineapple/` 并满足：

| 项 | 值 |
|----|----|
| `data files` | 348 |
| `saves` | 30 |
| `sound` | 109 |
| `events` | 1068 |
| `talk` | 3596 |
| `fight*.grp` | 154（其中 **115 零字节**） |
| `hdgrp` 条目 | 300（`hdgrp.idx` 1200B） |
| `eft` 条目 | 1378（`eft.idx` 5512B，`eft.grp` 2266744B） |
| 记录段 | 720 / 344 / 118 / 174 |

实测：

```
$ cd game && lua tools/mod_build.lua kys-pineapple
[mod_build] kys-pineapple: data files=348, saves=30, sound=109, events=1068, talk=3596
[mod_build] diff -> mods/pineapple/diff.md
```

**消费方**：`verify` 的全部审计与报告。

### Contract B：穷举审计

`mod_audit --mod pineapple --evidence` 必须满足：

```
total=529 in_product=484 not_in_product=45 unclassified=0 bad_evidence=0
evidence: checked=10 failed=0
```

分级：REQUIRED 479 / REQUIRED_CONVERTED 4 / LEGACY 5 / BUILD_INPUT 2 / PENDING 39
闭合校验：`479 + 4 + 5 + 2 + 39 = 529` = 源文件总数。

### Contract C：字节级覆盖

`format_spec --mod pineapple`：

```
formats=12 checked=289 gaps=0
```

### Contract D：启动链路

`boot_one_mod.lua pineapple 720 344 118 174 蘿卜大`（5 个位置参数是**期望值**，缺省会产生 `FAIL (5)` 假阳性）：

```
RESULT pineapple: OK
```

16 项断言全 PASS / 0 FAIL；扫描 2764 字段，0 U+FFFD、0 控制字符；连续 10 帧无错误。

`MOD_SLUG=pineapple lua tools/mod_check_one.lua`（环境变量，非位置参数）：

```
PERSON=720 THING=344 SCENE=118 WUGONG=174 HERO=蘿卜大
STRINGS/EVENTS/SAVE=OK
```

### Contract E：记录段与 `hdgrp` / `eft` / 零字节 fight 判据

| 判据 | 期望 | 实测 |
|------|------|------|
| `ranger.idx` 偏移 | 6 项 | `[1860,132900,198260,204396,228060,228210]` |
| `ranger.grp` 大小 | — | `229680` |
| Person 段 | `131040 / 182 = 720` 余 0 | ✅ |
| Thing 段 | `65360 / 190 = 344` 余 0 | ✅ |
| Scene 段 | `6136 / 52 = 118` 余 0 | ✅ |
| Wugong 段 | `23664 / 136 = 174` 余 0 | ✅ |
| Shop 段 | `150 / 50 = 3` 余 0 | ✅ |
| 四段与基线不同 | 基线 320/200/84/93 | ✅ 全部不同 |
| `hdgrp.idx` | 1200B → 300 条目 | ✅ 300 |
| `eft.idx` | 5512B → 1378 条目 | ✅ 1378 |
| 零字节 fight | 见 Contract H | 115 |

**关键**：`131040 / 720 = 182` ⇒ 运行时 `CC.PersonSize = 182`（**非** `jyconst.lua` 源码里的 202）。
`person.size` 由 `ranger.idx` 段长动态推导，不取源码常量。

### Contract F：`diff.md` 双向 set 相等

| 项 | 声明 | 实测 | 判定 |
|----|-----:|-----:|:----:|
| MOD 独有 | 140 | 140 | ✅ |
| 基线独有 | 21 | 21 | ✅ |
| `add == 实测独有` | — | `True` | ✅ |
| `rem == 实测基线` | — | `True` | ✅ |

**不只是数量相等，是集合相等** —— 一错一漏会被 `==` 暴露。
`140 = 124 fight（62 组 × 2）+ 16 非 fight`。

### Contract G：`not_in_product` ≠ 物理缺失

pineapple 的 `not_in_product = 45`，其中部分文件**物理上存在**于源中，
只是不属于产物必需成员。语义为「**非必需产物成员**」，不是「产物中不存在」。

生成逻辑三步门（`tools/mod_audit.lua:453-462`）。**不得**改判为缺陷。

### Contract H：零字节 fight 三分支（本 MOD 核心独特性）

#### H.1 三态判据

`lib_love.lua:435`：

```lua
if idxlen < 0 or grplen < 0 then return end   -- FILE_MISSING 早退（:436）
```

| 分支 | 条件 | `getPic` 行为 | 结果 |
|------|------|---------------|------|
| `OK` | `idxlen > 0 and grplen > 0` | 正常 | 真实 `w×h` |
| `ZERO_BYTE` | `idxlen == 0 or grplen == 0` | 不早退 → `num = idxlen/4 = 0` → `idx` 仅 1 项 → `idx[picid] == nil` → `:270-273` 返回 nil | `0, 0` |
| `FILE_MISSING` | `idxlen < 0`（文件不存在） | 早退 `:436` → `getPic` 开文件失败 `:264` | `0, 0` |

#### H.2 实测三分支（`pcall` 全 `true`，无异常）

```
ZERO_BYTE 115 / OK 36 / FILE_MISSING 0
```

> **交叉验证**：`OK 36` 与 H.4 的「被引用 151 − 零字节 115 = 36」**精确相等** ——
> 两条独立测量（三分支 `getPic` 实测 vs `头像代号` 集合运算）互相印证。

| 代号 | 大小 | 分支 | 结果 |
|-----:|-----:|------|------|
| 1 | 144B / 69516B | OK | 124×67 |
| 15 | — | OK | 23×47 |
| 16 | 0B | ZERO_BYTE | 0×0 |
| 71 | 0B | ZERO_BYTE | 0×0 |
| **72** | 144B / 57822B | **OK** | **79×60** |
| 73 | 0B | ZERO_BYTE | 0×0 |
| 131 | 0B | ZERO_BYTE | 0×0 |
| 132 | — | OK | 41×65 |
| 299 | — | OK | 23×50 |
| 400 / 719 | —（人造） | FILE_MISSING | 0×0 |

#### H.3 `fight072` 是区间内唯一非零例外（边界负对照）

零字节区间为 `fight016`~`fight131`，但**不连续**：

```
71 = 0B  ZERO_BYTE
72 = 57822B OK 79×60     ← 唯一例外
73 = 0B  ZERO_BYTE
```

⇒ 零字节**不是**「区间一刀切」，必须逐文件判定。

#### H.4 零字节集合全部被引用（115/115），但被引用集合更大（151）

| 判据 | 值 |
|------|-----:|
| 运行时被引用 `头像代号`（offset **2**） | **151** 个（min 1, max 299） |
| 零字节 ∩ 被引用 | **115** |
| 零字节 − 被引用 | **0**（∅） |
| 被引用 − 零字节 | **36**（= 151 − 115，均为 `OK` 分支） |
| 代号 > 299（文件缺失） | **0** |

> **口径修正**：本节初稿写「被引用 − 零字节 = ∅」，实测**错误**。
> 被引用 151 个代号中 115 个落在零字节集内，其余 **36 个**是正常 `OK` 包
> （与 Contract H.2 的 `OK 36` 精确吻合，互为交叉验证）。
> 关键结论不变：**零字节 − 被引用 = 0** ⇒ 没有任何零字节包是「被引用但文件缺失」。

⇒ pineapple **无 `FILE_MISSING` 实例**（`代号 > 299` 计数为 0）。
`FILE_MISSING` 证据由 Dragon `fight101` 与人造编号 `400/719` 提供。

#### H.5 零字节源侧溯源（决定性）

```
产物零字节 grp: 115
源中找不到: 0
源也 0B: 115
源非 0B: 0
```

⇒ **115/115 源文件本身即 0 字节**，`mod_build.lua` 只是忠实复制，**无缺陷**。

#### H.6 两层性质

| 层 | 条数 |
|----|-----:|
| 零字节 ∩ 与基线同名（基线非零 → 被清零） | **76** |
| 零字节 ∩ 基线无此名（新增空占位） | **39** |
| 合计 | **115** |

#### H.7 禁止事项

- **不得**裸调 `PicGetXY`（未 `PicLoadFile` 会抛 `lib_love.lua:462`）
- **不得**把零字节与文件缺失混为一谈（`FileLength` `0` vs `-1`）
- **不得**为零字节 fight 生成占位图（引擎已饱和降级）
- **不得**把 `fight072` 例外说成「区间内全部零字节」

### Contract I：fight 四象限（`diff.md` 盲区）

| 象限 | 判据 | 条数 | 是否在 `diff.md` |
|------|------|-----:|:----------------:|
| A 同名同容 | md5 相同 | **2** | ❌ 否（完全无差异） |
| B 同名异容 | md5 不同 | **90** | ❌ **否（盲区）** |
| C MOD 独有 | 基线无此名 | **62** | ✅ 是（62 `.grp` + 62 `.idx`） |
| D 零字节 | `size == 0` | **115** | 跨 B/C |

自洽：`A + B = 92`（基线 fight 数）、`A + B + C = 154`、`D∩B(76) + D∩C(39) = 115`。

**核心发现**：`diff.md` 只报「基线无此名」，**漏掉 B 类 90 处同名改写**。
只看 `diff.md` 会漏审 90 个文件。必须用四象限补全。

### Contract J：两套口径不得混用

| 口径 | 定义 | 数字 |
|------|------|------|
| ① `diff.md` | 基线无此名 | `140 = 124 fight 文件（62 组 × 2）+ 16 非 fight` |
| ② 四象限 | 同名 × 内容 × 零字节 | `154 = 2 + 90 + 62`（仅 `.grp`） |

`124 = 62 × 2`。混用会产生「pineapple 有 140 或 154 个 fight」的矛盾表述。

### Contract K：21 条基线独有三分类

| 类 | 条数 | 判据 | 性质 |
|----|-----:|------|------|
| ① 存档槽改道 | **18** | `mods/pineapple/save/<n>` 长度 == 源 | 设计内路由（`mod_build.lua:626-631` + `:665-670`） |
| ② 模板回退 | **3** | `thing.grp`/`thing.idx`/`allsinbk.grp`：源中无，`ModData.Resolve` 回退基线且 EXISTS | 设计内回退 |
| ③ 真删除 | **0** | 三处皆无 | **不存在** |

`18 + 3 + 0 = 21` ✅

`ModData.Resolve` 实测：

```
thing.grp      -> data/thing.grp          EXISTS (345600 B)
thing.idx      -> data/thing.idx          EXISTS (800 B)
allsinbk.grp   -> data/allsinbk.grp       EXISTS (4128768 B)
```

⇒ **不得**判为「构建遗漏」或「MOD 删除了基线文件」。

> **与 RiverLake 区分**：RiverLake 的 `allsinbk.grp` 是「路径被引用、内容未被使用」；
> pineapple 是「MOD 未提供、回退基线」。语义不同，不合并。

### Contract L：`CC.Effect` 越界（范围外取证，不修复）

| 判据 | 实测 |
|------|-----:|
| `CC.Effect` 真实键范围 | **0..52（53 项）** |
| `#CC.Effect` | 52（**不等于**项数，须用 `pairs`） |
| `武功动画&音效` max | **83** |
| 越界判据 | `eft > 52` |
| 越界记录 | **62 条** |
| 不同越界值 | **28 个**（53..83） |
| 占比 | 62/174 = **35.6%**（7/20 越界 MOD 中最严重） |

降级实测（探针令 `fightdelay = 0` 隔离 `CC.Effect` 贡献）：

| eft | `CC.Effect[eft]` | `framenum` | `starteft` | pcall |
|----:|-----------------:|-----------:|-----------:|:-----:|
| 52 | 7 | 7 | 705 | true/true |
| 53 | nil | 10 | 712 | true/true |
| 83 | nil | 10 | 712 | true/true |

⇒ **饱和降级**：`eft=53` 与 `eft=83` 结果完全相同，不崩溃、不抛错。

**不修复理由**：修复点在 `game/script/jyconst.lua`（四禁改路径），
且需将 `list/effect.bin` 从 PENDING 提升为 REQUIRED = 独立 change
（epic 级 spike `allmods-effect-table`）。

### Contract M：8 道门禁

| # | 门禁 | 期望 |
|---|------|------|
| 1 | `lua tests/test_runner.lua` | `1842 / 1842 通过 / 0 失败` |
| 2 | `lua tools/mod_build.lua --verify-pascal` | PASS，`mismatches=0` |
| 3 | `lua tools/mod_build.lua --all` | `20 mods, 0 build failures`（退出码 **1 属设计**） |
| 4 | `lua tools/mod_check.lua` | `通过 20, 失败 0` |
| 5 | `lua tools/mod_audit.lua --all --evidence` | `unclassified=0 bad_evidence=0`；`failed=0` |
| 6 | `lua tools/format_spec.lua --all` | `formats=12 checked=6773 gaps=0` |
| 7 | 门禁 7 脚本 | 槽 **341** + 模板 **110** = 451；真实问题 **0** |
| 8 | 四禁改路径 + `jyconst.lua` | porcelain 全空；无 `CC.*=` 增删 |

## 验证策略

每个子 change 的 `verification.md` 必须含：
1. REQ 追溯矩阵
2. 实测命令与输出
3. Blast Radius 合规检查
4. 偏差记录（对初稿的推翻逐条列出）

## 状态汇总

| 子 change | tasks | verification | status |
|-----------|-------|--------------|--------|
| `allmods-pineapple-activate` | 14 节全 [x] | 16 章节 / 13 REQ | [x] done |
| `allmods-pineapple-verify` | 11 节全 [x] | 12 章节 / 10 REQ | [x] done |

## 关键交付物

| 产物 | 路径 |
|------|------|
| 构建产物 | `game/mods/pineapple/`（348 data / 30 save / 109 sound / 1068 events） |
| 差异清单 | `game/mods/pineapple/diff.md`（140 独有 / 21 基线独有） |
| 验证记录（activate） | `openspec/changes/allmods-pineapple-activate/verification.md`（13 REQ） |
| 验证记录（verify） | `openspec/changes/allmods-pineapple-verify/verification.md`（10 REQ） |
| 验证报告 | `openspec/changes/allmods-pineapple-verify/reports/pineapple-verify.md`（9 章节） |

## 本 slice 的方法论产出

1. **`diff.md` 存在结构性盲区** —— 只报「基线无此名」，漏掉同名异容
   （pineapple 漏 90 处）。后续所有 MOD 必须用四象限补全。
2. **零字节 fight 必须溯源到源文件** —— 源也 0B 才能证明非构建缺陷。
3. **`CC.Effect` 项数必须用 `pairs` 计数** —— `#` 对显式 `[0]` 键表不可靠。
4. **`diff.md` 双向 set-equal** —— 数量相等不能证明集合相等。
