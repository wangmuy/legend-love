# Tasks: port-engine-boot

> **策略**：先把「启动知识」契约化（#2 + #5 + 清单），再修主路径 stdlib 依赖（#4），
> 最后补门禁。三项中 #1（清单）和 #3（别名）会撞 `engine_api.lua` 与 4 个
> 引擎文件，所以合并成一条工作流；#4 与它们零重叠，可并行。

## Task 1：新增 4 个契约（90 → 94）

**Blast Radius**：`game/engine-love2d/engine_api.lua`

**DoD**：
- [x] `M.app.install(runtime)` 声明 + 文档写清「runtime 是宿主能力
      （退出/错误上报/全屏/资源根），不是引擎契约的一部分」
- [x] `M.app.requestQuit()` 声明 + 文档写清「未注册时返回 false，不抛错」
- [x] `M.render.beginFrame()` / `M.render.endFrame()` 声明
- [x] `setDrawLoopFlag` 标 `@deprecated` 并给出转发实现建议
- [x] 文档写明**立即模式**假设 + Godot 的 `draw_string` 在 `_draw` 外静默无效
- [x] 契约数 90 → 94

## Task 2：新增 `framework/boot.lua`

**Blast Radius**：`game/framework/boot.lua`（新）

**DoD**：
- [x] `Boot.install(runtime)`：7 步装配顺序写死并注释
- [x] `Boot.update(dt)`：3 个调用顺序固定，dt 单位文档写明是秒
- [x] `Boot.draw()`：`beginFrame/endFrame` 夹住，`pcall` 保证 endFrame 一定执行
- [x] `Boot.quit()` / `Boot.requestQuit()`
- [x] 幂等（重复 install 只更新 runtime）
- [x] 测试辅助：`Boot.isInstalled` / `Boot._runtime` / `Boot._reset`
- [x] 零 `love.*`

## Task 3：4 引擎实现新契约

**Blast Radius**：`engine_love2d.lua` / `engine_mud.lua` / `engine_web.lua` /
`tests/engine_test.lua`

**DoD**：
- [x] LÖVE：`beginFrame/endFrame` 转发 `lib.SetDrawLoopFlag`；
      `app.install/requestQuit` 转发 `framework.boot`
- [x] MUD：`beginFrame/endFrame` 走 `logCall`；`install/requestQuit` 同转发
- [x] Web：`webInDrawLoop` 置位；`install/requestQuit` 同转发
- [x] 测试桩：同 MUD
- [x] `test_engine_api.lua` 的 `newFns` 加 4 项，4 引擎都必须显式实现

## Task 4：`main.lua` 变薄

**Blast Radius**：`game/main.lua`

**DoD**：
- [x] 头部改 `local Boot = require("framework.boot")`
- [x] `love.load` 里的 7 步装配 → 一次 `Boot.install({...})`
- [x] `runtime` 传 `quit`（`love.event.quit`）与 `onError`（写 `__crash.txt`）
- [x] `love.update` → `Boot.update(dt)`
- [x] `love.draw` → `Boot.draw()`（保留截图调试）
- [x] `love.quit` → `Boot.quit()`
- [x] 保留 `--shot` / `--keys` / `--battle` / `--mmap` 四个调试设施
- [x] `main.lua` 里不再出现 `JYMainAdapter.init()` / `EventBridge:init()`

## Task 5：`require_aliases.lua`（裸名别名唯一来源）

**Blast Radius**：`game/framework/require_aliases.lua`（新）、
`engine_love2d.lua`、`engine_mud.lua`、`engine_web.lua`、
`game/engine-web/web_game_bridge.lua`、`tests/engine_test.lua`

**DoD**：
- [x] 5 个别名写死在一处，require 时自动 install（幂等）
- [x] 4 引擎都改成 `require("framework.require_aliases")`
      （MUD/Test 此前**完全没有** → 跑不了 script 层；Web 原有 26 个「顺带注册」）
- [x] `web_game_bridge.lua` 的重复注册表统一过来（26 → 5）
- [x] `engine_api.lua` 头部加「新引擎实现清单」：
      ① 实现 94 个契约 ② `require framework.require_aliases`
      ③ `EngineAPI.init()`（隐式约定） ④ 3 个全局（CONFIG/CC/Byte）
      ⑤ 6 步启动序列 ⑥ 每帧 3 个调用 + 绘制边界 ⑦ dt 单位 ⑧ 绘制时机

## Task 6：修 4 处主路径 stdlib 依赖

**Blast Radius**：`framework/mod_ini.lua`、`jymain_adapter.lua`、
`game_states.lua`、`lib_log.lua`、`framework/clock.lua`（新）

**DoD**：
- [x] `ModIni.readFile` 优先 `EngineAPI.file.read`，兜底 `io.open`
- [x] `math.randomseed` 用 `EngineAPI.time.getTimeSeconds` × 1000，兜底 `os.time`
      **取毫秒不取秒**：getTimeSeconds 是单调计时（启动时恒 0.x），
      floor 成秒永远是 0 → 每次启动随机序列相同
- [x] 存档时间戳 / 日志时间戳走 `framework/clock.lua`
      **修正原计划**：加了 1 个契约 `time.formatNow`（94 → 95）。
      原计划说「用 getTimeSeconds 自己算 Y-M-D」是**语义错误** ——
      getTimeSeconds 不是 Unix 纪元秒，自己算只会得到 1970-01-01，
      且每次启动都一样，存档时间戳会变成明显错误的数据
- [x] 日志时间戳失败时降级为 `"-"`（不崩）
- [x] 新增 `test_engine_io_portability.lua`（54 断言）

## Task 7：门禁 + 测试 + 文档

**Blast Radius**：`gate_engine_contract.sh`、`test_boot.lua`、
`test_require_aliases.lua`、`docs/screenshots/README.md`

**DoD**：
- [x] 新增 `test_boot.lua`（61 断言）+ `test_require_aliases.lua`（45）
      + `test_engine_io_portability.lua`（54）
- [x] gate STEP L：`engine_api.lua` 含「新引擎实现清单」+ 写明
      `framework.require_aliases`
- [x] gate STEP F2：**显式白名单**（`boot|war_async`）登记允许 require
      script 的 framework 模块；另断言「装配入口唯一（只有 boot）」
      负向对照已验证 FAIL（往 status_page 加 require("script.jymain")）
- [x] 修正 `docs/screenshots/README.md` 里 save-menu 的判据分类
      （原来标「逐字节稳定」是错的 —— 背景含随机云）
- [x] 全量测试 **4271/0**；门禁 PASS；双版本 luac 零失败；
      场景 `1efd2af3…` / 战斗 `6c8eb322…` md5 不变

## 依赖

- 无前序依赖（`engine-portability` slice 的 14 个 change 已全部归档）
- 后续可接：真正的 `engine-godot` / `engine-unreal` 实现
