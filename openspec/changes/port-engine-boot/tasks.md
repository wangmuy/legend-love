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
- [ ] 5 个别名写死在一处，require 时自动 install（幂等）
- [ ] 4 引擎都改成 `require("framework.require_aliases")`
- [ ] `web_game_bridge.lua` 的重复注册表统一过来
- [ ] `engine_api.lua` 头部加「新引擎实现清单」：
      ① 实现 94 个契约 ② `require framework.require_aliases`
      ③ `EngineAPI.init()`（隐式约定） ④ 3 个全局（CONFIG/CC/Byte）
      ⑤ 6 步启动序列 ⑥ 每帧 3 个调用 + 绘制边界 ⑦ dt 单位 ⑧ 绘制时机

## Task 6：修 4 处主路径 stdlib 依赖

**Blast Radius**：`framework/mod_ini.lua`、`jymain_adapter.lua`、
`game_states.lua`、`lib_log.lua`、`framework/clock.lua`（新）

**DoD**：
- [ ] `ModIni.readFile` 优先 `EngineAPI.file.read`，兜底 `io.open`
- [ ] `math.randomseed` 用 `EngineAPI.time.getTimeSeconds`，兜底 `os.time`
- [ ] 存档时间戳 / 日志时间戳走 `framework/clock.lua`（不新增契约）
- [ ] 日志时间戳失败时降级为「无时间戳」（不崩）
- [ ] 新增 `test_engine_io_portability.lua`

## Task 7：门禁 + 测试 + 文档

**Blast Radius**：`gate_engine_contract.sh`、`test_boot.lua`、
`test_require_aliases.lua`、`docs/screenshots/README.md`

**DoD**：
- [x] 新增 `test_boot.lua`（61 断言）
- [x] gate 断言 `engine_api.lua` 含「新引擎实现清单」
- [ ] gate STEP F 为 `framework/boot.lua` 开**显式**白名单
      （它是缝合层，允许调 script 全局；但不能让别的模块借此漏过）
- [x] 修正 `docs/screenshots/README.md` 里 save-menu 的判据分类
      （原来标「逐字节稳定」是错的 —— 背景含随机云）
- [x] 全量测试 4172/0；门禁 PASS；双版本 luac 零失败；场景/战斗 md5 不变

## 依赖

- 无前序依赖（`engine-portability` slice 的 14 个 change 已全部归档）
- 后续可接：真正的 `engine-godot` / `engine-unreal` 实现
