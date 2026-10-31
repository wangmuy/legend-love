---
status: done
created: 2026-10-26
---

# Design: allmods-pineapple-activate

> 父上下文：[`../proposal.md`](proposal.md)、[`../allmods-slice12/slice-proposal.md`](../../allmods-slice12/slice-proposal.md)

---

## ADR-001：零字节 `fight*.grp` 必须与「文件缺失」分属不同降级分支

### Context

pineapple 的 `fight016`~`fight131` 区间内共 **115** 个 `.grp` 与 `.idx` **均为 0 字节**
（区间内唯一例外 `fight072` = 57822B），而 `Person.头像代号` **恰好全部引用**这 115 个编号
（被引用 151 个，范围 1..299；**零字节集合 ⊆ 被引用集合**，115/115 全被引用，
差额 36 为正常 `OK` 包，与三分支实测 `OK=36` 吻合）。

epic 在 Slice 11（Dragon）已处理过「`fight101`/`fight102` 文件**不存在**」的情形，
当时的结论是 `FileLength → -1 → PicLoadFile 早退 → getPic 返回 nil → PicGetXY 返回 0,0`。

若直接套用该结论，pineapple 会被判为「同 Dragon」而**跳过取证** ——
这正是 Slice 2 的教训（「同形」不等于「同行为」）。

### Decision

把降级行为拆成**三个可区分分支**，并要求实测证明 pineapple 走的是哪一个：

| 分支 | 条件 | `FileLength` | `PicLoadFile` | `getPic` | `PicGetXY` |
|------|------|-------------:|---------------|----------|------------|
| `OK` | grp 非空 | `>0` | 正常填 idx | 命中 | **真实 w×h** |
| `FILE_MISSING` | 文件不存在 | `-1` | **早退**（`lib_love.lua:435`） | grp 打不开 → `nil`（`:264-267`） | `0,0,0,0` |
| `ZERO_BYTE` | 文件存在但 0B | `0` | **不早退**，`num = 0` | grp **打得开** → `idx[picid]==nil` → `nil`（`:270-273`） | `0,0,0,0` |

关键依据：`lib_love.lua:435` 的条件是 `if idxlen < 0 or grplen < 0 then return end`。
当 `grplen == 0` 时 `0 < 0` 为**假**，函数**不早退**，
随后 `num = idxlen/4 = 0`，`pic_file.idx[1] = 0` 之后 `for i=1,num` 循环体不执行，
`idx` 表只有一项 —— 于是 `getPic` 里的 `self.idx[picid]==nil` 判断成为实际失败点。

### Alternatives

1. **直接沿用 Dragon 结论**（「文件缺失 ⇒ 0,0」）
   - 放弃理由：`FileLength` 返回值不同（`-1` vs `0`），代码分支不同，
     「结论相同」不能代替「路径相同」。且若将来 `PicLoadFile` 改变对 `0` 的处理，
     两 MOD 会分道扬镳，而套用式结论无法预警。
2. **把零字节 fight 判为构建缺陷**
   - 放弃理由：源包即为 0 字节（`reference/allmods/kys-pineapple/fight/fight016.grp`），
     构建对 `resource/` 与 `fight/` 一律原样复制，是既有契约。判缺陷会导向
     「补占位图」这种偏离源数据的改动。
3. **不测正对照，只测缺失**
   - 放弃理由：只观察 `0,0` 无法区分「降级生效」与「测量方法失效」。

### Consequences

- **正**：三 MOD（Dragon / pineapple / 未来 books）的 fight 缺失/空包可归一到同一张表，
  但每格都有独立实测支撑。三态判据已实测齐备：`FileLength` = `0`（零字节）/ `>0`（正常）/ `-1`（缺失）。
- **正**：`fight072` 在 0B 区间内为非零例外（57822B），充当「零字节」判定的**边界负对照**，
  证明该判定不是按编号区间一刀切。
- **正**：`ZERO_BYTE` 的失败点在 `getPic` 内而非 `PicLoadFile`，因此**真正的风险点**
  是 `idx` 表长度为 1 时 `idx[picid+1]` 也为 `nil`，两处判断都在 `:270`。
- **负**：需要在 `Game` 里对 151 个被引用代号逐个 `pcall`，测量成本较高（可接受，秒级）。
- **约束**：不得裸调 `PicGetXY`（`picFileCache[fileid]` 为 `nil` 时会在 `:462` 抛错），
  必须先 `PicLoadFile`。

---

## ADR-002：`Person 720` 的记录数整除**不是**内容正确性的证据

### Context

`ranger.idx` offsets `[1860, 132900, 198260, 204396, 228060, 228210]` 与 grp 229680B
给出 `(720, 344, 118, 174, 3)`，五段余数全 0。这是「结构正确」的强信号，
但前 11 个 slice 已多次证明：**记录数相等 ≠ 内容相同**（Scene 负对照方法）。

pineapple 的 `Person 720` 在全 20 个 MOD 中排第 2（BookCalamity 800 第 1），
`ranger.grp` 229680B 同为第 2（BookCalamity 313242，基线 136412），
字段错位的风险面最大。

### Decision

以**四类直接证据**替代记录数推断：

1. **边界记录值**：`Person[0]=蘿卜大`、`Person[719]=空`、`Thing[0]=小續命丹`、
   `Thing[343]=天書`、`Scene[0]=許昌`、`Scene[117]=暗云蒼穹`、`Wugong[0]=普通攻擊`、
   `Wugong[173]=兌澤化三才`。
2. **事件计数与构建报告逐字相符**：`oldevent/*.lua` = **1068** = `events=1068`。
3. **对话计数与首末文本可读**：`oldtalk.idx` 14384B = **3596** = `talk=3596`；
   `oldtalk.grp` 首行「已经满级了」、末条目「…quick*ly！」。
4. **全量字符串扫描**：2764 个字符串字段，`U+FFFD` = 0，控制符 = 0。

并强制**负对照**：基线 `Person[0]=徐小俠`、`Scene[0]=胡斐居`、`Scene[2]=云鶴崖`
⇒ pineapple `Scene[0]=許昌`、`Scene[2]=兵營` 均不同。

### Alternatives

1. **只报记录数与整除**：放弃理由 —— 已被 Slice 10 的 Scene 案例证伪。
2. **只抽查 8 个边界记录**：放弃理由 —— 边界对但中段错位仍可能（如字段偏移整体平移）。
   必须配合全量字符串扫描（2764 字段）才有覆盖保证。
3. **逐字段与源 Big5 解码结果比对**：理想但成本高（需在测试内复现 Big5 解码器）；
   当前 `ranger.str` 已是转换后的真值表，抽查 `P0000→蘿卜大`、`P0002→關羽` 已足够。

### Consequences

- **正**：`Person[719]` 名字为空这类「看似异常」的值被**追溯至源数据**
  （源字节 `20 00 00 …` = `0x20` 空格填充），不会误报为缺陷。
- **负**：需要额外跑一次基线进程（无 MOD）做负对照。

---

## ADR-003：`ranger.str` 的 hint 去重是设计，不是索引错乱

### Context

初步探测发现 `ranger.grp` 中同一 `P####` hint 被多条记录复用（119 处），
且 `ranger.str` 出现 `0001,Person,-1,Nick,`（`record = -1`）。
表面看像「索引冲突 + 非法记录号」，容易被误判为工具缺陷。

### Decision

判定为**两处独立的设计行为**，并给出机器可核验的判据：

**① hint 复用 = 同值去重**
`tools/mod_encoding.lua:910-916`：

```lua
local byValue = ...                     -- 值 → 首次分配的 index
if byValue[value] == nil then
    byValue[value] = index; side[seg.name][index] = value
else
    report.dedup = report.dedup + 1     -- 同值复用
end
```

判据：对 119 处复用逐一检查「同一 hint 指向的值是否相同」⇒ **真冲突 = 0**。
若存在真冲突（同 hint 指向不同值），才是缺陷。

**② `record = -1` = 共享空 hint 占位**
`tools/mod_encoding.lua:943-957`：当字段被判定为非字符串（如 pig3dos 把 int16 塞进外号槽），
写入一个**共享的**空 hint，`side.__meta` 标记 `{ rec = -1, field = …, offset = -1, empty = true }`。
判据：该 hint 解析结果为 `""`，且只有一条。

### Alternatives

1. **判为编码转换缺陷并修 `mod_encoding.lua`**
   - 放弃理由：去重是**有意的体积优化**（`report.dedup` 是正式统计项），
     `record=-1` 是**有意的空值占位**，两者都有明确注释与 meta 标记。
     改它们会增大所有 MOD 的 `ranger.str`，且无行为收益。
2. **要求 `record` 必须是有效下标**
   - 放弃理由：`__meta.rec` 只用于调试/报告，运行时通过 `ranger.str` 按
     `(segment, index)` 查值（`mod_data.lua:517` `SideValue`），不依赖 `rec`。

### Consequences

- **正**：避免把正常去重误报为缺陷（本 epic 已因「同族判定」误报过 `head/`，见 Slice 11）。
- **负**：`ranger.str` 的行数（648）不等于记录数（720）+ 字段数，人工核对时容易困惑；
  需要在报告里明确「hint 数 ≠ 记录数」。

---

## ADR-004：`name.*` 与 `talk.*` 的关系是**逐 MOD 事实**，不是不变量

### Context

Slice 11（Dragon）实测 `name.grp` 与 `talk.grp` md5 **完全相同**（`4c41c044…`），
`name.idx` 与 `talk.idx` 也相同（`1a0c74ab…`），据此在 Dragon 的报告里写下
「`name.*` 是 `talk.*` 的历史兼容副本」。

pineapple 实测四者**两两不同**：

```
d7ea262bf2a2e5ddfdce8bfd9bd070d3  name.grp
e2b3cd0585243c555dab401acd958d30  talk.grp
793bfa542b4a4d294c09939f6220a92c  name.idx
537355667856c0d5767d236f27bb7129  talk.idx
```

且大小也不同（`name.grp` 152082B vs `talk.grp` 152098B）。

### Decision

把「`name.*` 是 `talk.*` 副本」**降级为 Dragon 的个案结论**，
不作为跨 MOD 不变量；每个 MOD 必须各自计算 md5 后判定。

两者的**共性结论**（可跨 MOD 保留）只有一条：
`name.*` 在 Lua 引擎中**无运行时消费者**（`grep -rn "name\.grp"` = 0），
审计类别为 `LEGACY`；`talk.*` 亦无运行时消费者，但**构建期**被
`mod_build.lua:916` 提取为 `script/oldtalk.{grp,idx}`。

### Alternatives

1. **沿用 Dragon 结论，声明 pineapple 也是副本**
   - 放弃理由：md5 直接反驳。
2. **判 pineapple 的 `name.*` 为「脏数据/构建冗余」**
   - 放弃理由：构建对 `resource/` 一律展平复制是既有契约（`mod_build.lua:567` 只
     `IGNORE_DIRS` 掉 `head/item/eft`）；`name.*` 属源包内容，不是构建生成。

### Consequences

- **正**：纠正了 Slice 11 报告中「副本」结论的适用范围，避免跨 MOD 误推。
- **负**：需要回头在 Dragon 的报告/ADR 里加注「仅 Dragon 成立」。

---

## ADR-005：`CC.Effect` 越界只取证、不修复

### Context

pineapple 的 `Wugong["武功动画&音效"]`（`CC.Wugong_S` offset 36）实测 **max = 83**，
而 `CC.Effect` 真实键范围只覆盖 `0..52`（53 项；源码 `[0]=9` 起显式给 `[0]` 赋值，
故 `#CC.Effect` 返回 52 **不等于**项数 53 —— 必须用 `pairs` 计数）。
越界判据是 `eft > 52`，共 **62 条 / 28 个不同越界值**（53..83）。
越界记录 **63** 条，涉及 **29** 个不同越界值。

这是 epic `TODO.md:206` 已记录的跨 MOD 问题（7/20 MOD 越界），pineapple 是首批取证对象之一。

### Decision

**只取证不修复**，取证内容为两条运行时路径的实测：

```lua
-- framework/war_async.lua:1109
local framenum = fightdelay + (CC.Effect and CC.Effect[eft] or 10) or 10
-- framework/war_async.lua:1126
if CC.Effect then for i = 0, eft - 1 do starteft = starteft + (CC.Effect[i] or 0) end end
```

实测：`eft=83` ⇒ `framenum=10`（`CC.Effect[83]==nil` 触发 `or 10`）、
`starteft=712`（`sum(0..52)`，53..82 贡献 0），`pcall` 均 `true`；
对照末有效值 `eft=52` ⇒ `framenum=7`、`starteft=705`（探针取 `fightdelay=0` 隔离）。

**不修复的三条理由**：

1. 修复点是 `game/script/jyconst.lua` 的 `CC.Effect={…}` —— **禁用路径**。
2. 正确修复不是「补 53..83 的默认值」，而是从 `list/effect.bin` 重建该表；
   `list/effect.bin` 当前归 `PENDING`（pineapple 的 39 项 PENDING 之一），
   提升为 REQUIRED 会牵动 20 个 MOD 的审计分类。
3. 越界**不崩溃**（`or 10` / `or 0` 双兜底），只导致特效帧数偏短 ⇒ 无功能阻断。

⇒ 归入 epic 级 spike `allmods-effect-table`（与 RiverLake 的同一 spike）。

### Alternatives

1. **在本 change 里给 `CC.Effect` 补默认值到索引 83**
   - 放弃理由：禁用路径 + 会掩盖真实数据缺失（补的值是猜的）。
2. **把越界记录截断到 51**
   - 放弃理由：改 `ranger.grp` 数据 = 偏离源包，且会改变战斗表现。
3. **判为 MOD 数据错误，要求作者修**
   - 放弃理由：7/20 MOD 都有此现象 ⇒ 更可能是 C 引擎有更大的内置表，
     Lua 侧移植不全，属**移植缺陷**而非 MOD 缺陷。

### Consequences

- **正**：spike 有了第一份**双向实测**（正常值 + 越界值）证据，而非仅统计计数。
- **负**：pineapple 的战斗特效帧数会偏短，属已知可接受偏差，须在报告中说明。

---

## ADR-006：`icon.png` 归 `REQUIRED` 是 `BY_KIND` 兜底，不改

### Context

pineapple 新增 `resource/icon.png`（9383B），`grep -rn "icon\.png"` **0 命中**。
审计把它标为 `REQUIRED`（`in_product=true`）。

Dragon 已发现同类问题 6 个（`cloud.{grp,idx}`、`title.{grp,idx}`、`open.png`、`end.png`），
`icon.png` 是第 7 个成员，且**只在 pineapple 出现**。

### Decision

判定为 **`BY_KIND` 兜底归类**（`mod_audit.lua:264-269`：
`resource|.grp` / `resource|.idx` / `resource|.png` → `REQUIRED`），
**不在本 change 改判定**。

理由：改判定需把 6~7 个文件从 `REQUIRED` 改为 `LEGACY`，
会改变 **20 个 MOD** 的 `REQUIRED` / `LEGACY` 计数，进而需要重跑并更新
12 个既有 slice 的审计数字 —— 属独立 change 的爆炸半径。

### Alternatives

1. **本 change 内改判 `icon.png` 为 `LEGACY`**
   - 放弃理由：破坏「审计口径跨 slice 可比」这一前提。
2. **判 `icon.png` 是构建冗余缺陷**
   - 放弃理由：构建对 `resource/` 展平复制是契约；源包里有它，产物里有它是正确的。

### Consequences

- **正**：口径稳定，Slice 12 的审计数字与 Slice 10/11 可直接对比。
- **负**：`icon.png` 被多带进产物（9383B），无害但非最小化；
  已在 `TODO.md` 列为待决策项。

---

## ADR-007：门禁 7 的比对必须按 `isSaveSlotFile` 真实路由

### Context

Slice 11 曾把门禁 7 写成「20 MOD `save/` vs 源 → 451 文件，不一致 = 0」，
实测为 **430 全等 + 21 差异**（`ranger.grp` ×20 经 Big5→UTF-8 转换、`ranger.idx` ×1 由
`RepairIdx` 重建），已在该 slice 修正。

pineapple 也有 `ranger.*` 模板（`ranger.grp` 229680B 为全 MOD 最大），
若沿用错误口径会重复出现「不一致」误报。

### Decision

门禁 7 的比对脚本必须复现 `mod_build.lua:665-670` 的路由逻辑：

```lua
-- mod_build.lua:626-631
local function isSaveSlotFile(name)
    return name:match("^[rds]%d+%.(grp|idx)$") ~= nil
end
-- :665-670
local target = isSaveSlotFile(name) and (outDir .. "save/" .. name)
                                   or  (outDir .. "data/" .. name)
```

判据分两级：

| 级 | 判据 | 期望 |
|----|------|------|
| 1 | 源 `save/` 中的**槽文件**在产物 `save/` 中逐字节相等 | 341 个，差异 0 |
| 2 | 源 `save/` 中的**模板**在产物 `data/` 中等长（内容可因编码转换而不同） | 110 个，长度差异 0 |

「真实问题」定义为：**目标文件不存在** 或 **槽文件字节不等** 或 **模板长度不等**。

### Alternatives

1. **只统计「文件数相等」**
   - 放弃理由：Slice 11 已证明这会掩盖 21 项差异。
2. **要求模板也必须逐字节相等**
   - 放弃理由：`ranger.grp` 的 Big5→UTF-8 转换是 `allmods-encoding-convert` 的
     既定设计（hint 重写 + 旁路表），字节必然不同。

### Consequences

- **正**：门禁 7 的口径在三处文档（epic.md / activate verification / verify tasks §15.9）统一。
- **负**：比对脚本比「文件数相等」复杂，需正确处理模板类。

---

## Negative Constraints

以下做法在本 change 中**明令禁止**：

| # | 禁止 | 理由 |
|---|------|------|
| 1 | 以「记录数整除」代替「内容正确」 | Slice 10 已用 Scene 负对照证伪 |
| 2 | 用 `PicGetXY` 裸调（未先 `PicLoadFile`）作降级证据 | 会在 `lib_love.lua:462` 抛错，属测量方法错误 |
| 3 | 把零字节 fight 与文件缺失混为一谈 | `FileLength` 为 `0` vs `-1`，分支不同 |
| 4 | 为零字节 fight 生成占位图或删除 | 偏离源包；引擎已优雅降级 |
| 5 | 把 `CC.Effect` 越界判为 MOD 数据缺陷 | 7/20 MOD 共有 ⇒ 更像 Lua 移植未覆盖 |
| 6 | 把 `ranger.str` 的 hint 去重 / `record=-1` 判为工具缺陷 | 均为有注释的设计行为 |
| 7 | 沿用「`name.*` 是 `talk.*` 副本」到其他 MOD | md5 逐 MOD 不同，不是不变量 |
| 8 | 用 `CC.MoneyID` 单独证明 `kysmod.ini` 生效 | 基线 `jyconst.lua:435` 已定义 174 |
| 9 | 写 `CC.LIFE_HURT` | 正确字段是 `CC.LifeHurt`（`mod_ini.lua:187`） |
| 10 | 在本 change 修 `not_in_product` / `icon.png` 判定 | 改工具契约 = 独立 change |
| 11 | 改 `game/engine-love2d/**`、`game/engine-mud/**`、`jyconst.lua` 常量、`reference/allmods/**` | 四禁改路径 |
| 12 | 用 `mod_audit.lua pineapple`（位置参数）取数 | 会静默审计全 20 MOD，得 `total=11220` |

---

## Review Checklist

- [x] REQ-PIN-1 构建输出逐字匹配 `data files=348 … talk=3596`
- [x] REQ-PIN-2 `Σ(类别) = 529` 且等于源文件总数
- [x] REQ-PIN-3 `gaps=0`
- [x] REQ-PIN-4 16/16 PASS，且调用带 5 个期望值参数
- [x] REQ-PIN-5 五段余数全 0，且段数异于基线
- [x] REQ-PIN-6 四类证据齐备，含基线负对照
- [x] REQ-PIN-7 10 项 `nil→有值`，字段名为 `CC.LifeHurt`
- [x] REQ-PIN-8 三分支可区分，含 `OK` 正对照，`pcall` 全 true
- [x] REQ-PIN-9 `framenum` 10 vs 7、`starteft` 712 vs 705 双向对照（`fightdelay=0` 隔离）
- [x] REQ-PIN-10 `icon.png` 0 命中，归类来源已指明
- [x] REQ-PIN-11 四 md5 两两不同，且与 Dragon 对照
- [x] REQ-PIN-12 复用 119 处、真冲突 0；`record=-1` 解析为 `""`
- [x] REQ-PIN-13 8 道门禁逐条实跑
- [x] Blast Radius 未越界（四禁改路径 `git status` 为空）
- [x] 未违反 12 条 Negative Constraints
