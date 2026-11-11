# Design: allmods-dragon-activate

## Negative Constraints

- **不得**改 `game/engine-love2d/**`、`game/engine-mud/**`、`game/script/jyconst.lua` 常量定义、
  `reference/allmods/**`。
- **不得**把 `hdgrp` 267 条目数差异判为结构异常（ADR-001 索引驱动判据）。
- **不得**把 `eft` 714 同形表述为「回退原版」（源文件存在且被复制，只是内容与基线相同）。
- **不得**把 `fight101`/`fight102` 缺失表述为「构建缺陷」（MOD 源本身没有；
  引擎需优雅降级而非报错）。
- **不得**用「记录数相同」作为内容已加载证据；Dragon 段数全异，但判据必须双向可用。
- **不得**把 `head/` 220 PNG 判为「需要」而无证据（ADR-004）。
- **不得**把 `war1.sta` 归为「回退原版」（引擎零引用，不是回退使用的路径）。
- **不得**把「源 `save/` 无 `.idx`」当作事实（实测有 `alldef.idx`/`allsin.idx`/`ranger.idx`）。

---

## ADR-001：`hdgrp` 267 —— 判据第 7 次应用

### Context

`hdgrp.idx` = 1068 字节 ⇒ 267 条目（基线 115，+152）。前 6 个样本已建立三重判据。

### Decision

沿用三重判据：

| 判据 | 证据 |
|------|------|
| ① 索引驱动 | `lib_love.lua:437` `local num = idxlen/4` —— 条目数由文件长度决定 |
| ② 无固定计数常量 | `grep -rn "hdgrpNum\|HDGRPNum\|HDPicNum\|MAX_HEAD" engine-love2d/ framework/ script/jyconst.lua` → **0 命中** |
| ③ 字节无缺口 | `format_spec --mod Dragon` → `gaps=0` |

⇒ **内容差异**（MOD 确实多 152 张头像），零引擎改动。

### Consequences

外推链 **125 / 129 / 173 / 178 / 204 / 252 / 267** 七次一致。
该判据在此已可视为**稳定收敛**（7 个样本、跨度 115→696 即将由 books 检验）。

---

## ADR-002：`eft` 714 同形 —— 「同形」≠「回退原版」

### Context

Dragon 的 `eft.idx` = 2856B（714 条目）、`eft.grp` = 691627B，与 pascal 基线**完全相同**，
且**逐字节相同**：

```
1c5aef33893e078ade30f6d237ec6cb1  data/eft.grp
35ccc7e5cc1a096e183d3ff2919f743b  data/eft.idx
1c5aef33893e078ade30f6d237ec6cb1  mods/Dragon/data/eft.grp
35ccc7e5cc1a096e183d3ff2919f743b  mods/Dragon/data/eft.idx
```

### Decision

判为 **「MOD 未修改该资源」**（内容差异为零），**不得**表述为「回退原版」。

区分依据：

| 情形 | 源存在 | 产物存在 | 运行时路径 |
|------|:------:|:--------:|-----------|
| **同形（本 MOD）** | ✅ | ✅ | `mods/Dragon/data/eft.*`（**MOD** 目录） |
| **回退原版** | ❌ | ❌ | `data/eft.*`（**基线**目录） |

实测（`CC.EffectFile`）：

```
CC.EffectFile[1] = mods/Dragon/data/eft.idx
CC.EffectFile[2] = mods/Dragon/data/eft.grp
```

⇒ 路径指向 **MOD 目录**，只是文件内容恰好与基线相同。

### Alternatives

- **判为「回退原版」**：会掩盖「源文件存在且被复制进产物」这一事实，
  且会导致「差异报告里 268 项 MOD 独有里为何没有 `eft.*`」的误判。
  **否决**。
- **判为「构建遗漏」**：产物里明明有该文件，**否决**。

### Consequences

- ✅ `eft` 维度本 slice **零工作量**，但必须留下「为何零工作量」的证据链。
- ⚠ 这修正了「同形 = 回退」的直觉陷阱 —— 与 Slice 10 的 Scene 阴性对照互补：
  RiverLake 是「**计数**相同但内容不同」，Dragon 是「**内容**相同但来源是 MOD」。
  两者共同确立「来源」与「内容」两个正交维度。

---

## ADR-003：`fight101`/`fight102` 缺失 —— MOD 删了贴图但数据仍引用

### Context

`diff.md` 显示基准独有含 `fight101.{grp,idx}`、`fight102.{grp,idx}` —— 即基线有、Dragon 没有。

同时实测 Dragon 的 `Person["头像代号"]`：

```
Person 总数=589 有头像代号=217 最大=219
引用 101 ? true   引用 102 ? true
```

⇒ **MOD 的数据仍引用 101/102，但 MOD 没提供这两个文件**。

### Decision

判为 **MOD 作者侧的数据不一致**（非构建缺陷），并要求证明引擎**优雅降级**。

引擎降级链（三级）：

1. `PicLoadFile(idxfilename, grpfilename, fileid)`
   → `idxlen = FileLength(idxfilename)`；
   `FileLength`（`lib_love.lua:281-288`）打开失败返回 **-1**
   → `if idxlen < 0 or grplen < 0 then return end` —— **提前返回，不建索引**。
2. `PicFile:getPic(picid)`
   → `self.idx[picid] == nil` → `Debug(...)` + `return nil`
   → 或 `f == nil`（`FileUtil.open` 失败）→ `Debug(...)` + `return nil`。
3. `PicGetXY(fileid, picid)` 上游已有 `picFileCache[fileid]` 的 nil 保护。

实测：

```
PicLoadFile(缺失 fight101) pcall=true err=nil
PicGetXY        pcall=true ret=0
```

⇒ **不崩溃**，仅该头像显示为空。

### Alternatives

- **从基线 `data/` 复制 `fight101/102` 进产物**：等于篡改 MOD 数据，
  且会让「MOD 独有/基准独有」的差异报告失真。**否决**。
- **修改数据把头像代号 101/102 改到别的值**：篡改 MOD 内容。**否决**。

### Consequences

- ✅ 本 epic 首个「MOD 删掉资源但数据仍引用」样本（RiverLake 的 0 字节 fight 是
  「文件在但内容空」，Dragon 是「文件根本不在」—— 两种不同降级路径）。
- ✅ 归入 `needs=false` + 引擎容错，无需修复。
- ⚠ 若未来引入「缺失资源告警」，此 MOD 会产生 2 条告警（属正常，非错误）。

---

## ADR-004：`head/` 220 PNG = `EDITOR_DUMP` —— 第 3 次同类判定

### Context

`reference/allmods/kys-Dragon/head/` 有 220 个 PNG（`0.png`~`219.png`）。

### Decision

判为 `EDITOR_DUMP`（UPedit 编辑器副产物，非运行时数据源），四条机器可复核证据：

| # | 证据 | 实测 |
|---|------|------|
| 1 | 构建忽略该目录 | `tools/mod_build.lua:567` `local IGNORE_DIRS = { head = true, item = true, eft = true }` |
| 2 | 引擎零引用 | `grep -rn 'head/\|"head"' engine-love2d/ framework/ script/` → **0 命中** |
| 3 | 产物无该目录 | `ls mods/Dragon/` → `data diff.md encoding-report.md save script sound`（无 `head/`） |
| 4 | 审计归类 | `mod_audit` 220 项全 `EDITOR_DUMP` / `in_product=false` |

运行时头像数据源 = `hdgrp.{idx,grp}`（267 条目），PNG 只是编辑器预览图。

### Consequences

- 第 3 次同类判定（Slice 6 GodsDevils `head/`+`item/` 279 个 / Slice 9 ptt `eft/` 105 个 /
  本 slice `head/` 220 个）—— 判据稳定，可复用。
- 220 项占本 MOD 源文件总数的 27%（220/811），是 `not_in_product` 的绝对主体。

---

## ADR-005：`war1.sta` `DEAD_FILE` —— 与 RiverLake `allsinbk.grp` 的区别

### Context

`reference/allmods/kys-Dragon/resource/war1.sta` = 66030 字节（`66030 ÷ 186 = 355` 记录，
`CC.WarDataSize=186`）。产物里**有**该文件（`mods/Dragon/data/war1.sta` 66030B）。

同时 `resource/war.sta` = 42222B（227 记录）也存在且进产物。

### Decision

判为 `DEAD_FILE`（not `needed`），三条证据：

| # | 证据 | 实测 |
|---|------|------|
| 1 | 常量只指向 `war.sta` | `script/jyconst.lua:129` `CC.WarFile = CONFIG.DataPath .. "war.sta"` |
| 2 | 代码零引用 | `grep -rn "war1" script/ framework/ engine-love2d/` → **0 命中** |
| 3 | 审计已标注 | `tools/mod_audit.lua:189` `["resource/war1.sta"] = { category="DEAD_FILE", needed=false, ... }`，证据串含「引擎只读 war.sta，war1.sta 不可达」 |

### 与 RiverLake `allsinbk.grp` 的区别（必须显式说明）

| 维度 | RiverLake `allsinbk.grp` | Dragon `war1.sta` |
|------|--------------------------|-------------------|
| 常量 | **存在**（`CC.TempS_Filename`） | **不存在** |
| 传参 | **传入** `LoadSMap(sFile, CC.TempS_Filename, ...)` | 从不传入 |
| 引擎侧 | 形参 `tmpfilename` 声明但**未使用** | 完全无代码路径 |
| 归类 | 「死文件」（本 epic 第 4 类「基准独有」判定的 D 类） | 审计 `DEAD_FILE` 规则 |
| 语义 | **路径被引用 ≠ 内容被使用** | **路径从未被引用** |

⇒ 两者都「不被读取」，但机制不同：RiverLake 是「传了但不用」，
Dragon 是「压根没传」。报告中不得混为一谈。

### Consequences

- ✅ 产物中保留 `war1.sta`（源有则复制，不主动删；`mod_audit` 已标 `needed=false`）。
- ⚠ 本 epic 首个由 `mod_audit` **规则**（而非运行时取证）标注的 `DEAD_FILE`。

---

## ADR-006：`war.sta` 同名不同内容 —— 内容差异，非结构异常

### Context

| 文件 | 源（= 产物） | 基线 `data/` |
|------|------------:|-------------:|
| `war.sta` | **42222**（227 记录） | 26040（140 记录） |

记录结构（`CC.WarDataSize = 186`）两处均整除：`42222 ÷ 186 = 227`、`26040 ÷ 186 = 140`。

### Decision

判为**内容差异**（MOD 增加了 87 场战斗的配置数据）。

判据 = ADR-001 的同族：**结构不变（186B/记录整除）+ 字节全覆盖（`gaps=0`）+ 无固定计数常量**
（`mod_data.lua:631` 注释明确「war.sta 记录数（无索引文件，靠 warid*WarDataSize 定位）」）。

### Consequences

- ✅ 与 119 新增战斗呼应（战斗配置与战斗贴图同步扩展）。
- ⚠ 记录数与 `fight` 数不必相等（`war.sta` 记录 = 战斗配置，`fight*.grp` = 战斗动画），
  不得用「记录数 = fight 数」作判据。

---

## ADR-007：25 项「基准独有」五分法 —— 新增第 5 类「数据引用但资源缺失」

### Context

`diff.md`「基准独有」= 25 项。前 10 个 slice 建立的是四类（在 save/ / 首次播种 /
回退原版 / 死文件）。Dragon 出现一组**无法归入任何已有类别**的项：
`fight101.{grp,idx}` + `fight102.{grp,idx}`。

### Decision

新增 **E 类「数据引用但资源缺失」**，四类扩为五类：

| 类别 | 项数 | 本质 |
|------|-----:|------|
| A 在 save/（源自带存档） | 9 | 基准与 MOD **都有**（MOD 也提供存档） |
| B 首次播种 | 9 | 源**无** `.idx`，运行时由 `SeedSaveSlot` 从 MOD 模板播种 |
| C 回退原版 | 2 | 源**无**，运行时路径指向基线 `data/` |
| D 死文件 | 1 | 源**有**，但引擎**不读**（形参零引用） |
| **E 数据引用但资源缺失** | **4** | 源**无**，产物**无**，但数据**仍引用** |

Σ = 9 + 9 + 2 + 1 + 4 = **25** ✅

### 判据（可执行）

| 类别 | 源有 | 产物有 | 运行时 | 数据引用 |
|------|:----:|:------:|--------|:--------:|
| A | ✅ | ✅（save/） | MOD `save/` | — |
| B | ❌ | ✅（save/，播种） | MOD `save/` | — |
| C | ❌ | ❌ | 基线 `data/` | — |
| D | ✅ | ✅ | 从不读 | — |
| **E** | ❌ | ❌ | 尝试 MOD `data/` 失败 | **✅ 仍引用** |

E 类的决定性判据 = **数据里的 id 指向不存在的文件**：
```lua
for i=0,JY.PersonNum-1 do v=JY.Person[i]["头像代号"] ... end
-- Person 总数=589 有头像代号=217 最大=219
-- 引用 101 ? true   引用 102 ? true
```
同时 `CC.FightPicFile = mods/Dragon/data/fight%03d.{idx,grp}` 指向 MOD 目录 ⇒ 必然找不到。

### Alternatives

- **归入 C（回退原版）**：C 是「运行时路径指向基线」，但 `CC.FightPicFile[1]` 实测为
  `mods/Dragon/data/fight%03d.idx`，**不**含回退逻辑（格式串不含 `ModData.Resolve`）。
  **否决**。
- **归入 D（死文件）**：D 是「源里有、引擎不读」；E 是「源里没有、引擎想读但读不到」。
  **否决**。
- **判为构建缺陷**：MOD 源本身就没有这 4 个文件，构建无遗漏。**否决**。

### Consequences

- ✅ 本 epic 首个「**MOD 删了资源，数据没跟着改**」样本 —— 属 MOD 作者侧数据不一致。
- ✅ 与 RiverLake 的 0 字节 fight（文件在、内容空）共同覆盖「缺资源」的两种形态：
  **0 字节** vs **完全缺失**。两者的引擎降级路径不同：
  0 字节 → `LoadPic` 头检查失败返回 nil；完全缺失 → `FileLength = -1` 提前 return。
- ⚠ 归入 `needs=false`，不复制基线文件、不篡改 MOD 数据（ADR-003）。
