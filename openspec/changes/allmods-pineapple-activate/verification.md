---
status: done
created: 2026-10-26
---

# Verification: allmods-pineapple-activate

> 逐条回答 [`specs/allmods-pineapple-activation/spec.md`](specs/allmods-pineapple-activation/spec.md) 的 13 条需求。
> 每条给出**实跑命令 + 真实输出 + 判定**。所有命令工作目录为 `game/`，执行前 `rm -f active_mod.txt`。
> 实测环境：Lua 直跑（无 LÖVE 图形），`mods/pineapple/` 由 `mod_build.lua kys-pineapple` 全新产出。

---

## 0 总览

| REQ | 标题 | 判定 | 关键证据 |
|-----|------|:----:|----------|
| REQ-PIN-1 | 构建产物 | ✅ | `data files=348, saves=30, sound=109, events=1068, talk=3596` |
| REQ-PIN-2 | 穷举审计闭合 | ✅ | `total=529 in_product=484 not_in_product=45 unclassified=0 bad_evidence=0` |
| REQ-PIN-3 | 字节级格式覆盖 | ✅ | `formats=12 checked=289 gaps=0` |
| REQ-PIN-4 | 独立进程启动链路 | ✅ | `RESULT pineapple: OK`，16 PASS / 0 FAIL |
| REQ-PIN-5 | 记录段边界整除 | ✅ | offsets `[1860,132900,198260,204396,228060,228210]`，`720/344/118/174/3` 余 0 |
| REQ-PIN-6 | 内容真实性 | ✅ | 10 个边界值 + 1068 事件 + 3596 对话 + 2764 字段无损坏 |
| REQ-PIN-7 | `kysmod.ini` 生效 | ✅ | 10 项 `nil→有值`，`LifeHurt=10` |
| REQ-PIN-8 | 零字节 fight 三分支 | ✅ | `OK=36 / ZERO_BYTE=115 / FILE_MISSING=0` + 人造 `-1` 三态齐备 |
| REQ-PIN-9 | `CC.Effect` 越界取证 | ✅ | 键 0..52（53 项），max=83，越界 **62 条/28 值**；`framenum 7→10`、`starteft 705→712` |
| REQ-PIN-10 | `icon.png` 无消费者 | ✅ | grep 0 命中，md5 与源一致 |
| REQ-PIN-11 | `name.*` ≠ `talk.*` | ✅ | pineapple 四 md5 两两不同；Dragon 两两相同 |
| REQ-PIN-12 | `ranger.str` hint 去重 | ✅ | 复用 119、真冲突 0；`record=-1` → `""` |
| REQ-PIN-13 | 8 道门禁 | ✅ | 见 §13 |

**结论：13/13 通过，0 缺陷，0 阻塞。**

---

## 1 REQ-PIN-1 构建产物

```bash
$ cd game && rm -f active_mod.txt && lua tools/mod_build.lua kys-pineapple
[mod_build] kys-pineapple: data files=348, saves=30, sound=109, events=1068, talk=3596
[mod_build] diff -> tools/../mods/pineapple/diff.md
```

产物结构实测：

```bash
$ ls mods/pineapple/data | wc -l                   → 348
$ ls mods/pineapple/script/oldevent/*.lua | wc -l  → 1068
$ stat -c '%s' mods/pineapple/script/oldtalk.idx   → 14384
$ stat -c '%s' mods/pineapple/script/oldtalk.grp   → 228575
$ test -f mods/pineapple/diff.md && echo exists    → exists
```

| 项 | 期望 | 实测 |
|----|-----:|-----:|
| `data/` 文件数 | 348 | **348** |
| `save/` | 30 | **30** |
| `sound/` | 109 | **109** |
| `oldevent/*.lua` | 1068 | **1068** |
| `oldtalk.idx` | 14384 | **14384** |
| `oldtalk.grp` | 228575 | **228575** |

**判定：✅ PASS**。构建可重入，重复执行输出逐字相同。

> ⚠ 调用约定：`mod_build.lua` 收**源目录名** `kys-pineapple`（带 `kys-` 前缀）。
> 写成 `--mod pineapple` 会报 `MOD 目录不存在: …/allmods/--mod`。

---

## 2 REQ-PIN-2 穷举审计闭合

```bash
$ cd game && rm -f active_mod.txt && lua tools/mod_audit.lua --mod pineapple --evidence
total=529 in_product=484 not_in_product=45 unclassified=0 bad_evidence=0
  REQUIRED             479
  REQUIRED_CONVERTED   4
  LEGACY               5
  BUILD_INPUT          2
  PENDING              39
evidence: checked=10 failed=0
```

求和闭合：

```
479 + 4 + 5 + 2 + 39 = 529
```

源文件总数：

```bash
$ find ../reference/allmods/kys-pineapple -type f | wc -l
529
```

**判定：✅ PASS**。`Σ(类别) = 529 = 源文件总数`；`unclassified=0`、`bad_evidence=0`、`failed=0`。

> ⚠ 反例：`lua tools/mod_audit.lua pineapple`（位置参数）会**静默审计全部 20 MOD**，
> 输出 `total=11220`。`--mod` 是选项，不是位置参数。

---

## 3 REQ-PIN-3 字节级格式覆盖

```bash
$ cd game && rm -f active_mod.txt && lua tools/format_spec.lua --mod pineapple
formats=12 checked=289 gaps=0
```

**判定：✅ PASS**。`gaps=0` 表示所有被检文件段结构符合规范。

---

## 4 REQ-PIN-4 独立进程启动链路

```bash
$ cd game && rm -f active_mod.txt && lua tests/unit/boot_one_mod.lua pineapple 720 344 118 174 蘿卜大
```

尾部输出：

```
[PASS] 扫描字段数 > 100（实际 2764）
[PASS] 全量字符串无 U+FFFD (期望 0, 实际 0)
[PASS] 全量字符串无控制符 (期望 0, 实际 0)
[PASS] 运行时 10 帧无报错: nil
--------------------------------------------------
RESULT pineapple: OK
```

计数核验：

```bash
$ lua tests/unit/boot_one_mod.lua pineapple 720 344 118 174 蘿卜大 | grep -c "\[PASS\]"   → 16
$ lua tests/unit/boot_one_mod.lua pineapple 720 344 118 174 蘿卜大 | grep -c "\[FAIL\]"   → 0
```

单 MOD 自检：

```bash
$ cd game && rm -f active_mod.txt && MOD_SLUG=pineapple lua tools/mod_check_one.lua
PERSON=720
THING=344
SCENE=118
WUGONG=174
HERO=蘿卜大
STRINGS=OK
EVENTS=OK
SAVE=OK
```

**判定：✅ PASS**。16/16 断言通过。

> ⚠ 调用约定：`boot_one_mod.lua` 的 5 个位置参数是**期望值**。缺省会期望 `nil`，
> 输出 `RESULT pineapple: FAIL (5)` —— 该结果**不可**作为证据。
> `mod_check_one.lua` 读环境变量 `MOD_SLUG`，位置参数会导致 `MOD_SLUG not set`。

---

## 5 REQ-PIN-5 记录段边界整除

```bash
$ cd game && python3 - <<'PY'
import struct
idx = struct.unpack("<6I", open("mods/pineapple/data/ranger.idx","rb").read())
print("offsets:", list(idx))
rc = {"Person":182,"Thing":190,"Scene":52,"Wugong":136,"Shop":50}
for i,n in enumerate(["Person","Thing","Scene","Wugong","Shop"]):
    seg = idx[i+1]-idx[i]
    print(f"{n:7s} seglen={seg:6d} rec={rc[n]:3d} count={seg//rc[n]:4d} rem={seg%rc[n]}")
PY
offsets: [1860, 132900, 198260, 204396, 228060, 228210]
Person  seglen=131040 rec=182 count= 720 rem=0
Thing   seglen= 65360 rec=190 count= 344 rem=0
Scene   seglen=  6136 rec= 52 count= 118 rem=0
Wugong  seglen= 23664 rec=136 count= 174 rem=0
Shop    seglen=   150 rec= 50 count=   3 rem=0
```

`ranger.grp` = 229680B。头部 1860B + 五段 226350B + 尾部 1470B = 229680 ✅

基线对照：

| 段 | 基线 | pineapple | 是否不同 |
|----|-----:|----------:|:--------:|
| Person | 320 | **720** | ✅ |
| Thing | 200 | **344** | ✅ |
| Scene | 84 | **118** | ✅ |
| Wugong | 93 | **174** | ✅ |
| Shop | 3 | 3 | 同 |

**判定：✅ PASS**。五段余数全 0；前四段记录数均异于基线。
但**整除本身不构成内容正确性证据**——见 §6。

---

## 6 REQ-PIN-6 内容真实性（四类直接证据）

### 6.1 边界记录值 + 基线负对照

```bash
$ cd game && rm -f active_mod.txt && lua /tmp/pin_one.lua ""          # 基线
$ cd game && rm -f active_mod.txt && lua /tmp/pin_one.lua pineapple   # pineapple
```

```
基线:      P0=徐小俠|Pn=大鱷魚|PMax=320|T0=醉生夢死酒|Tn=最後|TMax=200|S0=胡斐居|S1=河洛客棧|S2=云鶴崖|Sn=圣堂|SMax=84|W0=普通攻擊|Wn=九陽神功|WMax=93
pineapple: P0=蘿卜大|Pn=|PMax=720|T0=小續命丹|Tn=天書|TMax=344|S0=許昌|S1=兵營|S2=兵營|Sn=暗云蒼穹|SMax=118|W0=普通攻擊|Wn=兌澤化三才|WMax=174
```

| 段 | 索引 | 字段 | 期望 | 实测 | 判定 |
|----|-----:|------|------|------|:----:|
| Person | 0 | 姓名 | 蘿卜大 | **蘿卜大** | ✅ |
| Person | 719 | 姓名 | `""` | **`""`** | ✅（源数据即空格，见 §12.3） |
| Thing | 0 | 名称 | 小續命丹 | **小續命丹** | ✅ |
| Thing | 343 | 名称 | 天書 | **天書** | ✅ |
| Scene | 0 | 名称 | 許昌 | **許昌** | ✅ |
| Scene | 1 | 名称 | 兵營 | **兵營** | ✅ |
| Scene | 2 | 名称 | 兵營 | **兵營** | ✅ |
| Scene | 117 | 名称 | 暗云蒼穹 | **暗云蒼穹** | ✅ |
| Wugong | 0 | 名稱 | 普通攻擊 | **普通攻擊** | ✅ |
| Wugong | 173 | 名稱 | 兌澤化三才 | **兌澤化三才** | ✅ |

**负对照（关键）**：

| 字段 | 基线 | pineapple | 结论 |
|------|------|-----------|------|
| `Scene[0]` | 胡斐居 | **許昌** | 不同 ⇒ 内容来自 MOD |
| `Scene[2]` | 云鶴崖 | **兵營** | 不同 ⇒ 内容来自 MOD |
| `Person[0]` | 徐小俠 | **蘿卜大** | 不同 |
| `Thing[0]` | 醉生夢死酒 | **小續命丹** | 不同 |
| `Wugong[93]` | 九陽神功（末） | — | pineapple 174 段，末为 兌澤化三才 |

> 判据第 5 次应用：**Scene/Thing 内容差异**证明加载的是 MOD 数据，
> 而非「记录数对了就算对」。

> ⚠ 字段名易错点：`Person` / `Thing` / `Scene` 用 **`名称`**，`Wugong` 用 **`名稱`**。
> 用错会静默返回 `nil` 而不报错（本轮踩过一次）。

### 6.2 事件数与构建报告一致

```bash
$ ls mods/pineapple/script/oldevent/*.lua | wc -l   → 1068
```

构建报告 `events=1068` ⇒ **逐字一致** ✅

### 6.3 对话条目可读

```bash
$ python3 -c "
d=open('mods/pineapple/script/oldtalk.grp','rb').read(); l=d.split(b'\n')
print('lines:',len(l)); print('[0]',l[0][:50].decode('utf-8','replace'))
print('[-2]',l[-2][:70].decode('utf-8','replace'))"
lines: 3597
[0] 已经满级了
[-2] 不要打岔，这是送你回去的咒语，一起念，quick*ly！
```

- `oldtalk.idx` = 14384B → **3596** 条目（`14384 / 4`）
- `oldtalk.grp` = 228575B → **3597** 行（含末尾空行）
- 词条数 3596 = 构建报告 `talk=3596` ✅
- 首/末条目均为可读 UTF-8 中文 ✅

### 6.4 全量字符串无损坏

来自 `boot_one_mod.lua`：

```
[PASS] 扫描字段数 > 100（实际 2764）
[PASS] 全量字符串无 U+FFFD (期望 0, 实际 0)
[PASS] 全量字符串无控制符 (期望 0, 实际 0)
```

**判定：✅ PASS**。四类证据齐备且含基线负对照。
仅靠 §5 的记录数整除**无法**排除字段整体错位。

---

## 7 REQ-PIN-7 `kysmod.ini` 生效

```bash
$ cd game && rm -f active_mod.txt && lua /tmp/pin_ini.lua
常量                 基线     pineapple  nil→有值
MaxLevel             nil      99         YES
MaxHP                nil      9999       YES
MaxMP                nil      9999       YES
MaxPhysicalPower     nil      100        YES
MaxItemAmount        nil      456        YES
ItemBeginPic         nil      3753       YES
MaxWeaponMatch       nil      58         YES
MinKnowledge         nil      80         YES
LifeHurt             nil      10         YES
ExpRate              nil      1          YES
MoneyID              174      342
nil→有值 跳变数: 10
```

**判定：✅ PASS**。10 项 `nil → 有值`。

**字段名核验**：`framework/mod_ini.lua:187` 映射 `life_hurt → {"CC","LifeHurt"}`，
故 `CC.LifeHurt = 10` ✅。`CC.LIFE_HURT` 恒为 `nil`，**不可**用作证据。

**`CC.MoneyID` 只作辅助**：基线 `script/jyconst.lua:435` 已定义 `CC.MoneyID=174`，
pineapple 变为 342 属「值变更」而非「`nil→有值`」，不能单独证明 ini 被注入。

---

## 8 REQ-PIN-8 零字节 fight 的三分支降级 ★

### 8.1 规模统计

```bash
$ cd game && python3 - <<'PY'
import os,glob
allf=sorted(glob.glob("mods/pineapple/data/fight*.grp"))
z=[f for f in allf if os.path.getsize(f)==0]
print("fight 总数:", len(allf), " 零字节:", len(z))
nums=sorted(int(os.path.basename(f)[5:8]) for f in z)
print("零字节编号范围:", nums[0], "-", nums[-1])
print("断点:", [(a,b) for a,b in zip(nums,nums[1:]) if b!=a+1])
PY
fight 总数: 154  零字节: 115
零字节编号范围: 16 - 131
断点: [(71, 73)]
```

`fight072` 是区间内**唯一非零例外**（`grp` = 57822B），充当边界负对照。
`fight*.idx` 同为 154 个，其中 115 个 0B —— `.grp` 与 `.idx` 的零字节集合一致。

### 8.2 零字节集合 ⊆ 被引用集合（115/115 全部被引用）

```bash
$ python3 - <<'PY'
import os,glob,struct
d=open("mods/pineapple/data/ranger.grp","rb").read(); o=1860
head=[struct.unpack('<h', d[o+i*182+2:o+i*182+4])[0] for i in range(720)]  # 头像代号 offset=2
used=set(v for v in head if v>0)
zero=set(int(os.path.basename(f)[5:8]) for f in glob.glob("mods/pineapple/data/fight*.grp") if os.path.getsize(f)==0)
print("被引用头像代号:", len(used), " min", min(used), " max", max(used))
print("零字节 ∩ 被引用:", len(zero & used))
print("零字节但未被引用:", sorted(zero-used))
print("被引用但文件缺失(>299):", sorted(c for c in used if c>299))
PY
被引用头像代号: 151  min 1  max 299
零字节 ∩ 被引用: 115
零字节但未被引用: []
被引用但文件缺失(>299): []
```

| 判据 | 值 |
|------|-----:|
| 被引用不同代号 | **151**（min 1, max 299） |
| 零字节 ∩ 被引用 | **115** |
| 零字节 − 被引用 | **0**（∅） |
| 被引用 − 零字节 | **36** |

⇒ **零字节集合 ⊆ 被引用集合**（115 个零字节包全部被引用，无一闲置）。
⇒ 但**不是**「两个集合相等」：被引用集合更大（151），多出的 **36 个是正常 `OK` 包**，
   与 §8.1 三分支实测的 `OK = 36` **精确吻合** —— 两条独立测量互为交叉验证。
⇒ 本 MOD **无 `FILE_MISSING` 实例**（被引用代号全部 ≤299，fight 包全部存在）。

> ⚠ 字段偏移易错点：`Person_S["头像代号"] = {2, 0, 2}`（`jyconst.lua:166`），
> **offset=2** 而非 0。按 offset 0 读会得到 `代号`（1..719、629 个不同值），
> 得出「被引用 629 个」的错误结论。

### 8.3 三分支分类

```bash
$ cd game && rm -f active_mod.txt && lua /tmp/pin_fight4.lua
被引用头像代号数: 151  min: 1  max: 299
  ZERO_BYTE      115
  OK             36
pcall 抛错: 0
  code=  1 ilen=    144 glen=   69516 OK           w=124 h=67
  code= 15 ilen=    224 glen=   55898 OK           w=23  h=47
  code= 16 ilen=      0 glen=       0 ZERO_BYTE    w=0   h=0
  code= 71 ilen=      0 glen=       0 ZERO_BYTE    w=0   h=0
  code= 72 ilen=    144 glen=   57822 OK           w=79  h=60
  code= 73 ilen=      0 glen=       0 ZERO_BYTE    w=0   h=0
  code=131 ilen=      0 glen=       0 ZERO_BYTE    w=0   h=0
  code=132 ilen=    176 glen=   57373 OK           w=41  h=65
  code=299 ilen=    944 glen=  247429 OK           w=23  h=50
  code=400 ilen=     -1 glen=      -1 FILE_MISSING w=0   h=0
  code=719 ilen=     -1 glen=      -1 FILE_MISSING w=0   h=0
```

**边界负对照**（同区间 0B / 非 0B / 0B）：`fight071` 0B、`fight072` 57822B、`fight073` 0B
⇒ 证明「零字节」**不是按编号区间一刀切**。

**`OK` 正对照**：36 个代号全部测出**非零**尺寸（124×67、23×47、79×60、41×65、23×50）
⇒ 证明测量方法本身有效。

**`pcall` 抛错 0**：151 个代号 × (`PicLoadFile` + `PicGetXY`) 全部返回 `true`。

### 8.4 `ZERO_BYTE` 与 `FILE_MISSING` 走不同 code path（决定性证据）

**证据 A：Debug 日志的失败点不同**

```bash
$ echo "--- ZERO ---"; cat /tmp/branch_zero.txt
getPic: mods/pineapple/data/fight016.grp picid=1, idx=0,-1
PicGetXY: pcache is nil!

$ echo "--- MISSING ---"; cat /tmp/branch_missing.txt
getPic: failed to open file mods/pineapple/data/fight500.grp
PicGetXY: pcache is nil!
```

| 分支 | `getPic` 日志 | 对应源码 |
|------|---------------|----------|
| `ZERO_BYTE` | `picid=1, idx=0,-1` | `lib_love.lua:270` `if self.idx[picid]==nil or self.idx[picid+1]==nil then` |
| `FILE_MISSING` | `failed to open file …` | `lib_love.lua:264` `if f == nil then` |

**证据 B：`idx` 表项数直接证明「是否早退」**

```bash
$ cd game && rm -f active_mod.txt && lua /tmp/pin_idxstate.lua
ZERO_BYTE code16     slot=4 idx项数=1   max下标=1   idx[1]=0   idx[2]=nil
OK code1             slot=5 idx项数=37  max下标=37  idx[1]=0   idx[2]=1767
```

| 分支 | `idx` 项数 | 解释 |
|------|-----------:|------|
| `ZERO_BYTE` | **1** | `num = 0/4 = 0` ⇒ `for i=1,num` 不执行 ⇒ 只有 `idx[1]=0` |
| `OK` | **37** | 36 sprites + 1 结束哨兵（`idx[num+2]=grplen`） |
| `FILE_MISSING` | 0（`pic_file` 未填充） | `if idxlen<0 or grplen<0 then return end` 早退 |

⇒ `grplen == 0` 时 `0 < 0` 为**假**，`PicLoadFile` **不早退**，
但 `num=0` 使填表循环空转，失败点因此下沉到 `getPic` 的 `idx[picid+1]==nil`。

### 8.5 Dragon 对照（证明不可类推）

```bash
$ cd game && rm -f active_mod.txt && lua /tmp/drg_branch.lua
Dragon code101 ->	0	0	0	0
$ cat /tmp/branch_dragon.txt
getPic: failed to open file mods/Dragon/data/fight101.grp
PicGetXY: pcache is nil!
```

| | Dragon `fight101` | pineapple `fight016` |
|---|---|---|
| 文件 | **不存在** | **存在但 0 字节** |
| `FileLength` | `-1` | `0` |
| `PicLoadFile` | **早退**（`:435`） | **不早退**，`num=0` |
| `idx` 项数 | 0 | **1** |
| `getPic` 失败点 | `:264` 打开失败 | `:270` 索引缺失 |
| `PicGetXY` | `0,0` | `0,0` |

⇒ **结果相同但路径不同**。Dragon 的结论**不可**套用到 pineapple。

**判定：✅ PASS**。三态（`0` / `>0` / `-1`）齐备，两条 branch 有日志 + `idx` 表双重证据。

> ⚠ 禁止：裸调 `PicGetXY`（未先 `PicLoadFile`）会因 `picFileCache[fileid]` 为 `nil`
> 在 `lib_love.lua:462` 抛 `attempt to index a nil value` —— 属测量方法错误，不可作证据。

---

## 9 REQ-PIN-9 `CC.Effect` 越界取证（只取证不修复）

### 9.1 规模

```bash
$ cd game && rm -f active_mod.txt && lua /tmp/eff6.lua
CC.Effect: 键数=53 范围=0..52  #运算符=52
键连续?	true
Wugong 总数=174 有eft字段=174
越界记录=62 不同越界值=28
越界值列表:	53,54,55,57,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,77,78,79,80,81,82,83
```

`CC.Effect` 源码（`script/jyconst.lua:439-449`）以 `{[0]=9,14,17,...}` 显式给 `[0]` 赋值，
故**真实键范围 0..52 = 53 项**，且键连续、无空洞。

> ⚠ **`#CC.Effect` 返回 52，不能当作项数**。Lua `#` 对「显式 `[0]` + 后续位置项」的表
> 返回边界不确定值（这里是 52），真实项数须用 `pairs` 计数（53）。
> 越界判据因此是 `eft > 52`，**不是** `eft > 51`。
> 本 change 初稿误用 `#` 得「52 项 / 0..51 / 63 条 / 29 值」，已修正为 53 项 / 0..52 / 62 条 / 28 值。

### 9.2 两条运行时路径

为**隔离 `CC.Effect` 自身贡献**，探针取 `fightdelay = 0`（源码中该值来自
`JY.Person[pid]["出招动画延迟"..n]`，实测 `Person[0]` 五个槽位为 7/10/9/9/10，
非固定常数；代入具体人物会污染对照，故归零）。

```bash
$ cd game && rm -f active_mod.txt && lua /tmp/eff4.lua
== A: 隔离 fightdelay=0，只看 CC.Effect 贡献 ==
  eft= 52  CC.Effect[eft]=7     framenum(仅Effect)=7    starteft=705  ok=true/true
  eft= 53  CC.Effect[eft]=nil   framenum(仅Effect)=10   starteft=712  ok=true/true
  eft= 83  CC.Effect[eft]=nil   framenum(仅Effect)=10   starteft=712  ok=true/true
== B: 真实人物 fightdelay 取值（Person[0] 出招动画延迟1..5）==
  出招动画延迟1=7 出招动画帧数1=10
  出招动画延迟2=10 出招动画帧数2=12
  出招动画延迟3=9 出招动画帧数3=11
  出招动画延迟4=9 出招动画帧数4=11
  出招动画延迟5=10 出招动画帧数5=15
```

| 路径 | 源码 | `eft=52`（末有效） | `eft=53`（首个越界） | `eft=83`（最大越界） | 行为 |
|------|------|---------:|---------:|---------:|------|
| `framenum` | `war_async.lua:1109` `fightdelay + (CC.Effect and CC.Effect[eft] or 10) or 10` | **7** | **10** | **10** | 越界 → `or 10` 兜底，帧数由「真实值」变为「默认 10」 |
| `starteft` | `war_async.lua:1126` `for i=0,eft-1 do … + (CC.Effect[i] or 0)` | **705** | **712** | **712** | 越界项贡献 0，累加停在 `sum(CC.Effect[0..52])=712` |

三条 `pcall` 全部 `true` ⇒ **越界不崩溃、不抛错、不越界读内存**（Lua 表读 `nil` 安全），
仅导致两处降级：

1. **特效帧数被夹到默认值** —— 越界武功不再按其真实效果帧数播放，统一退化为 `10` 帧。
2. **起始偏移被夹到全表累加和** —— `starteft` 停在 `712`，
   即所有越界武功的特效帧序号都从同一位置起算，与实际 `eft.grp` 布局无关。

> 注：`eft=53` 与 `eft=83` 结果完全相同（`framenum=10`、`starteft=712`），
> 说明这是**饱和降级**而非线性退化 —— 越界程度不影响最终退化结果。

### 9.3 不修复（明确排除）

修复点在 `game/script/jyconst.lua` 的 `CC.Effect={…}`（**四禁改路径之一**）；
正确修复需从 `list/effect.bin`（pineapple 的 39 个 PENDING 之一）重建，
并把它提升为 REQUIRED，牵动 20 个 MOD 的审计分类 ⇒ 独立 change。

⇒ 归入 epic 级 spike `allmods-effect-table`（与 RiverLake、Dragon 同一条目）。
pineapple 是 7/20 越界 MOD 之一，本次提供**双向实测**（正常值 + 越界值）。

**判定：✅ PASS（取证完成，修复明确排除）**

---

## 10 REQ-PIN-10 `icon.png` 无运行时消费者

```bash
$ cd game && grep -rn "icon\.png" --include=*.lua script/ framework/ engine-love2d/ tests/ | wc -l
0

$ md5sum mods/pineapple/data/icon.png ../reference/allmods/kys-pineapple/resource/icon.png
8e80ebb4a0d3f6149d3e91dd025cb143  mods/pineapple/data/icon.png
8e80ebb4a0d3f6149d3e91dd025cb143  ../reference/allmods/kys-pineapple/resource/icon.png

$ stat -c '%s' mods/pineapple/data/icon.png
9383
```

| 项 | 结果 |
|----|------|
| grep 命中 | **0** |
| 产物 vs 源 md5 | **相同** |
| 大小 | 9383B |
| 归类来源 | `tools/mod_audit.lua:264-269` `BY_KIND`（`resource|.png → REQUIRED`）兜底 |

**与 Dragon 对比**：Dragon 的同类集合为 6 个（`cloud.{grp,idx}`、`title.{grp,idx}`、
`open.png`、`end.png`）；pineapple 多出 `icon.png`，是**第 7 个成员**。

**判定：✅ PASS**。**不因本 change 改判定** —— 改判会改变 20 个 MOD 的
`REQUIRED`/`LEGACY` 计数，需重跑 12 个既有 slice 的审计数字 = 独立 change。

---

## 11 REQ-PIN-11 `name.*` ≠ `talk.*`

```bash
$ cd game && md5sum mods/pineapple/data/name.grp mods/pineapple/data/talk.grp \
    mods/pineapple/data/name.idx mods/pineapple/data/talk.idx
d7ea262bf2a2e5ddfdce8bfd9bd070d3  mods/pineapple/data/name.grp
e2b3cd0585243c555dab401acd958d30  mods/pineapple/data/talk.grp
793bfa542b4a4d294c09939f6220a92c  mods/pineapple/data/name.idx
537355667856c0d5767d236f27bb7129  mods/pineapple/data/talk.idx

$ cd game && md5sum mods/Dragon/data/name.grp mods/Dragon/data/talk.grp \
    mods/Dragon/data/name.idx mods/Dragon/data/talk.idx
4c41c044413860015bd626d480e36951  mods/Dragon/data/name.grp
4c41c044413860015bd626d480e36951  mods/Dragon/data/talk.grp
1a0c74ab1dd84e8714a5b4fd1ed22488  mods/Dragon/data/name.idx
1a0c74ab1dd84e8714a5b4fd1ed22488  mods/Dragon/data/talk.idx
```

| MOD | `name.grp` vs `talk.grp` | `name.idx` vs `talk.idx` | 结论 |
|-----|--------------------------|--------------------------|------|
| **pineapple** | `d7ea262b…` ≠ `e2b3cd05…` | `793bfa54…` ≠ `53735566…` | **非副本** |
| Dragon | `4c41c044…` = `4c41c044…` | `1a0c74ab…` = `1a0c74ab…` | 副本 |

大小也不同：`name.grp` 152082B vs `talk.grp` 152098B。

```bash
$ grep -rn "name\.grp" --include=*.lua script/ framework/ engine-love2d/ | wc -l
0
```

**判定：✅ PASS**。「`name.*` 是 `talk.*` 副本」**只是 Dragon 的个案**，
不是跨 MOD 不变量。两者的共性结论仅为：`name.*` 无 Lua 运行时消费者，审计类别 `LEGACY`。

---

## 12 REQ-PIN-12 `ranger.str` hint 去重不产生语义冲突

### 12.1 复用与真冲突

```bash
$ cd game && python3 - <<'PY'
d=open("mods/pineapple/data/ranger.grp","rb").read(); o=1860
def hint(rec,off,ln=10): return rec[off:off+ln].split(b'\0')[0].decode('ascii','replace')
side={}
for line in open("mods/pineapple/data/ranger.str",encoding="utf-8"):
    if line.startswith("#") or not line.strip(): continue
    p=line.rstrip("\n").split(",",4)
    if len(p)==5: side[(p[1],int(p[0]))]=p[4]
from collections import defaultdict
m=defaultdict(set)
for i in range(720):
    r=d[o+i*182:o+(i+1)*182]
    m[hint(r,8)].add(('Name',i)); m[hint(r,18)].add(('Nick',i))
multi={k:v for k,v in m.items() if len(v)>1}
bad=0
for h,uses in multi.items():
    idx=int(h[1:]); vals={side.get((s,idx),"<<MISSING>>") for s,_ in uses}
    if len(vals)>1: bad+=1
print("复用条目数:", len(multi), " 真冲突数:", bad)
PY
复用条目数: 119  真冲突数: 0
```

`tools/mod_encoding.lua:910-916` 的 `byValue[value]` 去重逻辑：
同值复用同一 index，`report.dedup` 计数 ⇒ 复用是**有意的体积优化**，非缺陷。

### 12.2 `record = -1` 是共享空 hint

```bash
$ head -7 mods/pineapple/data/ranger.str
# ranger.str - MOD side string table (UTF-8)
# format: index,segment,record,field,value
# index is segment-local, matching the hint in ranger.grp
# Person
0000,Person,0,Name,蘿卜大
0001,Person,-1,Nick,
0002,Person,1,Name,關羽
```

`mod_encoding.lua:943-957`：非字符串字段写入**共享空 hint**，
`side.__meta` 标记 `{ rec = -1, field = …, offset = -1, empty = true }`，解析为 `""`。
⇒ 不是索引错误。

### 12.3 `Person[719]` 空名溯源到源数据

```bash
$ cd game && python3 -c "
import struct
s=open('../reference/allmods/kys-pineapple/save/ranger.grp','rb').read()
print('源 Person[719] Name raw:', s[1860+719*182+8:1860+719*182+18].hex())
print('源 Person[0]   Name raw:', s[1860+0*182+8:1860+0*182+18].hex())"
源 Person[719] Name raw: 20000000000000000000
源 Person[0]   Name raw: c5daa452a46a00000000
```

- 源 `Person[719]` 姓名字段 = `0x20`（空格）+ 零填充 ⇒ 转换后空串是**忠实还原**
- 源 `Person[0]` 姓名字段 = Big5 `c5da a452 a46a` = **蘿卜大** ⇒ 与产物一致

`ranger.str` 行数 648 ≠ 记录数 720 —— 因 hint 去重，**hint 数 ≠ 记录数**。

**判定：✅ PASS**。三处「看似异常」均已追溯至设计行为或源数据，**0 缺陷**。

---

## 13 REQ-PIN-13 8 道门禁

| # | 命令 | 实测输出 | 判定 |
|---|------|----------|:----:|
| 1 | `cd game && lua tests/test_runner.lua` | `总测试数: 1842` / `通过: 1842` / `失败: 0` | ✅ |
| 2 | `lua tools/mod_build.lua --verify-pascal` | `pascal baseline: PASS`（`events=1018, mismatches=0, known-deviations=3`） | ✅ |
| 3 | `lua tools/mod_build.lua --all` | `20 mods, 0 build failures, 5 annotated-problematic`；退出码 **1**（设计） | ✅ |
| 4 | `lua tools/mod_check.lua` | `总计: 20 MOD, 通过 20, 失败 0` | ✅ |
| 5 | `lua tools/mod_audit.lua --all --evidence` | `total=11220 in_product=9245 not_in_product=1975 unclassified=0 bad_evidence=0`；`evidence: checked=17 failed=0` | ✅ |
| 6 | `lua tools/format_spec.lua --all` | `formats=12 checked=6773 gaps=0` | ✅ |
| 7 | 门禁 7 脚本（§13.1） | `槽文件=341 模板=110 合计=451` / `真实问题数: 0` | ✅ |
| 8 | 三禁改路径 + `jyconst.lua` | 三处 porcelain 全空；无 `CC.*=` 增删 | ✅ |

### 13.1 门禁 7：按 `isSaveSlotFile` 真实路由

```bash
$ cd game && lua /tmp/gate7.lua
槽文件=341 模板=110 合计=451
真实问题数:	0
```

路由依据 `tools/mod_build.lua:626-631`：

```lua
local function isSaveSlotFile(name)
    local lower = name:lower()
    local base, ext = lower:match("^([rds]%d+)%.([a-z]+)$")
    if not base then return false end
    return ext == "grp" or ext == "idx"
end
```

与 `:665-670`：槽文件 → `mods/<m>/save/`；模板（`ranger.*`/`alldef.*`/`allsin.*`）→ `mods/<m>/data/`。

| 级 | 判据 | 期望 | 实测 |
|----|------|-----:|-----:|
| 1 | 槽文件长度逐字节相等 | 341 | **341**，差异 0 |
| 2 | 模板长度相等 | 110 | **110**，差异 0 |

**真实问题 0** ✅

> ⚠ 两次口径修正：
> 1. 首版脚本用 `name:match("^[rds]%d+%.(grp|idx)$")` —— **Lua 模式不支持 `|` 交替**
>    （`mod_build.lua:625` 原文注释即写明「Lua 模式不支持 `|` 交替，故分开写」），
>    导致 451 个文件全被判为槽文件、误报 341 个「目标缺失」。已按源码真实写法修正。
> 2. 不得笼统宣称「451 文件全等」——`ranger.grp` ×20 经 Big5→UTF-8 转换、
>    `ranger.idx` ×1 由 `RepairIdx` 重建，属**设计内转换**，只能比长度（Slice 11 已修正）。

### 13.2 门禁 8：禁改路径

```bash
$ cd /home/woodfish/project/legend-love && \
    git status --porcelain -- game/engine-love2d game/engine-mud reference/allmods
（空）

$ git diff --stat -- game/script/jyconst.lua
 game/script/jyconst.lua | 12 +++++++++++-
 1 file changed, 11 insertions(+), 1 deletion(-)

$ git diff -U0 -- game/script/jyconst.lua | grep -E "^[+-]\s*CC\.[A-Za-z]+\s*="
（无命中）
```

`jyconst.lua` 的 +11/−1 来自既有 `allmods-data-fallback` 的
`RewriteConstants` / `ApplyLayout` 接线，**不含**任何 `CC.*=` 常量定义行增删 ✅

---

## 14 本 change 内的测量修正汇总

本节记录本轮**修正过的错误结论**。**最终结论均为修正后版本**，且已回写到
`proposal.md` / `design.md` / `spec.md` / `tasks.md`。

| # | 初稿错误 | 实测修正 | 影响位置 |
|---|----------|----------|----------|
| 1 | 零字节 fight「`fight016`~`fight131` 连续 115 个」 | 区间内**唯一例外 `fight072`**（57822B），已作为边界负对照补入 | spec REQ-PIN-8、tasks §8.1/8.3、design ADR-001 |
| 2 | `Person.头像代号` 按 offset **0** 读，得「被引用 629 个」 | 真实 offset = **2**（`jyconst.lua:166`）；被引用 **151** 个，范围 1..299 | §8.2 |
| 3 | 「零字节被引用 98 / 未引用 17」 | 修正后：**零字节 ∩ 被引用 = 115，零字节 − 被引用 = 0**（零字节集 ⊆ 被引用集）；被引用 − 零字节 = **36**（对应 `OK 36`） | §8.2 |
| 4 | 门禁 7 用 `match("^[rds]%d+%.(grp|idx)$")` | Lua 模式**不支持 `|`**；改用真实写法 `match("^([rds]%d+)%.([a-z]+)$")` + `ext` 比较 | §13.1 |
| 5 | 用 `lib.FileLength` 取文件长度 | `FileLength` 是 `lib_love` 的 **local 函数**，未导出；改用 `io.open` + `f:seek("end")` | §8.1 探针 |
| 6 | 直接读 `picFileCache` | `lib_love.lua` 用 `setfenv(1, M)`，须 `require("engine-love2d.lib_love").picFileCache` | §8.4 证据 B |
| 7 | 正对照用 `PicGetXY(4, 5106+代号*8)` | fight 包动画帧 id 用 `0`/`2`；`5106+代号*8` 属 **archive 0（wmap 站位贴图）** | §8.3 |
| 8 | `PicGetXY` 返回值按 `x,y,w,h` 解读 | 实际返回 `w, h, xoff, yoff`（`lib_love.lua:467-468`） | §8.3 |
| 9 | **`CC.Effect` 为 52 项 / 键 0..51 / 越界 63 条 / 29 值** | 真实**键 0..52 = 53 项**（`#` 返回 52 是边界不确定值，须用 `pairs`）；越界判据 `eft>52`，实测 **62 条 / 28 值（53..83）** | §9.1、spec REQ-PIN-9、design ADR-005、proposal、tasks §9 |
| 10 | `framenum` 对照用 `eft=51 → 16`、`starteft → 689` | 末有效值为 `eft=52` ⇒ `framenum=7`、`starteft=705`；越界 `eft=53`/`83` ⇒ `10`/`712`。且探针须令 `fightdelay=0` 才能隔离 `CC.Effect` 贡献（真实值来自人物字段，非常数） | §9.2、design、tasks §9 |
| 11 | `Person[0]` 源 Big5 字节写作 `c3cfb2b7f3a4a7` | 实测 `c5daa452a46a`（解码同为「蘿卜大」） | §12.3 |
| 12 | `mod_check_one` 输出写作单行 | 实际为**逐行** 8 行 | §4 |

> 上述 12 项均为**测量方法/记录精度**层面的修正，不涉及构建产物或引擎行为缺陷。
> 修正后**未发现任何真实缺陷**。

---

## 15 Out of Scope 确认

| 项 | 归属 | 状态 |
|----|------|------|
| `diff.md` 逐项审计 + 报告 | `allmods-pineapple-verify` | 本 slice 下一子 change |
| 修复 `not_in_product` 语义 | 独立 change | 未做（§2 注释记录） |
| 修复 `CC.Effect` 仅 53 项 / 越界 62 条 | 独立 change（`allmods-effect-table` spike） | 未做（§9.3） |
| `icon.png` 改判 `LEGACY` | 独立 change | 未做（§10） |
| 为零字节 fight 生成占位图 | 无（引擎已饱和降级） | 不做（ADR-001） |
| `music/*.mid` / `list/*.bin` | epic 级 spike | 未做 |
| Slice 13（books） | 下一 slice | 未做 |

---

## 16 结论

**REQ-PIN-1 ~ REQ-PIN-13 全部通过（13/13），0 缺陷，0 阻塞。**

本 MOD 的四个独特性均已实证：

1. **115 个零字节 fight 全部被引用** —— 走 `getPic` 索引缺失分支（`idx` 表仅 1 项），
   与 Dragon 的 `PicLoadFile` 一级早退**本质不同**；`fight072`（57822B）为边界负对照。
2. **`Person 720`（全部 20 MOD 中最多）** —— 四类内容证据 + 基线负对照证明字段无错位。
3. **`icon.png` 第 7 个 `BY_KIND` 兜底成员** —— 零运行时消费者，不改判定。
4. **`name.*` ≠ `talk.*`** —— 推翻「副本」跨 MOD 不变量，仅 Dragon 成立。

另：`CC.Effect` 越界在本 MOD 达 **62/174（35.6%）**，属 7/20 越界 MOD 中最严重的一档，
但退化是**饱和**的（`eft=53` 与 `eft=83` 结果相同），不崩溃、不抛错。

**缺陷数：0。** 历史 6 个工具缺陷（A–F）在本 MOD 均未复现或已修复。
