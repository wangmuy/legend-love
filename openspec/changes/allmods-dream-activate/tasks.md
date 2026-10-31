---
status: done
created: 2026-10-26
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice14
---
# Tasks: allmods-dream-activate

## Blast Radius

| 路径 | 允许 | 说明 |
|------|:----:|------|
| `game/mods/dream/**` | ✅ 写 | 构建产物 |
| `openspec/changes/allmods-dream-activate/**` | ✅ 写 | 本 change |
| `openspec/changes/allmods-slice14/**` | ✅ 写 | manifest |
| `openspec/epics/2026-10-allmods-compat/**` | ✅ 写 | 索引 |
| `reference/allmods/kys-dream/**` | ⚠ 只读 | 构建输入 |
| `game/tools/**` | ❌ 不改 | 未发现工具缺陷 |
| `game/engine-love2d/**` | ❌ 禁 | 四禁改 |
| `game/engine-mud/**` | ❌ 禁 | 四禁改 |
| `game/script/jyconst.lua` 常量 | ❌ 禁 | 四禁改 |

---

## 组 1 — 构建（REQ-DRM-1）

- [x] **T1.1** 执行构建
      ▸ DoD: `lua tools/mod_build.lua kys-dream` → `data files=280, saves=27, sound=77, events=4569, talk=6464`
- [x] **T1.2** 产物目录清点
      ▸ DoD: `ls game/mods/dream/data | wc -l` = **281**
- [x] **T1.3** 声明 280/281 口径差
      ▸ DoD: 文档写明差 1 是 `ranger.str`（生成物，不计入 builder 计数），**非矛盾**

## 组 2 — 穷举审计（REQ-DRM-2）

- [x] **T2.1** 执行审计（**必须** `--mod dream`）
      ▸ DoD: `total=416 in_product=383 not_in_product=33 unclassified=0 bad_evidence=0`
- [x] **T2.2** 类别闭合
      ▸ DoD: `REQUIRED 378 / REQUIRED_CONVERTED 4 / LEGACY 3 / DEAD_FILE 1 / BUILD_INPUT 1 / PENDING 29`
      ▸ DoD: `378+4+3+1+1+29 = 416` ✅
- [x] **T2.3** 证据检查
      ▸ DoD: `evidence: checked=9 failed=0`

## 组 3 — 字节级覆盖（REQ-DRM-3）

- [x] **T3.1** 执行格式检查
      ▸ DoD: `formats=12 checked=225 gaps=0`

## 组 4 — 记录段判据（REQ-DRM-4）

- [x] **T4.1** offsets 与末 offset
      ▸ DoD: `[836,75274,111754,118098,131970,132270]`，末 offset == grp `132270`，tail 0
- [x] **T4.2** 五段整除
      ▸ DoD: `74438/182=409`、`36480/190=192`、`6344/52=122`、`13872/136=102`、`300/50=6`，余数全 0
- [x] **T4.3** CC 尺寸标准值
      ▸ DoD: 运行时 `182/190/52/136/50`，与基线一致 ⇒ 排除自定义布局
- [x] **T4.4** 源 `ranger.idx` 完好证明
      ▸ DoD: `md5(mods/dream/data/ranger.idx) == md5(src/save/ranger.idx)`
- [x] **T4.5** `RepairIdx` 未触发证明
      ▸ DoD: 构建日志无 `RepairIdx`；`encoding-report.md` 无 `idxRepaired`
      ▸ DoD: manifest 勘误已写入（dream **不是** RepairIdx 案例）

## 组 5 — 启动链路（REQ-DRM-5）

- [x] **T5.1** `rm -f active_mod.txt` 后跑真实启动
      ▸ DoD: `lua tests/unit/boot_one_mod.lua dream 409 192 122 102 隨小破` → `RESULT dream: OK`
- [x] **T5.2** 16 断言全 PASS
      ▸ DoD: 输出 16 行 `[PASS]`，0 行 `[FAIL]`
- [x] **T5.3** 5 个位置参数为**规格期望值**
      ▸ DoD: 传入 `409 192 122 102 隨小破`（不是运行时实测值），防 `x==x` 假通过
- [x] **T5.4** 关键断言值
      ▸ DoD: `CC.PersonSize=182` / `ThingSize=190` / `SceneSize=52` / `WugongSize=136`
      ▸ DoD: 扫描字段 `1618`、U+FFFD `0`、控制符 `0`、10 帧无报错

## 组 6 — 编码转换（REQ-DRM-6）

- [x] **T6.1** 读取 `encoding-report.md`
      ▸ DoD: `转换 1618 / 去重 855 / 旁路 763 / 截断 0 / 溢出 0`
- [x] **T6.2** `ranger.str` 条目核对
      ▸ DoD: 770 行 / 763 有效 / 7 注释；分段 `243+343+82+95=763`；字段 `513+82+168=763`
- [x] **T6.3** 格式确认
      ▸ DoD: 逗号分隔 `id,段,索引,字段,值`（**不是** tab）

## 组 7 — `hdgrp` 484（REQ-DRM-7）

- [x] **T7.1** offsets 与段数
      ▸ DoD: `484 offsets` / `483 段`；`offs[0]=2895`；`tail=0`
- [x] **T7.2** 段分类
      ▸ DoD: `411 RLE + 72 零长 = 483`，头异常 **0**
- [x] **T7.3** 上限与零长块
      ▸ DoD: `w 1..58` / `h 1..71`；零长块 `(381,69) (480,3)`，`Σ=72`
- [x] **T7.4** 基线对照
      ▸ DoD: `基线 115 offsets / 114 段 = PNG 2 + RLE 112 + 零长 0`，`w 13..56`

## 组 8 — `eft` 零改动（REQ-DRM-8）

- [x] **T8.1** md5 比对
      ▸ DoD: `md5(eft.idx)` 相同 True；`md5(eft.grp)` 相同 True（2856B / 691627B）
- [x] **T8.2** 排除回退
      ▸ DoD: `eft.*` **不在** `diff.md` 的 `added`/`removed`
- [x] **T8.3** 正样本声明
      ▸ DoD: 文档写明 dream 是 `eft` 零改动正样本（对照 books 973 / pineapple 1378 改动）

## 组 9 — 8 道门禁（REQ-DRM-9）

- [x] **T9.1** 门禁 1 ▸ DoD: `通过: 1842 / 失败: 0`
- [x] **T9.2** 门禁 2 ▸ DoD: `pascal baseline: PASS`，`known-deviations=3`
- [x] **T9.3** 门禁 3 ▸ DoD: `all: 20 mods, 0 build failures`（退出码 1 属设计）
- [x] **T9.4** 门禁 4 ▸ DoD: `总计: 20 MOD, 通过 20, 失败 0`
- [x] **T9.5** 门禁 5 ▸ DoD: `total=11220 in_product=9245 not_in_product=1975 unclassified=0 bad_evidence=0`，`checked=17 failed=0`
- [x] **T9.6** 门禁 6 ▸ DoD: `formats=12 checked=6773 gaps=0`
- [x] **T9.7** 门禁 7 ▸ DoD: 与 Slice 12/13 同口径复跑，真实问题 0
- [x] **T9.8** 门禁 8 ▸ DoD: 四禁改路径无改动；`jyconst.lua +11/−1` 属 allmods-data-fallback 接线

## 组 10 — 文档

- [x] **T10.1** `proposal.md` ▸ DoD: REQ-DRM-1~9 + In/Out Scope + Blast Radius
- [x] **T10.2** `design.md` ▸ DoD: ADR-DRM-001~005 + 15 Negative Constraints + Checklist 11 项全 `[x]`
- [x] **T10.3** `specs/allmods-dream-activation/spec.md` ▸ DoD: 9 个 REQ 各至少 1 Given/When/Then
- [x] **T10.4** `tasks.md`（本文件）▸ DoD: 0 未勾选
- [x] **T10.5** `verification.md` ▸ DoD: 每条 REQ 附实测命令 + 输出 + 结论
