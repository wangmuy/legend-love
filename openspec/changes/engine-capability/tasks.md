# Tasks: engine-capability

## Blast Radius

### 新增

- `game/tests/unit/test_engine_system.lua`
- `game/tests/unit/test_mouse_input.lua`
- `game/tests/unit/test_sprite_tinted.lua`

### 修改

- `game/engine-love2d/engine_api.lua`
- `game/engine-love2d/engine_love2d.lua`
- `game/engine-love2d/lib_love.lua`
- `game/engine-mud/engine_mud.lua`
- `game/engine-web/engine_web.lua`
- `game/tests/engine_test.lua`
- `game/framework/settings.lua`
- `game/framework/input_manager.lua`
- `game/framework/jymain_adapter.lua`
- `game/tests/unit/test_settings.lua`
- `game/tests/unit/test_input_manager.lua`
- `game/tests/test_runner.lua`
- `AGENTS.md`
- `SRC_FILES.md`
- `ENGINE_API_DESIGN.md`

### 不得触碰

- `game/script/jymain.lua`（slice 3 才需要，本 change 只读参考）
- `game/framework/menu_state_machine.lua`（slice 2 才改）
- `game/framework/game_states.lua`（slice 3 才改）
- `game/conf.lua`（实测无需调整 DPI 选项）
- `game/main.lua`（slice 2 才注册鼠标回调）

---

## T1: `EngineAPI.system` 新模块

- [x] `engine_api.lua`：新增 `M.system = {}`，声明 `getOS()` 与完整注释
- [x] `engine_love2d.lua`：`EngineAPI.system.getOS = function() return love.system.getOS() end`
- [x] `engine_mud.lua`：返回 `"unknown"`
- [x] `engine_web.lua`：返回 `"web"`（**硬编码，不调 love.system**）
- [x] `tests/engine_test.lua`：`_os` 可注入，默认 `"Windows"`
- [x] **DoD**: 三引擎 + 测试引擎都可调用，返回值在允许集合内

## T2: `EngineAPI.input.mousePosition` / `mouseButton`

- [x] `engine_api.lua`：声明两函数 + **DPI 契约注释**（逻辑坐标、Windows 150% 实测）
- [x] `engine_love2d.lua`：`mousePosition` 返回 `love.mouse.getPosition()`；`mouseButton` 用 `love.mouse.isDown`
- [x] `engine_mud.lua`：`mousePosition` 返回 `-1, -1`；`mouseButton` 返回 `false`
- [x] `engine_web.lua`：同 mud
- [x] `tests/engine_test.lua`：`mousePosition` 可注入；`mouseButton` 可注入
- [x] **DoD**: `grep "toDensity\|toPixels" engine-love2d/` 为空（无需换算）
- [x] **DoD**: 实机断言 150% 缩放下 `setPosition(1023,767)` → 读回 `(1023,767)`

## T3: `EngineAPI.sprite.drawTinted`

- [x] `engine_api.lua`：声明 `drawTinted(archiveId, spriteId, x, y, color, alpha)` + 注释
- [x] `lib_love.lua`：实现 `DrawPicTinted`（参考 `PicLoadCache`，颜色不写死）
- [x] `engine_love2d.lua`：委托 `lib.DrawPicTinted`
- [x] `engine_mud.lua` / `engine_web.lua`：记录调用，不抛错
- [x] `tests/engine_test.lua`：记录 `archiveId/spriteId/color/alpha`
- [x] 参数容错：`color` 为 nil/缺分量 → 退化为原色
- [x] **DoD**: 实机截图确认红闪效果（`{1,0,0}` 在菱形上可见）

## T4: `settings.lua` 新增 platform 层

- [x] 内部状态加 `platformName` 与 `platformDefaults`（每个 key 一份）
- [x] `Settings.setPlatform(name)` 注入；`nil` 视为 `"unknown"`
- [x] `define` 接受 `platformDefaults` 字段并归一化
- [x] `get()` 解析顺序改为 `user > mod > platform > default`
- [x] `spec()` 返回 `platformDefaults` 副本（便于测试与界面枚举）
- [x] `save()` **不**写入 platform 层（只写 user 层）
- [x] **DoD**: `grep -E "EngineAPI|love\.|CC\.[A-Za-z]|JY\.[A-Za-z]" framework/settings.lua`
      （排除注释）为空
- [x] **DoD**: 6 条优先级场景全部有测试

## T5: `input_manager.lua` 鼠标事件队列

- [x] 新增 `mouseQueue` / `mouseHead` / `mouseTail`（与键盘队列同结构）
- [x] `enqueueMouseEvent(event)`：容量上限与丢最旧策略同键盘
- [x] `InputManager:getMouseEvent()` 或模块级 `getMouseEvent()`
- [x] `init()` 时清空鼠标队列（与键盘一起）
- [x] **DoD**: `getKey()` 在只有鼠标事件时返回 `-1`
- [x] **DoD**: 既有 `input_manager` 测试零回归

## T6: 宿主注入平台

- [x] `jymain_adapter.lua` 初始化：`Settings.setPlatform(EngineAPI.system.getOS())`
- [x] 位置必须在 `Settings.load()` **之前**（否则 platform 层尚不可用）
- [x] 失败时（`EngineAPI.system` 缺失）退化为 `"unknown"`，不崩
- [x] **DoD**: 日志中能看到注入的平台名

## T7: 测试

- [x] `test_engine_system.lua`：三引擎 + 测试引擎的 `getOS`
- [x] `test_mouse_input.lua`：`mousePosition` / `mouseButton` / 队列隔离
- [x] `test_sprite_tinted.lua`：参数容错、任意 spriteId、透明色
- [x] `test_settings.lua` 扩展：platform 层 6 条场景
- [x] `test_runner.lua`：注册新模块 + 更新帮助文本
- [x] **DoD**: `lua tests/test_runner.lua` 四版本全绿，断言数不低于 2417

## T8: 文档计数同步

- [x] `AGENTS.md`：「12 个模块」→「15 个模块」
- [x] `SRC_FILES.md`：EngineAPI 计数 → 55 函数 / 15 模块
- [x] `ENGINE_API_DESIGN.md`：「51 个函数」→「55 个函数」
- [x] **DoD**: `grep -n "12 个模块" AGENTS.md` 为空

## DoD 汇总（change 级）

1. [x] Lua 5.1 / 5.3 / 5.4 / 5.5 全量测试全绿（记录各版断言数）
2. [x] `luac5.1 -p` 与 `luac5.5 -p` 全仓零失败
3. [x] 干净 Windows PATH 下结果与完整 PATH 一致
4. [x] LÖVE 11.5 启动冒烟无报错
5. [x] `settings.lua` 零引擎依赖（grep 为空）
6. [x] `engine-love2d/` 无 `toDensity`/`toPixels` 调用（实测无需换算）
7. [x] Windows 150% 下 `mousePosition` 与绘图坐标 1:1（可复跑的断言）
8. [x] `drawTinted` 实机红闪可见（截图或人工确认记录）
9. [x] 文档计数 15 模块 / 55 函数
10. [x] 负向对照：回退 `settings.lua` 的 platform 层 → 平台默认值测试必须失败
11. [x] 负向对照：把鼠标事件混入键盘队列 → `getKey()` 隔离测试必须失败
