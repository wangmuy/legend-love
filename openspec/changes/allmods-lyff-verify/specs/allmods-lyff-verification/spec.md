# Spec: allmods-lyff-verification

> Change: `allmods-lyff-verify` · Slice: `allmods-slice8` · Epic: `2026-10-allmods-compat`
> 对应需求：REQ-LYFFV-1 ~ REQ-LYFFV-6

## REQ-LYFFV-1: `diff.md` 逐条审计

**Given** `game/mods/lyff/diff.md` 已生成
**When** 逐条审计其差异
**Then** 105 项「MOD 独有」全部有判定，需修复项 = 0

**And** 105 项 = 46 场额外战斗（92 文件）+ 13 项标准资源
（`cloud.grp/idx`、`dead.png`、`end.png`、`kdef.grp/idx`（1358 事件）、
`kysmod.ini`（BUILD_INPUT）、`open.png`、`ranger.str`、`talk.grp/idx`（5655 对话）、
`title.grp/idx`）。

## REQ-LYFFV-2: 「基准独有」项性质确认

**Given** `diff.md` 列出 23 项「基准独有」
**When** 逐项用文件系统事实 + 引擎引用证据定性
**Then** 每项归入以下三类之一，且**无未解释项**：

| 性质 | 项数 |
|------|-----:|
| 在 save/（源自带，产物逐字节一致） | 3（`d1.grp`/`r1.grp`/`s1.grp`） |
| 死文件（引擎无引用） | 9（`alldef.idx`/`allsin.idx`/`allsinbk.grp` + `d1/d2/d3.idx`/`s1/s2/s3.idx`） |
| 回退原版（含首次存档播种） | 11（`d2/d3.grp`、`r1/r2/r3.idx`、`r2/r3.grp`、`s2/s3.grp`、`thing.grp/idx`） |
| **Σ** | **23** |

**And** `d/s*.idx` 的死文件判据为源码级：`jyconst.lua:80`「S和D由于是固定大小，
因此不再定义idx了」+ 全仓库无 `S_IDX`/`D_IDX` 常量。

## REQ-LYFFV-3: MOD 独有内容确实被加载

**Given** 启动链路初始化完成
**When** 检查运行时内容
**Then** 用**非基线值**证明加载来自 MOD：

| 判据 | lyff | pascal | 区分度 |
|------|------|--------|--------|
| 主角姓名 | AAA | 小蝦米 | ✅ |
| `JY.Person[1]["姓名"]` | 胡斐 | （同集合不同布局） | ✅ |
| `JY.Person[325]["姓名"]` | 枯榮（边界记录） | （不存在，仅 320 条） | ✅ |
| 人物记录数 | 326 | 320 | ✅ |
| 对话条目数 | 5655 | 2977 | ✅ |
| 事件脚本数 | 1358 | 1018 | ✅ |
| `hdgrp` 条目数 | 178 | 115 | ✅ |
| 战斗数 | 138 | 92 | ✅ |
| Thing/Scene/Wugong | 200/84/93 | 200/84/93 | ❌（同数，**不作为证据**） |

**And** 资源路径：`CC.HeadPicFile[1]`/`CC.TalkGrpFile` 指向 `mods/lyff/`；
`CC.ThingPicFile[1]` = `data/thing.idx`（回退原版）。

## REQ-LYFFV-4: 记录数差异 vs 结构异常判定

**Given** lyff 人物段 326 条（vs 320）
**When** 判定差异性质
**Then** 判定为**内容差异**，判据（4 条，全部机器可验证）：

| 条件 | 实测 |
|------|------|
| 动态推导 | `PersonNum = (idx[2]-idx[1])/CC.PersonSize`（`jymain.lua:1747`） |
| 无固定计数 | 不存在 `PERSON_NUM` 等固定计数常量 |
| 边界记录有效 | `Person[325]` = 枯榮/南帝（姓名/外号可读） |
| 字节全覆盖 | `formats=12 checked=242 gaps=0` |

**And** 判据可**外推**到后续所有记录数 ≠ 基线的 MOD。

## REQ-LYFFV-5: 零引擎改动

**Given** 本 change 的改动清单
**When** 检查改动路径
**Then** 以下路径**未被触碰**：
- `game/engine-love2d/**`
- `game/engine-mud/**`
- `game/script/jyconst.lua` 常量定义
- `reference/allmods/**`

## REQ-LYFFV-6: 验证报告

**Given** 审计完成
**When** 检查 `reports/lyff-verify.md`
**Then** 报告包含：
- 结论摘要表
- `diff.md` 逐条审计表（105 + 23）
- 326 人物段判定（4 条判据 + 边界记录证据）
- `hdgrp` 差异 vs 结构异常的判定（含外推链）
- MOD 独有内容的非基线值证据（同数项标注无区分度）
- 零回归实测输出
- 结论
