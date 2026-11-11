---
status: done
created: 2026-10-26
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice14
result: PASS
---
# Verification: allmods-dream-activate

> 全部命令在 `game/` 下执行，每次运行前 `rm -f active_mod.txt`。

## 总览

| REQ | 主题 | 结论 |
|-----|------|------|
| REQ-DRM-1 | 构建产物 | ✅ `280/27/77/4569/6464`，目录 281 |
| REQ-DRM-2 | 穷举审计 | ✅ `416=378+4+3+1+1+29`，`unclassified=0` |
| REQ-DRM-3 | 字节覆盖 | ✅ `formats=12 checked=225 gaps=0` |
| REQ-DRM-4 | 记录段判据 | ✅ 5 段整除全 0；`RepairIdx` **未触发** |
| REQ-DRM-5 | 启动链路 | ✅ `RESULT dream: OK`，16 断言 |
| REQ-DRM-6 | 编码转换 | ✅ 旁路表 763，Σ 双重闭合 |
| REQ-DRM-7 | `hdgrp` 484 | ✅ `411 RLE + 72 零长`，头异常 0 |
| REQ-DRM-8 | `eft` 零改动 | ✅ md5 与基线**全同** |
| REQ-DRM-9 | 8 道门禁 | ✅ 全绿 |

**结论：9/9 PASS，0 构建缺陷，0 工具缺陷。**

---

## REQ-DRM-1 构建产物 ✅

```bash
$ rm -f active_mod.txt && lua tools/mod_build.lua kys-dream
[mod_build] kys-dream: data files=280, saves=27, sound=77, events=4569, talk=6464
[mod_build] diff -> tools/../mods/dream/diff.md

$ ls mods/dream/data | wc -l
281
```

**口径差说明**：`280` 是构建器计数（不含 `ranger.str`），目录实测 `281`。
`ranger.str` 由 `tools/mod_encoding.lua` 生成（旁路表），
不是构建遗漏 —— 同 books 口径（`392` vs `393`）。

源文件分布（416）：

```
fight 245 / sound 77 / save 31 / resource 30 / music 25 / list 6 / script 1 / root 1
```

---

## REQ-DRM-2 穷举审计 ✅

```bash
$ lua tools/mod_audit.lua --mod dream --evidence
total=416 in_product=383 not_in_product=33 unclassified=0 bad_evidence=0
  REQUIRED             378
  REQUIRED_CONVERTED   4
  LEGACY               3
  DEAD_FILE            1
  BUILD_INPUT          1
  PENDING              29
evidence: checked=9 failed=0
```

闭合验算：`378 + 4 + 3 + 1 + 1 + 29 = 416` ✅（== 源文件总数）

PENDING 29 = `music/*.mid` 25 + `list/*.bin` 4（epic 级遗留 spike）。

---

## REQ-DRM-3 字节级覆盖 ✅

```bash
$ lua tools/format_spec.lua --mod dream
formats=12 checked=225 gaps=0
```

---

## REQ-DRM-4 记录段判据 ✅

```bash
$ python3 (解析 ranger.idx)
offsets=[836, 75274, 111754, 118098, 131970, 132270]
seglen =[74438, 36480, 6344, 13872, 300]   grp=132270B
Person 74438/182=409.0  Thing 36480/190=192.0  Scene 6344/52=122.0
Wugong 13872/136=102.0  Shop 300/50=6.0
```

| 记录 | 段长 | 尺寸 | 商 | 余数 |
|------|-----:|-----:|---:|-----:|
| Person | 74438 | 182 | 409 | **0** |
| Thing | 36480 | 190 | 192 | **0** |
| Scene | 6344 | 52 | 122 | **0** |
| Wugong | 13872 | 136 | 102 | **0** |
| Shop | 300 | 50 | 6 | **0** |

末 offset `132270` == `ranger.grp` `132270B`，`tail = 0` ✅

**源 `ranger.idx` 完好** + **`RepairIdx` 未触发**：

```bash
$ md5(src/save/ranger.idx) vs md5(mods/dream/data/ranger.idx)
源 ranger.idx = 24B  offsets=[836, 75274, 111754, 118098, 131970, 132270]
产物 ranger.idx = 24B  同上
md5 相同 = True

$ lua tools/mod_build.lua kys-dream | grep -i "repair"
（无输出）

$ grep -i "idxRepaired" mods/dream/encoding-report.md
（无输出）
```

### 4.1 偏差记录（推翻 manifest 初稿）

manifest 初稿断言：

> 「源 `ranger.idx`：5 段长全不可整除 → 构建期 `RepairIdx` → **结构修复（第 2 案例）**」

**实测推翻**：源 `ranger.idx` 段长 `[74438, 36480, 6344, 13872, 300]`
**全部整除**（182/190/52/136/50），末 offset == grp 大小，**完好无损**。
`RepairIdx` **未触发**（三重佐证：构建日志无输出、产物 idx 与源 md5 相同、
`encoding-report.md` 无 `idxRepaired` 字段）。

⇒ **dream 不是 `RepairIdx` 案例，zheng 仍是唯一案例。**
manifest 已按实测修正并保留勘误说明。

---

## REQ-DRM-5 真实启动链路 ✅

```bash
$ rm -f active_mod.txt && lua tests/unit/boot_one_mod.lua dream 409 192 122 102 隨小破
[PASS] lib.init 无报错: nil
[PASS] JYMainAdapter.init 无报错: nil
[PASS] CC.PersonSize=182（MOD 布局） (期望 182, 实际 182)
[PASS] CC.ThingSize=190（MOD 布局） (期望 190, 实际 190)
[PASS] CC.SceneSize=52（MOD 布局） (期望 52, 实际 52)
[PASS] CC.WugongSize=136（MOD 布局） (期望 136, 实际 136)
[PASS] LoadRecord(0) 无报错: true
[PASS] PersonNum (期望 409, 实际 409)
[PASS] ThingNum (期望 192, 实际 192)
[PASS] SceneNum (期望 122, 实际 122)
[PASS] WugongNum (期望 102, 实际 102)
[PASS] 主角姓名 (期望 隨小破, 实际 隨小破)
[PASS] 扫描字段数 > 100（实际 1618）
[PASS] 全量字符串无 U+FFFD (期望 0, 实际 0)
[PASS] 全量字符串无控制符 (期望 0, 实际 0)
[PASS] 运行时 10 帧无报错: nil
--------------------------------------------------
RESULT dream: OK
```

16/16 PASS ✅。5 个位置参数 `409 192 122 102 隨小破` 全部为**规格期望值**，
不是运行时实测值 —— 避免 `x == x` 的假通过。

---

## REQ-DRM-6 编码转换 ✅

```bash
$ head -20 mods/dream/encoding-report.md
| 转换字段数 | 1618 |
| 去重复用数 | 855 |
| 旁路表条目 | 763 |
| 截断字段数 | 0 |
| hint 溢出 | 0 |

| 段 | 记录数 | 字符串字段 | 转换 | 去重 |
| Person | 409 | 818 | 818 | 575 |
| Thing  | 192 | 576 | 576 | 233 |
| Scene  | 122 | 122 | 122 | 40  |
| Wugong | 102 | 102 | 102 | 7   |
```

`ranger.str` 独立核对：

```bash
$ python3 (统计 ranger.str)
总行=770 有效=763 注释=7
分段: {'Person': 243, 'Thing': 343, 'Scene': 82, 'Wugong': 95} Σ= 763
字段: {'Name': 513, 'Nick': 82, 'Desc': 168} Σ= 763
唯一值=732 重复=31
前3行: ['0000,Person,0,Name,隨小破', '0001,Person,0,Nick,天下奇男子', '0002,Person,1,Name,李文秀']
```

✅ 三重一致：`encoding-report 763` == `ranger.str 有效 763` == `分段 Σ 763` == `字段 Σ 763`。

格式为**逗号分隔** `id,段,索引,字段,值`（实测首页即证）。

---

## REQ-DRM-7 `hdgrp` 484 ✅

```bash
$ python3 (解析 hdgrp.idx / hdgrp.grp)
hdgrp: 记录=483 PNG=0 RLE=411 零长=72 头异常=0
   w: 1..58  h: 1..71
   offs[0]=2895 last=944448 grp=944448 tail=0 严格递增=True
零长块: [(381, 69), (480, 3)]  Σ=72
```

- `484 offsets` ↔ `483 段`（末 offset `944448` 为哨兵，不构成段）✅
- `411 RLE + 72 零长 = 483` ✅
- **头异常 = 0**：411 个非空段全部 `w>0, h>0` ✅
- 上限 `w 1..58` / `h 1..71`，无异常巨值 ✅

基线对照：

```bash
baseline hdgrp: 记录=114 PNG=2 RLE=112 零长=0 头异常=0 w:13..56
```

`eft` 同家族对照（证明零长是内容特征）：

```bash
dream eft: 记录=713 PNG=0 RLE=713 零长=0 头异常=0 w:1..214 h:1..189
```

✅ dream `hdgrp` 的 72 个零长段（2 个块）与 `eft` 的 0 个零长形成对照，
且头异常 0 ⇒ 零长属 `idx_grp_rle` 内容特征，非格式缺陷。

---

## REQ-DRM-8 `eft` 与基线逐字节相同 ✅

```bash
$ python3 (md5 比对)
eft.idx      dream==baseline ? True
eft.grp      dream==baseline ? True
  dream    eft.idx=2856B  eft.grp=691627B
  baseline eft.idx=2856B  eft.grp=691627B
```

`diff.md` 排除回退：

```bash
$ grep -E "^\s*-\s*[-+]\s*eft\." mods/dream/diff.md
（无输出）
```

✅ `eft.*` 既不在 `added` 也不在 `removed` ⇒ 产物侧真实存在，内容与基线相同
（**不是**构建器回退）。

⇒ dream 是 epic 中 `eft` **零改动**的正样本：

| MOD | eft 条目 | 与基线关系 |
|-----|--------:|------------|
| dream | 714 | **md5 全同（零改动）** |
| books | 973 | 改动（全 RLE） |
| pineapple | 1378 | 改动 |
| mingdong | 2268 | 改动 |
| BookCalamity | 2857 | 改动 |

---

## REQ-DRM-9 8 道门禁 ✅

| # | 门禁 | 实测输出 | 结论 |
|---|------|----------|------|
| 1 | `lua tests/test_runner.lua` | `通过: 1842` / `失败: 0` / `✓ 所有测试通过!` | ✅ |
| 2 | `lua tools/mod_build.lua --verify-pascal` | `[mod_build] pascal baseline: PASS`；3 条 `[known]`（event 320/655/691） | ✅ |
| 3 | `lua tools/mod_build.lua --all` | `all: 20 mods, 0 build failures, 5 annotated-problematic` | ✅ |
| 4 | `lua tools/mod_check.lua` | `总计: 20 MOD, 通过 20, 失败 0` | ✅ |
| 5 | `lua tools/mod_audit.lua --all --evidence` | `total=11220 in_product=9245 not_in_product=1975 unclassified=0 bad_evidence=0`；`evidence: checked=17 failed=0` | ✅ |
| 6 | `lua tools/format_spec.lua --all` | `formats=12 checked=6773 gaps=0` | ✅ |
| 7 | 门禁 7（槽/模板统计） | 与 Slice 12/13 同口径复跑，真实问题 **0**（本 change 不改脚本） | ✅ |
| 8 | `git status --porcelain` | 四禁改路径**无改动**；`game/script/jyconst.lua` `+11/−1`（allmods-data-fallback 接线，**非** `CC.*=` 新增，acceptable） | ✅ |

门禁 3 退出码 `1` 属设计（`mod_build.lua:1222-1224`，`--all` 汇总有 annotated-problematic 时非零退出）。

---

## Blast Radius 合规检查

```bash
$ git status --porcelain | grep -E "engine-love2d|engine-mud|reference/allmods" 
（无输出）
$ git diff --stat game/script/jyconst.lua
 game/script/jyconst.lua | 12 +++++++++++-
 1 file changed, 11 insertions(+), 1 deletion(-)
```

| 路径 | 是否改动 | 判定 |
|------|:--------:|------|
| `game/engine-love2d/**` | 无 | ✅ |
| `game/engine-mud/**` | 无 | ✅ |
| `game/script/jyconst.lua` 常量 | 仅 `+11/−1` 接线（非 `CC.*=`） | ✅ |
| `reference/allmods/**` | 无 | ✅ |
| `game/tools/**` | 无（未发现工具缺陷） | ✅ |
| `game/mods/dream/**` | 新增产物 | ✅ 允许 |

---

## 偏差记录汇总

| # | 项 | 初稿断言 | 实测结论 | 处置 |
|---|----|----------|----------|------|
| 1 | 源 `ranger.idx` | 损坏，5 段长全不可整除，`RepairIdx` 第 2 案例 | **完好**，段长全整除，`RepairIdx` **未触发** | manifest 已勘误 |
| 2 | 产物 `save/` | 31 文件与源 31 逐字节一致 | 产物 **27**（全槽 `.grp`），源 31；差 4 个改道 `data/` | manifest 已勘误 |
| 3 | `data files` | 280 | 280（builder 口径）/ **281** 目录实测（`ranger.str`） | manifest 已补口径说明 |
| 4 | fight 自洽 | 未给删除象限 | `A+B=51 ≠ 92`；需 **E=41 删除象限**才闭合 | manifest 已补五分类 |

---

## 复现命令

```bash
cd game && rm -f active_mod.txt

lua tools/mod_build.lua kys-dream
lua tools/mod_audit.lua --mod dream --evidence
lua tools/format_spec.lua --mod dream
MOD_SLUG=dream lua tools/mod_check_one.lua
lua tests/unit/boot_one_mod.lua dream 409 192 122 102 隨小破

lua tests/test_runner.lua
lua tools/mod_build.lua --verify-pascal
lua tools/mod_build.lua --all
lua tools/mod_check.lua
lua tools/mod_audit.lua --all --evidence
lua tools/format_spec.lua --all
```
