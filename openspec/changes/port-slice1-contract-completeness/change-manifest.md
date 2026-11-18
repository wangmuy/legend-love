---
status: active
parent_epic: 2026-11-engine-portability
---
# Change Manifest: port-slice1-contract-completeness — 契约完整性

> 本 slice 只有一个子 change，位于 `openspec/changes/port-contract-completeness/`
> （与 slice 目录同级，符合既有 `mouse-slice1` 的组织方式）。

## Change Assignments

### Change: port-contract-completeness

- **Repository**: this repo
- **Scope**: fullstack（4 引擎实现 + 契约定义 + framework 调用改写 + 跨引擎测试 + 文档）
- **Responsibility**:
  1. **16 种 `lib.*` 提升为契约**（ADR-PORT-001，粒度逐个论证）：
     - 地图：`GetMMap` / `DrawMMap` / `DrawSMap` / `UnloadMMap` / `CloudTick`
     - 精灵：`PicInit` / `PicLoadFile` / `PicLoadCache` / `LoadPicture`
     - 渲染：`SetClip` / `ShowSlow` / `FillColor` / `DrawRect`
     - 音频：`PlayMIDI` / `PlayMPEG`
     - 输入：`EnableKeyRepeat`
  2. **补齐 3 个缺失契约**：`render.getWidth` / `render.getHeight` / `font.measureText`
  3. **191 处 `lib.Debug/GetKey/Delay/GetTime` → `EngineAPI.*`**
  4. **46 处 `lib.*` → 新契约函数**
  5. **修虚拟手柄接线 bug**（`pollVirtualPad` 的 `render.getWidth` 依赖）
  6. **38 个 dead contract 决策**（`decisions.md`，逐项留痕）
  7. **4 引擎实现同步补齐**（LOVE/MUD/Web/测试桩）
  8. **新建 `test_engine_conformance.lua`**（行为断言，MUD/Web 上真实执行）
  9. **文档同步**：AGENTS.md / ENGINE_API_DESIGN.md / SRC_FILES.md 的计数
- **Depends On**: —
- **Status**: [ ] Pending

---

## 依赖图

```
（无前置依赖，但复用以下既有设施）
  EngineAPI 契约框架（engine_api.lua，64 函数）
  4 个引擎实现（LOVE/MUD/Web/测试桩）
  framework 的 input-action-layer（viurtual_pad 待修）
  基座测试：3310 断言
```

## 下游 slice 依赖本 slice 的具体契约

slice 2 / slice 3 会用到以下接口，**签名一经确定不得随意改动**：

```lua
-- slice 2（script 解耦）用：render facade 要调这些
EngineAPI.render.getWidth()          --> number
EngineAPI.render.getHeight()         --> number
EngineAPI.render.text(...)           --> 已存在
EngineAPI.render.fillRect(...)       --> 已存在
EngineAPI.render.rectOutline(...)    --> 已存在
EngineAPI.render.setClip(...)        --> 已存在（本 slice 确认）
EngineAPI.render.present()           --> 已存在
EngineAPI.font.measureText(str, size, fontName)  --> number
EngineAPI.debug.log(...)             --> 已存在

-- slice 3（sprite 动画）用
EngineAPI.sprite.draw(archiveId, frameId, x, y, flags, alpha)  --> 已存在
EngineAPI.sprite.getSize(archiveId, frameId)                  --> 已存在
EngineAPI.sprite.loadArchive(idxFile, grpFile, archiveId)     --> 已存在
```

## Slice 级验收

见 `slice-proposal.md` 的 Requirements（REQ-PORT1-1 ~ REQ-PORT1-8），
以及 `port-contract-completeness/tasks.md` 的 DoD。
