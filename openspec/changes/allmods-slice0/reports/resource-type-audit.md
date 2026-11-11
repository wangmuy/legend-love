---
status: done
created: 2026-04-03
---

# MOD 资源类型审计报告（Q1 + Q2）

> 目标：回答两个问题
> 1. MOD 转换生成的 `oldevent` 脚本内文本是否已是 UTF-8？是否还需把 `oldevent` 内的 Big5 等中文编码再转 UTF-8？
> 2. 除已知资源类型外，这些 MOD 是否有自定义类型（新增 / 遗漏）？

所有结论均由**实际文件字节**、**原版 C 引擎 (`kys.exe`) 字符串表**、**`UPedit.ini` 权威资源注册表**、
以及**引擎运行时常量解析实测**推导得出，非推测。

---

## 一、问题 1：编码（结论：已是 UTF-8，无需二次转换）

### 1.1 扫描范围与结果

| 目标 | 文件数 | 非 UTF-8 | Big5 残留 |
|---|---|---|---|
| 20 个 MOD 的 `mods/<mod>/script/oldevent/*.lua` | **26,790** | **0** | **0** |
| 20 个 MOD 的 `old_talk.lua` + `oldtalk.grp` | 40 | **0** | **0** |
| 原版 `game/script/oldevent/*.lua` | 1,018 | **0** | **0** |
| 原版 `game/script/*.lua` + `newevent/*.lua` | — | **0** | **0** |
| 源 MOD `reference/allmods/kys-*/script/*.lua` | 19 | **0** | **0** |

命令（可复现）：

```bash
cd game && python3 - <<'PY'
import os, glob
bad=0; tot=0
for m in sorted(os.listdir('mods')):
    d=f'mods/{m}/script/oldevent'
    if not os.path.isdir(d): continue
    for f in glob.glob(f'{d}/*.lua'):
        tot+=1
        try: open(f,encoding='utf-8').read()
        except: bad+=1
print(f"oldevent 文件总数={tot} 非UTF-8={bad}")
PY
# => oldevent 文件总数=26790 非UTF-8=0
```

### 1.2 `oldevent` 脚本的本质

`mods/<mod>/script/oldevent/*.lua` **不是对话文本**，而是 `mod_build.lua` 由 `kdef.grp/idx`
反编译生成的**事件指令脚本**，其中中文仅为注释标签（如 `说话: 对话编号2978`、`修改事件定义`、`空语句`）。
真正的对话文本位于 `script/oldtalk.grp`（由 `talk.grp` 构建期转换而来）+ `script/old_talk.lua`（解码表）。

### 1.3 为什么无需二次转换

- **构建期已完成 Big5 → UTF-8**：
  - `talk.grp`（`~big5` 编码）→ `oldtalk.grp`（UTF-8）。
  - `ranger.grp` 字符串字段（Big5）→ 固定宽度 hint + 旁路表 `data/ranger.str`（UTF-8）。
- **`oldevent` 注释由构建器生成**（非复制自源 MOD），天然为 UTF-8。
- **`.idx` 文件为二进制**（uint32 LE 偏移表），"非 UTF-8" 属预期，非缺陷。
- **源 MOD `script/` 内仅 1 个游离 `1.lua`**，且已是 UTF-8。

### 1.4 误报澄清（避免后续误判）

早期宽松扫描曾在 `old_talk.lua` / `oldtalk.grp` 报出 "Big5 对"（BookCalamity 2、GodsDevils 29、
RiverLake 2/3、pig3dos 35、pineapple 5/3、ptt 5、books 1、dream 1）。经**跳过 2 字节 UTF-8 序列**
的严格重扫，命中数归零——这些是**把 UTF-8 多字节序列误读为 Big5 对**的假阳性。

**结论：`oldevent` 及全部构建产物已是合法 UTF-8，0 个 U+FFFD，无需二次 Big5 转换。**

---

## 二、问题 2：资源类型（结论：有 4 类"遗漏"，4 类"自定义"，3 类"编辑器副产物"）

### 2.1 权威来源

| 来源 | 说明 |
|---|---|
| `reference/allmods/kys-pascal/kys.exe` | 原版 C 引擎（`strings` 提取其引用的全部资源路径） |
| `reference/allmods/UPedit/UPedit.ini` | MOD 编辑器权威资源注册表（`[File]` 段） |
| `game/script/jyconst.lua` | Lua 引擎实际读取的 `CC.*File` 常量 |

### 2.2 原版 C 引擎引用清单（`kys.exe` strings）

```
resource/a.png b.png building.002 buildx.002 buildy.002 chinese.ttf cloud.grp cloud.idx
        dead.png d.png earth.002 eft.grp eft.idx end.png eng.ttf hdgrp.grp hdgrp.idx
        kdef.grp kdef.idx l.png mmap.col mmap.grp mmap.idx open.png r.png sdx smp
        surface.002 talk.grp talk.idx title.grp title.idx u.png warfld.grp warfld.idx
        war.sta wdx wmp
fight/fight000   list/{leave,effect,match,levelup}.bin  list/{start,end}.txt
save/ranger.idx  sound/{atk00,e00}  music/mid.sf2
```

**关键：`kys.exe` 从不引用 `name.grp`、`thing.grp`、`allsinbk.grp`、`smap.*`、`wmap.*`。**

### 2.3 Lua 引擎 vs 原版 C 引擎：命名映射

| Lua 引擎（`jyconst.lua`） | 原版 C 引擎（`kys.exe`） | 关系 |
|---|---|---|
| `data/smap.idx` + `smap.grp` | `resource/sdx` + `smp` | **同格式，改名** |
| `data/wmap.idx` + `wmap.grp` | `resource/wdx` + `wmp` | **同格式，改名** |
| `script/oldtalk.idx` + `oldtalk.grp` | `resource/talk.idx` + `talk.grp` | 构建期改名 + 转码 |
| `data/thing.idx` + `thing.grp` | （无） | **Lua 引擎新增**（物品图标 200 项） |
| `data/allsinbk.grp` | （无） | **Lua 引擎新增**（实为未使用参数，见 2.6） |
| `pic/title.png` | `resource/title.grp` + `title.idx` | Lua 改用 PNG |
| `pic/dead.png` / `pic/end.png` | `resource/dead.png` / `end.png` | 路径从 `resource/` 改为 `pic/` |

**实测证据（idx 末值 == grp 大小，格式自洽）**：

| MOD | sdx entries | sdx 末值 | smp 大小 | 一致 |
|---|---|---|---|---|
| kys-pascal | 4368 | 4,349,778 | 4,349,778 | ✓ |
| kys-mingdong | 4635 | 4,501,874 | 4,501,874 | ✓ |
| kys-Dragon | 4644 | 4,655,636 | 4,655,636 | ✓ |

（`wdx`/`wmp` 同理：pascal 3701 项末值 1,966,700 == wmp 大小。）

### 2.4 【遗漏类型 A — 真实缺陷】`sdx/smp` / `wdx/wmp` 未被改名

- **现象**：源 MOD 提供 `resource/sdx`、`smp`、`wdx`、`wmp`（**20/20 MOD 全部提供**）。
  `mod_build.lua` 原样复制到 `data/sdx`、`smp`、`wdx`、`wmp`。
- **引擎需求**：`CC.SMAPPicFile = {data/smap.idx, data/smap.grp}`、`WMAPPicFile = {data/wmap.idx, data/wmap.grp}`。
- **后果**：文件名不匹配 → MOD 的**场景地图 / 战斗地图贴图完全不被读取**，静默回退原版。

**运行时常量解析实测**（激活 `mingdong`）：

```
SMAPPicFile  -> data/smap.idx   ← 原版（MOD 4635 个场景地图丢失）
WMAPPicFile  -> data/wmap.idx   ← 原版（MOD 3850 个战斗地图丢失）
MMAPPicFile  -> mods/mingdong/data/mmap.idx   ✓ MOD
EffectFile   -> mods/mingdong/data/eft.idx    ✓ MOD
HeadPicFile  -> mods/mingdong/data/hdgrp.idx  ✓ MOD
WarMapFile   -> mods/mingdong/data/warfld.idx ✓ MOD
```

**历史误判证据**：前序 change `allmods-data-fallback` 的 DoD 第 2 条把
`data/smap.grp → data/smap.grp`（回退）记录为**通过项**，即 `sdx→smap` 的命名错配**从未被识别为 bug**。

### 2.5 【遗漏类型 B — 真实缺陷】`thing.*` 在源 MOD 中不存在

- **引擎需求**：`CC.ThingPicFile = {data/thing.idx, data/thing.grp}`（200 项物品图标，每项 1728B = 40×40 调色板 RLE）。
- **源 MOD 提供**：**0/20**。源 MOD 只有 `item/*.png`（40×40 **RGB** PNG，编辑器导出），
  与 `thing.grp` 的**调色板 RLE** 格式不同。
- **后果**：全部 MOD 的物品图标均回退原版 `data/thing.grp`。

**实测**：

```
thing.idx: 200 项，每项 1728B，首项头 28 00 28 00 = 40×40  ✓ 与 item/0.png 尺寸一致
item/0.png: 40×40 RGB PNG（编辑器导出）
```

### 2.6 【遗漏类型 C — 无害】`allsinbk.grp` 在源 MOD 中不存在

- **引擎声明**：`CC.TempS_Filename = data/allsinbk.grp`，作为 `LoadSMap` 的 `tmpfilename` 参数。
- **实测**：`lib_love.lua:890 LoadSMap(Sfilename, tmpfilename, ...)` 中 `tmpfilename`
  **在整个函数体内 0 次引用**（纯遗留参数）。
- **结论**：源 MOD 0/20 提供 `allsinbk.grp` **无害**，引擎不会读取它。

### 2.7 【遗漏类型 D — 真实缺陷】`sound/` 未复制、`music/` 格式不兼容

- **源 MOD 提供**：
  - `sound/`：**201 个 wav**（26 个 `atk*.wav` + 175 个 `e*.wav`），与引擎的
    `atk%02d.wav` / `e%02d.wav` 命名**完全吻合**，其中 **123 个为 MOD 独有**。
  - `music/`：**66 个 `<NN>.mid`**（C 引擎 MIDI + `music/mid.sf2` 音色库）。
- **`mod_build.lua` 只 walk `resource/`、`fight/`、`save/`** → 音频**零复制**
  （`grep -n "sound\|music\|\.wav\|\.ogg\|\.mid" game/tools/mod_build.lua` 无任何匹配）。
- **`ModData.rewrite` 只重写 `data/` 与 `script/` 前缀** → `sound/`、`pic/` 无 MOD 回退链。
- **实测**：`game/mods/mingdong/` 下无 `sound/`、无 `music/`、`data/` 内无任何 `.wav`/`.ogg`。
- **后果（两部分）**：
  1. **`sound/`**：MOD 独有音效无法播放；78 个同名文件中 **25/50 的 md5 与原版不同**
     （MOD 定制音效被原版覆盖）。→ **只需构建期复制 + `SoundPath` 回退链即可修复**。
  2. **`music/`**：格式不兼容——MOD 为 `.mid`（C 引擎 + `mid.sf2` 音色库），
     而 Lua 引擎期望 `sound/game%02d.ogg`（原版仅 25 个 ogg，MOD 有 66 个 mid）。
     → **需要格式转换（MIDI→OGG）而非单纯复制**，工作量更大。

### 2.8 【自定义类型 1 — 无害】`name.grp` + `name.idx`

- **出现于 4 个 MOD**：BookCalamity、Dragon、pineapple、RiverLake（**不是** `books`；
  前序 `TODO.md` 的记录有误，已需更正）。
- **格式**：与 `talk` 同构（idx uint32 偏移表 + `~big5` 文本），条目数：
  | MOD | name.idx | talk.idx | 说明 |
  |---|---|---|---|
  | Dragon | 4020 | 4020 | 完全相同的副本（md5 一致） |
  | pineapple | 3596 | 3596 | 同条目数，内容不同 |
  | RiverLake | 8015 | 8015 | 同条目数，内容不同 |
  | BookCalamity | 4020 | 5967 | 条目数不同 |
- **`kys.exe` 从不引用 `name.grp`**；`UPedit.ini` 将其登记为「人名文件」（编辑器用）。
- **引擎读人名来源**：`JY.Person[i]["姓名"]`（即 `ranger.grp`），非 `name.grp`。
- **结论**：`name.grp` 是 **C 引擎 / 编辑器遗留资源**，Lua 引擎无需读取。构建期原样复制到 `data/name.grp`，无害。

### 2.9 【自定义类型 2 — 死文件】awaken 的 `fightNNN..grp` / `fightNNN_02.grp`

- **`kys-awaken` 独有**：`fight000..grp`（双点）等 8 组、`fight030_02.grp` 等 9 组。
- **实测**：与同名正常文件的**大小相同但 md5 不同**（是不同角色的备用动画，作者用错名保存）。
- **引擎读取方式**：`string.format(CC.FightPicFile[2], JY.Person[pid]["头像代号"])` → `fight%03d.grp`。
  3 位数字格式**永远无法生成** `fight000..grp` 或 `fight030_02.grp`。
- **结论**：这些文件**永远不可达**（死文件）。构建期原样复制，无害。

### 2.10 【自定义类型 3 — 死文件】dream 的 `new.idx` / `fight23.idx`

- **`new.idx`**：大小 18285B = `kdef.idx`(18276B) + 9 字节垃圾；前 18276 字节与 `kdef.idx` **逐字节相同**；
  **无 `new.grp`**。→ `kdef.idx` 的损坏备份，引擎不引用。
- **`fight23.idx`**（128B，2001年）与正常 `fight023.idx`（144B，2006年）**并存**；
  引擎只生成 3 位格式 `fight023.idx` → `fight23.idx` 不可达。
- **结论**：均为死文件，无害。

### 2.11 【自定义类型 4 — 死文件】Dragon 的 `war1.sta`

- 与 `war.sta` 并存（66030B vs 42222B，不同内容）。
- 引擎只读 `CC.WarFile = data/war.sta`；`kys.exe` 亦只引用 `resource/war.sta`。
- **结论**：`war1.sta` 不可达，死文件。

### 2.12 【编辑器副产物 — 正确忽略】`head/`、`item/`、`eft/`、`cc/`

| 目录 | 出现 MOD | 内容 | 判定 |
|---|---|---|---|
| `head/` | Dragon(220)、GodsDevils(79)、mingdong(335)、pascal(79) | `hdgrp` 头像的 PNG 转储：标准 MOD 固定画布 **60×62**（对应 `hdgrp` 首项 56×58 + 4px 边距），mingdong 为 **86×89**（其头像更大）；同一 MOD 内画布统一，非逐项直拷 | 编辑器副产物，`IGNORE_DIRS` 正确忽略 |
| `item/` | GodsDevils(200)、pascal(200) | 物品图标 PNG 转储（40×40 RGB，与 `thing.grp` 首项头一致） | 同上 |
| `eft/` | ptt(105) | `eft.grp` 的编辑器导出：`eftNNN.idx`（5 个 uint32 = 5 个方向的帧数，**首值 == `CC.Effect[NNN]`**，已实测 eft001=14==CC.Effect[1]）+ `eftNNN.png`（拼接精灵图，如 eft001 为 2156×90） | 编辑器副产物，`IGNORE_DIRS` 正确忽略 |
| `cc/` | pascal(4 文件) | OpenCC 简繁词典（`STCharacters.txt` 等） | MOD 启动器配置，非引擎资源 |

`mod_build.lua:560` 的 `IGNORE_DIRS = { head = true, item = true, eft = true }` **判定正确**。
`cc/` 因不在 walk 范围内（顶层非 `resource/fight/save`）自然未复制。

### 2.13 【Lua 引擎不读】`list/`、`kysmod.ini` 中部分常量

- `list/{leave,effect,match,levelup}.bin` + `list/{start,end}.txt`：**仅 C 引擎**引用
  （`kys.exe` strings 可见），Lua 引擎无任何读取代码。
- `CC.ItemBeginPic`（`ITEM_BEGIN_PIC`，值 2001~5720）：`mod_ini.lua` 会解析进 `CC`，
  但**Lua 引擎从不使用**（hdgrp 仅 115~412 项，值远超范围，证明它索引的是 `thing.grp` 空间，
  而 Lua 引擎直接以 0..199 索引 `thing.grp`）。
- `CC.HeadpicName = resource/Heads.pic`：`UPedit.ini` 登记，但**全 20 MOD 均无 `Heads.pic`**，
  且 Lua 引擎不引用。

### 2.14 顶层杂项文件

| 文件 | MOD | 是否复制 | 判定 |
|---|---|---|---|
| `kysmod.ini` | 20/20 | ✓（构建期解析） | 必需 |
| `111.txt` / `111.xlsx` | awaken | ✗ | 作者草稿 |
| `SDL3.dll` / `kys.exe` / `lua52.dll` 等 | pascal | ✗ | C 引擎运行时 |

---

## 三、结论汇总

### 问题 1 结论

**MOD 转换生成的 `oldevent` 脚本（及 `old_talk.lua` / `oldtalk.grp`）内文本已是合法 UTF-8，
0 个 U+FFFD，0 个 Big5 残留。无需再对 `oldevent` 做任何中文编码转换。**
（`oldtalk.idx` 等 `.idx` 为二进制偏移表，"非 UTF-8" 属预期。）

### 问题 2 结论

**除已知资源类型外，确实存在自定义与遗漏类型。经 `allmods-slice0b` 三个子 change 处理后，
全部条目已有明确最终处置（含一个对原审计的修正）。**

| 类别 | 资源 | 涉及 MOD | 影响 | 最终处置 |
|---|---|---|---|---|
| **A. 遗漏（真实缺陷）** | `sdx/smp`、`wdx/wmp` 未改名为 `smap.*`/`wmap.*` | **20/20** | 场景/战斗地图贴图静默回退原版 | **✓ 已修复** — `allmods-slice0b-smap-rename`（构建期 `ALIAS_MAP`） |
| **B. 遗漏（原判为缺陷 → 修正为设计性回退）** | `thing.idx/grp` 源 MOD 不存在 | **20/20** | 物品图标回退原版 | **✓ 设计性回退** — 引擎 `CC.ThingPicFile` 回退原版是预期行为；**不从 `item/*.png` 派生**（`allmods-slice0b-resource-classify` 固化断言） |
| **C. 遗漏（无害）** | `allsinbk.grp` 源 MOD 不存在 | 20/20 | 无（`tmpfilename` 未被使用） | **✓ 死参数** — `LoadSMap` 函数体内 0 引用；断言固化 |
| **D. 遗漏（真实缺陷）** | `sound/`（201 wav）未复制 | 20/20 | MOD 音效无法播放；同名音效被原版覆盖（mingdong 52/78 内容不同） | **✓ 已修复** — `allmods-slice0b-sound-fallback`（构建期复制 + `CC.ATKFile`/`EFile` 前缀回退） |
| **D'. 遗漏（待决策）** | `music/`（66 mid）未复制且格式不兼容 | 20/20 | MOD 音乐无法播放 | **⏳ PENDING** — 需 MIDI→OGG 转换（外部工具）+ 槽位映射（66 vs 25）；已记录为 epic TODO spike 条目 |
| 1. 自定义（无害） | `name.grp/idx` | BookCalamity、Dragon、pineapple、RiverLake | 无（C 引擎/编辑器遗留） | **✓ 遗留资源** — 引擎从不读取；断言固化 |
| 2. 自定义（死文件） | `fightNNN..grp`、`fightNNN_02.grp` | awaken | 无（不可达） | **✓ 死文件** — `%03d` 生成不出这些名；保留忠实拷贝 + 断言固化 |
| 3. 自定义（死文件） | `new.idx`、`fight23.idx` | dream | 无（不可达） | **✓ 死文件** — 同上 |
| 4. 自定义（死文件） | `war1.sta` | Dragon | 无（不可达） | **✓ 死文件** — 引擎只读 `war.sta`；断言固化 |
| 编辑器副产物 | `head/`、`item/`、`eft/`、`cc/` | 4/2/1/1 | 无（`IGNORE_DIRS` 正确忽略） | **✓ 编辑器副产物** — `IGNORE_DIRS` 正确；断言固化 |

**分类判定对照表**（`allmods-slice0b-resource-classify` Contract C）：

| 分类 | 含义 | 对应条目 |
|------|------|---------|
| `REQUIRED` | 引擎必需，源 MOD 应提供 | A、D |
| `DESIGNED_FALLBACK` | 源 MOD 不提供是预期，引擎回退原版 | B |
| `DEAD_PARAM` | 形参从未被引用 | C |
| `LEGACY` | C 引擎/编辑器遗留，Lua 引擎不读 | 1 |
| `DEAD_FILE` | 引擎命名规则无法生成，永不可达 | 2、3、4 |
| `EDITOR_DUMP` | 编辑器导出副产物，不复制 | head/item/eft/cc |
| `PENDING` | 待决策（需 spike） | D' |

### 对原审计的修正

原审计把 **B（`thing.*`）** 列为「遗漏（真实缺陷）→ 需补建」，**这是错误的**：

- 源 MOD **0/20** 提供 `thing.idx`/`thing.grp`；
- 引擎 `CC.ThingPicFile` 指向 `data/thing.*`，回退原版是**设计性行为**（原版 200 项物品图标可用）；
- 源 MOD 的 `item/*.png` 是 **UPedit 编辑器导出**（40×40 RGB PNG），不是引擎数据源（引擎读 `thing.grp` 的调色板 RLE）；
- 「缺文件」≠「bug」——这是本 slice 的核心教训。

### 修正记录

- `openspec/epics/2026-10-allmods-compat/TODO.md:91` 记 "kys-books（…唯一使用 name.grp）" **有误**：
  实际 `name.grp` 出现于 **BookCalamity / Dragon / pineapple / RiverLake** 四个 MOD，`books` 未使用。

---

## 四、可复现验证命令

```bash
# Q1：oldevent 编码
cd game && python3 -c "
import os,glob
bad=tot=0
for m in sorted(os.listdir('mods')):
    for f in glob.glob(f'mods/{m}/script/oldevent/*.lua'):
        tot+=1
        try: open(f,encoding='utf-8').read()
        except: bad+=1
print(f'total={tot} bad={bad}')"

# Q2：源 MOD 资源名 vs 引擎需求
cd game && python3 -c "
import os
# sdx/smp 命名错配
for m in ['kys-pascal','kys-mingdong']:
    r=f'../reference/allmods/{m}/resource'
    print(m, 'sdx' in os.listdir(r), 'smp' in os.listdir(r), 'smap.idx' in os.listdir(r))"

# Q2：运行时常量解析（激活 mingdong 后 SMAPPicFile 是否指向 MOD）
cd game && lua /tmp/verify_smap.lua   # 见报告正文实测输出

# 原版 C 引擎资源清单
strings reference/allmods/kys-pascal/kys.exe | grep -oE 'resource/[A-Za-z0-9_.*%]+' | sort -u
```
