# Spec: allmods-godsdevils-verification

> Change: `allmods-godsdevils-verify` · Slice: `allmods-slice6` · Epic: `2026-10-allmods-compat`
> 对应需求：REQ-GDV-1 ~ REQ-GDV-6

## REQ-GDV-1: `diff.md` 逐条审计

**Given** `game/mods/GodsDevils/diff.md` 已生成
**When** 逐条审计其差异
**Then** 13 项「MOD 独有」全部有判定，需修复项 = 0

**And** 13 项为：`cloud.grp/idx`、`dead.png`、`end.png`、`kdef.grp/idx`（1123 事件）、
`kysmod.ini`（BUILD_INPUT）、`open.png`、`ranger.str`、`talk.grp/idx`（4640 对话）、
`title.grp/idx`。无额外战斗（fight 92 == pascal 92，同集合）。

## REQ-GDV-2: 「基准独有」项性质确认

**Given** `diff.md` 列出 23 项「基准独有」
**When** 逐项用文件系统事实 + 引擎引用证据定性
**Then** 每项归入以下三类之一，且**无未解释项**：

| 性质 | 项数 |
|------|-----:|
| 在 save/（源自带，产物逐字节一致） | 6（`d1/d2/r1/r2/s1/s2 .grp`） |
| 死文件（引擎无引用） | 9（`alldef.idx`/`allsin.idx`/`allsinbk.grp` + `d1/d2/d3.idx`/`s1/s2/s3.idx`） |
| 回退原版（含首次存档播种） | 8（`r1.idx`/`r2.idx`/`r3.grp`/`r3.idx`/`s3.grp`/`d3.grp`/`thing.grp`/`thing.idx`） |
| **Σ** | **23** |

**And** `d/s*.idx` 的死文件判据为源码级：`jyconst.lua:80`「S和D由于是固定大小，
因此不再定义idx了」+ 全仓库无 `S_IDX`/`D_IDX` 常量。

## REQ-GDV-3: MOD 独有内容确实被加载

**Given** 启动链路初始化完成
**When** 检查运行时内容
**Then** 用**非基线值**证明加载来自 MOD：

| 判据 | GodsDevils | pascal | 区分度 |
|------|------------|--------|--------|
| 主角姓名 | 蝦米 | 小蝦米 | ✅ |
| `JY.Person[1]["姓名"]` | 胡斐 | （不同） | ✅ |
| `JY.Person[2]["姓名"]` | 程靈素 | （不同） | ✅ |
| 对话条目数 | 4640 | 2977 | ✅ |
| 事件脚本数 | 1123 | 1018 | ✅ |
| `hdgrp` 条目数 | 129 | 115 | ✅ |
| fight 数 | 92 | 92 | ❌（同数，**不作为证据**） |

**And** 资源路径：`CC.MMAPPicFile[1]`/`CC.HeadPicFile[1]`/`CC.TalkGrpFile` 指向
`mods/GodsDevils/`；`CC.ThingPicFile[1]` = `data/thing.idx`（回退原版）。

## REQ-GDV-4: `hdgrp` 差异 vs 结构异常判定

**Given** GodsDevils 的 `hdgrp` 为 129 条目（vs 115）
**When** 判定差异性质
**Then** 判定为**内容差异**，判据（Slice 5 ADR-001，第二次外推）：

| 条件 | 实测 |
|------|------|
| 索引驱动（`idxlen/4`） | `lib_love.lua:437` |
| 无固定计数常量 | `CC.HDGRPNum` 等 5 个常量全 `nil` |
| 记录布局常量同 | `182`/`190`/`52`/`136` |
| 字节全覆盖 | `formats=12 checked=475 gaps=0` |

**And** 判据外推链：HeavenSword（125，首次）→ GodsDevils（129，第二次），结果一致。

## REQ-GDV-5: 零引擎改动

**Given** 本 change 的改动清单
**When** 检查改动路径
**Then** 以下路径**未被触碰**：
- `game/engine-love2d/**`
- `game/engine-mud/**`
- `game/script/jyconst.lua` 常量定义
- `reference/allmods/**`

## REQ-GDV-6: 验证报告

**Given** 审计完成
**When** 检查 `reports/godsdevils-verify.md`
**Then** 报告包含：
- 结论摘要表
- `diff.md` 逐条审计表（13 + 23）
- `hdgrp` 差异 vs 结构异常的判定（含外推链）
- MOD 独有内容的非基线值证据（fight 同数标注无区分度）
- 第 3 种存档形态说明
- 零回归实测输出
- 结论
