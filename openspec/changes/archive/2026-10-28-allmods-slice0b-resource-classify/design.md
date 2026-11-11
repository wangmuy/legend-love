## Context

资源类型审计产出了一份 8 类的清单，但它是「一次性报告」，不是「可回归事实」。本 change 把清单变成测试与文档。

### 分类表（Contract C）

| 分类 | 资源 | 涉及 MOD | 判据（证据） | 处置 |
|------|------|---------|-------------|------|
| `REQUIRED` | `smap.*`、`wmap.*` | 20/20 | `UPedit.ini` 声明 `sdx/smp`=场景贴图 | **已修复**（smap-rename） |
| `REQUIRED` | `sound/*.wav` | 20/20 | 命名与 `CC.ATKFile`/`EFile` 吻合；pascal 逐字节相同 | **已修复**（sound-fallback） |
| `DESIGNED_FALLBACK` | `thing.idx`、`thing.grp` | 20/20 | 源 MOD 0/20 提供；引擎 `CC.ThingPicFile` 回退原版 | 断言固化 |
| `DEAD_PARAM` | `allsinbk.grp` | 20/20 | `LoadSMap(Sfilename, tmpfilename, ...)` 的 `tmpfilename` 函数体内 0 引用 | 断言固化 |
| `LEGACY` | `name.idx`、`name.grp` | 4（BookCalamity/Dragon/pineapple/RiverLake） | `kys.exe` strings 不引用；人名实来自 `ranger.grp` | 文档固化 |
| `DEAD_FILE` | `fightNNN..grp`、`fightNNN_02.grp` | awaken | `%03d` 格式永不生成双点名/`_02` | 断言固化 |
| `DEAD_FILE` | `new.idx`、`fight23.idx` | dream | `new.idx`=`kdef.idx`+9 字节垃圾（无 `new.grp`）；`fight23` 非 3 位 | 断言固化 |
| `DEAD_FILE` | `war1.sta` | Dragon | 引擎只读 `war.sta`；`kys.exe` 亦只引用 `war.sta` | 断言固化 |
| `EDITOR_DUMP` | `head/`、`item/`、`eft/`、`cc/` | 4/2/1/1 | `hdgrp`/`thing`/`eft` 的 PNG 导出；OpenCC 词典 | 断言固化（`IGNORE_DIRS`） |
| `PENDING` | `music/*.mid` | 20/20 | `.mid` ≠ 引擎 `game%02d.ogg`；66 首 vs 25 槽 | 记录为待决策 spike |

### 关键洞察

1. **「缺文件」不等于「bug」**：`thing.grp`/`allsinbk.grp` 在源 MOD 中不存在，但这是**正确的**——一个靠回退原版，一个是死参数。
2. **「多余文件」不等于「需移植」**：死文件与编辑器副产物在产物中存在或不存在都无害。
3. **分类错误的代价**：`sdx/smp` 曾被误归为「小写归一/同名冲突」，潜伏了整个 Slice 0。本 change 的目的就是让分类**可回归**。

## Goals / Non-Goals

**Goals:**

- 把 8 类资源的判定变成机器可验证的断言。
- 提供权威文档，使未来开发者/AI 不会重蹈「误判」覆辙。
- 记录 `music/*.mid` 为待决策（附判据），不擅自实施。

**Non-Goals:**

- 不修任何运行时代码。
- 不实施 `music/*.mid` 转换。
- 不过滤产物中的死文件（保持 Slice 0 的「忠实拷贝」）。
- 不从 `item/*.png` 派生 `thing.grp`。

## Architecture Decision Records

### ADR-001: 死文件保留拷贝，不主动过滤

- **Context**: 产物中含 `fight000..grp`、`new.idx`、`war1.sta` 等不可达文件。是否在构建期过滤掉？
- **Decision**: 保留（忠实拷贝），仅在 `diff.md`/文档中标注为「死文件」。
- **Alternatives Considered**:
  - **过滤掉**：**否决**——① 违反 Slice 0 已确立的「resource/ 忠实拍平」契约；② 过滤规则会变成又一张需要维护的「已知无用文件」清单（正是本 change 试图避免的那种隐式知识）；③ 死文件体积小（`new.idx` 18KB、`war1.sta` 66KB），过滤收益低；④ 万一某死文件其实被某条冷门代码路径引用，过滤会造成难查的回归。
  - **在 `diff.md` 中单独标注**：**采纳**——零风险，信息透明。
- **Consequences**:
  - ✅ 保持构建器简单、忠实；契约不变。
  - ✅ 信息通过文档暴露，而非通过删除隐藏。
  - ⚠️ 产物略大（可忽略）。

### ADR-002: 分类断言放在独立测试文件

- **Context**: 分类断言放哪？
- **Decision**: 新建 `tests/unit/test_mod_resources.lua`，独立于 `test_mod_build.lua`/`test_mod_data.lua`。
- **Alternatives Considered**:
  - **并入 `test_mod_data.lua`**：**否决**——该文件聚焦「回退链 API」；资源分类是「数据事实断言」，主题不同。独立文件便于定位失败。
- **Consequences**:
  - ✅ 主题清晰；失败时一眼定位。
  - ⚠️ 需在 `test_runner.lua` 注册（顺序放在 `test_mod_data` 之后）。

### ADR-003: `music/*.mid` 记录为 PENDING，不实施

- **Context**: 是否在本 change 处理 `music/*.mid`？
- **Decision**: 不实施；在 TODO.md 建 spike 条目，说明为何需要 spike（格式/槽位/编号体系三重不匹配）。
- **Alternatives Considered**:
  - **直接转换**：**否决**——需外部 MIDI→OGG 工具（破坏「构建期纯 Lua」约束），且 66 首 vs 25 槽的编号体系不明（引擎 `PlayMIDI(id)` 的 `id` 来自 MOD 数据引用，不是 1:1 映射）。**在信息不足时实施 = 猜测**。
- **Consequences**:
  - ✅ 不引入未验证的转换逻辑。
  - ✅ 用 spike 把「要不要做、怎么做」变成有证据的决策。
  - ⚠️ MOD 音乐暂时不生效（可接受，音效已由 sound-fallback 覆盖）。

## Negative Constraints

- **不得修改** `game/engine-love2d/**`、`game/engine-mud/**`。
- **不得修改** `reference/allmods/**`。
- **不得修改** `game/framework/**` 或 `game/script/**` 的**行为**（本 change 零代码行为变更）。
- **不得修改** `game/tools/mod_build.lua` 的构建行为（死文件策略 = 保留）。
- **不得**实施 `music/*.mid` 转换。
- **不得**过滤产物中的死文件。
- **不得**引入新依赖。

## Alignment Check

对照 `openspec/project/profile.md`：

- **文档以源码为准**：本 change 的断言全部基于源码/二进制实测，不基于文档推测。✓
- **构建期处理原则**：不改构建行为。✓
- **零回归**：纯测试 + 文档。✓

无违规。

## Decisions

- **测试文件的真实数据依赖**：分类断言尽量用**真实 20 MOD 的源数据**（`reference/allmods/`）而非伪造，因为「源 MOD 是否提供 `thing.*`」本身就是要断言的事实。为速度，用轻量扫描（`os.listdir`）而非全量构建。
- **`allsinbk` 断言方式**：`grep` 风格扫描 `game/` 下的 `.lua` 源，断言 `allsinbk`/`TempS_Filename` 只出现在常量定义行，不出现于任何函数调用（除已确认未使用的 `LoadSMap` 参数传递）。
- **死文件断言方式**：断言「若源 MOD 提供 `fightNNN..grp`，则 `%03d` 格式化无法生成该名」——即断言 `string.format("fight%03d.grp", n)` 永不含 `..` 或 `_`。
- **`IGNORE_DIRS` 断言**：断言 `IGNORE_DIRS` 含 `head`/`item`/`eft`；并断言产物中无这些目录。

## Risks

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| 分类断言与未来实现冲突（如将来真做 music 转换） | 低 | 低 | PENDING 分类不写「永不实现」断言，只记录状态 |
| 真实数据扫描慢 | 低 | 低 | 用 `os.listdir` 轻量扫描，不全量构建 |
| `allsinbk` grep 断言过于严格（未来可能真用） | 低 | 低 | 断言的是「当前」行为；若未来启用，同步更新测试（这正是可回归的价值） |
