# Tasks: port-conformance-hardening

> **本 change 的性质**：三项修复**已经落地并验证**（commit `5e3c0ce` /
> `e270864` / `d0241bb` / `cd9a6dc`），本 change 是把它们**正式立项、
> 补 spec、并记录「以后怎么防」**。所以所有 task 都已完成。

## Task 1：`playSequence` 语义补到 4 引擎

**Blast Radius**：`engine_mud.lua`、`engine_web.lua`、`tests/engine_test.lua`、
`tests/unit/test_engine_conformance.lua`

**DoD**：
- [x] MUD：`playSequence(id)` + `type(id) ~= "number"` → false + `id < 0` → false
- [x] Web：同上
- [x] 测试桩：同上（桩返回 true 表示「调用被接受」，语义仍守 number 校验）
- [x] conformance 断言改成**源码级**（require 后调用抓不到，因为共享表）
- [x] 负向对照：破坏 MUD → 4 条 FAIL

## Task 2：`mod_data` 的 2 处主路径 io 收进契约

**Blast Radius**：`framework/mod_data.lua`、`tests/unit/test_engine_io_portability.lua`

**DoD**：
- [x] `readActiveFile()` 优先 `EngineAPI.file.read`，兜底 io.open
      （**契约返回 nil 时不能立刻 return nil**：测试里 file.read 常被 mock 成白名单）
- [x] `WarRecordCount()` 优先 `EngineAPI.file.getSize`
      （只问大小，不该打开文件）
- [x] 4 条新测试：两个函数各一对（契约可用时 io 计数 0 / 无契约时计数 1）
- [x] 负向对照：改回 stdlib-first → 2 条 FAIL

## Task 3：conformance 完整性检查改源码级 + 补缺口

**Blast Radius**：`tests/unit/test_engine_conformance.lua`、
`engine_mud.lua`、`tests/engine_test.lua`

**DoD**：
- [x] 判据改为读源码找 `EngineAPI.x.y = function` / `function EngineAPI.x.y(`
- [x] 检查范围 3 引擎 → **4 引擎**（原来漏了 LÖVE）
- [x] 补 MUD 缺的 7 个契约：
      `file.read` / `file.write` / `file.lines` / `file.openFile` /
      `file.createDirectory` / `app.quit` / `time.getTimeSeconds`
- [x] 补测试桩缺的 3 个：`dialog.measure` / `dialog.draw` / `dialog.clear`
- [x] 负向对照：删 MUD 的 `file.read` → 「MUD 缺 1 个契约实现: file.read」

## Task 4：注入点 nil 安全（getMyPicOr + CurrentD 守卫）

**Blast Radius**：`framework/game_hooks.lua`、`game_states.lua`、
`jymain_adapter.lua`、`interact.lua`、`tests/unit/test_auto_move.lua`、
`tests/unit/test_nil_safety.lua`（新）

**DoD**：
- [x] 新增 `GameHooks.getMyPicOr(fallback)`（`getMyPic()` 的 nil 语义不变）
- [x] 8 处调用点改用 `getMyPicOr`
- [x] `JY.CurrentD >= 0` 的 2 处缺失守卫补齐（`game_states:765` / `:830`）
- [x] `test_auto_move.setupMoveEnv` 注册 GameHooks；`restoreMoveEnv` 里 clear
      → 单模块跑 68/68（原来必崩）
- [x] 新增 `test_nil_safety.lua`（25 断言），含负向对照
      ① getMyPicOr 行为 ② 框架零 `JY.MyPic = getMyPic()`
      ③ CurrentD 比较必须有守卫 ④ test_auto_move 自注册 ⑤ 旧写法确实崩

## Task 5：文档与归档

**Blast Radius**：`openspec/project/TODO.md`、
`openspec/changes/archive/2026-11-22-engine-portability/change-manifest.md`

**DoD**：
- [x] `TODO.md` 记录 3 个「靠漏判通过」及修复
- [x] `change-manifest.md`：header 14 → **17**；新增「第三批」小节（含依赖图 +
      对 slice 结论的影响表）；Slice 完成判定改为 17 个 + 最终验收数据
- [x] `slice-proposal.md`：子 change 清单加第三批 2 个（含「3 个验证缺陷」对照表）；
      「14 个 change」→ 17；修正「若将来出现第三批缺口」的过期表述
- [x] 全量测试 **4328/0** + 门禁 A–L PASS + 双版本 luac 零失败 +
      实机 md5（场景 `1efd2af3…` / 战斗 `6c8eb322…`）不变
- [x] 归档

## 依赖

- 无前序依赖（`engine-portability` slice 的 14 个 change 已全部归档）
- 与 `port-engine-boot` 是**承接关系**（那个 change 交了 4 处 io，
  本 change 补了漏掉的 2 处）
