# Tasks: port-contract-completeness

> 父 slice: `port-slice1-contract-completeness`
> 分批策略：每批一个 commit，每批跑全量测试。**不允许一次性提交 237 处改动。**

## Task 1：契约定义（19 个新函数）

**Blast Radius**：`game/engine-love2d/engine_api.lua`（只加不改）

**DoD**：
- [ ] 新增 19 个函数声明，每个带完整文档注释（含「为什么是这个粒度」）
- [ ] 分组：`render` +3（getWidth/getHeight/measureText 归 font）
- [ ] 分组：`map` +2（getTile/setTile）
- [ ] 分组：`sprite` +3（initPalette/loadPicture/invalidateCache）
- [ ] 分组：`render` +4（setClip/showSlow/fillColor/drawRect 归一到已有或新增）
- [ ] 分组：`audio` +2（playSequence / playVideo，对应 PlayMIDI/PlayMPEG）
- [ ] 分组：`input` +1（enableKeyRepeat）
- [ ] `luac5.1 -p` 与 `luac55 -p` 通过

---

## Task 2：`lib.Debug` 批量改写（180 处）

**Blast Radius**：`game/framework/*.lua`（24 个文件）

**DoD**：
- [ ] 180 处 `lib.Debug(` → `EngineAPI.debug.log(`
- [ ] 保留 `lib.Debug` 全局定义（script 层仍在用）
- [ ] 全量测试零失败（这一批是纯机械替换，必须 0 回归）
- [ ] **一个 commit**

---

## Task 3：`lib.GetKey` / `lib.Delay` / `lib.GetTime` 改写（25 处）

**Blast Radius**：`game/framework/*.lua`

**DoD**：
- [ ] 15 处 `lib.GetKey` → `EngineAPI.input.getKey`
- [ ] 9 处 `lib.Delay` → `EngineAPI.time.sleep`
- [ ] 1 处 `lib.GetTime` → `EngineAPI.time.getTime`
- [ ] VK 整数语义不变（36 处业务调用点零改动）
- [ ] 全量测试零失败

---

## Task 4：渲染契约改写（14 处）

**Blast Radius**：`game/framework/*.lua`

**DoD**：
- [ ] 3 处 `lib.SetClip` → `EngineAPI.render.setClip`
- [ ] 9 处 `lib.ShowSlow` → `EngineAPI.render.presentAndWait`（或新契约）
- [ ] 1 处 `lib.FillColor` → `EngineAPI.render.fillRect`（已有）
- [ ] 1 处 `lib.DrawRect` → `EngineAPI.render.rectOutline`（已有）
- [ ] 全量测试零失败

---

## Task 5：精灵契约改写（16 处）

**Blast Radius**：`game/framework/*.lua`

**DoD**：
- [ ] 4 处 `lib.PicInit` → `EngineAPI.sprite.initPalette`
- [ ] 8 处 `lib.PicLoadFile` → `EngineAPI.sprite.loadArchive`
- [ ] 2 处 `lib.PicLoadCache` → `EngineAPI.sprite.draw`
- [ ] 2 处 `lib.LoadPicture` → `EngineAPI.sprite.loadPicture`
- [ ] 实机冒烟：物品图标、人物头像、地图精灵显示正确
- [ ] 全量测试零失败

---

## Task 6：地图契约改写 + `map_render.lua`（16 处 + 新模块）

**Blast Radius**：`game/framework/game_states.lua`、`game/framework/mouse_hover.lua`、
`game/framework/map_render.lua`（新）

**DoD**：
- [ ] 新建 `framework/map_render.lua`：等距投影 + 裁剪 + 排序（纯计算，零引擎依赖）
- [ ] 5 处 `lib.GetMMap` → `EngineAPI.map.getTile`
- [ ] 4 处 `lib.DrawMMap` → `MapRender.drawMain`
- [ ] 2 处 `lib.DrawSMap` → `MapRender.drawScene`
- [ ] 1 处 `lib.UnloadMMap` → `EngineAPI.map.unload`
- [ ] 1 处 `lib.CloudTick` → `MapRender.tickClouds`（纯逻辑）
- [ ] **实机对照**：主地图与场景地图逐格像素一致（截图对比）
- [ ] 全量测试零失败

---

## Task 7：音频契约改写（2 处）

**Blast Radius**：`game/framework/*.lua`

**DoD**：
- [ ] 1 处 `lib.PlayMIDI` → `EngineAPI.audio.playSequence`
- [ ] 1 处 `lib.PlayMPEG` → `EngineAPI.audio.playVideo`
- [ ] 1 处 `lib.EnableKeyRepeat` → `EngineAPI.input.enableKeyRepeat`
- [ ] 实机冒烟：开始菜单音乐、场景音乐、开场 MPEG
- [ ] 全量测试零失败

---

## Task 8：虚拟手柄接线修复

**Blast Radius**：`game/framework/jymain_adapter.lua`、
`game/engine-mud/engine_mud.lua`、`game/engine-web/engine_web.lua`

**DoD**：
- [ ] 4 引擎实现 `render.getWidth` / `render.getHeight`
  （LÖVE 返回真实尺寸；MUD/Web 返回哨兵 1024×768）
- [ ] `pollVirtualPad` 在 LÖVE 下真实激活
- [ ] 端到端测试：注入触摸点 → `pollVirtualPad()` 返回 true
      → 动作队列出现 `{action="ui.accept", source="touch"}`
- [ ] **负向对照**：去掉 `render.getWidth` 实现后该测试必须 FAIL
- [ ] 全量测试零失败

---

## Task 9：38 个 dead contract 决策

**Blast Radius**：`openspec/changes/port-contract-completeness/decisions.md`（新）、
`game/engine-love2d/engine_api.lua`

**DoD**：
- [ ] 新建 `decisions.md`：38 项逐条记录（保留 / 删除 / 标 @deprecated）
- [ ] 删除明确无意义的 8 个函数
- [ ] 18 个标 `@deprecated` 并指向新契约
- [ ] 12 个保留的加注释说明未来消费者（引用 TODO.md 条目）
- [ ] 全量测试零失败（删除函数前先确认无调用点）

---

## Task 10：跨引擎一致性测试

**Blast Radius**：`game/tests/unit/test_engine_conformance.lua`（新）、
`game/tests/test_runner.lua`

**DoD**：
- [ ] 新建 `test_engine_conformance.lua`：
      - 遍历 4 个引擎实现，断言每个契约函数非 nil
      - 对 MUD/Web 真实调用（不 skip），断言哨兵值
      - 断言 `render.getWidth/getHeight` 返回 number 且 > 0
      - 断言 `font.measureText` 存在时被 `TextBoxLayout` 使用
- [ ] 注册到 `test_runner.lua`
- [ ] **负向对照**：从某引擎删一个契约函数，测试必须 FAIL
- [ ] 全量测试零失败

---

## Task 11：门禁与文档

**Blast Radius**：`game/tests/gate_engine_contract.sh`（新）、
`AGENTS.md`、`ENGINE_API_DESIGN.md`、`SRC_FILES.md`

**DoD**：
- [ ] 新建 `gate_engine_contract.sh`：
      - `grep framework/ 的 lib.` = 0
      - `grep framework/ 的 love.` = 0
      - 契约函数在 4 引擎齐全
      - 负向对照实测（加回一处 `lib.DrawMMap` → FAIL）
- [ ] 文档计数：`AGENTS.md` 的「59 个函数」→ 实际数（75 / 15 模块）
- [ ] `ENGINE_API_DESIGN.md` 同步
- [ ] `SRC_FILES.md` 同步

---

## Task 12：全量验证

**DoD**：
- [ ] Lua 5.1 / 5.3 / 5.4 / 5.5 全量测试全绿（记录断言数）
- [ ] `luac5.1 -p` / `luac55 -p` 全仓零失败
- [ ] LÖVE 11.5 启动冒烟无报错
- [ ] 门禁 `gate_engine_contract.sh` 全 PASS
- [ ] 既有门禁 `gate_input_actions.sh` / `gate_base_music.sh` / `gate_ascii.sh` 全 PASS
- [ ] 实机冒烟：菜单 / 对话 / 地图 / 战斗 / 商店 / 存档各跑一次
