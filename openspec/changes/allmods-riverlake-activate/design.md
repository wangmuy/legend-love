---
status: done
parent_change: allmods-riverlake-activate
---
# Design: allmods-riverlake-activate

## Negative Constraints

1. **不得**修改 `game/engine-love2d/**`、`game/engine-mud/**`、`game/script/jyconst.lua` 的常量定义、`reference/allmods/**`。
2. **不得**用「均回退原版」这类笼统表述替代逐项定性。
3. **不得**用「记录数相同」作为「MOD 内容已加载」的证据 —— 必须用非基线值
   （RiverLake `Scene=84` 与基线相同，故必须改用**内容**证据）。
4. **不得**把内容差异（更多事件 / 更多战斗 / 更多记录）判为结构异常。
5. **不得**把播种槽归为「回退原版」或「死文件」。
6. **不得**硬编码 MOD 尺寸或记录数（`PersonNum=325` 必须由 `idx` 推导）。
7. 测试写产物 `mods/RiverLake/save/` 时必须备份 + 恢复。

---

## ADR-001：记录段差异判据 —— 索引驱动 + 段长整除 + 边界可读

### Context

RiverLake 的 `ranger.idx` 给出 6 个偏移：

```
[836, 59986, 107296, 111664, 124720, 124870]
```

段长与记录尺寸（`CC.PersonSize=182`、`ThingSize=190`、`SceneSize=52`、`WugongSize=136`、`ShopSize=50`）：

| 段 | 段长 | ÷ 记录尺寸 | 记录数 | 基线 | 差异 |
|----|-----:|-----------:|-------:|-----:|-----:|
| Person | 59150 | 182 | **325** | 320 | +5 |
| Thing | 47310 | 190 | **249** | 200 | +49 |
| Scene | 4368 | 52 | **84** | 84 | **0（同）** |
| Wugong | 13056 | 136 | **96** | 93 | +3 |
| Shop | 150 | 50 | 3 | 3 | 0 |

### Decision

判据沿用 Slice 8/9（索引驱动）：

1. 记录数由 `idx` 段长除以 `CC.*Size` 得出（`jymain.lua:1747-1752` 的实际加载逻辑），
   **无任何固定计数常量**（`grep` 引擎无 `320`/`200`/`84`/`93` 硬编码）。
2. 4 段全部**整除**（余数 0）。
3. 边界记录**可读且非空**（`Person[324]="袁冠南"`、`Thing[248]="玄虛刀法"`、
   `Scene[83]="圣堂"`、`Wugong[95]="玄虛刀法"`）。
4. 字节级无缺口（`format_spec --mod RiverLake` → `gaps=0`）。

⇒ **内容差异**，零引擎改动。

### 阴性对照（本 slice 新增，关键）

`Scene` 段 **84 = 基线 84**，是本 epic 首次出现「段数与基线相同但需证明内容来自 MOD」。

判据必须能区分「段数相同」与「内容未加载」。实测对照：

| 记录 | RiverLake | pascal |
|------|-----------|--------|
| `Scene[0]` | **盛京** | 胡斐居 |
| `Scene[1]` | 河洛客棧 | 河洛客棧 |
| `Scene[2]` | **靈鷲宮** | 雲鶴崖 |
| `Scene[83]` | **圣堂** | 聖堂 |

段数相同但 4 个抽样中 3 个内容不同 ⇒ 内容是 MOD 的，**不是回退原版**。
`Scene[1]` 相同属正常（MOD 保留了原版场景）。

**因此本 change 明确禁止使用「记录数相同 ⇒ 内容已加载」的推理**（负约束 3）；
`Scene` 段的内容证据是**逐条名称比对**，而非计数。

### Alternatives

- **用 `ranger.grp` 字节数变化证明**（124870 vs 114242）：只能证明文件不同，不能证明
  引擎加载了它。**否决**（间接证据）。
- **用 `gaps=0` 单独证明**：只证明格式合法，不证明内容来源。**否决**（不充分）。
- **比对全部 84 条 Scene 名称**：本次抽样 4 条（含首尾）已足够区分；全量比对属 verify
  的证据加强项。

### Consequences

- ✅ 判据可在「段数同」与「段数异」两种情况下给出结论。
- ⚠ `Scene` 段的证明强度依赖**抽样比对**而非计数 —— 已在 verify 中补全量比对。

---

## ADR-002：`hdgrp` 252 —— 判据第 6 次应用

### Context

`hdgrp.idx` = 1008 字节 = **252** 条目（基线 115，+137）。这是判据外推链的
第 6 个样本（125/129/173/178/204/**252**）。

### Decision

沿用三重判据：

1. **索引驱动**：条目数 = `hdgrp.idx` 字节数 / 4（每个条目一个 `uint32` 偏移）。
2. **无固定计数常量**：`grep -rn '115\|hdgrpNum\|HEADNUM' game/engine-love2d game/script/jyconst.lua`
   无硬编码。
3. **字节层无缺口**：`format_spec --mod RiverLake` → `gaps=0`（`hdgrp.idx` 与 `hdgrp.grp`
   的偏移/长度对全部闭合）。

### Consequences

- ✅ 第 6 个样本仍与判据一致 ⇒ 外推链稳定。
- 判据未因样本增多而松弛。

---

## ADR-003：`eft` 921 —— 索引闭合通过，但发现 `CC.Effect` 截断（**范围外**，记录为 spike）

### Context

`eft.idx` = 3684 字节 = **921** 条目（基线 pascal 714，+207）。ptt（Slice 9）记录 `eft`
**同形**（714 = 714），故本 MOD 是首个 `eft` 差异样本。

偏移闭合完全正常：

| 检查 | RiverLake | pascal |
|------|-----------|--------|
| 条目数 = `idx` 字节数 / 4 | 921 | 714 |
| 偏移单调不减 | ✅ | ✅ |
| `idx[-1] == eft.grp` 字节数 | **1078261 == 1078261** | 691627 == 691627 |

`PicLoadFile`（`lib_love.lua:423-451`）完全由 `idxlen/4` 驱动，无固定计数 ⇒ **`eft.idx` 侧零问题**。

### 但发现：`CC.Effect` 是硬编码 53 项表，与 `eft.idx` 规模脱钩

**两张表的语义（本轮实测确认，关键）**：

| 文件 | 语义 | RiverLake | pascal |
|------|------|----------:|-------:|
| `list/effect.bin` | **每个效果**的帧数（int16 序列），项数 = 效果个数 | **70** 项 | 64 项 |
| `eft.idx` | **逐帧**偏移表，条目数 = `sum(effect.bin)` | 921 | 714 |
| `CC.Effect` | 硬编码 53 项快照（= `effect.bin[0..52]`，`[0]` 被改成 9） | — | — |

3 个 MOD 的 `sum(effect.bin) == eft.idx` **精确相等**（RiverLake 921 / BookCalamity 2857 /
pineapple 1378），其余因尾部补零差 1–44。`CC.Effect[0]=9` vs `effect.bin[0]=10` 是基线既存 1 帧偏差。

`script/jyconst.lua:439` 的 `CC.Effect` 是**字面量表**（`[0]=9,14,17,...`，共 53 项，sum=712），
`war_async.lua:1106-1128` 用它算动画帧：

```lua
local framenum = fightdelay + (CC.Effect and CC.Effect[eft] or 10) or 10
for i = 0, eft - 1 do starteft = starteft + (CC.Effect[i] or 0) end
```

实测 20/20 MOD 的 `JY.Wugong[i]["武功动画&音效"]`（= eft id）上界：

| MOD | wugong 数 | eft id 最大 | 越 `CC.Effect`(53) | 越自带 `effect.bin` | `eft.idx` |
|-----|----------:|------------:|-------------------:|--------------------:|----------:|
| pascal（基线） | 93 | 52 | **0** | 0/64 | 714 |
| Dragon / dream / GodsDevils / HeavenSword / lostbook / loving / lyff / pig / stronger / SweeOan / zheng / ptt | 93–114 | 52 | 0 | 0 | 714 |
| **RiverLake** | 96 | **69** | **10** | 0/70 | 921 |
| books | 100 | 55 | 2 | 0/64 | 973 |
| awaken | 163 | 53 | 1 | 0/64 | 727 |
| **pineapple** | 174 | **83** | **62** | 0/84 | 1378 |
| **mingdong** | 220 | **168** | **136** | 0/200 | 2268 |
| **BookCalamity** | 398 | **198** | **296** | 0/200 | 2857 |
| **pig3dos** | 202 | **85** | **52** | **21/64** ⚠ | 714 |

⇒ **7/20 MOD 越出 `CC.Effect`**；**pig3dos 连 MOD 自己的 `effect.bin` 都越界**
（该 MOD 已在 `annotated-problematic` 名单内，属其数据自身问题）。

**权威来源已定位**：`list/effect.bin` —— `reference/allmods/UPedit/UPedit.ini:80`
明确映射 `Effect=list\effect.bin`。20/20 MOD 均有该文件。

### Decision

判据沿用 Slice 8/9（索引驱动）：

1. 记录数由 `idx` 段长除以 `CC.*Size` 得出（`jymain.lua:1747-1752` 的实际加载逻辑），
   **无任何固定计数常量**（`grep` 引擎无 `320`/`200`/`84`/`93` 硬编码）。
2. 4 段全部**整除**（余数 0）。
3. 边界记录**可读且非空**（`Person[324]="袁冠南"`、`Thing[248]="玄虛刀法"`、
   `Scene[83]="圣堂"`、`Wugong[95]="玄虛刀法"`）。
4. 字节级无缺口（`format_spec --mod RiverLake` → `gaps=0`）。

⇒ **内容差异**，零引擎改动。

### 阴性对照（本 slice 新增，关键）

`Scene` 段 **84 = 基线 84**，是本 epic 首次出现「段数与基线相同但需证明内容来自 MOD」。

判据必须能区分「段数相同」与「内容未加载」。实测对照：

| 记录 | RiverLake | pascal |
|------|-----------|--------|
| `Scene[0]` | **盛京** | 胡斐居 |
| `Scene[1]` | 河洛客棧 | 河洛客棧 |
| `Scene[2]` | **靈鷲宮** | 雲鶴崖 |
| `Scene[83]` | **圣堂** | 聖堂 |

段数相同但 4 个抽样中 3 个内容不同 ⇒ 内容是 MOD 的，**不是回退原版**。
`Scene[1]` 相同属正常（MOD 保留了原版场景）。

**因此本 change 明确禁止使用「记录数相同 ⇒ 内容已加载」的推理**（负约束 3）；
`Scene` 段的内容证据是**逐条名称比对**，而非计数。

### Alternatives

- **用 `ranger.grp` 字节数变化证明**（124870 vs 114242）：只能证明文件不同，不能证明
  引擎加载了它。**否决**（间接证据）。
- **用 `gaps=0` 单独证明**：只证明格式合法，不证明内容来源。**否决**（不充分）。
- **比对全部 84 条 Scene 名称**：本次抽样 4 条（含首尾）已足够区分；全量比对属 verify
  的证据加强项。

### Consequences

- ✅ 判据可在「段数同」与「段数异」两种情况下给出结论。
- ⚠ `Scene` 段的证明强度依赖**抽样比对**而非计数 —— 已在 verify 中补全量比对。

---

## ADR-004：额外战斗三重确认（127 场，本 epic 第 2 多）

### Context

产物 `fight*.grp` = **219**；基线 = 92；差集 = **127**。
（本 epic 最多是 awaken 237 / +145；RiverLake 219 / +127 为第 2。）

### Decision

三重确认，缺一不可：

1. **`diff.md` 列出**：`mods/RiverLake/diff.md` 的 `+ fightNNN.grp` 条目数 = 127。
2. **产物存在**：`comm -13` 差集 = 127。
3. **审计归类**：`mod_audit` 中 219 个 `fight*.grp` **全部** `REQUIRED` 且 `in_product=true`。

三条清单必须**逐个文件名精确一致**（不只比数量）。实测：

```
diff.md 提及 fight*.grp: 127
diff.md set == 差集 set: True
diff.md 独有: []     差集独有: []
```

### Why not fewer checks

Slice 5 曾发现「差集数量一致但清单不同」的假阳性风险；Slice 7 起固定为
「清单逐个比对 + 抽样内容验证」。

### Consequences

- ✅ 127 场额外战斗是被引擎按索引加载的真实内容（清单逐个一致）。
- ⚠ **127 个中 44 个为 0 字节**（源如此，逐字节一致）—— 见 ADR-007。
  故有效美术内容为 **83** 场；但 44 个空文件必须保留（索引语义），
  故 `fight` 计数仍按文件数记为 **219 / +127**。
- 采样 5 场（首/中/尾/两个边界）：`fight030`(96 帧) / `fight123`(**0 字节**) /
  `fight155`(32 帧) / `fight187`(44 帧) / `fight218`(**0 字节**)。

---

## ADR-005：空 WAV 容错（28 个 0 字节 `e72`~`e98`）

### Context

源 `sound/` 有 **28 个 0 字节 WAV**（`e72.wav`~`e98.wav`，连续 27 个 + 检查边界）。
Slice 0c 已记录但未验证运行时行为。

### Decision

不改引擎、不改数据，验证 `PlayWAV`（`engine-love2d/lib_love.lua:602-621`）的容错：

```lua
local success, source_or_err = pcall(love.audio.newSource, filepath, "static")
if success then source_or_err:play() end
```

`pcall` 吞掉空文件的解码错误 ⇒ 静音继续，不中断游戏。

验证方式：
1. 28 个文件**原样**进产物（`sound` 计数 170 包含它们）。
2. 真实启动链路跑 10 帧无报错。
3. `file_exists && size==0` 显式列出。

### Alternatives

- **补 28 个静音 WAV**：修改了 MOD 数据，破坏「产物 = 源 + 格式转换」不变式。**否决**。
- **删除 28 个空文件**：会让 `e72`~`e98` 的音效 ID 索引错位风险。**否决**。

### Consequences

- ✅ 空文件被安全容忍，零改动。

---

## ADR-006：`name.grp`/`name.idx` = `LEGACY`

### Context

源 `resource/name.grp`（+ `name.idx`）在 RiverLake 中存在，但差异报告显示为 **MOD 独有**
（基线 `data/` 无同名文件）。需判定它是「需要」还是「不需要」。

### Evidence（机器可复核）

| # | 证据 | 命令 | 结果 |
|---|------|------|------|
| 1 | 代码中无 `name.grp` 引用 | `grep -rn 'name\.grp' game/engine-love2d/ game/framework/ game/script/` | 0 命中（`EV_LEGACY_NAME`） |
| 2 | `CC.*` 常量表无 name 项 | `grep -n 'name' game/script/jyconst.lua` | 仅 `NameSize`/`Name` 字段名，无文件路径常量 |
| 3 | 产物中不存在 | `ls game/mods/RiverLake/data/name.grp` | 不存在 |
| 4 | 审计归类 | `mod_audit --mod RiverLake` | `LEGACY`（`in_product=false` 一致） |

### Decision

归 `LEGACY`：源里保留、产物不带、运行时零影响。理由：编辑器（UPedit）产出但引擎不读。

### Consequences

✅ 不构成「必需但缺失」。LEGACY 共 5 项（`name.{grp,idx}`、`list/*.txt` 2 项、另 1 项）。

---

## ADR-007：**44 个 0 字节 `fight*.grp`** —— 源数据既存缺陷，优雅降级（本 epic 首次发现）

### Context

`fight` 差集 127 个，其中**大量为 0 字节**。这是本 epic 前 9 个 slice 未出现的现象
（`fight` 计数此前一律按「文件数」统计，未检查内容长度）。

### Evidence（机器可复核）

**1. 源 vs 产物逐字节一致，0 字节数完全相同**

| 检查 | 结果 |
|------|------|
| 差集中源 0 字节 | **44** |
| 差集中产物 0 字节 | **44** |
| 源0 集合 == 产物0 集合 | ✅ 完全一致 |
| 源 vs 产物尺寸不一致 | **0**（127/127 尺寸相同） |

全域：RiverLake 源 `fight/*.grp` **219** 个中 **44** 个为 0 字节（pascal 92 个中 0 个）。

**2. 其他 MOD 也有同类现象**（说明是 MOD 作者侧的普遍遗留，非 RiverLake 特有）

| MOD | fight 总数 | 0 字节 |
|-----|----------:|-------:|
| **pineapple** | 154 | **115** |
| **RiverLake** | 219 | **44** |
| ptt | 162 | 7 |
| books | 178 | 2 |
| loving | 107 | 2 |
| 其余 15 个（含 pascal） | — | 0 |

**3. 34/44 被实际引用**（`Person[i]["头像代号"]` → `fight%03d.grp`）

运行时取证（`LoadRecord(0)` 后遍历 325 个 Person）：

```
Person 总数=325 有头像代号=325 最大头像代号=216
被引用的头像代号中：文件缺失=0  0 字节=34
```

⇒ 44 个空文件中 **34 个**确实会被 `WarPictures`（`war_async.lua:93-95`）以
`PicLoadFile(fight%03d.idx, fight%03d.grp, 4+i)` 加载。

**4. 引擎侧优雅降级（不崩溃）**

`PicLoadFile`（`lib_love.lua:423-451`）对 0 字节 `idx`：`num = 0/4 = 0`，
循环不执行，`pic_file.idx[1] = 0`；`PicFile:getPic`（`:262-285`）发现
`self.idx[picid+1] == nil` → `Debug()` + `return nil`，不抛错。
`LoadPic`（`:291-295`）另有 `idx2 <= idx1` 前置判据 → `return nil`。

实测：

```
PicLoadFile(0字节) pcall = true err=nil
PicGetXY(0字节 grp) pcall = true 返回=0      ← 优雅降级，非崩溃
```

### Decision

**不补数据、不删除、不跳过**。0 字节文件**原样进产物**（尺寸 127/127 一致）。理由：

1. 补内容会**伪造** MOD 作者没提供的美术资源，违反「产物 = 源 + 格式转换」不变式。
2. 删除会改变 `fight%03d` 的**索引语义**（`头像代号` → 文件名是位置绑定），
   导致引用它的 34 个 Person 取不到图（更差）。
3. 引擎已优雅降级（`nil` → 调用方 `or` 兜底），实测不崩溃。

⇒ 归 **`REQUIRED` 且 `in_product=true`**（文件必须存在以维持索引语义），
并在 verify 报告中标注「内容 0 字节 = 源既有，非构建缺陷」。

### Consequences

- ✅ +127 差集成立，其中 83 个有内容、44 个空。
- ⚠ 记录了本 epic 第一个「0 字节资源」样本，为后续 `pineapple`（115 个空）建立判据。
- ✅ 不影响 `mod_audit`（按路径分类，不看内容长度）与 `format_spec`（`gaps=0`）。

---

## Review Checklist

- [ ] 4 段段长全部整除记录尺寸，余数为 0
- [ ] `Person[324]`/`Thing[248]`/`Scene[83]`/`Wugong[95]` 边界记录可读且非空
- [ ] `Scene=84` 与基线相同 → 已用**内容比对**（非计数）证明来自 MOD
- [ ] `hdgrp` 252 = `hdgrp.idx` 字节数 / 4，且无硬编码常量
- [ ] `eft` 921 = `eft.idx` 字节数 / 4，`idx[-1] == eft.grp` 字节数
- [ ] `CC.Effect` 截断（53 项 vs eft id 69）已记录为范围外 spike，含 **7/20 MOD** 越界全表 + 语义关系 + 非致命性证明
- [ ] 127 场额外战斗三条清单**逐个文件名**一致
- [ ] 21 个产物存档与源逐字节一致
- [ ] 28 个空 WAV 原样保留且运行时不报错
- [ ] `unclassified=0 bad_evidence=0`，`total=699` = 源文件数
- [ ] `gaps=0`
- [ ] 引擎 / `jyconst.lua` 常量 / `reference/**` 零改动
