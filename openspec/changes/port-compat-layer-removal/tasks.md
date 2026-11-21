# Tasks: port-compat-layer-removal

> **策略**：先摘掉自引用（`lib_love` 8 处）→ 再补契约（`setDrawLoopFlag`）
> → 再改 5 处消费者 → 最后删 `_G.lib`。
> 顺序不能反：先删 `_G.lib` 会让 `lib_love` 的自引用立刻崩。

## Task 1：`lib_love.lua` 去自引用（8 处）

**Blast Radius**：`game/engine-love2d/lib_love.lua`

**DoD**：
- [x] 8 处 `lib.Debug(...)` → `Debug(...)`
      （7 处在 `SaveSMap`：`lib_love.lua:1421/1424/1429/1432/1435/1440/1443`；
       1 处在 `DrawWarMap`：`:1703`）
- [x] `grep -nE '\blib\.' game/engine-love2d/lib_love.lua`（非注释）= 0
- [x] 全量测试零失败（4011）
- [x] 实机三界面 md5 不变（场景 `1efd2af3…` ✓ / 战斗 `6c8eb322…` ✓）
- [x] 一个 commit

## Task 2：新增契约 `render.setDrawLoopFlag(flag)`（4 引擎）

**Blast Radius**：`engine_api.lua`、`engine_love2d.lua`、`engine_mud.lua`、
`engine_web.lua`、`tests/engine_test.lua`、`tests/unit/test_engine_api.lua`

**DoD**：
- [ ] `engine_api.lua` 声明 `M.render.setDrawLoopFlag(flag)`（带注释说明用途）
- [ ] LÖVE：转发 `lib.SetDrawLoopFlag`
- [ ] MUD/Web：空实现（记录调用即可）
- [ ] 测试桩：记录调用
- [ ] 单测：4 引擎都存在（`assertNotNil`）
- [ ] 契约数 91 → **92**（基线实测：`engine_api.lua` 当前 91 个 `M.*` 声明）
- [ ] 全量测试零失败
- [ ] 一个 commit

## Task 3：`main.lua` 改调契约

**Blast Radius**：`game/main.lua`

**DoD**：
- [ ] 2 处 `lib.SetDrawLoopFlag(true/false)` → `EngineAPI.render.setDrawLoopFlag(...)`
- [ ] `main.lua:118` 的全局 `lib = require "engine-love2d.engine_love2d"` 仍保留
      （它是入口程序持有 EngineAPI 的方式，且 `lib.init()` 需要它 ——
      换成 `local EngineAPI` 更干净，但那是可选清理，记在 Task 6）
- [ ] 实机截图：主菜单/地图/战斗三界面正常（present 门控生效）
- [ ] 一个 commit

## Task 4：`async_globals` 补丁点迁移

**Blast Radius**：`game/framework/async_globals.lua`、`game/script/jymain.lua`、
`game/tests/unit/test_wait_frame.lua`

**DoD**：
- [ ] `_libDelay = lib and lib.Delay` → `_engineSleep = EngineAPI.time.sleep`
- [ ] `lib.Delay = AsyncGlobals.lib_Delay_Async` → `EngineAPI.time.sleep = ...`
- [ ] `lib.Delay = _libDelay` → `EngineAPI.time.sleep = _engineSleep`
- [ ] `lib_Delay_Async` 内部：协程内走 `scheduler:waitFrame`，非协程走 `_engineSleep`
      （**不再**回落 `EngineAPI.time.sleep`，否则自己调自己）
- [ ] `jymain.lua:51` 的 fallback `function(m) lib.Delay(m) end`
      → `function(m) EngineAPI.time.sleep(m) end`
- [ ] 单测：非协程 `WaitFrame` → 调 `EngineAPI.time.sleep`；协程内 → 0 次
- [ ] 门禁 STEP D6 的「只允许 WaitFrame fallback」白名单同步改判据
- [ ] 全量测试零失败
- [ ] 一个 commit

## Task 5：删死变量 + 删 `_G.lib`

**Blast Radius**：`game/framework/interact.lua`、`game/framework/settings_store.lua`、
`game/engine-love2d/engine_love2d.lua`、`game/engine-mud/engine_mud.lua`、
`game/engine-web/engine_web.lua`

**DoD**：
- [ ] 删 `interact.lua:185` 的死变量
- [ ] 删 `settings_store.lua:45` 的死变量
- [ ] 删 `engine_love2d.lua:1123` 的 `_G.lib = setmetatable(...)`
- [ ] `engine_mud.lua:537` / `engine_web.lua:642` 的 `_G.lib`：先 `grep` 各引擎内部
      对 `lib.` 的引用，确认是 `local lib` 还是全局后，删除或降级
- [ ] 三个引擎都冒烟：LÖVE 实机三界面 + MUD 跑一局 + Web 起一次
- [ ] `grep -rn '_G.lib =' game/` = 0（tests/ 除外）
- [ ] 一个 commit

## Task 6：门禁 + 文档

**Blast Radius**：`game/tests/gate_engine_contract.sh`、`openspec/project/TODO.md`、
`openspec/changes/engine-portability/change-manifest.md`

**DoD**：
- [ ] 新增 STEP I：
      ① `_G.lib =` 只允许出现在 `game/tests/`
      ② `lib_love.lua` 代码行零 `lib.`
      ③ framework/script/main 零 `rawget(_G,"lib")`
- [ ] 负向对照：往 `lib_love.lua` 加一处 `lib.Debug` → gate FAIL
- [ ] 更新 `TODO.md`：删掉「`lib.*` 兼容层本身」条目（本轮实测推翻其前提）
- [ ] 更新 `change-manifest.md`：把第 3 项标为已拆出
- [ ] 全量测试 + 五门禁
- [ ] 一个 commit

## 前置核实（Task 0，只读）

- [ ] `grep 'lib\.' game/engine-mud/engine_mud.lua game/engine-web/engine_web.lua`（非注释）
      确认两引擎自身不依赖全局 `lib`
- [ ] 确认 `tests/engine_test.lua:621` / `tests/test_helper.lua:274` 的 `_G.lib`
      是「测试桩模拟」而非被测代码需要
