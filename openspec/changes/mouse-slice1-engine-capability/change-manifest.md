---
status: active
parent_epic: 2026-11-mouse-input
---
# Change Manifest: mouse-slice1-engine-capability — 鼠标设施层

> 本 slice 只有一个子 change。它不直接产生用户价值，但为 slice 2 / slice 3
> 提供引擎无关的基础能力。

## Change Assignments

### Change: engine-capability

> 位于 `openspec/changes/engine-capability/`（与 slice 目录同级，符合既有 slice0 的组织方式）

- **Repository**: this repo
- **Scope**: fullstack（engine 三实现 + framework 扩展 + 单元测试 + 文档同步）
- **Responsibility**:
  1. 新增 `EngineAPI.system` 模块（第 15 个）与三引擎实现：
     `getOS()` → `"Windows"|"Linux"|"macOS"|"Android"|"iOS"|"web"|"unknown"`
  2. `EngineAPI.input` 加 `mousePosition()`（**逻辑坐标**）与 `mouseButton(button)`
  3. `EngineAPI.sprite` 加 `drawTinted(archiveId, spriteId, x, y, color, alpha)`，
     `color = {r,g,b}`（0-1 浮点）；love2d 真实染色，mud/web 记录
  4. `framework/settings.lua` 新增第四层 `platform`：
     `user > mod > platform > default`；`Settings.setPlatform(name)` 注入式；
     `define` 支持 `platformDefaults = { Windows = true, Android = false }`
  5. `framework/input_manager.lua` 新增鼠标事件独立队列
     （`enqueueMouseEvent` / `getMouseEvent`），键盘队列零改动
  6. DPI 契约写入 `engine_api.lua` 注释；
     Windows 150% 已实测 1:1，macOS/Android 记为待验证
  7. 文档同步：`SRC_FILES.md` / `AGENTS.md` / `ENGINE_API_DESIGN.md`
     的计数 51 函数/14 模块 → 55 函数/15 模块
  8. 单元测试：`test_engine_api`（新接口）、`test_settings`（platform 层）、
     `test_input_manager`（鼠标队列隔离）、`test_sprite_tinted`
- **Depends On**: none
- **Status**: [ ] Pending

---

## 依赖图

```
（无前置依赖，但复用以下既有设施）
  framework/settings.lua      ← audio-settings 引入
  framework/input_manager.lua ← 既有键盘队列
  framework/fs_compat.lua     ← 既有（本 slice 不直接用）
```

## 后续 slice 依赖本 slice 的具体契约

slice 2 / slice 3 会用到以下接口，**签名一经确定不得随意改动**：

```lua
-- slice 2 用
EngineAPI.input.mousePosition()        --> x, y       逻辑坐标
EngineAPI.input.mouseButton(button)    --> boolean    1=左 2=右
EngineAPI.system.getOS()               --> string
Settings.get("input.mouse")            --> boolean
Settings.setPlatform(name)             -- 宿主注入
enqueueMouseEvent({type="pressed", x=, y=, button=})
getMouseEvent()                        --> event|nil

-- slice 3 用
EngineAPI.sprite.drawTinted(archiveId, spriteId, x, y, color, alpha)
                                       -- color = {r,g,b} 0-1 浮点
EngineAPI.input.mousePosition()        --> x, y       逻辑坐标
```

## Slice 级验收

见 `slice-proposal.md` 的 Requirements（REQ-MS1-1 ~ REQ-MS1-6），
以及 `engine-capability/tasks.md` 的 DoD。
