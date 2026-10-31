# Spec: allmods-ptt-verification

> Change: `allmods-ptt-verify` · Slice: `allmods-slice9` · Epic: `2026-10-allmods-compat`
> 对应需求：REQ-PTTV-1 ~ REQ-PTTV-9

## REQ-PTTV-1: `diff.md` 逐条审计

**Given** `game/mods/ptt/diff.md` 已生成
**When** 逐条审计其差异
**Then** **154 项**「MOD 独有」全部有判定，需修复项 = 0

**And** 按类别分解：
| 类别 | 项数 |
|------|-----:|
| 额外战斗（70 场 × 2） | 140 |
| `kdef`/`talk`/`cloud`/`title`（各 grp+idx） | 8 |
| `end.png`/`open.png` | 2 |
| `ranger.str`（构建产物） | 1 |
| `kysmod.ini`（`BUILD_INPUT`/`in_product=true`） | 1 |
| `talkutf8.txt`（`BUILD_INPUT`/`in_product=false`） | 1 |
| `save.zip`（`PLATFORM_ARTIFACT`） | 1 |
| **Σ** | **154** |

**And** 审计 `total=596` 恰等于源文件总数 596（`find reference/allmods/kys-ptt -type f | wc -l`），
即**每个源文件都被归类**，`unclassified=0 bad_evidence=0`。

## REQ-PTTV-2: 「基准独有」项性质确认

**Given** `diff.md` 列出 21 项「基准独有」
**When** 逐项用文件系统事实与运行时 `CC.*` 值定性
**Then** 每项归入以下四类之一，且**无未解释项**：

| 性质 | 项数 | 明细 |
|------|-----:|------|
| 在 save/（源自带 `.grp`） | 9 | `d1`~`d3`/`r1`~`r3`/`s1`~`s3` 的 `.grp` |
| 首次播种（源无 `.idx`） | 9 | 对应的 `.idx`；`ModData.SeedSaveSlot` 从 `data/ranger.idx` 播种 |
| 回退原版 | 2 | `thing.grp`/`thing.idx`（`CC.ThingPicFile[1]`/`[2]` = `data/...`） |
| 死文件 | 1 | `allsinbk.grp`（`CC.TempS_Filename` 仅作 `LoadSMap` 第 2 实参，引擎形参 `tmpfilename` 零使用） |
| **Σ** | **21** | |

## REQ-PTTV-3: MOD 独有内容确实被加载

**Given** 启动链路初始化完成（`LoadRecord(0)`）
**When** 检查运行时内容
**Then** 用**非基线值**证明加载来自 MOD：

| 字段 | ptt | pascal 基线 |
|------|-----|------------|
| `Person[0].姓名` | 鄉民 | 小蝦米 |
| `Thing[0].名称` | 千面人蠻牛 | 康倍特 |
| `Person[384].姓名`（末条） | 卓不凡 | —（基线仅 320 条） |
| `Thing[213].名称`（末条） | 高昌迷宮地圖 | —（基线仅 200 条） |
| `PersonNum/ThingNum/SceneNum/WugongNum` | 385/214/90/108 | 320/200/84/93 |
| talk | 5689 条 | 2977 |
| events | 1229 个 | 1018 |
| fight | 162 场 | 92 |

**And** 回退链生效：
- `CC.HeadPicFile[1]` = `mods/ptt/data/hdgrp.idx`
- `CC.TalkGrpFile` = `mods/ptt/script/oldtalk.grp`
- `CC.R_GRPFilename[1]`/`D_Filename[1]`/`S_Filename[1]` = `mods/ptt/save/{r1.grp,d1.grp,s1.grp}`

## REQ-PTTV-4: `hdgrp` / fight / 记录段 差异 vs 结构异常判定

**Given** ptt 的 `hdgrp` 204（vs 115）、fight 162（vs 92）、4 段记录数 385/214/90/108（vs 320/200/84/93）
**When** 应用判据
**Then** 三者均判定为**内容差异**：

**`hdgrp`（Slice 5 ADR-001，第 5 次应用）**：
| 条件 | 实测 |
|------|------|
| 索引驱动 | 816 B = 204 × 4；`PicLoadFile` 用 `idxlen/4` |
| 无固定计数 | `CC.HDGRPNum` 等全 `nil` |
| 字节全覆盖 | `gaps=0` |

**记录段（Slice 8 统一判据，第 2 次应用）**：
| 条件 | 实测 |
|------|------|
| 段长整除 | 70070=385×182 / 40660=214×190 / 4680=90×52 / 14688=108×136 / 150=3×50 |
| 索引驱动 | `jymain.lua:1747` 按 `idx[k+1]-idx[k]` 推导 |
| 无固定计数 | 无 `PERSON_NUM` 类常量 |
| 边界有效 | 末条 hint `P0489`/`N0448`/`T0395`/`T20395`/`TD0395`/`S0088`/`W0107`；名称可读 |
| 字节全覆盖 | `gaps=0` |

**Then** 判定为内容差异（零引擎改动），并记录判据外推链：
`hdgrp` **125 → 129 → 173 → 178 → 204**（第 5 次）；
记录段 **lyff(1 段) → ptt(4 段全异)**（第 2 次）。

## REQ-PTTV-5: 70 场额外战斗复核

**Given** 70 场额外战斗（本 epic 最多）
**When** 复核三重确认
**Then** 三重证据全部通过：
1. `diff.md` 提及 140 项（70 场 × 2）
2. 产物 `fight*.grp` = 162；`comm -13` 差集 = 70
3. 162 个 `fight*.grp` 全部 `REQUIRED`/`in_product=true`，其他类别 = 0

**And** 至少 5 场抽样逐项复核（`fight073`/`fight130`/`fight154`/`fight195`/`fight216`）。

## REQ-PTTV-6: 零引擎改动 / 零代码改动

**Given** 本 slice 的全部改动
**When** 检查 `git diff`
**Then** 不得修改：
- `game/engine-love2d/**`
- `game/engine-mud/**`
- `game/script/jyconst.lua` 常量定义
- `reference/allmods/**`
- `game/tools/**`（本 slice 零代码改动）
- `game/framework/**`（本 slice 零代码改动）

## REQ-PTTV-7: 验证报告

**Given** 审计完成
**When** 产出报告
**Then** `reports/ptt-verify.md` 必须含：
- 逐条审计表（154 + 21）
- 判据应用记录（`hdgrp` 第 5 次 / 记录段第 2 次）
- 70 场额外战斗三重证据
- MOD 独有内容非基线值证据
- 零回归实测输出
- 第 3 梯队进度

## REQ-PTTV-8: `eft/` 105 个 PNG 的 `EDITOR_DUMP` 证据

**Given** ptt 源有 `eft/` 目录 105 个文件
**When** 判定其是否为「需要」
**Then** 必须给出 **4 条机器可复核证据**：
1. `mod_build.lua:567` `IGNORE_DIRS = { head=true, item=true, eft=true }`
2. `grep -rn "eft/" game/...` → 引擎 0 引用
3. 产物 `game/mods/ptt/eft` 不存在
4. 审计 105 项全为 `EDITOR_DUMP`/`in_product=false`/`needed=false`

## REQ-PTTV-9: PENDING 27 项的显式边界

**Given** 27 项审计类别为 `PENDING`
**When** 说明其归属
**Then** 必须显式列出且**不得**用「不确定」笼统表述：

| 项 | 数量 | 归属 |
|----|-----:|------|
| `music/*.mid` | 23 | 全局遗留 spike（C 引擎 MIDI vs Lua 引擎 `sound/game%02d.ogg` 三重不匹配） |
| `list/*.bin` | 4 | C 引擎列表数据，Lua 引擎无读取路径 |

**And** 必须说明 `needed=nil` 与 `needed=false` 的区别：未判定 ≠ 判定为不需要。
