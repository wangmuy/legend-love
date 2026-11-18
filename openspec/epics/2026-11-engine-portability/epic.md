---
status: active
created: 2026-11
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
  impact: []
---
# Epic: 引擎可移植性硬化（Godot / Unreal / 任意引擎）

## 愿景

让 `game/framework/` 真正成为**引擎无关层**：换上一个新的 `engine-xxx/` 实现后，
framework 与 script 不需要任何改动就能跑起来。

当前状态是「**名义上引擎无关，实际上 LÖVE 专属**」：framework 里
`love.*` 的直接调用确实是 0 处（这点做对了），但它通过**两条隐式通道**
依赖 LÖVE 实现，而这两条通道在 EngineAPI 契约之外：

```
通道 1: framework 调 lib.*  →  46 处调用落到 lib_love 的原始实现（无契约）
通道 2: framework 调 script 全局  →  140 处调用反向依赖 game/script/jymain.lua
```

接 Godot/Unreal 时，这两条通道都必须由移植者**凭猜测实现** —— 契约里没有它们的规格。

---

## 为什么需要 epic 而不是单个 change

### 规模对比（与本仓已有 change 实测对比）

| 工作项 | 调用点 | 说明 |
|--------|--------|------|
| 16 种 `lib.*` 提升为契约 | **46 处** | 每种都要新增契约函数 + 4 引擎实现 + 测试 |
| `lib.Debug/GetKey/Delay/GetTime` 改契约调用 | **191 处** | 这 4 个已有契约，只需改调用形式 |
| script 全局函数改 facade | **140 处** | 8 个全局函数，跨 24 个 framework 文件 |
| dead contract 处置 | **38 个** | 声明了但从未调用，需决策保留/删除 |
| 缺失契约补齐 | 3 个 | `render.getWidth`/`render.getHeight`/`font.measureText` |

合计需改动的调用点：**46 + 191 + 140 = 377 处**

对比已完成 change 的任务量：

```
input-action-layer    31 任务
audio-settings        88 任务
mouse-input epic      3 slices（epic 自估约 335）
```

本 epic 保守估计 **120+ 任务**，是 `audio-settings` 的 1.4 倍。
塞进单个 change 会有 epic 文档里已记录的那个后果：
**中间任何一点卡住，整个 change 无法 archive，已完成的价值被锁死。**

### 可交付价值天然分层

```
Slice 1 完成后：游戏照常跑，接新引擎时不再靠猜（无用户价值）
Slice 2 完成后：framework 不再反向依赖 script（无用户价值）
Slice 3 完成后：动画可按时间驱动、可换帧率、可加新动画（**有用户价值**）
```

这正是 vertical slice 的形态。

---

## 触发本 epic 的直接证据

**这不是"未来投资"，当前就有活体缺陷。**

`input-action-layer`（刚完成，commit `33b89bc`）引入的虚拟手柄存在接线 bug：

```lua
-- game/framework/jymain_adapter.lua pollVirtualPad（实际代码）
local okW, sw = pcall(EngineAPI.render.getWidth)    -- ← 契约里没有这个函数
local okH, sh = pcall(EngineAPI.render.getHeight)   -- ← 契约里没有这个函数
if not okW or not okH or type(sw) ~= "number" ... then
    return false                                     -- ← 永远走这里
end
```

实测确认：

```
EngineAPI.render.getWidth  = nil
EngineAPI.render.getHeight = nil
```

**虚拟手柄在真机上永远不会激活。** 逻辑层 57 条测试全绿，但接线断了 ——
因为契约不完整，我写代码时调用了一个不存在的东西。

这是「契约缺一个函数 → 实现静默失效」的最小样本。

---

## 已通过代码/实测确认的约束

以下事实来自对本仓当前代码的阅读与探测，是本 epic 的设计基础。

### 1. framework 的 `love.*` 直接调用确实是 0 处

```bash
$ grep -rn 'love\.' game/framework/*.lua | grep -v 注释行 | wc -l
0
$ grep -rn 'require("engine' game/framework/*.lua | wc -l
0
```

framework 对引擎**没有硬依赖**。问题在于隐式通道。

### 2. LÖVE 引擎靠元表回退，把契约缺口全部掩盖

```lua
-- game/engine-love2d/engine_love2d.lua:735
_G.lib = setmetatable(EngineAPI, { __index = lib })   -- ← 关键
```

`EngineAPI` 上找不到的函数，回退到 `lib_love` 的**原始实现**（1766 行）。
所以在 LÖVE 上"什么都能跑"，掩盖了 16 种函数没有契约的事实。

实测 MUD 引擎（它只提供 3 个回退：`Debug`/`GetTime`/`Delay`）：

```
lib.DrawMMap        崩溃: attempt to call field 'DrawMMap' (a nil value)
lib.PicLoadCache    崩溃: attempt to call field 'PicLoadCache' (a nil value)
lib.GetMMap         崩溃: attempt to call field 'GetMMap' (a nil value)
lib.SetClip         崩溃: attempt to call field 'SetClip' (a nil value)
lib.CloudTick       崩溃: attempt to call field 'CloudTick' (a nil value)
lib.EnableKeyRepeat 崩溃: attempt to call field 'EnableKeyRepeat' (a nil value)
```

**这就是接 Godot 时会发生的事，只是崩溃点更晚、更难查。**

### 3. 契约契约里 38 个函数是死的

```
契约声明 64 个函数
被 framework/script 实际调用: 26
从未被调用（dead contract）: 38
```

三个引擎专属子系统的存活率：

```
sprite:  5 个函数，被调用 0 个  →  0%
map:     7 个函数，被调用 0 个  →  0%
render:  7 个函数，被调用 1 个  →  14%（只有 fillRect，且是 input-action-layer 新加的）
input:  10 个函数，被调用 6 个  →  60%
file:   12 个函数，被调用 10 个 →  83%
```

**地图与精灵子系统整块是"为契约而契约"，实际绘制全走 `lib_love`。**
这说明契约的设计粒度错了：`map.drawMain(playerX, playerY, playerPic)` 一个函数
要盖住等距投影 + 裁剪 + 云动画 + 建筑遮罩 + 玩家绘制（`lib_love` 里 79 行），
粒度太粗，没有任何引擎能靠这个签名还原出相同的画面。

### 4. 层次倒置：framework 反向依赖 script

framework 调用的**游戏脚本层**全局函数：

```
DrawString    28 次      ShowScreen   11 次      ShowMenu     8 次
Cls           28 次      DrawBox       8 次      WaitKey     11 次
DrawStrBox    10 次      TalkEx        3 次      GetMyPic    13 次
                         SceneCanPass  2 次      AddMyCurrentPic 4 次
                         PlayMIDI      6 次      ……合计 140 处
```

这些函数定义在 `game/script/jymain.lua:2094-2994`。
依赖方向是 **framework → script → EngineAPI**，
而设计意图是 **framework → EngineAPI**。

接新引擎时不仅要实现 EngineAPI，还要把 `jymain.lua` 这 2000 行一起搬过去。

### 5. 三大外部引擎都**没有**可用的动画播放器 API

这是 sprite 动画设计的核心依据，实测各引擎的官方 API 形态：

| 引擎 | 动画能力 | 绑定到什么 |
|------|---------|-----------|
| LÖVE | `love.graphics.draw(quad, ...)` | Quad（自定义纹理区域） |
| Godot 4 | `AnimatedSprite2D` + `SpriteFrames` | **资产格式**（.tres 资源） |
| Unreal 5 | `PaperFlipbookComponent` + `PaperFlipbook` | **资产格式**（.uasset） |
| SDL | `blit(srcRect)` | 无动画概念 |

**Godot 与 Unreal 的动画播放器都绑死各自的资产管线**（`SpriteFrames` / `PaperFlipbook`）。
要把本项目自研的 `.idx`/`.grp` 格式喂给它们，需要做**资产格式转换**，
那不是 API 适配，是数据迁移 + 工具链建设，工作量远大于本 epic。

三者的**唯一公共子集**是：

```
"给定 archiveId 和一个不透明整数帧号，把这一帧画在 (x, y)"
```

LÖVE 用 `quad` 实现、Godot 用 `Sprite2D.set_frame(N)`、Unreal 用 `SetSpriteIndex(N)`、
SDL 用 `blit(archive[N])`，**四种实现都能满足同一个签名**。

### 6. 现有帧号语义就是「不透明整数绝对索引」

```lua
-- game/script/jymain.lua:624 GetMyPic
function GetMyPic()
    if JY.Base["乘船"] == 0 then
        n = CC.MyStartPic + JY.Base["人方向"] * 7 + JY.MyCurrentPic
    else
        n = CC.BoatStartPic + JY.Base["人方向"] * 4 + JY.MyCurrentPic
    end
    return n
end
-- game/script/jymain.lua:645
function AddMyCurrentPic() JY.MyCurrentPic = JY.MyCurrentPic + 1 end
```

帧的"身份"是 archive 里的**绝对编号**（`MyStartPic + 方向*7 + 帧号`），
不是 `(row, col)` 坐标。这与 Godot/Unreal 的"区域性子索引"模型不同，
但**恰好是最容易跨引擎对齐的形态** —— 引擎只需保证 `loadArchive` 建立的
索引映射一致，动画层完全不关心内部布局。

### 7. 动画当前**不是时间驱动**，而是"走一格加一帧"

```lua
-- game/framework/game_states.lua:248, 300, 457, 790（4 处）
AddMyCurrentPic()      -- 每移动一格调用一次
```

帧率与移动速度**绑死**：改移速动画就变速；不移动时动画完全静止（连待机摆动都没有）。

`dt` 已经在 `love.update` → `EventBridge:update(dt)` → `StateMachine:update(dt)`
这条链上传到位，但**没有任何代码用它驱动动画**。

### 8. 缺失契约是"框架在用、契约没写"

```lua
-- game/framework/jymain_adapter.lua:589  （我写的虚拟手柄接线）
EngineAPI.render.getWidth      -- 契约未声明、实现未提供
EngineAPI.render.getHeight     -- 同上

-- game/framework/text_box_layout.lua:77  （有防御性 fallback）
if engineAPI.font.measureText then ... end   -- 契约未声明，永远走 em 估算
```

`text_box_layout` 有 fallback 所以不崩，但**在 Godot 上用非等宽字体时必然偏差**
（`emWidth` 假设汉字精确 1em，这在 simsun 上实测成立，在其它字体上不成立）。

### 9. 音频走两条完全不同的路径

```
framework 里 lib.PlayMIDI(...)   1 处  →  引擎序号（PlayMIDI(0)、PlayMIDI(16)）
framework 里 PlayMIDI(...)       6 处  →  同上的全局版本
framework 里 lib.PlayMPEG(...)   1 处  →  带中断键 PlayMPEG(path, VK_ESCAPE)

契约里 audio.playMusic(filename)      →  按**文件名**播放
```

契约概念（文件名）与实际用法（索引号 + 中断键 + MPEG 视频）完全不匹配，
所以 framework 绕开它直接用 `lib`。这部分归入 TODO 后续处理。

---

## 产物结构（Epic → Slice → Change）

本 epic 遵循项目的三级层次。**Slice 本身只是规划容器**，
实际实施落在每 slice 下的子 change：

```
openspec/
├── epics/2026-11-engine-portability/
│   ├── epic.md               ← 本文件（愿景 + slice 分解）
│   └── TODO.md               ← 后续缺口清单
│
└── changes/
    ├── port-slice1-contract-completeness/     ← Slice 1（规划）
    │   ├── .openspec.yaml      schema: vertical-slice
    │   ├── slice-proposal.md   为什么 / 范围 / Requirements
    │   └── change-manifest.md  子 change 清单 + 依赖
    │
    ├── port-contract-completeness/            ← Slice 1 的子 change（实施）
    │   └── (proposal/design/specs/tasks)
    │
    ├── port-slice2-script-decoupling/         ← Slice 2（规划）
    ├── port-script-decoupling/                ← Slice 2 的子 change
    ├── port-slice3-sprite-animation/          ← Slice 3（规划）
    └── port-sprite-animation/                 ← Slice 3 的子 change
```

每个 slice 只有一个子 change，因此 slice 目录里只有 3 个规划文件，
实施工作全在子 change 里（与既有 `mouse-slice1` 的组织方式一致）。

---

## Vertical Slices

### Slice 1: `port-slice1-contract-completeness`（Infrastructure）

**业务价值**：无（纯设施）。让 framework 的全部引擎调用都有契约可依。

**为什么必须独立成 slice**：它触及 4 个引擎实现的同步扩展（LÖVE/MUD/Web/测试桩），
一旦某个实现有问题，功能 slice 也无法验收。且 **Slice 2 是它的下游** ——
没有契约就先谈解耦是空转。

**Acceptance Criteria (DoD)**

```
1. 16 种 lib.* 绕过全部消除：framework 里 lib.XXX( 形式的调用只剩
   Debug/GetKey/Delay/GetTime 这 4 种（它们已有契约，需同时改为 EngineAPI 调用）
2. 验收断言：grep framework/ 里 'lib\.' 命中数 = 0
3. 补齐 3 个缺失契约：render.getWidth / render.getHeight / font.measureText
4. 修复虚拟手柄接线 bug：pollVirtualPad 在 LÖVE 下真实能激活
   （用注入式触摸点做端到端测试，不依赖真实触摸设备）
5. 38 个 dead contract 逐个决策并记录（保留并加说明 | 删除）
6. 4 引擎（LOVE/MUD/Web/测试桩）契约函数实现齐全
7. 引擎契约一致性测试：同一套断言在 MUD 与 Web 上真实执行（不是"能加载"）
8. 文档同步：AGENTS.md 的「59 个函数」计数修正（实际 64，本 slice 后更多）
9. Lua 5.1/5.3/5.4/5.5 全量测试全绿
10. luac5.1 -p 与 luac5.5 -p 全仓零失败
```

**Affected Domains**：`game/engine-love2d/`、`game/engine-mud/`、
`game/engine-web/`、`game/framework/`（24 个文件）、`game/tests/`

**Implementation Changes**：
- `engine_api.lua` 新增约 19 个契约函数（16 个 lib.* 提升 + 3 个缺失）
- 4 个引擎实现同步补齐
- framework 里 191 处 `lib.Debug/GetKey/Delay/GetTime` 改为 `EngineAPI.*`
- framework 里 46 处 `lib.*` 改为新契约函数
- 新建 `game/tests/unit/test_engine_conformance.lua`（跨引擎行为断言）

**Status**：`pending`

---

### Slice 2: `port-slice2-script-decoupling`（Infrastructure）

**业务价值**：无（纯设施）。让依赖方向回到设计意图：**framework → EngineAPI**。

**依赖 Slice 1**：先有完整契约，才可能把 140 处全局调用改写到契约上。

**Acceptance Criteria (DoD)**

```
1. framework 里调用 script 全局函数的命中数 = 0
   （DrawString/Cls/ShowScreen/DrawBox/DrawStrBox/ShowMenu/WaitKey/TalkEx
     等 8 个函数，共 140 处调用点全部消除）
2. 新建 framework/render_facade.lua：把 DrawString/DrawBox/Cls/ShowScreen
   封装为 facade，内部只调 EngineAPI.render
3. DrawStrBox / DrawStrBoxYesNo / DrawStrBoxWaitKey 三个语义函数
   也由 facade 提供（内部用 EngineAPI.dialog + EngineAPI.render）
4. ShowMenu / ShowMenu2 / WaitKey / TalkEx → 改为通过既有 framework 模块
   （menu_async / input_async / talk_async）调用，不再走 script 全局
5. game/script/jymain.lua 的同名全局函数**保留**（游戏脚本仍要用），
   但改为 facade 的薄包装（保证 script 层行为零变化）
6. 全部既有测试零回归（这是最大风险点：140 处改动）
7. Lua 四版本全量测试全绿
```

**Affected Domains**：`game/framework/`（24 个文件）、
`game/script/jymain.lua`（只加薄包装）、`game/tests/`

**Implementation Changes**：
- 新建 `framework/render_facade.lua`
- framework 里 140 处全局调用改为 facade
- `jymain.lua` 的 8 个全局函数改为 facade 包装

**Status**：`pending`

---

### Slice 3: `port-slice3-sprite-animation`（Feature）

**业务价值**：**动画可按时间驱动** —— 行走动画不再与移动速度绑死，
待机时可以播摆动，新动画（战斗特效、场景动画）可以按需添加。

**可与 Slice 1 / 2 并行**（只依赖既有 `sprite.draw` 契约）。

**核心设计（回答"什么设计更适配多引擎"）**

三大引擎的动画播放器都绑死各自资产格式（约束 5），所以 framework
**不能**依赖任何引擎的动画播放器。正确形态是：

```
framework/sprite_anim.lua      纯逻辑：帧序列定义 + 时间推进 + 播放状态机
        │
        │  只调一个契约函数
        ▼
EngineAPI.sprite.draw(archiveId, frameId, x, y, flags, alpha)   ← 已存在
```

**关键决策：帧号是「不透明整数」，语义由引擎的 `loadArchive` 定义。**

- LÖVE：`frameId` = `.grp` 里的绝对索引（现有实现）
- Godot：`frameId` = 该引擎 `loadArchive` 建立的索引映射（可能是 `hframes/vframes` 组合）
- Unreal：`frameId` = `PaperSprite` 在 atlas 内的序号
- SDL：`frameId` = 纹理数组下标

**framework 永远不解释 frameId 的内部含义**，只把它当作不透明句柄传递。
这样任何引擎都能实现，且换引擎时动画逻辑零改动。

**Acceptance Criteria (DoD)**

```
1. 新建 framework/sprite_anim.lua（**零引擎依赖**，可纯算法单测）：
   - defineSequence(id, {archive=, frames={}, fps=, loop=})  帧序列定义
   - play(handle, id, opts)      开始播放
   - update(dt)                  时间推进（唯一的时间源）
   - stop(handle) / isPlaying(handle) / getCurrentFrame(handle)
   - 播放模式：loop（循环）/ once（单次）/ pingpong（往复）
   - onComplete 回调（once 播完触发）
2. sprite_anim.lua 零引擎依赖验证：grep 该文件 'EngineAPI' 只在 draw 调用处
3. 主角行走动画改为时间驱动：
   - 新增 sprite_anim 序列定义（替代 GetMyPic 的手算）
   - 行走帧率可配置（Settings: `animation.walkFps`，默认 15）
   - **保持现有手感**：默认参数下行走节奏与改动前肉眼一致
4. 站立待机不再静止（可选，可配置关闭）：默认关闭以零回归
5. 战斗特效 / instruct_27 动画可复用同一模块（提供 API，不改既有逻辑）
6. 引擎侧**不需要**新增动画相关函数（sprite.draw 已足够）
7. 全部既有测试零回归
8. Lua 四版本全量测试全绿
```

**Affected Domains**：`game/framework/sprite_anim.lua`（新）、
`game/framework/game_states.lua`、`game/script/jymain.lua`（GetMyPic 改为读序列）、
`game/tests/`

**Implementation Changes**：
- 新建 `framework/sprite_anim.lua`
- 新建 `framework/animation_defs.lua`（本游戏的帧序列定义，游戏层可覆盖）
- `game_states.lua` 的 4 处 `AddMyCurrentPic()` 改为 `sprite_anim.update(dt)`
- `jymain.lua` 的 `GetMyPic` 改为查询 sprite_anim 当前帧

**Status**：`pending`

---

## Slice Dependency Graph

```
              ┌──────────────────────────────────┐
              │ slice 1: contract-completeness    │
              │  16 种 lib.* 契约化 + 补 3 个缺失  │
              │  + 修虚拟手柄接线 bug             │
              └───────────────┬──────────────────┘
                              │
                              ▼
              ┌──────────────────────────────────┐
              │ slice 2: script-decoupling        │
              │  140 处全局调用 → render_facade    │
              └──────────────────────────────────┘

              ┌──────────────────────────────────┐
              │ slice 3: sprite-animation         │
              │  （只依赖既有 sprite.draw 契约）   │
              └──────────────────────────────────┘
                              ▲
                              │
                    可与 1/2 并行（无依赖）
```

- Slice 1 **必须**先于 Slice 2（先有契约才能解耦）
- Slice 3 与 1/2 **互不依赖**，可并行

---

## Global Acceptance Criteria（Epic 级 DoD）

```
1. 三个 slice 的 DoD 各自通过
2. framework 里 lib.* 绕过契约的调用 = 0
3. framework 里调用 script 全局函数的次数 = 0
4. framework 里直接调 love.* 的次数 = 0（现状已达成，需保持）
5. framework 里 require("engine-*") 的次数 = 0（现状已达成，需保持）
6. 引擎契约一致性测试在 MUD 与 Web 上真实执行并通过
7. 虚拟手柄在 LÖVE 下真实激活（端到端可验证，用注入触摸点）
8. 全部既有测试零回归（基线 3309 断言）
9. Lua 5.1 / 5.3 / 5.4 / 5.5 全量测试全绿（每版记录断言数）
10. luac5.1 -p 与 luac5.5 -p 全仓零失败
11. LÖVE 11.5 启动冒烟无报错
12. 文档同步：AGENTS.md / ENGINE_API_DESIGN.md / SRC_FILES.md 的
    EngineAPI 计数与实际一致
```

---

## 风险与缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| Slice 2 改 140 处调用点 | 大面积回归 | 按文件分批改，每批跑全量测试；每批一个 commit 便于 bisect |
| `render_facade` 引入额外间接层 | 绘制性能下降 | facade 是纯转发，无逻辑；LÖVE 上实测绘制耗时对比 |
| 16 种 lib.* 的契约签名设计不当 | 延用错误粒度（如 map 的 79 行塞一个函数） | 每个函数先写契约注释与「为什么是这个粒度」，再改实现 |
| sprite 动画改变行走手感 | 用户感知回归 | 默认参数校准到与改动前肉眼一致；`animation.walkFps` 可配可关 |
| 38 个 dead contract 处置不当 | 删了以后又要加回来 | 全部先「保留 + 注释说明消费者为何缺位」，只删明确无意义的 |
| 4 引擎同步扩展遗漏 | 某引擎下静默失效 | 契约一致性测试强制跑全部 4 个实现 |

---

## 明确不做（Out of Scope）

```
✗ resize 事件处理      —— 记入 TODO.md
✗ IME 中文输入         —— 记入 TODO.md（需真机验证，且当前无输入框消费方）
✗ audio 概念重设计     —— 记入 TODO.md（playMusic(filename) vs PlayMIDI(索引) 需先定语义）
✗ 旋转/缩放/变换矩阵   —— 当前无消费方
✗ circle/line/polygon 绘制原语 —— 当前无消费方
✗ 资产格式转换工具链   —— .grp → Godot SpriteFrames / Unreal Flipbook 是独立工程
✗ 实际移植到 Godot/Unreal —— 本 epic 只消除"契约缺口"，不写新引擎实现
✗ 触摸/手柄的进一步扩展 —— 归 input-action-layer 后续
✗ localStorage/存档格式迁移 —— 与引擎无关，不受影响
```
