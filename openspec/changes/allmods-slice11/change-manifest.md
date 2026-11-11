---
status: done
parent_slice: allmods-slice11
parent_epic: 2026-10-allmods-compat
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Change Manifest: allmods-slice11

> 本 slice 将一个 MOD（kys-Dragon / 苍龙逐日）的端到端适配拆成 2 个 spec-driven 子 change。
> 子 change 之间通过下方 **Contracts** 传递可验证接口。
>
> Dragon 是第 4 梯队第 2 个 MOD、累计第 11 个，也是全部 20 个 MOD 中
> **`hdgrp` 条目最多（267）**、**唯一删除既有战斗贴图**（`fight101`/`fight102`）的一个。

## 子 change 列表

| # | 子 change | 依赖 | 状态 |
|---|-----------|------|------|
| 1 | `allmods-dragon-activate` | Slice 0/0b/0c | [x] done |
| 2 | `allmods-dragon-verify` | 子 change #1 | [x] done |

## 执行顺序

```
allmods-dragon-activate  →  allmods-dragon-verify
    (构建+启动+机器验证)          (内容审计+报告)
```

## Contracts

### Contract A：构建产物

`activate` 必须产出 `game/mods/Dragon/` 并满足：

| 项 | 值 |
|----|----|
| `data files` | 458 |
| `saves` | 21 |
| `sound` | 80 |
| `events` | 1087 |
| `talk` | 4020 |
| `fight*.grp` | 209 |
| `hdgrp` 条目 | 267（`hdgrp.idx` 1068B） |
| `eft` 条目 | 714（`eft.idx` 2856B） |
| 记录段 | 589 / 237 / 106 / 114 |

实测：

```
$ lua tools/mod_build.lua kys-Dragon
[mod_build] kys-Dragon: data files=458, saves=21, sound=80, events=1087, talk=4020
[mod_build] diff -> mods/Dragon/diff.md
```

**消费方**：`verify` 的全部审计与报告。

### Contract B：穷举审计

`lua tools/mod_audit.lua --mod Dragon --evidence` 必须输出：

```
total=811 in_product=555 not_in_product=256 unclassified=0 bad_evidence=0
  REQUIRED 550  REQUIRED_CONVERTED 4  LEGACY 5  DEAD_FILE 1
  EDITOR_DUMP 220  BUILD_INPUT 2  PENDING 29
```

不变量：Σ(类别) = 811 = 源文件总数。

> ⚠ **调用易错**：`--mod` 是**选项**，不是位置参数。
> `lua tools/mod_audit.lua Dragon --evidence` 会静默审计**全部 20 MOD**
> （输出 `total=11220`），得到错误结论。

**消费方**：`verify` 的 §7 审计与 `not_in_product` 分类。

### Contract C：字节级覆盖

`lua tools/format_spec.lua --mod Dragon` 必须输出 `formats=12 checked=535 gaps=0`。

**消费方**：`verify` 判定「内容差异 vs 结构异常」。

### Contract D：启动链路

`lua tests/unit/boot_one_mod.lua Dragon 589 237 106 114 資` 必须 16/16 PASS 并输出
`RESULT Dragon: OK`。

> ⚠ **调用易错**：位置参数是**期望值**。缺省时期望 `nil`，
> 即使实际加载正确也会 FAIL 5 项（`PersonNum`/`ThingNum`/`SceneNum`/`WugongNum`/主角姓名）。

`MOD_SLUG=Dragon lua tools/mod_check_one.lua` 须输出
`PERSON=589 THING=237 SCENE=106 WUGONG=114 HERO=資 STRINGS=OK EVENTS=OK SAVE=OK`。

**消费方**：`verify` 的端到端结论。

### Contract E：记录段与 `hdgrp` / `eft` 判据

`ranger.idx` offsets = `[836, 108034, 153064, 158576, 174080, 174230]`，grp = 174230B。

| 项 | 实测 | 判据 | 结论 |
|----|------|------|------|
| `hdgrp` | **267**（`hdgrp.idx` 1068B） | 索引驱动 `idxlen/4`（`lib_love.lua:437`）+ 无固定计数常量 + `gaps=0` | 内容差异（**第 7 次应用**） |
| `eft` | 714（`eft.idx` 2856B） | 索引驱动 + 单调 + `idx[-1]==grp 大小` + **md5 与基线相同** | **MOD 未修改该资源**（非"回退原版"） |
| Person 589 | 107198/182 = 589 rem 0 | 整除 + 边界记录可读 | 内容差异 |
| Thing 237 | 45030/190 = 237 rem 0 | 整除 + 边界记录可读 | 内容差异 |
| Scene 106 | 5512/52 = 106 rem 0 | **四段全部异于基线** + 内容负对照 | 内容差异（**第 4 次应用**） |
| Wugong 114 | 15504/136 = 114 rem 0 | 整除 + 边界记录可读 | 内容差异 |
| Shop 3 | 150/50 = 3 rem 0 | 整除 | 内容差异 |

`hdgrp` 外推链：**125 → 129 → 173 → 178 → 204 → 252 → 267**。

**消费方**：`verify` 的 ADR-003、报告 §2.2/§2.3。

### Contract F：`diff.md` 双向 set 相等

`mods/Dragon/diff.md` 的列表必须与实测差集**双向 set 相等**（非仅计数相等）：

| 方向 | 计数 | set 相等 | 双向差集 |
|------|-----:|:--------:|----------|
| MOD 独有（`added`） | **254** | ✅ True | `[]` / `[]` |
| 基准独有（`removed`） | **25** | ✅ True | `[]` / `[]` |

比对须用 `mod_build.lua:1057` `dataFileSet` 同口径（只列**顶层**文件名），
并剔除别名对 `sdx/smp/wdx/wmp` ↔ `smap.idx/smap.grp/wmap.idx/wmap.grp`。

254 = **119 `fight*.grp`** + **119 `fight*.idx`** + **16 非 fight**。

非 fight 16 项中 15 项与源**逐字节相同**，`ranger.str` 由构建生成
（`mod_build.lua:1174` `E.SerializeSideTable`）。

25 项基准独有五分法：**A 9 / B 9 / C 2 / D 1 / E 4**（E = `fight101`/`fight102` 的 4 个文件）。

**消费方**：`verify` 的 ADR-001、报告 §5。

### Contract G：`not_in_product` ≠ 物理缺失

`not_in_product = 256` 中，**4 项物理存在于产物**：

| 文件 | 类别 |
|------|------|
| `resource/name.grp` | `LEGACY` |
| `resource/name.idx` | `LEGACY` |
| `resource/talkutf8.txt` | `BUILD_INPUT` |
| `resource/war1.sta` | `DEAD_FILE` |

`4 + 252 = 256`。

根因：`mod_audit.lua:453-462` `checkInProduct` 三关卡，
`IN_PRODUCT_BY_CATEGORY`（`:48`）中 `LEGACY`/`DEAD_FILE`/`BUILD_INPUT` 均为 `false`
⇒ **关卡 2 直接否决，从未走到物理检查**。

**正确解读**：`not_in_product` = 「**非必需产物成员**」。
判为语义不精确，**本 slice 不修复**（改则需同步 12 个既有 slice 口径）。

**消费方**：`verify` 的 ADR-004、报告 §7.2。

### Contract H：`fight101`/`fight102` 优雅降级

Dragon 删除了基线的 `fight101`/`fight102`，但 `Person` 数据仍引用头像代号 101/102
（589 条记录中 588 条有代号，max=219；引用 101 者 1 条、102 者 1 条）。

降级链路（须带**正对照**才有效）：

| 场景 | `PicLoadFile` | `PicGetXY(4, 0/2/4/6)` |
|------|---------------|------------------------|
| `fight101`（缺失） | `pcall=true err=nil` | **0,0 / 0,0 / 0,0 / 0,0** |
| `fight103`（存在，正对照） | `pcall=true err=nil` | **33×63 / 74×67 / 74×70 / 72×69** |

代码路径：`FileLength` → `-1`（`lib_love.lua:283-289`）→ `PicLoadFile` 早退
（`:435`）→ `getPic` 返回 `nil`（`:269-273`）→ `PicGetXY` 返回 `0,0,0,0`（`:465-468`）。

> ⚠ **禁止**用 `PicGetXY` 裸调（未先 `PicLoadFile`）作证据 ——
> `picFileCache[fileid]` 为 `nil`，会抛 `lib_love.lua:462 attempt to index a nil value`。

**判定**：MOD 作者侧数据不一致；**不补文件、不改头像代号**。

**消费方**：`verify` 的 ADR-002、报告 §6.1。

### Contract I：`war1.sta` 双判定一致

| 维度 | 值 |
|------|-----|
| 源存在 | ✅ 66030B（`66030 ÷ 186 = 355` 记录） |
| 产物存在 | ✅ 66030B，md5 = 源 |
| 基线存在 | ❌ |
| `CC.WarFile` | `war.sta`（`jyconst.lua:129`），不含 `war1` |
| 代码引用 | `grep -rn "war1" script/ framework/ engine-love2d/` → **0** |
| 审计 | `mod_audit.lua:189` `DEAD_FILE, needed=false` |

`DEAD_FILE` 回答「引擎需要读它吗」（否）；`diff.md` MOD 独有回答「相对基线新增吗」（是）。
**「新增但不用」，两判定不矛盾。**

须与 RiverLake `allsinbk.grp` 区分：后者是「**回退到的**死文件」（有常量、有传参、body 不读），
本项是「**新增的**死文件」（无常量、零引用）。

**消费方**：`verify` 的 ADR-006、报告 §6.2。

### Contract J：`cloud/title/open/end` 无运行时消费者（范围外发现）

6 个文件（`cloud.{grp,idx}`、`title.{grp,idx}`、`open.png`、`end.png`）被标 `REQUIRED`，
但 Lua 引擎**无运行时消费者**：

```
cloud / title.grp / title.idx / open.png → 0 命中
end.png → 1 命中（script/jymain.lua:4273），但读 CONFIG.PicturePath="pic/" 下的基线文件
CC.CloudPicFile / TitlePicFile / OpenFile / EndFile → 全部 nil
```

归类来源 = `mod_audit.lua:264-269` `BY_KIND`（`resource|.grp/.idx/.png` → `REQUIRED`）**兜底**。

**判定**：C 引擎资源、Lua 引擎未接入；保守归类 = 多带文件 = 无害。
**本 slice 不改判定**（影响 6 项 × 20 MOD 计数）。

**消费方**：`verify` 的 ADR-004b、报告 §7.3。

### Contract K：门禁 7 口径（**本 slice 修正项**）

20 MOD `save/` vs 源：

```
源 save/ 文件数 = 451
  逐字节一致    = 430
  差异          = 21    ← ranger.grp ×20 + ranger.idx ×1(zheng)
  真实问题      = 0
```

21 项差异全部**设计内转换**：

| 项 | 数量 | 机制 |
|----|-----:|------|
| `ranger.grp` | 20 | Big5→UTF-8 + 固定宽度 hint，真值进 `data/ranger.str` |
| `ranger.idx` | 1（zheng） | 源 idx 描述 138596B 而 grp 仅 114242B ⇒ `ModEncoding.RepairIdx`（`:248`）重建 |

`mod_build.lua:665-670` 按 `isSaveSlotFile`（`:626-631`，`^[rds]%d+%.(grp|idx)$`）
把 `save/` 分两类：槽文件 → `mods/<m>/save/`（341 个），模板 → `mods/<m>/data/`（110 个）。

**修正**：不得笼统宣称「451 文件不一致 = 0」。已在
`allmods-dragon-activate/verification.md`、`epic.md:781`、
`allmods-dragon-verify/tasks.md` §15.9 三处同步修正。

**消费方**：`verify` 的 REQ-DRGV-14 门禁 7、报告 §8.7。

## 验证策略

每个子 change 的 `verification.md` 必须含：
1. REQ 追溯矩阵
2. 实测命令与输出（含 §10 可复跑清单）
3. Blast Radius 合规检查
4. 偏差记录（对初稿的推翻逐条列出）

## 状态汇总

| 子 change | tasks | verification | status |
|-----------|-------|--------------|--------|
| `allmods-dragon-activate` | 16/16 [x] | 15 章节 | [x] done |
| `allmods-dragon-verify` | 17/17 [x] | 14 REQ + 偏差汇总 | [x] done |

## 关键交付物

| 产物 | 路径 |
|------|------|
| 构建产物 | `game/mods/Dragon/`（458 data / 21 save / 80 sound / 1087 events） |
| 差异清单 | `game/mods/Dragon/diff.md`（254 独有 / 25 基准独有） |
| 验证报告 | `openspec/changes/allmods-dragon-verify/reports/dragon-verify.md`（10 章节） |
| 验证记录 | `openspec/changes/allmods-dragon-verify/verification.md`（14 REQ） |
