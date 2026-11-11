# Spec: allmods-pig-verification

> Change: `allmods-pig-verify` · Slice: `allmods-slice7` · Epic: `2026-10-allmods-compat`
> 对应需求：REQ-PIGV-1 ~ REQ-PIGV-7

## REQ-PIGV-1: `diff.md` 逐条审计

**Given** `game/mods/pig/diff.md` 已生成
**When** 逐条审计其差异
**Then** **103 项**「MOD 独有」全部有判定，需修复项 = 0

**And** 按类别分解：
| 类别 | 项数 |
|------|-----:|
| 额外战斗（45 场 × 2） | 90 |
| `kdef`/`talk`/`cloud`/`title`（各 grp+idx） | 8 |
| `dead.png`/`end.png`/`open.png` | 3 |
| `ranger.str` | 1 |
| `kysmod.ini`（`BUILD_INPUT`） | 1 |
| **Σ** | **103** |

## REQ-PIGV-2: 「基准独有」项性质确认

**Given** `diff.md` 列出 21 项「基准独有」
**When** 逐项用文件系统事实与运行时 `CC.*` 值定性
**Then** 每项归入以下三类之一，且**无未解释项**：

| 性质 | 项数 |
|------|-----:|
| 回退原版 | 11 |
| 在 save/ | 9（`d1`~`d3`/`r1`~`r3`/`s1`~`s3`） |
| 死文件 | 1（`allsinbk.grp`） |
| **Σ** | **21** |

## REQ-PIGV-3: MOD 独有内容确实被加载

**Given** 启动链路初始化完成
**When** 检查运行时内容
**Then** 用**非基线值**证明加载来自 MOD：

| 判据 | pig | pascal | 区分度 |
|------|-----|--------|--------|
| 主角姓名 | 小小豬 | 小蝦米 | ✅ |
| `JY.Person[1]["姓名"]` | 胡斐 | （不同） | ✅ |
| `JY.Person[2]["姓名"]` | 程靈素 | （不同） | ✅ |
| 对话条目数 | 4123 | 2977 | ✅ |
| 事件脚本数 | 1288 | 1018 | ✅ |
| `hdgrp` 条目数 | 173 | 115 | ✅ |
| 战斗数 | 137 | 92 | ✅ |

## REQ-PIGV-4: `hdgrp` / fight 差异 vs 结构异常判定

**Given** pig 的 `hdgrp` 为 173 条目、fight 为 137 场
**When** 复用 Slice 5 ADR-001 判据
**Then** 两者均判定为**内容差异**：

| 条件 | `hdgrp` | fight |
|------|---------|-------|
| 索引驱动 | `idxlen/4` | 脚本按编号引用 |
| 无固定计数常量 | ✅ | ✅ |
| 字节全覆盖 `gaps=0` | ✅ | ✅ |
| 引擎改动 | 0 | 0 |

**And** 记录为判据的**第 3 次应用**（HeavenSword 125 → GodsDevils 129 → pig 173）。

## REQ-PIGV-5: 45 场额外战斗复核

**Given** 45 场额外战斗
**When** 复核三重证据
**Then** 每场满足：

| # | 证据 | 期望 |
|---|------|------|
| 1 | `diff.md` 提及 | ≥1 次 |
| 2 | 产物 `data/fightNNN.grp` | 存在 |
| 3 | 审计归类 | `REQUIRED` + `in_product=true` |

**And** 产物 `fight*.grp` 总数 = 137。

## REQ-PIGV-6: 零引擎改动

**Given** 本 change 的改动清单
**When** 检查改动路径
**Then** 以下路径**未被触碰**：
- `game/engine-love2d/**`
- `game/engine-mud/**`
- `game/script/jyconst.lua` 常量定义
- `reference/allmods/**`

## REQ-PIGV-7: 验证报告

**Given** 审计完成
**When** 检查 `reports/pig-verify.md`
**Then** 报告包含：
- 结论摘要表
- `diff.md` 逐条审计表（103 + 21）
- `hdgrp` / fight 差异判定 + 判据第 3 次应用记录
- 45 场额外战斗三重证据
- MOD 独有内容的非基线值证据
- 零回归实测输出
- 结论
