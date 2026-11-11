# Tasks — allmods-zheng-fix

## Blast Radius

允许修改/新增的文件路径：

- `game/tools/mod_encoding.lua`
- `game/tools/mod_build.lua`
- `openspec/changes/allmods-slice-zheng/**`

**不允许**修改：`game/engine-love2d/**`、`game/engine-mud/**`、`reference/allmods/**`（只读源数据）。

## 任务

- [x] T2.1 `IdxIsConsistent`：递增 + 段对齐 + 不越界（容忍尾部 padding）
- [x] T2.2 `DetectLayout`：按 Big5 串位置枚举候选起点，测最长 run，链式单调布局
- [x] T2.3 `RepairIdx`：一致则原样返回
- [x] T2.4 `convertRangerFile` 调用 `RepairIdx`，拷贝循环后写出修复 idx
- [x] T2.5 重建全 20 MOD，确认 0 失败

## 修改报告

详见 [`reports/fix.md`](reports/fix.md)。

## Definition of Done

- [x] `mods/zheng/data/ranger.idx` = `836,59076,97076,101444,114092,114242`
- [x] 完好 MOD 的 idx 未被改动
