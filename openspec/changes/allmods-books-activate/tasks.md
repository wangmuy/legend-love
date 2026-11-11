---
status: done
created: 2026-10-26
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice13
---
# Tasks: allmods-books-activate

> 全部任务已完成（`[x]`）。每条 DoD 均可在 `game/` 下复跑。

## Blast Radius

| 路径 | 允许 | 说明 |
|------|:----:|------|
| `game/mods/books/**` | ✅ 写 | 构建产物 |
| `openspec/changes/allmods-books-activate/**` | ✅ 写 | 本 change |
| `openspec/changes/allmods-slice13/**` | ✅ 写 | slice + manifest |
| `openspec/epics/2026-10-allmods-compat/**` | ✅ 写 | 索引 |
| `game/tools/**` | ⚠ 仅限已记录缺陷 | 本 MOD 未发现新缺陷 |
| `game/tests/**` | ⚠ 只读 | 用位置参数调用 |
| `game/engine-love2d/**` | ❌ 禁 | 四禁改 |
| `game/engine-mud/**` | ❌ 禁 | 四禁改 |
| `game/script/jyconst.lua` 常量 | ❌ 禁 | 四禁改 |
| `reference/allmods/**` | ❌ 禁 | 只读 |

---

## 组 1 — 构建与机器验证（REQ-BK-1~3）

- [x] **T1.1** 清理 `game/active_mod.txt`
      ▸ DoD: `ls game/active_mod.txt` 返回 `No such file`
- [x] **T1.2** 构建 MOD
      ▸ `lua tools/mod_build.lua kys-books`
      ▸ DoD: 输出含 `data files=392, saves=19, sound=84, events=573, talk=6655`
- [x] **T1.3** 生成 `diff.md`
      ▸ DoD: `game/mods/books/diff.md` 存在且含 `added`/`removed` 两段
- [x] **T1.4** 穷举审计
      ▸ `lua tools/mod_audit.lua --mod books --evidence`
      ▸ DoD: `total=525 in_product=495 not_in_product=30 unclassified=0 bad_evidence=0`
      ▸ DoD: `490+4+3+1+27 = 525` 且 `495+30 = 525`
      ▸ DoD: `evidence: checked=8 failed=0`
- [x] **T1.5** 格式覆盖
      ▸ `lua tools/format_spec.lua --mod books`
      ▸ DoD: `formats=12 checked=287 gaps=0`
- [x] **T1.6** 单 MOD 结构检查
      ▸ `MOD_SLUG=books lua tools/mod_check_one.lua`
      ▸ DoD: `PERSON=382 THING=200 SCENE=84 WUGONG=100 HERO=古天奇 STRINGS=OK EVENTS=OK SAVE=OK`

## 组 2 — 启动链路（REQ-BK-4）

- [x] **T2.1** 独立进程启动
      ▸ `lua tests/unit/boot_one_mod.lua books 382 200 84 100 古天奇`
      ▸ DoD: `RESULT books: OK`
      ▸ DoD: 12 条 `[PASS]` 全绿，含 `CC.SceneSize=52` / `CC.WugongSize=136` / 扫描字段 1548
- [x] **T2.2** 验证位置参数是期望值（非传即通）
      ▸ DoD: 传错参数（如 `books 381 200 84 100 古天奇`）必须 FAIL —— 由 `boot_one_mod.lua`
        的「期望/实际」双列输出证明（每条 `[PASS] xxx (期望 N, 实际 N)`）

## 组 3 — 记录段边界（REQ-BK-5）

- [x] **T3.1** 解析 `ranger.idx` offsets
      ▸ DoD: `[836, 70360, 108360, 112728, 126328, 126478]`
- [x] **T3.2** 五段整除
      ▸ DoD: `69524/182=382`、`38000/190=200`、`4368/52=84`、`13600/136=100`、`150/50=3`，余数全 0
- [x] **T3.3** 头尾校验
      ▸ DoD: `Σ(段长)=126328`，`grp=126478` ⇒ 头 836 + 尾 150
- [x] **T3.4** 基线差异对照
      ▸ DoD: 基线 `[836, 65476, 117476, 122684, 136262, 136412]` / `[64640, 52000, 5208, 13578, 150]`
      ▸ DoD: Thing/Scene/Shop **同**，Person 320→382 **异**，Wugong 93→100 **异**，`grp` 136412→126478 **变小**

## 组 4 — 内容真实性（REQ-BK-6）

- [x] **T4.1** 边界记录语义
      ▸ DoD: `Person[0]=古天奇/天下奇男子`、`Person[1]=胡斐/雪山飛狐`、`Person[381]=閻基/毒手藥王`
      ▸ DoD: `Thing[0]=腐骨穿心膏`、`Thing[199]=最後`、`Scene[0]=崑侖山`、`Scene[83]=待定`
- [x] **T4.2** 证明 hint 不是编码失败
      ▸ DoD: 确认 `ranger.grp` 中 offset 844 起为 `P0000` 字节，运行时被回填为 `古天奇`
- [x] **T4.3** `ranger.str` 侧表统计
      ▸ DoD: 964 行总 / 957 条有效；Person 419+Thing 368+Scene 72+Wugong 98 = 957
      ▸ DoD: Name 670 + Nick 119 + Desc 168 = 957；唯一 934 / 重复 23
- [x] **T4.4** `573` 事件 / `6655` 对话
      ▸ DoD: 构建输出含 `events=573, talk=6655`
      ▸ DoD: `diff.md` 新增列表含 `kdef.grp/idx` 与 `talk.grp/idx`
- [x] **T4.5** `kysmod.ini` 双进程对照
      ▸ DoD: 28 项 `nil→有值`；5 项与基线同值（`NewGameSceneID 70`/`NewGameEvent 691`/`NewGameSceneX 19`/`NewGameSceneY 20`/`MoneyID 174`）

## 组 5 — `kysmod.ini`（REQ-BK-7）

- [x] **T5.1** 源/产物逐行 diff
      ▸ DoD: 各 96 行，仅首行注释差异
- [x] **T5.2** 键统计
      ▸ DoD: 非注释 52（`constant 36 / system 13 / music 3`）
- [x] **T5.3** 映射与 unknown
      ▸ DoD: 映射 56 个 CC 键；`unknown` 仅 `SOUND3D` 1 个

## 组 6 — `hdgrp` 696（REQ-BK-8）

- [x] **T6.1** 条目数
      ▸ DoD: `hdgrp.idx=2784B` → 696；`hdgrp.grp=1233815B`
- [x] **T6.2** 逐条 RLE 头解析
      ▸ DoD: `PNG=0 RLE=474 零长=222 头异常=0`；`w 1..82 / h 1..70`
- [x] **T6.3** 零长段分块
      ▸ DoD: `(215,54)`、`(270,2)`、`(273,165)`、`(695,1)`，`Σ=222`
- [x] **T6.4** 证明零长不计 gap
      ▸ DoD: `format_spec.lua` 的 `idx_grp_rle` 家族 + `verifyPair` 用 `b > a` 跳过 → `gaps=0`
- [x] **T6.5** 基线对照
      ▸ DoD: 基线 115 = PNG 2 + RLE 112 + 零长 1，`w 13..56 / h 9..58`

## 组 7 — `Wugong` 100（REQ-BK-9）

- [x] **T7.1** 字段全量统计
      ▸ DoD: `Wugong_S` 64 字段，全 nil 字段数 **0**，`名称` 非空 **100/100**
- [x] **T7.2** 边界抽样（真实字段名）
      ▸ DoD: `[0] 普通攻擊/1/1/12/1` … `[99] 震天三十掌/1/1/27/8`
- [x] **T7.3** `CC.Effect` 越界
      ▸ DoD: `CC.Effect` 键数 53、`max键=52`；越界 2 条、`max=55`

## 组 8 — fight 三分支（REQ-BK-10）

- [x] **T8.1** 全量扫描 0..177
      ▸ DoD: `PicGetXY` 有效 168、`0x0` 10
      ▸ DoD: `0x0` 集合 = `30,39,52,66,104,110,111,112,113,164`
- [x] **T8.2** `ZERO_BYTE` 2 个
      ▸ DoD: `fight104`/`fight164` 的 `.grp`/`.idx` 均 0B，源侧亦 0B
- [x] **T8.3** `FILE_MISSING` 4 个被引用
      ▸ DoD: `30(風清揚)/39(石中玉)/66(段正淳)/110(張召重)`，源与基线均 MISSING
- [x] **T8.4** 未引用的 4 个缺失
      ▸ DoD: `52/111/112/113` 引用次数 0
- [x] **T8.5** 引用面统计
      ▸ DoD: 被引用不同代号 **174**（min 0 / max 185）
- [x] **T8.6** 不可区分性声明
      ▸ DoD: 文档显式写明 `ZERO_BYTE` 与 `FILE_MISSING` 的 `PicGetXY` 均为 `0,0`，
        分支判定靠文件事实 + `lib_love.lua:435`
- [x] **T8.7** 负对照
      ▸ DoD: 人造代号 400 → `PicGetXY=0x0` 且 `pcall=true`

## 组 9 — 产物溯源（REQ-BK-11~12）

- [x] **T9.1** `ranger.str` 源侧不存在
      ▸ DoD: `find ../reference/allmods/kys-books -name "ranger.str"` 无输出
- [x] **T9.2** 判定为构建产物
      ▸ DoD: 文档写明由 `tools/mod_encoding.lua` hint 抽取生成
- [x] **T9.3** `name.*` 三重 0 命中
      ▸ DoD: 产物 / diff 新增列表 / 源目录 各 0
- [x] **T9.4** 与有 `name.grp` 的 4 个 MOD 对照
      ▸ DoD: BookCalamity/Dragon/pineapple/RiverLake 有、books 无

## 组 10 — 8 道门禁（REQ-BK-13）

- [x] **T10.1** `lua tests/test_runner.lua` ▸ DoD: `通过: 1842 失败: 0`
- [x] **T10.2** `lua tools/mod_build.lua --verify-pascal` ▸ DoD: PASS，`mismatches=0`，`known-deviations=3`
- [x] **T10.3** `lua tools/mod_build.lua --all` ▸ DoD: `20 mods, 0 build failures`
- [x] **T10.4** `lua tools/mod_check.lua` ▸ DoD: `20 MOD, 通过 20, 失败 0`
- [x] **T10.5** `lua tools/mod_audit.lua --all --evidence` ▸ DoD: `unclassified=0 bad_evidence=0`，`failed=0`
- [x] **T10.6** `lua tools/format_spec.lua --all` ▸ DoD: `gaps=0`
- [x] **T10.7** 20 MOD `save/` vs 源 ▸ DoD: 真实问题 0
- [x] **T10.8** 禁改路径 ▸ DoD: 三处 porcelain 为空；`jyconst.lua` 无 `CC.*=` 增删

## 组 11 — 文档

- [x] **T11.1** `proposal.md`（In/Out of Scope + REQ-BK-1~13）▸ DoD: 文件存在，含 13 个 REQ
- [x] **T11.2** `design.md`（ADR-BK-001~006 + 12 Negative Constraints + Review Checklist）▸ DoD: 全 `[x]`
- [x] **T11.3** `specs/allmods-books-activation/spec.md`（Given/When/Then）▸ DoD: 13 个 REQ 各至少 1 场景
- [x] **T11.4** `tasks.md`（本文件）▸ DoD: 0 个未勾选
- [x] **T11.5** `verification.md` ▸ DoD: 每条 REQ 附实测命令 + 输出 + 结论
