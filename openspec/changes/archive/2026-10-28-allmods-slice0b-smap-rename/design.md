## Context

MOD 源数据（`reference/allmods/kys-<mod>/resource/`）沿用原版 C 引擎（`kys.exe`）的文件命名：场景地图贴图为 `sdx`（索引）+ `smp`（数据），战斗地图贴图为 `wdx` + `wmp`。Lua 引擎（`game/script/jyconst.lua`）改用了描述性命名：

```lua
CC.SMAPPicFile={CONFIG.DataPath .. "smap.idx",CONFIG.DataPath .. "smap.grp"};  -- 场景地图
CC.WMAPPicFile={CONFIG.DataPath .. "wmap.idx",CONFIG.DataPath .. "wmap.grp"};  -- 战斗地图
```

`tools/mod_build.lua` 的 `flattenResources()` 只做小写归一后原样复制，因此 MOD 产物里是 `sdx/smp/wdx/wmp`，引擎找不到 `smap.*`/`wmap.*`，回退原版 `game/data/`。

`ModData.RewriteConstants` 的 `rewrite()` 逻辑本身是正确的：它对 `CC.SMAPPicFile` 的每个元素做 `mods/<slug>/data/smap.idx` 存在性检查。问题是 MOD 产物里根本没有 `smap.idx` —— 所以检查失败，回退原版。**修复点在构建期，不在运行期。**

### 现状证据（实测）

| 验证 | 结果 |
|------|------|
| 激活 mingdong 后 `CC.SMAPPicFile[1]` | `data/smap.idx`（原版，❌ 应为 MOD） |
| 激活 mingdong 后 `CC.MMAPPicFile[1]` | `mods/mingdong/data/mmap.idx`（✓，因源 MOD 就叫 `mmap.idx`） |
| 源 MOD `sdx` 条目数 vs 原版 `smap.idx` | mingdong 4635 vs 原版 4129 |
| `sdx` 末偏移 vs `smp` 文件大小 | 4635 项末值 4501874 == smp 大小 4501874（✓ 格式自洽） |
| 20/20 MOD 是否同时提供 `sdx` 和 `smap.idx` | 否（无冲突） |
| `wdx` 是否 == `sdx` | 否（3 个抽样 MOD 的 md5 均不同）→ `wdx→wmap` 正确 |

## Goals / Non-Goals

**Goals:**

- 构建期把 `sdx/smp/wdx/wmp` 正确映射为 `smap.idx/smap.grp/wmap.idx/wmap.grp`，使引擎读到 MOD 的地图数据。
- 让 `diff.md` 正确表达「改名」而非「增删」。
- 保持零回归：未激活 MOD 时行为不变；pascal 基线验证仍 PASS。

**Non-Goals:**

- 不改引擎侧数据加载代码（`RewriteConstants` 已正确）。
- 不做地图数据的格式/内容转换（已验证同格式）。
- 不处理 `sound/`、`thing`、`music/`（分属其他 change）。
- 不引入「运行时自动探测别名」的机制——映射表固定，来自权威 `UPedit.ini`。

## Architecture Decision Records

### ADR-001: 别名映射放在构建期，而非运行期

- **Context**: 引擎在运行期读 `CC.SMAPPicFile`。有两种修法：① 构建期改名，让产物就叫 `smap.*`；② 运行期让引擎也认 `sdx/smp`。
- **Decision**: 构建期改名（方案 ①）。
- **Alternatives Considered**:
  - **运行期别名表**：在 `ModData.Resolve` 里对 `smap.idx` 也去查 `sdx`。**否决**——把「C 引擎命名」这一历史包袱泄漏进运行期；且 `RewriteConstants` 的 `exists()` 检查会变得多分支难维护；未来 `MMAPPicFile` 等其他常量也要各自加别名，扩散面大。
  - **同时产出两个名字**（既拷 `sdx` 又拷 `smap.idx`）：**否决**——产物冗余（每个 MOD 多 6MB+），且 `diff.md` 会更乱。
- **Consequences**:
  - ✅ 引擎侧零改动；产物命名与引擎常量一致；`diff.md` 自然正确。
  - ⚠️ 需重建全部 20 MOD 产物（一次性成本，构建可重复）。
  - ⚠️ 别名表硬编码在构建器；若未来发现更多别名（如 `name.grp`），需扩展此表——但这正是「构建期单一映射点」的好处。

### ADR-002: 映射表来自 `UPedit.ini`，硬编码为构建器常量

- **Context**: 别名关系从何而来？
- **Decision**: 以 `reference/allmods/UPedit/UPedit.ini` 的 `[File]` 段为权威，硬编码为 `tools/mod_build.lua` 的 `ALIAS_MAP` 常量（附来源注释）。
- **Alternatives Considered**:
  - **运行时解析 `UPedit.ini`**：**否决**——`UPedit.ini` 在 `reference/allmods/UPedit/`，是编辑器配置，不是 MOD 数据的一部分；让构建器依赖它会把构建器耦合到编辑器目录布局。硬编码 + 注释来源更简单、可审计。
  - **推断（如「resource 下 4 个无扩展名文件」）**：**否决**——脆弱，`wdx`/`wmp` 无扩展名但 `sdx`/`smp` 也无；无法可靠推断。
- **Consequences**:
  - ✅ 映射明确、可审计、有权威出处。
  - ⚠️ 若 `UPedit.ini` 更新，需手动同步（可接受，别名是稳定历史约定）。

### ADR-003: 冲突时硬失败，不静默覆盖

- **Context**: 若某 MOD 同时提供 `sdx` 和 `smap.idx` 怎么办？
- **Decision**: 映射后目标名已存在 → 报错退出（非 0 退出码 + stderr 说明）。
- **Alternatives Considered**:
  - **后者覆盖前者 / 保留原版**：**否决**——静默行为会让数据来源不明；本项目 DoD 一贯要求「数据异常显式失败」。
- **Consequences**:
  - ✅ 异常可见；符合项目 REQ-BUILD 的显式失败原则。
  - ✅ 已验证 20/20 MOD 无此冲突，实际不会触发。

## Negative Constraints

- **不得修改** `game/engine-love2d/**`、`game/engine-mud/**`（引擎层）。
- **不得修改** `reference/allmods/**`（只读数据源）。
- **不得修改** `game/script/jyconst.lua` 的 `CC.SMAPPicFile`/`WMAPPicFile` 定义（它们已经正确）。
- **不得修改** `game/framework/mod_data.lua` 的 `RewriteConstants`（已正确；本 change 只改构建器）。
- **不得**改变 `fight/`、`save/` 的复制行为。
- **不得**改文件内容（只改文件名）。
- **不得**引入新的第三方依赖。
- **不得**让别名转换影响 pascal 基线验证（`--verify-pascal` 必须仍 PASS）。

## Alignment Check

对照 `openspec/project/profile.md` 的治理规则：

- **构建期处理原则**：本 change 完全在构建期（`tools/mod_build.lua`），符合「MOD 数据适配是构建期流水线」的架构定位。✓
- **可重复流水线**：别名转换是确定性映射，`mod_build.lua <mod>` 可重复执行产出相同结果。✓
- **零回归**：不改引擎、不改运行时路径，未激活 MOD 行为不变。✓
- **显式失败**：冲突硬失败。✓

无违规，无例外。

## Decisions

- **别名应用位置**：`flattenResources()` 的 `destRel` 计算之后、`writeFile(dest, data)` 之前。理由：此处是所有 `resource/` 文件的唯一汇聚点，且已有小写归一逻辑，插入别名映射最自然。
- **`diff.md` 抵消逻辑**：在 `buildDiff()` 计算 `added`/`removed` 后，若 `smap.idx` 在 `removed` 且对应别名源（`sdx`）在 MOD 侧出现过，则从 `removed` 移除并计入「别名转换」小节。实现上更简单：直接在 `removed` 列表中过滤掉 `ALIAS_MAP` 的所有值（`smap.idx`/`smap.grp`/`wmap.idx`/`wmap.grp`），因为它们已由别名提供。
- **测试策略**：`test_mod_build.lua` 用临时目录 + 伪造 MOD 树做单元测试（不依赖真实 20 MOD 全量构建，避免慢）；另加一个集成断言用真实 mingdong 产物。

## Risks

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| 别名表遗漏其他别名（如未来发现 `name.grp`） | 低 | 中 | 别名表集中单点，易扩展；本 change 只处理已证实的 4 个 |
| 重建 20 MOD 产物耗时 | 中 | 低 | `--all` 已是现有流程；一次执行 |
| `diff.md` 抵消逻辑误过滤 | 低 | 低 | 测试断言 `smap.*` 不在「基准独有」、但「别名转换」小节存在 |
| 别名影响 pascal 基线 | 低 | 中 | `--verify-pascal` 纳入 DoD 门禁 |
