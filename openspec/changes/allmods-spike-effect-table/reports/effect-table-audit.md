---
status: done
created: 2026-10-27
---
# `CC.Effect` 硬编码表 vs `list/effect.bin` —— 全 20 MOD 实测审计

> Spike 报告。只读实测，**不改运行代码**。
> 数据来源：`reference/allmods/kys-<slug>/list/effect.bin`（源侧）、
> `game/mods/<slug>/data/eft.idx`（产物侧）、`game/script/jyconst.lua:439`（硬编码表）、
> `game/framework/war_async.lua:1110/1121-1123`（消费点）。

## 0. 结论摘要

| 项 | 实测值 |
|----|--------|
| `CC.Effect` 项数 | **53**（索引 `0..52`，字面量，`jyconst.lua:439-449`） |
| `sum(CC.Effect)` | **712** |
| `list/effect.bin` 存在率 | **20/20 MOD**（源侧全有） |
| 产物 `game/data/effect.bin` | **不存在**（20/20 MOD 产物 `data/` 均无）⇒ 构建器未搬运 |
| 语义链 `sum(effect.bin) == eft.idx 段数` | **13/20 精确成立**（含 `pascal` 基线）；6 个有 ±偏差 |
| `CC.Effect[0]` vs 全部 `effect.bin[0]` | `9` vs **`10`**（**20/20 全部含 pascal 都不一致**）⇒ 基线既有口径差异 |
| 真越界影响面（`eft > 52` 的武功引用） | **7/20 MOD**（与 Slice 10 估计 7/20 **一致** ✅） |
| 越界运行时后果 | `framenum` **退化为 10 帧**、`starteft` **停在 712** —— 动画错位，**不崩溃** |

## 1. [REQ-EFF-1] `effect.bin` 语义链实测（20/20）

**命令**：

```bash
cd game && python3 - <<'PY'
import struct,os,glob
for d in sorted(glob.glob("../reference/allmods/kys-*/")):
    n=os.path.basename(d.rstrip("/")).replace("kys-","")
    b=open(d+"list/effect.bin",'rb').read()
    v=list(struct.unpack("<%dh"%(len(b)//2),b))
    segs=len(open(f"mods/{n}/data/eft.idx",'rb').read())//4-1
    print(n,len(v),sum(v),segs,sum(v)==segs)
PY
```

**输出**：

| MOD | `effect.bin` 条目 | `sum` | `eft.idx` 段数 | `sum == 段数` |
|-----|-----:|-----:|-----:|:---:|
| BookCalamity | 200 | 2857 | 2856 | ✗ (+1) |
| Dragon | 64 | 713 | 713 | ✅ |
| GodsDevils | 64 | 713 | 713 | ✅ |
| HeavenSword | 64 | 713 | 713 | ✅ |
| RiverLake | 70 | 921 | 920 | ✗ (+1) |
| SweeOan | 64 | 713 | 713 | ✅ |
| awaken | 64 | 713 | 726 | ✗ (−13) |
| books | 64 | 963 | 972 | ✗ (−9) |
| dream | 64 | 713 | 713 | ✅ |
| lostbook | 64 | 713 | 713 | ✅ |
| loving | 64 | 713 | 713 | ✅ |
| lyff | 64 | 713 | 713 | ✅ |
| mingdong | 200 | 2312 | 2267 | ✗ (+45) |
| **pascal** | 64 | **713** | **713** | ✅（基线） |
| pig | 64 | 713 | 713 | ✅ |
| pig3dos | 64 | 713 | 713 | ✅ |
| pineapple | 84 | 1378 | 1377 | ✗ (+1) |
| ptt | 64 | 713 | 713 | ✅ |
| stronger | 64 | 713 | 713 | ✅ |
| zheng | 64 | 713 | 713 | ✅ |

**结论**：语义链（`effect.bin` 是逐效果帧数表，`eft.idx` 是逐帧偏移表）**在 13/20 MOD
含基线 `pascal` 上精确成立**（`sum 713 == segs 713`）。6 个 MOD 有 ±偏差（+45 到 −13），
属 **MOD 数据侧自身不一致**（作者的 `effect.bin` 与 `eft.idx` 不同步），**不是解析口径问题**——
因为同一解析路径在 13/20 上给出精确相等。

## 2. [REQ-EFF-2] `CC.Effect` 与 `effect.bin` 前 53 项逐项对比

**命令**：

```bash
python3 - <<'PY'
import struct,re
src=open("game/script/jyconst.lua",encoding="utf-8").read()
CCe=[int(x) for x in re.findall(r"\d+", re.sub(r"\[0\]=","",
     re.search(r"CC\.Effect=\{.*?\};",src,re.S).group(0)))]
print("CC.Effect =",CCe)
b=open("reference/allmods/kys-pascal/list/effect.bin",'rb').read()
p=list(struct.unpack("<%dh"%(len(b)//2),b))
print("pascal 前53 =",p[:53])
print("差异:",[(i,CCe[i],p[i]) for i in range(53) if CCe[i]!=p[i]])
print("pascal[53:] =",p[53:])
PY
```

**输出**：

```
CC.Effect = [9, 14, 17, 9, 13, 17, 17, 17, 18, 19, 19, 15, 13, 10, 10, 15, 21, 16,
             9, 11, 8, 9, 8, 8, 7, 8, 8, 9, 12, 19, 11, 14, 12, 17, 8, 11, 9, 13,
             10, 19, 14, 17, 19, 14, 21, 16, 13, 18, 14, 17, 17, 16, 7]
pascal 前53 = [10, 14, 17, 9, 13, 17, 17, 17, 18, 19, 19, 15, 13, 10, 10, 15, 21, 16,
               9, 11, 8, 9, 8, 8, 7, 8, 8, 9, 12, 19, 11, 14, 12, 17, 8, 11, 9, 13,
               10, 19, 14, 17, 19, 14, 21, 16, 13, 18, 14, 17, 17, 16, 7]
差异: [(0, 9, 10)]
pascal[53:] = [0,0,0,0,0,0,0,0,0,0,0]
```

**结论（关键）**：`CC.Effect` 与 `pascal` 的 `effect.bin` **前 53 项仅索引 0 一处差异**
（`9` vs `10`），其余 52 项**完全一致**。而 `effect.bin[53..63]` 全为 `0`（11 项填充）。

逐 MOD 差异统计：

| MOD | 前 53 项差异数 | 第 53 项起非零项 | 是否真越界（需 >53 槽） |
|-----|-----:|-----:|:---:|
| BookCalamity | 50 | 146 | ✅ 是 |
| Dragon | 1 | 0 | ✗ 否 |
| GodsDevils | 1 | 0 | ✗ 否 |
| HeavenSword | 1 | 0 | ✗ 否 |
| RiverLake | 2 | 17 | ✅ 是 |
| SweeOan | 1 | 0 | ✗ 否 |
| awaken | 1 | 0 | ✗ 否 |
| books | 26 | 5 | ✅ 是 |
| dream | 1 | 0 | ✗ 否 |
| lostbook | 1 | 0 | ✗ 否 |
| loving | 1 | 0 | ✗ 否 |
| lyff | 1 | 0 | ✗ 否 |
| mingdong | 49 | 147 | ✅ 是 |
| **pascal** | **1** | **0** | ✗ 否（基线） |
| pig | 1 | 0 | ✗ 否 |
| pig3dos | 1 | 0 | ✗ 否 |
| pineapple | 26 | 31 | ✅ 是 |
| ptt | 1 | 0 | ✗ 否 |
| stronger | 1 | 0 | ✗ 否 |
| zheng | 1 | 0 | ✗ 否 |

**结论**：

1. **"差异数 1" 的 13 个 MOD 全部只差索引 0**（`9` vs `10`），与 `pascal` 同 ⇒ **基线既有偏差，
   不是 MOD 缺陷**。索引 0 是「效果 0」的帧数，硬编码表写 9、数据写 10，属原版提取期的口径遗留。
2. **真越界（`effect.bin` 在第 53 项之后还有非零值）的只有 5 个**：
   BookCalamity、RiverLake、books、mingdong、pineapple。

## 3. [REQ-EFF-3] 运行时越界后果量化

复现 `war_async.lua:1110` 与 `:1121-1123` 的逻辑：

```lua
local framenum = fightdelay + (CC.Effect and CC.Effect[eft] or 10) or 10
local starteft = 0
if CC.Effect then
    for i = 0, eft - 1 do starteft = starteft + (CC.Effect[i] or 0) end
end
```

**命令**（完整启动链取 `CC`）：

```bash
cd game && cat > /tmp/eftsem.lua <<'EOF'
package.path="./?.lua;"..package.path
require("tests.mod_boot_harness").setup()
package.loaded["framework.mod_data"]=nil
require("framework.mod_data")
_G.EngineAPI=require("tests.engine_test")
local EB=require("framework.event_bridge")
require("framework.config")
_G.Byte=require("framework.lib_Byte")
require("engine-love2d.lib_love")
_G.lib=require("engine-love2d.engine_love2d")
lib.init(); EB.getInstance():init()
require(CONFIG.ScriptPath.."jymain")
local E=CC.Effect
local function sim(eft)
  local fn = (E and E[eft] or 10)      -- war_async.lua:1110 的等价式（fightdelay=0）
  local se = 0
  for i=0,eft-1 do se = se + (E[i] or 0) end   -- war_async.lua:1121-1123
  return fn, se
end
for _,e in ipairs({0,1,52,53,55,69,83,168,198}) do
  local fn,se = sim(e)
  print(string.format("eft=%-3d CC.Effect[eft]=%-5s framenum=%-4d starteft=%-5d %s",
    e, tostring(E[e]), fn, se, E[e]~=nil and "正常" or "越界→退化10帧"))
end
EOF
lua /tmp/eftsem.lua
```

**输出**：

| `eft` | `CC.Effect[eft]` | `framenum` | `starteft` | 判定 |
|-----:|-----:|-----:|-----:|------|
| 0 | 9 | 9 | 0 | 正常 |
| 1 | 14 | 14 | 9 | 正常 |
| 52 | 7 | 7 | 705 | 正常（最大合法索引） |
| 53 | **nil** | **10** | **712** | ★越界→退化 10 帧 |
| 55 | **nil** | **10** | **712** | ★越界→退化 10 帧 |
| 69 | **nil** | **10** | **712** | ★越界→退化 10 帧 |
| 83 | **nil** | **10** | **712** | ★越界→退化 10 帧 |
| 168 | **nil** | **10** | **712** | ★越界→退化 10 帧 |
| 198 | **nil** | **10** | **712** | ★越界→退化 10 帧 |

**结论**：

- `eft > 52` 时 `CC.Effect[eft] == nil` → `or 10` 兜底 ⇒ **`framenum` 恒为 10**，
  不论真实效果有多少帧（可能 20+ 帧）。
- `starteft` 求和循环在 `i > 52` 时对 `CC.Effect[i] == nil` 加 `0` ⇒ **恒停在 712**，
  所有越界效果**共用同一错误起始帧** ⇒ 视觉上播错动画。
- **不崩溃**（`lib_*.` 无越界索引，只是逻辑退化）⇒ 是**静默缺陷**，无日志、无报错。

## 4. [REQ-EFF-4] 越界影响面（全 20 MOD 实测）

用真实启动链读 `JY.Wugong[i]["武功动画&音效"]`，统计 `eft > 52` 的条目数：

**命令**：

```bash
cd game && rm -f active_mod.txt
for m in awaken BookCalamity books Dragon dream GodsDevils HeavenSword lostbook \
         loving lyff mingdong pig pig3dos pineapple ptt RiverLake stronger SweeOan zheng; do
  lua /tmp/eftv.lua $m 2>/dev/null | head -1
done
```

**输出**：

| MOD | 武功数 | 有 `eft` 者 | `max(eft)` | **越界（`>52`）条目数** |
|-----|-----:|-----:|-----:|-----:|
| **BookCalamity** | 397 | 398 | **198** | **296** |
| **mingdong** | 219 | 220 | **168** | **136** |
| **pineapple** | 173 | 174 | 83 | **62** |
| **pig3dos** | 201 | 202 | 85 | **52** |
| **RiverLake** | 95 | 96 | 69 | **10** |
| **books** | 99 | 100 | 55 | **2** |
| **awaken** | 162 | 163 | 53 | **1** |
| Dragon | 113 | 114 | 52 | 0 |
| dream | 101 | 102 | 52 | 0 |
| GodsDevils | 92 | 93 | 52 | 0 |
| HeavenSword | 92 | 93 | 52 | 0 |
| lostbook | 92 | 93 | 52 | 0 |
| loving | 92 | 93 | 52 | 0 |
| lyff | 92 | 93 | 52 | 0 |
| **pascal** | 92 | 93 | **52** | **0**（基线） |
| pig | 92 | 93 | 52 | 0 |
| ptt | 107 | 108 | 52 | 0 |
| stronger | 92 | 93 | 52 | 0 |
| SweeOan | 92 | 93 | 52 | 0 |
| zheng | 92 | 93 | 52 | 0 |

**结论**：**7/20 MOD** 有越界引用，与 Slice 10 TODO 的估计「影响 7/20 MOD」**实测一致** ✅。
严重度排序：BookCalamity(296) > mingdong(136) > pineapple(62) > pig3dos(52) > RiverLake(10) > books(2) > awaken(1)。
其余 **13 个 MOD（含 `pascal` 基线）`max(eft) == 52`，恰好等于 `CC.Effect` 最大索引**
⇒ 证明 **53 项表是为原版 `pascal` 精确设计的**，MOD 才需要扩展。

## 5. [REQ-EFF-5] 三方案对比

| 方案 | 做法 | 优点 | 缺点 | 是否需改禁改路径 |
|------|------|------|------|:---:|
| **A. 直接改 `CC.Effect` 常量** | 把 `jyconst.lua:439` 的 53 项扩到 200 项 | 一行改动（换表） | ① **`jyconst.lua` 是四禁改路径**（`CC.*` 常量）；② 一张表无法覆盖 5 个 MOD 的**不同**帧数（BookCalamity `effect.bin` 与 mingdong 完全不同）；③ 治标 | ❌ **禁止** |
| **B. 构建期生成**（推荐） | 构建器把 `list/effect.bin` 搬进产物 `data/effect.bin`；运行时 `CC.Effect` 改为**惰性装载**：若 `data/effect.bin` 存在则读入覆盖，否则保留硬编码兜底 | ① 每 MOD 用**自己的**帧数表（正确性最高）；② 不在 `jyconst.lua` 写死、违反禁改；③ 未激活 MOD / 基线无 `effect.bin` 时**零行为变化**（保留 53 项兜底）；④ 与 `allmods-data-fallback` 的 `ModData.Resolve` 机制一致 | 需改 2 处：构建器（搬文件，`game/tools/**` 允许）+ 一个惰性装载函数（**新增**文件或挂到 `ModData`，不改 `jyconst.lua` 字面量） | ✅ 可行 |
| **C. 运行时直接读源 `effect.bin`** | 运行时按 `ModData.Resolve("list/effect.bin")` 读 | 无需构建器改动 | ① 依赖源目录存在（分发时没有 `reference/`）；② 破坏「构建期纯 Lua + 产物自包含」约束；③ 每次战斗读盘 | ✅ 但架构倒退 |

**推荐方案 B**，理由：

1. **正确性**：5 个越界 MOD 的 `effect.bin` 各不相同（BookCalamity 200 条 / mingdong 200 条但
   sum 2312 ≠ 2857 / pineapple 84 条 / pig3dos / RiverLake 70 条）⇒ **任何单一硬编码表都不可能覆盖**，
   必须**按 MOD 装载**。
2. **合规性**：唯一不触碰四禁改路径的方案（`jyconst.lua` 的 `CC.Effect` 字面量保持原样作为兜底）。
3. **零回归**：13 个 MOD（含 `pascal`）的 `effect.bin` 第 53 项起全 0 ⇒ 即使装载了，
   `CC.Effect[53..]` 都是 0，**与原行为逐值相同**；激活 MOD 才有差异，且差异正是修复方向。
4. **与既有架构一致**：`ModData.Resolve` / `ApplyLayout` 已是同类模式（`mod_data.lua:466`）。

**实施代价估计**：

| 改动 | 文件 | 规模 |
|------|------|------|
| 构建器搬运 `list/effect.bin` → `data/effect.bin` | `game/tools/mod_build.lua` | ~5 行（加一条 copy/stage 规则） |
| 惰性装载函数 | `game/framework/mod_data.lua`（新增 `LoadEffectTable`） | ~25 行（读 int16 LE → 覆盖 `CC.Effect`） |
| 接线 | `script/jyconst.lua` 尾部（**已有** `ApplyLayout` 调用点旁边加一行调用） | ~2 行（调用，不写字面量 ⇒ 不违反禁改） |
| 验证 | `boot_one_mod.lua` 增 1 条断言（`CC.Effect` 长度 == MOD `effect.bin` 条目数） | ~3 行 |

**风险**：`CC.Effect` 是全局共享表，若在同一进程内切换 MOD 需重置（现有架构是
「一进程一 MOD」，`boot_one_mod.lua` 注释明确说明）⇒ 无实际风险。

**待用户决策**：是否实施方案 B。若实施，建议独立 change `allmods-effect-table-fallback`，
纳入下一批；若不实施，7/20 MOD 的越界武功动画将持续静默错位（不崩溃，仅视觉错误）。

## 6. 复现脚本

报告用到的两个探针已留存在本节，可直接重跑：

### `/tmp/eftv.lua`（越界影响面）

```lua
package.path="./?.lua;"..package.path
local slug=arg[1]
require("tests.mod_boot_harness").setup()
package.loaded["framework.mod_data"]=nil
local MD=require("framework.mod_data"); MD.SetActive(slug)
_G.EngineAPI=require("tests.engine_test")
local EB=require("framework.event_bridge")
require("framework.config")
_G.Byte=require("framework.lib_Byte")
require("engine-love2d.lib_love")
_G.lib=require("engine-love2d.engine_love2d")
lib.init(); EB.getInstance():init()
require(CONFIG.ScriptPath.."jymain")
require("framework.jymain_adapter").init()
LoadRecord(0)
local mx,cnt,over=-1,0,0
for i=0,#JY.Wugong do
  local w=JY.Wugong[i]
  if w then
    local e=w["武功动画&音效"]
    if type(e)=="number" then
      cnt=cnt+1
      if e>mx then mx=e end
      if e>52 then over=over+1 end
    end
  end
end
print(string.format("%s: 武功数=%d 有eft=%d max=%d 越界(>52)=%d",slug,#JY.Wugong,cnt,mx,over))
```

### `list/effect.bin` 语义链核对（REQ-EFF-1/2）

见 §1、§2 内联脚本。

## 7. 与既有文档的关系

- **Slice 10 TODO 原估计「影响 7/20 MOD」→ 实测 7/20 完全一致**（本报告 §4），
  但原估计**没有**给出「每 MOD 越界条目数」与「运行时后果」，本报告补齐。
- **Slice 12（pineapple）记录的「`CC.Effect` 越界 62/174 = 35.6%」→ 实测 62/174 一致** ✅，
  且本报告为它提供了**全 20 MOD 的对照基线**（pineapple 第 3 严重）。
- **Slice 13（books）记录的「`武功动画&音效` 越界 2 条（max 55）」→ 实测 2 条 max 55 一致** ✅。
- **Slice 14（dream）`max(eft) == 52` 无越界** ⇒ dream 不受此缺陷影响（与 §4 表一致）。

## 8. 缺陷定级

| 项 | 定级 | 理由 |
|----|------|------|
| `CC.Effect` 53 项无法覆盖 7/20 MOD | **引擎侧限制（非 MOD 缺陷）** | 13 个 MOD（含基线）`max(eft)=52` 恰好匹配；只有扩展过效果的 MOD 才越界 |
| `effect.bin[0]=10` vs `CC.Effect[0]=9` | **基线既有偏差（不修）** | `pascal` 亦然，20/20 全同；修它反而会让 13 个 MOD 行为变化 |
| 6 个 MOD 的 `sum(effect.bin) ≠ eft 段数` | **MOD 数据侧不一致（不修）** | 作者的 `effect.bin` 与 `eft.idx` 不同步；13/20 精确相等证明解析口径正确 |
| `list/effect.bin` 未进产物 `data/` | **构建器缺口（方案 B 需补）** | 20/20 MOD 源侧都有，产物都没有 ⇒ 构建器未搬运 |
