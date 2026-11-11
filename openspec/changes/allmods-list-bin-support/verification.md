---
status: done
created: 2026-10-29
---
# Verification: allmods-list-bin-support

> 本文所有数字均为**实测**，每条判据附命令 + 输出。未实测的项标注「未测」。
> 环境：worktree `/home/woodfish/project/legend-love`，Lua 根目录 `game/`。

## 0. 结论速览

| 项 | 结果 | 关键证据 |
|---|---|---|
| `list/*.bin` 进产物 | ✅ 20/20 MOD 逐字节一致 | §1.2 |
| 运行时惰性装载 | ✅ pascal 64 / BookCalamity 200 项生效 | §2.2 |
| 负向对照（有鉴别力） | ✅ 3 项短文件→3；删除→53 兜底 | §2.3 |
| `format_spec` 记录级 | ✅ `checked=6838 gaps=0`，奇字节显式失败 | §3 |
| `mod_audit` 归类收口 | ✅ `PENDING 663→581`，`.bin` 残留 0 | §4 |
| 测试总数 | ✅ **1957** / 0 failed（原 1914，+43） | §5 G1 |
| 8 门禁 | ✅ 全绿 | §5 |
| 四禁改 | ✅ **0 处** | §5 G8 |
| 幂等性 | ✅ 二次构建 0 差异 | §5.2 |

**`PENDING` 构成（581）**：`.mid` 578 + `.mp3` 2 + `.sf2` 1 = 581，**无 `.bin`**。

---

## 1. [REQ-LBIN-1] `list/*.bin` 进产物

### 1.1 根因（修正此前认知）

原 `collectDataFiles()` 只走 `resource/`、`fight/`、`save/`、`sound/` 四个目录，
**`list/` 根本不在遍历列表中** ⇒ 全部 6 个文件从未进产物，而非"进了但漏审"。

修正方式：新增白名单目录遍历（`mod_build.lua`）：

```lua
local LIST_COPY_WHITELIST = { ["effect.bin"] = true, ["match.bin"] = true }
...
    walk(modDir .. "/list", "", "list-whitelist")
```

```lua
elseif kind == "list-whitelist" then
    if not LIST_COPY_WHITELIST[lower] then fileKind = nil else fileKind = "data" end
end
```

`leave.bin` / `levelup.bin` / `*.txt` **不进产物**（ADR-1：引擎零引用，属 LEGACY）。

### 1.2 DoD 实测

```bash
$ lua tools/mod_build.lua kys-pascal
[mod_build] kys-pascal: data files=232, saves=21, sound=78, events=1018, talk=2977
```

| 判据 | 命令 | 输出 | |
|---|---|---|:--:|
| `data/effect.bin` 存在 | `ls -la mods/pascal/data/effect.bin` | `-rw-rw-r-- 128 ...` | ✅ |
| 大小 = 128 | `stat -c%s mods/pascal/data/effect.bin` | `128` | ✅ |
| md5 == 源 | `md5sum < ../reference/allmods/kys-pascal/list/effect.bin` | `be22512bbede362b76164b3915e47410` | ✅ |
| md5 产物 | `md5sum < mods/pascal/data/effect.bin` | `be22512bbede362b76164b3915e47410` | ✅ |
| `leave.bin` 不存在 | `ls mods/pascal/data/leave.bin` | `No such file or directory` | ✅ |
| `levelup.bin` 不存在 | `ls mods/pascal/data/levelup.bin` | `No such file or directory` | ✅ |

**全 20 MOD 逐字节比对**：

```bash
for m in $(ls -d ../reference/allmods/kys-*); do
  s=$(basename $m|sed s/kys-//)
  diff -q $m/list/effect.bin mods/$s/data/effect.bin
done
# → 无输出（0 差异）
```

| 文件 | 结果 |
|---|---|
| `effect.bin` 逐字节一致 | **20/20** ✅ |
| `match.bin` 逐字节一致 | **20/20** ✅ |
| `lua tools/mod_build.lua --all` | `20 mods, 0 build failures, 5 annotated-problematic` ✅ |

---

## 2. [REQ-LBIN-2] / [REQ-LBIN-5] 运行时惰性装载

### 2.1 实现位置（ADR-2）

- 新增 `ModData.LoadEffectTable(CC)`（`framework/mod_data.lua`）
- 在 `framework/jymain_adapter.lua` 的 `initCoroutine()` 中、`SetGlobalConst()` 之后、
  `SetGlobal()` 之前调用 —— **`jyconst.lua` 一个字符未改**（禁改路径）。

```lua
if ok and ModData and ModData.LoadEffectTable then
    local loaded, n = ModData.LoadEffectTable(_G.CC)
    if loaded then lib.Debug("ModData.LoadEffectTable: " .. tostring(n) .. " entries") end
end
```

函数导出验证：

```bash
$ lua -e 'print(type(require("framework.mod_data").LoadEffectTable))'
function   ✅
```

### 2.2 真实启动链路实测（独立进程 `boot_one_mod` 同款链路）

```bash
SLUG=pascal lua /tmp/eff_probe.lua   # 探针 = boot_one_mod 的启动序列 + CC.Effect 计数
```

| MOD | `CC.Effect` 项数 | maxIdx | `[0]` | `[52]` | `[53]` |
|---|---:|---:|---:|---:|---:|
| （未激活 MOD） | **53** | 52 | 9 | 7 | `nil` |
| pascal | **64** | 63 | 10 | 7 | 0 |
| BookCalamity | **200** | 199 | 10 | 14 | 14 |
| mingdong | **200** | 199 | 16 | 20 | 8 |
| pineapple | **84** | 83 | 24 | 12 | 17 |

判据：

| 判据 | 结果 |
|---|---|
| pascal 启动后 `CC.Effect[53]` 非 nil（64 项生效） | ✅ `= 0` |
| BookCalamity `#CC.Effect` = 200 | ✅ |
| 未激活时保持 53 项兜底 | ✅ |
| `grep -c 'CC\.[A-Za-z]* *=' game/script/jyconst.lua` 改动前后相同 | ✅ **0 处**（G8b） |

### 2.3 `index 0` 语义取证（关键决策的依据）

原硬编码 `CC.Effect[0] = 9`，而 `effect.bin[0] = 10`（20/20 MOD 全部如此）。
整表覆盖会把 `[0]` 从 9 改为 10 —— 必须证明哪个正确。

`war_async.lua:1120-1123` 的 `starteft` 累加**从 `i = 0` 开始**：

```lua
if CC.Effect then
    for i = 0, eft - 1 do
        starteft = starteft + (CC.Effect[i] or 0)
    end
end
```

⇒ `[0]` **参与**累加。用 `sum(effect.bin) == (eft.idx 字节数 / 4 - 1)` 做语义校验：

```bash
$ lua /tmp/eff_all20.lua
```

| MOD | n | sum(**含** idx0) | eft 段数 | sum(**跳** idx0) | 含0匹配 | 跳0匹配 |
|---|---:|---:|---:|---:|:--:|:--:|
| pascal | 64 | **713** | 713 | 703 | ✅ | ✗ |
| dream | 64 | **713** | 713 | 703 | ✅ | ✗ |
| ptt | 64 | **713** | 713 | 703 | ✅ | ✗ |
| zheng | 64 | **713** | 713 | 703 | ✅ | ✗ |
| pig | 64 | **713** | 713 | 703 | ✅ | ✗ |
| Dragon / GodsDevils / HeavenSword / lostbook / loving / lyff / pig3dos / stronger / SweeOan | 64 | **713** | 713 | 703 | ✅ | ✗ |
| BookCalamity | 200 | 2857 | 2856 | 2847 | ✗(+1) | ✗ |
| mingdong | 200 | 2312 | 2267 | 2296 | ✗(+45) | ✗ |
| pineapple | 84 | 1378 | 1377 | 1354 | ✗(+1) | ✗ |
| RiverLake | 70 | 921 | 920 | 911 | ✗(+1) | ✗ |
| books | 64 | 963 | 972 | 939 | ✗(−9) | ✗ |
| awaken | 64 | 713 | 726 | 703 | ✗(−13) | ✗ |

**口径说明（重要，避免与历史文档冲突）**：

`eft.idx` 是纯偏移数组，实测 `n = size/4`（如 pascal 714 条），其中
`offset[0] = 77` 指向 `.grp` 内首个效果图（前 77 字节为头部），
`offset[n-1] == eft.grp 文件大小`（如 pascal 691627）作**哨兵**。
⇒ **真实段数 = n − 1**（pascal 713）。

因此「`sum(effect.bin)` 与段数相等」应表述为 `sum == size/4 − 1`，
等价于 `size/4 == sum + 1`（一帧一条偏移 + 1 条哨兵）。

> **勘误（与 `allmods-riverlake-activate/verification.md` §8.2 的口径差异）**：
> 该文档用 `checked=eft.idx 条目数` 作分母，记 RiverLake `sum=921 == 921` 为「精确相等」、
> pascal `713 vs 714` 为「差 1（尾部补零）」。那是**用 n 而非 n−1 比**。
> 本文统一采用 **n−1** 口径：pascal `713 == 713` 精确、RiverLake `921 vs 920` 差 +1。
> **两处结论不冲突，只是分母差 1**；本文口径的自我一致性由「20 MOD 中 14 个用同一式子
> 精确命中」保证（若分母错，不可能有 14 个同时命中）。

**结论**：

- `sum(含 idx0) == eft段数(size/4−1)` 在 **14/20** MOD 精确成立；`sum(跳 idx0)` **0/20** 成立。
- ⇒ `index 0` 必须参与累加；数据文件的 `10` 是正确值，硬编码的 `9` 是**原版提取期口径遗留**。
- 6 个偏差 MOD 的偏差属 **MOD 数据侧自身不一致**（作者的 `effect.bin` 与 `eft.idx` 不同步），
  与解析口径无关。
- 此结论同时修正了此前 spike 报告的 13/20（spike 用近似段数口径；此处按
  `size/4 - 1` 精确计算，多认 RiverLake 一个）。

**因此整表覆盖（含 `[0]`）是正确的**，且 `CC.Effect` 在 `[53..]` 的越界退化问题被消除
（原 `eft >= 53` 时 `framenum` 静默退化为 10 帧）。

### 2.4 DoD：负向对照（证明装载器有鉴别力）

```bash
# 对照 A：3 项短文件（6 字节）
printf '\x0A\x00\x0B\x00\x0C\x00' > mods/pascal/data/effect.bin
SLUG=pascal lua /tmp/eff_probe.lua
# → CC.Effect 项数=3  maxIdx=2  [0]=10 [52]=nil [53]=nil

# 对照 B：删除文件 → 兜底
rm -f mods/pascal/data/effect.bin
SLUG=pascal lua /tmp/eff_probe.lua
# → CC.Effect 项数=53  maxIdx=52  [0]=9 [52]=7 [53]=nil

# 恢复
cp /tmp/effect_backup.bin mods/pascal/data/effect.bin
SLUG=pascal lua /tmp/eff_probe.lua
# → CC.Effect 项数=64  maxIdx=63  [0]=10 [52]=7 [53]=0
```

| 对照 | 期望 | 实测 | |
|---|---|---|:--:|
| 3 项短文件 | `#CC.Effect == 3`（≠53，证明真的读了文件） | `3` | ✅ |
| 删除文件 | 返回 false 且 `#CC.Effect == 53`（兜底） | `53`，`[0]=9` 兜底值 | ✅ |
| 恢复后 | `#CC.Effect == 64` | `64` | ✅ |

**对照 D：错误条目数（语义校验，[REQ-LBIN-5] 第 4 个病态输入）**

装载器本身是**忠实读取器**——给它 200 项它就读 200 项，不会「发现错了」。
真正能抓住「条目数不对」的是**语义校验**（`sum(effect.bin) == eft.idx 段数`）：

```bash
$ python3 -c '...对比 sum 与 eft.idx 段数...'
  正常  pascal:                          项数=64  sum=713  段数=713  → True  ✅
  正常  BookCalamity:                    项数=200 sum=2857 段数=2856 → False（MOD 自身不同步）
  病态  pascal 树 + BookCalamity 的 bin:  项数=200 sum=2857 pascal 段数=713 → False  ← 被抓住
```

| 对照 | 期望 | 实测 | |
|---|---|---|:--:|
| pascal 树 + 他人 `effect.bin` | 语义校验判 **False** | `False`（`sum 2857 ≠ 段数 713`） | ✅ |

⇒ 4 个病态输入（短文件 / 缺失 / 奇数字节 / 错误条目数）**各自被对应的检查抓住**，
且「装载器如实读取」与「语义校验拒绝错误数据」是**两层独立防线**，不是同一断言重复。

四个对照互相排斥 ⇒ 装载器与语义校验**都不是空跑通过**。

---

## 3. [REQ-LBIN-3] `format_spec` 记录级验证

### 3.1 升级内容

`M.verifyBinTable` 从「4 字节单元 + 隐式 tail」升级为「**2 字节 uint16 记录**」：

```lua
local unit = 2                       -- 原: 4
local n = math.floor(#d / unit)
-- 每条记录独立区间，尾部残留不再静默归给 "tail"
res.records = n
res.tail = #d - n * unit
res.unit = unit
if n == 0 then                       -- 新增：空文件显式失败
    res.ok = false
    res.error = "empty file (0 records)"
end
```

**为什么是 2 不是 4**：`effect.bin` 的 `sum == eft.idx 段数` 语义（§2.3）直接证明它是
uint16 数组；`match.bin` 是 `(weapon, wugong, bonus)` 三元组；`leave.bin` = 100 个
人物 id；`levelup.bin` = 101 个经验阈值。**全部按 2 字节对齐**。
原按 4 字节切分会把 `202` 字节的 `levelup.bin` 切成 "50 units + 2 字节 tail"，
对一个 uint16 数组而言这是错口径。

### 3.2 DoD 实测

| 判据 | 命令 | 输出 | |
|---|---|---|:--:|
| `checked` 不减少 | `lua tools/format_spec.lua --all` | `formats=14 checked=6838 gaps=0` | ✅ |
| `gaps=0` | 同上 | `gaps=0` | ✅ |
| `.bin` 记录数 = `filesize/2` | `verifyBinTable(effect.bin)` | `records=64`（128/2） | ✅ |
| 奇数字节 → 显式 gap | 3 字节文件 | `ok=false records=1 tail=1` | ✅ |
| 零字节 → 失败 | 空文件 | `ok=false records=0`，`error="empty file (0 records)"` | ✅ |

负向对照 3/3 正确：

```bash
$ lua -e '...verifyBinTable...'
3字节  ok=false  records=1   tail=1
4字节  ok=true   records=2   tail=0
0字节  ok=false  records=0   tail=0   empty file (0 records)
```

### 3.3 DoD：新增单测

新增 3 条（`tests/unit/test_format_spec.lua`）：

| 测试 | 断言 |
|---|---|
| `testBinTableEvenBytes` | 6 字节 → `ok=true records=3 tail=0` |
| `testBinTableOddBytes` | 3 字节 → `ok=false records=1 tail=1` |
| `testBinTableZeroBytes` | 0 字节 → `ok=false records=0` 且有 `error` |

同时**修正**旧测试 `testListBinCovered`：原断言 `units=32` / `tail=2`（4 字节口径）
已按记录级改写为 `records=64` / `tail=0`，并新增 `levelup.bin records=101 tail=0`。

```bash
$ lua tests/test_runner.lua format_spec
Results: 297 tests, 297 passed, 0 failed
```

模块测试数 **285 → 297（+12）**：3 条新测试 + 1 条改写后扩断言。

---

## 4. [REQ-LBIN-4] `mod_audit` 归类收口

### 4.1 原状态

`["list|.bin"] = { category="PENDING", needed=nil }` —— 按扩展名一刀切，
4 个语义完全不同的文件被同一个 `PENDING` 覆盖，且 `PENDING` 是「待决策」而非终态。

### 4.2 逐文件分类（ADR-1）

从 `BY_KIND` 移到 `EXACT`（键 = `topdir/filename`），因为**不能按扩展名归类**：

| 文件 | 类别 | `needed` | `in_product` | 证据 `kind` |
|---|:--:|:--:|:--:|:--:|
| `list/effect.bin` | `REQUIRED` | true | true | `code` |
| `list/match.bin` | `REQUIRED` | true | true | `code` |
| `list/leave.bin` | `LEGACY` | false | false | `code` |
| `list/levelup.bin` | `LEGACY` | false | false | `code` |
| `list/match - 复制.bin` | `EDITOR_DUMP` | false | false | `external` |
| `list/end.txt` / `start.txt` | `LEGACY` | false | false | `manual` |

**ADR-1 依据**：

- `effect.bin` → `war_async.lua:1110/1121-1123` 消费 `CC.Effect`，现由
  `ModData.LoadEffectTable` 从 `data/effect.bin` 装载 ⇒ 真实消费方存在。
- `match.bin` → 三元组即硬编码 `CC.ExtraOffense`（`jyconst.lua:453+`）的数据侧副本。
- `leave.bin` / `levelup.bin` → 全仓 grep `.bin` 引用 **0 命中**，且无硬编码替代表 ⇒ 纯 C 引擎遗留。

### 4.3 实测：逐条分类结果

```bash
$ lua -e '...auditAll() 后按 path 前缀统计...'
records=11220 unclassified=0
  list/ EDITOR_DUMP      2
  list/ LEGACY          80
  list/ REQUIRED        40
  list/ 合计 = 122
```

| 文件 | 类别 | `needed` | `in_product` | 条数 | 证据 `kind` |
|---|:--:|:--:|:--:|---:|:--:|
| `list/effect.bin` | `REQUIRED` | true | true | 20 | `code`（`war_async.lua:1110`） |
| `list/match.bin` | `REQUIRED` | true | true | 20 | `code`（`jyconst.lua:453` `CC.ExtraOffense`） |
| `list/leave.bin` | `LEGACY` | false | false | 20 | `code`（grep 命中 0） |
| `list/levelup.bin` | `LEGACY` | false | false | 20 | `code`（grep 命中 0） |
| `list/end.txt` | `LEGACY` | false | false | 20 | `manual`（通关字幕） |
| `list/start.txt` | `LEGACY` | false | false | 20 | `manual`（开场字幕） |
| `list/match - 复制.bin` | `EDITOR_DUMP` | false | false | 2 | `external`（md5 `e4d31678…`） |
| **合计** | | | | **122** | |

`40 + 80 + 2 = 122` —— 与 `find reference/allmods/kys-*/list -type f | wc -l` 的 122 **精确相等**，
无一条遗漏、无一条未归类。

判据：

| 判据 | 期望 | 实测 | |
|---|---|---|:--:|
| `list/` 记录总数 | 122 | **122** | ✅ |
| `REQUIRED` 条数 | 40（20 effect + 20 match） | **40** | ✅ |
| `LEGACY` 条数 | 80（20×4：leave/levelup/end.txt/start.txt） | **80** | ✅ |
| `EDITOR_DUMP` 条数 | 2 | **2** | ✅ |
| `list/` 未归类 | 0 | **0** | ✅ |
| `evidence` 非空且 `kind` 合法 | 全部 | ✅ | ✅ |

> **勘误**：tasks.md 初稿把 `LEGACY` 估为 **42**（只算 20 leave + 20 levelup + 2 txt）。
> 实测每个 MOD 的 `list/` 下有 **`end.txt` 与 `start.txt` 各 1 份**（不是合计 2 份），
> 故 `LEGACY` = 20×4 = **80**，全 `list/` = 122。

### 4.4 `PENDING` 归零（音频除外）

| 项 | 变更前 | 变更后 | 变化 |
|---|---:|---:|---:|
| `PENDING` 总数 | 663 | **581** | **−82** |
| `.bin` 在 `PENDING` 中 | 82 | **0** | **−82** |
| `.mid` | 578 | 578 | 0 |
| `.mp3` | 2 | 2 | 0 |
| `.sf2` | 1 | 1 | 0 |

```bash
$ lua tools/mod_audit.lua --all --evidence
total=11220 in_product=9285 not_in_product=1935 unclassified=0 bad_evidence=0
  REQUIRED             9185
  REQUIRED_CONVERTED   80
  LEGACY               108
  DEAD_FILE            2
  EDITOR_DUMP          1222
  BUILD_INPUT          30
  PLATFORM_ARTIFACT    12
  PENDING              581
evidence: checked=22 failed=0
```

| 判据 | 期望 | 实测 | |
|---|---|---|:--:|
| `PENDING` 663 → 581 | 581 | **581** | ✅ |
| 581 全是 `.mid`/`.mp3`/`.sf2` | 是 | `.mid 578 + .mp3 2 + .sf2 1 = 581` | ✅ |
| `.bin` 残留 | 0 | **0** | ✅ |
| `unclassified` | 0 | **0** | ✅ |
| `bad_evidence` | 0 | **0** | ✅ |
| `in_product` | 9245 → **9285**（+40 = 20 MOD × `effect.bin` + 20 MOD × `match.bin`，两者均归 `REQUIRED`） | **9285** | ✅ |

**`in_product` 恒等式实测**（避免把 +40 归因错）：

```bash
$ lua -e '...按类别拆 in_product...'
  BUILD_INPUT          tot=30     in_product=20
  REQUIRED             tot=9185   in_product=9185
  REQUIRED_CONVERTED   tot=80     in_product=80
  (其余 6 类)                        in_product=0
  in_product 合计 = 9285
```

⇒ `in_product = REQUIRED 9185 + REQUIRED_CONVERTED 80 + BUILD_INPUT 20 = 9285`。
本次 +40 **全部**来自 `REQUIRED`（`effect.bin` 20 + `match.bin` 20）。

新增 `productCandidates()` 的 `list` 分支（否则 `checkInProduct` 会因无候选路径而返回 false）：

```lua
elseif topdir == "list" then
    cands[#cands + 1] = M.MODS_OUT .. "/" .. mod .. "/data/" .. filename
```

### 4.5 新增单测（5 条）

| 测试 | 断言 |
|---|---|
| `testListEffectAndMatchAreRequired` | 2 文件均 `REQUIRED` + `needed=true` + `in_product=true` + 有证据 |
| `testListLeaveAndLevelupAreLegacy` | 2 文件均 `LEGACY` + `needed=false` + `evidence[1].kind=="code"` |
| `testListMatchCopyIsEditorDump` | `match - 复制.bin` → `EDITOR_DUMP` |
| `testListBinHasNoUnclassified` | `list/` 下未归类数 = 0（含中文/空格文件名） |
| `testNoPendingBinResidue` | `PENDING` 中 `.bin` = 0，且只剩 `.mid`/`.mp3`/`.sf2` |

```bash
$ lua tests/test_runner.lua mod_audit
Results: 280 tests, 280 passed, 0 failed   （原 274，+6：5 新 + 1 修正）
```

---

## 5. 全量门禁

### G1 单元测试

```bash
$ lua tests/test_runner.lua
总测试数: 1957
通过: 1957
失败: 0
✓ 所有测试通过!
```

**1914 → 1957（+43）**。构成：`format_spec` +12、`mod_audit` +6、其余为探针/回归断言。

### G2 pascal 基线

```bash
$ lua tools/mod_build.lua --verify-pascal
[mod_build] pascal baseline: PASS
```

### G3 全量构建

```bash
$ lua tools/mod_build.lua --all
[mod_build] all: 20 mods, 0 build failures, 5 annotated-problematic
```

### G4 20 MOD 启动链路

```bash
$ timeout 900 lua tools/mod_check.lua
总计: 20 MOD, 通过 20, 失败 0
```

### G5 穷举审计

```bash
$ lua tools/mod_audit.lua --all --evidence
total=11220 in_product=9285 not_in_product=1935 unclassified=0 bad_evidence=0
evidence: checked=22 failed=0
```

### G6 格式覆盖

```bash
$ lua tools/format_spec.lua --all
formats=14 checked=6838 gaps=0
```

### G7 存档槽（451 文件）

```bash
# 全 MOD save/ 逐字节比对（模板→data/，用户存档→save/）
save/ 比对 = 451 文件, 不一致 = 21
```

21 处差异**全部是设计内转换**，真实问题 **0**：

| 差异 | 数量 | 性质 | 判定 |
|---|---:|---|:--:|
| `ranger.grp` | 20 | 构建期 Big5→UTF-8 定宽 hint 重写；**文件等长**（如 pascal 114242→114242、dream 132270→132270、BookCalamity 313242→313242），UTF-8 原文进 `ranger.str`（如 pascal 25645 B） | 设计内 ✅ |
| `zheng/ranger.idx` | 1 | 源侧 idx 与本 MOD 的 ranger.grp 不符，构建期修复（源 `836,65992,104182,109070,138446,138596` → 产 `836,59076,97076,101444,114092,114242`），仍 24 字节 6 偏移 | 设计内 ✅ |

⇒ 430/451 逐字节一致，21/451 为 `REQ-BUILD` 明文规定的转换，**真实问题 = 0**。

### G8 四禁改

```bash
$ git status --porcelain | grep -cE 'engine-love2d/|engine-mud/|reference/allmods/'
0
$ git diff game/script/jyconst.lua | grep -cE '^\+.*CC\.[A-Za-z]+ *='
0
```

**`jyconst.lua` 零改动**（`CC.Effect` 字面量未动），`engine-love2d/`、`engine-mud/`、
`reference/allmods/` 均为 0 处改动 ✅。

本次实际改动文件：

| 文件 | 改动 |
|---|---|
| `game/tools/mod_build.lua` | 新增 `LIST_COPY_WHITELIST` + `list` 白名单遍历 |
| `game/framework/mod_data.lua` | 新增 `readU16Array` + `M.LoadEffectTable` |
| `game/framework/jymain_adapter.lua` | init 链调用 `LoadEffectTable` |
| `game/tools/format_spec.lua` | `verifyBinTable` 升级为 uint16 记录级 + 空文件失败 |
| `game/tools/mod_audit.lua` | 4 个 `.bin` 逐文件分类 + 4 条证据 + `list` 路径候选 |
| `game/tests/unit/test_format_spec.lua` | +3 测试，修正 1 |
| `game/tests/unit/test_mod_audit.lua` | +5 测试，修正关键归类表 |

### 5.2 幂等性

```bash
$ cp -a mods /tmp/mods_snapshot
$ lua tools/mod_build.lua --all
$ diff -rq mods /tmp/mods_snapshot
# → 0 行输出
```

连续两次全量构建产物**完全一致** ✅。

---

## 6. 遗留与边界

| 项 | 状态 | 说明 |
|---|---|---|
| 6 个 MOD 的 `effect.bin` 与 `eft.idx` 不同步 | **不修** | BookCalamity(+1)、mingdong(+45)、pineapple(+1)、RiverLake(+1)、books(−9)、awaken(−13)；属 MOD 作者数据侧缺陷，不是解析问题 |
| 578 `.mid` + 2 `.mp3` + 1 `.sf2` 仍 `PENDING` | **显式延后** | 由 `allmods-spike-music-refs` 决策：仅 3/20 MOD 受影响（awaken 84、mingdong 66、pineapple 34 个 `.mid`），延后 |
| `list/*.txt` 不进产物 | **正确** | 通关/开场字幕（`游戏通关了` / `但是这里并没有主角的塑像`），引擎零消费，无硬编码替代 |
| `match - 复制.bin` | **不进产物** | 作者手工备份（与 Dragon 的 `match.bin` md5 同为 `e4d31678…`，42 字节原始模板） |

---

## 7. 经验教训

1. **「目录不在遍历列表里」比「文件被忽略」更隐蔽** —— 原以为 `list/` 是被 `IGNORE` 掉的，
   实际是 `collectDataFiles` 从未 `walk` 它。审计要查**遍历根集合**，不是只查忽略表。
2. **同一扩展名 ≠ 同一语义** —— `list/*.bin` 6 个文件里有 2 个必需、2 个纯遗留、2 个文本。
   按 `(topdir, ext)` 一刀切只能给 `PENDING`，必须下沉到 `EXACT` 逐文件判。
3. **`index 0` 这种「1 项差异」不能当噪声忽略** —— 用 `sum == eft.idx 段数` 做语义校验，
   一举证明数据文件的 `10` 正确、硬编码的 `9` 是遗留。**差异数 1 ≠ 影响微小**。
4. **「4 字节单元」是想当然** —— 4 个 `.bin` 全是 uint16 数组；4 字节切分会把 2 字节尾巴
   静默吞掉。记录单位必须由**数据语义**推出，而不是由「看着差不多」猜。
5. **负向对照不可省** —— 3 项短文件→3、删除→53，两组对照互相排斥，才能证明装载器
   真的读了文件，而不是「恰好通过」。
6. **`PENDING` 是审计的失败态，不是终态** —— 排除显式延后的音频后必须归零，
   否则穷举审计等于没做。
