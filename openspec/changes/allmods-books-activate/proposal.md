---
status: done
created: 2026-10-26
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice13
---
# Proposal: allmods-books-activate

> Slice 13 子 change 1/2 —— 让 MOD「天书奇侠试玩」（`kys-books`）在 Love2D 引擎上
> 完成构建、机器验证与启动链路，并证明内容真实。

## 1. 背景

books 是 epic 的**最后一个 MOD**，也是 `hdgrp` 条目数最多（**696**）、
`kdef` 事件最少（**573**）的 MOD。它的两个特性决定了本 change 的必要性：

1. **`hdgrp` 696 是本 epic 的最后一个极端值**（上限封顶）。前 12 个 MOD 依次
   验证了 125/129/173/178/204/252/267/300 等条目数，696 是峰值。
2. **`FILE_MISSING` 首次成为真实性实例**（非人造负对照）。前 12 个 MOD 中
   Dragon 的 `fight101` 是唯一缺失，pineapple 则 `FILE_MISSING = 0`。
   books 有 **4 个被引用的代号（30/39/66/110）文件不存在**。

## 2. In Scope

- 构建 `game/mods/books/`（`data files=392, saves=19, sound=84, events=573, talk=6655`）
- 穷举审计（`total=525 in_product=495 not_in_product=30 unclassified=0 bad_evidence=0`）
- 字节级格式覆盖（`formats=12 checked=287 gaps=0`）
- 独立进程启动链路（`boot_one_mod.lua books 382 200 84 100 古天奇`）
- 内容真实性：
  - 边界记录（`ranger.idx` 五段整除、首尾记录）
  - `573` 事件与 `6655` 对话
  - `kysmod.ini` 的 **28 项** `nil→有值` 覆盖
  - `ranger.str` 侧表的 957 条 UTF-8 字符串回填
- `hdgrp` **696** 逐条结构验证（474 有效 RLE + 222 零长）
- `Wugong` **100** 的 64 字段全对齐验证
- fight 三分支实测（OK / ZERO_BYTE / FILE_MISSING），含 `FILE_MISSING` 4 实例
- 8 道门禁复跑
- `verification.md` 记录全部实测命令与输出

## 3. Out of Scope

| 项 | 原因 |
|----|------|
| `diff.md` 逐项审计与报告 | 属姊妹 change `allmods-books-verify` |
| 修复 `FILE_MISSING`（补 4 个 fight 包） | **改源数据 = 禁用路径**；且该缺失在源侧与基线侧均存在，属 MOD 原始状态 |
| 修复 `not_in_product` 语义 | 改审计工具契约 = 独立 change |
| `CC.Effect` 越界修复（books 仅 2 条） | 修复点在 `script/jyconst.lua`（禁用路径）= epic 级 spike |
| `music/*.mid` / `list/*.bin` | epic 级 spike |
| 引擎改动 | 四禁改路径 |

## 4. 需求（REQ-BK-1 ~ REQ-BK-13）

### REQ-BK-1 构建输出逐字匹配

```
[mod_build] kys-books: data files=392, saves=19, sound=84, events=573, talk=6655
```

五个数字任一不符即 FAIL。

### REQ-BK-2 穷举审计闭合

```
total=525  in_product=495  not_in_product=30  unclassified=0  bad_evidence=0
490 + 4 + 3 + 1 + 27 = 525        (逐类闭合)
495 + 30 = 525                     (双向闭合)
```

### REQ-BK-3 字节级格式覆盖

`formats=12 checked=287 gaps=0`。

### REQ-BK-4 独立进程启动链路

`lua tests/unit/boot_one_mod.lua books 382 200 84 100 古天奇` 必须 `RESULT books: OK`，
且**5 个位置参数全部是期望值**（不是「传入即通过」）。

### REQ-BK-5 记录段边界整除

`ranger.idx` = `[836, 70360, 108360, 112728, 126328, 126478]`，
五段余数**必须全 0**：

| 段 | 字节 | 记录长 | 条数 | 余数 |
|----|-----:|-------:|-----:|-----:|
| Person | 69524 | 182 | 382 | 0 |
| Thing | 38000 | 190 | 200 | 0 |
| Scene | 4368 | 52 | 84 | 0 |
| Wugong | 13600 | 136 | 100 | 0 |
| Shop | 150 | 50 | 3 | 0 |

**且**必须与基线做差异对照（Thing/Scene/Shop 与基线**相同**，Person/Wugong 不同）——
否则「整除」只证明脚本能算，不证明读取正确。

### REQ-BK-6 内容真实性（四类直接证据）

（1）**边界记录**：`Person[0]`/`[1]`/`[381]`、`Thing[0]`/`[199]`、`Scene[0]`/`[83]`
必须解出**语义字符串**（`古天奇`/`天下奇男子`/`胡斐`/`雪山飛狐`…），不是 hint 占位符。

（2）**`ranger.str` 侧表**：957 条有效条目（Person 419 / Thing 368 / Scene 72 / Wugong 98），
字段 Name 670 / Nick 119 / Desc 168；必须证明根目录 `ranger.grp` 里的 `P0000` 是**设计内 hint**，
运行时被回填为真实字符串。

（3）**`573` 事件 / `6655` 对话**：与源 `resource/kdef.*`、`resource/talk.*` 对应，
不得是构建截断。

（4）**`kysmod.ini` 反向对照**：ini 声明 52 个非注释键，运行时 **28 项** 从 `nil` 变为有值；
另 5 项（`NewGameSceneID/NewGameEvent/NewGameSceneX/NewGameSceneY/MoneyID`）与代码默认同值。
若 ini 未被应用，28 项应全为 `nil`。

### REQ-BK-7 `kysmod.ini` 生效（反向对照）

同 REQ-BK-6（4）。补充：`[music] SOUND3D` 是唯一 `unknown` 键（无映射，设计内，1 个）。

### REQ-BK-8 `hdgrp` 696 逐条结构验证

`hdgrp.idx = 2784B` → 696 条；`hdgrp.grp = 1233815B`。
逐条解析 RLE 头 8 字节（`w,h,xoff,yoff` 小端）：

- **非空段 474 条，头异常 0 条**（`w>0, h>0`，范围 `w 1..82 / h 1..70`）
- **零长段 222 条** = RLE 重复帧（格式规范允许；`format_spec.lua` 的 `verifyPair`
  只对 `b>a` 建区间，零长段不计 gap）
- 零长段呈 3 个连续块：`(215,54)`、`(270,2)`、`(273,165)`
- 基线对照：115 条 = PNG 2 + RLE 112 + 零长 1；books **全部 RLE，无 PNG**

### REQ-BK-9 `Wugong` 100 字段映射

`Wugong_S` **64 个字段**，在 100 条记录上必须：

- **全 nil 字段数 = 0**
- `名称` 非空 **100/100**
- 边界抽样 `[0]/[1]/[2]/[97]/[98]/[99]` 语义正确
- `武功动画&音效` 越界（`>52`）**2 条**，`max = 55`（远轻于 pineapple 62 条）

### REQ-BK-10 fight 三分支降级（含 `FILE_MISSING` 真实实例）

- `ZERO_BYTE` 2 个：`fight104`、`fight164`（`.grp`/`.idx` 均 0B，**源侧也是 0B**）
- `FILE_MISSING` **4 个被引用**：`fight030`(風清揚) / `fight039`(石中玉) /
  `fight066`(段正淳) / `fight110`(張召重)
- 另有 4 个未引用的缺失：`fight052/111/112/113`
- 全量 `0..177`：`PicGetXY` 有效 168、返回 `0x0` 10
- **必须显式声明**：`PicGetXY` 对 `ZERO_BYTE` 与 `FILE_MISSING` 返回相同的 `0,0`，
  **运行时不可区分**；分支归属靠文件系统事实 + `lib_love.lua:435` 代码路径
- 负对照：人造代号 `400` 必须同样 `0,0` 且 `pcall` 为 `true`

### REQ-BK-11 `ranger.str` 是构建生成物（非 MOD 提供）

源 `kys-books/` 中**不存在** `ranger.str`（`find` 无输出）。
它由 `tools/mod_encoding.lua` 的 hint 抽取生成（964 行含注释 / 957 条有效）。
⇒ 判为**构建产物**，不是多余文件。

### REQ-BK-12 `name.*` 不存在（books 与 4 个 MOD 的差异）

`TODO.md:268` 勘误：`name.grp` 出现于 BookCalamity / Dragon / pineapple / RiverLake，
**books 未使用**。本 change 需确认：
- `game/mods/books/data/` 中无 `name.grp`/`name.idx`
- `diff.md` 的 12 条非 fight 中不含 `name.*`
- `ranger.str` 生成**不依赖** `name.*`（依赖 `ranger.grp`）

### REQ-BK-13 8 道门禁

同 manifest Contract M。

## 5. Blast Radius

| 路径 | 允许 | 说明 |
|------|:----:|------|
| `game/mods/books/**` | ✅ 写 | 构建产物；实验后须恢复 |
| `openspec/changes/allmods-books-activate/**` | ✅ 写 | 本 change 全部产物 |
| `openspec/changes/allmods-slice13/**` | ✅ 写 | slice 与 manifest |
| `openspec/epics/2026-10-allmods-compat/**` | ✅ 写 | epic.md / TODO.md 索引 |
| `game/tests/unit/boot_one_mod.lua` | ⚠ 只读 | 用位置参数调用，不改 |
| `game/tools/**` | ⚠ 仅限已记录的工具缺陷 | 本 MOD 若发现新缺陷须单列 |
| `game/engine-love2d/**` | ❌ 禁 | 四禁改路径 |
| `game/engine-mud/**` | ❌ 禁 | 四禁改路径 |
| `game/script/jyconst.lua` 常量 | ❌ 禁 | 四禁改路径 |
| `reference/allmods/**` | ❌ 禁 | 只读参考 |

## 6. 交付物

- `proposal.md`（本文件）
- `design.md`（ADR + Negative Constraints + Review Checklist）
- `specs/allmods-books-activation/spec.md`（REQ-BK-1~13 的 Given/When/Then）
- `tasks.md`（含 Blast Radius 与机器可验证 DoD）
- `verification.md`（全部实测命令 + 输出 + 结论）
