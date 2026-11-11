---
status: active
created: 2026-10
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
  impact: []
---
# Epic: allmods MOD 兼容 — love2d-event-driven

## 愿景

让 `reference/allmods/` 下全部 19 个 MOD（不含原版 kys-pascal）在 love2d-event-driven 分支的 Love2D 引擎上运行。架构设计一次性覆盖 20 种数据形态（文件缺失回退、文件新增动态发现、ini 参数差异、hdgrp 条目数 114→266），实现从与原版最接近的 MOD（名动天下）开始逐个完成。

## 为什么不做 kys-pascal（原版）

原版 kys-pascal 不在 MOD 清单内——不是遗漏，而是**它不需要任何适配工作**：

1. **当前分支运行的就是原版**：`game/data/` 与 kys-pascal 的 `resource/ + fight/ + save/` 拍平后的 230 个文件逐字节相同（仅大小写差异），`script/oldevent/` + `old_talk.lua` 即原版 kdef/talk 的提取产物。原版"已适配"，没有东西可改。
2. **零引擎改动**：原版的数据形态（hdgrp 114 条目、文件清单、ini 默认值）正是现有引擎的构建假设。
3. **kys-pascal 在本 epic 中承担两个支撑角色**：① **回退基准**——运行时回退链落到的 `data/`、`script/` 就是原版数据；② **回归基准**——构建管线对 pascal 跑出的提取产物必须与现有 `script/oldevent/` 一致（管线正确性基准，见 allmods-build-pipeline）。

## 背景与已验证结论（2026-10 探索产出）

以下事实经代码与二进制实测，是本 epic 的约束基础：

1. **数据同源**：`game/data/` 与 `base:bin/data/`（原版）230 个文件 100% 相同（仅大小写差异），且正是 kys-pascal 的 `resource/ + fight/ + save/` 拍平进 `data/` 的结果。当前分支跑的就是"原版"这一个 MOD。
2. **PNG 头像已支持**：`lib_love.lua` 的 grp 加载有 PNG 分支，且 `game/data/hdgrp.grp`（114 条目）内嵌 2 个 PNG 条目（头像代号 59 主角、111 韦小宝）——与原版 SDL3 引擎 `piccache.c` 的 `IMG_isPNG` 机制一致。**引擎侧零工作量，不需要"独立 PNG 目录加载器"**。
3. **独立 `head/*.png` 目录是编辑器副产物**：原版 SDL3 引擎 `src/` 零引用；PNG 与对应 RLE 条目一一对应（统一 +4px padding，UPedit 导出格式）。allmods 实际头像数据是 `hdgrp.grp` 内 RLE 条目，现有解码器直接可读。
4. **`kysmod.ini` 是原版 SDL3 引擎的 MOD 入口**，love2d 无对应机制。各 MOD 取值互不一致（`EXP_RATE=4` vs 原版 100、mingdong 分辨率 960x660、键名 typo `SCENCEAMI`），解析必须容忍缺失段/缺失键/typo 键名，并映射到 `CONFIG.*`/`CC.*`。
5. **MOD 间数据内容差异大（md5 实测）**：不能假设文件清单与原版相同。引擎必须容忍：文件缺失（回退原版）、文件新增（fight 数量动态变化）、内容不同（战斗/剧情全变）。
6. **事件/对话是构建期内容适配**：`oldevent/*.lua`（1018 个）是从原版 kdef 提取的静态产物，每 MOD 的 kdef 不同 → 必须对每个 MOD 重新走提取流程（用户已拍板：**构建期间提取**）。
7. **hdgrp 条目数分布**（实测，`hdgrp.idx` 字节数 / 4）：pascal/mingdong = **115**，GodsDevils = **129**，ptt = **204**，Dragon = **267**。条目数是数据形态分层的主要维度，其余 14 个 MOD 的精确差异由 Slice 0 的数据差异报告产出后排序。
   > **修正（2026-10-27 实测）**：此处早期探索记录为 `114/128/203/266`，**系统性差 1**。
   > 实测源侧 `reference/allmods/kys-pascal/resource/hdgrp.idx` = **460B = 115 段**（460/4），
   > 产物 `mods/pascal/data/hdgrp.idx` 同为 460B。四档正确值为 **115/129/204/267**。

## 架构概述

MOD 接入是**构建期流水线**而非运行时特性：

```
reference/allmods/kys-<mod>/            （只读数据源）
  ├─ resource/ + fight/ + save/         拍平 + 大小写归一
  ├─ kysmod.ini                         解析 → ini 覆盖层
  ├─ script/ (kdef.grp 等)              构建期提取
  └─ head/ item/ eft/ png 目录           忽略（编辑器副产物）
        │
        ▼  构建流水线（tools/mod_build.lua）
  game/mods/<mod>/data/                 合并后的数据目录（<mod> = slug，如 mingdong）
  game/mods/<mod>/script/oldevent/      本 MOD 的事件脚本
  game/mods/<mod>/script/old_talk.lua   本 MOD 的对话表
  game/mods/<mod>/diff.md               数据差异报告（驱动后续排序）
        │
        ▼  运行时
  game/ （framework 不变）
  ├─ config: 原版 CONFIG/CC 默认值 ← kysmod.ini 覆盖
  ├─ data:  优先 mods/<mod>/data/，缺失回退 data/
  └─ script: 加载 mods/<mod>/script/，缺失回退 script/
```

关键设计原则：
- **回退链**：`mods/<mod>/data/<file>` → `data/<file>`（原版）。运行时与构建期共用同一优先级逻辑。
- **产物同父目录**：单 MOD 的全部构建产物归 `game/mods/<mod>/` 一个父目录（`data/`、`script/`、`diff.md`）。
- **动态发现**：fight 文件数、hdgrp 条目数等不硬编码，加载时枚举。
- **原版零回归**：不指定 MOD 时，行为与现状完全一致（回退链全部落到 `data/`）。

## Vertical Slices

### Slice 0: MOD 兼容地基（foundation）

搭建 MOD 接入的横向地基：spike 审计、ini 解析、数据合并回退、构建期提取管线。完成本 slice 后，任意 MOD 的数据都可以接入，且产出数据差异报告驱动后续 slice 排序。

**业务价值**：把"换 MOD"从 20 次手工工程变成一条可重复流水线；数据差异报告决定后续 18 个 MOD 的实施顺序。

**范围**：

| 任务 | 说明 |
|------|------|
| Spike: `LoadThingPic=0` 审计 | 验证物品图在 smap 路径下的显示路径，确认 `thing.grp` 与物品图渲染的耦合点，为数据弹性改造定界 |
| kysmod.ini 解析器 | 解析 `[system]`/`[constant]` 等段 → 覆盖 `CONFIG.*`/`CC.*`；容忍缺失段/缺失键/typo 键名（如 `SCENCEAMI`）；键名映射表可配置 |
| 数据合并 + 回退加载 | `mods/<mod>/data/` 优先、`data/` 回退的文件加载机制（引擎加载点收敛到单一入口）；fight 文件数动态枚举 |
| 构建期内容管线 | `tools/mod_build.lua`：kdef.grp → `mods/<mod>/script/oldevent/*.lua`、talk.grp → `mods/<mod>/script/old_talk.lua`（复用/改造 `convertkdef2.lua` + `tools/extract_*.lua`，解决对 fishedit 文本格式的依赖）；资源拍平 + 大小写归一 |
| 数据差异报告 | 每 MOD 产出 `mods/<mod>/diff.md`：相对原版的文件增删、hdgrp 条目数、fight 数量、ini 差异——用于给剩余 18 个 MOD 排序 |

**DoD**（机器可验证）：
1. `lua tools/mod_build.lua kys-mingdong` 跑通，产出 `game/mods/mingdong/data/`、`game/mods/mingdong/script/`、`game/mods/mingdong/diff.md`。
2. 19 个 MOD 全部跑一遍数据差异报告，排序写入 TODO.md。
3. 不指定 MOD 时，`lua tests/test_runner.lua` 全绿（原版零回归）。
4. ini 解析器对 19 个 MOD 的 kysmod.ini 全部解析成功（含 typo 键名）。

**影响领域**：engine (data loading), framework (config), tools (build pipeline)
**依赖**：无
**状态**：done（slice change: [allmods-slice0](../../changes/allmods-slice0/slice-proposal.md)；4 个子 change 全部完成）

---

### Slice 1: 名动天下（kys-mingdong）端到端

第一个真实 MOD 跑通端到端。名动天下数据形态与原版最接近（hdgrp 114 条目、与原版同构），且 ini 有实际差异（分辨率 960x660），能同时验证"数据弹性"和"ini 覆盖"两条路径。

**业务价值**：证明架构可行——MOD 数据经流水线后引擎能完整跑通，后续 18 个 MOD 是重复劳动而非再探索。

**范围**：
- 用 Slice 0 流水线构建 mingdong 数据包
- 审计并修复 mingdong 特有的数据差异（以 `game/mods/mingdong/diff.md` 为准）
- ini 差异生效：分辨率 960x660 等配置

**DoD**（机器可验证）：
1. 完整游玩路径通过：主菜单 → 读档 → smap 移动/进出场景 → 战斗（mingdong fight 数据）→ 事件对话（mingdong kdef 提取脚本）→ 存档 → 读档。
2. 分辨率 960x660 生效（画面尺寸与 ini 一致）。
3. 原版（不指定 MOD）测试全绿，无回归。
4. 事件脚本抽查：mingdong kdef 提取出的事件数与 kdef 条目数一致，抽样 3 个事件对话内容与 MOD 数据一致。

**影响领域**：engine, framework, script (per-MOD build output)
**依赖**：Slice 0
**状态**：done（slice change: [allmods-slice1](../../changes/allmods-slice1/slice-proposal.md)；2 个子 change 全部完成，5 个验收场景通过）

---

### Slice 0b: MOD 兼容地基补漏（资源类型）

Slice 0 的补漏（foundation gap-fill）。2026-10 的资源类型审计发现地基存在**验收漏洞**：4 类资源被静默丢弃或误判，且全部横跨 20 个 MOD（非某个 MOD 特有），因此必须在地基层补齐。

**业务价值**：让 Slice 0 声称的「构建期拍平」与「数据回退链」两条能力**真正完整**；后续 Slice 2-18 无需每个 MOD 重复处理同一处别名/音频问题。

**范围**：

| 子 change | 说明 |
|------|------|
| `allmods-slice0b-smap-rename` | 构建期把 `sdx/smp/wdx/wmp` 映射为 `smap.*`/`wmap.*`（依据 `UPedit.ini` 权威映射）；`diff.md` 识别改名对 |
| `allmods-slice0b-sound-fallback` | 构建期复制 `sound/`；`CC.MIDIFile`/`ATKFile`/`EFile` 支持 MOD 前缀回退 |
| `allmods-slice0b-resource-classify` | 把「设计性回退 / 死参数 / 死文件 / 编辑器副产物」判定固化为可回归测试与权威文档 |

**DoD**（机器可验证）：
1. `lua tools/mod_build.lua --all` → 20 MOD 全部产出 `smap.*`/`wmap.*`，0 个 `sdx/smp/wdx/wmp` 残留，0 build failures。
2. 激活 mingdong → `CC.SMAPPicFile` 指向 MOD 且条目数 = 4635（非原版 4129）；`CC.ATKFile`/`CC.EFile` 前缀为 `mods/mingdong/sound/`。
3. 资源分类断言测试全绿（`test_mod_resources.lua`）。
4. 不指定 MOD 时 `lua tests/test_runner.lua` 全绿；`--verify-pascal` 仍 PASS。

**影响领域**：devops (build pipeline), framework (path constants), tests
**依赖**：Slice 0
**状态**：done（slice change: [allmods-slice0b](../../changes/allmods-slice0b/slice-proposal.md)；3 个子 change 全部完成，DoD 6/6 通过）

---

### Slice 0c: 资源覆盖穷举审计（文件级 + 字段级）

Slice 0b 的**机制补漏**。Slice 0b 修复了已知的 4 类问题；Slice 0c 建立**发现未知问题的机制**。

**业务价值**：把 DoD 从**抽样驱动**改为**穷举驱动**——判定范围由“源文件全集”决定，而非“人写的比对目标”。
Slice 2-18 的每个 MOD slice 可直接复用本 slice 的审计工具做本 MOD 的穷举验收。

**背景**：实测 20 MOD 共 11220 个源文件，其中 1971 个（18%）**无任何 DoD 断言覆盖**；
`diff.md` 只比对 `data/` 目录 → `head/`、`item/`、`eft/`、`music/`、`cc/`、`list/`、dll 天生在盲区。
字节级更糟：全项目仅对 `smap.grp` 一个文件做过逐字节断言。

**范围**：

| 子 change | 说明 |
|------|------|
| `allmods-slice0c-file-inventory` | 新增 `tools/mod_audit.lua`，11220 个源文件逐个归类；`Σ(类别) == 11220` 且**未归类 == 0**（无兜底类别） |
| `allmods-slice0c-format-spec` | 新增 `tools/format_spec.lua`，每种二进制格式的无缺口字段表；`Σ(字段区间) == 文件大小` |
| `allmods-slice0c-unneeded-evidence` | 每个 `needed=false` 给出**可机器校验的证据**；产出 `MOD_RESOURCE_AUDIT.md` |

**DoD**（机器可验证）：
1. `lua tools/mod_audit.lua --all` → `total=11220 unclassified=0`，退出码 0。
2. `lua tools/format_spec.lua --all` → `gaps=0`，20 MOD × 每种格式覆盖完整。
3. 所有 `needed=false` 记录有 ≥1 条结构化且可复现的证据。
4. `MOD_RESOURCE_AUDIT.md` 生成且每行可追溯到 `audit.json`。
5. 不指定 MOD 时 `lua tests/test_runner.lua` 全绿；`--verify-pascal` PASS；`--all` 0 failures。

**影响领域**：devops (audit tooling), docs, tests
**依赖**：Slice 0b（复用其 `ALIAS_MAP`/`IGNORE_DIRS` 作为判据依据）
**状态**：**done**（2026-10-19 完成；slice change: [allmods-slice0c](../../changes/allmods-slice0c/slice-proposal.md)；3 个子 change 均已归档验证）

**实测结果**：

| 门禁 | 命令 | 结果 |
|------|------|------|
| 穷举归类 | `lua tools/mod_audit.lua --all` | `total=11220 unclassified=0 bad_evidence=0` ✅ |
| 证据可执行 | `lua tools/mod_audit.lua --all --evidence` | `checked=17 failed=0` ✅ |
| 字节覆盖 | `lua tools/format_spec.lua --all` | `formats=12 checked=6773 gaps=0` ✅ |
| 全量测试 | `lua tests/test_runner.lua` | 867/867 ✅ |
| pascal 基线 | `lua tools/mod_build.lua --verify-pascal` | `events=1018 mismatches=0` ✅ |
| 产物检查 | `lua tools/mod_check.lua` | 20/20 ✅ |

**本轮发现并修复的真实缺陷**（5 项）：
1. `mod_check.lua` 把新生成的 `mods/_audit/` 当第 21 个 MOD（→ 跳过 `_` 前缀目录）。
2. `save/` 模板（`ranger.*` 等）被判到 `mods/<mod>/save/`，实际应到 `data/`（→ 按 `SAVE_TEMPLATE_NAMES` 分流；`save/` 未进产物从 131 降到 1）。
3. `resource/*.exe`/`*.bat` 触发未归类失败（→ 新增 `PLATFORM_ARTIFACT` 判据）。
4. `--all` 的陈旧产物被审计检出（验证审计器可发现产物陈旧）。
5. `test_mod_resources.lua` 扫描全部 `.lua`，误报新审计工具（→ 收窄为 `runtimeSources()`）。

**数据事实修正**（来自字节级穷举）：
- `war.sta` 记录数**非固定 140**，随 MOD 在 110..438 变化。
- `dream/resource/earth.002` 比其余 19 MOD 多 1 字节（460801）。
- `kys-RiverLake` 有 28 个零字节 WAV。
- `BookCalamity` 的 WAV 在 `data` chunk 后有 `LIST/INFO/ICMT` 元数据块。
- 3 个孤儿 fight 文件（`dream/fight23.idx`、`BookCalamity/fight915.idx`、`awaken/fight099_02.grp`）。
- `mmap.idx` 两段拼接（seg1 3731 项覆盖 grp，tail=0；seg2 5000 项 sentinel）。

**遗留 spike**：`music/*.mid`（663 条 PENDING 的主体）—— MOD 音乐引用分析，需先做 spike 决策。
> **✅ 已完成（2026-10-27）**：[`allmods-spike-music-refs`](../../changes/allmods-spike-music-refs/reports/music-refs-audit.md)（304 行，5 REQ 全实测）。
> 实测结论**推翻了「20/20 MOD 受影响」的高估**：`music/*.mid` 共 **578** 个（去重 151），
> 但**真正受影响仅 3/20 MOD**，其余 **17/20 零影响**（被引用 id 全在 25 个 ogg 内）。
> 分类：**A 类需转换 2 个**（mingdong 26 id、awaken 15 id，去重 34 个唯一 id，最大 id 81）；
> **B 类源侧本就缺 1 个**（BookCalamity 20 个被引用 id 无 `.mid`，MOD 原始缺陷，转换无法修复）；
> **C 类零影响 17 个**（含 `pascal`）。`mid.sf2` 仅 `pascal` 有 ⇒ 若转换则单一依赖点。
> 运行时缺 BGM **静默不崩溃**（`lib_love.lua:588` `pcall` + `:590` 仅 `Debug`）。
> **决策：不阻塞 epic，归为可选增强脚本**（需外部 `timidity`/`fluidsynth`，与「构建期纯 Lua」冲突）。

---

### Slice 2: 瑞安群侠传（kys-SweeOan）端到端

**状态**：**done**（2026-10-19）。slice change: [allmods-slice2](../../changes/allmods-slice2/slice-proposal.md)。

剩余 MOD 清单第 1 梯队第 1 个（hdgrp 115 / fight 92，与基线完全同形）。

| 子 change | 职责 |
|------|------|
| `allmods-sweeOan-activate` | 构建 + 逐文件穷举审计 + 字节级覆盖 + 真实启动链路 |
| `allmods-sweeOan-verify` | `diff.md` 逐条审计 + MOD 独有内容验证 + 报告 |

**DoD 实测**：

| 门禁 | 命令 | 结果 |
|------|------|------|
| 构建 | `lua tools/mod_build.lua kys-SweeOan` | `events=1018` ✅ |
| 穷举归类 | `lua tools/mod_audit.lua --mod SweeOan` | `total=334 unclassified=0` ✅ |
| 字节覆盖 | `lua tools/format_spec.lua --mod SweeOan` | `gaps=0` ✅ |
| 产物检查 | `MOD_SLUG=SweeOan lua tools/mod_check_one.lua` | `STRINGS/EVENTS/SAVE=OK` ✅ |
| 启动链路 | `lua tests/unit/boot_one_mod.lua SweeOan 320 200 84 93 王小石` | `RESULT SweeOan: OK` ✅ |
| 全量测试 | `lua tests/test_runner.lua` | 907/907 ✅ |

**引擎改动**：**零**（同形 MOD，符合预期）。

**本 slice 发现并修复的跨 20 MOD 缺陷**：`game/tools/mod_check_one.lua` 的存档自检直接操作真实产物目录，
`os.remove(dir.."r1.grp")` 会**永久删除** MOD 自带的 `r1.grp`（`mod_check.lua` 对全部 20 MOD 调用）。
修复：自检前备份、自检后字节级恢复。新增 2 个回归测试（`testCheckOneDoesNotDeleteProductSaves`、
`testProductSaveSlotMatchesSource`）。

**为何 Slice 0c 之前未发现**：旧 DoD 只比对 `data/` 目录，`save/` 是盲区。
这是 Slice 0c「穷举驱动 DoD」的首个实际战果。

报告：[sweeOan-verify.md](../../changes/allmods-sweeOan-verify/reports/sweeOan-verify.md)

---

### Slice 3: 威力加强版（kys-stronger）端到端

**状态**：**done**（2026-10-19）。slice change: [allmods-slice3](../../changes/allmods-slice3/slice-proposal.md)。

剩余 MOD 清单第 1 梯队第 2 个（hdgrp 115 / fight 92，与基线完全同形；talk 3727 vs pascal 2977）。

| 子 change | 职责 |
|------|------|
| `allmods-stronger-activate` | 构建 + 逐文件穷举审计 + 字节级覆盖 + 真实启动链路 |
| `allmods-stronger-verify` | `diff.md` 逐条审计 + MOD 独有内容验证 + 报告 + 工具修复 |

**DoD 实测**：

| 门禁 | 命令 | 结果 |
|------|------|------|
| 构建 | `lua tools/mod_build.lua kys-stronger` | `events=1018 talk=3727` ✅ |
| 穷举归类 | `lua tools/mod_audit.lua --mod stronger` | `total=335 unclassified=0` ✅ |
| 字节覆盖 | `lua tools/format_spec.lua --mod stronger` | `gaps=0` ✅ |
| 产物检查 | `MOD_SLUG=stronger lua tools/mod_check_one.lua` | `STRINGS/EVENTS/SAVE=OK` ✅ |
| 启动链路 | `lua tests/unit/boot_one_mod.lua stronger 320 200 84 93 韋大寶` | `RESULT stronger: OK` ✅ |
| 全量测试 | `lua tests/test_runner.lua` | 958/958 ✅ |

**引擎改动**：**零**（同形 MOD）。

**本 slice 修复的 2 个工具缺陷**：
1. **`mod_audit.lua` 的 `kysmod.ini` `in_product` 误判** —— 类别级一刀切无法处理
   「同类不同产物状态」（`kysmod.ini` 在产物中，`cc/*.txt` 不在）。修正为 per-rule 覆盖。
   **连带修正与代码矛盾的证据文本**（原写「不进入产物」）。
2. **`test_mod_boot.lua` 销毁产物 `r1.grp`** —— 与 Slice 2 的 `mod_check_one` 缺陷同源。
   新增备份+恢复与末位断言 `testProductSavesNotDestroyedByTests`。

**方法论意义**：再次印证「同形 ≠ 零问题」—— stronger 的**数据**同形，但**工具链**仍有缺陷。

报告：[stronger-verify.md](../../changes/allmods-stronger-verify/reports/stronger-verify.md)

---

### Slice 4: 失传天书-越女剑（kys-lostbook）端到端

**状态**：**done**（2026-10-19）。slice change: [allmods-slice4](../../changes/allmods-slice4/slice-proposal.md)。

第 1 梯队第 3 个（**最后一个**）：hdgrp 115 / eft 714 / warfld 26 / cloud 9 / title 9 与 pascal 同形，
但**内容更多**：kdef **1071** vs 1018、fight **97** vs 92、talk **3181** vs 2977。

| 子 change | 职责 |
|------|------|
| `allmods-lostbook-activate` | 构建 + 逐文件穷举审计 + 字节级覆盖 + 真实启动链路 + 存档播种 |
| `allmods-lostbook-verify` | `diff.md` 逐条审计 + 内容差异判定 + MOD 独有内容验证 + 报告 |

**DoD 实测**：

| 门禁 | 命令 | 结果 |
|------|------|------|
| 构建 | `lua tools/mod_build.lua kys-lostbook` | `events=1071 talk=3181` ✅ |
| 穷举归类 | `lua tools/mod_audit.lua --mod lostbook` | `total=342 unclassified=0` ✅ |
| 字节覆盖 | `lua tools/format_spec.lua --mod lostbook` | `gaps=0` ✅ |
| 产物检查 | `MOD_SLUG=lostbook lua tools/mod_check_one.lua` | `STRINGS/EVENTS/SAVE=OK` ✅ |
| 启动链路 | `lua tests/unit/boot_one_mod.lua lostbook 320 200 84 93 金迷` | `RESULT lostbook: OK` ✅ |
| 全量测试 | `lua tests/test_runner.lua` | 958/958 ✅ |

**引擎改动**：**零**（同形 MOD）。**发现缺陷：0**。

**内容差异判定（ADR-001）**：kdef/fight 条目数差异是**内容量**差异，非结构异常。
三重机器可验证判据：记录布局常量同（182/190/52/136）+ 记录数同（320/200/84/93）+ 字节全覆盖 `gaps=0`。
若为结构异常，按 pascal 尺寸解析会错位 → `gaps > 0`。

**新增验证点**：lostbook 源**无** `r1.grp`（前两个 MOD 自带）—— 补充验证「首次存档播种」路径：
`SaveRecord(1)` 从 `ranger.idx` 播种 `r1.idx`/`r1.grp`，字符串改写写 `r1.ovr`，验证后无残留。

报告：[lostbook-verify.md](../../changes/allmods-lostbook-verify/reports/lostbook-verify.md)

---

### 第 1 梯队收官小结

| MOD | Slice | 构建 | 穷举 | 字节 | 启动 | 引擎改动 | 缺陷 |
|-----|-------|------|------|------|------|---------|------|
| SweeOan | 2 | ✅ | `unclassified=0` | `gaps=0` | ✅ 王小石 | 零 | 1 |
| stronger | 3 | ✅ | `unclassified=0` | `gaps=0` | ✅ 韋大寶 | 零 | 2 |
| lostbook | 4 | ✅ | `unclassified=0` | `gaps=0` | ✅ 金迷 | 零 | 0 |

**结论**：第 1 梯队（与基线同形）**零引擎改动**，验证了排序假设（数据同形 → 无需引擎改动）。
但前 2 个 MOD 暴露 **3 个工具链缺陷** → 「同形 ≠ 零问题」。

---

### Slice 5: 倚天剑（kys-HeavenSword）端到端

**状态**：**done**（2026-10-19）。slice change: [allmods-slice5](../../changes/allmods-slice5/slice-proposal.md)。

第 2 梯队第 1 个，也是本 epic **第一个 `hdgrp` 条目数 ≠ 115 的 MOD**（**125**）。

| 子 change | 职责 |
|------|------|
| `allmods-heavensword-activate` | 构建 + 逐文件穷举 + 字节级 + 启动链路 + `hdgrp` 差异验证 + 缺陷 D 修复 |
| `allmods-heavensword-verify` | `diff.md` 逐条审计 + `hdgrp` 判定 + 内容验证 + 报告 |

**DoD 实测**：

| 门禁 | 命令 | 结果 |
|------|------|------|
| 构建 | `lua tools/mod_build.lua kys-HeavenSword` | `events=1066 talk=3315` ✅ |
| 穷举归类 | `lua tools/mod_audit.lua --mod HeavenSword` | `total=335 unclassified=0` ✅ |
| 字节覆盖 | `lua tools/format_spec.lua --mod HeavenSword` | `gaps=0` ✅ |
| 产物检查 | `MOD_SLUG=HeavenSword lua tools/mod_check_one.lua` | `STRINGS/EVENTS/SAVE=OK` ✅ |
| 启动链路 | `lua tests/unit/boot_one_mod.lua HeavenSword 320 200 84 93 楊千葉` | `RESULT HeavenSword: OK` ✅ |
| 全量测试 | `lua tests/test_runner.lua` | 1612/1612 ✅ |

**引擎改动**：**零**。

**关键验证：`hdgrp` 差异无需引擎改动**

三重机器可验证判据：
1. **索引驱动**：`PicLoadFile` 用 `local num = idxlen/4`（`lib_love.lua:437`）—— 条目数由文件大小推导
2. **无固定计数**：`CC.HDGRPNum`/`HDPicNum`/`MAX_HEAD_NUM`/`HDGRP`/`HeadNum` 全部 `nil`
3. **字节全覆盖**：`format_spec --mod HeavenSword` → `gaps=0`

→ 判据可**外推到第 2~5 梯队全部** hdgrp ≠ 115 的 MOD（125~350+）。

**本 slice 修复的第 4 个工具缺陷**：`mod_check_one.lua` 的 `SLOTS` 仅列 `r1.*`，
但 `SaveRecord(1)` 还写 `d1.grp`/`s1.grp`（`SaveMMap`/`SaveSMap`）→ 销毁 20 个 MOD 的这两个槽。
这是 `r1.grp` 缺陷（Slice 2/3）的**第三次遗漏**。回归测试强化为「比对源 `save/` 全部文件」。

报告：[heavensword-verify.md](../../changes/allmods-heavensword-verify/reports/heavensword-verify.md)

---

### Slice 6: 天龙八部（kys-GodsDevils）端到端

**状态**：**done**（2026-10-19）。slice change: [allmods-slice6](../../changes/allmods-slice6/slice-proposal.md)。

第 2 梯队第 2 个（**第 2 梯队收官**）。含本 epic **最多 `EDITOR_DUMP`** 文件（279 个 PNG）。

| 子 change | 职责 |
|------|------|
| `allmods-godsdevils-activate` | 构建 + 逐文件穷举 + 字节级 + 启动链路 + `hdgrp` 差异验证 + `EDITOR_DUMP` 确认 + 存档验证 |
| `allmods-godsdevils-verify` | `diff.md` 逐条审计 + `hdgrp` 判据外推记录 + `EDITOR_DUMP` 复核 + 报告 |

**DoD 实测**：

| 门禁 | 命令 | 结果 |
|------|------|------|
| 构建 | `lua tools/mod_build.lua kys-GodsDevils` | `events=1123 talk=4640` ✅ |
| 穷举归类 | `lua tools/mod_audit.lua --mod GodsDevils` | `total=615 unclassified=0` ✅ |
| 字节覆盖 | `lua tools/format_spec.lua --mod GodsDevils` | `gaps=0` ✅ |
| 产物检查 | `MOD_SLUG=GodsDevils lua tools/mod_check_one.lua` | `STRINGS/EVENTS/SAVE=OK` ✅ |
| 启动链路 | `lua tests/unit/boot_one_mod.lua GodsDevils 320 200 84 93 蝦米` | `RESULT GodsDevils: OK` ✅ |
| 全量测试 | `lua tests/test_runner.lua` | 1612/1612 ✅ |

**引擎改动**：**零**。**代码改动**：**零**。

**关键验证 1：`hdgrp` 判据首次外推成功**

| 条件 | HeavenSword | GodsDevils |
|------|-------------|-----------|
| 索引驱动（`idxlen/4`） | ✅ | ✅ |
| 无固定计数常量 | ✅ | ✅ |
| 字节全覆盖 `gaps=0` | ✅ | ✅ |
| 引擎改动 | 0 | 0 |

→ 判据可继续外推到第 3~5 梯队全部 hdgrp ≠ 115 的 MOD。

**关键验证 2：279 个 `EDITOR_DUMP` 有 4 条机器可复核证据**

| # | 证据 | 实测 |
|---|------|------|
| 1 | 构建器忽略 | `IGNORE_DIRS = { head=true, item=true, eft=true }`（`mod_build.lua:567`） |
| 2 | 引擎无引用 | `grep "head/\|item/"` → 0 命中 |
| 3 | 打包格式 | `CC.HeadPicFile` → `hdgrp.idx`/`hdgrp.grp` |
| 4 | 审计规则 | `EDITOR_DUMP` + `EV_UPEDIT_DUMP` |

产物中 `head`/`item` 目录**不存在**。

**关键验证 3：缺陷 D 修复持久性**

GodsDevils 有 **6 个**源自带存档（`d1`/`d2`/`r1`/`r2`/`s1`/`s2`），
比 HeavenSword（仅 `r1.idx`）更丰富 —— 若 Slice 5 的 `SLOTS` 修复遗漏 `d2`/`s2`，本 MOD 会立即暴露。
**全量测试后全 MOD `save/` 与源一致（不一致 = 0）**。

**第 2 梯队收官小结**

| Slice | MOD | hdgrp | 缺陷 |
|-------|-----|------:|------|
| 5 | HeavenSword | 125 | 1（`SLOTS` 遗漏 `d1`/`s1`） |
| 6 | GodsDevils | 129 | **0** |

报告：[godsdevils-verify.md](../../changes/allmods-godsdevils-verify/reports/godsdevils-verify.md)

---

### Slice 7: 小猪闯江湖（kys-pig）端到端

**状态**：**done**（2026-10-19）。slice change: [allmods-slice7](../../changes/allmods-slice7/slice-proposal.md)。

第 3 梯队第 1 个。含本 epic **最多额外战斗**（+45）与 **9 个源自带存档**。

| 子 change | 职责 |
|------|------|
| `allmods-pig-activate` | 构建 + 逐文件穷举 + 字节级 + 启动链路 + `hdgrp` 差异 + 45 场额外战斗验证 + 存档验证 |
| `allmods-pig-verify` | `diff.md` 逐条审计 + 判据第 3 次应用记录 + 额外战斗复核 + 报告 |

**DoD 实测**：

| 门禁 | 命令 | 结果 |
|------|------|------|
| 构建 | `lua tools/mod_build.lua kys-pig` | `events=1288 talk=4123` ✅ |
| 穷举归类 | `lua tools/mod_audit.lua --mod pig` | `total=440 unclassified=0` ✅ |
| 字节覆盖 | `lua tools/format_spec.lua --mod pig` | `gaps=0` ✅ |
| 产物检查 | `MOD_SLUG=pig lua tools/mod_check_one.lua` | `STRINGS/EVENTS/SAVE=OK` ✅ |
| 启动链路 | `lua tests/unit/boot_one_mod.lua pig 320 200 84 93 小小豬` | `RESULT pig: OK` ✅ |
| 全量测试 | `lua tests/test_runner.lua` | 1612/1612 ✅ |

**引擎改动**：**零**。**代码改动**：**零**。

**关键验证 1：`hdgrp` 判据第 3 次应用**

| # | MOD | hdgrp | 结论 |
|---|-----|------:|------|
| 建立 | HeavenSword | 125 | 内容差异 |
| 外推 | GodsDevils | 129 | 内容差异 |
| **第 3 次** | **pig** | **173** | **内容差异** ✅ |

**关键验证 2：45 场额外战斗三重确认**

| # | 证据 | 结果 |
|---|------|------|
| 1 | `diff.md` 提及 | 45 项，各 2 次 |
| 2 | 产物存在 | `fight*.grp` = **137**（92 + 45） |
| 3 | 审计归类 | `REQUIRED` + `in_product=true` |

**关键验证 3：缺陷 D 修复完整性**

pig 有 **9 个**源自带存档（`d1`~`d3`/`r1`~`r3`/`s1`~`s3`），比 GodsDevils（6 个）更多。
若 Slice 5 的 `SLOTS` 修复只补了 `d1`/`s1`，本 MOD 的 `d2`/`d3`/`r2`/`r3`/`s2`/`s3` 会暴露。
**全量测试后全 MOD `save/` 与源一致（341 文件，不一致 = 0）**。

**第 3 梯队进度**

| Slice | MOD | hdgrp | fight | 缺陷 |
|-------|-----|------:|------:|------|
| 7 | pig | 173 | 137 | **0** |
| 8 | lyff | 178 | 138 | **0**（工具修复 +1） |
| **9** | **ptt** | **204** | **162** | **0**（工具加固 +1，no-op） |

报告：[pig-verify.md](../../changes/allmods-pig-verify/reports/pig-verify.md)

---

### Slice 8: 刘亦纷飞版（kys-lyff）端到端

**状态**：**done**（2026-10-22）。slice change: [allmods-slice8](../../changes/allmods-slice8/slice-proposal.md)。

第 3 梯队第 2 个。本 epic **首个记录数差异 MOD**（326 人物段 vs 基线 320），
**最多额外战斗**（+46，超过 pig 的 +45），并触发 **`isStringField` 跨 MOD 工具修复**
（纯 ASCII 文本被误判为数值槽，5 MOD 6 字段）。

| 子 change | 职责 |
|------|------|
| `allmods-lyff-activate` | `isStringField` 修复 + 构建 + 逐文件穷举 + 字节级 + 326 人物段判定 + 启动链路 + 存档验证 |
| `allmods-lyff-verify` | `diff.md` 逐条审计 + 判据统一原则（记录数差异 = hdgrp 判据同族）+ 46 场战斗复核 + 报告 |

**DoD 实测**：

| 门禁 | 命令 | 结果 |
|------|------|------|
| 构建 | `lua tools/mod_build.lua kys-lyff` | `events=1358 talk=5655` ✅ |
| 穷举归类 | `lua tools/mod_audit.lua --mod lyff` | `total=425 unclassified=0` ✅ |
| 字节覆盖 | `lua tools/format_spec.lua --mod lyff` | `checked=242 gaps=0` ✅ |
| 产物检查 | `MOD_SLUG=lyff lua tools/mod_check_one.lua` | `PERSON=326 STRINGS/EVENTS/SAVE=OK` ✅ |
| 启动链路 | `lua tests/unit/boot_one_mod.lua lyff 326 200 84 93 AAA` | `RESULT lyff: OK` ✅ |
| 全量测试 | `lua tests/test_runner.lua` | 1613/1613 ✅ |

**引擎改动**：**零**。**代码改动**：1 处跨 MOD 工具修复（`mod_encoding.lua` `isStringField`）+ 回归测试。

**关键验证 1：326 人物段判定（本 epic 首个记录数差异 MOD）**

| 判据 | 实测 |
|------|------|
| 索引驱动 | `PersonNum = (idx[2]-idx[1])/CC.PersonSize`（`jymain.lua:1747`）；`59332 = 326×182`（pascal `320×182`） |
| 无固定计数 | 全仓库无 `PERSON_NUM` 类常量 |
| 边界有效 | `Person[325]` = 枯榮/南帝（可读） |
| 字节全覆盖 | `gaps=0`（含 326 条人物段） |

**判据统一原则**（可外推第 4~5 梯队）：索引驱动 + 无固定计数 + 字节全覆盖 + 边界有效
= 内容差异（零引擎改动）。`hdgrp`（`idxlen/4`）与记录段（`idx[2]-idx[1]`）同属索引驱动。

**关键验证 2：`isStringField` 守卫（REQ-LYF-0，跨 5 MOD 修复）**

| MOD | 修复字段 | 值 |
|-----|---------|-----|
| lyff | `Person[0].姓名` | `AAA` |
| HeavenSword | `Person[74].姓名` | `killer-G` |
| GodsDevils | `Person[191].外号` | `123` |
| ptt | `Scene[64].名称` | `PTT` |
| dream | `Thing[80].名称`/`别名` | `------` ×2 |

单字节残留（`" "`、`"<"` 等，zheng 31 条 / pineapple 623 条）仍判为数值槽，无误判。
重建 8 MOD；回归测试 +1（1612 → 1613）。

**关键验证 3：46 场额外战斗 + `hdgrp` 判据第 4 次应用**

| # | 判据/证据 | 结果 |
|---|------|------|
| hdgrp | 178（712B = 178×4） | 内容差异 ✅（外推链 125/129/173/178） |
| 战斗 1 | `diff.md` 提及 | 46 场 × 2 = 92 项 |
| 战斗 2 | 产物存在 | `fight*.grp` = **138**（92 + 46） |
| 战斗 3 | 审计归类 | `REQUIRED` + `in_product=true` |

**第 3 梯队进度**

| Slice | MOD | hdgrp | fight | 缺陷 |
|-------|-----|------:|------:|------|
| 7 | pig | 173 | 137 | **0** |
| **8** | **lyff** | **178** | **138** | **0**（工具修复 +1，跨 MOD） |
| **9** | **ptt** | **204** | **162** | **0**（工具加固 +1，no-op） |

报告：[lyff-verify.md](../../changes/allmods-lyff-verify/reports/lyff-verify.md)

---

### Slice 9: PTT（kys-ptt）端到端 —— 第 3 梯队收官

**状态**：**done**（2026-10-28）。slice change: [allmods-slice9](../../changes/allmods-slice9/slice-proposal.md)。

第 3 梯队第 3 个（收官）。本 epic **首个 4 段记录数全部异于基线**的 MOD
（385/214/90/108 vs 320/200/84/93）、**最多额外战斗**（+70，超过 lyff 的 +46）、
**最多源自带存档槽**（18 个，pig 为 9 个）。零引擎改动、**零代码改动**。

| 子 change | 职责 |
|------|------|
| `allmods-ptt-activate` | 构建 + 逐文件穷举 + 字节级 + `hdgrp` 第 5 次判据 + 4 段记录数第 2 次判据 + 70 场战斗三重确认 + 启动链路 + 存档验证 |
| `allmods-ptt-verify` | `diff.md` 逐条审计（154 + 21）+ `eft/` `EDITOR_DUMP` 证据 + PENDING 边界 + 报告 |

**机器可验证 DoD（全部通过）**

| # | 判据 | 命令 | 实测 |
|---|------|------|------|
| 1 | 构建 | `lua tools/mod_build.lua kys-ptt` | `data files=362 saves=21 sound=78 events=1229 talk=5689` ✅ |
| 2 | 穷举归类 | `lua tools/mod_audit.lua --mod ptt` | `total=596 unclassified=0 bad_evidence=0`（= 源文件数 596）✅ |
| 3 | 字节覆盖 | `lua tools/format_spec.lua --mod ptt` | `formats=12 checked=317 gaps=0` ✅ |
| 4 | 产物检查 | `MOD_SLUG=ptt lua tools/mod_check_one.lua` | `PERSON=385 THING=214 SCENE=90 WUGONG=108 HERO=鄉民` ✅ |
| 5 | 启动链路 | `lua tests/unit/boot_one_mod.lua ptt 385 214 90 108 鄉民` | `RESULT ptt: OK`（16 断言）✅ |
| 6 | 存档 | 产物 `save/` 21 文件 vs 源 | **21/21 逐字节一致** ✅ |
**关键验证 1：`hdgrp` 204 —— 判据第 5 次应用**

`hdgrp.idx` = 816 B = 204 × 4；`PicLoadFile` 用 `idxlen/4`（`lib_love.lua:437`）；
固定计数常量全 `nil`；`gaps=0`。→ **内容差异**。
外推链：**125 → 129 → 173 → 178 → 204**（五次一致）。

**关键验证 2：4 段记录数全异 —— 统一判据第 2 次应用**

| 段 | 段长 | 记录大小 | 条数 | 整除 | 基线 | 边界 hint |
|----|-----:|--------:|-----:|:----:|-----:|-----------|
| Person | 70070 | 182 | **385** | YES | 320 | `P0489`/`N0448` |
| Thing  | 40660 | 190 | **214** | YES | 200 | `T0395`/`T20395`/`TD0395` |
| Scene  |  4680 |  52 | **90**  | YES |  84 | `S0088` |
| Wugong | 14688 | 136 | **108** | YES |  93 | `W0107` |
| Shop   |   150 |  50 | **3**   | YES |   3 | — |

索引驱动（`jymain.lua:1747`）+ 无固定计数 + 字节全覆盖 + 边界有效（卓不凡/高昌迷宮地圖/
計老人居/天魔極樂）→ **内容差异**（零引擎改动）。
**本 epic 首个 4 段全异 MOD**（lyff 仅 Person 段差异）。

**关键验证 3：70 场额外战斗（本 epic 最多）**

| 战斗 1 | `diff.md` 提及 | 140 项（70 场 × 2） |
| 战斗 2 | 产物存在 | `fight*.grp` = **162**（92 + 70）；`comm -13` 差集 = 70 |
| 战斗 3 | 审计归类 | 162 个**全部** `REQUIRED`/`in_product=true`，其他类别 = 0 |

抽样 5 场（`fight073`/`fight130`/`fight154`/`fight195`/`fight216`）逐项复核通过。
`change-manifest.md` Contract F 的 70 场清单与实测差集**精确一致**（70/70）。

**关键验证 4：存档 18 槽 —— 首次拆分「在 save/」与「首次播种」**

ptt 源 `save/` 28 文件，其中只有 3 个 `.idx`（`alldef`/`allsin`/`ranger`），
**9 个 `rN.idx`/`dN.idx`/`sN.idx` 源不存在** —— 靠 `ModData.SeedSaveSlot(id)`
从 `data/ranger.idx` 派生（实测：播种后与模板逐字节一致）。
本 epic 首次把「基准独有」拆为 4 类：**在 save/ 9 + 首次播种 9 + 回退原版 2 + 死文件 1 = 21**。

**关键验证 5：105 个 `eft/` PNG = `EDITOR_DUMP`**

4 条机器可复核证据：`IGNORE_DIRS` 含 `eft=true`（`mod_build.lua:567`）+
引擎 0 引用 + 产物无 `eft/` + 审计 105 项全 `EDITOR_DUMP`/`in_product=false`。
与 Slice 6 的 `head/`/`item/`（279 个）同族。

**本 slice 零缺陷**。唯一代码改动是把 Slice 8 的 `isStringField` 从裸高位测试
加固为「高位字节须全 Big5 可解码」（Slice 8 遗留项收尾）——
对真实数据**逐字节 no-op**（20/20 `ranger.str` md5 不变），仅消除假阳性 + 补 9 条回归断言
（测试 **1613 → 1622**）。

**第 3 梯队进度（收官）**

| Slice | MOD | hdgrp | fight | 记录段 | 缺陷 |
|-------|-----|------:|------:|--------|------|
| 7 | pig | 173 | 137 | 320/200/84/93 | **0** |
| 8 | lyff | 178 | 138 | **326**/200/84/93 | **0**（工具修复 +1） |
| **9** | **ptt** | **204** | **162** | **385/214/90/108** | **0**（工具加固 +1，no-op） |

报告：[ptt-verify.md](../../changes/allmods-ptt-verify/reports/ptt-verify.md)

---

### Slice 10: 再战江湖（kys-RiverLake）端到端 —— 第 4 梯队开场

**状态**：**done**。slice change: [allmods-slice10](../../changes/allmods-slice10/slice-proposal.md)。
子 change：[activate](../../changes/allmods-riverlake-activate/proposal.md) /
[verify](../../changes/allmods-riverlake-verify/proposal.md)。

第 4 梯队第 1 个（`hdgrp` 252 / `fight` 219 / `talk` 8015 全场最多）。
本 slice 引入 **Scene 阴性对照**方法（记录数相同 ⇒ 必须用内容证明）、
**「基准独有」第 4 类「死文件」**、以及两项**范围外既有缺陷**的完整取证。

**6 步模板结果**

| # | 步骤 | 命令 | 输出 |
|---|------|------|------|
| 1 | 构建 | `lua tools/mod_build.lua kys-RiverLake` | `data files=478 saves=21 sound=170 events=1232 talk=8015` ✅ |
| 2 | 穷举归类 | `lua tools/mod_audit.lua --mod RiverLake` | `total=699 in_product=666 not_in_product=33 unclassified=0 bad_evidence=0`（= 源文件数 699）✅ |
| 3 | 字节覆盖 | `lua tools/format_spec.lua --mod RiverLake` | `formats=12 checked=413 gaps=0` ✅ |
| 4 | 产物检查 | `MOD_SLUG=RiverLake lua tools/mod_check_one.lua` | `PERSON=325 THING=249 SCENE=84 WUGONG=96 HERO=茲` ✅ |
| 5 | 启动链路 | `lua tests/unit/boot_one_mod.lua RiverLake 325 249 84 96 茲` | `RESULT RiverLake: OK`（16 断言）✅ |
| 6 | 报告 | `reports/riverlake-verify.md` | 6 章节齐备 ✅ |

**关键验证 1：Scene 阴性对照（本 epic 首次正式化）**

Person/Thing/Wugong 三段记录数均异（325/249/96 vs 320/200/93），但 **Scene 段 84 = 基线 84**。
故「记录数相同」**不能**作为 MOD 内容已加载的证据 —— 改用**内容**证明：

| 记录 | RiverLake | pascal | 相同 |
|------|-----------|--------|:----:|
| `Scene[0]` | **盛京** | 胡斐居 | ❌ |
| `Scene[1]` | 河洛客棧 | 河洛客棧 | ✅（MOD 保留原版） |
| `Scene[2]` | **靈鷲宮** | 雲鶴崖 | ❌ |
| `Scene[83]` | **圣堂** | 聖堂 | ❌（简繁差异） |

3/4 不同 ⇒ **内容差异**（零引擎改动）。`Scene[1]` 相同不构成「回退」证据。

**关键验证 2：`hdgrp` 252 —— 判据第 6 次应用**

`hdgrp.idx = 1008B → 252`；索引驱动（`lib_love.lua:437` `num = idxlen/4`）+ 无固定计数常量 +
`gaps=0`。外推链 **125 / 129 / 173 / 178 / 204 / 252** 六次一致。

**关键验证 3：127 场额外战斗 —— 首次发现 0 字节 fight 文件**

pascal 92 → RiverLake **219**（+127）。三重确认（`diff.md` 127 / 产物差集 127 / 审计全 `REQUIRED`），
127/127 有配对 `.idx` 且尺寸一致。

**新发现**：差集 127 项中 **44 项为 0 字节**，源↔产物 127/127 **尺寸完全一致**，
源 0 字节集合 == 产物 0 字节集合。全域分布：

| MOD | fight 总数 | 0 字节 |
|-----|----------:|-------:|
| **pineapple** | 154 | **115** |
| **RiverLake** | 219 | **44** |
| ptt | 162 | 7 |
| books | 178 | 2 |
| loving | 107 | 2 |
| 其余 15 个（含 pascal） | — | 0 |

**34/44 被运行时引用**（`Person["头像代号"]` 最大 216，文件缺失 0 个）；
引擎优雅降级实测：`PicLoadFile` pcall=true、`PicGetXY` 返回 0，不崩溃。
⇒ 保留（删除会破坏 `fight%03d` 位置索引语义，让 34 个 Person 更差）、不补（伪造）。

**关键验证 4：21 项「基准独有」四类定性 —— 首次引入「死文件」**

| 类别 | 项数 | 判据要点 |
|------|-----:|----------|
| **A 在 save/（源自带存档）** | 9 | `d1`~`d3`/`r1`~`r3`/`s1`~`s3` `.grp`，源↔产物**逐字节一致** |
| **B 首次播种** | 9 | 对应 9 个 `.idx`；`CC.R_IDXFilename[1] = mods/RiverLake/save/r1.idx`（**MOD** 目录）；`SeedSaveSlot(1)` 实测 == MOD `ranger.idx`（True）/ == 基线（False） |
| **C 回退原版** | 2 | `thing.{grp,idx}`；源 `resource/` 无；`CC.ThingPicFile = data/thing.*`（**基线**目录） |
| **D 死文件** | **1** | `allsinbk.grp`；`CC.TempS_Filename` 传入 `LoadSMap`，但 `tmpfilename` 形参**零引用** |

Σ = 9 + 9 + 2 + 1 = **21** ✅

**D 的代码级证据**：`grep -n tmpfilename game/engine-love2d/lib_love.lua` **仅 1 处命中 = 函数签名**
（`:890`），函数体内无引用 ⇒ 路径被传入但内容永不读取。
本 epic 首个「**路径被引用 ≠ 内容被使用**」样本。

B/C/D 三分的可执行判据：**打印 `CC.*` 运行时解析值** —— B 指向 MOD 存档目录、
C 指向基线 `data/`、D 指向基线但代码不读。

**关键验证 5（范围外缺陷，只记录不修复）：`CC.Effect` 硬编码 53 项截断**

`script/jyconst.lua:439` 的 `CC.Effect` 是 53 项字面量表（sum=712，`[0]=9`），
而 `war_async.lua:1106/1126` 用它算动画帧。**7/20 MOD 的 eft id 越出上界 52**：

| MOD | wugong | eft max | 越界条数 | `effect.bin` 项 | `eft.idx` |
|-----|-------:|--------:|---------:|----------------:|----------:|
| pascal（基线） | 93 | 52 | 0 | 64 | 714 |
| **RiverLake** | 96 | **69** | **10** | 70 | 921 |
| books | 100 | 55 | 2 | 64 | 973 |
| awaken | 163 | 53 | 1 | 64 | 727 |
| **pineapple** | 174 | **83** | **62** | 84 | 1378 |
| **pig3dos** | 202 | **85** | **52** | 64（**21 越界**） | 714 |
| **mingdong** | 220 | **168** | **136** | 200 | 2268 |
| **BookCalamity** | 398 | **198** | **296** | 200 | 2857 |

**语义关系**（实测纠正）：`list/effect.bin` = **每效果**帧数（int16），
`eft.idx` = **逐帧**偏移表，`sum(effect.bin)` == `eft.idx` 条目数——
**3 MOD 精确相等**（RiverLake 921 / BookCalamity 2857 / pineapple 1378），
其余因尾部补零差 1–44。权威来源 `reference/allmods/UPedit/UPedit.ini:80`
`Effect=list\effect.bin`，20/20 MOD 均有该文件。

**非致命**：`CC.Effect[eft]` 为 nil ⇒ `or 10` 回退；`CC.Effect[i]` 为 nil ⇒ `or 0`。
实测 `eft=69 → framenum=15, starteft=40`（应为 15/229），不抛错不崩溃，仅动画帧错位。
基线 `CC.Effect[0]=9` vs `effect.bin[0]=10` 同样有 1 帧既存偏差。

**不修复理由**：① `CC.Effect` 在 `script/jyconst.lua`，属**负约束禁改路径**；
② 修复需在 `mod_data.RewriteConstants` 按 `effect.bin` 重建，并把 `list/effect.bin`
从 `PENDING`（20 MOD 各 1 项）提升为 `REQUIRED` —— 改动 20 MOD 审计分类、构建管线与产物清单，
属**独立 change**，超本 slice Blast Radius。已入 [TODO.md](TODO.md) epic 级 spike。

**关键验证 6（缺陷 F，第 6 个工具缺陷，已修复）**

`test_mod_boot.testSaveLoadRoundTripWithMingdong` 写 `mods/mingdong/save/`，仅在**正常结束**时
恢复；被中断（超时 kill / 断言抛错）后脏槽残留。runner 顺序 `mod_resources`(16) **先于**
`mod_boot`(21)，下次运行读到脏槽 → 4 条 mingdong 假失败。

修复：`test_mod_resources` 新增 `restoreAllProductSaves()` —— 比对前按源包**自愈式重建**
20 MOD 产物 `save/`（源有则逐字节拷回，源无则删除残留）。测试从此**幂等**，
不依赖执行顺序或上一轮是否正常结束。

测试数 **1622 → 1842**（+220）= 覆盖扩充（此前因文件缺失被 `else` 跳过的比对断言恢复执行），
非新增断言。

**关键验证 7：28 个 0 字节 WAV（`e72`~`e98`）**

原样保留（不补静音、不删除，保护「产物 = 源 + 格式转换」与音效 ID 索引）；
`PlayWAV`（`lib_love.lua:602-621`）用 `pcall` 包裹，静默返回，运行不中断。

**门禁（全 Green）**

| # | 门禁 | 结果 |
|---|------|------|
| 1 | `tests/test_runner.lua` | **1895/1895** |
| 2 | `mod_build --verify-pascal` | `mismatches=0` PASS |
| 3 | `mod_build --all` | `20 mods, 0 build failures`（退出码 1 属既有设计） |
| 4 | `mod_check.lua` | **20/20** |
| 5 | `mod_audit --all --evidence` | `unclassified=0 bad_evidence=0`，`failed=0` |
| 6 | `format_spec --all` | `formats=14 checked=6826 gaps=0` |
| 7 | 20 MOD `save/` vs 源 | **451 文件，真实问题 0**（430 逐字节一致 + 21 项设计内转换，见 `allmods-dragon-verify/tasks.md` §15.9） |
| 8 | 脏态幂等 | 959/959 |

**第 4 梯队进度**

| Slice | MOD | hdgrp | fight | 记录段 | 缺陷 |
|-------|-----|------:|------:|--------|------|
| **10** | **RiverLake** | **252** | **219** | **325/249/84/96** | **0**（工具缺陷 F +1，已修复） |
| **11** | **Dragon** | **267** | **209** | **589/237/106/114** | **0**（3 条精度发现，非缺陷） |
| **12** | **pineapple** | **300** | **154** | **720/344/118/174** | **0**（115 零字节 fight 全溯源；Person 与 grp 均为第 2） |
| **13** | **books** | **696** | **178** | **382/200/84/100** | **0**（`hdgrp` 696 全 MOD 第 1；`kdef` 573 全 MOD 最少；4 个 `FILE_MISSING` 被引用，源侧本缺） |

报告：[riverlake-verify.md](../../changes/allmods-riverlake-verify/reports/riverlake-verify.md)

---

### Slice 11: 苍龙逐日（kys-Dragon）端到端 —— 第 4 梯队第 2 个

沿用 Slice 10 的 6 步模板，一次跑通。

| 步 | 命令 | 实测输出 | 判 |
|----|------|----------|----|
| 1 | `mod_build.lua kys-Dragon` | `data files=458 saves=21 sound=80 events=1087 talk=4020` | ✅ |
| 2 | `mod_audit.lua --mod Dragon --evidence` | `total=811 in_product=555 not_in_product=256 unclassified=0 bad_evidence=0` | ✅ |
| 3 | `format_spec.lua --mod Dragon` | `formats=12 checked=535 gaps=0` | ✅ |
| 4 | `MOD_SLUG=Dragon mod_check_one.lua` | `PERSON=589 THING=237 SCENE=106 WUGONG=114`，`HERO=資`，`STRINGS/EVENTS/SAVE=OK` | ✅ |
| 5 | `boot_one_mod.lua Dragon 589 237 106 114 資` | `RESULT Dragon: OK`，**16/16 断言 PASS** | ✅ |
| 6 | `diff.md` 双向 set 相等 | MOD 独有 **254/254**、基准独有 **25/25**，双向差集 `[]` | ✅ |

审计类别闭合：`REQUIRED 550 / REQUIRED_CONVERTED 4 / LEGACY 5 / DEAD_FILE 1 /
EDITOR_DUMP 220 / BUILD_INPUT 2 / PENDING 29`，Σ = 811 = 源文件总数。

#### 规模（第 4 梯队最大）

| 项 | 基线 | Dragon | 变化 |
|----|-----:|-------:|------|
| 源 `resource/` 文件 | — | 811 | — |
| `hdgrp` 条目 | 115 | **267** | +152（**全 20 MOD 最多**） |
| `fight*.grp` | 92 | 209 | +117（+119 −2） |
| `eft` 条目 | 714 | 714 | 0（**md5 与基线相同**） |
| 记录段 | 320/200/84/93 | **589/237/106/114** | 全面扩张 |

`ranger.idx` offsets = `[836, 108034, 153064, 158576, 174080, 174230]`，
`(589, 237, 106, 114, 3)` 余数全 0 —— **四段全部异于基线**（判据第 4 次应用）。

#### `hdgrp` 267 —— 索引驱动判据第 7 次应用

```
hdgrp.idx = 1068B → 1068/4 = 267
lib_love.lua:437   local num = idxlen/4
```

无固定计数常量（`CC.HeadPicFile` 只有路径）。外推链：
**125 → 129 → 173 → 178 → 204 → 252 → 267**。

#### 内容真实性四类证据

| 类 | 证据 |
|----|------|
| 记录边界值 | `資`/`李卡多`、`小還丹`/`真武劍`、`胡斐居`/`西部農村`、`普通攻擊`/`閃電貂` |
| 事件 | `mods/Dragon/script/oldevent/*.lua` = **1087** = 构建报告 `events=1087` |
| 对话 | `oldtalk.idx` 16080B = **4020** 条目；`[1]`「小兄弟，到此寒天雪地，不知有何指教？」`[4018]`「国家兴亡，匹夫有责！」 |
| ini 常量 | **10 项**基线为 `nil` 的常量跳变：MaxLevel 60 / MaxHP 999 / MaxMP 9999 / MaxPhysicalPower 100 / MaxItemAmount 200 / ItemBeginPic 4131 / MaxWeaponMatch 7 / MinKnowledge 80 / LifeHurt 10 / ExpRate 1 |

#### Scene 内容负对照（第 5 次应用）

| 索引 | Dragon | 基线 | 判 |
|-----:|--------|------|----|
| 0 | 胡斐居 | 胡斐居 | 同 |
| 1 | 河洛客棧 | 河洛客棧 | 同 |
| 2 | **雪山** | 云鶴崖 | **异** ✅ |
| 105 | 西部農村 | — | — |

**Scene 记录数 106 = 106，内容不同** ⇒ 记录数相等 ≠ 内容相同。

#### `diff.md` 254 项 MOD 独有

119 `fight*.grp` + 119 `fight*.idx` + **16 非 fight** = 254。
16 项中 15 项与源**逐字节相同**，`ranger.str` 由构建生成（`mod_build.lua:1174`）。

25 项基准独有五分法：**A 9 / B 9 / C 2 / D 1 / E 4**。
**E 类是本 epic 首次出现**：`fight101`/`fight102` 的 4 个文件
—— 数据仍引用但资源缺失（见下）。

#### 三个独特之处（本 MOD 专属）

**① `fight101/102` 缺失：数据仍引用、引擎优雅降级**

`Person` 中 588/589 条有头像代号，max=219，引用 101 者 1 条、102 者 1 条，
但 MOD 删除了这两个贴图包。

| 场景 | `PicLoadFile` | `PicGetXY(4, 0/2/4/6)` |
|------|---------------|------------------------|
| `fight101`（缺失） | `pcall=true err=nil` | **0,0 / 0,0 / 0,0 / 0,0** |
| `fight103`（存在，**正对照**） | `pcall=true err=nil` | **33×63 / 74×67 / 74×70 / 72×69** |

链路：`FileLength` → `-1`（`lib_love.lua:283-289`）→ `PicLoadFile` 早退（`:435`）
→ `getPic` 返回 `nil`（`:269-273`）→ `PicGetXY` 返回 `0,0`（`:465-468`）。

判定：MOD 作者侧数据不一致；**不补文件、不改头像代号**。

> ⚠ `PicGetXY` **裸调**（未先 `PicLoadFile`）会抛 `lib_love.lua:462 attempt to index a nil value`，
> 不能作降级证据 —— 该错误源于调用前置条件不满足。

**② `war1.sta`：两种判定不矛盾**

`66030B ÷ 186 = 355` 记录；源=产物（md5 同）；基线不存在；
`CC.WarFile` 只 `war.sta`（`jyconst.lua:129`）；`grep -rn "war1"` → **0 命中**。

`DEAD_FILE` 回答「引擎需要读它吗」（否）；`diff.md` MOD 独有回答「相对基线新增吗」（是）。
**「新增但不用」，两判定都正确。**

必须与 RiverLake `allsinbk.grp` 区分：

| | RiverLake `allsinbk.grp` | Dragon `war1.sta` |
|---|---|---|
| 归属 | 基准独有（D 类） | MOD 独有 |
| 常量 | ✅ `CC.TempS_Filename` | ❌ |
| 传参 | ✅ 入 `LoadSMap` | ❌ |
| 性质 | 「**回退到的**文件是死的」 | 「**新增的**文件是死的」 |

**③ `head/` 220 PNG = EDITOR_DUMP（同族判定第 3 次）**

`mod_build.lua:567` `IGNORE_DIRS = { head = true, item = true, eft = true }`；
引擎 0 引用；产物无 `head/` 目录。
（同族：GodsDevils 279 / ptt 105 / Dragon 220）

#### 3 条「精度发现」（非缺陷）

| # | 发现 | 证据 | 处置 |
|---|------|------|------|
| 1 | `not_in_product=256` ≠ 物理缺失 | 4 项物理存在（`name.grp`/`name.idx`/`talkutf8.txt`/`war1.sta`）+ 252 真缺 = 256；`mod_audit.lua:453-462` 关卡 2 按类别否决 | 语义不精确，不改（需同步 12 个既有 slice） |
| 2 | `cloud/title/open/end` 无运行时消费者 | 4 类全部 0 命中；`CC.CloudPicFile` 等全 `nil`；`end.png` 的唯一命中读的是基线 `pic/end.png`（md5 不同） | `BY_KIND` 兜底归类，保守 = 无害，不改 |
| 3 | `name.*` = `talk.*` 副本 | md5 `4c41c044…`/`1a0c74ab…` 两侧相同 | 历史遗留 + 「`resource/` 一律展平」契约 |

#### 缺陷

**0**。前 10 个 slice 累计的 6 个工具缺陷（A~F）在 Dragon 上均未复现或已修复。

**唯一修正**（非缺陷，属文档口径）：门禁 7「20 MOD `save/` vs 源」的
「451 文件，不一致 = 0」**表述错误**。实测：

```
源 save/ = 451
  逐字节一致 = 430
  差异       = 21   ← ranger.grp ×20（Big5→UTF-8+hint，真值进 ranger.str）
                     + ranger.idx ×1（zheng，RepairIdx 重建段边界）
  真实问题   = 0
```

`mod_build.lua:665-670` 按 `isSaveSlotFile`（`:626-631`）把 `save/` 分两类：
槽文件 → `mods/<m>/save/`（341 个），模板 → `mods/<m>/data/`（110 个）。
已在 `allmods-dragon-activate/verification.md`、本表、`allmods-dragon-verify/tasks.md` §15.9 三处同步修正。

#### 8 道门禁

| # | 门禁 | 实测 |
|---|------|------|
| 1 | `tests/test_runner.lua` | **1895/1895** |
| 2 | `mod_build --verify-pascal` | `mismatches=0` PASS |
| 3 | `mod_build --all` | `20 mods, 0 build failures`（退出码 1 属设计） |
| 4 | `mod_check.lua` | **20/20** |
| 5 | `mod_audit --all --evidence` | `unclassified=0 bad_evidence=0`，`failed=0` |
| 6 | `format_spec --all` | `formats=14 checked=6826 gaps=0` |
| 7 | 20 MOD `save/` vs 源 | **451 文件，真实问题 0**（430 全等 + 21 设计内转换） |
| 8 | 禁改路径 | `git status` 三处为空；`jyconst.lua` 无 `CC.*=` 定义行增删 |

报告：[dragon-verify.md](../../changes/allmods-dragon-verify/reports/dragon-verify.md)

---

### Slice 12: 再破菠萝（kys-pineapple）端到端 —— 第 4 梯队第 3 个

沿用 Slice 10/11 的 6 步模板。pineapple 在全部 20 个 MOD 中：
**零字节 fight 最多（115，第 1）**、**`CC.Effect` 越界最严重（62/174 = 35.6%）**、
**`Person` 记录第 2（720；BookCalamity 800 第 1，awaken 亦 720）**
（⚠ 初稿称「Person 最多 / `ranger.grp` 最大」已实测修正为**第 2**）。

| 步骤 | 命令 | 实测 |
|------|------|------|
| 1 构建 | `lua tools/mod_build.lua kys-pineapple` | `data files=348, saves=30, sound=109, events=1068, talk=3596` |
| 2 穷举审计 | `mod_audit.lua --mod pineapple --evidence` | `total=529 in_product=484 not_in_product=45 unclassified=0 bad_evidence=0` |
| 3 字节级覆盖 | `format_spec.lua --mod pineapple` | `formats=12 checked=289 gaps=0` |
| 4 产物四项 | `MOD_SLUG=pineapple mod_check_one.lua` | `PERSON=720 THING=344 SCENE=118 WUGONG=174 HERO=蘿卜大` |
| 5 启动链路 | `boot_one_mod.lua pineapple 720 344 118 174 蘿卜大` | `RESULT pineapple: OK`，16/16 PASS |
| 6 差异审计 | `diff.md` 双向 set-equal | 140 独有 / 21 基线独有，双向 `True` |

**关键数据**

| 项 | 值 |
|----|----|
| 源文件 | 529 |
| `ranger.idx` 偏移 | `[1860,132900,198260,204396,228060,228210]`，`ranger.grp` 229680B |
| 记录段 | `720 / 344 / 118 / 174`（+ Shop 3），全部余 0 |
| `hdgrp` | 300 条目（`hdgrp.idx` 1200B） |
| `eft` | 1378 条目（`eft.idx` 5512B，`eft.grp` 2266744B） |
| fight | 154 个（基线 92）→ **A 同名同容 2 / B 同名异容 90 / C 独有 62 / D 零字节 115** |
| 基线独有 | 21 = **18 存档槽改道 + 3 模板回退 + 0 真删除** |

**本 slice 的四个核心发现**

1. **零字节 115 个全部溯源为源文件 0B** —— `源也 0B: 115 / 源非 0B: 0`。
   `mod_build.lua` 只是忠实复制，**非构建缺陷**。
   且 `fight072`（57822B）是 `fight016`~`fight131` 零字节区间内的**唯一非零例外**，
   证明零字节不是「区间一刀切」。
2. **`diff.md` 存在结构性盲区** —— 它只报「基线无此名」，
   **漏掉 90 处同名异容改写**（B 类）。必须用四象限补全才能审全 154 个 fight。
   这是首个把该盲区量化的 MOD。
3. **`CC.Effect` 项数必须用 `pairs` 计数** —— `#CC.Effect` 返回 52，
   真实键 `0..52` = **53 项**（`[0]` 显式键使 `#` 不可靠）。
   越界判据 `eft > 52`，实测 **62 条 / 28 个不同值**，
   且退化是**饱和**的（`eft=53` 与 `eft=83` 结果相同，`framenum=10`、`starteft=712`），不崩溃。
4. **21 条基线独有中真删除为 0** —— 18 个存档槽改道 `save/`（长度全等），
   3 个（`thing.*`、`allsinbk.grp`）由 `ModData.Resolve` 回退基线且实测 EXISTS。
   **不得**表述为「MOD 删除了 21 个基线文件」。

**8 道门禁复跑**

| # | 门禁 | 结果 |
|---|------|------|
| 1 | 单元测试 | `1895 / 1895 通过 / 0 失败` |
| 2 | `mod_build --verify-pascal` | `mismatches=0` PASS |
| 3 | `mod_build --all` | `20 mods, 0 build failures`（退出码 1 属设计） |
| 4 | `mod_check.lua` | **20/20** |
| 5 | `mod_audit --all --evidence` | `unclassified=0 bad_evidence=0`，`failed=0` |
| 6 | `format_spec --all` | `formats=12 checked=6773 gaps=0` |
| 7 | 20 MOD `save/` vs 源 | 槽 **341** + 模板 **110** = 451，真实问题 **0** |
| 8 | 禁改路径 | `git status` 三处为空；`jyconst.lua` 无 `CC.*=` 定义行增删 |

**缺陷数：0。**

报告：[pineapple-verify.md](../../changes/allmods-pineapple-verify/reports/pineapple-verify.md)

---

### Slice 13: books（最后一个 MOD）— ✅ 已完成

| 项 | 结果 |
|----|------|
| 源文件 | **525** |
| 构建 | `data files=392, saves=19, sound=84, events=573, talk=6655` |
| 穷举审计 | `total=525 in_product=495 not_in_product=30 unclassified=0 bad_evidence=0`；`490+4+3+1+27=525` ✅；`evidence: checked=8 failed=0` |
| 字节覆盖 | `formats=12 checked=287 gaps=0` |
| 记录段 | `Person 382` / `Thing 200` / `Scene 84` / `Wugong 100`（基线 320/200/84/93） |
| 启动链路 | `RESULT books: OK`（`CC.SceneSize=52`、`CC.WugongSize=136`，扫描字段 1548） |
| `diff.md` | `added 184`（172 fight + 12 非 fight）/ `removed 21`（13 槽改道 + 5 缺席 + 3 模板 + **0 真删除**），**双向集合相等** |
| fight 四象限 | `A 89 / B 3 / C 86 / D 2`；`A+B=92` ✅、`A+B+C=178` ✅、`D∩B=0`、`D∩C=2` |
| `hdgrp` | **696**（全 20 MOD 第 1）= 474 有效 RLE + **222 零长段**（RLE 重复帧），头异常 **0** |
| `Wugong` | 100 条 × **64 字段**全对齐（全 nil 字段 0）；`武功动画&音效` 越界 **2** 条（max 55） |
| `ranger.grp` | **126478**（**比基线 136412 更小**，第 9/20）；`ranger.str` 侧表 **957** 条 |
| `FILE_MISSING` | **4 个被引用**：`fight030`(風清揚)/`039`(石中玉)/`066`(段正淳)/`110`(張召重)——**epic 首个真实实例** |
| 缺陷 | **0 构建缺陷**；5 类 MOD 原始缺陷（源侧本有，不修） |

**独特性**：

1. **`hdgrp` 696 = 全 20 MOD 第 1**（dream 484 / pig3dos 412 / BookCalamity 373 / pineapple 300），
   且 222 个零长段是 RLE 重复帧（同家族 `eft` 零长仅 1 ⇒ 内容特征非格式缺陷）。
2. **`kdef` 573 = 全 20 MOD 最少**（次少 1018，最多 dream 4569）。
   配合 `talk 6655` ⇒ **每事件 11.6 条对话**（pineapple 仅 3.4）——「少事件、长对话」结构。
3. **fight 分布与 pineapple 互为极端**：books `A 89/B 3`（B 占比 **3.3%**，保留基线+新增），
   pineapple `A 2/B 90`（B 占比 **97.8%**，改写存量）。两者 `fight` 总数接近（178 vs 154）
   但**性质完全相反** ⇒ 本 epic 中「不能用总数代替四象限」的最强论据。
4. **`FILE_MISSING` 4 个被引用实例**（epic 首个）：4 个 NPC 的头像代号指向不存在的 fight 包，
   源目录与基线目录**均缺** ⇒ MOD 原始缺陷。运行时 `PicGetXY` 返回 `0,0` 不崩溃，
   且与 `ZERO_BYTE` **不可区分**（须靠文件事实 + `lib_love.lua:435` 代码路径判定）。
5. **`ranger.grp` 比基线更小**（126478 < 136412）而 `Person` 更多（382 > 320）——
   因基线 Thing 段更大（52000 vs 38000）。
6. **`removed` 21 的三分法**：13 槽改道 `save/`（md5 13/13 全同）+ 5 槽缺席走回退 +
   3 模板回退 + **0 真删除**。且 `save/` 19 与 `removed` 18 **不是同一集合**。
7. **`ranger.str` 957 条侧表**：`P0000`/`N0001` 是设计内 hint（定宽字段装不下 UTF-8，
   就地重编码会截断 41%），运行时回填为 `古天奇`/`天下奇男子`。

子 change：`allmods-books-activate`（构建+启动+内容真实性）、
`allmods-books-verify`（diff 审计+四象限+报告）。
报告：[books-verify.md](../../changes/allmods-books-verify/reports/books-verify.md)

### Slice 14: dream（笑梦游记）— ✅ 已完成

| 项 | 结果 |
|----|------|
| 源文件 | **416**（fight 245 / sound 77 / save 31 / resource 30 / music 25 / list 6 / script 1 / root 1） |
| 构建 | `data files=280`（目录实测 **281**，差 1 为生成的 `ranger.str`）/ `saves=27` / `sound=77` / `events=4569` / `talk=6464` |
| 穷举审计 | `total=416 in_product=383 not_in_product=33 unclassified=0 bad_evidence=0`；`378+4+3+1+1+29=416` ✅；`evidence: checked=9 failed=0` |
| 字节覆盖 | `formats=12 checked=225 gaps=0` |
| 记录段 | `Person 409` / `Thing 192` / `Scene 122` / `Wugong 102` / `Shop 6`（基线 320/200/84/93/3）——**5/5 全异** |
| 启动链路 | `RESULT dream: OK`（`CC.PersonSize=182`、`ThingSize=190`、`SceneSize=52`、`WugongSize=136`；扫描字段 1618；16 断言全 PASS） |
| `diff.md` | `added 156`（71 组 fight 配对 142 + 孤儿 `fight23.idx` 1 + 13 非 fight）/ `removed 105`，**双向集合相等**（对称差空集） |
| fight 五分类 | `A 2 / B 49 / E 41（删除）/ C 71 / D 0`；`A+B+E=92` ✅、`A+B+C=122` ✅、`92−41+71=122` ✅ |
| `hdgrp` | **484**（全 20 MOD **第 2**）= 411 有效 RLE + **72 零长段**（2 个块 `(381,69)(480,3)`），头异常 **0** |
| `kdef` | **4569**（全 20 MOD **第 1**，为第 2 名 1701 的 2.69 倍）；`kdef.grp` 尾 12B 残留（源侧本有，md5 全同） |
| `eft` | **714，与基线 md5 逐字节相同**（`idx` 2856B / `grp` 691627B）——**epic 唯一零改动** |
| `ranger.grp` | **132270**（第 9/20）；`ranger.idx` = 24B / 6 offsets，末 offset == grp，**完好无损** |
| `ranger.str` 侧表 | **763** 条（770 行 − 7 注释）；分段 `243+343+82+95`、字段 `513+82+168`，均 Σ=763 |
| 存档 | 产物 `save/` **27**（全槽 `.grp`）/ 源 **31**；27/27 逐字节一致；4 项改道 `data/`（`ranger.grp` md5 异因编码转换） |
| `RepairIdx` | **未触发**（源 `ranger.idx` 完好）——dream **不是** RepairIdx 案例，zheng 仍是唯一 |
| 缺陷 | **0 内容缺陷 / 0 构建缺陷 / 0 工具缺陷** |

**独特性**：

1. **`kdef` 4569 = 全 20 MOD 第 1**（BookCalamity 1701 / mingdong 1654 / lyff 1358 / pig 1288），
   是第 2 名的 **2.69 倍**。这是 dream **唯一**的真正「第 1」。
2. **fight 增删并行**（epic 首个删除象限）：`92 − 41 删 + 71 增 = 122`。
   books / pineapple 的删除象限都是 **0**；dream 的 `E=41` 使「四象限」判据失效
   （`A+B=51≠92`）⇒ 必须升级为**五分类**。
3. **三种 fight 形态并存**：books 保留+增（`89/3/0/86/2`）、pineapple 全改写（`2/90/0/62/115`）、
   dream 增删并行（`2/49/41/71/0`）⇒ 本 epic 中「任何单一计数口径必漏项」的最强论据。
4. **`eft` 零改动（epic 唯一）**：md5 + diff 缺席 + 大小相同三重证明。
   前 13 个 MOD 全部改过特效（books 973 / pineapple 1378 / mingdong 2268 / BookCalamity 2857）。
5. **记录段 5/5 全异**（epic 唯一）：lyff 1 段、ptt 4 段，其余基线同形。
   但 CC 尺寸全为标准值（182/190/52/136/50）⇒ 只是记录数不同，布局标准。
6. **`hdgrp` 484 = 第 2**（books 696 第 1），含 72 个零长段（2 个块）+ **`eft` 反证**：
   同 MOD 同家族 `eft` 零长 **0** ⇒ 零长是 `hdgrp` 内容特征非格式缺陷。
7. **`removed` 105 的四类型结构**：9 槽 `.grp` 改道 + **9 槽 `.idx` 按需播种**（源无 idx）
   + 82 战斗回退 + 2 模板 + 3 死文件 + **0 真删除**。比 books 的 21 项大 **5 倍**，
   且多出「槽 `.idx` 播种」与「大量战斗回退」两类。
8. **孤儿 `fight23.idx`**：作者删 grp 漏删 idx（源侧亦然），流水线忠实保留、引擎不读。
   ⇒ 打破「fight `.grp` 与 `.idx` 必成对」假设（`.grp` 71 组 / `.idx` 72 组）。

子 change：`allmods-dream-activate`（构建+启动+记录段判据）、
`allmods-dream-verify`（diff 审计+五分类+报告）。
报告：[dream-verify.md](../../changes/allmods-dream-verify/reports/dream-verify.md)

每个 MOD 一个独立 slice。每个 slice 的标准形状（已由 Slice 2 定型，可直接复用）：
1. 构建（`mod_build.lua kys-<mod>`）
2. 逐文件穷举审计（`mod_audit.lua --mod <slug>`）
3. 字节级覆盖（`format_spec.lua --mod <slug>`）
4. 产物四项检查（`mod_check_one.lua`）
5. 真实启动链路（`boot_one_mod.lua`，独立进程）
6. `diff.md` 逐条审计 + 报告

**顺序**：由 `TODO.md` 的梯队排序驱动（hdgrp 条目数为主、fight 数为辅）。

**重要教训（来自 Slice 2）**：即使 MOD 与基线「同形」，也**不得预设**零改动 ——
每个 MOD 必须跑完整的穷举审计 + 启动链路验证。Slice 2 就是在「同形」的 SweeOan 上
发现了跨 20 MOD 的 `save/` 缺陷。

清单与排序状态见 [TODO.md](TODO.md)。

## 运行 / 切换 MOD

配置只需一个文件 `game/active_mod.txt`（内容为 MOD slug，去掉 `kys-` 前缀）。示例见
[`game/active_mod.sample.txt`](../../../game/active_mod.sample.txt)（该示例文件提交仓库；`active_mod.txt` 本身
是每用户运行时状态，已被 `.gitignore` 忽略）。

推荐用启动脚本（自动检测 love、列出/选择 MOD、按需构建、写配置并启动）：

```bash
./tools/run-mod.sh                 # 交互式选择 MOD
./tools/run-mod.sh mingdong        # 直接启动指定 MOD（接受 mingdong 或 kys-mingdong）
./tools/run-mod.sh --list          # 只列出 MOD
./tools/run-mod.sh --vanilla       # 不激活 MOD（原版，删除 active_mod.txt）
```

手动方式：`cd game && echo mingdong > active_mod.txt && love .`（关 MOD：`rm game/active_mod.txt`）。

## Slice 依赖图

```
Slice 0 (foundation: spike + ini + 数据合并 + 构建管线 + 差异报告)
   │
   ▼
Slice 0b (foundation gap-fill: smap 改名 + sound 回退 + 资源分类)
   │
   ▼
Slice 0c (foundation audit: 文件级穷举 + 字段级覆盖 + 证据)
   │
   ▼
Slice 1 (mingdong 端到端)
   │
   ├──▶ Slice 2 (下一个最接近的 MOD)
   │       │
   │       ▼
   ├──▶ ...  按数据差异报告排序，逐个
   │
   ▼
   dream / Dragon / RiverLake / pineapple / books (数据形态最远的收尾)
   + 标注"有问题"的 5 个 MOD (数据可用性存疑，单独验证)
```

> Slice 0c 与 Slice 1 的关系：0c 只新增审计工具与文档，**不修改** `game/mods/**` 产物，
> 因此不阻塞 Slice 1（已完成）。Slice 2-14 应复用 `mod_audit.lua` 做本 MOD 的穷举验收。

## 全局验收标准（Epic DoD）

1. **架构覆盖**：19 个 MOD 全部完成端到端验证（或经排查确认源数据本身损坏，记录在案）。
2. **零回归**：不指定 MOD 时原版行为与 epic 开始前一致，`lua tests/test_runner.lua` 全绿。
3. **流水线可重复**：任一 MOD 接入 = 一条 `lua tools/mod_build.lua <mod>` 命令 + 引擎按回退链加载，无手工数据拷贝步骤。
4. **数据形态全覆盖**：hdgrp 条目数 **115/129/204/267** 四档（实测 `idx/4`；早期记录 114/128/203/266 系差 1 的口径错误，已修正）、文件缺失回退、文件新增（fight 动态数量）、ini 参数差异（含 typo 键名）均有对应 MOD 实测通过。

### DoD 终验记录（2026-10-27，当前工作树实测）

| DoD | 判据 | 实测命令 | 结果 |
|:---:|------|----------|------|
| 1 架构覆盖 | 19 个 MOD 全部端到端 | 逐 MOD `MOD_SLUG=<m> lua tools/mod_check_one.lua` | **19/19 ✅**（`EVENTS=OK` / `SAVE=OK`，失败 0） |
| 1 启动链路 | 19 个 MOD 真实启动（独立进程） | `lua tests/unit/boot_one_mod.lua <slug> <Person> <Thing> <Scene> <Wugong> <hero>` | **19/19 ✅**（全量断言 PASS，含记录数与主角姓名解码） |
| 2 零回归 | 原版行为不变 | `lua tests/test_runner.lua` | **通过 1895 / 失败 0 ✅** |
| 3 流水线可重复 | 一条命令 + 幂等 + 无手工拷贝 | `lua tools/mod_build.lua kys-dream` 连续两次 + `diff -rq` | **diff 为空（幂等）✅**；`--all` = `20 mods, 0 build failures` |
| 4 数据形态 | hdgrp 四档 | `stat -c%s mods/*/data/hdgrp.idx` ÷ 4 | **115 / 129 / 204 / 267 ✅**（pascal·mingdong / GodsDevils / ptt / Dragon） |
| 4 数据形态 | 文件缺失回退 | books `FILE_MISSING` 4 实例（`books-verify.md` §4） | **✅** |
| 4 数据形态 | 文件新增（fight 动态数量） | `ls mods/<m>/data/fight*.grp` | **dream 122 / books 178 / pineapple 154 ✅** |
| 4 数据形态 | ini typo 键名 | `grep SCENCEAMI reference/allmods/kys-mingdong/kysmod.ini` → `9:SCENCEAMI=2` | **✅**（`mod_check_one mingdong` 通过） |

---

## Slice 0c 复核与补全（2026-10-28）

用户复核「资源覆盖穷举审计（文件级 + 字段级）是否完成、有无可验证 DoD」。
结论：**文件级 100% 完成；字段级有真实注册遗漏，已补全**。

### 复核结论

| 子 change | 声称 | 实测 | 判定 |
|-----------|------|------|------|
| `allmods-slice0c-file-inventory` | Σ(类别)==11220，未归类==0 | `total=11220 unclassified=0 bad_evidence=0`，与 `find` 独立计数 11220 **精确相等** | ✅ 属实 |
| `allmods-slice0c-format-spec` | 覆盖全部格式族（含 `save_grid`/`save/rN.*`） | 初版 `FORMATS` **只注册 ranger**；`save/` 451 文件中 **411 个从未验证** | ❌ **误标完成 → 已补全** |
| `allmods-slice0c-unneeded-evidence` | 每个 `needed=false` 有可复现证据 | `bad_evidence=0`，`checked=17 failed=0`，`EVIDENCE_KINDS` 6 种 | ✅ 属实 |

### DoD 可验证性（negative control）

两条核心断言均做了**病态输入对照**，证明不是空跑通过：

| 断言 | 对照输入 | 期望 | 实测 |
|------|----------|------|------|
| `verifyIntervals` 无缺口 | 中间缺口 / 尾部缺口 / 首部缺口 / 重叠 / 空表 | 全部 `ok=false` | **6/6 全部被抓 ✅** |
| `classify` 不兜底 | `zzz/x.qqq`、`data/person.grp`（产物路径） | 返回 `nil` | **2/2 返回 nil ✅** |

`CATEGORY` 恰 10 项且不含 `OTHER`/`UNKNOWN`/`MISC`/`DEFAULT`；
未使用的 `DESIGNED_FALLBACK`/`DEAD_PARAM` 经 `M.ABSENT_EXPECTED`（3 条）+
单元测试表达「源侧本就缺失」，计数 0 属正确语义。

### 补全内容与实测

| 项目 | 补全前 | 补全后 |
|------|--------|--------|
| `FORMATS` 注册 | 12（缺 `save_grid` + `save_slot`） | **14** |
| `format_spec --all` | `checked=6773 gaps=0` | **`checked=6826 gaps=0`** |
| save 族覆盖 | 40 / 451 | **451 / 451**（53 个格式实例） |
| 单测总数 | 1842 | **1895** |
| format_spec 单测 | 213 | **266**（+5 专项断言） |

补全**复用既有 `verifyPair`**（allsin/alldef/rN/sN/dN 与 ranger 同为
uint32 offset 表 + 分段负载），零新解析器 ⇒ 缺口性质是**注册遗漏**而非能力缺失。
补全过程另抓到真实 MOD 残留：`kys-HeavenSword/save/r1.idx`（24B，与 `ranger.idx`
逐字节相同）有 idx 无 grp，已按 `fight/` 既有约定归 `ORPHAN_IDX`，不计缺口、
**不生成零字节占位**。

### 边界诚实声明

字段级覆盖对象是**二进制结构化格式**：

- 二进制结构化格式覆盖率 = **100%**（10,553 / 10,553）
- 全源文件覆盖率 = **94.1%**（10,553 / 11,220）
- 未覆盖 667 个 = `.mid 578`（proposal 已声明 Out of Scope）+ `.txt 52` +
  `.lua 19` + `.dll/.exe/.bat/.zip/.xlsx 13` + `.ttf 2` + `.mp3/.sf2 3`

### 改动文件（四禁改零触碰）

| 文件 | 改动 |
|------|------|
| `game/tools/format_spec.lua` | 注册 11 个 save 族格式 + `optional` 跳过 + `ORPHAN_IDX` 归并 |
| `game/tests/unit/test_format_spec.lua` | +5 条专项断言（save 族） |
| `openspec/changes/allmods-slice0c-format-spec/{tasks,verification}.md` | 2.7 实证 + §9 补全复核 |
| `openspec/changes/allmods-slice0c/change-manifest.md` | Contract A/B 实测验证段 |

`game/engine-love2d/**`、`game/engine-mud/**`、`jyconst.lua` 常量、`reference/allmods/**` —— **0 处改动**。

---

## 字段/格式支持全面复核（2026-10-29）

用户质询：「这些覆盖到的字段和格式，都有支持吗？在对应 mod slice/change 里面有做支持对应字段和格式的 design 和 tasks 吗？」

### 复核方法与结论

逐一核对 **14 个格式族 × 消费者符号 × 逐 MOD 文档留痕**，发现并处置 4 类问题：

| # | 问题 | 严重度 | 处置 |
|---|------|--------|------|
| 1 | `save_grid` 验证器结构假设**错误**（用 `verifyPair` offset 表验定长 uint16 网格） | **高** | 已改正为 `verifySaveGrid` + 交叉校验；§10 记录 |
| 2 | `list/*.bin`（82 个，20/20 MOD）**引擎完全不读**，被 `CC.Effect` 硬编码 53 项替代（`effect.bin` 实有 64~200 项） | **高** | 新建 `allmods-list-bin-support`（design ADR-1/2 + tasks 5 组） |
| 3 | 5 个 MOD（awaken/bookcalamity/mingdong/pig3dos/zheng）**零字段级 DoD 文档** | 中 | 新建 5 个 `allmods-<m>-format-dod` + `allmods-permod-format-dod` |
| 4 | 13 个 MOD 文档记 `formats=12`（现为 14），数字普遍少 2；`extractKdef` consumer 标注为「导出符号」但实为 `local` | 低 | 逐 MOD 追加「字段/格式支持复核」段 + 修正 consumer 标注 + 测试加导出性断言 |

### 格式族 × 消费者支持矩阵（实测）

| 族 | 格式 | 消费者 | 支持 |
|----|------|--------|------|
| `idx_grp_rle` | hdgrp/eft/warfld/cloud/title/mmap | `lib_love.PicLoadFile`（`:423`，`getPic:262`→`LoadPic:291` 8 字节 PNG 头 + RLE 逐行） | ✅ |
| `idx_grp_text` | talk | `jymain.ReadTalk`（`:3169`，offset 表 + `read("*line")`） | ✅ |
| `idx_grp_bytecode` | kdef | `mod_build.lua:892` `local function extractKdef`（**构建期**，运行时不再读） | ✅ |
| `bare_idx_grp` | smap/wmap/sdx/smp/wdx/wmp | `lib_love.LoadSMap:890` / `LoadWarMap:1090` | ✅ |
| `grid_save` | allsin/alldef | `lib_love.LoadSMap` → `Byte.LoadToTable16`（**定长 uint16，不读 .idx**） | ✅（本次改正） |
| `ranger_seg` | ranger | `jymain.LoadRecord:1685` | ✅ |
| `save_slot` | r1..3/s1..3/d1..3 | `jymain.LoadRecord` | ✅ |
| `bin_table` | list/*.bin | `ModData.LoadEffectTable`（`framework/mod_data.lua`，init 链调用）→ 覆盖 `CC.Effect`；`match.bin` 对应 `CC.ExtraOffense` | ✅（本轮补齐） |
| `text` | kysmod.ini | `mod_ini.lua` via `mod_data.lua:660 pcall require` | ✅ |
| `wav_pcm` | sound/*.wav | `lib_love.PlayWAV:602` | ✅ |
| `png_image` | head/*.png | `lib_love.PicLoadFile` | ✅ |
| `grid` | surface/earth/building/buildx/buildy/palette/war | 各类 `lib_love` 网格装载 | ✅ |

**结论（本轮已收口）：14/14 族均有真实消费者。`bin_table` 原为唯一缺失族，已由 `allmods-list-bin-support` 补齐。**

### 8 门禁复跑（复核后全绿）

| 门 | 结果 |
|----|------|
| G1 单元测试 | **1957 / 0 failed**（+43 vs 1914，`format_spec` +12 / `mod_audit` +6 / 其余回归断言） |
| G2 pascal 基线 | `PASS` |
| G3 全量构建 | `20 mods, 0 build failures, 5 annotated-problematic` |
| G4 `mod_check` | `20 MOD, 通过 20, 失败 0` |
| G5 `mod_audit --all --evidence` | `total=11220 in_product=9285 not_in_product=1935 unclassified=0 bad_evidence=0`，`PENDING 663→581`，`evidence checked=22 failed=0` |
| G6 `format_spec --all` | `formats=14 checked=6838 gaps=0` |
| G7 存档槽 | 451 文件全在；430 逐字节一致，21 处为设计内转换（20 `ranger.grp` Big5→UTF-8 hint + 1 `zheng/ranger.idx` 修复）⇒ 真实问题 0 |
| G8 四禁改 | `engine-love2d/` `engine-mud/` `reference/allmods/` = **0 处**；`jyconst.lua` 的 `CC.*=` = **0 处** |

### 本轮新增产物

| 文件 | 内容 |
|------|------|
| `openspec/changes/allmods-list-bin-support/{proposal,design,tasks,specs/}` | `list/*.bin` 支持：ADR-1 分类处置（effect/match→REQUIRED，leave/levelup→LEGACY）、ADR-2 不改 `jyconst.lua` 的惰性装载、13 条 Negative Constraints |
| `openspec/changes/allmods-permod-format-dod/{proposal,specs,tasks}` | 5 个缺文档 MOD 的补全总纲 |
| `openspec/changes/allmods-{awaken,bookcalamity,mingdong,pig3dos,zheng}-format-dod/**` | 各含 proposal + spec（逐格式表 + 20-MOD 横向表 + REQ-FMT-1~7 追溯）+ tasks + verification |
| `allmods-slice0c-format-spec/verification.md` **§10** | `save_grid` 结构假设错误的反证（3 份独立证据）、`verifyPair` 为何假通过、8/8 负向对照、20/20 交叉校验、教训：「0 gaps ≠ 结构正确」 |
| 14 个 MOD 的 `verification.md` | 追加「字段/格式支持复核」段（逐格式表 + 数字勘误 + `list/*.bin` 缺口 + 20-MOD 横向对照） |
| `epics/.../TODO.md` | 新增「字段/格式支持补全（2026-10-29）」段，4 条待办 |

### 本轮实施收口（`allmods-list-bin-support` 已落地）

复核发现的 4 类问题**全部处置完毕**，其中第 2 类（`list/*.bin`）已从「立 change」推进到「代码实施 + 实测验证」：

| 类 | 处置状态 |
|---|---------|
| 1 `save_grid` 结构假设错误 | ✅ 已改正（`verifySaveGrid` + 交叉校验，8/8 负向对照） |
| 2 `list/*.bin` 无支持 | ✅ **已实施**：`effect/match` 进产物（20/20 逐字节）+ 运行时惰性装载 + `format_spec` 记录级 + `mod_audit` 逐文件分类 |
| 3 5 MOD 缺 DoD 文档 | ✅ 5 个子 change 全部产出并实测校验（数字逐格吻合） |
| 4 陈旧数字 + consumer 标注 | ✅ 13 MOD 追加复核段；`extractKdef` 标注改正；测试加导出性断言 |

**关键实测证据**：

- `PENDING` **663 → 581**（`.bin` 残留 0），`in_product` **9245 → 9285**
- `CC.Effect` 运行时：pascal **64** / BookCalamity **200** / pineapple **84**；未激活 **53** 兜底
- `index 0` 语义取证：`sum(effect.bin 含 idx0) == eft.idx 段数` **14/20** 精确成立、`跳 idx0` **0/20**
  ⇒ 数据侧 `10` 正确，硬编码 `9` 为原版提取期遗留（同时消除 `eft≥53` 的静默退化）
- 装载器负向对照：3 项短文件→`3`、删文件→`53`、恢复→`64`（三者互斥）
- `format_spec.verifyBinTable` → **uint16 记录级**（奇字节显式 gap、空文件失败），
  `formats=14 checked=6838 gaps=0` 不变
- 幂等性：二次全量构建 `diff -rq` **0 差异**
- 四禁改 **0 处**，`jyconst.lua` 的 `CC.*=` **0 处**

**7 个新建 change 全部 `status: done`**，`tasks.md` 勾选 176/176（list-bin 51 + permod 25 + 5×20）。

---
## Slice 15: MOD 音乐直放（`allmods-midi-direct-play`）— ✅ 已完成

> 本 slice 是 `allmods-spike-music-refs`（审计 spike，`done`）的**实施出口**。
> **方案在实施前被用户质疑推翻并改为更优解**：不再转码 OGG，改为**直接播放 MIDI**。
> 原方案 `allmods-slice15-music-ogg` 已标记 `abandoned`（被取代）。

### 为什么改方案

原计划用 `timidity` + `ffmpeg` 把 41 个被引用 `.mid` 转成 `.ogg`，代价是
**+36 MB 产物、5 分钟构建、两个外部二进制依赖**。用户提问「LÖVE 能否直接播 MIDI/MP3」，
实测答案是**能**：

| 探测 | 结果 |
|---|---|
| `love.audio.newSource("x.mid")` | ✅ 原生支持（内置 libmodplug） |
| `love.audio.newSource("x.mp3")` | ✅ 原生支持 |
| 抽样 40 `.mid` + 2 `.mp3` | **42/42 解码成功、42/42 真出声、0 静音** |

⇒ 直接播放成本：**+7.5 MB（578 个全进）、0 构建时间、0 外部依赖**。取得用户同意后按方案 B 实施。

### 实测发现（5 条，均有实验证据）

| # | 发现 | 证据 |
|:-:|---|---|
| 1 | LÖVE **按扩展名选解码器** | MIDI 内容命名 `.ogg` → `Could not read Ogg bitstream`；`.mid` → 出声 |
| 2 | 既有**路径前缀 bug** | `CONFIG.SoundPath="sound/"` 使 `mods/<slug>/sound/x.ogg` 被误拼成 `sound/mods/...` |
| 3 | `mid.sf2` 对 LÖVE **无效** | 3 种 cfg 写法（含 `bank 0`+128 行 `%font`）合成 md5 **全同** `bfeebf68…` ⇒ 忽略自定义 SoundFont |
| 4 | 编号是 `music/<id>.mid`，**非 `<id+1>`** | `<id>` 命中 94.6% vs `<id+1>` 90.5%；多个 MOD 有 `music/0.mid`（`<id+1>` 会取 `-1.mid`，不可能） |
| 5 | 单一编号方案会让 BookCalamity **变差** | 它引用 24–51 但源只有 0–23；MOD 目录会遮蔽原可播的内置 ogg ⇒ 必须加内置回退 |

### 实施的 4 处改动

| # | 文件 | 内容 |
|:-:|---|---|
| 1 | `game/engine-love2d/lib_love.lua` | `PlayMIDI`/`PlayWAV` 前缀修正 + `MUSIC_EXTS={.ogg,.mid,.mp3}` 探测 + `bundledFallback()`（+90/−2 行） |
| 2 | `game/framework/mod_data.lua` | `ModData.MUSIC_DIR`；`CC.MIDIFile` 改为 `mods/<slug>/music/game%02d`（**剥掉 `.ogg`** 交引擎探测） |
| 3 | `game/tools/mod_build.lua` | `flattenMusic()`：`music/<id>.{mid,mp3}` → `mods/<slug>/music/game<id+1>.{mid,mp3}`；`.sf2` 不复制 |
| 4 | `test_mod_data.lua` / `test_mod_build.lua` | 3 + 5 个测试（共 4 组负向对照） |

### 兼容性结果（用户核心要求：20 MOD + 原版都要支持）

**原版零回归**（不激活 MOD）：

```
激活MOD = nil
CC.MIDIFile = sound/game%02d.ogg      ← 与改前逐字节相同
CC.ATKFile  = sound/atk%02d.wav
CC.EFile    = sound/e%02d.wav
```

| 对象 | 被改变的路径数 |
|---|---:|
| 25 个 `sound/gameNN.ogg` | **0** |
| 1093 个 wav 音效 | **0** |

**20 MOD 覆盖**：

| 指标 | 结果 |
|---|---|
| 产物 `music/*.mid` | **578**（源 578，**100% 搬运零丢失**） |
| 被引用 id 可解析 | **348/368 = 94.6%** |
| 完整覆盖 MOD 数 | **19/20**（唯一例外 BookCalamity） |
| BookCalamity | 15 MOD + 1 内置回退 + 19 静音（静音数与改前**相同**，未变差） |

**真实播放出声**（LÖVE 实跑，非模拟）：

| 文件 | 时长 | RMS | 判定 |
|---|---:|---:|---|
| mingdong `game27.mid` | 122.00s | 0.1022 | 出声 ✅ |
| awaken `game82.mid` | 89.00s | 0.1075 | 出声 ✅ |
| 内置 `game25.ogg`（对照） | 119.55s | 0.0960 | 出声 ✅ |

### 门禁

| 门 | 结果 |
|---|---|
| G1 测试 | **1965 / 0 failed**（+8） |
| G2 pascal baseline | `PASS` |
| G3 `mod_build --all` | `20 mods, 0 build failures` |
| G4 `mod_check` | **20/20 通过** |
| G5 `mod_audit` | `11220 / 9285 / 1935 / unclassified=0 / bad_evidence=0`（**未变**） |
| G6 `format_spec` | `formats=14 checked=6838 gaps=0` |
| G7 存档 | 真实问题 0 |
| G8 禁改 | `jyconst` 的 `CC.*=` = **0**；`reference/allmods` = **0** |

幂等：二次全量构建 `diff -rq` = **0**。真实启动：pascal/mingdong/awaken/BookCalamity 全 `OK`。

### ⚠ 已解禁的禁改路径

本 slice **修改了 `game/engine-love2d/lib_love.lua`**（四禁改之一），已获用户明确授权。
其余三禁改未触碰：`engine-mud/**` = 0、`jyconst` 的 `CC.*=` = 0、`reference/allmods/**` = 0。

### 审计口径为何未变

`mod_audit --all` 数字**与改动前完全一致**（`PENDING` 仍 581）。原因：
578 个 `.mid` 现在**进了产物但仍是源侧分类**，`mod_audit` 的 `PENDING` 统计的是
`reference/allmods/` 侧的未归口文件，与产物无关。**这不是遗漏，是口径定义**。
原转码方案预期的 `PENDING 581→537` 随方案废弃而作废。

### 未完成的项（明确记录）

| # | 项 | 性质 |
|:-:|---|---|
| 1 | BookCalamity 19 个 id 无源文件 | **MOD 原始数据缺陷**，不可修复 |
| 2 | `.mp3` 2 个未被引用 | **已支持播放**（第二轮）：LÖVE 原生解码，构建期已搬运；仅源数据无引用 |
| 3 | `mid.sf2` 音色不生效 | libmodplug 忽略自定义 SoundFont（实测三写法 md5 全同） |
| 4 | 578 个 mid 全进产物（含未引用 537 个） | 仅 7.5 MB，完整性优先 |

文档：[proposal.md](../../changes/allmods-midi-direct-play/proposal.md)、
[tasks.md](../../changes/allmods-midi-direct-play/tasks.md)

### 第二轮追加：MP3 支持

用户追问「mp3 可以支持吗？mod 里有播放 mp3 的吗？」后补做，结论推翻第一轮的一部分。

| 问题 | 实测答案 |
|---|---|
| LÖVE 能播 MP3 吗 | **能**（`dream/24.mp3` 266.72s RMS 0.1511、`pineapple/37.mp3` 248.08s RMS 0.1656） |
| MOD 里引用 MP3 吗 | **没有**（5 条 id 来源全量扫描，两个 mp3 编号均未出现） |

**第一轮两处判断修正**：

1. **「引擎无 MP3 音乐通道」只对改动前成立** —— 新增的 `MUSIC_EXTS`
   已含 `.mp3`，通道已通，缺的只是构建期搬运。
2. **扫描漏了 `instruct_66(id)`** —— 第一轮只查 `Scene["进门音乐"]` 和
   `WAR.Data["音乐"]`，而事件脚本可调 `instruct_66` 播任意 id
   （`awaken` 就用了 **48 个不同 id，0–80**）。补全后 dream / pineapple
   的引用集合仍未包含 24 / 37。

**踩坑（已加测试防守）**：第一版用 `name:match("^(%d+)%.(mid|mp3)$")`，
Lua pattern **没有** `|` 选择符（`|` 是字面字符），导致**静默匹配 0 个文件**，
`mod_build --all` 报成功但产物 `music/` 全空（`.mid` 一起丢）。
改为 `([%a%d]+)` + 白名单比较。

**产物对账**：`.mid` 578=578 ✅、`.mp3` 2=2 ✅、`.sf2` 0（按设计排除）；
md5 逐字节一致（`game25.mp3` = `39c4c26b…`、`game38.mp3` = `d02246c5…`）。
编号无冲突（全库扫描 0 冲突）。

### 第三轮：`tools/run-mod.sh` 音频就绪

用户问「run-mod.sh 要不要对应修改，把音频文件也准备好？」——**要改，且有真实缺陷**。

原逻辑 `[ ! -d "$MODS_OUT_DIR/$SELECTED" ]` 只判断目录存在。而 `mods/<slug>/`
一旦构建过就永久存在，所以本轮新增 `music/` 产物类型后，所有旧目录都被判
「已就绪」而跳过重建 ⇒ **音频永远缺失**。实测删掉 `mods/pig/music` 后脚本报
「MOD 数据包已存在」，`music/` 再也不回来。

修复：

| 函数 | 作用 |
|---|---|
| `mod_ready(slug)` | 目录存在 + `data/` 非空 + 源侧有音频时产物 `music/` 必须存在且数量 ≥ 源侧 |
| `report_audio(slug)` | 打印 `mid/mp3/ogg` 计数；为空时 warn（音频不阻塞启动） |
| `--list` 新增列 | 已构建 `mid/mp3`、缺 `music/` 显示 `缺`、未构建显示 `src:N` |

实测 4 种场景（缺 music 触发重建 / 完整跳过 / 带 mp3 计数 / 全新构建）
与兼容性（`--vanilla` 删 active_mod.txt、`--no-build` 跳过检查）全部正确。

新增门禁 `game/tests/gate_run_mod.sh`（7 项），守两个真实坑：①只看目录；
②`flattenMusic` 的 `(mid|mp3)` Lua pattern alternation 陷阱。
负向对照：删 `mods/pig/music` ⇒ `GATE_FAIL (1 项)`；改回旧判断 ⇒ `GATE_FAIL (1 项)`。

### 第四轮：libmodplug 警告治理

MOD 运行时 stderr 会刷两类警告，均来自 **libmodplug C 层**（直写 stderr，
Lua 无法捕获）。全量实测 578 首：

| 警告 | 触发 | 成因 |
|---|---:|---|
| `load_pat can not open timidity.cfg` | 578 | 找不到音色库配置 |
| `Meta event not at end of track` | 519 | 作者 MIDI 在 EOT 后还有字节 |
| `ends with note on` | 329 | 末音缺 note-off |

**两类都不影响听感，已实证**：

1. **`load_pat`**：设 `MMPAT_PATH_TO_CFG=/etc/timidity` 后警告归零，且逐样本哈希
   **完全相同**（`172447810`，含「指向不存在目录」和「换 FluidR3/TimGM6mb 真音色库」
   三种对照）⇒ libmodplug 忽略 SF2 用内置波形合成，此警告纯属路径噪声。
2. **`load_mid`**：timidity 渲染 521 首逐首对账，按**衰减曲线形状**判定：
   衰减拖尾 505（96.9%）、近乎静音 11（2.1%）、LÖVE 不短 5（1.0%）、
   **内容缺失 0（0%）**。典型 `m0403` 超出段 6 等分 RMS
   `0.3336→0.0581→0.0076→0.0006` 单调衰减 ⇒ 砍掉的是末音混响释音，非旋律。

> **勘误**：中途曾把 245 首判为「真截断」，因只看「超出段 RMS>0.005」而未看
> 衰减形状。加入曲线单调性判定后真实缺失数降为 **0**。

`tools/run-mod.sh` 处理：自动探测并 `export MMPAT_PATH_TO_CFG`；用
`2> >(grep -vE '^(load_pat|load_mid) > ' >&2)` 仅过滤这两类前缀（不吞其它 stderr）；
`FUZZY_MIDI_WARN=0` 可关闭。实测 `Dragon`：直连 `love .` 有 **10** 行警告，
经 `run-mod.sh` 为 **0** 行。门禁 `gate_run_mod.sh` 增加 5 项检查
（负向对照：删过滤 ⇒ `GATE_FAIL (2 项)`；删 MMPAT 探测 ⇒ `GATE_FAIL (1 项)`）。

### 第五轮：音质修复 —— OGG 预渲染

用户反馈「MIDI 播放效果很差」。根因是 LÖVE AppImage **自带** 336 KB 的
`libmodplug.so.1`，其 MIDI 合成**完全不读外部音色库**：

| 配置（同一首 `Dragon/game01.mid` 前 2 秒） | md5 |
|---|---|
| 无音色库 | `df5a2b54…` |
| freepats 128 个 GUS `.pat` | `df5a2b54…` |
| `FluidR3_GM.sf2`（148 MB） | `df5a2b54…` |
| **128 个音色全指向同一低音鼓** | `df5a2b54…` |

连「所有音色都是低音鼓」都不改变一个字节 ⇒ `load_pat` 警告纯属误导。

客观量化：libmodplug 直放过零率 **4749 Hz**（差分/RMS 0.338），
预渲染 OGG **2215 Hz**（0.154），无损基准 2214 Hz。高频能量差 **2.1 倍**。

**格式选型**（同源 78 秒实测）：OGG q3（1017 KB，偏差 +0.1%）优于
MP3 q:a 7（1014 KB，+2.0%）；OGG q1（728 KB，+2.8%）优于 MP3 q:a 9
（781 KB，**+10.7%**）。同体积 OGG 明显更好，MP3 无优势。

**实现**：
- `lib_love.lua`：`MUSIC_EXTS` 改为 `.ogg, .mp3, .mid`（用户指定 mid 兜底）
- `mod_build.lua`：`preservedOgg` —— `rmdirp` 前暂存 `music/*.ogg`，之后写回
- `tools/render-music.sh`（新增）：`--all`/`--list`/`--force`，增量渲染
- 3 个顺序单元测试 + 9 项门禁检查（含真实重建行为验证）

**Dragon 试点**：24 首 **1 分 57 秒**，music/ 从 288 KB 增至 **18 MB**；
LÖVE 实际选中 `game01.ogg`，播放后过零率 **2215 Hz**。
全量 578 首估算 OGG q3 ≈ 560 MB / 约 78 分钟。

> **门禁弱点记录**：`gate_run_mod.sh` 多数检查是文本级的。把恢复循环改成
> `pairs({})`（代码在但逻辑被架空）时文本检查仍全 PASS，因此补了一条
> **行为验证**（植入标记 ogg → 真实重建 → 检查存活），负向对照 `GATE_FAIL (1 项)`。

**全量渲染完成**（用户试听 Dragon 通过后执行）：20/20 MOD、**578/578** 首，
失败 0 警告 0，耗时约 **53 分钟**，OGG 总量 **476.3 MB**（中位 729 KB/首，
最大 `awaken/game81.ogg` 5.9 MB / 458 秒）。逐 MOD 独立 `find` 对账不一致 **0**；
抽检 9 个 MOD 过零率 2079~2752 Hz，全部落在真实音色区间（libmodplug 直放为 4749 Hz）。
重建保护实测：Dragon 重建后 OGG 仍为 578，无丢失。

> `game/mods/` 合计约 2.0 GB，但 OGG 只占 476 MB；其余为既有产物
> （`save/` 718 MB、`data/` 633 MB 等）。该目录已被 `.gitignore` 覆盖。
