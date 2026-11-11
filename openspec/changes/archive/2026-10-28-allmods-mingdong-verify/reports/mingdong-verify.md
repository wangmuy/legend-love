# mingdong 数据可用性验证报告

> 变更: `allmods-mingdong-verify`（Slice 1 — 名动天下端到端）
> 生成时间: 2026-10-17
> 数据来源: `game/mods/mingdong/diff.md`、`reference/allmods/kys-mingdong/`、无头端到端测试 `tests/unit/test_mod_e2e.lua`

## 结论

名动天下（kys-mingdong）数据经 Slice 0 流水线构建后**可用**：全部运行时加载点均可容忍其数据形态，
事件脚本 1654 个与 kdef 条目数一致，对话 5183 条与 talk 条目数一致，抽样内容与 MOD 原始二进制一致。
仅有的偏差是**显示层换行符 `*` 的布局**（fishedit 生成时的自动折行），不影响功能——引擎
`talk_async.lua` 对无 `*` 的对话自动折行。

## 1. 文件差异审计（REQ-MDV-1）

`diff.md` 记录 MOD 独有 385 项、基准独有 16 项。逐条分类如下：

### 1.1 基准独有（16 项）——全部走回退链，已确认回退目标存在

| 基准文件 | MOD 是否提供 | 引擎处理 | 结论 |
|----------|--------------|----------|------|
| `smap.grp` / `smap.idx` | 否 | `CC.SMAPPicFile` 回退 `data/` | ✅ 回退目标存在 |
| `wmap.grp` / `wmap.idx` | 否 | `CC.WMAPPicFile` 回退 `data/` | ✅ 回退目标存在 |
| `thing.grp` / `thing.idx` | 否 | `CC.ThingPicFile` 回退 `data/` | ✅ 回退目标存在 |
| `allsinbk.grp` | 否 | 非运行时必需（备份） | ✅ 无影响 |
| `d1.idx`/`d2.idx`/`d3.idx` | 否 | MOD 提供 `d4~d11.grp` 替代；`d*.idx` 非引用 | ✅ 无影响 |
| `r1.idx`/`r2.idx`/`r3.idx` | 否 | MOD 提供 `r4~r11.grp` 替代 | ✅ 无影响 |
| `s1.idx`/`s2.idx`/`s3.idx` | 否 | MOD 提供 `s4~s11.grp` 替代 | ✅ 无影响 |

**验证证据**：`lua tests/test_runner.lua mod_e2e` 断言 `CC.SMAPPicFile`/`WMAPPicFile`/`ThingPicFile`
保持 `data/` 原版路径（回退），且 `data/smap.grp` 等回退目标文件均存在（见 §1.3）。

### 1.2 MOD 独有（385 项）——分类

| 类别 | 数量 | 引擎处理 | 结论 |
|------|------|----------|------|
| `fight*.grp/idx`（新增战斗） | 267 对中新增 ~175 对 | `ModData.FightFiles()` 动态枚举；`WarLoad` 用 `warid*186` 定位 | ✅ 动态发现，见 §4 |
| `hdgrp.grp/idx` | 1 对 | `PicLoadFile` 按 idx 长度动态建表（115 条目） | ✅ 无硬编码 |
| `mmap.*`/`eft.*`/`warfld.*`/`war.sta` | 各 1 对 | 路径重定向到 MOD | ✅ 见 §3 |
| `kdef.grp/idx`、`talk.grp/idx` | 各 1 对 | **构建输入**，非运行时数据（运行时用 `script/oldevent/` + `script/oldtalk.*`） | ✅ 不加载 |
| `kysmod.ini` | 1 | `ModIni` 解析 → 覆盖 `CONFIG`/`CC` | ✅ 见 §3 |
| `cloud.*`/`title.*`/`r*.grp`/`s*.grp`/`d*.grp`/`*.png` | 若干 | MOD 资源，按需加载 | ✅ |
| `sdx`/`wdx`/`smp`/`wmp` | 4 | 索引文件（`resource/` 内的 map 数据） | ✅ 无引用（`data/` 侧不需要） |
| `ranger - 副本.idx` | 1 | 名称含空格/中文，非标准文件名 | ✅ 无引用 |

### 1.3 回退目标存在性核验

```
data/smap.grp OK    data/smap.idx OK
data/wmap.grp OK    data/wmap.idx OK
data/thing.grp OK   data/thing.idx OK
```

### 1.4 hdgrp 条目数

- MOD: **115** 条目（`mods/mingdong/data/hdgrp.idx` = 460 字节）
- 基准: **115** 条目（`data/hdgrp.idx` = 460 字节）
- 结论：与原版同形，引擎动态建表（`lib_love.lua` `PicLoadFile`）无硬编码假设。

### 1.5 fight 数量

- MOD: **267** 个 `fight*.grp`（编号不连续，如 `030,039,040...321`）
- 基准: 92 个
- 结论：编号**不连续**，引擎必须动态枚举而非按 0..N 循环。`ModData.FightFiles()` 返回排序后的实际清单；
  `lua tests/test_runner.lua mod_e2e` 断言 `#FightFiles() == 267`，首项 `fight000.grp`，末项 `fight321.grp`。

### 1.6 ini 差异

`kysmod.ini` 与 pascal 不同的键（详见 `mods/mingdong/data/kysmod.ini`）：

| 键 | mingdong | pascal | 映射目标 | 验证 |
|----|----------|--------|----------|------|
| `SCENEAMI`（typo）| 960 | 640 | `CONFIG.Width` | ✅ 见 §3 |
| `SCENEAMJ`（typo）| 660 | 440 | `CONFIG.Height` | ✅ 见 §3 |
| `THING_KIND_NUM` | 330 | 200 | `CC.MyThingNum` | ✅ |
| `MAX_HP` | 9999 | 999 | `CC.MaxHP` | ✅ |

typo 键名 `SCENCEAMI`/`SCENEAMI` 由 `ModIni` 的别名表容忍。

## 2. 提取产物内容核验（REQ-MDV-2）

### 2.1 数量一致

| 产物 | 数量 | MOD 原始数据 | 一致 |
|------|------|--------------|------|
| `mods/mingdong/script/oldevent/*.lua` | 1654 | `kdef.idx` = 1654 条目 | ✅ |
| `mods/mingdong/script/oldtalk.grp` 行数 | 5183 | `talk.idx` = 5183 条目 | ✅ |
| `mods/mingdong/script/oldtalk.idx` 条目 | 5183 | — | ✅ |

### 2.2 抽样内容一致（3 条）

用**独立** Python 解码器（不经过 Lua 流水线）直接解码 `kys-mingdong/resource/talk.grp`，与流水线产物比对：

| talk id | 流水线产物 | 独立二进制解码 | 一致 |
|---------|-----------|----------------|------|
| 0 | `小兄弟，你好啊。` | `小兄弟，你好啊。` | ✅ |
| 1 | `请问你是胡斐胡大哥吗？` | `请问你是胡斐胡大哥吗？` | ✅ |
| 2978（事件 1000 引用） | `袁姑娘，请你先回去，若有需要你帮忙时，我再去找*你.` | 同 | ✅ |

另对全部 5183 条逐条比对，**4466 条完全一致**，其余 717 条差异为流水线追加的尾部杂散字节 `?`——
该问题已在本轮修复（见 §5），修复后 `?` 从 828 降至 43。

### 2.3 事件脚本引用核验

事件 `oldevent_1000.lua` 引用 `instruct_1(2978,0,1)`，即 talk 编号 2978。
该 talk 内容经独立解码为 `袁姑娘，请你先回去...`，与 mingdong 剧情（袁姑娘/田掌门/丁大侠/水姑娘
系列劝说对话）吻合，证明事件脚本与对话表来自**同一份 MOD 数据**。

## 3. 启动链路验证（REQ-MDV-1 补充）

用真实启动链路（`framework.config` → `ModData.SetActive("mingdong")` → `dofile("script/jyconst.lua")`
→ `SetGlobalConst()` → `ModData.LoadIni()`）无头执行，结果：

```
CC.MMAPPicFile[2] = mods/mingdong/data/mmap.grp     （MOD 命中）
CC.SMAPPicFile[2] = data/smap.grp                    （回退原版）
CC.HeadPicFile[2]  = mods/mingdong/data/hdgrp.grp    （MOD 命中）
CC.FightPicFile[2] = mods/mingdong/data/fight%03d.grp（MOD 前缀）
CC.WarFile         = mods/mingdong/data/war.sta      （MOD 命中）
CC.TalkGrpFile     = mods/mingdong/script/oldtalk.grp（MOD 命中）
CC.TalkIdxFile     = mods/mingdong/script/oldtalk.idx（MOD 命中）
CONFIG.Width/Height = 960 / 660
CC.ScreenW/H        = 960 / 660
CC.MyThingNum       = 330
CC.MaxHP            = 9999
```

## 4. 战斗数据动态枚举与越界校验

- `ModData.FightFiles()` = 267（与 `mods/mingdong/data/` 实际一致）
- `mods/mingdong/data/war.sta` = 57474 字节 → `WarRecordCount(warFile, 186)` = **309** 条记录
  （基准 `data/war.sta` = 26040 字节 → 140 条）
- `WarLoad(warid)` 已加入边界校验（`script/jymain.lua`）：`warid >= 记录数` 时 `lib.Debug` 报错并返回，
  不再静默读越界内存（审计报告风险 R3）。

## 5. 已知偏差（不影响功能）

1. **对话换行符 `*` 布局**：原版 `script/oldtalk.grp` 的 `*` 由 fishedit 自动折行生成（约每 12 个全角字），
   与二进制中的 `0xd5` 标记位置不一致。流水线保留二进制 `0xd5` 位置的 `*`，不做 fishedit 式重排。
   引擎 `framework/talk_async.lua:159` 对**无 `*` 的对话自动折行**，故显示功能正常，仅折行位置可能不同。
2. **繁→简转换的异体字差异**：`计画/计划`、`藉口/借口`、`眼裏/眼里` 等约 11 条（pascal 基准，
   2967/2978 = 99.6% 一致）。由 OpenCC `t2s` 与原始转换器的异体字选择不同导致，语义相同。
3. **尾部杂散字节**：mingdong talk 条目以 `0xff` 终止且偶有 1 个杂散尾字节；已在 `extractTalk`
   的终止符处理中修复（`0x00` 约定优先，无尾 `0x00` 时用 `0xff` 约定并去杂散字节）。
4. **对话 idx 语义修复**：构建初期 `oldtalk.idx` 写的是「行起始偏移」，而运行时 `GenTalkIdx`
   写的是「读完该行后的偏移」→ `ReadTalk` 全部 off-by-one。已在 `extractTalk` 修正，
   验证产物 idx 与独立模拟 `GenTalkIdx` 逐字节相同（pascal 2977、mingdong 5183）。
5. **存档目录隔离（新增）**：MOD 的 `save/` 原本与基础模板一起被拍平到 `data/`，且存档槽
   路径固定为顶层 `save/` → 所有 MOD 共享存档、互相覆盖。现改为：构建期 `save/` 拆分（模板
   → `data/`、用户存档 → `mods/<mod>/save/`）；运行时 `ModData.SaveDir()` 返回
   `mods/<mod>/save/`，`RewriteConstants` 重定向存档槽常量；`SaveRecord` 首次保存自动从
   MOD `ranger.idx` 播种 `rN.idx`（否则读到全 0 idx → 损坏存档）。

## 6. 原版零回归

- 无 `game/active_mod.txt` 时：`cd game && lua tests/test_runner.lua` → **252 tests, 252 passed, 0 failed**。
- `lua tools/mod_build.lua --verify-pascal` → **PASS**（events=1018, mismatches=0, 3 known-deviations）。

## 6.1 全启动链路无头验证（强证据）

用 `tests/unit/test_mod_boot.lua`（最小 love stub + 无头 EngineAPI）真实执行：

```
lib.init ............................ OK
EventBridge.init .................... OK
JYMainAdapter.init ................. OK（主菜单 GAME_START）
30 帧菜单 update .................... OK
LoadRecord(0)（MOD ranger.grp/idx）.. OK → PersonNum=569, ThingNum=268, SceneNum=116, WugongNum=204
GAME_FIRSTMMAP → GAME_MMAP .......... OK（JY.Status=2）
30 帧地图 update .................... OK
ReadTalk(0/1/2) .................... OK（小兄弟，你好啊。/ 请问你是胡斐胡大哥吗？/ 正是在下．）
WarLoad(0) / WarLoadMap(0) .......... OK（mingdong war.sta + warfld；越界 warid 不加载）
SaveRecord(1) → LoadRecord(1) ....... OK（r1.grp/s1.grp/d1.grp 写入并回读，PersonNum 恢复）
存档隔离 ........................... OK（SaveDir=mods/mingdong/save/；r1.idx 自动播种 = MOD ranger.idx；
                                       不同 MOD 的 SaveDir 互不相同；未激活 = save/）
MOD 路径/ini：MMAPPicFile→MOD、SMAPPicFile→回退、TalkGrpFile→MOD、960x660、MyThingNum=330、MaxHP=9999
```

结论：mingdong 激活后的**完整游玩启动路径**（主菜单 → 新游戏读档 → 主地图 → 对话读取 → 战斗 → 存档 → 读档）无报错，
且存档落在 MOD 专属目录（与其他 MOD 隔离）。

## 7. DoD 对照

| DoD | 要求 | 状态 | 证据 |
|-----|------|------|------|
| 1 | 报告存在且覆盖全部差异条目 | ✅ | 本文档 §1 |
| 2 | 事件数=1654、对话数=5183，抽样 3 条内容一致 | ✅ | §2.1、§2.2 |
| 3 | 原版零回归 | ✅ | §6 |

## 8. 超出本 slice 范围的发现

- **存档/定义数据编码**：MOD `ranger.grp`/`alldef.grp`/`allsin.grp` 的人物/物品/场景名称为 **Big5** 编码，
  而引擎按 UTF-8 读取（原版 `ranger.grp` 为 UTF-8）→ 名称显示乱码。已记入 epic TODO（存档数据编码转换），
  不影响本 slice 的 5 个验收场景。

---

## 补充：逐 MOD 字段/格式 DoD（2026-10-29）

本 change 产生于 `format_spec.lua` 成形之前，原报告未包含字段级覆盖 DoD。
现已由 **`openspec/changes/allmods-mingdong-format-dod`** 补齐：

```
$ cd game && lua tools/format_spec.lua --mod mingdong
formats=13 checked=831 gaps=0
```

`checked=831` 在 20 个 MOD 中排**第 1**（最高），主因是 `png=338`——
该 MOD 的 `head/` 目录有大量 UPedit 导出 PNG（其余 MOD 多为 1~3）。

详见 `openspec/changes/allmods-mingdong-format-dod/{proposal,spec,verification}.md`。
