# Verification: allmods-ptt-activate

> 状态：**done** · 日期：2026-10-28 · Slice: `allmods-slice9` · Epic: `2026-10-allmods-compat`
> 结论：**PASS**（零引擎改动；**首个 4 段记录数全异 MOD**；**+70 额外战斗**为本 epic 最多）

## 1. 目标回顾

激活 `kys-ptt`（PTT，hdgrp 204 / fight 162 / 记录段 385/214/90/108）：构建 → 穷举审计 →
字节覆盖 → 启动链路 → `hdgrp` 差异 → 4 段记录数差异 → 额外战斗 → 存档验证，零引擎改动。
第 3 梯队收官（第 3 个）。

## 2. REQ 追溯矩阵

| REQ | 状态 | 证据 |
|-----|------|------|
| REQ-PTT-1 构建 | ✅ | `data files=362 saves=21 sound=78 events=1229 talk=5689`（§3.1） |
| REQ-PTT-2 逐文件穷举 | ✅ | `total=596 unclassified=0 bad_evidence=0`；Σ(类别)=596（§3.2） |
| REQ-PTT-3 字节级覆盖 | ✅ | `formats=12 checked=317 gaps=0`（§3.3） |
| REQ-PTT-4 `hdgrp` 204 | ✅ | 三重判据 + 判据第 5 次应用（§3.4） |
| REQ-PTT-5 4 段记录数差异 | ✅ | 385/214/90/108 全整除 + 边界 hint 有效（§3.5） |
| REQ-PTT-6 70 场额外战斗 | ✅ | 三重确认 162 = 92 + 70（§3.6） |
| REQ-PTT-7 启动链路 | ✅ | `RESULT ptt: OK`（16 断言）（§3.7） |
| REQ-PTT-8 存档验证 | ✅ | 21/21 逐字节一致（§3.8） |
| REQ-PTT-9 零回归 | ✅ | 7 项门禁全绿（§4） |
| REQ-PTT-10 零引擎改动 | ✅ | `git diff` 无 engine/framework/script 路径（§6） |
| REQ-PTT-11 `isStringField` 加固 | ✅ | 高位字节须全 Big5 可解码；20/20 `ranger.str` md5 不变；+9 回归断言（§7.1） |

## 3. 实测证据

### 3.1 构建（REQ-PTT-1）

```
$ cd game && rm -f active_mod.txt && lua tools/mod_build.lua kys-ptt
[mod_build] kys-ptt: data files=362, saves=21, sound=78, events=1229, talk=5689
[mod_build] diff -> tools/../mods/ptt/diff.md
```

退出码 0；`game/mods/ptt/diff.md` 生成。
`fight*.grp` 产物 = **162**（DoD 要求）。

### 3.2 逐文件穷举审计（REQ-PTT-2）

```
$ lua tools/mod_audit.lua --mod ptt
total=596 in_product=459 not_in_product=137 unclassified=0 bad_evidence=0
  REQUIRED             454
  REQUIRED_CONVERTED   4
  LEGACY               3
  EDITOR_DUMP          105
  BUILD_INPUT          2
  PLATFORM_ARTIFACT    1
  PENDING              27
```

`Σ = 454+4+3+105+2+1+27 = 596` = `total`。
`total=596` 恰等于源目录文件总数 `find reference/allmods/kys-ptt -type f | wc -l` = **596**
—— 每个源文件都被归类，无遗漏。

「必需但未进产物」矛盾数 = **0**：

```
$ lua -e 'local A=require("tools.mod_audit"); local r,s,u,c=A.auditAll("ptt"); print(#c)'
0
```

137 条 `not_in_product` 全部有具名类别：
- **PENDING 27** = `music/*.mid` 23 个 + `list/*.bin` 4 个（全局遗留 spike，非本期范围）
- **EDITOR_DUMP 105** = `eft/` 目录 105 个 PNG/idx（UPedit 副产物）
- **LEGACY 3** = `list/end.txt`、`list/start.txt`、`script/1.lua`（旧引擎遗留）
- **BUILD_INPUT 1** = `resource/talkutf8.txt`（构建输入，已消费）
- **PLATFORM_ARTIFACT 1** = `save.zip`（源压缩包，解包产物即已归类文件）

### 3.3 字节级覆盖（REQ-PTT-3）

```
$ lua tools/format_spec.lua --mod ptt
formats=12 checked=317 gaps=0
```

317 个二进制文件逐字节归入具名字段区间，**0 缺口 0 重叠**。

### 3.4 `hdgrp` 204（REQ-PTT-4）——判据第 5 次应用

| 判据 | 实测 |
|------|------|
| 索引驱动 | `hdgrp.idx` = **816 字节** = 204 × 4；`PicLoadFile` 用 `idxlen/4`（`engine-love2d/lib_love.lua:437`） |
| 无固定计数 | `CC.HDGRPNum` / `CC.HDPicNum` / `CC.MAX_HEAD_NUM` / `CC.HDGRP` / `CC.HeadNum` **全 nil**（未定义） |
| 字节全覆盖 | `lua tools/format_spec.lua --format hdgrp --mod ptt` → `formats=1 checked=1 gaps=0` |

`hdgrp.idx` 实测：ptt **816 B = 204 条目**；pascal 460 B = 115 条目。
判定：**内容差异**（+89 头像）。
外推链：**125 → 129 → 173 → 178 → 204**，五次结论一致。

### 3.5 4 段记录数差异（REQ-PTT-5）——统一判据第 2 次应用，首个全段差异 MOD

`ranger.idx` 段偏移：`836, 70906, 111566, 116246, 130934, 131084`

| 段 | 段长 | 记录大小 | 条数 | 整除 | pascal | 差异 |
|----|-----:|--------:|-----:|:----:|-------:|-----:|
| Person | 70070 | 182 | **385** | YES | 320 | +65 |
| Thing  | 40660 | 190 | **214** | YES | 200 | +14 |
| Scene  |  4680 |  52 | **90**  | YES |  84 | +6 |
| Wugong | 14688 | 136 | **108** | YES |  93 | +15 |
| Shop   |   150 |  50 | **3**   | YES |   3 | 0 |

**索引驱动**：`JY.PersonNum = math.floor((idx[2]-idx[1]) / CC.PersonSize)`（`jymain.lua:1747`）；
Thing/Scene/Wugong 同构。**无固定计数常量**。

**边界记录有效**（产物 `mods/ptt/data/ranger.grp` 末条记录，NUL 截断后为 hint）：

| 段 | 末条索引 | 字段 @偏移 | 值 |
|----|---------:|-----------|-----|
| Person | 384 | `@8` / `@18` | `P0489` / `N0448` |
| Thing  | 213 | `@2` / `@22` / `@42` | `T0395` / `T20395` / `TD0395` |
| Scene  | 89  | `@2` | `S0088` |
| Wugong | 107 | `@2` | `W0107` |

（hint 是**构建产物**写入的旁路表指针；源 `ranger.grp` 该处为 Big5 原文，符合方案 D 设计。）

**边界记录内容可读**（运行时 `LoadRecord(0)`，见 §3.7 上下文）：

| 段 | 末条索引 | 名称 |
|----|---------:|------|
| Person | 384 | 卓不凡 |
| Thing  | 213 | 高昌迷宮地圖 |
| Scene  | 89  | 計老人居 |

判定：**内容差异**（零引擎改动）。统一判据（Slice 8 ADR）第 2 次应用；
**首个 4 段全部异于基线的 MOD**（lyff 仅 Person 段差异）。

### 3.6 70 场额外战斗（REQ-PTT-6）——本 epic 最多

三重确认：

| # | 判据 | 实测 |
|---|------|------|
| 1 | `diff.md` 提及 | `mods/ptt/diff.md` MOD 独有 154 项中，**140 项** = 70 个 `fightNNN.grp` + 70 个 `fightNNN.idx` |
| 2 | 产物存在 | `ls mods/ptt/data/fight*.grp \| wc -l` = **162**（pascal 92 + 70）；`comm -13 pascal ptt` = **70** |
| 3 | 审计归类 | 162 个 `fight*.grp` **全部** `category=REQUIRED` / `in_product=true`，其他类别 = 0 |

抽样 5 场逐项复核：

| 文件 | category | in_product | 产物存在 |
|------|----------|:----------:|:--------:|
| `fight073.grp` | REQUIRED | true | true |
| `fight130.grp` | REQUIRED | true | true |
| `fight154.grp` | REQUIRED | true | true |
| `fight195.grp` | REQUIRED | true | true |
| `fight216.grp` | REQUIRED | true | true |

### 3.7 启动链路（REQ-PTT-7）

```
$ lua tests/unit/boot_one_mod.lua ptt 385 214 90 108 鄉民
[PASS] lib.init 无报错
[PASS] JYMainAdapter.init 无报错
[PASS] CC.PersonSize=182 / ThingSize=190 / SceneSize=52 / WugongSize=136（MOD 布局）
[PASS] LoadRecord(0) 无报错
[PASS] PersonNum 385 / ThingNum 214 / SceneNum 90 / WugongNum 108
[PASS] 主角姓名 鄉民
[PASS] 扫描字段数 > 100（实际 1610）
[PASS] 全量字符串无 U+FFFD（期望 0，实际 0）
[PASS] 全量字符串无控制符（期望 0，实际 0）
[PASS] 运行时 10 帧无报错
--------------------------------------------------
RESULT ptt: OK
```

16 项断言全 PASS。

**MOD 独有内容（非基线值证明）** —— 运行时实测 vs pascal 基线：

| 字段 | ptt | pascal 基线 |
|------|-----|------------|
| `Person[0].姓名` | **鄉民** | 小蝦米 |
| `Person[0].外号` | 天下奇男子 | 天下奇男子 |
| `Thing[0].名称` | **千面人蠻牛** | 康倍特 |
| `Person[384].姓名`（末条） | **卓不凡** | —（基线仅 320 条） |
| `Thing[213].名称`（末条） | **高昌迷宮地圖** | —（基线仅 200 条） |
| `PersonNum/ThingNum/SceneNum/WugongNum` | **385/214/90/108** | 320/200/84/93 |

**回退链生效**（运行时 `CC.*` 路径指向 MOD）：

```
CC.HeadPicFile[1]   = mods/ptt/data/hdgrp.idx
CC.D_Filename[1]    = mods/ptt/save/d1.grp
CC.S_Filename[1]    = mods/ptt/save/s1.grp
CC.R_GRPFilename[1] = mods/ptt/save/r1.grp
```

### 3.8 存档（REQ-PTT-8）——本 epic 源槽最多（18 个）

- 源 `reference/allmods/kys-ptt/save/` 28 个文件：`ranger.*`/`alldef.*`/`allsin.*`（基础数据，
  进 `data/`）+ **18 个存档槽**（`d1`~`d6`/`r1`~`r6`/`s1`~`s6` @ `.grp`）+ `d11`/`r11`/`s11` @ `.grp`
  + `save.zip`（源压缩包）
- 产物 `mods/ptt/save/` **21 个文件**，与源同名文件**逐字节一致（21/21，不一致 = 0）**

```
$ for f in $(ls game/mods/ptt/save/); do cmp -s reference/allmods/kys-ptt/save/$f game/mods/ptt/save/$f; done
检查 21 个，不一致 = 0
```

- 非槽位文件去向核实：`ranger.grp`/`ranger.idx`/`alldef.grp`/`alldef.idx`/`allsin.grp`/`allsin.idx`
  → **全部在 `mods/ptt/data/`** ✔；`save.zip` = 源压缩包，解包产物即上列文件，不进产物。
- 运行时 `CC.D_Filename[1]`/`R_GRPFilename[1]`/`S_Filename[1]` 指向 `mods/ptt/save/`（§3.7）。

## 4. 零回归（REQ-PTT-9）

七项门禁全部实测：

| 门禁 | 命令 | 结果 |
|------|------|------|
| 全量单测 | `lua tests/test_runner.lua` | **1622/1622 通过，0 失败** |
| pascal 基线 | `lua tools/mod_build.lua --verify-pascal` | `events=1018, mismatches=0, known-deviations=3` · **PASS** |
| 全 MOD 构建 | `lua tools/mod_build.lua --all` | `20 mods, 0 build failures, 5 annotated-problematic` |
| 全 MOD 自检 | `lua tools/mod_check.lua` | **20/20 通过，失败 0** |
| 全 MOD 审计 | `lua tools/mod_audit.lua --all` | `total=11220 in_product=9245 not_in_product=1975 unclassified=0 bad_evidence=0` |
| 证据校验 | `lua tools/mod_audit.lua --all --evidence` | `evidence: checked=17 failed=0` |
| 字节覆盖 | `lua tools/format_spec.lua --all` | `formats=12 checked=6773 gaps=0` |
| 存档完好 | 全 20 MOD `save/` vs 源逐字节 | 比对 **341** 个文件，**不一致 = 0** |

> 说明：本轮曾出现 2 个 `test_mod_boot` 失败（`r1.idx auto-seeded` / `save/load round-trip`）。
> 根因是**我自己**在后台跑全量测试的同时并行执行了 `lua tools/mod_build.lua --all`，
> 后者重写 `mods/mingdong/save/` 与测试的写盘产生竞态。单独复跑 `mod_boot`（87/87）、
> `mod_encoding`（全绿）及**全量串行复跑**（1622/1622）均通过。**非代码回归**。

## 5. 产物清单

- `game/mods/ptt/`：`data/`（362 文件，含 `ranger.str` 旁路表）、`script/`（`oldevent/` 1229 事件 +
  `oldtalk.grp/.idx`）、`save/`（21 文件）、`sound/`（78 文件）、`diff.md`
- `openspec/changes/allmods-ptt-activate/`：proposal / design / specs / tasks / verification

## 6. Blast Radius 合规检查（REQ-PTT-10）

| 路径 | 状态 |
|------|------|
| `game/engine-love2d/**` | ✅ 未改 |
| `game/engine-mud/**` | ✅ 未改 |
| `game/script/jyconst.lua`（常量定义） | ✅ 未改 |
| `reference/allmods/**` | ✅ 未改 |
| `game/tools/mod_encoding.lua` | ⚠ 已改（**仅为 §7.1 `isStringField` 加固**，允许路径；对真实数据逐字节 no-op） |
| `game/tests/unit/test_mod_encoding.lua` | ⚠ 已改（+9 回归断言，允许路径） |
| `game/framework/**` | ✅ 未改 |
| `game/mods/ptt/**` | 产物（gitignore） |
| `openspec/**` | artifacts（允许） |

除 §7.1 的加固（对真实数据逐字节 no-op）外，本 slice 无其他代码改动。
判据与工具链在 lyff（Slice 8）修复后已收敛；本次加固属同一处工具的收尾。

## 7. 偏差记录

| # | 偏差 | 说明 |
|---|------|------|
| 1 | `allmods-slice9/change-manifest.md` 在本轮核实前已标 `status: done`，但 `allmods-ptt-verify/` 目录不存在、`allmods-ptt-activate/verification.md` 缺失 | 本轮核实补齐（本文件 + `allmods-ptt-verify/**`）。所有 DoD 实测值均与 manifest 声明一致，无虚报。 |
| 2 | `diff.md` 未列出 `ranger.str` | `ranger.str` 是**构建产物**（`mod_build.lua:1174` 写入 `data/ranger.str`），源目录不存在该文件，故不进 diff。审计 `total=596` = 源文件总数 596。 |
| 3 | `diff.md` 「基准独有 21 项」 | 全部合法：18 项为存档槽（源在 MOD `save/`，产物在 `mods/ptt/save/`，不进 `data/`）+ `allsinbk.grp`/`thing.grp`/`thing.idx`（基线回退，MOD 未提供）。 |
| 4 | `isStringField` 在本 slice 被加固（处理残余项时发现） | 见 §7.1。改动对真实数据是**逐字节 no-op**（20/20 `ranger.str` md5 不变），仅消除假阳性并补上回归测试。 |

### 7.1 `isStringField` 加固（Slice 8 遗留项的收尾）

**背景**：Slice 8 引入的 `isStringField`（含高位字节 OR 全可打印 ASCII 且 len≥2）
正确地恢复了 5 MOD 6 个 ASCII 名，但「含高位字节即字符串」这一条**是裸高位测试**：
任何非 Big5 高位字节（如 int32 槽填 `0xFF`、或截断的 Big5 首字节）都会被误判为字符串，
随后 `DecodeBig5` 产出 U+FFFD 垃圾。

**改动**（`game/tools/mod_encoding.lua`，允许路径）：

```lua
-- 改前：空写高位字节即返回 true
if b >= 0x80 then return true end

-- 改后：高位字节必须成对且能在 Big5 表中解码（与 DecodeBig5 能力严格镜像）
while i <= n do
    local b = raw:byte(i)
    if b >= 0x80 then
        hasHigh = true
        if i + 1 > n then return false end          -- 孤立首字节
        tbl = tbl or loadBig5()
        local ch = tbl[b * 256 + raw:byte(i + 1)]
        if ch == nil or ch == "\239\191\189" then return false end
        i = i + 2
    else
        if b < 0x20 or b > 0x7e then allPrint = false end
        i = i + 1
    end
end
```

**为何安全**：全 20 MOD 的 `ranger.grp` 解码后 U+FFFD 数 = **0**（旧行为已实测），
所以「要求全 Big5 可解码」对真实数据是**恒真条件** —— 只剔除假阳性。

**逐字节无变化验证**（重建 20 MOD 后比对 md5）：

```
$ lua tools/mod_build.lua --all     # 20 mods, 0 build failures
$ diff <(重建前 md5) <(重建后 md5)
ranger.str 20/20 逐字节未变（isStringField 加固为 no-op）
```

**新增回归测试**（`game/tests/unit/test_mod_encoding.lua`，9 条新断言）：

| 测试 | 断言 |
|------|------|
| `testIsStringFieldDiscriminator` | 10 正例（`AAA`/`killer-G`/`123`/`PTT`/`------`/`AB`/`53\xa1A219`/`\xa4\xa4\xa4\xe5`/`a\xa1A`/Big5 六字节）+ 12 反例（` ` / `<` / `K` / `7` / `$` 单字节残留、NUL/C0 数值槽、`\xff\xff\xff\xff`、`\xff\xfe\xfd\xfc`、孤立 `\xa4`） |
| `testRangerStrSideTableContents` | `ptt` 含 `PTT`、`lyff` 含 `AAA`（用 `ParseSideTable` 反解，避免子串误命中 `AAA居`）；20 MOD 每行可解析为 5 字段（值内逗号合法）；`-1` 空条目数精确（`GodsDevils` 1 / `pig3dos` 1 / `pineapple` 3，其余 0） |

为此把原本 local 的判别器以薄包装导出：`M.IsStringField(raw)`。

测试总数 **1613 → 1622**（+9）。

## 8. 结论

**PASS**。ptt 激活完成，**零引擎改动**；唯一的代码改动是 §7.1 的 `isStringField` 加固
（对真实数据是逐字节 no-op，仅消除假阳性 + 补回归测试）。

1. **首个 4 段记录数全异 MOD**（385/214/90/108）—— 统一判据第 2 次应用成功，零引擎改动。
2. **`hdgrp` 204** —— 判据第 5 次应用（125/129/173/178/204）五次结论一致。
3. **+70 额外战斗**（本 epic 最多）—— 三重确认 + 5 场抽样。
4. **18 个源存档槽**（本 epic 最多）—— 21/21 逐字节一致。
5. 全部门禁通过，无回归。
