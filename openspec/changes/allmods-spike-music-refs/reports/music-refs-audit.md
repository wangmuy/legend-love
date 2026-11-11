---
status: done
created: 2026-10-27
---
# MOD 音乐引用分析（`music/*.mid`）—— 全 20 MOD 实测审计

> Spike 报告。只读实测，**不改运行代码**。
> 数据来源：`reference/allmods/kys-<slug>/music/`（源侧）、`game/sound/*.ogg`（产物侧）、
> 运行时 `JY.Scene[i]["进门音乐"]` 与 `WAR.Data[i]["音乐"]`（真实启动链读取）。

## 0. 结论摘要

| 项 | 实测值 |
|----|--------|
| `.mid` 总文件数 | **578**（20/20 MOD 全有） |
| `.mid` 唯一文件数（按 md5 去重） | **151** |
| 音色库 `.sf2` | **仅 `pascal` 有 1 个** `music/mid.sf2`（其余 19 个 MOD 无） |
| 非 `.mid` 音频 | `pineapple/37.mp3`、`dream/24.mp3`（各 1 个） |
| 产物 `sound/*.ogg` | **25**（引擎 `CC.MIDIFile = sound/game%02d.ogg`） |
| **真正受影响的 MOD** | **3/20**（mingdong / BookCalamity / awaken） |
| 其中「源侧本就缺 `.mid`」 | **1/20**（BookCalamity，20 个被引用 id 无对应文件） |
| 其余 17/20 MOD | 被引用 id 的 `game%02d.ogg` **全部存在** ⇒ **零影响** |

**与 TODO 初稿的关键差异**：初稿断言「20/20 MOD 的 `music/` … 三重不匹配」，
实测 **17/20 MOD 实际零影响**（引用 id 全部 ≤25，产物 ogg 齐全）。真正需要处理的是 **3 个 MOD**，
且其中 BookCalamity 的问题**不是格式转换能解决的**（源侧缺文件）。

## 1. [REQ-MUS-1] `music/` 供给量实测（20/20）

**命令**：

```bash
for d in reference/allmods/kys-*/; do
  n=$(basename $d | sed 's/kys-//')
  c=$(ls "$d/music"/*.mid 2>/dev/null | wc -l)
  sf=$(ls "$d/music"/*.sf2 2>/dev/null | wc -l)
  [ "$c" -gt 0 ] && echo "  $n: $c mid, $sf sf2"
done
```

**输出**（`.mid` 文件数）：

| MOD | `.mid` | `.sf2` |
|-----|-----:|-----:|
| awaken | **84** | 0 |
| mingdong | **66** | 0 |
| pineapple | 34 | 0 |
| BookCalamity | 24 | 0 |
| Dragon | 24 | 0 |
| dream | 24 | 0 |
| GodsDevils | 23 | 0 |
| HeavenSword | 23 | 0 |
| lostbook | 23 | 0 |
| loving | 23 | 0 |
| lyff | 23 | 0 |
| **pascal** | 23 | **1** |
| pig | 23 | 0 |
| pig3dos | 23 | 0 |
| ptt | 23 | 0 |
| RiverLake | 23 | 0 |
| stronger | 23 | 0 |
| SweeOan | 23 | 0 |
| zheng | 23 | 0 |
| books | 23 | 0 |
| **合计** | **578** | 1 |

**去重与编号**：

```bash
python3 -c "
import glob,hashlib
u={hashlib.md5(open(f,'rb').read()).hexdigest() for f in glob.glob('reference/allmods/kys-*/music/*.mid')}
print('唯一 md5:',len(u))"
```

```
唯一 md5: 151
```

**结论**：

- 20/20 MOD **均提供** `.mid`，共 **578** 个文件，按 md5 去重后 **151** 个唯一内容。
- **音色库只 `pascal` 有 `mid.sf2`** —— 其余 19 个 MOD 若要做 MIDI→OGG 转换，
  **必须共享 `pascal` 的 `mid.sf2`**（否则音色不对）。这是重要的工程约束。
- 基线 23 个 `.mid` vs 产物 25 个 `.ogg` ⇒ **原版的 ogg 并非从这 23 个 mid 直接一一转换而来**
  （数量不匹配），说明原版转换时还用了别的音源或做过取舍。

## 2. [REQ-MUS-2] 实际被引用的 MIDI id

`CC.MIDIFile = CONFIG.SoundPath .. "game%02d.ogg"`，`id` 来自 MOD 数据：
`JY.Scene[i]["进门音乐"]`（进场景音乐）与 `WAR.Data[i]["音乐"]`（战斗音乐）。

**命令**（`/tmp/midref.lua`，完整源码见 §6）：

```bash
cd game && rm -f active_mod.txt
for m in pascal mingdong awaken ... ; do lua /tmp/midref.lua $m; done
```

**输出**：

| MOD | 被引用 id 数 | 引用 id 列表 |
|-----|-----:|------|
| mingdong | **43** | 1,2,4,8,9,10,11,12,13,14,15,17,18,20,21,22,23,26,27,28,29,30,31,32,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52 |
| BookCalamity | **35** | 1,2,4,8,9,10,11,12,13,15,17,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,41,42,50,51 |
| awaken | **31** | 1,2,4,8,9,10,11,12,13,15,17,20,21,22,23,24,26,27,31,32,40,44,45,55,57,58,70,71,72,77,81 |
| pig | 18 | — |
| lyff | 18 | — |
| GodsDevils | 17 | — |
| HeavenSword | 16 | — |
| lostbook | 16 | — |
| ptt | 16 | — |
| RiverLake | 16 | — |
| stronger | 16 | — |
| SweeOan | 16 | — |
| zheng | 16 | — |
| **pascal** | **16** | 1,2,4,8,9,10,11,12,13,15,16,17,20,21,22,23 |
| books | 15 | — |
| loving | 15 | — |
| pineapple | 15 | — |
| Dragon | 15 | — |
| dream | 14 | — |
| pig3dos | **4** | — |

**结论**：

- **引用数远少于供给数**：mingdong 供给 66 个 `.mid` 但只引用 **43** 个；
  awaken 供给 84 个只引用 **31** 个；pineapple 供给 34 个只引用 **15** 个。
  ⇒ **不需要转换 MOD 提供的全部 `.mid`**，只需转换**被引用的子集**。
- **最大引用 id**：mingdong 52、BookCalamity 51、awaken 81 ⇒ 需扩展到 **`game81.ogg`**。
- **`pascal` 引用 16 个（1..23 范围内）**，产物有 25 个 ogg ⇒ 基线引用完全覆盖。

## 3. [REQ-MUS-3] 交叉核对：源 `.mid` vs 产物 `.ogg`

**命令**：

```bash
cd game && rm -f active_mod.txt
for m in ...; do
  refs=$(lua /tmp/midref.lua $m | grep -oP '\-> \K.*')
  # 源侧与产物侧逐个核对
done
```

**输出**（全 20 MOD）：

| MOD | `.mid` 文件 | 引用 id | **源缺** | **产物 ogg 缺** |
|-----|-----:|-----:|-----:|-----:|
| **awaken** | 84 | 31 | 0 | **15** |
| **BookCalamity** | 24 | 35 | **20** | **18** |
| books | 23 | 15 | 0 | 0 |
| Dragon | 24 | 15 | 0 | 0 |
| dream | 24 | 14 | 0 | 0 |
| GodsDevils | 23 | 17 | 0 | 0 |
| HeavenSword | 23 | 16 | 0 | 0 |
| lostbook | 23 | 16 | 0 | 0 |
| loving | 23 | 15 | 0 | 0 |
| lyff | 23 | 18 | 0 | 0 |
| **mingdong** | 66 | 43 | 0 | **26** |
| pascal | 23 | 16 | 0 | 0 |
| pig | 23 | 18 | 0 | 0 |
| pig3dos | 23 | 4 | 0 | 0 |
| pineapple | 34 | 15 | 0 | 0 |
| ptt | 23 | 16 | 0 | 0 |
| RiverLake | 23 | 16 | 0 | 0 |
| stronger | 23 | 16 | 0 | 0 |
| SweeOan | 23 | 16 | 0 | 0 |
| zheng | 23 | 16 | 0 | 0 |

**具体缺失 id 清单**：

- **mingdong（26 个，源侧齐全）**：`26,27,28,29,30,31,32,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52`
- **awaken（15 个，源侧齐全）**：`26,27,31,32,40,44,45,55,57,58,70,71,72,77,81`
- **BookCalamity（18 个产物缺 / 其中 20 个源侧也缺）**：
  产物缺 `26,27,28,29,30,31,32,33,34,35,36,37,38,39,41,42,50,51`；
  源侧缺 `24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,41,42,50,51`

**结论**：

- **17/20 MOD 零影响**：被引用 id 全部有对应 `game<dd>.ogg`（都 ≤25）。
- **2/20 MOD 纯粹是「缺转换」**：mingdong、awaken —— 源侧 `.mid` 齐全，只是没转成 ogg。
- **1/20 MOD 是「源侧本就缺」**：BookCalamity 有 20 个被引用 id **连 `.mid` 都没有**
  （作者漏打包），其中 2 个（`24`、`25`）产物侧有 ogg 但源侧无 mid（历史遗留），
  其余 18 个两头都无 ⇒ **转换流水线无法修复**，属 MOD 原始缺陷。

## 4. [REQ-MUS-4] 两类问题分离

| 类别 | MOD 数 | MOD 清单 | 能否用转换流水线修复 |
|------|:---:|------|:---:|
| **A. 需转换**（源 `.mid` 有，产物 `.ogg` 无） | **2** | mingdong（26 个）、awaken（15 个） | ✅ 能 |
| **B. 源侧本就缺 `.mid`**（MOD 原始缺陷） | **1** | BookCalamity（20 个 id 无 mid） | ❌ 不能（无源可转） |
| **C. 零影响**（引用 id 全有 ogg） | **17** | 其余全部（含 `pascal`） | — 无需处理 |

**去重后的实际转换需求**：mingdong 26 个 + awaken 15 个 = **41 个 id**，
两者重叠 **7 个**（`26,27,31,32,40,44,45`）⇒ 按 id 去重后 **34 个唯一 id**：

```
26,27,28,29,30,31,32,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,
55,57,58,70,71,72,77,81
```

且需**按 MOD 分别转换**（同一 id 在不同 MOD 的 `.mid` 内容可能不同）。

**运行时后果**（源码确认）：`lib_love.lua:588` 用 `pcall(love.audio.newSource, ...)` 包裹，
失败时仅 `Debug("PlayMIDI error: ...")`（`:590-592`）**不抛错、不崩溃** ⇒
表现为**该场景/战斗无背景音乐**，静默。

## 5. [REQ-MUS-5] 决策建议

### 方案对比

| 方案 | 做法 | 代价 | 收益 |
|------|------|------|------|
| **A. 不做** | 保持现状：3 个 MOD 部分场景无音乐 | 0 | 游戏可玩，仅缺 BGM |
| **B. 只转 A 类（推荐若要做）** | 对 mingdong/awaken 的 41 个被引用 id 用 `pascal` 的 `mid.sf2` 转 ogg | 中：需外部工具（`timidity`/`fluidsynth`），**破坏「构建期纯 Lua」约束** | 2 个 MOD 的 BGM 完整 |
| **C. 全转 578 个 `.mid`** | 全部转 | 高：578 次转换 + 151 个唯一内容 + 音色一致性校验 | 过度，17/20 MOD 用不到 |
| **D. 运行时直接播 MIDI** | 用 Lua MIDI 播放器 | 很高：需纯 Lua MIDI 合成器 + 音色库加载 | Love2D 无内置 MIDI 支持 |

### 推荐

**建议做方案 B，但降级为「可选增强」而非阻塞项**，理由：

1. **影响面小**：仅 **2/20 MOD**（mingdong、awaken），且都是「缺 BGM」不崩溃。
2. **不阻塞 epic**：17/20 MOD 零影响，`pascal` 基线零影响 ⇒ **MOD 兼容性目标不依赖此项**。
3. **工程约束冲突**：方案 B 需要外部 MIDI 工具（`timidity`/`fluidsynth`），
   与「构建期纯 Lua」的项目约束冲突 ⇒ 必须作为**独立的、可选的构建步骤**，
   不能塞进 `mod_build.lua` 主流程（否则 CI 要装音频工具）。
4. **BookCalamity 无法修复**：20 个 id 源侧无 `.mid` ⇒ 无论做不做转换，
   该 MOD 这 20 个场景都无 BGM。这属 MOD 原始缺陷，应记入文档而非修代码。

### 若实施，最小范围

```
新增可选工具 game/tools/mid2ogg.lua（或 shell 脚本）
  ├─ 输入：reference/allmods/kys-<slug>/music/<id>.mid（仅被引用的 41 个）
  ├─ 音色：reference/allmods/kys-pascal/music/mid.sf2（唯一音色库）
  ├─ 输出：game/mods/<slug>/sound/game<dd>.ogg
  └─ 前置检查：timidity/fluidsynth 存在，否则跳过并打印提示（不失败）
```

**不纳入** `mod_build.lua` 主流程（保持「纯 Lua 构建」）；作为 `tools/` 下的
**可选增强脚本**，由用户按需执行。

**当前建议**：**标记为「已审计，不阻塞，可选实施」**，从 TODO「待决策」移入
「已决策：不做（可选增强）」，理由是本 epic 的目标是 MOD 兼容性（数据/渲染/逻辑），
BGM 缺失不影响该目标，且修复需外部工具链。

## 6. 复现脚本

### `/tmp/midref.lua`（被引用 id 提取）

```lua
package.path="./?.lua;"..package.path
local slug=arg[1]
require("tests.mod_boot_harness").setup()
package.loaded["framework.mod_data"]=nil
require("framework.mod_data").SetActive(slug)
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
local ids={}
local function add(v) if type(v)=="number" and v>0 then ids[v]=(ids[v] or 0)+1 end end
for i=0,#JY.Scene do local s=JY.Scene[i]; if s then add(s["进门音乐"]) end end
for i=0,(WAR and WAR.Data and #WAR.Data or 0) do
  local w=WAR and WAR.Data and WAR.Data[i]; if w then add(w["音乐"]) end
end
local ks={} for k in pairs(ids) do ks[#ks+1]=k end table.sort(ks)
print(string.format("%s: 被引用 MIDI id 数=%d -> %s", slug, #ks, table.concat(ks,",")))
```

### 去重核对

```bash
python3 -c "
import glob,hashlib
u={hashlib.md5(open(f,'rb').read()).hexdigest() for f in glob.glob('reference/allmods/kys-*/music/*.mid')}
print('唯一 md5:',len(u))"
```

## 7. 与 TODO 初稿的差异（修正）

| 初稿断言 | 实测 | 修正 |
|----------|------|------|
| 「20/20 MOD 的 `music/` 提供 66 个 `<NN>.mid`」 | `.mid` 总数 **578**（各 MOD 23~84 个），**无 66 这个数**（66 是 mingdong 一家的数量） | 初稿把 mingdong 的 66 当成全体 |
| 「三重不匹配」暗示全部 MOD 都受影响 | 仅 **3/20** 受影响，**17/20 零影响** | 影响面被大幅高估 |
| 「MOD 66 首 vs 引擎 25 槽」 | 引用 id 最多到 **81**（awaken），需扩展至 `game81.ogg` | 槽位不是"25 槽"限制，而是 id 范围 |
| 「需先确定 MOD 数据实际引用了哪些 id」 | ✅ 本 spike 已给出全部 20 MOD 的引用 id 集合 | 完成 |
| 未区分「源侧缺」与「未转换」 | BookCalamity **20 个 id 源侧就无 `.mid`** | 新增关键区分 |

## 8. 缺陷定级

| 项 | 定级 | 理由 |
|----|------|------|
| mingdong/awaken 缺 41 个 BGM | **构建能力缺口（可选）** | 源侧 `.mid` 齐全，Lua 引擎不做 MIDI 转换 ⇒ 可行但需外部工具 |
| BookCalamity 20 个 id 源侧无 `.mid` | **MOD 原始缺陷（不修）** | 作者漏打包，无源可转；与转换流水线无关 |
| `mid.sf2` 仅 `pascal` 有 | **风险项** | 若做转换，19 个 MOD 必须共享此音色库 ⇒ 单一依赖点 |
| 17/20 MOD 零影响 | **无需处理** | 引用 id 全在 25 个 ogg 范围内 |
