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
- [x] `engine_api.lua` 声明 `M.render.setDrawLoopFlag(flag)`（带注释说明用途）
- [x] LÖVE：转发 `lib.SetDrawLoopFlag`
- [x] MUD/Web：空实现（记录调用即可）
- [x] 测试桩：记录调用
- [x] 单测：4 引擎都存在（`assertNotNil` + `testNewContractsExplicitlyImplemented` 扩项）
- [x] 契约数 91 → **92**（基线实测：`engine_api.lua` 当前 91 个 `M.*` 声明）
- [x] 全量测试零失败（4011）
- [x] 一个 commit

## Task 3：`main.lua` 改调契约

**Blast Radius**：`game/main.lua`

**DoD**：
- [x] 2 处 `lib.SetDrawLoopFlag(true/false)` → `EngineAPI.render.setDrawLoopFlag(...)`
- [x] `main.lua:118` 的全局 `lib = require "engine-love2d.engine_love2d"` 改 `local engineAPI`
      （入口程序不需要再持有全局 `lib`；`engineAPI.init()` 照旧）
- [x] 实机截图：场景 `1efd2af3…` ✓ / 战斗 `6c8eb322…` ✓（present 门控生效）
- [x] 一个 commit

## Task 4：`async_globals` 补丁点迁移

**Blast Radius**：`game/framework/async_globals.lua`、`game/script/jymain.lua`、
`game/tests/unit/test_wait_frame.lua`

**DoD**：
- [x] `_libDelay = lib and lib.Delay` → `_engineSleep = EngineAPI.time.sleep`
- [x] `lib.Delay = AsyncGlobals.lib_Delay_Async` → `EngineAPI.time.sleep = ...`
- [x] `lib.Delay = _libDelay` → `EngineAPI.time.sleep = _engineSleep`
- [x] `lib_Delay_Async` 内部：协程内走 `scheduler:waitFrame`，非协程走 `_engineSleep`
      （**不再**回落 `EngineAPI.time.sleep`，否则自己调自己）
- [x] `jymain.lua:51` 的 fallback `function(m) lib.Delay(m) end`
      → 闭包绑定 `EngineAPI.time.sleep`（在覆盖前取出，避免递归）
- [x] 单测：非协程 `WaitFrame` → 调契约 1 次；协程内 → 0 次；
      新增 `testNeverTouchesGlobalLib`（断言零 `lib.Delay` 调用）
- [x] 门禁 STEP D3 + D6 白名单归零（负向对照已验证：加一处 `lib.Debug` → FAIL）
- [x] 全量测试零失败（4013，比基线 +2 = 新增的 2 条断言）
- [x] 一个 commit

## Task 5：删死变量 + 删 `_G.lib`

**Blast Radius**：`game/framework/interact.lua`、`game/framework/settings_store.lua`、
`game/engine-love2d/engine_love2d.lua`、`game/engine-mud/engine_mud.lua`、
`game/engine-web/engine_web.lua`

**DoD**：
- [x] 删 `interact.lua:185` 的死变量
- [x] 删 `settings_store.lua:45` 的死变量（同时补 `local EngineAPI = rawget(...)`，
      原代码在本函数内引用 `EngineAPI` 会拿到 nil）
- [x] 删 `engine_love2d.lua` 的 `_G.lib = setmetatable(...)`
- [x] `engine_mud.lua` / `engine_web.lua` 的 `_G.lib` 一并删除
      （实测两引擎运行时零 `lib.` 引用；Web 的 30 余条 if 链整块删除）
- [x] 三个引擎都冒烟：LÖVE 场景 `1efd2af3…` ✓ / 战斗 `6c8eb322…` ✓ /
      主地图目视正常；MUD 与 Web 各自 `require` 后 `rawget(_G,"lib") == nil` ✓
- [x] `grep -rn '_G.lib =' game/` = 0（tests/ 与 tools/ 除外）
- [x] Web 的 `lua-vm.spec.js` 断言从「lib 存在」改为「lib == nil」
- [x] 一个 commit

## Task 6：门禁 + 文档

**Blast Radius**：`game/tests/gate_engine_contract.sh`、`openspec/project/TODO.md`、
`openspec/changes/engine-portability/change-manifest.md`

**DoD**：
- [x] 新增 STEP I：① 生产代码零 `_G.lib =`（tests/tools 豁免）
      ② `lib_love.lua` 代码行零 `lib.` ③ framework/script/main 零 `rawget(_G,"lib")`
- [x] 负向对照 3 项全部验证：加 `_G.lib =` / 加 `lib.Debug` /
      加 `rawget(_G,"lib")` → 各自 FAIL
- [x] 顺带修两个门禁自身缺陷：
      ① `GREP_OPTIONS` 非空时**覆盖** `--include`（实测会把 `.js` 搜进来）
         → 门禁开头 `GREP_OPTIONS=` 清空
      ② `` 在 POSIX grep 下不生效（被误写成退格字符）
         → 改 `(^|[^A-Za-z0-9_])lib\.` 这种可移植写法
- [x] 更新 `TODO.md`（4 条遗留已立项）
- [x] 更新 `change-manifest.md`（第二批 4 个 change + 依赖 + 过期 stub 标注）
- [x] 全量测试 4013/0 + ENGINE_CONTRACT/INPUT_ACTIONS/BASE_MUSIC 三门禁 PASS
- [x] 一个 commit

## 前置核实（Task 0，只读）

- [x] `grep 'lib\.' game/engine-mud/engine_mud.lua game/engine-web/engine_web.lua`（非注释）
      确认两引擎自身不依赖全局 `lib`（实测：MUD 0 处；Web 只有 `_G.lib =` 定义本身）
- [x] 确认 `tests/engine_test.lua:625` / `tests/test_helper.lua:274` 的 `_G.lib`
      是「测试桩模拟」而非被测代码需要：**是**（`test_helper.mockLib()` 给
      老套件提供 `Debug/GetKey/Delay/Cls` 桩；引擎测试桩同理）。
      按 change 的 spec 保留（`REQ-CLR-1` 的 Out of Scope）。
