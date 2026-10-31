# Tasks: allmods-spike-thingpic-audit

> 只读审计 change。所有任务已完成，证据见 `reports/thingpic-audit.md`。

## Blast Radius

- `openspec/changes/allmods-spike-thingpic-audit/**`（只读审计，不改运行代码）

## Tasks

### T1: 追踪 `LoadThingPic=0` 物品图渲染链路
- [x] 定位 `CC.LoadThingPic` / `CC.StartThingPic` 定义（`script/jyconst.lua:624-625`）
- [x] 定位取图分支（`script/jymain.lua:1259-1263`、`framework/item_async.lua:310-314`）
- [x] 定位贴图缓存机制（`engine-love2d/lib_love.lua:423-452, 483-520`）
- [x] 确认 slot 约定（0=mmap/smap/wmap、1=hdgrp、2=thing、3=eft、4=fightNNN）
- **DoD**: 链路完整，`LoadThingPic=0` 不读独立 thing.grp/idx，结论已写入报告 §2

### T2: 枚举数据加载侧硬编码假设
- [x] 路径常量清单（`script/jyconst.lua:83-134`，22 处 `CONFIG.DataPath` 引用）
- [x] 直接文件加载点清单（`jymain.lua` / `war_async.lua` / `jymain_adapter.lua` / `event_executor.lua`）
- [x] 条目数假设：hdgrp/thing/mmap/smap 均为动态（`PicLoadFile` 按 idx 长度建表）
- [x] fight 文件编号：动态拼接但无枚举（`jyconst.lua:119` + `jymain.lua:4383`）
- [x] war.sta 记录数：无索引，靠 `warid*186` 定位（`jyconst.lua:492`、`jymain.lua:4344`）
- [x] 脚本加载链（`config.lua:44-46`、`script_loader.lua:7-20`）
- **DoD**: 每个假设均有 `file:line` 证据，写入报告 §3

### T3: 定界 data-fallback 改造清单
- [x] 必须收敛到 `ModData.Resolve` 的加载点（报告 §4.1）
- [x] 必须改为动态枚举的点（报告 §4.2）
- [x] 无需改动（已动态）的点（报告 §4.3）
- [x] MOD 实际提供的文件集 + 拍平规则注意（报告 §4.3.1 / §4.3.2）
- **DoD**: `allmods-data-fallback` 可直接按清单实施，写入报告 §4/§6

### T4: 风险项核对（ptt/GodsDevils grp 条目完整性）
- [x] hdgrp 条目数二进制核对（pascal 114 / mingdong 114 / GodsDevils 128 / ptt 203 / Dragon 266）
- [x] `hdgrp.idx` 与 `hdgrp.grp` 成对、末 offset = grp 大小 → 无截断
- [x] 原版 fight 文件编号不连续（92 个，0..109 有缺口）；mingdong 267 个（0..321 有缺口）
- **DoD**: 风险项结论写入报告 §5

## DoD 汇总（change 级）

1. [x] `reports/thingpic-audit.md` 产出，含加载点清单（文件 + 函数级）
2. [x] 报告中每个硬编码假设都有源码 `file:line` 证据
3. [x] allmods-data-fallback 可直接按报告清单实施，无需二次探索（§6 给出输入契约）
