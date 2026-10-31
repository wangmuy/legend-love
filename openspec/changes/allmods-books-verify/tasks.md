---
status: done
created: 2026-10-26
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice13
---
# Tasks: allmods-books-verify

## Blast Radius

| 路径 | 允许 | 说明 |
|------|:----:|------|
| `openspec/changes/allmods-books-verify/**` | ✅ 写 | 本 change |
| `openspec/changes/allmods-slice13/**` | ✅ 写 | manifest 同步 |
| `openspec/epics/2026-10-allmods-compat/**` | ✅ 写 | 索引 |
| `game/mods/books/**` | ⚠ 只读 | 审计对象 |
| `game/tools/**` | ❌ 不改 | 未发现新缺陷 |
| `game/engine-love2d/**` | ❌ 禁 | 四禁改 |
| `game/engine-mud/**` | ❌ 禁 | 四禁改 |
| `game/script/jyconst.lua` 常量 | ❌ 禁 | 四禁改 |
| `reference/allmods/**` | ❌ 禁 | 只读 |

---

## 组 1 — `diff.md` 双向集合相等（REQ-BKV-1）

- [x] **T1.1** 解析 `added` / `removed` 集合
      ▸ DoD: `added=184`、`removed=21`（正则 `^\s*-\s*\+\s*(\S+)\s*$` / `^\s*-\s*-\s*(\S+)\s*$`）
- [x] **T1.2** 独立计算实测独有集合
      ▸ DoD: `mod_only=184`、`base_only=21`（基于 `set(os.listdir) - set(...)`）
- [x] **T1.3** **集合相等**比对（非数量比对）
      ▸ DoD: `added == mod_only` → `True`，差集为空
      ▸ DoD: `removed == base_only` → `True`，差集为空
- [x] **T1.4** 同名异容不计入 add/remove
      ▸ DoD: `同名异容=27`（6 fight + 21 非 fight）未出现在 `added`/`removed` 中

## 组 2 — `removed` 21 三分法（REQ-BKV-2）

- [x] **T2.1** 13 槽改道 save
      ▸ DoD: `d1.grp r1.grp r1.idx r2.grp r2.idx r3.grp r3.idx s1.grp s1.idx s2.grp s2.idx s3.grp s3.idx`
      ▸ DoD: 与源 `save/` md5 全同 `13/13`
- [x] **T2.2** 5 槽缺席走回退
      ▸ DoD: `d1.idx d2.grp d2.idx d3.grp d3.idx`，源 `save/` 中同样不存在
- [x] **T2.3** 3 模板回退
      ▸ DoD: `thing.grp thing.idx allsinbk.grp`，源与产物均无
- [x] **T2.4** 真删除 0
      ▸ DoD: 无任何基线文件在「源 + 产物」两侧都不存在
- [x] **T2.5** 闭合验算
      ▸ DoD: `13 + 5 + 3 + 0 = 21` ✅
- [x] **T2.6** 声明两集合不同
      ▸ DoD: 文档写明 `save/` 有而 `removed` 无 = `d11 d6 r11 r6 s11 s6`；
        `removed` 有而 `save/` 无 = `d2 d3`

## 组 3 — `added` 184 拆解与溯源（REQ-BKV-3）

- [x] **T3.1** fight / 非 fight 拆解
      ▸ DoD: `172 (86 组×2) + 12 = 184`
- [x] **T3.2** 12 项非 fight 逐项溯源
      ▸ DoD: 11 项在源 `resource/`（+ `kysmod.ini` 在根），`ranger.str` 源中不存在
- [x] **T3.3** `ranger.str` 生成物确认
      ▸ DoD: `find ../reference/allmods/kys-books -name "ranger.str"` 无输出

## 组 4 — `hdgrp` 696 内容有效性（REQ-BKV-4）

- [x] **T4.1** 逐条头解析
      ▸ DoD: `记录=696 PNG=0 RLE=474 零长=222 头异常=0`
- [x] **T4.2** 上限检查
      ▸ DoD: `w 1..82`、`h 1..70`，无异常巨值/零值
- [x] **T4.3** 零长段分块
      ▸ DoD: `(215,54) (270,2) (273,165) (695,1)`，`Σ=222`
- [x] **T4.4** `eft` 同家族对照
      ▸ DoD: `eft 记录=973 RLE=972 零长=1 头异常=0 w 1..230 h 1..200`
      ▸ DoD: 结论「零长是 hdgrp 内容特征，非格式缺陷」
- [x] **T4.5** 基线对照
      ▸ DoD: `基线 115 = PNG 2 + RLE 112 + 零长 1`，`w 13..56 / h 9..58`

## 组 5 — `Wugong` 100（REQ-BKV-5）

- [x] **T5.1** 64 字段全量统计
      ▸ DoD: `全 nil 字段数 = 0`、`名称非空 100/100`
- [x] **T5.2** 实名抽样
      ▸ DoD: 使用 `武功动画&音效`（非 `动画`），6 条边界值正确
- [x] **T5.3** 越界统计
      ▸ DoD: `CC.Effect` 键数 53 / `max键` 52；越界 2 条 / `max=55`
      ▸ DoD: **未**使用 `#CC.Effect`

## 组 6 — fight 四象限（REQ-BKV-6）

- [x] **T6.1** 四象限计数
      ▸ DoD: `A=89 B=3 C=86 D=2`
- [x] **T6.2** 自洽校验
      ▸ DoD: `A+B=92`（基线组数）、`A+B+C=178`（MOD 组数）
      ▸ DoD: `D∩B=0`、`D∩C=2`
- [x] **T6.3** D 象限编号
      ▸ DoD: `fight104`、`fight164`
- [x] **T6.4** 独立验证 B 象限
      ▸ DoD: md5 比对得 fight 同名异容 **6 个文件 = 3 组**（`fight003/037/088`），
        与 `B=3` 精确一致（**不从总数外推**）

## 组 7 — fight 与 pineapple 反向分布（REQ-BKV-7）

- [x] **T7.1** 两 MOD 四象限并表
      ▸ DoD: books `89/3/86/2` vs pineapple `2/90/62/115`
- [x] **T7.2** B 占比
      ▸ DoD: books `3/92 = 3.3%`；pineapple `90/92 = 97.8%`
- [x] **T7.3** 性质结论
      ▸ DoD: books = 保留基线 + 新增增量；pineapple = 几乎全部改写存量
      ▸ DoD: 显式写明「总数接近但性质相反，四象限是唯一可靠方式」

## 组 8 — `FILE_MISSING` 4 实例（REQ-BKV-8）

- [x] **T8.1** 引用面统计
      ▸ DoD: 被引用不同代号 174（min 0 / max 185）
- [x] **T8.2** 缺失实例识别
      ▸ DoD: `30(風清揚) 39(石中玉) 66(段正淳) 110(張召重)`
- [x] **T8.3** 源与基线双侧核验
      ▸ DoD: 4 个均 `src=MISSING base=MISSING`
- [x] **T8.4** 未引用缺席
      ▸ DoD: `fight052/111/112/113`（引用 0 次）
- [x] **T8.5** pineapple 对照
      ▸ DoD: pineapple `FILE_MISSING = 0`

## 组 9 — `ranger.str` 957（REQ-BKV-9）

- [x] **T9.1** 条目统计
      ▸ DoD: 964 行 / 957 有效；分段 `419+368+72+98=957`；字段 `670+119+168=957`
- [x] **T9.2** 唯一值
      ▸ DoD: 唯一 934 / 重复 23
- [x] **T9.3** 回填证明
      ▸ DoD: `ranger.grp @844 = "P0000"` → 运行时 `JY.Person[0]["姓名"] = 古天奇`

## 组 10 — 排名实测（REQ-BKV-10）

- [x] **T10.1** 20 MOD 全量扫描
      ▸ DoD: 脚本遍历 `mods/*/data`，对 `hdgrp/eft/kdef/talk` 取 `idx//4`、
        `fight` 取 glob 计数、`ranger.grp` 取 size、`Person` 取 `(off[1]-off[0])//182`
- [x] **T10.2** 8 项排名逐项确认
      ▸ DoD: `hdgrp 1/20`、`kdef 20/20(最少)`、`talk 3/20`、`eft 4/20`、
        `fight 7/20`、`Person 9/20`、`ranger.grp 9/20`、`零字节 4/20`
- [x] **T10.3** 修正错误断言
      ▸ DoD: `kdef` 从「最少」修正为「**20/20，全 epic 最低**」并附次少值 1018
      ▸ DoD: `ranger.grp` 从「非第 1」细化为「**第 9**」并附前序 8 个值
      ▸ DoD: `Person` 细化为「**第 9**」
- [x] **T10.4** 前序值齐备
      ▸ DoD: 每个排名在文档中附前序 MOD 的具体数值（不只写名次）

## 组 11 — 文档

- [x] **T11.1** `proposal.md`（REQ-BKV-1~10 + In/Out of Scope）▸ DoD: 存在且含 10 个 REQ
- [x] **T11.2** `design.md`（ADR-BKV-001~005 + 19 Negative Constraints + Review Checklist）▸ DoD: 10 项全 `[x]`
- [x] **T11.3** `specs/allmods-books-verification/spec.md` ▸ DoD: 10 个 REQ 各至少 1 Given/When/Then
- [x] **T11.4** `tasks.md`（本文件）▸ DoD: 0 未勾选
- [x] **T11.5** `verification.md` ▸ DoD: 每条 REQ 附实测命令 + 输出 + 结论
- [x] **T11.6** `reports/books-verify.md` ▸ DoD: 7 个独特性章节 + 缺陷清单 + 机器可核验
