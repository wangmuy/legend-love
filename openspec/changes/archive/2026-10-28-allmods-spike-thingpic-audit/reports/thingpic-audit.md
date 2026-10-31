# Spike 审计报告：物品图渲染链路与数据加载硬编码假设

- **Change**: `allmods-spike-thingpic-audit`
- **Slice**: `allmods-slice0`（Contract B 的前置输入）
- **状态**: 完成（只读审计，无运行代码修改）
- **证据基准**: 当前分支 `love2d-event-driven` 工作树，所有引用均给出 `file:line`

---

## 1. 结论摘要

1. `CC.LoadThingPic=0`（默认值）路径**不读独立的 `thing.grp/idx`**，物品图从「当前已加载的贴图文件缓存 slot 0」取图，索引为 `(item.id + CC.StartThingPic) * 2`。当前 `game/data/` 中原版数据 `CC.StartThingPic=0`，即物品图实际取自 `mmap.grp`/`smap.grp`/`wmap.grp` 的条目区段。
2. 全部数据/贴图/脚本路径都是**构建期在 `jyconst.lua` 里用 `CONFIG.DataPath` 拼好的绝对路径常量**（`CC.*`），不是运行时查询。MOD 数据回退必须在 `SetGlobalConst()` 之后、使用前把 `CC.*` 重定向，或在加载点统一走 `ModData.Resolve`。
3. **无任何条目数硬编码**用于 hdgrp/thing/mmap/smap 的加载（`PicLoadFile` 按 `idx` 文件长度动态建表）。硬编码风险集中在 **fight 文件编号引用**（`CC.FightPicFile` 用 `%03d` 拼接，编号来自人物数据「头像代号」）与 **war.sta 记录数**（无索引文件，靠 `warid * CC.WarDataSize` 定位）。
4. 原版与各 MOD 的 `hdgrp.grp` 条目数不同（114/128/203/266…），但因为 `PicLoadFile` 动态读 `idx`，**不需要改条目数逻辑**；需要保证的是 `hdgrp.idx` 与 `hdgrp.grp` 成对存在（回退链必须成对解析，不能只命中一个）。
5. 遗留风险项（ptt/GodsDevils grp 条目完整性）已用二进制核对：见 §5。

---

## 2. `LoadThingPic=0` 物品图渲染链路（完整调用链）

### 2.1 配置定义

| 项 | 位置 | 值 |
|----|------|-----|
| `CC.LoadThingPic` | `game/script/jyconst.lua:624` | `1`（**默认=1**，读独立 thing.idx/grp） |
| `CC.StartThingPic` | `game/script/jyconst.lua:625` | `0`（物品贴图在 mmap/smap/wmap 中的起始编号，`LoadThingPic=0` 有效） |
| `CC.ThingPicFile` | `game/script/jyconst.lua:122` | `{DataPath.."thing.idx", DataPath.."thing.grp"}` |
| `CC.ThingPicWidth/Height` | `game/script/jyconst.lua:573-574, 586-587` | `40/40` |

> 注：源码注释（`jyconst.lua:624`）写明 `0 从mmap/smap/wmap中读取  1 读取独立的thing.idx/grp`。当前默认 `1`，`=0` 是「物品图内嵌于地图贴图」的路径。

### 2.2 贴图文件缓存 slot 约定

`lib.PicLoadFile(idxfile, grpfile, fileid)`（`game/engine-love2d/lib_love.lua:423`）把 `idx/grp` 载入 `picFileCache[fileid+1]`。全代码库的 slot 分配固定为：

| slot | 文件 | 加载点 |
|------|------|--------|
| 0 | mmap / smap / wmap（按场景切换） | `jymain.lua:371`(mmap), `jymain.lua:486`(smap), `jymain.lua:4367`(wmap), `jymain.lua:4493`(smap), `framework/war_async.lua:79,197` |
| 1 | hdgrp（头像） | `jymain.lua:372,487,4368,4494`；`war_async.lua:80,198` |
| 2 | thing（物品，仅 `LoadThingPic==1`） | `jymain.lua:374,489,4370,4496`；`war_async.lua:82,200` |
| 3 | eft（特效） | `jymain.lua:4372`；`war_async.lua:84` |
| 4 | fightNNN（战斗人物图，按头像代号动态） | `jymain.lua:4383-4384`；`war_async.lua:93-94` |

### 2.3 物品图取图点（`LoadThingPic` 分支）

| 位置 | 分支 | 代码 |
|------|------|------|
| `game/script/jymain.lua:1259-1263` | `==1` | `lib.PicLoadCache(2, thing[id]*2, ...)` |
| `game/script/jymain.lua:1259-1263` | `else (==0)` | `lib.PicLoadCache(0, (thing[id]+CC.StartThingPic)*2, ...)` |
| `game/framework/item_async.lua:310-314` | `==1` | `lib.PicLoadCache(2, item.id*2, ...)` |
| `game/framework/item_async.lua:310-314` | `else (==0)` | `lib.PicLoadCache(0, (item.id+CC.StartThingPic)*2, ...)` |

`lib.PicLoadCache(fileid, picid, ...)`（`lib_love.lua:483`）内部 `picid = floor(picid/2)+1` 后从 `picFileCache[fileid+1]` 取第 `picid` 个条目（`lib_love.lua:497-499`）。因此 `LoadThingPic=0` 时物品图 = slot 0（当前地图贴图）的第 `thing[id]+StartThingPic+1` 个条目。

### 2.4 结论

- `LoadThingPic=0` **不涉及 `thing.grp/idx`**；`thing.grp/idx` 只在 `==1` 时通过 `CC.ThingPicFile` 载入（`jymain.lua:373-374` 等）。
- 因此 MOD 的 `thing.grp/idx` 与 `hdgrp.grp/idx` 对 `==0` 路径**无关**；对 `==1` 路径只需 `ModData.Resolve` 命中该文件。
- 物品图在 `==0` 下依赖「地图贴图条目数 ≥ `item.id + StartThingPic`」，是**数据内容约束**，不是加载代码约束。MOD 若把物品图放进独立 thing.grp，应在 ini/常量层把 `LoadThingPic` 设为 1（见 §4 风险 R2）。

---

## 3. 数据加载侧硬编码假设清单（含 `file:line` 证据）

### 3.1 路径常量（构建期拼好的绝对路径）

全部集中在 `game/script/jyconst.lua` 的 `SetGlobalConst()`（第 60 行起），由 `CONFIG.DataPath/ScriptPath/PicturePath/SoundPath`（`framework/config.lua:41-47`）拼接：

| 常量 | 行 | 文件 |
|------|----|------|
| `CC.R_IDXFilename[0]` | `jyconst.lua:83` | `data/ranger.idx` |
| `CC.R_GRPFilename[0]` | `jyconst.lua:87` | `data/ranger.grp` |
| `CC.S_Filename[0]` | `jyconst.lua:91` | `data/allsin.grp` |
| `CC.D_Filename[0]` | `jyconst.lua:98` | `data/alldef.grp` |
| `CC.PaletteFile` | `jyconst.lua:103` | `data/mmap.col` |
| `CC.FirstFile` / `CC.DeadFile` | `jyconst.lua:105-106` | `pic/title.png` / `pic/dead.png` |
| `CC.MMapFile[1..5]` | `jyconst.lua:108-112` | `data/earth.002`, `surface.002`, `building.002`, `buildx.002`, `buildy.002` |
| `CC.MMAPPicFile` | `jyconst.lua:115` | `data/mmap.idx` + `mmap.grp` |
| `CC.SMAPPicFile` | `jyconst.lua:116` | `data/smap.idx` + `smap.grp` |
| `CC.WMAPPicFile` | `jyconst.lua:117` | `data/wmap.idx` + `wmap.grp` |
| `CC.EffectFile` | `jyconst.lua:118` | `data/eft.idx` + `eft.grp` |
| `CC.FightPicFile` | `jyconst.lua:119` | `data/fight%03d.idx` + `fight%03d.grp`（**编号动态**） |
| `CC.HeadPicFile` | `jyconst.lua:121` | `data/hdgrp.idx` + `hdgrp.grp` |
| `CC.ThingPicFile` | `jyconst.lua:122` | `data/thing.idx` + `thing.grp` |
| `CC.MIDIFile/ATKFile/EFile` | `jyconst.lua:125-127` | `sound/*` |
| `CC.WarFile` | `jyconst.lua:129` | `data/war.sta` |
| `CC.WarMapFile` | `jyconst.lua:130` | `data/warfld.idx` + `warfld.grp` |
| `CC.TalkIdxFile` / `CC.TalkGrpFile` | `jyconst.lua:133-134` | `script/oldtalk.idx` / `oldtalk.grp` |

**改造点**：这些常量必须在 MOD 激活时被重定向到 `mods/<mod>/data/`（存在则用，否则回退 `data/`）。这是 `ModData.Resolve` 的核心消费面。
- **注意**：MOD 包的文件并不都在 `resource/`，`fight/`、`save/` 也是数据来源，拍平阶段须把三者合并到 `mods/<mod>/data/`（见 §4.3.1）。

### 3.2 直接文件加载点（须收敛到 `ModData.Resolve`）

| 加载点 | 位置 | 说明 |
|--------|------|------|
| `PicLoadFile`（mmap） | `script/jymain.lua:371` | 大地图 |
| `PicLoadFile`（hdgrp/thing/eft） | `script/jymain.lua:372-374` | 大地图配套 |
| `PicLoadFile`（smap） | `script/jymain.lua:486-489` | 场景 |
| `PicLoadFile`（wmap+全部） | `script/jymain.lua:4367-4372` | 战斗前 |
| `PicLoadFile`（fightNNN） | `script/jymain.lua:4383-4384` | 战斗人物图（**动态编号**） |
| `PicLoadFile`（smap 战斗内） | `script/jymain.lua:4493-4496` | 战斗内场景 |
| `LoadWarMap` | `script/jymain.lua:4962` | `CC.WarMapFile` |
| `WarLoad` / `Byte.loadfile` | `script/jymain.lua:4344` | `CC.WarFile`，偏移 `warid*CC.WarDataSize` |
| `ReadTalk` / `GenTalkIdx` | `script/jymain.lua:3012-3069` | `CC.TalkIdxFile` / `CC.TalkGrpFile` |
| `oldCallEvent` → `ScriptLoader.load` | `script/jymain.lua:2773-2775` | `CONFIG.OldEventPath .. oldevent_N.lua` |
| `oldCallEvent`（异步版） | `framework/event_executor.lua:71,88` | 同上 |
| `PlayMPEG` | `framework/jymain_adapter.lua:115` | `CONFIG.DataPath .. "start.mpg"` |
| `PicLoadFile`（war_async 全套） | `framework/war_async.lua:79-94,197-200` | 战斗异步版 |

> `Byte.loadfile` 定义与其它 `Byte.*` 文件 IO 收敛点见 `game/framework/lib_Byte.lua`；`FileUtil.open/getInfo` 见 `game/framework/lib_file.lua`。

### 3.3 条目数 / 文件数假设

| 假设 | 位置 | 现状 | 是否需改 |
|------|------|------|----------|
| hdgrp 条目数 | `lib_love.lua:423-452`（`PicLoadFile` 按 `idxlen/4` 动态） | 动态 | **否**（MOD 114→266 自动适配） |
| thing 条目数 | 同上 | 动态 | **否** |
| mmap/smap/wmap 条目数 | 同上 | 动态 | **否** |
| fight 文件编号 | `jyconst.lua:119` `%03d`，编号来自 `JY.Person[pid]["头像代号"]`（`jymain.lua:4383`） | 动态拼接，**无枚举** | **是**（须动态枚举可用 fight 文件集，越界给出明确错误） |
| war.sta 记录数 | `jyconst.lua:492` `CC.WarDataSize=186`；`jymain.lua:4344` `warid*186` | 无索引，靠乘法定位 | **是**（越界需按文件大小校验，MOD war.sta 大小不同） |
| 战斗人物上限 | `jymain.lua:4300` `for i=0,26-1` | 硬编码 26 | 否（与原版一致，非 MOD 差异项） |
| 物品栏容量 | `jyconst.lua:138` `CC.MyThingNum=200` | 常量 | 与 ini `MAX_ITEM_AMOUNT` 关联（见 §4） |
| 队伍人数 | `jyconst.lua:137` `CC.TeamNum=6` | 常量 | 否 |

### 3.4 脚本加载链

| 项 | 位置 | 值 |
|----|------|-----|
| `CONFIG.ScriptPath` | `framework/config.lua:44` | `script/` |
| `CONFIG.OldEventPath` | `framework/config.lua:45` | `script/oldevent/` |
| `CONFIG.NewEventPath` | `framework/config.lua:46` | `script/newevent/` |
| 事件脚本加载 | `script/jymain.lua:2773-2775`、`framework/event_executor.lua:71-95` | `ScriptLoader.load(CONFIG.OldEventPath .. "oldevent_N.lua")` |
| `ScriptLoader.load` | `framework/script_loader.lua:7-20` | 委托 `EngineAPI.script.load`，回退 `loadfile` |

**改造点**：MOD 激活时 `CONFIG.OldEventPath` 须重定向为 `mods/<mod>/script/oldevent/`（或让 `ScriptLoader` 支持 `ModData.ScriptFile` 回退链）。

---

## 4. 需要 `ModData` 收敛的改造清单（供 `allmods-data-fallback` 直接实施）

### 4.1 必须收敛到 `ModData.Resolve` 的加载点

1. `game/script/jyconst.lua:83-134` —— `CC.*` 路径常量。**建议实施方式**：在 `SetGlobalConst()` 末尾调用 `ModData.RewriteConstants(CC, CONFIG)`，对每个 `data/`、`script/` 路径做「MOD 优先 → 回退」重写。这比逐点改调用方更少侵入。
2. `game/framework/jymain_adapter.lua:115` —— `CONFIG.DataPath .. "start.mpg"`。
3. `game/framework/event_executor.lua:88` + `game/script/jymain.lua:2775` —— oldevent 脚本路径（走 `ModData.ScriptFile`）。
4. `game/script/jymain.lua:4383-4384` / `framework/war_async.lua:93-94` —— fightNNN 路径（走 `ModData.FightFiles()` 校验）。
5. `game/script/jymain.lua:4344` —— war.sta 读取前用文件大小校验 `warid*CC.WarDataSize+CC.WarDataSize <= size`。

### 4.2 必须改为动态枚举的点

1. **fight 文件集**：`ModData.FightFiles()` 列出 `mods/<mod>/data/fight*.grp`（无则回退 `data/`）；`jymain.lua:4383`/`war_async.lua:93` 在拼接前校验编号存在，否则报错而非静默加载失败。
2. **war.sta 记录数**：`floor(FileLength(CC.WarFile)/CC.WarDataSize)`，`WarLoad` 入口做边界校验。

### 4.3 无需改动（已动态）

- `PicLoadFile`（`lib_love.lua:423`）按 `idx` 长度建表 → hdgrp/thing/mmap/smap/wmap/eft/fight 的**条目数**全部自动适配。

### 4.3.1 MOD 实际提供的文件集（mingdong 为例，二进制核对）

MOD 包目录结构与 `game/data/` 并非一一对应，回退链覆盖面据此定界：

| 来源目录 | 提供的文件 | 需回退到 `game/data/` 的文件 |
|----------|-----------|------------------------------|
| `resource/` | `mmap.grp/idx`、`hdgrp.grp/idx`、`eft.grp/idx`、`warfld.grp/idx`、`war.sta`、`cloud.grp/idx`、`talk.grp/idx`、`kdef.grp/idx`、`*.002`（earth/surface/building/buildx/buildy）、`mmap.col`、`sdx`/`wdx`/`smp`/`wmp` | **`smap.grp/idx`、`wmap.grp/idx`、`thing.grp/idx`、`allsin*.grp`、`alldef.grp`、`ranger.grp`** |
| `save/` | `alldef.grp/idx`、`allsin.grp/idx`、`ranger.grp/idx`、`d1-d11.grp`、`r1-r11.grp`、`s1-s11.grp` | 覆盖同名的原版角色/定义数据 |
| `fight/` | `fight000.grp/idx` … `fight321.grp/idx`（**267 个**，远多于原版 92 个） | —（MOD 自带全套） |
| `list/` | `effect.bin`、`leave.bin`、`levelup.bin`、`match.bin`、`end.txt`、`start.txt` | 原版无对应 |
| `music/`、`sound/` | MOD 音乐/音效 | — |

> 原版 `game/data/` fight 文件编号**不连续**（`fight000..109`，缺 30、39-42、52、66、72-75、89、103-108，共 **92** 个）。mingdong 的 `fight/` 为 `fight000..321` 中不连续 **267** 个（同样有缺口）。因此 fight 文件集**必须动态枚举**（§4.2.1），任何「连续编号 0..N」假设都会踩空。

### 4.3.2 拍平规则注意（供 build-pipeline）

`resource/` 的文件名大小写/命名与 `game/data/` 不完全一致（例如原版有 `allsinbk.grp`，MOD 无；MOD 有 `cloud.grp/idx`、`sdx/wdx/smp/wmp`、`title.grp/idx`，原版无）。拍平必须**小写归一**并对同名冲突做显式处理（MOD 覆盖原版）。
- `ReadTalk`/`GenTalkIdx`（`jymain.lua:3012-3069`）按 `idx` 大小与 mtime 缓存 → 对话条目数自动适配。

### 4.4 ini 覆盖接入点

`ModIni.Apply` 需在 `SetGlobalConst()` 之后注入，影响面（据 `kysmod.ini` 键）：

| ini 键（段） | 目标 | 现默认 | 备注 |
|--------------|------|--------|------|
| `RESOLUTIONX/Y`（system） | `CONFIG.Width/Height`、`CC.ScreenW/H`（`config.lua:22-23`, `jyconst.lua:77-78`） | 1024x768 | mingdong=960x660 |
| `WALK_speed`/`walk_speed2`（system） | 走路速度常量 | 见 `jymain.lua` | |
| `SCENCEAMI`/`SCENEAMI`（system，**typo**） | 场景动画开关 | | mingdong 拼 `SCENCEAMI`，pascal 拼 `SCENEAMI` |
| `MAX_ITEM_AMOUNT`（constant） | `CC.MyThingNum`（`jyconst.lua:138`） | 200 | mingdong=330 |
| `MAX_HP`/`MAX_MP`（constant） | 生命/内力上限 | | mingdong=9999，pascal=999 |
| `EXP_RATE`（constant） | 经验倍率 | 100 | GodsDevils=4 |
| `ITEM_BEGIN_PIC`/`BEGIN_EVENT`/`BEGIN_SCENCE`/`BEGIN_Sx`/`BEGIN_Sy`/`SOFTSTAR_*`/`MONEY_ID`/`COMPASS_ID`/`BEGIN_LEAVE_EVENT`/`BEGIN_BATTLE_ROLE_PIC`/`MAX_LEVEL`/`MAX_WEAPON_MATCH`/`MIN_KNOWLEDGE`/`LIFE_HURT`/`MaxProList43..58`/`MAX_ADD_PRO`（constant） | 相应 `CC.*` | | 未在 love2d 侧落地的键 → `unknown` |

---

## 5. 风险项结论

### R1 — ptt/GodsDevils 的 grp 条目完整性（探索期遗留项）

**已核对**（二进制读取 `*.idx`，`条目数 = idx文件大小/4`）：

| MOD | hdgrp 条目数 | kdef 条目数 | talk 条目数 |
|-----|-------------|-------------|-------------|
| kys-pascal | 114 | 1018 | 2977 |
| kys-mingdong | 114 | 1654 | 5183 |
| kys-GodsDevils | 128 | — | 4640 |
| kys-ptt | 203 | — | — |
| kys-Dragon | 266 | — | 4020 |

`hdgrp.idx` 与 `hdgrp.grp` 成对存在、最后一个 offset = grp 文件大小 → **条目完整，无截断**。ptt/GodsDevils 无异常。

**结论**：条目数差异是正常的数据差异，`PicLoadFile` 动态适配，**不构成风险**。

### R2 — `LoadThingPic` 与 MOD 物品图数据形态

- 原版 `game/data/thing.grp`（345600 字节）+ `thing.idx`（800 字节 = 200 条目）**存在**，与原版默认 `CC.LoadThingPic=1`（`jyconst.lua:624`）一致 → 原版物品图从 `thing.grp` 正常读取。
- **全部 5 个已核对 MOD（pascal/mingdong/Dragon/GodsDevils/ptt）的 `resource/` 均不含 `thing.grp/idx`**。
- 因此 MOD 激活时 `CC.ThingPicFile`（`data/thing.idx/grp`）在 `mods/<mod>/data/` 无命中 → **必须回退到 `data/thing.grp/idx`**，否则 `PicLoadFile` 在 `FileLength<0` 时静默 return（`lib_love.lua:433`），物品图全部不显示（回归）。这正是 Contract B 回退链必须覆盖的文件之一。
- **风险等级**：低（回退链自动解决）。列为 `REQ-DATA-1` 的必测用例：激活 mingdong 后 `ModData.Resolve("thing.grp")` 必须命中 `data/thing.grp`。

### R3 — war.sta 与 fight 编号越界

- MOD 的 `war.sta` 大小与原版不同（战斗数不同）；`jymain.lua:4344` 无边界校验，越界读取返回空数据 → 战斗逻辑异常。
- `fight%03d` 编号来自人物「头像代号」，MOD 若人物数据引用了不存在的 fight 文件，`PicLoadFile` 静默失败（`lib_love.lua:433-434`）。
- **处置**：`allmods-data-fallback` 在 `WarLoad` 与 fight 拼接处加显式校验并输出 `lib.Debug`/错误（`REQ-DATA-3`）。

---

## 6. 对 `allmods-data-fallback` 的输入契约（定界）

```lua
-- 依据本报告，data-fallback 必须实现并接线的最小集合：
ModData.Active()            -- 读 game/active_mod.txt
ModData.Resolve(filename)   -- mods/<mod>/data/<filename> 存在则用，否则 data/<filename>
ModData.FightFiles()        -- 动态枚举 fight*.grp
ModData.ScriptFile(relpath) -- mods/<mod>/script/<relpath> 存在则用，否则 script/<relpath>
ModData.RewriteConstants(CC, CONFIG)  -- 在 SetGlobalConst() 末尾重写 CC.* 路径（建议实现）
ModIni.Apply(ModIni.Load(ModData.Resolve("kysmod.ini")))  -- ini 覆盖接线
```

**验收对齐**：
- `REQ-DATA-1` ← §4.1.1/§4.1.2/§4.1.3
- `REQ-DATA-2` ← §3.4 + §4.1.3
- `REQ-DATA-3` ← §4.2.1/§4.2.2
- `REQ-DATA-4` ← §4.3（已动态，未激活时路径逐字节不变）

---

## 7. 证据索引（快速定位）

- 物品图分支：`game/script/jymain.lua:1259-1263`、`game/framework/item_async.lua:310-314`
- 贴图缓存机制：`game/engine-love2d/lib_love.lua:423-452`（`PicLoadFile`）、`:483-520`（`PicLoadCache`）
- 路径常量：`game/script/jyconst.lua:83-134`
- 全局配置：`game/framework/config.lua:22-47`
- 事件脚本加载：`game/script/jymain.lua:2773-2775`、`game/framework/event_executor.lua:71-95`
- 对话加载：`game/script/jymain.lua:3012-3069`
- 战斗数据：`game/script/jymain.lua:4344`、`game/script/jyconst.lua:492`
- 脚本加载器：`game/framework/script_loader.lua:7-20`
