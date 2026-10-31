---
status: done
created: 2026-10-27
---
# Tasks: allmods-spike-music-refs

> Change: `allmods-spike-music-refs`（TODO「开放问题（待决策）」首项 spike，只读实测）
> 报告: `reports/music-refs-audit.md`

## Blast Radius（允许改动的路径）

| 路径 | 权限 | 说明 |
|------|------|------|
| `openspec/changes/allmods-spike-music-refs/**` | ✅ 写 | 本 change 文档与报告 |
| `/tmp/*.lua`（探针脚本） | ✅ 写 | 临时实测脚本，不入库 |
| `reference/allmods/**/music/` | 👁 只读 | 读 `.mid` / `.sf2` / `.mp3` |
| `game/sound/**` | 👁 只读 | 读 `*.ogg`（25 个） |
| `game/mods/**` | 👁 只读 | 无写入 |
| `game/script/jyconst.lua` | 👁 只读 | 读 `CC.MIDIFile`（**禁写**） |
| `game/engine-love2d/lib_love.lua` | 👁 只读 | 读 `PlayMIDI` 容错路径（**禁写**） |
| `game/engine-love2d/**` | ❌ 禁改 | 四禁改路径 |
| `game/engine-mud/**` | ❌ 禁改 | 四禁改路径 |
| `game/tools/**` | ❌ 禁改（本 spike） | 若实施转换属后续 change |

## 1. 前置准备

- [x] 1.1 确认引擎音乐路径常量（`CC.MIDIFile = sound/game%02d.ogg`）
- [x] 1.2 确认 id 数据来源（`JY.Scene["进门音乐"]` + `WAR.Data["音乐"]`）
- [x] 1.3 确认产物 `sound/` 仅 25 个 ogg
- [x] 1.4 确认 `PlayMIDI` 对缺失文件的容错路径（`lib_love.lua:588` `pcall`）

## 2. [REQ-MUS-1] 供给量实测（20/20）

- [x] 2.1 逐 MOD 统计 `music/*.mid` 文件数（23~84，合计 **578**）
- [x] 2.2 逐 MOD 统计 `.sf2` 数量（**仅 `pascal` 有 1 个** `mid.sf2`）
- [x] 2.3 按 md5 去重得唯一内容数（**151**）
- [x] 2.4 统计非 `.mid` 音频（`pineapple/37.mp3`、`dream/24.mp3`）
- [x] 2.5 记录结论到报告 §1

## 3. [REQ-MUS-2] 实际引用 id 提取

- [x] 3.1 写探针 `/tmp/midref.lua`（真实启动链 + `LoadRecord(0)`）
- [x] 3.2 读 `JY.Scene[i]["进门音乐"]` 全部索引
- [x] 3.3 读 `WAR.Data[i]["音乐"]` 全部索引
- [x] 3.4 汇总各 MOD 被引用 id 集合（14~43 个）
- [x] 3.5 确认最大引用 id（mingdong 52 / BookCalamity 51 / awaken 81）
- [x] 3.6 确认引用数**远少于**供给数（mingdong 66→43、awaken 84→31）
- [x] 3.7 记录结论到报告 §2

## 4. [REQ-MUS-3] 交叉核对存在性

- [x] 4.1 逐 MOD 核对被引用 id 在源 `music/<id>.mid` 是否存在
- [x] 4.2 逐 MOD 核对被引用 id 在产物 `sound/game<dd>.ogg` 是否存在
- [x] 4.3 列出具体缺失 id 清单（mingdong 26 / awaken 15 / BookCalamity 18）
- [x] 4.4 确认 **17/20 MOD 双侧零缺失**
- [x] 4.5 记录结论到报告 §3

## 5. [REQ-MUS-4] 两类问题分离

- [x] 5.1 识别 A 类「需转换」（源有、产物无）：**mingdong 26 + awaken 15 = 41 个 id**
- [x] 5.2 识别 B 类「源侧本就缺」（MOD 原始缺陷）：**BookCalamity 20 个 id**
- [x] 5.3 识别 C 类「零影响」：**17/20 MOD**（含 `pascal`）
- [x] 5.4 计算去重后唯一 id 数（41 − 7 重叠 = **34**）
- [x] 5.5 确认运行时后果（`pcall` 静默失败，无 BGM，不崩溃）
- [x] 5.6 记录结论到报告 §4

## 6. [REQ-MUS-5] 决策建议

- [x] 6.1 列出 4 个方案（不做 / 只转 A 类 / 全转 / 运行时 MIDI 播放器）
- [x] 6.2 论证方案 B 需外部工具（`timidity`/`fluidsynth`），与「构建期纯 Lua」冲突
- [x] 6.3 确认不阻塞 epic（17/20 MOD 零影响，基线零影响）
- [x] 6.4 确认 BookCalamity 无法修复（无源可转）
- [x] 6.5 给出若实施的最小范围（可选工具脚本，不入 `mod_build.lua` 主流程）
- [x] 6.6 给出推荐（「已审计，不阻塞，可选实施」）
- [x] 6.7 记录结论到报告 §5

## 7. 报告产出与自查

- [x] 7.1 `reports/music-refs-audit.md` 产出（297 行）
- [x] 7.2 五个 REQ 每个都有「实测命令 + 输出 + 结论」
- [x] 7.3 附复现脚本（`/tmp/midref.lua` 完整源码 + 去重命令）
- [x] 7.4 修正 TODO 初稿的 5 处错误断言（§7 差异表）
- [x] 7.5 缺陷定级表（4 项，区分构建缺口 / MOD 原始缺陷 / 风险项 / 无需处理）
- [x] 7.6 自查：所有数字可追溯到命令输出，无估计值

## DoD 校验

| DoD | 证据 | 状态 |
|-----|------|:---:|
| 报告产出 5 个 REQ | `reports/music-refs-audit.md` §1~§5 | ✅ |
| 每 REQ 有命令+输出+结论 | 各节内联命令与输出表 | ✅ |
| 受影响 MOD 数用全 20 MOD 实测 | §3 表 20 行全列 | ✅ |
| 区分「源侧缺」vs「未转换」 | §4 三类分离表 + §3/§4 具体清单 | ✅ |
| 给出可执行决策建议 | §5 方案对比 + 推荐 + 最小范围 | ✅ |
| 修正初稿错误 | §7 差异表（5 处） | ✅ |
