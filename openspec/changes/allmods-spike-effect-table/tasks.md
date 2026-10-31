---
status: done
created: 2026-10-27
---
# Tasks: allmods-spike-effect-table

> Change: `allmods-spike-effect-table`（Slice 10 提出的开放问题 spike，只读实测）
> 报告: `reports/effect-table-audit.md`

## Blast Radius（允许改动的路径）

| 路径 | 权限 | 说明 |
|------|------|------|
| `openspec/changes/allmods-spike-effect-table/**` | ✅ 写 | 本 change 文档与报告 |
| `/tmp/*.lua`（探针脚本） | ✅ 写 | 临时实测脚本，不入库 |
| `reference/allmods/**` | 👁 只读 | 读 `list/effect.bin` |
| `game/mods/**` | 👁 只读 | 读产物 `eft.idx` |
| `game/data/**` | 👁 只读 | 读基线 `eft.idx` |
| `game/script/jyconst.lua` | 👁 只读 | 读 `CC.Effect` 字面量（**禁写：`CC.*` 常量**） |
| `game/framework/war_async.lua` | 👁 只读 | 读消费点 |
| `game/engine-love2d/**` | ❌ 禁改 | 四禁改路径 |
| `game/engine-mud/**` | ❌ 禁改 | 四禁改路径 |
| `game/tools/**` | ❌ 禁改（本 spike） | 方案 B 的实施属后续 change |

## 1. 前置准备

- [x] 1.1 确认 `CC.Effect` 定义位置与项数（`jyconst.lua:439-449`，53 项，索引 `0..52`）
- [x] 1.2 确认消费点（`war_async.lua:1110` framenum、`:1121-1123` starteft）
- [x] 1.3 确认权威来源（`UPedit.ini:80` → `Effect=list\effect.bin`）
- [x] 1.4 确认 `list/effect.bin` 在 20/20 源目录存在（字节数 128~400）

## 2. [REQ-EFF-1] 语义链实测

- [x] 2.1 遍历 20/20 MOD 读 `list/effect.bin`（int16 LE），统计条目数与非零项
- [x] 2.2 读各 MOD 产物 `eft.idx`，按 `len/4 - 1` 算段数
- [x] 2.3 对比 `sum(effect.bin) == eft 段数`，逐 MOD 列出
- [x] 2.4 确认 13/20（含 `pascal`）精确相等，6 个有 ±偏差
- [x] 2.5 判定偏差责任方（MOD 数据侧不同步，非解析口径问题）
- [x] 2.6 记录结论到报告 §1

## 3. [REQ-EFF-2] `CC.Effect` 逐项对比

- [x] 3.1 从 `jyconst.lua` 提取 53 项字面量为数组
- [x] 3.2 与 `pascal` `effect.bin` 前 53 项逐项比对
- [x] 3.3 确认**仅索引 0 差异**（`9` vs `10`），其余 52 项全同
- [x] 3.4 确认 `pascal[53..63]` 全为 0（11 项填充）
- [x] 3.5 统计 20/20 MOD 的前 53 项差异数 + 第 53 项起非零项数
- [x] 3.6 判定「差异数 1」的 13 个 MOD 均为索引 0 同源偏差（含基线）
- [x] 3.7 识别**真越界 5 个**（BookCalamity/RiverLake/books/mingdong/pineapple）
- [x] 3.8 记录结论到报告 §2

## 4. [REQ-EFF-3] 运行时后果量化

- [x] 4.1 用完整启动链取 `CC`（`mod_boot_harness` + `jymain`）
- [x] 4.2 复现 `framenum` 计算（`CC.Effect[eft] or 10`）
- [x] 4.3 复现 `starteft` 求和循环
- [x] 4.4 对 `eft ∈ {0,1,52,53,55,69,83,168,198}` 逐个求值
- [x] 4.5 确认 `eft>52` 时 `framenum` 恒 10、`starteft` 恒 712
- [x] 4.6 确认**不崩溃**（静默退化，无日志无报错）
- [x] 4.7 记录结论到报告 §3

## 5. [REQ-EFF-4] 越界影响面（全 20 MOD）

- [x] 5.1 写探针 `/tmp/eftv.lua`（真实启动链 + `LoadRecord(0)` → 读 `JY.Wugong`）
- [x] 5.2 逐 MOD 统计「有 `eft` 的武功数」「`max(eft)`」「越界（`>52`）条目数」
- [x] 5.3 确认 **7/20 MOD** 有越界（BookCalamity 296 / mingdong 136 / pineapple 62 /
      pig3dos 52 / RiverLake 10 / books 2 / awaken 1）
- [x] 5.4 确认其余 **13 个（含 `pascal`）`max(eft) == 52`**，恰好匹配 53 项表
- [x] 5.5 与 Slice 10 估计「7/20」交叉验证（一致 ✅）
- [x] 5.6 与 Slice 12（pineapple 62/174）、Slice 13（books 2 条 max 55）交叉验证（一致 ✅）
- [x] 5.7 记录结论到报告 §4

## 6. [REQ-EFF-5] 三方案对比

- [x] 6.1 方案 A（直接改 `CC.Effect` 常量）——判定**违反四禁改**（`jyconst.lua` `CC.*`），且
      一张表无法覆盖 5 个 MOD 的不同帧数
- [x] 6.2 方案 B（构建期搬运 + 运行时惰性装载）——列出 4 项优点、改动点（构建器 + 装载函数
      + 接线调用，**不写字面量**）、~35 行规模
- [x] 6.3 方案 C（运行时读源目录）——判定破坏「产物自包含」约束
- [x] 6.4 确认推荐方案 B，并论证「零回归」（13 个 MOD `effect.bin[53:]` 全 0）
- [x] 6.5 给出实施代价表（4 项改动 + 行数估计）
- [x] 6.6 记录结论到报告 §5

## 7. 报告产出与自查

- [x] 7.1 `reports/effect-table-audit.md` 产出（331 行）
- [x] 7.2 五个 REQ 每个都有「实测命令 + 输出 + 结论」
- [x] 7.3 附复现脚本（`/tmp/eftv.lua` 完整源码 + 内联 python 脚本）
- [x] 7.4 缺陷定级表（4 项，区分引擎限制 / 基线偏差 / MOD 数据 / 构建器缺口）
- [x] 7.5 与既有 Slice 10/12/13/14 文档交叉验证一致
- [x] 7.6 自查：报告内所有数字可追溯到命令输出，无估计值

## DoD 校验

| DoD | 证据 | 状态 |
|-----|------|:---:|
| 报告产出 5 个 REQ | `reports/effect-table-audit.md` §1~§5 | ✅ |
| 每 REQ 有命令+输出+结论 | 各节内联命令与输出表 | ✅ |
| 数字可复现 | §6 附完整探针源码 | ✅ |
| 越界影响面用全 20 MOD 实测 | §4 表 20 行全列 | ✅ |
| 指出 `effect.bin` 未进产物 | §0 摘要 + §5 方案 B 前提 | ✅ |
