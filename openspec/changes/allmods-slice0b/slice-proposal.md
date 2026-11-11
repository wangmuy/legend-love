---
status: done
parent_epic: 2026-10-allmods-compat
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Slice Proposal: allmods-slice0b — MOD 兼容地基补漏（资源类型）

## Fit-Level Context
本 slice 评估为 vertical-slice（可测试 MVP）。若实施中范围膨胀，通过 /opsx:explore 重新评估。

## Parent Epic

[2026-10-allmods-compat](../../epics/2026-10-allmods-compat/epic.md) — Slice 0b（Slice 0 的补漏）

## Slice Type

Infrastructure

## 背景：为什么需要 Slice 0b

Slice 0（地基）声称覆盖「构建期拍平 + 数据回退链」，但 2026-10 的资源类型审计
（[resource-type-audit.md](../allmods-slice0/reports/resource-type-audit.md)）发现地基存在
**验收漏洞**：4 类资源被静默丢弃或误判，且全部横跨 20 个 MOD（非某个 MOD 特有），
因此必须在地基层补齐，而不是塞进任何单个 MOD slice。

| 漏洞 | 涉及 MOD | 影响 |
|------|---------|------|
| **A. `sdx/smp`/`wdx/wmp` 未改名为 `smap.*`/`wmap.*`** | 20/20 | 每个 MOD 的场景地图 + 战斗地图贴图被静默替换为原版（mingdong 场景图 4.5MB / 战斗图 2.4MB 全丢） |
| **B. `thing.idx/grp` 源 MOD 不存在** | 20/20 | 物品图标回退原版（**设计性回退**，非缺陷，需固化为预期） |
| **C. `allsinbk.grp` 源 MOD 不存在** | 20/20 | 无害（`LoadSMap` 的 `tmpfilename` 参数从未被引用） |
| **D. `sound/` 未复制、无回退链** | 20/20 | MOD 音效（201 wav，123 独有）无法播放；同名音效被原版覆盖 |

**根因**：Slice 0 的 `diff.md` 是「扁平集合比对」，把 `+ sdx` 与 `- smap.grp` 报成
两个无关的增删项，看不见「改名」语义；spike 报告虽已列出两边清单，却把它归类为
「小写归一 / 同名冲突」（而 `sdx`≠`smap` 不是大小写问题）→ 分类错误导致漏判。

**权威依据**：`reference/allmods/UPedit/UPedit.ini` 的 `[File]` 段显式声明映射：
```
File2=resource\sdx,resource\smp,场景贴图
File3=resource\wdx,resource\wmp,战斗贴图
SMAPIDX=resource\sdx   SMAPGRP=resource\smp
```

## User Story

系统可以在构建期正确识别并转换 MOD 的资源类型别名（`sdx/smp`→`smap.*`、`wdx/wmp`→`wmap.*`），
并让 MOD 的音频资源进入回退链；同时把「引擎不消费 / 死文件 / 设计性回退」的资源判定固化为可回归断言，
使全部 20 个 MOD 的场景地图、战斗地图、音效真正生效，且不误报。

## In Scope

1. **资源类型别名转换（A）** — 构建期把 `sdx`→`smap.idx`、`smp`→`smap.grp`、`wdx`→`wmap.idx`、`wmp`→`wmap.grp`；`diff.md` 增加「改名对」识别，不再误报为增删。
2. **音频复制 + 回退链（D）** — 构建期复制 `sound/` → `mods/<mod>/sound/`；运行期 `CC.MIDIFile`/`CC.ATKFile`/`CC.EFile` 三个 `%02d` 格式串常量支持 MOD 前缀回退。
3. **资源分类固化（B/C + 自定义 + 编辑器副产物）** — 把审计报告的判定（`thing` 设计性回退、`allsinbk` 死参数、`name.grp` 遗留、`fightNNN..`/`new.idx`/`fight23.idx`/`war1.sta` 死文件、`head/`/`item/`/`eft/`/`cc/` 副产物）写成可回归测试与文档，防止未来再次误判为 bug。

## Out of Scope

- **`music/*.mid` 转换** — 格式不兼容（`.mid` vs 引擎 `game%02d.ogg`），需外部音源工具；且 MOD 有 66 首而引擎只有 25 个槽位，编号体系不匹配。需先做「MOD 音乐引用分析」spike 确定是否值得做（见 epic TODO）。
- **`thing.grp` 从 `item/*.png` 派生** — 源 MOD 不提供该文件，回退原版是设计行为；`item/` 是编辑器导出副产物，不做反向构建。
- 任何具体 MOD 的端到端游玩（Slice 1+ 已覆盖 mingdong；其余按 TODO 排序）
- 运行时动态切换 MOD
- 引擎侧数据加载代码重构（本 slice 只做「别名转换 + 回退链扩展」，不改 `PicLoadFile` 等加载器）

## Acceptance Criteria

#### Scenario: 场景/战斗地图别名转换生效
- **GIVEN** `reference/allmods/kys-mingdong/resource/` 含 `sdx`/`smp`/`wdx`/`wmp`
- **WHEN** 运行 `lua tools/mod_build.lua kys-mingdong` 并激活 mingdong
- **THEN** `mods/mingdong/data/` 产出 `smap.idx`/`smap.grp`/`wmap.idx`/`wmap.grp`（不再有 `sdx`/`smp`/`wdx`/`wmp`），且 `CC.SMAPPicFile`/`CC.WMAPPicFile` 指向 MOD 路径，条目数 = MOD 实际值（smap 4635 / wmap 3850），非原版值（4129 / 3701）

#### Scenario: 20 MOD 别名转换全覆盖
- **GIVEN** `reference/allmods/` 下 20 个 MOD 全部提供 `sdx/smp/wdx/wmp`
- **WHEN** 运行 `lua tools/mod_build.lua --all`
- **THEN** 每个 MOD 产物都含 `smap.*`/`wmap.*`，且 0 个 `sdx/smp/wdx/wmp` 残留

#### Scenario: diff 报告识别改名对
- **GIVEN** 别名转换已实现
- **WHEN** 生成 `mods/<mod>/diff.md`
- **THEN** 报告含「改名」小节，列出 `sdx→smap.idx` 等映射；`smap.grp`/`wmap.grp` 不再出现在「基准独有」列表

#### Scenario: 音频资源进入回退链
- **GIVEN** `reference/allmods/kys-mingdong/sound/` 含 201 个 wav（123 独有）
- **WHEN** 构建 mingdong 并激活，播放某 MOD 独有编号的音效
- **THEN** `mods/mingdong/sound/` 存在该 wav；`CC.ATKFile`/`CC.EFile` 解析到 MOD 路径；缺失编号回退 `sound/`

#### Scenario: 资源分类可回归
- **GIVEN** 审计报告已把 8 类资源分类为「需移植 / 设计性回退 / 死文件 / 编辑器副产物」
- **WHEN** 运行 `lua tests/test_runner.lua`
- **THEN** 存在断言固化关键判定（如 `thing.*` 回退原版是预期、`allsinbk.grp` 未被引用），全部通过

#### Scenario: 原版零回归
- **GIVEN** 未激活任何 MOD
- **WHEN** 运行 `lua tests/test_runner.lua`
- **THEN** 全部测试通过，行为与 Slice 0 完成时完全一致

## Affected Domains

- **devops** — `tools/mod_build.lua`（别名转换、`sound/` 复制、diff 改名识别）
- **framework** — `framework/mod_data.lua`（`RewriteConstants` 新增音频格式串常量改写）
- **game-scripts** — `script/jyconst.lua`（如需新增 `sound/` 回退常量，仅消费 `ModData` 结果）
- **legacy-events** — 无（`oldevent` 不受影响）
- **tests** — `tests/unit/test_mod_*.lua`（别名转换、音频回退、资源分类断言）

## 与 Slice 0 的关系

本 slice 是 Slice 0 的**补漏**（foundation gap-fill），不是新地基：
- Slice 0 的 4 个子 change 已完成并归档，本 slice 不重开它们（保持 `done` 状态语义）。
- 本 slice 的产物使 Slice 0 的「构建期拍平」「数据回退链」两条能力**真正完整**。
- 完成后，epic 的 Slice 2-18（逐 MOD）可以直接受益，无需每个 MOD 重复处理同一处别名/音频问题。
