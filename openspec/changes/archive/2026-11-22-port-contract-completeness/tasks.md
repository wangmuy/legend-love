# Tasks: port-contract-completeness

> 父 slice: `engine-portability`（openspec/changes/engine-portability/）
> 分批策略：每批一个 commit，每批跑全量测试。**不允许一次性提交 237 处改动。**

## Task 1：契约定义（13 个新函数，64 → 77）

**Blast Radius**：`game/engine-love2d/engine_api.lua`（只加不改）

> **与原计划的差异**：原计划写「19 个」，实际只加了 13 个。
> 原因是设计阶段把一些既有契约误算成缺失（`setClip`/`showSlow` 等其实已有），
> 另一些（`setTile`/`invalidateCache`）在实现时发现无消费者，按
> Negative Constraint「不得为完整性新增无消费者函数」砍掉了。
> 这不是缩水：实际交付的 13 个**全部**有真实消费者或明确的接线计划。

**实际新增（13 个）**：

- [x] `render.getWidth` / `render.getHeight`（替代编译期常量 CC.ScreenW）
- [x] `font.measureText`（非等宽字体适配）
- [x] `sprite.createFromRGBA`（ADR-PORT-013 核心）
- [x] `sprite.createFromEncoded`（ADR-PORT-014 PNG 路径）
- [x] `sprite.getMeta`
- [x] `sprite.drawPictureFile`（独立图片，开场图/结局图）
- [x] `map.getTile` / `map.unload` / `map.tickClouds`
- [x] `audio.playSequence` / `audio.playVideo`
- [x] `input.enableKeyRepeat`
- [x] 每个都带完整文档注释（含「为什么是这个粒度」）
- [x] `initSprites` 补充可选 `paletteFile` 参数（修既有契约缺陷）
- [x] `fillRect`/`rectOutline` 的 color 参数注释修正（int 或 table 都接受）
- [x] `luac5.1 -p` 与 `luac55 -p` 通过

---

## Task 2：`lib.Debug` 批量改写（180 处）

**Blast Radius**：`game/framework/*.lua`（24 个文件）

**DoD**：
- [x] 180 处 `lib.Debug(` → `EngineAPI.debug.log(`
- [x] 保留 `lib.Debug` 全局定义（script 层仍在用）
- [x] 全量测试零失败（这一批是纯机械替换，必须 0 回归）
- [x] **一个 commit**

---

## Task 3：`lib.GetKey` / `lib.Delay` / `lib.GetTime` 改写（25 处）

**Blast Radius**：`game/framework/*.lua`

**DoD**：
- [x] 15 处 `lib.GetKey` → `EngineAPI.input.getKey`
- [x] 9 处 `lib.Delay` → `EngineAPI.time.sleep`
- [x] 1 处 `lib.GetTime` → `EngineAPI.time.getTime`
- [x] VK 整数语义不变（36 处业务调用点零改动）
- [x] 全量测试零失败

---

## Task 4：渲染契约改写（14 处）

**Blast Radius**：`game/framework/*.lua`

**DoD**：
- [x] 3 处 `lib.SetClip` → `EngineAPI.render.setClip`
- [x] 9 处 `lib.ShowSlow` → `EngineAPI.render.presentAndWait`（或新契约）
- [x] 1 处 `lib.FillColor` → `EngineAPI.render.fillRect`（已有）
- [x] 1 处 `lib.DrawRect` → `EngineAPI.render.rectOutline`（已有）
- [x] 全量测试零失败

---

## Task 4b：新建 `sprite_decoder.lua`（RLE + 调色板解码搬到 framework）

**Blast Radius**：`game/framework/sprite_decoder.lua`（新）、
`game/framework/text_box_layout.lua`（不加，仅参考）

**DoD**：
- [x] `SpriteDecoder.decodeRLE(grpBytes, offsetA, offsetB)` →
      `{ w=, h=, xoff=, yoff=, rgba=<w*h*4 字节> }`
      - 解析前 8 字节帧头（`w,h` 小端 u16；`xoff,yoff` 小端 i16）
      - 逐行 RLE 解压（`count=u8`，`trans=u8`，`solid=u8`，索引 u8）
      - 调色板 256×3 字节，值 0..63 → `*4`
      - 输出 RGBA 顺序字节串（透明像素 = 0,0,0,0）
- [x] `SpriteDecoder.loadPalette(colBytes)` → 调色板表
- [x] `SpriteDecoder.sniffFormat(bytes)` → `"rle"` | `"png"`（按字节签名，
      **不看扩展名**）
- [x] `SpriteDecoder.decodeAnchors(format, w, h, opts, usage)` →
      - packed+RLE → 用帧头
      - packed+PNG + usage="avatar" → `w/2, h/2`（**中心**）
      - packed+PNG + 其它 → `w/2, h`（脚底中心，保守默认）
      - loose → 用 `opts.xoff/opts.yoff`
- [x] **头像锚点实测**：`hdgrp.grp` slot 60（100×102）应得
      `xoff=50, yoff=51`；slot 112（100×93）应得 `xoff=50, yoff=46`
- [x] 文件里 `love\.` = 0、`require("engine` = 0
- [x] **性能**：用 raw RGBA 一次性构造（不逐像素 setPixel）
- [x] 单元测试：解码一帧真实 RLE，断言 `w/h/xoff/yoff` 与 RGBA 前 4 字节
- [x] **负向对照**：把 `xoff/yoff` 硬置 0 → 测试必须 FAIL

---

## Task 4c：契约新增两个上传函数 + 锚点查询

**Blast Radius**：`game/engine-love2d/engine_api.lua`

**DoD**：
- [x] `sprite.createFromRGBA(w, h, rgbaBytes, opts)` →
      `{ handle, w, h, xoff, yoff }`
      - 契约注释写清：`rgbaBytes` **一律 RGBA 顺序**；
        Unreal 的 BGRA 在实现内 swizzle
- [x] `sprite.createFromEncoded(bytes, formatHint)` → 同上
      - 引擎用自身的图片解码能力（LÖVE `newImageData(FileData)` /
        Godot `load_png_from_buffer` / Unreal `ImportBufferAsTexture2D` /
        SDL `IMG_Load_RW`）
- [x] `sprite.getMeta(handle)` → `{ w, h, xoff, yoff }`
- [x] 4 引擎实现齐全
- [x] `luac5.1 -p` / `luac55 -p` 通过

---

## Task 5：精灵契约改写（16 处）

**Blast Radius**：`game/framework/*.lua`

**DoD**：
- [x] 4 处 `lib.PicInit` → `EngineAPI.sprite.initPalette`
- [x] 8 处 `lib.PicLoadFile` → `EngineAPI.sprite.loadArchive`
- [x] 2 处 `lib.PicLoadCache` → `EngineAPI.sprite.draw`
- [x] 2 处 `lib.LoadPicture` → `EngineAPI.sprite.loadPicture`
- [x] 实机冒烟：物品图标、人物头像、地图精灵显示正确
- [x] **混合容器验证**：`hdgrp.grp` 的 2 个 PNG 帧（slot 60/112）能加载
- [x] **锚点回归验证**：主角帧 `xoff=5, yoff=44` 与改动前一致
- [x] **锚点缺陷验证**：PNG 帧的 `xoff/yoff` 不再是 0
- [x] 全量测试零失败

---

## Task 6：地图契约改写 + `map_render.lua`（16 处 + 新模块）

**Blast Radius**：`game/framework/game_states.lua`、`game/framework/mouse_hover.lua`、
`game/framework/map_render.lua`（新）

**DoD**：
- [x] 新建 `framework/map_render.lua`：等距投影 + 裁剪 + 排序（纯计算，零引擎依赖）
- [x] 5 处 `lib.GetMMap` → `EngineAPI.map.getTile`
- [x] 4 处 `lib.DrawMMap` → `MapRender.drawMain`
- [x] 2 处 `lib.DrawSMap` → `MapRender.drawScene`
- [x] 1 处 `lib.UnloadMMap` → `EngineAPI.map.unload`
- [x] 1 处 `lib.CloudTick` → `MapRender.tickClouds`（纯逻辑）
- [x] **实机对照**：主地图与场景地图逐格像素一致（截图对比）
- [x] 全量测试零失败

---

## Task 7：音频契约改写（2 处）

**Blast Radius**：`game/framework/*.lua`

**DoD**：
- [x] 1 处 `lib.PlayMIDI` → `EngineAPI.audio.playSequence`
- [x] 1 处 `lib.PlayMPEG` → `EngineAPI.audio.playVideo`
- [x] 1 处 `lib.EnableKeyRepeat` → `EngineAPI.input.enableKeyRepeat`
- [x] 实机冒烟：开始菜单音乐、场景音乐、开场 MPEG
- [x] 全量测试零失败

---

## Task 8：虚拟手柄接线修复

**Blast Radius**：`game/framework/jymain_adapter.lua`、
`game/engine-mud/engine_mud.lua`、`game/engine-web/engine_web.lua`

**DoD**：
- [x] 4 引擎实现 `render.getWidth` / `render.getHeight`
  （LÖVE 返回真实尺寸；MUD/Web 返回哨兵 1024×768）
- [x] `pollVirtualPad` 在 LÖVE 下真实激活
- [x] 端到端测试：注入触摸点 → `pollVirtualPad()` 返回 true
      → 动作队列出现 `{action="ui.accept", source="touch"}`
- [x] **负向对照**：去掉 `render.getWidth` 实现后该测试必须 FAIL
- [x] 全量测试零失败

---

## Task 9：38 个 dead contract 决策

**Blast Radius**：`openspec/changes/port-contract-completeness/decisions.md`（新）、
`game/engine-love2d/engine_api.lua`

**DoD**：
- [x] 新建 `decisions.md`：38 项逐条记录（保留 / 删除 / 标 @deprecated）
- [x] 删除明确无意义的 8 个函数
- [x] 18 个标 `@deprecated` 并指向新契约
- [x] 12 个保留的加注释说明未来消费者（引用 TODO.md 条目）
- [x] 全量测试零失败（删除函数前先确认无调用点）

---

## Task 10：跨引擎一致性测试

**Blast Radius**：`game/tests/unit/test_engine_conformance.lua`（新）、
`game/tests/test_runner.lua`

**DoD**：
- [x] 新建 `test_engine_conformance.lua`：
      - 遍历 4 个引擎实现，断言每个契约函数非 nil
      - 对 MUD/Web 真实调用（不 skip），断言哨兵值
      - 断言 `render.getWidth/getHeight` 返回 number 且 > 0
      - 断言 `font.measureText` 存在时被 `TextBoxLayout` 使用
- [x] 注册到 `test_runner.lua`
- [x] **负向对照**：从某引擎删一个契约函数，测试必须 FAIL
- [x] 全量测试零失败

---

## Task 11：门禁与文档

**Blast Radius**：`game/tests/gate_engine_contract.sh`（新）、
`AGENTS.md`、`ENGINE_API_DESIGN.md`、`SRC_FILES.md`

**DoD**：
- [x] 新建 `gate_engine_contract.sh`：
      - `grep framework/ 的 lib.` = 0
      - `grep framework/ 的 love.` = 0
      - `grep framework/sprite_decoder.lua 的 love.` = 0
      - 契约函数在 4 引擎齐全
      - **引擎里不得出现 RLE 解码逻辑**（`grep 'palletteIdx\|paletteIdx' engine-*/` = 0）
      - 负向对照实测（加回一处 `lib.DrawMMap` → FAIL；
        在引擎里加回 RLE 解码 → FAIL）
- [x] 文档计数：`AGENTS.md` 的「59 个函数」→ 实际数（75 / 15 模块）
- [x] `ENGINE_API_DESIGN.md` 同步
- [x] `SRC_FILES.md` 同步

---

## Task 12：全量验证

**DoD**：
- [x] Lua 5.1 / 5.3 / 5.4 / 5.5 全量测试全绿（记录断言数）
- [x] `luac5.1 -p` / `luac55 -p` 全仓零失败
- [x] LÖVE 11.5 启动冒烟无报错
- [x] 门禁 `gate_engine_contract.sh` 全 PASS
- [x] 既有门禁 `gate_input_actions.sh` / `gate_base_music.sh` / `gate_ascii.sh` 全 PASS
- [x] 实机冒烟：菜单 / 对话 / 地图 / 战斗 / 商店 / 存档各跑一次
