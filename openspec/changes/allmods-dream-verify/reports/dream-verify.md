---
status: active
created: 2026-10-26
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice14
---
# 审计报告：kys-dream（笑梦游记）

> 独立审计。全部数据由**当前 worktree 实测**得出，不引用任何历史文档数值。
> 命令均在 `game/` 下执行。

## 0. 结论

| 维度 | 结论 |
|------|------|
| 构建 | ✅ `data 280(+1 ranger.str) / saves 27 / sound 77 / events 4569 / talk 6464` |
| 审计闭合 | ✅ `416 = 378+4+3+1+1+29`，`unclassified=0 bad_evidence=0` |
| 格式覆盖 | ✅ `formats=12 checked=225 gaps=0` |
| 记录边界 | ✅ 5 段整除全 0 余数，CC 尺寸全标准值 |
| 启动链路 | ✅ `RESULT dream: OK`，16 断言 |
| 内容真实性 | ✅ `added/removed` 双向集合相等；fight 五分类自洽 |
| 缺陷 | **0**（内容 0 / 工具 0） |
| `RepairIdx` | **未触发**（源 `ranger.idx` 完好） |

---

## 1. 独特性一：`kdef` 事件 4569 —— 全 20 MOD **第 1**

```bash
$ python3 (扫 mods/*/data/kdef.idx 条目数)
dream=4569  排名 1/20
前5: dream=4569, BookCalamity=1701, mingdong=1654, lyff=1358, pig=1288
```

dream 的 `kdef` 是**全 epic 最大**，为第 2 名（BookCalamity 1701）的 **2.69 倍**。

- `kdef.idx` = 18276B → **4569** offsets；`kdef.grp` = 206286B
- 末 offset `206274` < grp `206286`，**尾部残留 12B**

12B 残留溯源：

```bash
$ python3
kdef.grp 产物=206286B 源=206286B  md5同=True
  末 offset=206274  尾部残留=12B  -> 源侧亦同? True
$ python3 -c "print(open('mods/dream/data/kdef.grp','rb').read()[-12:])"
b'$\xea\xb9\xaf%\xc6*.\xfb\xfeDx'
```

✅ 源侧本有 12B 尾部（`md5` 全同）⇒ 构建器**忠实搬运**，不是截断/损坏。

---

## 2. 独特性二：fight **增删并行**（`92 − 41 + 71 = 122`）

```bash
$ python3 (md5 分象限)
A=2 B=49 E=41 C=71 D=0
A+B+E=92 ✅   A+B+C=122 ✅   92−41+71=122 ✅
A+B=51 ≠ 92  ← 四象限失效
```

| 象限 | 数量 | 说明 |
|------|-----:|------|
| A 保留（同名同容） | 2 | 仅 2 场与基线逐字节相同 |
| B 改写（同名异容） | 49 | 半数以上被改 |
| **E 删除（基线有、MOD 无）** | **41** | **本 epic 首个删除象限** |
| C 新增（MOD 独有） | 71 | 大量新战斗 |
| D 零字节 | 0 | 无零字节 |

被删 41 组：
`43,46,49,50,56..65,67,68,70,71,76..83,85..88,90..93,95..99,101,102,109`

**为什么这是独特性**：books 与 pineapple 的 `E` 都是 **0**（只增/只改，不删）。
dream 是 epic 中**第一个**同时大量增（71）与大量删（41）的 MOD。

附带产物：`added` 中含**孤儿 `fight23.idx`**（有 idx 无 grp，源侧亦然）。

```bash
$ python3
idx 独有组（有 idx 无 grp）: [23]
产物 fight23.idx 存在=True   产物 fight23.grp 存在=False
源   fight23.idx 存在=True   源   fight23.grp 存在=False
```

⇒ 作者删 grp 漏删 idx。流水线**忠实保留**，引擎**不读**。

---

## 3. 独特性三：`eft` 与基线**逐字节相同**（epic 唯一零改动）

```bash
$ python3
eft.idx      dream==baseline ? True
eft.grp      dream==baseline ? True
  dream    eft.idx=2856B  eft.grp=691627B
  baseline eft.idx=2856B  eft.grp=691627B

$ grep -E "^\s*-\s*[-+]\s*eft\." mods/dream/diff.md
（无输出）
```

| MOD | eft 条目 | 与基线 |
|-----|--------:|--------|
| **dream** | **714** | **md5 全同** |
| books | 973 | 改动 |
| pineapple | 1378 | 改动 |
| mingdong | 2268 | 改动 |
| BookCalamity | 2857 | 改动 |

**三重证明**（见 `verification.md` REQ-DRMV-7）：
md5 相同 + diff 缺席（排除回退）+ 大小相同。

⇒ dream 是 epic 中**唯一**完全未改 `eft` 的 MOD。前 13 个 MOD 全部改过特效。

---

## 4. 独特性四：记录段 **5/5 全异**（epic 唯一）

```bash
$ python3
offsets=[836, 75274, 111754, 118098, 131970, 132270]
seglen =[74438, 36480, 6344, 13872, 300]   grp=132270B
```

| 记录 | 段长 | CC 尺寸 | 记录数 | 余数 |
|------|-----:|--------:|-------:|-----:|
| Person | 74438 | 182 | **409** | 0 |
| Thing | 36480 | 190 | **192** | 0 |
| Scene | 6344 | 52 | **122** | 0 |
| Wugong | 13872 | 136 | **102** | 0 |
| Shop | 300 | 50 | **6** | 0 |

**5 段记录数全部与基线不同**（基线 `320/200/84/93/3`），是本 epic 唯一。

前序 MOD 的段差异数量：

| MOD | 段与基线不同的个数 |
|-----|:------------------:|
| lyff | 1 |
| ptt | 4 |
| **dream** | **5（全异）** |

**关键**：CC 尺寸实测全部为**标准值** `182/190/52/136/50`（与基线完全一致）
⇒ 段长全异只是**记录数**不同，**布局标准**，统一判据成立（第 3 次应用）。

### 4.1 重要勘误：源 `ranger.idx` **完好**，`RepairIdx` **未触发**

slice14 manifest 初稿断言：

> 「源 `ranger.idx`：5 段长全不可整除 → 构建期 `RepairIdx` → 结构修复（第 2 案例）」

实测推翻：

```bash
$ python3
seglen 整除 182/190/52/136/50 : [True, True, True, True, True]
md5(产物 idx) == md5(源 idx) : True
$ lua tools/mod_build.lua kys-dream | grep -i repair
（无输出）
$ grep -i idxRepaired mods/dream/encoding-report.md
（无输出）
```

⇒ **dream 不是 `RepairIdx` 案例；zheng 仍是唯一案例。**

---

## 5. 独特性五：`hdgrp` 484 含 72 个零长段（**第 2 大**）

```bash
$ python3
hdgrp: 记录=483 PNG=0 RLE=411 零长=72 头异常=0
   w: 1..58  h: 1..71
   offs[0]=2895 last=944448 grp=944448 tail=0 严格递增=True
零长块: [(381, 69), (480, 3)]  Σ=72
```

| 维度 | dream | 基线 |
|------|------:|-----:|
| offsets | **484** | 115 |
| 段数 | 483 | 114 |
| PNG | 0 | 2 |
| RLE | 411 | 112 |
| **零长** | **72** | **0** |
| 头异常 | **0** | 0 |
| `w` 范围 | 1..58 | 13..56 |
| `h` 范围 | 1..71 | — |

**排名第 2**（不是第 1）：

```bash
$ python3
hdgrp   dream=484  排名 2/20
前5: books=696, dream=484, pig3dos=412, BookCalamity=373, awaken=353
```

**零长非缺陷的反证**：同一 MOD、同一 `idx_grp_rle` 家族、同一解析器：

```bash
$ python3
dream eft: 记录=713 PNG=0 RLE=713 零长=0 头异常=0 w:1..214 h:1..189
```

⇒ `hdgrp` 有 72 零长而 `eft` 有 0 ⇒ 零长是 `hdgrp` **内容特征**（共享/占位帧）。
与 `format_spec --mod dream` 的 `gaps=0` 一致（`format_spec.lua:232`；`verifyPair` 以 `b > a` 跳过）。

零长块集中在段 `381..449`（69 段）与 `480..482`（3 段）。

---

## 6. 独特性六：`removed 105` 的「四类型」结构

```bash
$ python3
removed 总=105
  槽 .grp=9   槽 .idx=9   fight=82  模板=2  死文件=3
  Σ=105  == 105? True
```

| 类别 | 数量 | 机制 | 验证 |
|------|-----:|------|------|
| 槽 `.grp` | 9 | 源提供 → 改道 `save/` | 产物 `save/` md5 一致 **9/9** |
| 槽 `.idx` | 9 | 源**不存在** → `SeedSaveSlot` 播种 | 源 `save/` **0/9**；播种 md5 == `ranger.idx` |
| 战斗 | 82 | 41 组回退原版 | `E=41`（见 §2） |
| 模板 | 2 | `thing.grp/idx` 回退 | 基线模板可用 |
| 死文件 | 3 | `alldef.idx`/`allsin.idx`/`allsinbk.grp` | 引擎无引用 |
| **真删除** | **0** | — | 无内容丢失 |

`SeedSaveSlot` 实测（**单返回值**）：

```bash
$ lua /tmp/dream_seed.lua
Resolve(save/r1.idx) =	data/save/r1.idx
SaveDir() =	mods/dream/save/
SeedSaveSlot(1) -> mods/dream/save/r1.idx
SeedSaveSlot(2) -> mods/dream/save/r2.idx
SeedSaveSlot(3) -> mods/dream/save/r3.idx
```

播种内容 md5 == `data/ranger.idx` (`08e488fefacf2e1fe43a757ad609bcab`) ✅

**与 books 的差异**：books 是 `13 槽改道 + 5 缺席 + 3 模板 = 21`；
dream 是 `9 槽改道 + 9 播种 + 82 战斗 + 2 模板 + 3 死 = 105`。
**规模差 5 倍**，且 dream 多了「槽 `.idx` 按需播种」与「大量战斗回退」两类。

---

## 7. 独特性七：`save/` 27 vs 源 31（4 项改道 `data/`）

```bash
$ python3
产物 save/ = 27   源 save/ = 31
  产物 .grp=27  .idx=0
  逐字节一致 = 27/27
  源独有 4: alldef.grp / allsin.grp / ranger.grp / ranger.idx
```

| 改道项 | 大小 | md5 | 说明 |
|--------|-----:|:---:|------|
| `alldef.grp` | 536800B | **同** | 纯二进制 |
| `allsin.grp` | 5996544B | **同** | 纯二进制 |
| `ranger.idx` | 24B | **同** | 纯偏移表 |
| `ranger.grp` | 132270B | **异** | **UTF-8 编码转换**（hint 方案，大小不变） |

27 槽覆盖 `d/r/s × {1,2,3,4,5,6,7,9,11}` —— **源缺 8 号槽**（作者删除）。

> **勘误**：manifest 初稿写「产物 `save/` 31 与源 31 逐字节一致」——实测产物 **27**。

---

## 8. 排名声明逐项实测

| 声明 | 实测 | 排名 | 判定 |
|------|-----:|-----:|:----:|
| `kdef` 第 1 | 4569 | 1/20 | ✅ 成立 |
| `hdgrp` 第 2 | 484 | 2/20 | ✅ 成立（**不是**第 1） |
| `talk` 第 4 | 6464 | 4/20 | ✅ 成立 |
| `Person` 第 7 | 409 | 7/20 | ✅ 成立 |
| `fight` 第 12 | 122 | 12/20 | ✅ 成立（**远非**前列） |
| `eft` 零改动 | 714 | 唯一 | ✅ 成立 |
| 零字节 fight 最少 | 0 | 并列最少 | ✅ 成立 |
| 记录段全异 | 5/5 | 本 epic 唯一 | ✅ 成立 |

⚠️ **防误判**：本 MOD 只有 `kdef` 是真正「第 1」。若误把 `hdgrp 484` 或
`fight 122` 写成「最大/最多」，即为错误断言（books 696 > 484；
11 个 MOD 的 fight 都多于 122）。

---

## 9. PENDING 遗留（29 项，epic 级 spike）

```
music/*.mid  25
list/*.bin    4
```

均属 epic 级待办（`music/*.mid` 播放支持、`list/effect.bin` → `CC.Effect`），
不在本 change 范围。

---

## 10. 零缺陷声明

| 类别 | 数量 | 依据 |
|------|-----:|------|
| 内容缺陷 | **0** | `diff.md` 双向集合相等；`unclassified=0`；fight 五分类自洽 |
| 构建缺陷 | **0** | `mod_build --all` 0 failures；产物 16 断言全 PASS |
| 工具缺陷 | **0** | `game/tools/**` 未改动 |
| 格式缺陷 | **0** | `formats=12 checked=225 gaps=0` |

本 MOD 的 3 处「异常表象」全部判定为**非缺陷**并给出依据：

1. **72 个零长 `hdgrp` 段** → `idx_grp_rle` 合法表达（`eft` 反证 + `format_spec` 跳过）
2. **`kdef.grp` 尾部 12B** → 源侧本有（md5 全同，忠实搬运）
3. **孤儿 `fight23.idx`** → 作者残留（源侧亦无 `fight23.grp`，忠实保留，引擎不读）
