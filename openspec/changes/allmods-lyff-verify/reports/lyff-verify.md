# lyff（刘亦纷飞版）验证报告

> Change: `allmods-lyff-verify` · Slice: `allmods-slice8` · Epic: `2026-10-allmods-compat`
> 日期：2026-10-21
> 结论：**PASS**（零缺陷；**首个记录数差异 MOD**（326 人物段）判定为内容差异，零引擎改动）

---

## 1. 结论摘要

| 维度 | 结果 |
|------|------|
| 构建 | ✅ `events=1358 talk=5655`，退出码 0 |
| 逐文件穷举 | ✅ `total=425 unclassified=0 bad_evidence=0` |
| 「必需但未进产物」矛盾 | ✅ **0** |
| 字节级覆盖 | ✅ `formats=12 checked=242 gaps=0` |
| 产物四项检查 | ✅ `PERSON=326 ... STRINGS/EVENTS/SAVE=OK` |
| 真实启动链路 | ✅ `RESULT lyff: OK`（16 项断言） |
| **326 人物段** | ✅ **首个记录数差异 MOD**：动态推导 + 边界记录有效 |
| `hdgrp` 差异 | ✅ 178 条目为内容差异（判据**第 4 次应用**成功） |
| 46 场额外战斗 | ✅ 本 epic 额外战斗最多（92 + 46 = 138） |
| MOD 独有内容 | ✅ 确认为 MOD 内容（非基线值） |
| 引擎改动 | ✅ **零改动** |
| 零回归 | ✅ 全部门禁通过 |
| **发现缺陷** | ✅ **0 个**（累计工具缺陷仍为 4 个） |

---

## 2. `diff.md` 逐条审计（REQ-LYFFV-1/2）

### 2.1 MOD 独有（105 项）

| 类别 | 项数 | 判定 |
|------|-----:|------|
| 额外战斗 `fight*.grp`/`.idx` | **46 场 × 2 = 92** | 预期（动态数量，三重确认见 §5） |
| `cloud.grp`/`.idx` | 2 | 预期（`CC.CloudPicFile` → MOD） |
| `dead.png` / `end.png` / `open.png` | 3 | 预期（死亡/结束/开场画面） |
| `kdef.grp`/`.idx` | 2 | 预期（事件脚本，**1358** 个） |
| `kysmod.ini` | 1 | `BUILD_INPUT`（在产物中） |
| `ranger.str` | 1 | `REQUIRED_CONVERTED`（UTF-8 旁路表） |
| `talk.grp`/`.idx` | 2 | 预期（对话表，**5655** 条） |
| `title.grp`/`.idx` | 2 | 预期（标题画面） |
| **Σ** | **105** | **0 项需修复** |

46 场额外战斗清单：`fight030`、`fight039`、`fight040`、`fight110`、`fight115`~`fight121`
（7 场）、`fight125`、`fight126`、`fight128`~`fight131`（4 场）、`fight133`~`fight146`
（14 场）、`fight152`~`fight162`（11 场）、`fight167`、`fight169`、`fight170`、`fight173`。

### 2.2 基准独有（23 项，REQ-LYFFV-2）——沿用 Slice 6 细化规则

| 性质 | 项数 | 项 |
|------|-----:|----|
| 在 save/（源自带，产物逐字节一致） | 3 | `d1.grp`、`r1.grp`、`s1.grp` |
| 死文件（引擎无引用） | 9 | `alldef.idx`、`allsin.idx`、`allsinbk.grp`、`d1/d2/d3.idx`、`s1/s2/s3.idx` |
| 回退原版（含首次存档播种） | 11 | `d2.grp`、`d3.grp`、`r1.idx`、`r2.grp`、`r2.idx`、`r3.grp`、`r3.idx`、`s2.grp`、`s3.grp`、`thing.grp`、`thing.idx` |
| **Σ** | **23** | ✅ 无未解释项 |

**死文件判据（源码级，同 Slice 6）**：
- `alldef.idx`/`allsin.idx`：引擎只引用对应 `.grp`（`CC.D_Filename[0]`/`CC.S_Filename[0]`）
- `allsinbk.grp`（save/ 副本）：引擎临时场景文件是 `data/allsinbk.grp`（`CC.TempS_Filename`）
- `d/s*.idx`：引擎无 S/D idx 常量（`jyconst.lua:80`「S和D由于是固定大小，因此不再定义idx了」）

**回退/播种项的运行时证据**：
```
CC.D_Filename[1]    = mods/lyff/save/d1.grp    ← 源自带
CC.R_GRPFilename[1] = mods/lyff/save/r1.grp    ← 源自带
CC.R_IDXFilename[1] = mods/lyff/save/r1.idx    ← 源无；首次 SaveRecord(1) 播种（Slice 6 已验证机制）
CC.S_Filename[1]    = mods/lyff/save/s1.grp    ← 源自带
CC.ThingPicFile[1]  = data/thing.idx           ← 回退原版
```

---

## 3. 326 人物段判定（REQ-LYFFV-4）——首个记录数差异 MOD

lyff 是本 epic **首个记录数与基线不同的 MOD**：源模板 `ranger.grp` 人物段含
**326** 条记录（pascal 320）。

**判定为「内容差异」的 4 条机器可验证判据**：

| # | 条件 | 实测 |
|---|------|------|
| 1 | 动态推导 | `JY.PersonNum = math.floor((idx[2]-idx[1])/CC.PersonSize)`（`jymain.lua:1747`）；lyff `idx[2]-idx[1] = 59332 = 326 × 182`（pascal `58240 = 320 × 182`） |
| 2 | 无固定计数 | 全仓库无 `PERSON_NUM` 等固定计数常量（记录数全部由 idx 分段偏移推导） |
| 3 | **边界记录有效** | `Person[325]`（第 326 条）= **枯榮/南帝**（姓名/外号可读，非 nil/乱码）——证明整段 326 条正确解析 |
| 4 | 字节全覆盖 | `formats=12 checked=242 gaps=0`（含 326 条人物段） |

**与 `hdgrp` 判据的统一**：`hdgrp`（`PicLoadFile` 用 `idxlen/4`）与记录段
（`idx[2]-idx[1]`）同属**索引驱动**——条目数/记录数由索引推导，无固定常量。
两个判据统一为一条原则：

> **索引驱动 + 无固定计数 + 字节全覆盖 + 边界有效 = 内容差异（零引擎改动）**

**可外推**：后续所有记录数 ≠ 基线的 MOD（第 4~5 梯队）复用此判据。

---

## 4. `hdgrp` 差异 vs 结构异常（REQ-LYFFV-4 相关）——判据第 4 次应用

| 条件 | 实测 |
|------|------|
| `hdgrp.idx` 大小 | 712 字节 = **178** × 4 |
| `CC.HeadPicFile[1]` | `mods/lyff/data/hdgrp.idx` |
| 索引驱动 | `lib_love.lua:437` `local num = idxlen/4` |
| 固定计数常量 | `CC.HDGRPNum` 等 5 个常量全 `nil` |
| 记录布局常量同 | `182`/`190`/`52`/`136` |
| 字节全覆盖 | `formats=12 checked=242 gaps=0` |

**外推链**：HeavenSword（125，建立）→ GodsDevils（129）→ pig（173）→ **lyff（178）**
——4 次一致。第 4 梯队（252/267/300）与第 5 梯队（books 696）可继续复用。

---

## 5. 46 场额外战斗（本 epic 最多）

| # | 证据 | 结果 |
|---|------|------|
| 1 | `diff.md` 提及 | 46 场 × 2 文件 = 92 项 |
| 2 | 产物存在 | `data/fight*.grp` = **138**（92 + 46） |
| 3 | 审计归类 | `REQUIRED` + `in_product=true` |

超过 pig 的 45 场，为本 epic **额外战斗最多**的 MOD。战斗文件数为动态
（`diff.md` 驱动），引擎按文件名引用，无固定数量依赖。

---

## 6. MOD 独有内容验证（REQ-LYFFV-3）

| 判据 | lyff | pascal 基线 | 区分度 |
|------|------|------------|--------|
| 主角姓名 | **AAA** | 小蝦米 | ✅ |
| `JY.Person[1]["姓名"]` | **胡斐**/雪山飛狐 | （不同布局） | ✅ |
| `JY.Person[2]["姓名"]` | **程靈素**/毒手藥王 | （不同布局） | ✅ |
| `JY.Person[325]["姓名"]` | **枯榮**/南帝（边界） | （不存在，仅 320 条） | ✅ |
| 人物记录数 | **326** | 320 | ✅ |
| 对话条目数 | **5655** | 2977 | ✅ |
| 事件脚本数 | **1358** | 1018 | ✅ |
| `hdgrp` 条目数 | **178** | 115 | ✅ |
| 战斗数 | **138** | 92 | ✅ |
| Thing/Scene/Wugong | 200/84/93 | 200/84/93 | ❌ **同数，不作为证据** |

**注意**：Thing/Scene/Wugong 与基线同数——按负约束，**不得**以「记录数相同」
作为 MOD 内容已加载的证据；此处用主角姓名（AAA）、边界记录（枯榮@325）等
非基线值证明。

**主角姓名 `AAA` 的解析依赖**：`Person[0].姓名` 源字节为纯 ASCII `AAA`（无 Big5 高字节）。
构建期 `mod_encoding.lua` 的 `isStringField` 守卫必须把「可打印 ASCII 且长度 ≥ 2」判为字符串
（而非数值槽），`AAA` 才会进入 `ranger.str` 旁路表并在运行时解析为 `AAA`；否则会被当作
数值槽中和成空串。此守卫有回归测试覆盖
（`test_mod_encoding.lua`「ConvertRanger 保留纯 ASCII 文本（不再误丢）」，断言 lyff `AAA`）。
该守卫同时修复 HeavenSword `killer-G`、GodsDevils `123`、ptt `PTT`、dream `------`。

---

## 7. 存档（第 3 种形态，Slice 6 已验证机制）

lyff 源自带 `save/` 10 个文件，含 3 个槽文件（`d1`/`r1`/`s1`，**无 `r1.idx`**）——
与 GodsDevils 同为**第 3 种形态**（`r1.grp` 有、`r1.idx` 无），但槽文件更少（3 vs 6）。

- 产物 `save/` 6 个文件（`d11`/`r11`/`s11` + `d1`/`r1`/`s1`），源自带 3 个与源**逐字节一致**
  （含全量测试后）
- 半状态 `LoadRecord(1)` 由 `jymain.lua:1697-1701` 守卫优雅跳过（不崩溃）
- 首次 `SaveRecord(1)` 经 `ModData.SeedSaveSlot` 播种 `r1.idx` 补全槽位
  （机制级 round-trip 已由 Slice 6 在 GodsDevils 上完成）

---

## 8. 穷举审计（Slice 0c 工具链）

```
$ cd game && lua tools/mod_audit.lua --mod lyff
total=425 in_product=395 not_in_product=30 unclassified=0 bad_evidence=0
  REQUIRED             390
  REQUIRED_CONVERTED   4
  LEGACY               3
  BUILD_INPUT          1
  PENDING              27
```
`Σ = 390+4+3+1+27 = 425` ✅ · **矛盾 = 0** ✅

**30 个未进产物文件构成**（机器可复核，`mod_audit --mod lyff --json`）：

| 类别 | 项数 | 具体文件 |
|------|-----:|---------|
| `PENDING` | **27** | `music/1`~`music/23.mid`（23 首）+ `list/{effect,leave,levelup,match}.bin`（4 个） |
| `LEGACY` | **3** | `list/end.txt`、`list/start.txt`、`script/1.lua` |
| **Σ** | **30** | ✅ 无 `head/`/`item/` 目录（lyff 无独立 PNG 副产物） |

`music/*.mid`（23 首）属全局遗留 spike（待决策），详见 epic TODO「开放问题」。

```
$ cd game && lua tools/format_spec.lua --mod lyff
formats=12 checked=242 gaps=0
```

---

## 9. 零引擎改动（REQ-LYFFV-5）

| 文件 | 改动 | 允许？ |
|------|------|-------|
| `game/mods/lyff/**` | 构建产物 | ✅ |
| `openspec/changes/allmods-slice8/**` 等 | 文档 | ✅ |

**未触碰**：`game/engine-love2d/**` ✅ · `game/engine-mud/**` ✅ ·
`game/script/jyconst.lua` 常量定义 ✅ · `reference/allmods/**` ✅

**本 slice 两个子 change 均零代码改动**（纯构建 + 验证）。

---

## 10. 零回归

```
lua tests/test_runner.lua                        → 1612/1612 ✅
lua tools/mod_build.lua --verify-pascal          → events=1018, mismatches=0, known-deviations=3 ✅
lua tools/mod_build.lua --all                    → 20 mods, 0 build failures, 5 annotated-problematic ✅
lua tools/mod_check.lua                          → 20 MOD, 通过 20, 失败 0 ✅
lua tools/mod_audit.lua --all                    → total=11220 unclassified=0 bad_evidence=0 ✅
lua tools/mod_audit.lua --all --evidence         → checked=17 failed=0 ✅
lua tools/format_spec.lua --all                  → formats=12 checked=6773 gaps=0 ✅
全量测试后全 MOD save/ 与源一致                   → mismatch=0 ✅
```

---

## 11. 累计工具缺陷（4 个，本 slice 新增 0）

| # | Slice | 缺陷 | 根因 |
|---|-------|------|------|
| 1 | 2 | `mod_check_one` 销毁 `r1.grp` | 自检直接 `os.remove` 真实产物目录 |
| 2 | 3 | `mod_audit` 对 `kysmod.ini` 的 `in_product` 误判 | 类别级一刀切 |
| 3 | 3 | `test_mod_boot` 销毁 `r1.grp` | 与 #1 同源 |
| 4 | 5 | `mod_check_one` 销毁 `d1.grp`/`s1.grp` | #1 的第三次遗漏（`SLOTS` 只列 `r1.*`） |

**本 slice 零缺陷**。

---

## 12. 结论

**PASS**。REQ-LYFFV-1~6 全部满足。lyff **零引擎改动、零代码改动**通过全部验证。

**本 change 的关键产出**：
1. **首个记录数差异 MOD 判定**：326 人物段为内容差异（4 条判据：动态推导 +
   无固定计数 + 边界记录有效 + 字节全覆盖），零引擎改动。
2. **判据统一**：`hdgrp` 条目数差异（`idxlen/4`）与记录数差异（`idx[2]-idx[1]`）
   统一为「索引驱动 + 无固定计数 + 字节全覆盖 + 边界有效 = 内容差异」原则，
   可外推到后续全部非基线形态 MOD。
3. **46 场额外战斗**为本 epic 最多（92 + 46 = 138），动态战斗数量再次验证。
4. `hdgrp` 判据**第 4 次应用成功**（178）。

**第 3 梯队进度**：pig（173，Slice 7）→ **lyff（178，Slice 8）** → ptt（204，Slice 9，收尾）。
