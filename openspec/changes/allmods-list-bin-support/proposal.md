---
status: done
created: 2026-10-29
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Proposal: allmods-list-bin-support — `list/*.bin` 全格式支持（补 `PENDING` 663 中的 82）

## Why

`lua tools/mod_audit.lua --all --evidence` 的实测结果是
`total=11220 in_product=9245 not_in_product=1975 unclassified=0 bad_evidence=0`，
**`unclassified=0` 已成立**，但其中 **663 条仍标 `PENDING`（needed=nil，未判定）**：

| 扩展名 | 条数 | 性质 |
|--------|------|------|
| `.mid` | 578 | MIDI，需外部转换器 → 已在 `allmods-spike-music-refs` 判定 defer |
| `.bin` | 82 | **本 change 的目标**：`list/` 下的数据表，可完全解析 |
| `.mp3` | 2 | 音频压缩域，与 `.mid` 同类 |
| `.sf2` | 1 | SoundFont（仅 pascal） |

`PENDING` 的语义是「尚未判定」，对一个声称「穷举审计」的 change 而言是不可接受的
终态——它意味着 82 个文件既没被证明「必需」，也没被证明「不需要」。

更严重的是本轮复核发现的**事实性缺陷**：

1. **`list/` 整个目录不进产物**。实测 `game/mods/pascal/data/list/` 为空，
   而源侧 `reference/allmods/kys-pascal/list/` 有 6 个文件。
   `mod_audit` 把这 82 条标为 `PENDING / in_product=false`。
2. **引擎完全不读 `list/*.bin`**。全仓 grep 引擎侧（`script/`、`framework/`、
   `engine-love2d/`）对 `list/` 与 `.bin` 的引用**为 0**。
3. **引擎用硬编码常量替代了数据文件**，且**截断**：
   - `CC.Effect`（`jyconst.lua:439`）硬编码 53 项，而 `list/effect.bin` 有 64 项
     （BookCalamity / mingdong 有 **200** 项，pineapple 84，RiverLake 70）。
   - 实测对齐：`CC.Effect[1..52]` **逐项等于** `effect.bin[1..52]`，
     `CC.Effect[0]=9` 是 Lua 索引占位（`effect.bin[0]=10` 被丢弃）。
   - `CC.ExtraOffense`（`jyconst.lua:453+`）对应 `list/match.bin`。
4. 因此 **20/20 MOD 的 `effect.bin` 条目数都 > 53**，`eft >= 53` 时
   `war_async.lua:1110/1121-1123` 静默退化（`or 10` / `or 0` 兜底）。

## What Changes

把 `list/*.bin` 从「未判定」推进到「必需 + 引擎真实支持」：

1. **构建期搬运**：`mod_build.lua` 把 `list/*.bin` 复制进产物 `data/`（与
   `allmods-data-fallback` 的解析机制一致）。
2. **运行时装载**：新增惰性装载（**不修改** `jyconst.lua` 的 `CC.Effect` 字面量，
   遵守禁改约束）——若 `data/effect.bin` 存在则读入覆盖，否则保留硬编码兜底。
3. **字段级验证**：`format_spec.lua` 的 `bin_table` 从「4 字节单元 + tail」升级为
   **记录级**（`.bin` 为定长 uint16 数组，记录大小已知）。
4. **审计归类**：`mod_audit.lua` 把 `list/*.bin` 从 `PENDING` 改为
   `REQUIRED`（进产物）或 `LEGACY`（有证据的不需要），`PENDING` 归零。

## In Scope

- `game/tools/mod_build.lua`：`list/*.bin` 搬运入产物
- `game/tools/format_spec.lua`：`bin_table` 记录级验证
- `game/tools/mod_audit.lua`：`list/*.bin` 归类判据
- `game/framework/**` 或**新增**模块：`list/*.bin` 惰性装载（不碰禁改路径）
- `game/tests/unit/**`：对应单元测试
- `openspec/changes/allmods-list-bin-support/**`

## Out of Scope

- `.mid` / `.mp3` / `.sf2`（581 条）——音频转换域，`allmods-spike-music-refs` 已判定
  defer（17/20 MOD 零影响），本 change 不动
- `CC.Effect` 的**字面量本身**（`jyconst.lua:439`）——禁改路径
- `list/end.txt` / `list/start.txt`——纯文本，引擎零消费、无硬编码替代，归 `LEGACY`
- `game/engine-love2d/**`、`game/engine-mud/**`、`reference/allmods/**`

## 父上下文

- Epic: `openspec/epics/2026-10-allmods-compat/epic.md`
- 前置 spike: `openspec/changes/allmods-spike-effect-table/`（`status: done`，44/44，
  三方案对比 + 推荐方案 B）
- 相关: `allmods-slice0c-file-inventory`（文件级归类）、
  `allmods-slice0c-format-spec`（字段级验证）

## 跟踪 ID

| ID | 需求 |
|----|------|
| [REQ-LBIN-1] | `list/*.bin` 进产物 `data/` |
| [REQ-LBIN-2] | `effect.bin` 运行时惰性装载，覆盖硬编码且保留兜底 |
| [REQ-LBIN-3] | `.bin` 字段级记录验证（定长 uint16） |
| [REQ-LBIN-4] | `mod_audit` 中 `list/*.bin` 不再为 `PENDING` |
| [REQ-LBIN-5] | 零回归：未激活 MOD / 无 `effect.bin` 时行为不变 |

## 影响面（实测，非估算）

| 项 | 实测值 | 命令 |
|----|--------|------|
| `list/*.bin` 源文件数 | **82** | `lua -e '...A.auditAll()... count ext==".bin"'` |
| 涉及 MOD 数 | **20/20** | 每个 MOD 都有 `list/effect.bin` |
| 产物 `data/list/` 现状 | **空**（0 文件） | `ls game/mods/pascal/data/list/` |
| `effect.bin` 条目范围 | 64 ~ **200** | `stat -c%s .../effect.bin` ÷ 2 |
| `CC.Effect` 硬编码项数 | **53**（索引 0..52） | `jyconst.lua:439-449` |
| 超出 53 的 MOD | **20/20** | 上表逐 MOD 实测 |
