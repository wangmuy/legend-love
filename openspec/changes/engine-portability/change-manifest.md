---
status: active
parent_epic: null
---
# Change Manifest: engine-portability — 引擎可移植性硬化

> 本 slice 统辖 3 个子 change，均位于 `openspec/changes/` 下与 slice 同级
> （符合本仓既有 `mouse-slice1` 的组织方式）。

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
- **Status**: [ ] Created

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
- **Status**: [ ] Created

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

---

## Shared Contract Stubs

以下是三个 change 之间的接口契约。**签名一经确定不得随意改动。**

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

slice 在 3 个 change 全部 archived 后标记 `status: done` 并移入 `archive/`。
