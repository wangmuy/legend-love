# Tasks: port-contract-pruning

## Task 1：核实 3 个契约确实无消费者（前置）

**Blast Radius**：`game/engine-love2d/*`、`game/engine-mud/*`、`game/engine-web/*`、`game/tests/*`

**DoD**：
- [x] `sprite.getSize`：framework+script 消费者 = 0；4 引擎都只有定义行（1/1/1/1）
- [x] `coroutine.yieldPoint`：同上
- [x] `coroutine.waitFor`：同上
- [x] **排除 `file.open`**（web 的 `openFile` 内部转发它，3 处引用）
- [x] **排除 `input.setKeyRepeat`**（web 的 lib 别名表引用它，2 处引用）

## Task 2：从契约文件删除 3 个声明

**Blast Radius**：`game/engine-love2d/engine_api.lua`

**DoD**：
- [x] 删 `M.sprite.getSize`（含注释块）
- [x] 删 `M.coroutine.yieldPoint`
- [x] 删 `M.coroutine.waitFor`
- [x] 契约数 79 → **76**（`grep -c 'function M\.'` = 76）
- [x] `luac5.1 -p` 通过

## Task 3：从 4 个引擎删除实现

**Blast Radius**：`engine_love2d.lua`、`engine_mud.lua`、`engine_web.lua`、`tests/engine_test.lua`

**DoD**：
- [x] LÖVE：删 3 个（含 `waitFor` 的 while 循环体）
- [x] MUD：删 3 个
- [x] Web：删 3 个（`waitFor` 体略不同，单独处理）
- [x] 测试桩：删 3 个
- [x] 4 个文件的 grep 命中数 = 0
- [x] 4 个文件 `luac5.1 -p` 通过

## Task 4：删除测试断言

**Blast Radius**：`game/tests/unit/test_engine_api.lua`

**DoD**：
- [x] 删 `assertNotNil(EngineAPI.sprite.getSize, ...)`
- [x] 删 `assertNotNil(EngineAPI.coroutine.yieldPoint, ...)`
- [x] 删 `assertNotNil(EngineAPI.coroutine.waitFor, ...)`
- [x] 全仓 grep 这 3 个名字 = 0（排除 mods）

## Task 5：全量验证

**DoD**：
- [x] Lua 5.1 全量测试：**3871/0**（主仓 3876 → 少 3 条断言在 worktree 副本下）
- [x] 五门禁全 PASS
- [x] 全仓 `luac5.1 -p` 零失败
- [x] 实机截图与删除前**逐字节相同**（md5 6c8eb322…）
