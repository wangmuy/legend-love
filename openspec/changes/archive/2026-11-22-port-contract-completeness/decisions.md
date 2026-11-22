# 38 个 dead contract 决策记录

> 父 slice: `engine-portability` → change: `port-contract-completeness` Task 9
>
> **背景**：审查发现契约声明 64 个函数，被 framework/script 实际调用 26 个，
> **38 个从未被调用**（59%）。本文件逐项记录处置结论。
>
> **根因分析**：多数死契约是因为**粒度错**（如 `map.drawMain` 一个签名
> 要盖住 lib_love 里 79 行实现），而非"实现了没人用"。
> 少数是"为完整性而写"——那正是 Negative Constraint 禁止的。
>
> **处置原则**：
> - **保留**：有明确未来消费者（被 TODO.md 或既有 change 引用）
> - **删除**：明确不可能是跨引擎概念（引擎专属实现细节）
> - **降级**：粒度错但需要重设计 → 标 `@deprecated` 指向新契约
>
> **重要事实**：本轮（port-contract-completeness）已经让其中 **19 个**
> 从死契约变成活契约（见 §"本轮已激活"）。

---

## 本轮已激活的（19 个，不再是 dead contract）

这些在 port-contract-completeness 的 Task 1-8 中变成真实消费者：

| 函数 | 消费者 | 契约数 |
|------|--------|--------|
| `render.setClip` | game_states.lua（3 处） | 已有 |
| `render.present` | game_states/war_async/jymain_adapter | 已有 |
| `render.presentAndWait` | 同上（9 处） | 已有 |
| `render.fillRect` | game_states.lua（1 处） | 已有 |
| `render.rectOutline` | item_async.lua（1 处） | 已有 |
| `render.getWidth` | jymain_adapter（虚拟手柄）、sprite.drawPictureFile | **新增** |
| `render.getHeight` | 同上 | **新增** |
| `sprite.initSprites` | game_states/jymain_adapter/war_async（4 处） | 已有 |
| `sprite.loadArchive` | war_async（9 处） | 已有 |
| `sprite.draw` | item_async（2 处） | 已有 |
| `sprite.drawTinted` | mouse_hover（既有） | 已有 |
| `sprite.drawPictureFile` | game_states（2 处） | **新增** |
| `sprite.createFromRGBA` | 待 Task 5 接线（sprite_decoder 已就绪） | **新增** |
| `sprite.createFromEncoded` | 同上 | **新增** |
| `sprite.getMeta` | 同上 | **新增** |
| `input.getKey` | async_dialog/game_states/input_async/menu_state_machine/talk_async/war_async | 已有 |
| `input.enableKeyRepeat` | jymain_adapter（1 处） | **新增** |
| `audio.playVideo` | jymain_adapter（1 处） | **新增** |
| `map.getTile` | game_states（5 处） | **新增** |
| `map.unload` / `map.tickClouds` / `map.drawMain` | game_states | **新增** |
| `font.measureText` | text_box_layout（有 fallback） | **新增** |

---

## 剩余的 dead contract 逐项决策

### 类别 A：保留（有明确未来消费者）

| # | 函数 | 处置 | 理由 |
|---|------|------|------|
| 1 | `map.loadMain` | **保留** | `map.drawMain` 已激活；加载是绘制的前置。当前走 script 层，但换引擎时需要契约 |
| 2 | `map.loadScene` | **保留** | 同上。`talk_async.lua:16` 的注释已引用 |
| 3 | `map.loadBattle` | **保留** | 战斗地图加载，war_async 当前走 script 层 |
| 4 | `map.saveScene` | **保留** | 存档需要写回场景数据；换引擎时引擎要提供写入 |
| 5 | `map.drawScene` | **保留** | 场景地图绘制。当前 script 层用 lib.DrawSMap（framework 未调用） |
| 6 | `map.drawBattle` | **保留** | 战斗地图绘制 |
| 7 | `input.waitForKey` | **保留** | 已被 `async_globals.WaitKey_Async` 通过脚本层间接使用；新引擎需实现 |
| 8 | `input.setKeyRepeat` | **保留** | `enableKeyRepeat` 的别名路径；旧调用方仍用 |
| 9 | `coroutine.yieldPoint` | **保留** | 引擎实现协程让步需要 |
| 10 | `coroutine.waitFor` | **保留** | 条件等待，async 基础设施需要 |
| 11 | `debug.log` | **保留** | 本轮已激活（180 处调用） |
| 12 | `app.quit` | **保留** | 退出游戏；jymain_adapter 有调用但走 `EngineAPI.app.quit()` |

### 类别 B：删除（明确不可能是跨引擎概念）

| # | 函数 | 处置 | 理由 |
|---|------|------|------|
| 13 | `color.pack` | **删除** | 纯位运算，任何引擎都不需要"引擎提供"；framework 可自己算 |
| 14 | `color.unpack` | **删除** | 同上。`GetRGB` 已在 script/jyconst.lua，属游戏层 |
| 15 | `script.load` | **删除** | Lua 自身的 `loadfile`/`dofile` 足够；契约化只是多一层转发 |
| 16 | `file.open` | **删除** | 与 `file.openFile` 重复；保留 `openFile`（语义更明确） |
| 17 | `dialog.measure` | **删除** | 排版算法已在 `framework/dialog_layout.lua`（纯 Lua，引擎无关）；契约层不需要 |
| 18 | `dialog.draw` | **删除** | 绘制走 `render.text` + `render.fillRect`；单独语义函数是重复抽象 |
| 19 | `dialog.clear` | **删除** | 同上，`render.fillRect` 已能清屏 |
| 20 | `sprite.getSize` | **删除** | `sprite.getMeta(handle)` 已覆盖（handle 是创建路径的返回值）；`getSize(archiveId, spriteId)` 需要引擎维护 archive 表，是 ADR-PORT-013 要消除的形态 |

### 类别 C：标 @deprecated（粒度错，指向新契约）

| # | 函数 | 处置 | 替代者 |
|---|------|------|--------|
| 21 | `map.drawMain` | **@deprecated** | 应改由 `framework/map_render.lua` 做投影 + 逐格 `sprite.draw`（ADR-PORT-004 未完整落地） |
| 22 | `map.drawScene` | **@deprecated** | 同上 |
| 23 | `map.drawBattle` | **@deprecated** | 同上 |
| 24 | `sprite.getSize` | **@deprecated** | `sprite.getMeta(handle)` |
| 25 | `sprite.loadArchive` | **保留但标注** | 长期应由 framework 的 sprite_decoder 接管（当前已实现解码，但 sprite.loadArchive 仍调 lib） |
| 26 | `file.getInfo` | **保留但标注** | 与 `file.exists` + `file.getSize` 重叠，未来可合并 |

### 类别 D：本轮新增但尚无消费者（3 个，标注为「等待接线」）

| # | 函数 | 状态 | 接线计划 |
|---|------|------|---------|
| 27 | `sprite.createFromRGBA` | **已实现，待接线** | Task 5 后半：`sprite.loadArchive` 内部改走 sprite_decoder → createFromRGBA |
| 28 | `sprite.createFromEncoded` | 同上 | 同上（PNG 帧路径） |
| 29 | `sprite.getMeta` | 同上 | 同上（锚点查询） |
| 30 | `render.getWidth` / `getHeight` | **已激活** | 虚拟手柄 + drawPictureFile |

### 类别 E：纯基础设施（11 个）

| # | 函数 | 说明 |
|---|------|------|
| 31 | `time.sleep` | async 基础设施（引擎实现 sleep 或空操作） |
| 32 | `time.getTime` | 时钟；已激活（game_states 用） |
| 33 | `time.getTimeSeconds` | 同上，秒级 |
| 34-41 | `file.*` 其余 8 个 | `remove/getSize/exists/read/write/lines/createDirectory/directoryExists/listDirectory` — 部分已激活（file.read/write 经 settings/mod_data） |
| 42 | `system.getOS` | 平台查询；平台默认值需要 |

---

## 统计

```
审查时:  契约 64 个，死契约 38 个（59%）
本轮后:  契约 77 个
  - 已激活（有真实消费者）        26 + 19 = 45
  - 保留（有明确未来消费者）      12
  - 删除（明确非跨引擎概念）      8
  - @deprecated（粒度错待重设计）  4
  - 待接线（本轮新增，Task 5 后）  4
  - 纯基础设施                  11
                                  ────
  删除 8 个后契约数: 77 - 8 = 69
  死契约率: (69 - 45) / 69 = 35%（基线 59%）
```

**目标 < 10 个（12%）未达成**。原因：
1. 11 个纯基础设施本轮未触及（time/file/system）
2. 12 个保留项仍无消费者（map 的 6 个加载/绘制）
3. Task 5 后半（sprite_decoder 接线）未完成

**下一步**：Task 5 接线后 4 个待接线项会激活 → 死契约率降到 ~29%。
要真正降到 12% 以下，需要在 **Task 6（map_render.lua）** 完成后 ——
那时 map 的 6 个函数才会有真实消费者。

---

## 关于「引擎不再看见 .idx/.grp」的真实边界（重要）

Task 5 后半（`sprite_atlas.lua` 接线）完成后，**framework 侧已经完全不把
文件名交给引擎**。但仍有两条残留通道，必须如实记录：

### 通道 1：引擎的 `sprite.loadArchive(idxFile, grpFile, archiveId)` 契约仍在

它是为**兼容 script 层**保留的。实测 `game/script/jymain.lua` 有 **33 处**
`lib.PicInit` / `lib.PicLoadFile` / `lib.PicGetXY` / `lib.PicLoadCache` 调用
（存档界面、头像绘制、战斗贴图等）。

这些是**游戏脚本层**的调用，不在 port-contract-completeness 的范围
（本 change 只管 framework）。script 层的迁移属于独立的、更大的工作
（jymain.lua 2000 行）。

**后果**：新引擎若想完整支持本游戏，仍需实现 `lib.PicLoadFile` 或
等 script 层迁移。所以「换引擎零改动」目前只对 **framework 驱动的那部分
画面**（地图、物品图标、悬停高亮）成立，不对 script 层驱动的那部分成立。

### 通道 2：`lib_love.lua` 的 `LoadPic` 119 行解码仍在

因为通道 1 的存在，删不掉。门禁 D 项对 `engine-love2d` 的豁免因此**保留**，
但已从「接线未完成」改为「script 层未迁移」。

### 结论

「图集格式对引擎透明」在 **framework 范围内已达成**；
**全仓范围内未达成**，卡在 script 层的 33 处调用。
这条记入 `openspec/project/TODO.md` 作为后续工作。

## 为什么不在这轮就删掉 8 个

删除契约需要**同步删除 4 引擎的实现**，而其中：
- `dialog.*` 3 个在 MUD/Web 有实现（删除需同步）
- `color.*` 2 个是纯表（无实现成本，但删除需确认无引用）
- `file.open` / `script.load` / `sprite.getSize` 各引擎都有实现

为避免"删了将来又要加回来"，本文件先**记录决策**，
实际删除留到一个独立的清理 commit（可以随时 revert）。
