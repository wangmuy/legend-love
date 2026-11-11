# Spec: allmods-lostbook-verification

> Change: `allmods-lostbook-verify` · Slice: `allmods-slice4` · Epic: `2026-10-allmods-compat`
> 对应需求：REQ-LOSTV-1 ~ REQ-LOSTV-6

## REQ-LOSTV-1: `diff.md` 逐条审计

**Given** `game/mods/lostbook/diff.md` 已生成
**When** 逐条审计其差异
**Then** 24 项「MOD 独有」全部有判定，需修复项 = 0

**And** 24 项含 5 场额外战斗：
- `fight039.grp`/`.idx`、`fight040.grp`/`.idx`、`fight041.grp`/`.idx`、
  `fight042.grp`/`.idx`、`fight052.grp`/`.idx`

## REQ-LOSTV-2: 「基准独有」项性质确认

**Given** `diff.md` 列出 21 项「基准独有」
**When** 逐项用文件系统事实与运行时 `CC.*` 值定性
**Then** 每项归入以下三类之一，且**无未解释项**：

| 性质 | 项数 |
|------|-----:|
| 回退原版 | 18 |
| 在 save/ | 2 |
| 死文件 | 1 |
| **Σ** | **21** |

**And** `r1.grp` 归为「在 save/（首次存档播种）」（见 REQ-LOSTV-4）。

## REQ-LOSTV-3: MOD 独有内容确实被加载

**Given** 启动链路初始化完成
**When** 检查运行时内容
**Then** 用**非基线值**证明加载来自 MOD：

| 判据 | lostbook | pascal | 区分度 |
|------|----------|--------|--------|
| 主角姓名 | 金迷 | 小蝦米 | ✅ |
| `JY.Person[1]["姓名"]` | 胡斐 | （不同） | ✅ |
| `JY.Person[2]["姓名"]` | 程靈素 | （不同） | ✅ |
| 对话条目数 | 3181 | 2977 | ✅ |
| 事件脚本数 | 1071 | 1018 | ✅ |

**And** 资源路径全部指向 `mods/lostbook/`。

## REQ-LOSTV-4: 内容差异 vs 结构异常判定

**Given** lostbook 的 kdef 1071（vs 1018）、fight 97（vs 92）
**When** 判定差异性质
**Then** 判定为**内容差异**，判据为：

| 条件 | 实测 |
|------|------|
| 记录布局常量与 pascal 相同 | `CC.PersonSize=182`/`ThingSize=190`/`SceneSize=52`/`WugongSize=136` ✅ |
| 字节全覆盖（`gaps=0`） | `formats=12 checked=201 gaps=0` ✅ |
| 记录数与 pascal 相同 | 320/200/84/93 ✅ |

**And** 若为结构异常，`format_spec` 会报 `gaps > 0`（按 pascal 尺寸解析会错位）。

## REQ-LOSTV-5: 零引擎改动

**Given** 本 change 的改动清单
**When** 检查改动路径
**Then** 以下路径**未被触碰**：
- `game/engine-love2d/**`
- `game/engine-mud/**`
- `game/script/jyconst.lua` 常量定义
- `reference/allmods/**`

## REQ-LOSTV-6: 验证报告

**Given** 审计完成
**When** 检查 `reports/lostbook-verify.md`
**Then** 报告包含：
- 结论摘要表
- `diff.md` 逐条审计表（24 + 21）
- 内容差异 vs 结构异常的判定
- MOD 独有内容的非基线值证据
- 零回归实测输出
- 结论
