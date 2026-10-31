---
status: done
created: 2026-10-18
---

# 魏征传奇 (zheng) — 确认修改

## 逆向结论（根因）

`save/ranger.idx` 描述的偏移超出 `ranger.grp` 文件大小（idx 末值 138596 vs grp 114242 字节），导致引擎按错误段边界解码。

## 关键洞察

zheng 的 `ranger.grp` **本身是 100% 标准 UPedit 布局**，从未结构损坏；此前「复合布局」的判断是损坏 idx 造成的红鲱鱼。

## 修改清单

1. `game/tools/mod_encoding.lua` 新增 `M.SEG_REC = {182,190,52,136,50}`（标准记录大小）
2. 新增 `M.IdxIsConsistent(idxOffsets, grpSize)`：`idx[6] <= grpSize` 且各段长度整除记录大小（容忍尾部 padding，故 pineapple 出厂 idx 保留）
3. 新增 `M.RepairIdx(grp, idxOffsets)`：从文件大小与标准记录大小反推一致 idx
4. 新增 `M.DetectLayout(grp)`：返回 `newIdx, det, err, padding`
5. `game/tools/mod_build.lua` 的 `convertRangerFile` 调用 `RepairIdx`，产物 `data/ranger.idx` 写入修复后值；`report.idxRepaired` 记录

## 验证证据

- zheng 产物 idx = `836,59076,97076,101444,114092,114242`（精确等于 grp 大小）
- `mod_check.lua` zheng 由损坏的 358/201/94/216 → 320/200/84/93
- `testRepairIdxLeavesGoodIdxUntouched`：pascal reason=nil（正确打包的 MOD 永不触碰）


## 修复前后量化对比（决定性证据）

| 指标 | 修复前（出厂 idx） | 修复后（RepairIdx） |
|------|---------------------|----------------------|
| 出厂 idx | `836,65992,104182,109070,138446,138596` | — |
| 修复后 idx | — | `836,59076,97076,101444,114092,114242` |
| grp 文件大小 | 114242 | 114242（不变） |
| 旁路表 U+FFFD | **11** | **0** |
| 旁路表控制符 | **3** | **0** |
| Person/Thing/Scene/Wugong | 358/201/94/216（错位） | **320/200/84/93**（正确） |

> `idx[6]=138596 > grp=114242`，引擎按错误段边界解码 → 错位 + 乱码。
> `RepairIdx` 从文件大小与标准记录大小（182/190/52/136）反推一致 idx。

## 约束遵守

- **数据驱动**：无任何可执行代码按 MOD 名分支（仅有注释说明）。
- **文件大小不变**：20/20 MOD 源尺寸 vs 产物尺寸一致。
- **构建幂等**：连续两次 `mod_build.lua --all` 产物 md5 相同。
