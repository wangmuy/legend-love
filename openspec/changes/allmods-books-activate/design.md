---
status: done
created: 2026-10-26
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice13
---
# Design: allmods-books-activate

> Slice 13 子 change 1/2 的技术设计。每个关键判断记作 ADR。

## ADR-BK-001 `ranger.grp` 里的 `P0000` 是设计内 hint，不是编码失败

**Context**

直接读 `game/mods/books/data/ranger.grp`，在 offset 844 处会看到：

```
DST @836: 00 00 00 00 02 00 01 00 50 30 30 30 30 00 ...
                                ^ "P0000"
```

而源 `kys-books/save/ranger.grp` 同一位置是 Big5 的「古天奇」：

```
SRC @836: 00 00 00 00 02 00 01 00 a5 6a a4 d1 a9 5f 00 ...
                                ^ Big5 古天奇
```

`src` 与 `dst` 长度完全相同（126478B），但 **13576 字节不同，分成 1549 个差异区间**。
初看像是「编码转换把名字弄坏了」。

**Decision**

`P0000` / `N0001` / `T0002` 是 `tools/mod_encoding.lua` 有意的 **hint 占位符**方案：

1. Big5 字符 2 字节，UTF-8 BMP 字符 3 字节。定宽字段（10/20/30 字节）
   **装不下** UTF-8 形式（`雪山飛狐` = 12B > 10B 字段）。就地重编码会截断 41% 的字符串，
   而**截断是明令禁止的**。
2. 于是把每个字符串字段替换为定宽 hint（`P` + 段内 `%04d` 索引），
   记录布局与文件大小**完全不变**，所有数值 offset 保持有效。
3. 真实 UTF-8 字符串写入侧表 `ranger.str`，按段分组、段内去重、同索引。
4. 引擎解析顺序：`save override (rN.ovr)` → `ranger.str` → 原始缓冲（vanilla 回退）。
   见 `framework/mod_data.lua`。

**Consequences**

- 判据**必须**用运行时取值（`JY.Person[0]["姓名"]`），**不能**直接读 `ranger.grp` 的字节。
- 实测：`LoadRecord(0)` 后 `JY.Person[0]["姓名"] = 古天奇`、
  `["外号"] = 天下奇男子`、`Person[1] = 胡斐/雪山飛狐`、`Person[381] = 閻基/毒手藥王`。
- `ranger.str` 957 条有效（Person 419 / Thing 368 / Scene 72 / Wugong 98），
  唯一值 934、重复 23（段内去重所致）。

**Alternatives rejected**

| 方案 | 否决理由 |
|------|----------|
| 就地重编码 UTF-8 | 41% 字符串被截断，违反禁止截断约束 |
| 扩宽字段（改记录布局） | `ranger.idx` 五段 offsets、`CC.*Size` 全部要改 = 破坏格式兼容 |
| 用 `t2s` 简体表降级 | 会丢失繁体（`雪山飛狐`→`雪山飞狐`），与 MOD 原意不符 |

## ADR-BK-002 `PicGetXY` 无法区分 `ZERO_BYTE` 与 `FILE_MISSING`，判据必须靠文件事实 + 代码路径

**Context**

books 有 2 个零字节 fight（104/164）和 4 个被引用但缺失的 fight（30/39/66/110）。
实测三者的 `PicGetXY` **全部返回 `0,0`**：

```
fight104: grp=0 idx=0         PicGetXY=0x0  pcall=true
fight164: grp=0 idx=0         PicGetXY=0x0  pcall=true
fight030: grp=MISSING         PicGetXY=0x0  pcall=true
fight400: grp=MISSING(人造)   PicGetXY=0x0  pcall=true
```

**Decision**

分支归属**不得**由 `PicGetXY` 返回值判定，必须由两条独立证据合成：

1. **文件系统事实**：`stat` 得到 `0`（存在但空）还是 `-1`（不存在）。
2. **代码路径**（`engine-love2d/lib_love.lua`）：

```
:433-436   local idxlen = FileLength(idxfilename)
           local grplen = FileLength(grpfilename)
           if idxlen < 0 or grplen < 0 then return end   -- FILE_MISSING 早退
:441       local num = idxlen/4                          -- ZERO_BYTE: num=0
:443-450   pic_file.idx[1]=0; 循环 num 次（0 次不执行）
:462       PicGetXY -> getPic(picid)
:270-273   if self.idx[picid]==nil or self.idx[picid+1]==nil then return nil  -- ZERO_BYTE 在此失败
:264-267   if f == nil then return nil                   -- grp 打不开（FILE_MISSING 已早退，不会到这）
```

⇒ `FILE_MISSING` 在 `:435` **早退**（`picFileCache[fileid]` 仍被创建但 `idx` 全空）；
`ZERO_BYTE` 通过 `:435`（`0 < 0` 为假），进到 `getPic` 后在 `:270-273` 因 `idx[picid]==nil` 返回 `nil`。
**两者最终都是 `nil` → `0,0`。**

**Consequences**

- 判据写成三元组：`(分支, FileLength, PicGetXY)`，其中分支由 `FileLength` 的正负/零判定。
- 全量扫描 `fight 0..177`：`PicGetXY` 有效 **168**、返回 `0x0` **10**。
- `0x0` 的 10 个 = 4 个被引用缺失 + 4 个未引用缺失 + 2 个零字节。
- 必须带**负对照**（人造代号 400）证明「不存在时也返回 `0x0`」，
  否则无法排除「测量方法本身失效」。

**Negative Constraint**

不得把 `ZERO_BYTE` 与 `FILE_MISSING` 写成「不同返回值」——它们**返回值相同**。
真正的区别在**代码路径**（早退 vs 进函数后失败）。

## ADR-BK-003 `FILE_MISSING` 4 实例来自 MOD 原始状态，不是构建丢文件

**Context**

`fight030/039/066/110` 在产物中不存在。可能是：
(a) 构建器漏拷；(b) 源就没有；(c) 源有但被判为 UNNEEDED 而跳过。

**Decision**

实测源侧：

```
fight030: src=MISSING  base=MISSING      fight039: src=MISSING  base=MISSING
fight066: src=MISSING  base=MISSING      fight110: src=MISSING  base=MISSING
```

四个在**源目录与基线目录中都不存在**。同时 `mod_audit` 报 `unclassified=0 bad_evidence=0`，
`not_in_product=30` 的 30 项全部有分类（27 PENDING + 3 LEGACY 等），
**没有**任何 `fight0xx` 落在 `not_in_product`。

⇒ 判定为 **(b) 源就没有**：MOD 作者本人也未提供这 4 个战斗贴图包，
但 `Person.头像代号` 仍指向它们。这是 MOD 的**原始缺陷**（缺资源），
运行时会落到 `0,0`（无图），不会崩溃。

**Consequences**

- 记入 `verification.md` 与 `TODO.md` 作为**已知 MOD 缺陷**（非本 epic 引入）。
- **不修**（补 4 个 fight 包 = 改源数据 = 禁用路径）。
- 与 pineapple 对照：pineapple `FILE_MISSING = 0`（被引用代号全部 ≤299 且文件存在）。

**Negative Constraint**

不得把「4 个被引用缺失」写进「构建缺陷」栏——它们是源侧缺陷，
构建器行为正确（不凭空造文件）。

## ADR-BK-004 `hdgrp` 696 中的 222 个零长段是 RLE 重复帧，不是缺陷

**Context**

逐条解析 `hdgrp.idx`（2784B / 4 = 696）发现 offsets **不是严格递增**：
有 222 处 `offs[i+1] == offs[i]`。若按「段长必须 > 0」判，会得 222 个"缺陷"。

**Decision**

`hdgrp` 属 `idx_grp_rle` 家族（`tools/format_spec.lua:232`），
`M.verifyPair` 建区间时用 `if a and b and b > a then` —— **零长段被有意跳过**。
零长段语义 = **该帧与前帧相同**（RLE 重复引用），是格式的合法表达。

**Consequences**

- 判据为「**非空段 474 条头异常 0**」，不是「696 条全非空」。
- 零长段呈 4 个块：`(起始 215, 长 54)`、`(270, 2)`、`(273, 165)`、`(695, 1)`，`Σ = 222`。
  前 3 块是连续 RLE 重复帧群，`(695,1)` 是末尾哨兵位。
- `format_spec --mod books` 报 `gaps=0`，与「0 缺陷」一致。
- 基线 115 条 = PNG 2 + RLE 112 + 零长 1。books **全部 RLE，无 PNG**。

**Negative Constraint**

不得把零长段计为 gap 或缺陷；不得因为「offsets 不递增」就判 `hdgrp.idx` 损坏。

## ADR-BK-005 `Wugong` 100 是罕见中间值，必须验字段而非只验条数

**Context**

20 个 MOD 的 `Wugong` 条数多为 93（基线）/96（RiverLake）/114（Dragon），
books 是 **100**。`Wugong` 段 13600B / 136 = 100，余 0 —— 整除只证明算术对，
不证明字段读对。

**Decision**

用 `pairs(CC.Wugong_S)` 取**全部 64 个字段名**（不是硬编码抽样），
逐字段统计 100 条记录中的非 nil 数：

```
Wugong_S 字段数: 64
全 nil 字段数: 0
名称 非空: 100 / 100
```

**Consequences**

- 判据必须包含 **「全 nil 字段数 = 0」**，否则字段名写错会静默通过。
- 边界抽样（`[0]/[1]/[2]/[97]/[98]/[99]`）只作为**语义**佐证，不能替代全量统计。
- `武功动画&音效` 越界（`>52`）仅 **2 条**、`max = 55`，远轻于 pineapple 的 62 条 / 83。

**Negative Constraint**

不得用 `pairs(JY.Wugong[i])` 遍历记录（该表元表使 `pairs` 返回 0 字段，
见 AGENTS.md 已知陷阱）——必须读显式字段名。

## ADR-BK-006 `kysmod.ini` 生效判据必须是「基线为 nil 的项变为有值」

**Context**

books 的 ini 有 52 个非注释键。若直接打印 `CC.*` 看到 33 个有值，
无法分辨「ini 生效」与「代码默认就有值」。

**Decision**

做**双进程对照**：同一脚本分别以 `baseline`（不激活 MOD）与 `books` 运行，
打印同一批 `CC.*`，逐项比对：

```
基线 nil -> books 有值 : 28 项   <= ini 真正生效
基线与 books 同值      : 5 项    <= 代码默认已相同，ini 未改变
```

5 项同值是 `NewGameSceneID 70` / `NewGameEvent 691` / `NewGameSceneX 19` /
`NewGameSceneY 20` / `MoneyID 174`。

**Consequences**

- 判据是 **28 项 `nil→value`**，不是「33 项有值」。
- 若 ini 未应用，28 项应全部为 `nil` —— 这就是反向对照。
- `[music] SOUND3D` 是唯一 `unknown` 键（`mod_ini.lua` 的 `SECTION_MAP.music`
  只有 `volume`/`volumewav`），属设计内，1 个，不计缺陷。

**Negative Constraint**

不得用「打印非 nil 数量」代替「与基线做差」——两者在 ini 未生效时可能都得同一个数。

---

## Negative Constraints（本 change 全局）

1. 不得直接读 `ranger.grp` 字节判编码对错（`P0000` 是设计内 hint）。
2. 不得把 `PicGetXY` 的 `0,0` 当作分支判别依据（`ZERO_BYTE` 与 `FILE_MISSING` 同值）。
3. 不得把 4 个被引用缺失的 fight 判为构建缺陷（源侧与基线侧均不存在）。
4. 不得把 222 个零长 `hdgrp` 段判为 gap（RLE 重复帧）。
5. 不得用「`ranger.idx` 五段整除」单独作为记录读取正确的证据（必须加基线差异对照）。
6. 不得用 `pairs(JY.Wugong[i])` 统计字段（元表导致 0 字段）。
7. 不得用「打印非 nil 项数」代替「与基线做差」证明 ini 生效。
8. 不得声称 books 的 `Person`/`ranger.grp` 是最大（BookCalamity 800 / 313242 更大）。
9. 不得改 `game/engine-love2d/**`、`game/engine-mud/**`、`game/script/jyconst.lua` 常量、`reference/allmods/**`。
10. 不得用 `mod_audit.lua books` 位置参数（会静默审计全部 MOD）——须 `--mod books`。
11. 不得用 Lua pattern 的 `|` 交替（不支持）；须 `match("^([rds]%d+)%.([a-z]+)$")` + 扩展名判断。
12. 不得为零字节 fight 生成占位图或补文件。

## Review Checklist

- [x] REQ-BK-1 构建输出逐字匹配 `data files=392, saves=19, sound=84, events=573, talk=6655`
- [x] REQ-BK-2 `490+4+3+1+27 = 525` 且 `495+30 = 525`
- [x] REQ-BK-3 `formats=12 checked=287 gaps=0`
- [x] REQ-BK-4 `RESULT books: OK`，5 个位置参数为期望值
- [x] REQ-BK-5 五段余数全 0，且与基线对照（Thing/Scene/Shop 同，Person/Wugong 异）
- [x] REQ-BK-6 四类证据齐备（边界记录 / 957 条侧表 / 573+6655 / 28 项 ini）
- [x] REQ-BK-7 28 项 `nil→value`，`SOUND3D` 为唯一 unknown
- [x] REQ-BK-8 696 = 474 有效 + 222 零长，头异常 0；基线 PNG 2 对照
- [x] REQ-BK-9 64 字段全 nil 数 0，名称 100/100，越界 2 条 max 55
- [x] REQ-BK-10 三分支可区分（文件事实 + 代码路径），含 4 个真实 `FILE_MISSING`
- [x] REQ-BK-11 `find ... -name ranger.str` 在源侧无输出
- [x] REQ-BK-12 books 无 `name.*`（diff 12 项非 fight 亦不含）
- [x] REQ-BK-13 8 道门禁复跑
