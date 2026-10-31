# Tasks — allmods-data-fallback

## Blast Radius

允许修改/新增的文件路径：

- `game/framework/mod_data.lua`（新增，Contract B 主体）
- `game/framework/script_loader.lua`（脚本回退链接入）
- `game/framework/jymain_adapter.lua`（启动链路 ini 接入）
- `game/script/jyconst.lua`（`SetGlobalConst` 末尾接入 `RewriteConstants`）
- `game/script/jymain.lua`（`WarLoad` 边界校验）
- `game/tests/unit/test_mod_data.lua`（新增）
- `game/tests/test_runner.lua`（注册测试）
- `openspec/changes/allmods-data-fallback/**`

**不允许**修改：`game/engine-love2d/**`（引擎实现）、`game/engine-mud/**`、
`game/tools/**`（构建管线属于 allmods-build-pipeline）。

## 任务

### T1 MOD 激活机制（REQ-DATA-1）

- [x] T1.1 `game/active_mod.txt`：一行 slug，缺失/空 = 未激活
- [x] T1.2 `ModData.Active()` / `ModData.SetActive(slug)`（归一化：去空白、去 `kys-` 前缀）

### T2 数据路径回退（REQ-DATA-1）

- [x] T2.1 `ModData.Resolve(filename)`：`mods/<mod>/data/` 存在 → 用它；否则 `data/`
- [x] T2.2 `ModData.exists` / `ModData.listDir` IO 适配（可测试替换）
- [x] T2.3 `ModData.RewriteConstants(CC, CONFIG)`：重定向 `CC.*` 路径常量（含表值、`FightPicFile` 格式串）
- [x] T2.4 `SetGlobalConst()` 末尾接入（未激活为空操作）

### T3 脚本回退链（REQ-DATA-2）

- [x] T3.1 `ModData.ScriptFile(relpath)`：`mods/<mod>/script/` 存在 → 用它；否则 `script/`
- [x] T3.2 `ScriptLoader.load` 接入回退链（覆盖 `jymain.lua` / `event_executor.lua` 两个调用点）

### T4 fight 动态枚举（REQ-DATA-3）

- [x] T4.1 `ModData.FightFiles()`：MOD 有 fight 则枚举 MOD 的，否则回退 `data/`
- [x] T4.2 构建管线把 `fight/` 内容拍平到 `mods/<mod>/data/` 顶层；`save/` 拆分：基础模板→`data/`、用户存档→`mods/<mod>/save/`
- [x] T4.3 `ModData.WarRecordCount(warFile, recordSize)` + `WarLoad` 边界校验（R3）

### T5 ini 覆盖接入（REQ-DATA-4）

- [x] T5.1 `ModData.LoadIni()`：激活时解析 `mods/<mod>/data/kysmod.ini` 并 `ModIni.Apply`
- [x] T5.2 `JYMainAdapter.initCoroutine` 在 `SetGlobalConst()` 后接入

### T6 零回归 + 测试（REQ-DATA-4）

- [x] T6.1 `test_mod_data.lua`（31 测试）：回退链、枚举、常量重定向、slug 归一化、war 记录数
- [x] T6.2 注册到 `test_runner.lua`
- [x] T6.3 无 `active_mod.txt` → 全绿（141/141）

### T7 存档目录隔离（REQ-DATA-5）

- [x] T7.1 `ModData.SAVE_DIR` + `ModData.SaveDir()`：未激活→`save/`，激活→`mods/<slug>/save/`
- [x] T7.2 `ModData.EnsureSaveDir()` / `readFileRaw` / `writeFileRaw` 辅助
- [x] T7.3 `RewriteConstants` 扩展：存档槽常量索引 1..3 重定向到 MOD 存档目录（索引 0 仍走 data/ 回退链）
- [x] T7.4 `ModData.SeedSaveSlot(id)`：首次保存时从 `ranger.idx` 模板播种 `rN.idx`（优先 MOD ranger.idx，非原版 rN.idx）
- [x] T7.5 `jymain.lua` `SaveRecord(id)` 接入播种（id>0 且目标 idx 缺失时）
- [x] T7.6 构建管线 `save/` 拆分（模板 vs 用户存档）
- [x] T7.7 `test_mod_data.lua` +8 测试（SaveDir/RewriteSaveSlots/SeedSaveSlot）
- [x] T7.8 `test_mod_boot.lua` 新增存档隔离 + 自动播种断言

## DoD（机器可验证）

1. 无 `active_mod.txt` → `cd game && lua tests/test_runner.lua` 全绿。
2. 激活 mingdong：`ModData.Resolve` 命中 `mods/mingdong/data/` 的文件从 MOD 目录读、
   仅原版有的（`smap.grp`/`wmap.grp`/`thing.grp`）从 `data/` 读。
3. `ModData.FightFiles()` 返回 267（= `mods/mingdong/data/fight*.grp` 实际数），非原版 92。
4. 激活 mingdong 后 `CONFIG`/`CC` 含 ini 覆盖值：`CONFIG.Width=960`、`CONFIG.Height=660`、
   `CC.ScreenW=960`、`CC.ScreenH=660`、`CC.MyThingNum=330`、`CC.MaxHP=9999`。
5. 存档隔离：激活 mingdong 后存档槽指向 `mods/mingdong/save/`；`SaveRecord(1)` 自动播种
   `r1.idx` 并写入 `r1.grp/s1.grp/d1.grp`；`r1.idx` 与 `mods/mingdong/data/ranger.idx` 逐字节一致；
   不同 MOD 的 `SaveDir()` 互不相同；未激活时 `SaveDir()="save/"`（零回归）。

### 验证记录

- DoD 1：`lua tests/test_runner.lua` → `总测试数: 252 / 通过: 252 / 失败: 0`
- DoD 2：`data/mmap.grp → mods/mingdong/data/mmap.grp`；`data/smap.grp → data/smap.grp`
- DoD 3：`FightFiles count = 267 first = fight000.grp last = fight321.grp`
- DoD 4：`CONFIG.Width=960 Height=660 CC.ScreenW=960 CC.ScreenH=660 CC.MyThingNum=330 CC.MaxHP=9999`
- DoD 5：`SaveDir()=mods/mingdong/save/`；`SaveRecord(1)` 后 `r1.idx` 自动播种且与 MOD `ranger.idx` 逐字节一致；
  `mod_data` 50/50、`mod_boot` 55/55；`--verify-pascal` PASS；`--all` 20 mods 0 failures
