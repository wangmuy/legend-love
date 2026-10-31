---
status: done
created: 2026-10-27
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

TODO「开放问题」记录：20/20 MOD 的 `music/` 提供 `.mid`（C 引擎 MIDI），
而 Lua 引擎期望 `sound/game%02d.ogg`（原版仅 25 个 ogg），构成「三重不匹配」
（格式 / 槽位 / 编号语义），当时判断「现做 = 猜」，需先做 spike 确定
「需几首、编号怎么对应」。

本 spike 用全 20 MOD 实测把三件事量化到底：

1. **到底有多少 MOD 真正受影响**（不是"20/20 都需要转"）
2. **MOD 数据实际引用了哪些 MIDI id**（`JY.Scene["进门音乐"]` + `WAR.Data["音乐"]`）
3. **哪些引用连源侧 `.mid` 都没有**（作者漏提供 ⇒ MOD 原始缺陷，与转换无关）

结论直接决定：是否需要做 MIDI→OGG 转换流水线，以及范围多大。

## Parent Context

- Epic: `openspec/epics/2026-10-allmods-compat/epic.md`
- TODO: `openspec/epics/2026-10-allmods-compat/TODO.md`（「开放问题（待决策）」首项）
- 相邻 spike: `allmods-spike-effect-table`（同为 Slice 10+ 提出的开放问题）
- 依赖: none（只读实测）

## What Changes

只读 Spike，产出 `reports/music-refs-audit.md`，**不改运行代码**：

1. 实测 20/20 MOD 的 `music/*.mid` 数量、唯一文件数（md5）、音色库（`.sf2`）
2. 用真实启动链读 `JY.Scene["进门音乐"]` 与 `WAR.Data["音乐"]`，得出**实际被引用的 id 集合**
3. 交叉核对：被引用 id 是否在源 `music/<id>.mid` 存在、是否在产物 `sound/game<dd>.ogg` 存在
4. 区分「需转换」（源有、产物无）与「源侧本就缺」（MOD 原始缺陷）
5. 给出是否需要实施、以及若实施的最小范围与代价

## Scope Boundaries

### In Scope
- 只读：`reference/allmods/kys-*/music/`、`game/sound/`、`JY.Scene`/`WAR.Data` 运行值
- 实测脚本与输出留档
- 报告（含受影响 MOD 清单 + id 清单 + 决策建议）

### Out of Scope
- 任何运行代码或构建器修改
- 实际做 MIDI→OGG 转换（属后续 change，若决策要做）
- `sound/*.wav` 音效（已由 `allmods-slice0b-sound-fallback` 覆盖）

## Capabilities

### New Capabilities
- `allmods-music-refs-audit`: 全 20 MOD 的 `music/*.mid` 供给量 vs 实际引用 id 的实测审计（[REQ-MUS-1]~[REQ-MUS-5]）

## Traceability

| REQ | 说明 |
|-----|------|
| [REQ-MUS-1] | 20/20 MOD `music/` 供给量实测（文件数 / 唯一 md5 / 编号范围 / 音色库） |
| [REQ-MUS-2] | 各 MOD 实际被引用 MIDI id 集合（`进门音乐` + `战斗音乐`） |
| [REQ-MUS-3] | 交叉核对：被引用 id 在源 `.mid` 与产物 `.ogg` 的存在性 |
| [REQ-MUS-4] | 区分「需转换」与「源侧本就缺」两类，并给出影响 MOD 数 |
| [REQ-MUS-5] | 决策建议：是否实施 + 最小范围 + 代价（含格式转换的工程约束） |

## DoD

1. `reports/music-refs-audit.md` 产出，五个 REQ 每个都有「实测命令 + 输出 + 结论」
2. 受影响 MOD 数用**全 20 MOD 实测**给出，不用"20/20"这类未验证断言
3. 明确区分「MOD 作者漏提供 `.mid`」与「有 `.mid` 但未转成 ogg」两种情形
4. 给出可执行的决策建议（做 / 不做 / 做多小）
