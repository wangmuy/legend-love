---
status: active
parent_epic: null
---
# Change Manifest: engine-portability — 引擎可移植性硬化

> 本 slice 统辖 **14 个**子 change（第一批 10 个已 Complete，第二批 4 个 Not Started），
> 均位于 `openspec/changes/` 下与 slice 同级（符合本仓既有 `mouse-slice1` 的组织方式）。

## Change Assignments

### Change: port-contract-completeness

- **Repository**: this repo
- **Scope**: fullstack（4 引擎实现 + 契约定义 + framework 调用改写 + 跨引擎测试 + 文档）
- **Responsibility**:
  1. 16 种 `lib.*` 提升为 EngineAPI 契约（46 处调用点）
  2. `lib.Debug/GetKey/Delay/GetTime` → `EngineAPI.*`（191 处调用点）
  3. 补齐 3 个缺失契约：`render.getWidth` / `render.getHeight` / `font.measureText`
  4. **修复虚拟手柄接线 bug**（`pollVirtualPad` 依赖不存在的 `render.getWidth`）
  5. **新建 `framework/sprite_decoder.lua`**：RLE + 调色板解码从引擎搬到 framework
     （ADR-PORT-013：`LoadPic` 124 行里只有 5 行碰引擎）
  6. **多格式支持**（ADR-PORT-014）：格式标签 + 两条解码路径
     - RLE → framework 解码 → `sprite.createFromRGBA(w, h, rgbaBytes)`
     - PNG/JPG → 引擎解码 → `sprite.createFromEncoded(bytes, formatHint)`
     - 新增 `sprite.getMeta(handle)` → `{ w, h, xoff, yoff }`
  7. **修复实测缺陷**：PNG 帧路径硬置 `xoff/yoff = 0`
     （RLE 路径保留真实锚点，同容器内两种格式锚点语义不一致）
  8. 38 个 dead contract 决策留痕（`decisions.md`）
  9. 4 引擎实现同步补齐
  10. 新建 `test_engine_conformance.lua`（行为断言，MUD/Web 上真实执行）
  11. 新建门禁 `gate_engine_contract.sh`
  12. 文档计数同步（`AGENTS.md` / `ENGINE_API_DESIGN.md` / `SRC_FILES.md`）
- **Depends On**: —（无前置）
- **Status**: [x] Archived / Complete（port-contract-completeness）

### Change: port-script-decoupling

- **Repository**: this repo
- **Scope**: fullstack（framework facade 新模块 + 140 处调用改写 + script 薄包装 + 测试）
- **Responsibility**:
  1. 新建 `framework/render_facade.lua`（绘制类转发，只调 `EngineAPI.render`）
  2. 新建 `framework/flow_facade.lua`（流程类转发，只调既有 framework 模块）
  3. 新建 `framework/game_hooks.lua`（游戏逻辑注入点，替代硬依赖 script）
  4. framework 里 140 处 script 全局调用改写：
     - 绘制类 87 处（DrawString 28 / Cls 28 / ShowScreen 11 / DrawBox 8 /
       DrawStrBox 10 / DrawStrBoxYesNo 1 / DrawStrBoxWaitKey 1）→ `render_facade`
     - 流程类 25 处（ShowMenu 8 / ShowMenu2 3 / WaitKey 11 / TalkEx 3）→ `flow_facade`
     - 游戏逻辑 19 处（GetMyPic 13 / AddMyCurrentPic 4 / SceneCanPass 2）→ `game_hooks`
     - 音频 8 处（PlayMIDI 6 / PlayMPEG 1）→ 契约；绘制 2 处（FillColor / DrawRect）→ facade
  5. `game/script/jymain.lua` 的 8 个全局函数改为 facade 薄包装
  6. 游戏逻辑回调注入接线（`jymain_adapter` 启动时注册）
  7. 全部既有测试零回归 + 实机冒烟
- **Depends On**: `port-contract-completeness`（需要完整契约；`render.getWidth`
  等是 facade 的基础）
- **Status**: [x] Archived / Complete（port-script-decoupling）

### Change: port-sprite-animation

- **Repository**: this repo
- **Scope**: fullstack（framework 新模块 + game_states 接线 + 测试）
  **引擎实现零改动**
- **Responsibility**:
  1. 新建 `framework/sprite_anim.lua`：纯逻辑动画播放器
     - `defineSequence(id, spec)`：`{archive=, frames={}, fps=, mode=}`
     - `play(handle, sequenceId, opts)` / `stop(handle)` / `isPlaying(handle)`
     - `update(dt)`：唯一时间源
     - `getFrameId(handle)`：返回不透明整数帧号
     - 模式 `loop` / `once` / `pingpong` + `onComplete` 回调
  2. 新建 `framework/animation_defs.lua`：本游戏的帧序列定义
  3. `game_states.lua` 的 4 处 `AddMyCurrentPic()` 改为 `sprite_anim.update(dt)`
  4. `jymain.lua` 的 `GetMyPic` 改为查询 `sprite_anim.getFrameId()`（签名不变）
  5. `Settings` 新增 `animation.walkFps`（默认 15，可调，可关）
  6. 单元测试 `test_sprite_anim.lua`（纯算法，无引擎桩）
- **Depends On**: —（只消费既有 `EngineAPI.sprite.draw` 契约）
  **但建议排在 `port-script-decoupling` 之后**：两者都要改
  `game_states.lua`（前者改 16 处绘制调用，后者改 4 处动画推进点），
  同文件冲突风险
- **Status**: [x] Archived / Complete（port-sprite-animation）

### Change: battle-extensibility

- **Repository**: this repo
- **Scope**: fullstack（战斗流程重构 + 策略接口 + dt 传播 + 实机验证）
- **Responsibility**:
  1. 抽出 `script/battle/` 五模块骨架（先搬不改逻辑）：
     `battle_flow` / `battle_rules` / `battle_ai` / `battle_action` / `battle_render`
  2. `battle_rules` 策略接口定义（`turnbased` / `realtime` / 未来扩展）
  3. `battle_flow` 改调策略，`war_async.lua` 降为「适配层」
  4. `dt` 传播到战斗（`battle_flow.tick(ctx, dt)`）
  5. 实机验证：原版回合制战斗**零回归**（手动/自动/武功/中毒/结算/升级/掉落）
  6. 更新门禁：战斗代码位置断言
- **Depends On**: `port-script-decoupling`（战斗现在调用了大量 framework facade）
- **Status**: [x] Archived / Complete（battle-extensibility）

### Change: port-sprite-native-migration

- **Repository**: this repo
- **Scope**: fullstack（SpriteAtlas PNG 路径修复 + script 层 lib.Pic* 迁移）
- **Responsibility**:
  1. 修 `SpriteAtlas.getMeta`/`getHandle` 的 PNG 路径（**前置**：人物 59 的头像
     命中 PNG 帧 slot 59，当前 getMeta 返回 nil）
  2. `battle_render.lua` 的 2 处 `lib.Pic*` + 5 处 `lib.DrawWarMap` 迁移
  3. `jymain.lua` 的 27 处 `lib.Pic*` 迁移（7 PicInit / 14 PicLoadFile /
     3 PicGetXY / 3 PicLoadCache）
  4. 移除 `war_async.lua` 的双轨加载补丁（`ebf81af` 的临时妥协）
  5. gate STEP D 取消 `engine-love2d` 豁免
- **Depends On**: `port-contract-completeness`（SpriteAtlas 已就绪）
- **Status**: [x] Archived / Complete（port-sprite-native-migration）

### Change: port-battle-robustness

- **Repository**: this repo
- **Scope**: fullstack（WarLoad 错误码 + WAR.Person 容量）
- **Responsibility**:
  1. `WarLoad` 返回明确 `true`/`false`（当前越界只 `JY_Error`，调用方无法分支）
  2. `WarMainCoroutine` 检查返回值，失败时 `warState.status="ended"` /
     `result=nil` 并干净退出
  3. `WAR.Person` 容量 26 → 40（当前 6 我方 + 20 敌方 = **零余量**）
  4. `WarSelectTeam`/`WarSelectEnemy` 越界守卫
- **Depends On**: `battle-extensibility`（战斗模块已抽出）
- **Status**: [x] Archived / Complete（port-battle-robustness）

### Change: port-contract-pruning

- **Scope**: engine（契约裁剪）
- **Responsibility**: 删除 3 个无消费者且引擎内部也不用的契约
  （`sprite.getSize` / `coroutine.yieldPoint` / `coroutine.waitFor`）→ 79 → 76
- **Depends On**: 无
- **Status**: [x] Archived / Complete

### Change: port-blocking-delay

- **Scope**: fullstack（协程等待语义 + 阻塞消除）
- **Responsibility**:
  1. 修 `CoroutineScheduler:waitForTime`（原实现记录 startTime 但从未使用，
     实际只等 1 帧；实测 `waitForTime(0.1)` 在帧 2 恢复，期望 6+）
  2. 修 `timeSource` 构造时绑定 → 动态解析（否则测试 stub 后假时钟推不动）
  3. `instruct_30` 等 7 个函数的阻塞 `lib.Delay` 处置（批 2，未完成）
- **Depends On**: 无
- **Status**: [x] Archived / Complete（批 1 + 批 2 都完成，26 处 lib.Delay → WaitFrame）

### Change: port-map-render-native

- **Scope**: fullstack（map 绘制契约透明化）
- **Responsibility**:
  1. `map.drawMain/drawScene/drawBattle` 三个 @deprecated 契约透明化
     （`framework/map_render.lua` 做投影 + 逐格 `sprite.draw`）
  2. 补 `map.setTile` 契约（当前不存在，而 `SetWarMap` 需要写地图）
  3. `lib.LoadMMap/LoadSMap/LoadWarMap` 一并透明化
  - **这是删 `lib_love.LoadPic` 119 行 + 摘掉 `war_async` 双轨补丁的唯一前提**
- **Depends On**: `port-contract-pruning`（同改 engine_api）
- **Status**: [x] Archived / Complete（port-map-render-native）

### Change: port-native-api-completion

- **Scope**: fullstack（225 处 `lib.*` 迁移）
- **Responsibility**: 迁 191 处有 EngineAPI 等价物的 + 补 34 处无等价物的契约
  （`map.setTile` 等），最后删 `lib.*` 兼容层
- **Depends On**: `port-map-render-native`（否则 `DrawMMap/DrawSMap` 会重复劳动）
- **Status**: [x] Archived / Complete（port-native-api-completion）

---

## 第二批：slice 收尾留下的 4 项（2026-11-21 实测后新增）

> 收尾时记的 4 项「不在 slice 范围」的遗留，本轮逐项实测后**前提全部修正**，
> 各自独立成 change。原陈述与实测结论的对照见每项下方。

### Change: port-compat-layer-removal

- **Scope**: engine + framework + 入口（5 处消费者 + 1 个新契约 + 3 个门禁判据）
- **Responsibility**:
  1. `lib_love.lua` 的 **8 处 `lib.Debug`** → 本地 `Debug`（消除循环依赖）
  2. 新增契约 `render.setDrawLoopFlag(flag)`（4 引擎），`main.lua` 改调它
  3. `async_globals` 的 Delay 补丁点从 `lib.Delay` 改到 `EngineAPI.time.sleep`
     （修活体缺陷：`_G.lib` 与 `EngineAPI` 同表 → 补丁写进契约外的键 `Delay`）
  4. `jymain.lua:51` 的 `WaitFrame` fallback → `EngineAPI.time.sleep`
  5. 删 2 处死变量（`interact.lua:185` / `settings_store.lua:45`）
  6. 删 3 个引擎的 `_G.lib = ...`
  7. 门禁 STEP I（`_G.lib` 只允许在 `tests/`）
- **前提修正**：slice 记的是「oldevent 脚本依赖 `lib.*`（约 2000 个数据文件）」。
  **实测 27808 个事件脚本（1018 基础 + 26790 MOD）零 `lib.` 引用**，
  调用面恰好是 `instruct_0..67`（67 个）→ 该前提不成立。
- **Depends On**: `port-native-api-completion`（script 已零 `lib.*`）
- **Status**: [x] Archived / Complete（port-compat-layer-removal）

### Change: port-legacy-picture-removal

- **Scope**: engine + framework（425 行旧贴图子系统 + 3 个逃生舱 + 190 行云子系统搬家）
- **Responsibility**:
  1. 删 3 个死契约 `sprite.draw` / `sprite.drawTinted` / `sprite.loadArchive`
     （**实测 0 处消费者**）
  2. dialog 头像逃逸舱改显式降级（删 2 处 `lib.PicGetXY/PicLoadCache`）
  3. 新建 `framework/cloud_layer.lua`：云解码（复用 `SpriteDecoder`）+ 烘焙 +
     60 朵漂移 + 坐标公式。**实测 cloud.grp 9 帧对拍 9/9 一致**
  4. 3 个地图绘制逃生舱改显式 `error`（不再静默回退旧实现）
  5. 删 `lib_love` 的 425 行（`LoadPic` 119 行 RLE + `PicInit/PicLoadFile/PicGetXY/
     PicLoadCache/DrawPicTinted/LoadPicture/ClearPictureCache/picFileCache`）
  6. 调色板改由 `SpriteDecoder.loadPalette` 加载
  7. 修 `clearPictureCache` 清错表（清 `lib_love.pictureCache` 而非 `_picCache`）
- **前提修正**：slice 记的是「要删 `LoadPic` 得先改旧事件脚本的调用方式」。
  **实测事件脚本零 `lib.`**；真正阻塞的是 3 个死契约 + dialog 逃逸舱 + 云子系统。
- **结果**：`lib_love.lua` **1795 → 875 行**（-920）；全量测试 4072/0；
  场景/战斗 md5 不变；新增 gate STEP J
- **Depends On**: `port-compat-layer-removal`
- **Status**: [x] Archived / Complete（port-legacy-picture-removal）

### Change: port-audio-semantics

- **Scope**: engine + script（audio 语义定案 + 1 个新契约）
- **Responsibility**:
  1. `playSequence(id)` 收窄为**只收编号**，扩展名候选 `{ogg, mid, mp3}` + `sound/`
     回落写进契约注释
  2. `playMusic(filename)` 收窄为**只收完整文件名**（不推测扩展名）
  3. 新增 `app.setMusicTemplate(template, startOffset)`（引擎不再读 `CC.*`）
  4. `CC.MIDIFile` 去扩展名；`JYMainAdapter.init` 注册模板
  5. `PlayMIDI` 的 `EnableMusic==0` 分支改调 `stopMusic()`（修活体缺陷）
  6. `playVideo` 返回真实结果（无能力/文件缺失 → `false`，不再无条件 `true`）
- **前提修正**：slice 记的是「语义需先定（filename vs 索引）」。本轮定案：
  **两个契约各管一半**，且把 `id+1` 偏移提升为 `setMusicTemplate` 的显式参数。
- **结果**：契约数 89 → 90；全量 4111/0；`gate_run_mod` GATE_PASS（20 MOD）；
  顺带修 3 个活体缺陷（关音乐不停 / playVideo 永真 / 模板带扩展名）
- **Depends On**: `port-native-api-completion`
- **Status**: [x] Archived / Complete（port-audio-semantics）

### Change: port-ui-screens-verification

- **Scope**: framework + docs（`framework/status_page.lua` + 4 张实机基线）
- **Responsibility**:
  1. 归档物品菜单 / 物品格 / 人物状态 3 张实机基线（**本轮已捕获**）
  2. 补存档界面基线（**须在主地图**：`GAME_SMAP` 下「系统」置灰是原版行为）
  3. 新建 `framework/status_page.lua`：`ShowPersonStatus_sub` 的 27 处绘制搬 framework
  4. 门禁 STEP F 白名单补 4 个 script 全局（`ShowPersonStatus_sub` 等）
  5. `docs/screenshots/README.md` 标注三类判据（逐字节/依赖存档/不稳定）
- **前提修正**：slice 记的是「`Menu_Thing` / `ShowPersonStatus` 在事件驱动下不可达」。
  **实测三个里两个可达**（物品菜单、物品格、人物状态均已截图）；
  存档不可达是**原版行为**，需在主地图验证。
- **Depends On**: 无（可独立开工；建议排在 `port-legacy-picture-removal` 之后回归基线）
- **Status**: [ ] Not Started

---

## 依赖图

```
  ┌──────────────────────────────────────┐
  │ port-contract-completeness            │
  │  契约完整化 + 修虚拟手柄接线           │
  │  237 处调用改动                        │
  └───────────────┬──────────────────────┘
                  │（必须先有完整契约）
                  ▼
  ┌──────────────────────────────────────┐
  │ port-script-decoupling                │
  │  140 处 script 全局 → facade           │
  └──────────────────────────────────────┘

  ┌──────────────────────────────────────┐
  │ port-sprite-animation                 │
  │  动画时间驱动（引擎侧零改动）          │
  └──────────────────────────────────────┘

  ┌──────────────────────────────────────┐
  │ battle-extensibility                  │
  │  战斗流程抽成可覆盖策略模块            │
  │  （支持半即时/即时/Hades 式）          │
  └──────────────────────────────────────┘
       │
       ├──▶ ┌──────────────────────────────────────┐
       │    │ port-battle-robustness               │
       │    │  WarLoad 错误码 + WAR.Person 容量      │
       │    └──────────────────────────────────────┘
       │
  ┌──────────────────────────────────────┐
  │ port-sprite-native-migration          │
  │  消除 script 层 lib.Pic* 双轨          │
  │  （为 gate 摘掉 engine-love2d 豁免）   │
  └──────────────────────────────────────┘
       ▲
       │ 无硬依赖，但建议排在上者之后（同文件冲突）
```

- change 1 **必须**先于 change 2（先有契约才能解耦）
- change 3 与 1/2 无硬依赖，但**同改 `game_states.lua`** → 建议顺序执行

### 第二批（2026-11-21 新增）的依赖

```
  ┌────────────────────────────────────────┐
  │ port-compat-layer-removal               │
  │  删 _G.lib + 1 新契约 + 修 Delay 补丁点   │
  └──────────────────┬─────────────────────┘
                     │（必须先删兼容层，否则旧贴图删除会崩）
                     ▼
  ┌────────────────────────────────────────┐
  │ port-legacy-picture-removal             │
  │  删 425 行旧贴图 + 云搬 framework        │
  └────────────────────────────────────────┘

  ┌────────────────────────────────────────┐
  │ port-audio-semantics                    │
  │  定案 playSequence/playMusic + 修开关     │
  └────────────────────────────────────────┘

  ┌────────────────────────────────────────┐
  │ port-ui-screens-verification            │
  │  4 张界面基线 + status_page 解耦          │
  └────────────────────────────────────────┘
```

- `port-legacy-picture-removal` **必须**在 `port-compat-layer-removal` 之后：
  前者要删 `lib_love` 的 425 行，而 `lib_love` 里有 8 处 `lib.Debug` 依赖 `_G.lib`
- `port-audio-semantics` / `port-ui-screens-verification` 与上面两条无硬依赖，可并行

---

## Shared Contract Stubs

以下是 change 之间的接口契约。**签名一经确定不得随意改动。**

### change 1 → change 2 的契约（facade 依赖）

```lua
-- change 2 的 render_facade 内部要调这些，所以 change 1 必须先确保它们可用
EngineAPI.render.getWidth()        --> number
EngineAPI.render.getHeight()       --> number
EngineAPI.render.text(x, y, str, color, size, fontname)
EngineAPI.render.fillRect(x1, y1, x2, y2, color)
EngineAPI.render.rectOutline(x1, y1, x2, y2, color)
EngineAPI.render.setClip(x1, y1, x2, y2)
EngineAPI.render.present()
EngineAPI.font.measureText(str, size, fontName)  --> number
EngineAPI.debug.log(...)
```

### change 1 → change 3 的契约（动画依赖）

```lua
-- change 3 的 sprite_anim 只调这一个
EngineAPI.sprite.draw(archiveId, frameId, x, y, flags, alpha)
-- frameId 是**不透明整数**，语义由引擎的 loadArchive 定义
```

> **⚠️ 已被 `port-legacy-picture-removal` 取代（2026-11-21 实测）**：
> `sprite.draw` / `sprite.loadArchive` 在 framework/script 里**零调用**
> （`port-native-api-migration` 已把 script 全迁到 `SpriteAtlas`）。
> 动画实际走 `SpriteAtlas.draw` → `sprite.drawHandle(handle, …)`。
> 上面这条 stub 仅作历史记录，**新代码不得再调 `sprite.draw`**。

### change 1 的资产解码契约（多格式核心）

```lua
-- framework 侧（纯数据，零引擎依赖）
SpriteDecoder.decodeRLE(grpBytes, offsetA, offsetB)
    --> { w=, h=, xoff=, yoff=, rgba = <w*h*4 字节，RGBA 顺序> }
SpriteDecoder.loadPalette(colBytes)          --> paletteTable
SpriteDecoder.sniffFormat(bytes)             --> "rle" | "png"   （按签名，不看扩展名）

-- 引擎侧（只做上传，不解码 RLE）
EngineAPI.sprite.createFromRGBA(w, h, rgbaBytes, opts)  --> handle
EngineAPI.sprite.createFromEncoded(bytes, formatHint)   --> handle
EngineAPI.sprite.getMeta(handle)                        --> { w, h, xoff, yoff }
```

**锚点约定**（解决实测缺陷）：

| 容器 | 格式 | `xoff` / `yoff` 来源 |
|------|------|---------------------|
| packed `<name>.idx/.grp` | RLE | 帧头 8 字节（数据自带） |
| packed 同上 | PNG | 无自带 → 约定 `w/2, h`（与同容器 RLE 的脚底中心锚定一致） |
| loose 单文件 | 任意 | 调用方显式传 `opts.xoff / opts.yoff` |

### change 3 → change 2 的冲突点

```lua
-- 两者都要改 game/framework/game_states.lua，但改不同行：
--   change 2: 16 处 Cls / DrawString / ShowScreen / lib.DrawMMap
--   change 3: 4 处 AddMyCurrentPic
```

---

## Integration Test Plan

slice 完成后如何验证端到端：

### 1. 契约完整性（静态验证）

```bash
# 零绕过
grep -rn 'lib\.' game/framework/*.lua | grep -vE ':[0-9]+:\s*--' | wc -l   # 期望 0
# 零 script 全局
grep -rhoE '\b(DrawString|Cls|ShowScreen|DrawBox|DrawStrBox|ShowMenu|WaitKey|TalkEx)\(' \
  game/framework/*.lua | wc -l                                              # 期望 0
# 保持既有的零
grep -rn 'love\.' game/framework/*.lua | grep -vE ':[0-9]+:\s*--' | wc -l  # 期望 0
grep -rn 'require("engine' game/framework/*.lua | wc -l                     # 期望 0
```

### 2. 换引擎可行性（最强验证）

构造一个"最小第三引擎" `engine_minimal/`（或复用 `engine_mud`），
它**只实现 `engine_api.lua` 声明的函数**，不提供任何 `lib.*` 回退：

```lua
_G.lib = setmetatable(EngineAPI, { __index = {} })   -- 空回退，任何绕过都会崩
```

> **⚠️ 该 stub 已过期（2026-11-21）**：`port-compat-layer-removal` 会把
> `_G.lib` 整个删掉，所以「空回退」这个构造不再需要 —— 正确验法是
> **根本不建 `_G.lib`**，直接跑 framework/script，任何 `lib.*` 引用会立刻
> `attempt to index nil`。见该 change 的 spec REQ-CLR-1。

然后在它上面跑：
- `framework/` 模块加载（无 nil 调用崩溃）
- 菜单构建与点击（`menu_state_machine`）
- 地图绘制调用链（`map_render.drawMain`）
- 动画推进（`sprite_anim.update(dt)`）

**若任何一处崩了，说明还有未契约化的绕过。**

### 3. 虚拟手柄真实激活（活体缺陷验证）

```lua
-- 注入触摸点，断言端到端
_G.EngineAPI.input._touches = { {id=1, x=<accept圆心x>, y=<accept圆心y>} }
Settings.set("input.virtualPad", true)
JYMainAdapter.pollVirtualPad()   -- 期望 true
InputManager.getActionEvent()    -- 期望 {action="ui.accept", source="touch"}
```

### 4. 动画手感对照

```bash
# 改动前后录制同一段行走，逐帧对比
# 默认 walkFps=15 时节奏应肉眼一致；不一致则校准默认值
```

### 5. 全量回归

```bash
cd game && for v in lua5.1 lua53 lua54 lua55; do
  "D:/lua/$v.exe" tests/test_runner.lua  # 期望失败 0，断言数 ≥ 3310
done
luac5.1 -p / luac55 -p 全仓零失败
LÖVE 11.5 启动冒烟
```

### 6. 门禁

```bash
gate_engine_contract.sh   # 本 slice 新增
gate_input_actions.sh     # 既有，不得回退
gate_base_music.sh        # 既有
gate_ascii.sh             # 既有
```

---

## Slice 完成判定

slice 在 **14 个** change 全部 archived 后标记 `status: done` 并移入 `archive/`。

当前进度：第一批 10 个已 Complete；第二批 4 个（`port-compat-layer-removal` /
`port-legacy-picture-removal` / `port-audio-semantics` /
`port-ui-screens-verification`）Not Started。
