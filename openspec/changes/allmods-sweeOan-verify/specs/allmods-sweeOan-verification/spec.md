# Spec: allmods-sweeOan-verification

> Change: `allmods-sweeOan-verify` · Slice: `allmods-slice2` · Epic: `2026-10-allmods-compat`
> 对应需求：REQ-SWEEV-1 ~ REQ-SWEEV-6

## REQ-SWEEV-1: `diff.md` 逐条审计

**Given** `game/mods/SweeOan/diff.md` 已生成
**When** 逐条审计其差异
**Then** 14 项「MOD 独有」全部有判定（预期 / 需修复 / 死文件）

**And** 判定结果：
- 12 项为预期资源（进产物）
- 1 项 `kysmod.ini` 为 `BUILD_INPUT`（不进产物）
- 1 项 `修改档说明.txt` 为死文件

**And** 需修复项 = 0。

## REQ-SWEEV-2: 「基准独有」项性质确认

**Given** `diff.md` 列出 23 项「基准独有」
**When** 逐项用文件系统事实与运行时 `CC.*` 值定性
**Then** 每项归入以下三类之一，且**无未解释项**：

| 性质 | 项数 | 判据 |
|------|-----:|------|
| 回退原版 | 16 | `CC.*` 指向 `data/` |
| 在 save/ | 4 | `CC.*_Filename[1]` 指向 `mods/SweeOan/save/` |
| 死文件 | 3 | 引擎无引用（`allsinbk.grp` 形参 0 引用） |

**And** 不得笼统表述为「均回退原版」。

## REQ-SWEEV-3: MOD 独有内容确实被加载

**Given** 启动链路初始化完成
**When** 检查运行时内容
**Then** 用**非基线值**证明加载来自 MOD：

| 判据 | SweeOan | pascal | 区分度 |
|------|---------|--------|--------|
| 主角姓名 | 王小石 | 小蝦米 | ✅ |
| `JY.Person[1]["姓名"]` | 衛悲回 | （不同） | ✅ |
| `JY.Person[2]["姓名"]` | 伊小深 | （不同） | ✅ |

**And** 资源路径全部指向 `mods/SweeOan/`：
- `CC.MMAPPicFile[1]` = `mods/SweeOan/data/mmap.idx`
- `CC.TalkGrpFile` = `mods/SweeOan/script/oldtalk.grp`
- `CC.WarFile` = `mods/SweeOan/data/war.sta`

**And** 不得用「记录数相同」作为证据（无区分度）。

## REQ-SWEEV-4: 零引擎改动

**Given** 本 slice 的改动清单
**When** 检查改动路径
**Then** 以下路径**未被触碰**：
- `game/engine-love2d/**`
- `game/engine-mud/**`
- `game/script/jyconst.lua` 常量定义
- `reference/allmods/**`

## REQ-SWEEV-5: 验证报告

**Given** 审计完成
**When** 检查 `reports/sweeOan-verify.md`
**Then** 报告包含：
- 结论摘要表
- `diff.md` 逐条审计表（14 + 23 项）
- MOD 独有内容的非基线值证据
- 穷举审计输出
- 零回归实测输出
- 结论

## REQ-SWEEV-6: 发现的问题已修复并回归

**Given** 审计发现 `mod_check_one.lua` 会删除产物 `r1.grp`
**When** 修复并验证
**Then**：
- 工具在自检前备份、自检后字节级恢复
- `mod_check_one` 运行前后产物 `save/` 字节不变
- 新增回归测试 `testCheckOneDoesNotDeleteProductSaves`
- 新增回归测试 `testProductSaveSlotMatchesSource`（全部 MOD 的 `r1.grp` 与源逐字节相同）

**And** 修复前证据：
- mingdong 产物 `r1.grp` = 223688 B（源 222888 B）
- 残留 `r1.idx` / `r1.ovr`

**And** 修复后证据：
- mingdong 产物 `r1.grp` = 222888 B（与源一致）
- 无残留
