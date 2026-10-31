# Tasks — allmods-mingdong-activate

## Blast Radius

允许修改/新增的文件路径：

- `game/active_mod.txt`（新增激活入口；**不提交**，`.gitignore` 已忽略）
- `game/tests/unit/test_mod_e2e.lua`（新增，Contract D 主体）
- `game/tests/test_runner.lua`（注册 `mod_e2e` 模块）
- `game/tools/mod_build.lua`（talk 产物扩展：`oldtalk.grp`/`oldtalk.idx`）
- `game/tools/talk_big5.lua`（Big5 → **简体** UTF-8 表）
- `game/framework/jymain_adapter.lua`（启动链路 ini 接入核对）
- `game/framework/mod_data.lua`（如需修复）
- `game/script/jymain.lua`（`WarLoad` 边界校验核对）
- `.gitignore`（忽略 `game/mods/`、`game/active_mod.txt`）
- `openspec/changes/allmods-mingdong-activate/**`

**不允许**修改：`game/engine-love2d/**`、`game/engine-mud/**`、`game/script/oldevent/**`（原版产物）。

## 任务

### T1 激活入口与启动链路接线（REQ-MD-1）

- [x] T1.1 `game/active_mod.txt` 机制：一行 slug；`.gitignore` 忽略（运行时状态）
- [x] T1.2 核对启动链路顺序：`SetGlobalConst()`（内部 `RewriteConstants`）→ `ModIni.Apply`
- [x] T1.3 真实链路无头验证：`dofile("script/jyconst.lua")` + `SetGlobalConst()` + `ModData.LoadIni()` 后
      `CC.MMAPPicFile`→MOD、`CC.SMAPPicFile`→回退、`CONFIG.Width=960`、`CC.MyThingNum=330`

### T2 事件脚本回退链（REQ-MD-2）

- [x] T2.1 `ScriptLoader.load("script/oldevent/oldevent_0.lua")` 命中 `mods/mingdong/script/oldevent/`
- [x] T2.2 实际 `loadfile` 成功（无头 EngineAPI）

### T3 对话表加载（REQ-MD-3）

- [x] T3.1 `ModData.ScriptFile("script/old_talk.lua")` → `mods/mingdong/script/old_talk.lua`
- [x] T3.2 `dofile` 后 `oldtalk[1]` 为 mingdong 首条对话（简体）
- [x] T3.3 运行时对话路径：`CC.TalkGrpFile`/`TalkIdxFile` → MOD；`oldtalk.grp` + `oldtalk.idx`
      （5183 条）可被 `ReadTalk` 语义读取
- [x] T3.4 `mod_build.lua` 增加 `oldtalk.grp`（UTF-8 文本 + CRLF）+ `oldtalk.idx`（4 字节小端偏移）产物
- [x] T3.5 `talk_big5.lua` 改为 Big5 → **简体** UTF-8（OpenCC `t2s`），匹配运行时语言
- [x] T3.6 talk 终止符处理修复：`0x00` 约定优先，无尾 `0x00` 时用 `0xff` 约定并去 1 个杂散尾字节
- [x] T3.7 **idx 语义修复**：`idx[k]` 改为「读完第 k 行后的字节偏移」（与运行时 `GenTalkIdx` 一致），
      修复原先「行起始偏移」导致的 `ReadTalk` off-by-one；验证 idx 与独立模拟 `GenTalkIdx` 逐字节相同

### T4 战斗数据动态枚举（REQ-MD-4）

- [x] T4.1 `ModData.FightFiles()` = 267（mingdong），编号不连续仍正确
- [x] T4.2 `WarRecordCount(mods/mingdong/data/war.sta, 186)` = 309
- [x] T4.3 `WarLoad` 越界校验生效（`script/jymain.lua`）

### T5 无头端到端验证脚手架（Contract D）

- [x] T5.1 `game/tests/unit/test_mod_e2e.lua`（37 断言，5 个测试函数 + 运行时对话测试）
- [x] T5.2 `game/tests/unit/test_mod_boot.lua`（55 断言，全启动链路：`lib.init` → `JYMainAdapter.init`
      → `LoadRecord(0)` → `GAME_FIRSTMMAP` → `GAME_MMAP` → `ReadTalk` 对话 → `WarLoad`/`WarLoadMap` 战斗 → `SaveRecord(1)` → `LoadRecord(1)` round-trip → 存档隔离）
- [x] T5.3 注册到 `test_runner.lua`（`mod_e2e` / `mod_boot` 模块 + 全量套件）
- [x] T5.4 `lua tests/test_runner.lua mod_e2e` / `mod_boot` 全绿
- [x] T5.5 全量 `lua tests/test_runner.lua` 全绿（无 `active_mod.txt`）

### T6 构建产物

- [x] T6.1 `lua tools/mod_build.lua kys-mingdong` → data files=599, events=1654, talk=5183
- [x] T6.2 产物：`mods/mingdong/{data,script/oldevent,script/old_talk.lua,script/oldtalk.grp,script/oldtalk.idx,diff.md}`

## DoD 验证记录

| DoD | 要求 | 结果 |
|-----|------|------|
| 1 | `lua tests/test_runner.lua mod_e2e` 全绿 | ✅ 37/37（+ `mod_boot` 55/55 全启动链路） |
| 2 | 无 `active_mod.txt` → 全量测试全绿 | ✅ 252/252 |
| 3 | `lua tools/mod_build.lua kys-mingdong` 四产物齐备 | ✅ events=1654, talk=5183 |
