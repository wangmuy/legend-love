---
status: active
parent_epic: null
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Slice Proposal: 引擎可移植性硬化

## Fit-Level Context

本 slice 经评估为 **vertical-slice（可测试的 MVP）**，不升 epic、不降为单 change。

判断依据（对比本仓既有产物）：

```
本仓 54 个 change 直接挂在 changes/ 下，只有 2 个挂在 epic 下
既有 epic 规模：allmods 17 个 slice、web-mud 6 个 slice、mouse 3 个 slice
本 slice：1 个 slice 统 14 个 change（第一批 10 已完成 + 第二批 4 个）
```

第一批子 change 合计 **约 377 处调用点改动**（超过 `audio-settings` 的 88 任务），
所以不能塞进单个 change；但它们**同属一条技术主线**（消除 framework 对
LÖVE 的隐式依赖），所以需要一层统辖，而不是各自为政的 change。

第二批 4 项是收尾实测后拉回的遗留（前提全部被推翻或改写），
体量小于第一批，但共同点是「都是**隐式回退/未验证**，会让 slice DoD 靠运气成立」。

> 若执行过程中范围显著扩张（例如决定实际移植 Godot），
> 应重新评估升为 epic（`/mvp:evaluate-scale`）。

## Parent Epic

Standalone vertical slice。

引擎可移植性硬化目前是一个有明确终点的工程：
契约补齐 → 解耦 → 动画 → **清旧账（第二批 4 项）**。
前 10 个 change 完成后，framework 即达到「换引擎只需写 `engine-xxx/`」的目标；
第二批（`port-compat-layer-removal` / `port-legacy-picture-removal` /
`port-audio-semantics` / `port-ui-screens-verification`）清掉收尾留下的
隐式回退与未验证界面，使该目标**可被机器验证**（`_G.lib` 不存在时脚本不崩）。
若将来出现第三批缺口（resize / IME），届时再考虑升 epic
（见 `openspec/project/TODO.md`）。

## Slice Type

**Infrastructure**（含一个用户价值 change）

严格说这是 Infrastructure slice：前两个子 change 无用户价值（纯设施），
第三个（sprite 动画）有用户价值。整个 slice 的价值是
「**换引擎时不需要移植整个游戏**」。

## User Story

> **The system can swap its rendering/input/map backend without touching
> `game/framework/` or `game/script/`.**

用户视角的次要收益（第三个子 change 带来）：
玩家看到行走动画不再与移动速度绑死，改移速不会让动画变速。

## In Scope

### 1. 消除 framework 对 LÖVE 实现的隐式依赖

```
通道 1: framework 调 lib.*  →  46 处调用落到 lib_love（16 种函数无契约）
通道 2: framework 调 script 全局  →  140 处调用反向依赖 jymain.lua
```

两条通道全部消除，改为通过 EngineAPI 契约与 framework facade。

### 2. 补齐缺失契约（含修复一个活体缺陷）

- `render.getWidth` / `render.getHeight` / `font.measureText` 三个契约缺失
- **虚拟手柄接线 bug**：`pollVirtualPad` 依赖不存在的 `render.getWidth`，
  实测 `EngineAPI.render.getWidth = nil` → 函数永远 `return false`
  → **虚拟手柄在真机上永远不会激活**（而它 57 条测试全绿）

### 3. 38 个 dead contract 决策留痕

```
契约声明 64 个，被实际调用 26 个，从未调用 38 个（59%）
sprite 子系统 5 函数 0 调用（0%）   map 子系统 7 函数 0 调用（0%）
```

根因是粒度错：`map.drawMain(px, py, pic)` 一个签名要盖住 `lib_love` 里 79 行。

### 4. sprite 动画按时间驱动

当前"动画"全部实现是一个整数自增（`AddMyCurrentPic`），且由
"走一格加一帧"驱动 —— 帧率与移速绑死，不移动时完全静止。

## Out of Scope

```
✗ resize 事件处理      → openspec/project/TODO.md
✗ IME 中文输入         → openspec/project/TODO.md（需真机验证）
✗ 绘制原语扩展（circle/line/polygon/旋转/缩放）→ TODO.md（无消费方）
✗ 资产格式转换（.grp → SpriteFrames/Flipbook）→ 独立 epic
✗ 实际写 Godot/Unreal 引擎实现 → 本 slice 只消除契约缺口，不写新引擎
✗ 战斗系统的玩法改造 → 归 `battle-extensibility`（本 slice 第 4 个子 change）
✗ 触摸/手柄的进一步扩展 → 归 input-action-layer 后续
✗ 存档格式迁移 → 与引擎无关，不受影响
```

### 曾明确排除、2026-11-21 实测后被拉回 slice 的 4 项

原 slice 把下面 4 项排除在外，理由是「前置不存在 / 范围太大 / 语义未定」。
本轮逐项实测后，**前提全部修正**，各自独立成 change（第二批）：

| 原排除项 | 原理由 | 实测结论 |
|---------|-------|---------|
| `lib.*` 兼容层本身 | 「oldevent 脚本依赖它（约 2000 个数据文件）」 | **27808 个事件脚本零 `lib.`**；调用面只有 `instruct_0..67` → `port-compat-layer-removal` |
| `lib_love.LoadPic` 119 行 | 「要删得先改旧事件脚本的调用方式」 | 事件脚本无需改；阻塞的是 3 个死契约 + dialog 逃逸舱 + 云子系统 → `port-legacy-picture-removal` |
| audio 概念重设计 | 「`playMusic(filename)` vs `PlayMIDI(索引)` 语义需先定」 | 已定案：两个契约各管一半 + `app.setMusicTemplate` 显式注册 `id+1` 偏移 → `port-audio-semantics` |
| 物品栏 / 人物状态 / 存档界面 | 「`Menu_Thing` / `ShowPersonStatus` 在事件驱动下不可达」 | **物品菜单/物品格/人物状态三个都已实机捕获**；存档只在 `GAME_SMAP` 不可达（原版行为）→ `port-ui-screens-verification` |

> 这 4 项的共同点：原陈述都是**未实测的推断**。本轮每条都做了可复现的
> 扫描或实机截图，结论写进各 change 的 proposal / design。


## Acceptance Criteria

### 整体 DoD（slice 级）

#### Scenario: framework 里零引擎绕过

- **GIVEN** 14 个 change 全部完成
- **WHEN** 执行 `grep -rn 'lib\.' game/framework/*.lua`（排除注释行）
- **THEN** 命中数 = 0

#### Scenario: framework 里零 script 全局依赖

- **WHEN** 检查 framework 对 `DrawString`/`Cls`/`ShowMenu`/`WaitKey` 等
  8 个 script 全局的调用
- **THEN** 命中数 = 0

#### Scenario: 保持既有的两条"零"

- **WHEN** 检查 `love.*` 直接调用与 `require("engine-*")`
- **THEN** 两者命中数都是 0（现状已达成，不得回退）

#### Scenario: 换引擎只需写 engine-xxx

- **GIVEN** 全部完成后，有人照 `engine_mud.lua` 写一个新的 `engine_godot.lua`
- **WHEN** 他实现 `engine_api.lua` 声明的全部函数
- **THEN** `game/framework/` 与 `game/script/` 不需要任何改动即可跑

### 子 change DoD

每个子 change 的 DoD 见其 `tasks.md`：

```
port-contract-completeness   14 Task 组 / 87 checkbox   契约完整化 + 解码搬家 + 多格式 + 修虚拟手柄（✓ Complete）
port-script-decoupling       7 Task 组 / 49 checkbox    绘制/流程/游戏逻辑解耦（✓ Complete）
port-sprite-animation        7 Task 组 / 38 checkbox    sprite 动画时间驱动（✓ Complete）
battle-extensibility         8 Task 组 / 74 checkbox    战斗流程抽成可覆盖策略模块（✓ Complete）
port-sprite-native-migration 7 Task 组 / 57 checkbox    SpriteAtlas PNG 修复 + script 层零 lib.Pic*（✓ Complete）
port-battle-robustness       5 Task 组 / 41 checkbox    WarLoad 错误码 + WAR.Person 容量（✓ Complete）
port-contract-pruning        5 Task 组 / 24 checkbox    删除 3 个无用契约（79→76）（✓ Complete）
port-blocking-delay          4 Task 组 / 42 checkbox    waitForTime 真等待 + 阻塞消除（批 1 + 批 2 均 ✓）
port-map-render-native       7 Task 组 / 74 checkbox    map 绘制契约透明化（✓ Complete）
port-native-api-completion   5 Task 组 / 45 checkbox    **196 处** lib.* → EngineAPI（✓ Complete）
                                                       实测只剩 1 处（WaitFrame fallback）
                                                       早期估的 225/258 含 oldevent 重复统计

── 第二批（2026-11-21 实测后新增，全部 Not Started）────────────────
port-compat-layer-removal    7 Task 组                删 _G.lib + 1 新契约 + 修 Delay 补丁点
port-legacy-picture-removal  8 Task 组                删 425 行旧贴图 + 云搬 framework
port-audio-semantics         7 Task 组                定案 playSequence/playMusic + 修开关
port-ui-screens-verification 6 Task 组                4 张界面基线 + status_page 解耦
```

> **注**：第二批 4 项的前提均由 2026-11-21 实测**推翻或改写**，
> 详见 `change-manifest.md` 的「第二批」小节与各 change 的 proposal。


## Affected Domains

按 `openspec/project/architecture.md` 的有界上下文：

| 领域 | 是否触及 | 说明 |
|------|---------|------|
| engine-render | **是** | 补 `getWidth`/`getHeight`，改 14 处调用 |
| engine-sprite | **是** | 16 处调用改契约；动画模块属此域 |
| engine-map | **是** | 16 处调用改契约；新增 `map_render.lua`（framework 侧等距投影） |
| engine-input | **是** | `enableKeyRepeat` 契约化；虚拟手柄接线修复 |
| engine-audio | **是** | `playSequence`/`playVideo` 契约化（2 处） |
| engine-font | **是** | 补 `measureText` 契约 |
| engine-color / engine-file / engine-debug | **是**（轻） | `debug.log` 191 处改写；file/color 无改动 |
| game-scripts | **是** | `jymain.lua` 的 8 个全局函数改 facade 薄包装 |
| async-* 全部 | **是** | framework 24 个文件的调用改写 |
| testing | **是** | 新增 `test_engine_conformance.lua` + 门禁 |
| devops | **否** | 不涉及构建 |

## 关键约束（来自代码与实测，是本 slice 的设计基础）

### 1. framework 的 `love.*` 直接调用确实是 0 处

```bash
$ grep -rn 'love\.' game/framework/*.lua | grep -v 注释行 | wc -l
0
$ grep -rn 'require("engine' game/framework/*.lua | wc -l
0
```

问题在隐式通道，不在直接调用。

### 2. LÖVE 引擎用元表回退掩盖了全部契约缺口

```lua
-- game/engine-love2d/engine_love2d.lua:735
_G.lib = setmetatable(EngineAPI, { __index = lib })   -- 回退到 lib_love 的 1766 行
```

### 3. MUD 引擎上这些调用直接崩溃（实测）

```
lib.DrawMMap        → attempt to call field 'DrawMMap' (a nil value)
lib.PicLoadCache    → 同上
lib.GetMMap         → 同上
lib.SetClip         → 同上
lib.CloudTick       → 同上
lib.EnableKeyRepeat → 同上
```

### 4. 三大外部引擎都**没有**可用的动画播放器 API

| 引擎 | 动画能力 | 绑定到什么 |
|------|---------|-----------|
| LÖVE | `love.graphics.draw(quad)` | 纹理区域（无资产格式） |
| Godot 4 | `AnimatedSprite2D` + `SpriteFrames` | **`.tres` 资产** |
| Unreal 5 | `PaperFlipbookComponent` | **`.uasset` 资产** |
| SDL2 | `SDL_RenderCopy(srcRect)` | 无动画概念 |

Godot/Unreal 的动画播放器**都绑死各自资产管线**。
唯一公共子集是「给定 archiveId + 不透明整数帧号，画在 (x,y)」。

**所以动画播放器必须住在 framework，不能借引擎的**
（否则陷入「Godot 有 SpriteFrames、Unreal 有 Flipbook、SDL 什么都没有」的三方分裂）。

### 5. 等距投影该由 framework 负责，不该留给引擎

`lib_love.lua:1054` 的 `DrawMMap` 79 行拆解：

| 逻辑 | 性质 | 归属 |
|------|------|------|
| 等距投影 `screenX = XScale*(i-j) + W/2` | 纯数学 | **framework** |
| 视野裁剪 | 纯数学 | **framework** |
| 建筑遮罩排序 | 纯数学 | **framework** |
| 云层动画位置 | 游戏逻辑 | **framework** |
| 精灵纹理采样 | 引擎特性 | 引擎 |

79 行里只有"采样一个精灵画到屏幕"是引擎特性。
现有 `map.drawMain(px, py, pic)` 契约粒度太粗，是它成为 dead contract 的根因。

## 为什么第一批拆成 3 个 change（而不是 1 个）

```
契约补齐   46 + 191 = 237 处调用改动
script 解耦          140 处调用改动
sprite 动画          约 12 处 + 新模块
                    ─────────────────────
合计                377 处
```

对比已完成 change：`input-action-layer` 31 任务、`audio-settings` 88 任务。
单 change 塞 377 处调用会重演 epic 文档已记录的风险：
「中间任何一点卡住，整个 change 无法 archive，已完成价值被锁死」。

第一批三个 change 的价值递进：

```
change 1 完成 → 游戏照常跑，接新引擎不再靠猜（无用户价值）
change 2 完成 → framework 不再反向依赖 script（无用户价值）
change 3 完成 → 动画可按时间驱动、可换帧率（**有用户价值**）
```

## 为什么第二批再拆 4 个 change

第一批完成后，DoD 的 4 条「零」靠 3 个**未实测的推断**撑着：

```
「事件脚本依赖 lib.*」        → 实测 27808 个脚本零 lib.*
「LoadPic 删不掉」            → 实测 3 个死契约 + 逃逸舱 + 云是真正阻塞
「audio 语义需先定」          → 已定案（两契约 + 模板注册）
「三个界面不可达」            → 实测 3 个里 2 个可达（已截图）
```

所以第二批的目标不是加功能，而是**把 DoD 从「推断成立」变成「机器可验证」**：

```
port-compat-layer-removal → 删 _G.lib，脚本不再靠回退兜底
port-legacy-picture-removal → 删 425 行旧贴图，引擎真的只剩 2 个上传契约
port-audio-semantics → 契约描述与实践一致（不再靠引擎猜）
port-ui-screens-verification → 未验证界面变成有基线
```
