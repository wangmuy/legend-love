# Tasks: port-sprite-native-migration

> 父 slice: `engine-portability`
> 顺序严格：Task 1（PNG 前置）→ Task 2..6（迁移）→ Task 7（收尾）

## Task 1：修 `SpriteAtlas` 的 PNG 路径（**前置，不可跳过**）

**Blast Radius**：`game/framework/sprite_atlas.lua`

**DoD**：
- [x] `getHandle` 的 PNG 分支：handle 创建后从 `EngineAPI.sprite.getMeta(handle)`
      回读真实 `w/h`，写进 `atlas.meta[slot]`（不是 `d.w or 0`）
- [x] `getMeta` 的 PNG 分支：兜底调 `getHandle`，再取 `atlas.meta[slot]`
- [x] **容忍 w=0**：MUD/Web 的 `createFromEncoded` 返回 `{w=0,h=0}`，
      兜底后 `getMeta` 返回 `w=0`（不抛错、不当错误）
- [x] 单元测试：用真实 `hdgrp.grp` 的 slot 59（PNG 帧）验证 `getMeta` 返回 `w>0`
- [x] 单元测试：MUD 桩引擎下 `getMeta` 返回 `w=0` 且不崩
- [x] 负向对照：把 PNG 分支改回 `return nil` → 测试 FAIL（实测生效）
- [x] 四版本全量测试零失败（3799/0）
- [x] 一个 commit（992f973）
- [x] **附带**：修了 `test_runner.lua` 的 60-upvalue 上限（57 模块收进 T 表 +
      54 个 elseif 改表查）

---

## Task 2：`battle_render.lua` 迁移（7 处）

**Blast Radius**：`game/script/battle/battle_render.lua`

**DoD**：
- [x] `WarShowHead` 的 `lib.PicGetXY(1, p["头像代号"]*2)` →
      `SpriteAtlas.getMeta(1, p["头像代号"]*2)`（解构改 table）
- [x] `WarShowHead` 的 `lib.PicLoadCache(1, ..., 1)` →
      `SpriteAtlas.draw(1, frameId, x, y, 0x1)`（flag 1 = 忽略锚点，语义相同）
- [x] `WarDrawMap` 的 5 处 `lib.DrawWarMap(...)` →
      `EngineAPI.map.drawBattle(...)`（参数一一对应）
- [x] **前置确认**：`EngineAPI.map.drawBattle` 在 4 个引擎里都实现了
      （若 LÖVE 的 `map.drawBattle` 内部就调 `lib.DrawWarMap`，则等价）
- [x] 单测：`WarDrawMap` 4 个 flag（0/1/2/4）各调一次 `map.drawBattle` 且不崩
- [x] 单测：`WarShowHead` 不崩（stub `getMeta`/`draw`）
- [x] 四版本全量测试零失败
- [x] 实机截图：战斗画面正常
- [x] 一个 commit

---

## Task 3：`jymain.lua` 的 7 处 `PicInit` 全删

**Blast Radius**：`game/script/jymain.lua`

**DoD**：
- [x] 删除 6 处无参 `lib.PicInit()`（实测 no-op）
- [x] 删除 `JY_Main_sub` 里的 `lib.PicInit(CC.PaletteFile)`（死代码 + 已被
      `jymain_adapter.init` → `initSprites` 覆盖）
- [x] **前置确认**：`jymain_adapter.init` 确实调了
      `EngineAPI.sprite.initSprites(CC.PaletteFile)`（决定调色板仍会加载）
- [x] 单测：调色板仍然被加载（检查 `EngineAPI.sprite.initSprites` 的调用）
- [x] 四版本全量测试零失败
- [x] 一个 commit

---

## Task 4：`jymain.lua` 的 14 处 `PicLoadFile` → `loadArchive`

**Blast Radius**：`game/script/jymain.lua`

**DoD**：
- [ ] `Init_MMap`（3 处）：MMAP / Head / Thing → `SpriteAtlas.loadArchive`,
      其中 Head 带 `{usage="avatar"}`
- [ ] `Init_SMap`（3 处）：SMAP / Head / Thing → 同上
- [ ] `WarMain` 阻塞版（5 处，死代码但必须迁，否则 gate 豁免摘不掉）：
      WMAP / Head / Thing / Effect / FightPic → 同上
- [ ] 全部带 `{paletteFile = CC.PaletteFile}`
- [ ] **注意 archive 编号必须与原来一致**（0 / 1 / 2 / 3 / 4+i）
- [ ] 单测：`SpriteAtlas` 的 5 个 archive 都被加载
- [ ] 四版本全量测试零失败
- [ ] 一个 commit

---

## Task 5：`jymain.lua` 的 6 处 `PicGetXY`/`PicLoadCache` → `getMeta`/`draw`

**Blast Radius**：`game/script/jymain.lua`

**DoD**：
- [ ] `Cal_PicClip` 的 2 处 `PicGetXY`（返回 4 值）→ `getMeta`（table 解构）
      —— **这是最高风险点**：裁剪矩形算错会导致武功动画错位
- [ ] `War_ShowHead`（死代码里的同名函数？）的 1 处 `PicGetXY` → `getMeta`
- [ ] 物品菜单的 2 处 `PicLoadCache` → `draw`
- [ ] `War_ShowHead` 的 1 处 `PicLoadCache` → `draw`
- [ ] 单测：`Cal_PicClip` 返回的裁剪矩形与改造前**数值一致**（用固定输入对比）
- [ ] 四版本全量测试零失败
- [ ] 实机截图：武功攻击动画的裁剪正常（不是"人物缺一块"）
- [ ] 一个 commit

---

## Task 6：移除 `war_async` 的双轨补丁

**Blast Radius**：`game/framework/war_async.lua`

**DoD**：
- [ ] 删除 `EngineAPI.sprite.loadArchive(...)` 那 4 行（保留 `SpriteAtlas` 的）
- [ ] `grep -c 'sprite.loadArchive' framework/war_async.lua` = 0
- [ ] 四版本全量测试零失败
- [ ] 实机截图：战斗画面正常（这是 `ebf81af` 修的那个 bug 的回归验证）
- [ ] 一个 commit

---

## Task 7：gate 取消豁免 + 收尾验证

**Blast Radius**：`game/tests/gate_engine_contract.sh`、`openspec/project/TODO.md`

**DoD**：
- [ ] `gate_engine_contract.sh` STEP D 删除 `engine-love2d` 豁免的 INFO 行
- [ ] STEP D 对 4 个引擎执行同一判据
- [ ] 新增 STEP：`script/` 零 `lib.Pic*`（硬断言）
- [ ] 负向对照：在 `script/` 加一处 `lib.PicLoadFile(` → gate FAIL
- [ ] 四版本全量测试零失败（记录断言数）
- [ ] 全仓 `luac5.1 -p` / `luac55 -p` 零失败
- [ ] 五门禁全 PASS
- [ ] **实机截图**：战斗 / 物品栏 / 人物状态 三个界面全部正常
- [ ] **人物 59 头像专项**：确认 PNG 帧路径正常（这是唯一的 PNG 命中案例）
- [ ] 更新 `openspec/project/TODO.md`（删掉已完成的条目）
- [ ] 一个 commit
