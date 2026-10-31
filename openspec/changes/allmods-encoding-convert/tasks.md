---
status: done
created: 2026-10-17
---

# tasks — allmods-encoding-convert

## 组 1：转换器（`game/tools/mod_encoding.lua`）

**Blast Radius**：`game/tools/mod_encoding.lua`、`game/tools/mod_big5_trad.lua`

- [x] 1.1 逆向 UPedit.ini `[R_Modify]` 得出权威 MOD 布局（Person 182 / Thing 190 / Scene 52 / Wugong 136 / Shop 50）
- [x] 1.2 生成繁体保留 Big5 表 `mod_big5_trad.lua`（13710 条，不转简）
- [x] 1.3 实现 `M.LAYOUT`（字段 off/len/hint 前缀）
- [x] 1.4 实现 `M.Hint(prefix, index)` = `prefix .. string.format("%04d", index)`
- [x] 1.5 实现 `M.ConvertRanger(grp, offs)` → newGrp（同尺寸）+ sideTable + report
- [x] 1.6 实现 `M.SerializeSideTable` / `M.ParseSideTable`（按段分组，含 index 列，去重）
- [x] 1.7 溢出检测：段内 index > 9999 → 记入 `report.overflows`

**DoD**：
- `#newGrp == #grp`（全 20 MOD）
- `#report.overflows == 0`（全 20 MOD）
- 无截断计数（`report.truncated == 0`）

## 组 2：构建流水线接入（`game/tools/mod_build.lua`）

**Blast Radius**：`game/tools/mod_build.lua`

- [x] 2.1 `convertRangerFile(grpData, modDir)`：读 `save/ranger.idx`，调用转换器，校验尺寸/溢出
- [x] 2.2 `flattenResources` 在写 `ranger.grp` 前转换，返回 `encReport`
- [x] 2.3 `BUILD.Build` 写 `data/ranger.str` + `encoding-report.md`
- [x] 2.4 生成人类可读报告（统计表 + 分段明细 + hint 格式表）

**DoD**：
- `lua tools/mod_build.lua kys-mingdong` → rc=0，产出 `data/ranger.str` 与 `encoding-report.md`
- `lua tools/mod_build.lua --all` → 20 mods, 0 failures
- `lua tools/mod_build.lua --verify-pascal` → PASS（结构零差异）

## 组 3：运行时布局适配（`game/framework/mod_data.lua` + `game/script/jyconst.lua`）

**Blast Radius**：`game/framework/mod_data.lua`、`game/script/jyconst.lua`

- [x] 3.1 `ModData.MOD_SIZES`（182/190/52/136/50）
- [x] 3.2 `ModData.MOD_STRINGS`（MOD 字符串字段 off/len）
- [x] 3.3 `ModData.MOD_SHIFT` / `MOD_STR_END`：数值字段 = 原版偏移 − 累计字符串缩小量
- [x] 3.4 `ModData.BuildModStruct(seg, vanillaStruct)` 生成 MOD 偏移表
- [x] 3.5 `ModData.ApplyLayout(CC)` 覆盖 size + 4 张 `*_S` 表
- [x] 3.6 `jyconst.lua` 在 `RewriteConstants` 后调用 `ApplyLayout`

**DoD**：
- 生成的 Person 偏移与 UPedit 权威值逐项一致（性别 28 / 体力 42 / 武器 46 / 携带物品4数量 180）
- `LoadRecord(0)` 在 mingdong 下得 632/367/139/220

## 组 4：运行时字符串链（`game/framework/mod_data.lua` + `game/script/jymain.lua`）

**Blast Radius**：`game/framework/mod_data.lua`、`game/script/jymain.lua`

- [x] 4.1 `ModData.SideTable()` / `ClearSideCache()` 加载并缓存旁路表
- [x] 4.2 `ModData.ParseHint(s)` → (seg, index, field)
- [x] 4.3 `ModData.ResolveString(v)`：hint → 旁路值，否则原样
- [x] 4.4 `ModData.SaveOverrides(id)` / `WriteSaveOverrides(id, ovr)`（`rN.ovr`）
- [x] 4.5 `jymain.lua` 在 `LoadRecord` 前定义 `modDataForStrings`/`resolveModString`/`writeModString`
- [x] 4.6 `GetDataFromStruct` 字符串分支接 `resolveModString`（`rN.ovr` → `ranger.str` → 缓冲）
- [x] 4.7 `SetDataFromStruct` 字符串分支接 `writeModString`（写覆盖表）
- [x] 4.8 `LoadRecord` 加载 `rN.ovr`；`SaveRecord` 写回 `rN.ovr`

**DoD**：
- `JY.Person[1]["姓名"] == "胡斐"`、`["外号"] == "雪山飛狐"`（保留繁体）
- `JY.Scene[0]["名称"] == "胡斐居"`
- 改名 → `SaveRecord(1)` → `r1.ovr` 含 `P0000=令狐冲` → 重读得 `令狐冲`
- 未改动字段仍从旁路表解析

## 组 5：验证与零回归

**Blast Radius**：`game/tests/unit/test_mod_boot.lua`

- [x] 5.1 更新 `test_mod_boot` 记录数断言（569/268/116/204 → 632/367/139/220）
- [x] 5.2 新增旁路表解析断言（姓名/外号/场景名）
- [x] 5.3 新增覆盖表 round-trip 断言（改名 → `r1.ovr` → 重读）
- [x] 5.4 全量测试（无 `active_mod.txt`）通过
- [x] 5.5 全量测试连跑 3 次幂等
- [x] 5.6 `--verify-pascal` PASS
- [x] 5.7 独立校验脚本：全 MOD 尺寸不变 + 零残留 Big5

**DoD**：
- `lua tests/test_runner.lua` → 262/262（连跑 3 次一致）
- `lua tools/mod_build.lua --verify-pascal` → PASS
- `lua tools/mod_build.lua --all` → 20 mods, 0 failures

## 组 6：文档

**Blast Radius**：`DATA_FILES.md`、`openspec/changes/allmods-slice1/slice-proposal.md`

- [x] 6.1 `DATA_FILES.md` 新增「MOD 数据格式（allmods / kys-*）」章节
- [x] 6.2 修正 slice1 proposal 中过期的记录数（569 → 632 等）
- [x] 6.3 报告集（`reports/`）：逆向 / 方案对比 / hint 占位 / 方案 D 定稿
