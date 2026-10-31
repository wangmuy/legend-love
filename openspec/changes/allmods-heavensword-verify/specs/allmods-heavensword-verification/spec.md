# Spec: allmods-heavensword-verification

> Change: `allmods-heavensword-verify` · Slice: `allmods-slice5` · Epic: `2026-10-allmods-compat`
> 对应需求：REQ-HSV-1 ~ REQ-HSV-6

## REQ-HSV-1: `diff.md` 逐条审计

**Given** `game/mods/HeavenSword/diff.md` 已生成
**When** 逐条审计其差异
**Then** 15 项「MOD 独有」全部有判定，需修复项 = 0

**And** 15 项含 1 场额外战斗：`fight073.grp`/`.idx`。

## REQ-HSV-2: 「基准独有」项性质确认

**Given** `diff.md` 列出 21 项「基准独有」
**When** 逐项用文件系统事实与运行时 `CC.*` 值定性
**Then** 每项归入以下三类之一，且**无未解释项**：

| 性质 | 项数 |
|------|-----:|
| 回退原版（含首次存档时播种） | 19 |
| 在 save/ | 1（`r1.idx`） |
| 死文件 | 1（`allsinbk.grp`） |
| **Σ** | **21** |

**And** 注意：`d1.grp`/`s1.grp` **不在** save/（HeavenSword 源自带存档包不含它们），
归为「回退原版（首次存档时播种）」。

## REQ-HSV-3: MOD 独有内容确实被加载

**Given** 启动链路初始化完成
**When** 检查运行时内容
**Then** 用**非基线值**证明加载来自 MOD：

| 判据 | HeavenSword | pascal | 区分度 |
|------|-------------|--------|--------|
| 主角姓名 | 楊千葉 | 小蝦米 | ✅ |
| `JY.Person[1]["姓名"]` | 胡斐 | （不同） | ✅ |
| `JY.Person[2]["姓名"]` | 程靈素 | （不同） | ✅ |
| 对话条目数 | 3315 | 2977 | ✅ |
| 事件脚本数 | 1066 | 1018 | ✅ |
| `hdgrp` 条目数 | 125 | 115 | ✅ |

**And** 资源路径全部指向 `mods/HeavenSword/`。

## REQ-HSV-4: `hdgrp` 差异 vs 结构异常判定

**Given** HeavenSword 的 `hdgrp` 为 125 条目（vs 115）
**When** 判定差异性质
**Then** 判定为**内容差异**，判据为：

| 条件 | 实测 |
|------|------|
| 索引驱动（`idxlen/4`） | `lib_love.lua:437` |
| 无固定计数常量 | `CC.HDGRPNum`/`HDPicNum`/`MAX_HEAD_NUM`/`HDGRP`/`HeadNum` 全 `nil` |
| 记录布局常量同 | `182`/`190`/`52`/`136` |
| 字节全覆盖 | `gaps=0` |

**And** 判据可**外推**到后续 hdgrp ≠ 115 的 MOD。

## REQ-HSV-5: 零引擎改动

**Given** 本 change 的改动清单
**When** 检查改动路径
**Then** 以下路径**未被触碰**：
- `game/engine-love2d/**`
- `game/engine-mud/**`
- `game/script/jyconst.lua` 常量定义
- `reference/allmods/**`

## REQ-HSV-6: 验证报告

**Given** 审计完成
**When** 检查 `reports/heavensword-verify.md`
**Then** 报告包含：
- 结论摘要表
- `diff.md` 逐条审计表（15 + 21）
- `hdgrp` 差异 vs 结构异常的判定
- MOD 独有内容的非基线值证据
- 缺陷 D 的说明
- 零回归实测输出
- 结论
