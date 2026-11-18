# Tasks: port-script-decoupling

> 父 slice: `engine-portability`
> 分批策略：按调用类别分 4 批，每批一个 commit，每批全量测试 + 实机冒烟。
> **不允许一次性提交 140 处改动**（这是本 slice 风险最高的一段）。

## Task 1：新建三个 facade 模块

**Blast Radius**：`game/framework/render_facade.lua`（新）、
`game/framework/flow_facade.lua`（新）、`game/framework/game_hooks.lua`（新）

**DoD**：
- [ ] `render_facade.lua`：`text` / `fillRect` / `rectOutline` / `setClip` /
      `drawBackground` / `present` / `clearScreen` / `drawBox` / `drawStrBox` /
      `drawStrBoxYesNo` / `drawStrBoxWaitKey` —— 全部**纯转发**，不含逻辑
- [ ] `flow_facade.lua`：`showMenu` / `showMenu2` / `waitKey` / `talkEx` ——
      转发到既有 `menu_async` / `input_async` / `talk_async`
- [ ] `game_hooks.lua`：`register(spec)` / `getMyPic()` / `addMyCurrentPic()` /
      `sceneCanPass(x, y)` —— 未注册时返回 nil/哨兵，不抛错
- [ ] 三个文件的 `JY\.` / `WAR\.` 命中数 = 0
- [ ] `luac5.1 -p` / `luac55 -p` 通过
- [ ] 不 require 任何 `engine-*`（只用 `EngineAPI` 与既有 framework 模块）

---

## Task 2：绘制类改写（87 处）

**Blast Radius**：`game/framework/*.lua`（24 个文件）

**DoD**：
- [ ] 28 处 `DrawString(` → `RenderFacade.drawString(` 或 `RenderFacade.text(`
- [ ] 28 处 `Cls(` → `RenderFacade.clearScreen(`
- [ ] 11 处 `ShowScreen(` → `RenderFacade.present(`
- [ ] 8 处 `DrawBox(` → `RenderFacade.drawBox(`
- [ ] 10 处 `DrawStrBox(` → `RenderFacade.drawStrBox(`
- [ ] 1 处 `DrawStrBoxYesNo` → `FlowFacade.drawStrBoxYesNo`
- [ ] 1 处 `DrawStrBoxWaitKey` → `FlowFacade.drawStrBoxWaitKey`
- [ ] 2 处 `FillColor` / `DrawRect` → `RenderFacade.fillRect` / `.rectOutline`
- [ ] 全量测试零失败
- [ ] **实机冒烟**：菜单渲染、对话框、地图绘制肉眼一致
- [ ] 一个 commit

---

## Task 3：流程类改写（25 处）

**Blast Radius**：`game/framework/*.lua`

**DoD**：
- [ ] 8 处 `ShowMenu(` → `FlowFacade.showMenu(`
- [ ] 3 处 `ShowMenu2(` → `FlowFacade.showMenu2(`
- [ ] 11 处 `WaitKey(` → `FlowFacade.waitKey(`
- [ ] 3 处 `TalkEx(` → `FlowFacade.talkEx(`
- [ ] 6 处 `PlayMIDI` / 1 处 `PlayMPEG` → 契约（前置 change 已提供）
- [ ] 全量测试零失败
- [ ] **实机冒烟**：打开菜单、菜单选择、对话推进、场景音乐
- [ ] 一个 commit

---

## Task 4：游戏逻辑钩子改写（19 处）

**Blast Radius**：`game/framework/game_states.lua`、
`game/framework/mouse_hover.lua`、`game/framework/jymain_adapter.lua`

**DoD**：
- [ ] 13 处 `GetMyPic(` → `GameHooks.getMyPic(`
- [ ] 4 处 `AddMyCurrentPic(` → `GameHooks.addMyCurrentPic(`
- [ ] 2 处 `SceneCanPass(` → `GameHooks.sceneCanPass(`
- [ ] `jymain_adapter` 启动时注册全部 hooks（指向 `jymain.lua` 的原函数）
- [ ] framework 里 `GetMyPic(` / `AddMyCurrentPic(` / `SceneCanPass(` 命中数 = 0
- [ ] 全量测试零失败
- [ ] **实机冒烟**：主角贴图正确、行走动画、场景进入判定
- [ ] 一个 commit

---

## Task 5：script 层改薄包装

**Blast Radius**：`game/script/jymain.lua`（只改 8 个函数体）

**DoD**：
- [ ] `DrawString` / `DrawBox` / `DrawStrBox` / `DrawStrBoxYesNo` /
      `DrawStrBoxWaitKey` / `Cls` / `ShowScreen` / `ShowMenu` / `ShowMenu2` /
      `WaitKey` / `TalkEx` 改为 facade 薄包装
- [ ] **签名完全不变**（script 层 1000+ 调用点零改动）
- [ ] `game/script/` 的 git diff 只有 `jymain.lua` 的这些函数体
- [ ] 全量测试零失败
- [ ] **实机冒烟**：完整流程（开始菜单 → 新游戏 → 地图 → 对话 → 战斗 → 存档）
- [ ] 一个 commit

---

## Task 6：门禁扩展

**Blast Radius**：`game/tests/gate_engine_contract.sh`（前置 change 新建，本 change 扩展）

**DoD**：
- [ ] 新增断言：framework 里 script 全局调用 = 0
- [ ] 新增断言：facade 文件里 `JY\.` / `WAR\.` = 0
- [ ] **负向对照**：往 framework 加一处 `DrawString(...)` → 门禁 FAIL
- [ ] 恢复后门禁 PASS

---

## Task 7：全量验证

**DoD**：
- [ ] Lua 5.1 / 5.3 / 5.4 / 5.5 全量测试全绿（记录断言数）
- [ ] `luac5.1 -p` / `luac55 -p` 全仓零失败
- [ ] LÖVE 11.5 启动冒烟无报错
- [ ] 门禁 `gate_engine_contract.sh` 全 PASS
- [ ] 既有门禁 `gate_input_actions.sh` / `gate_base_music.sh` / `gate_ascii.sh` 全 PASS
- [ ] **完整实机走查**：开始 → 载入/存档 → 地图移动 → 场景进入 →
      对话（含是/否框、选择框）→ 战斗（手动/自动）→ 商店 → 系统菜单 → 音量调节
