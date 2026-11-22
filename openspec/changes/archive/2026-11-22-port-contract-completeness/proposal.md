# Change Proposal: port-contract-completeness — 引擎契约完整性

> 父 slice: `engine-portability`（openspec/changes/engine-portability/）

## Why

`game/framework/` 表面上引擎无关（`love.*` 直接调用 = 0 处），
但它通过 `lib` 元表回退隐式依赖 LÖVE 的 1766 行原始实现。
换引擎时这些调用全部没有契约可依，只能靠移植者猜。

本 change 消除这条隐式通道，并**修复一个当前就存在的活体缺陷**。

## In Scope

1. 16 种 `lib.*` 提升为 EngineAPI 契约（46 处调用点）
2. `lib.Debug/GetKey/Delay/GetTime` → `EngineAPI.*`（191 处调用点）
3. 补齐 3 个缺失契约：`render.getWidth` / `render.getHeight` / `font.measureText`
4. 修复虚拟手柄接线 bug（`pollVirtualPad` 依赖不存在的 `render.getWidth`）
5. **新增 `framework/sprite_decoder.lua`**：RLE + 调色板解码从引擎搬到 framework
   （ADR-PORT-013：`LoadPic` 124 行里只有 5 行碰引擎，其余 119 行是可移植的数据处理）
6. **多格式支持**：格式标签 + 两条解码路径（ADR-PORT-014）
   - RLE → framework 解码 → `EngineAPI.sprite.createFromRGBA(w, h, rgbaBytes)`
   - PNG/JPG → 引擎解码 → `EngineAPI.sprite.createFromEncoded(bytes, "png")`
7. **修复实测缺陷**：PNG 帧路径硬置 `xoff/yoff = 0`（RLE 路径保留真实锚点，
   同容器内两种格式锚点语义不一致）
8. 38 个 dead contract 决策留痕
9. 4 引擎实现同步补齐
10. 跨引擎契约一致性测试（行为断言，不 skip）
11. 文档计数同步

## Out of Scope

- script 全局函数解耦 → `port-script-decoupling`
- sprite 动画 → `port-sprite-animation`
- resize / IME / audio 概念重设计 / 绘制原语扩展 → epic 的 TODO.md
- 资产格式**转换工具链**（把磁盘资产批量转成 PNG 图集）→ 不做，
  实测会从 40 MB 涨到 80–200 MB（见 design.md ADR-PORT-014 的方案 B）
- 实际写 Godot/Unreal 引擎实现

## 关键度量（基线与目标）

| 指标 | 基线 | 目标 |
|------|------|------|
| framework 里 `lib.*` 绕过调用 | 46 处（16 种） | **0** |
| framework 里 `lib.Debug/GetKey/Delay/GetTime` | 191 处 | **0** |
| EngineAPI 契约函数 | 64 | 64 + 19 = **83** |
| dead contract | 38（59%） | **< 10（12%）** |
| 缺失契约（框架在用但未声明） | 3 | **0** |
| 虚拟手柄可激活 | **否**（接线断） | **是** |
| 跨引擎一致性测试覆盖 | 4 引擎仅"能加载" | **行为断言全跑** |
| 全量断言数 | 3310 | ≥ 3310（只增不减） |

## Tracking

| REQ ID | 需求 | 落点 |
|--------|------|------|
| REQ-PORT1-1 | 引擎调用零绕过 | specs/engine-contract/spec.md |
| REQ-PORT1-2 | 契约覆盖实际用法 | specs/engine-contract/spec.md |
| REQ-PORT1-3 | 四引擎实现齐全 | specs/engine-contract/spec.md |
| REQ-PORT1-4 | 跨引擎行为一致性 | specs/engine-contract/spec.md |
| REQ-PORT1-5 | 虚拟手柄真实激活 | specs/virtual-pad-wiring/spec.md |
| REQ-PORT1-6 | 缺失契约可观测 | specs/engine-contract/spec.md |
| REQ-PORT1-7 | dead contract 决策留痕 | specs/engine-contract/spec.md |
| REQ-PORT1-8 | 零回归 | specs/engine-contract/spec.md |

## 风险

| 风险 | 缓解 |
|------|------|
| 237 处调用改写引入回归 | 按文件分批；每批跑全量测试；每批一个 commit 便于 bisect |
| 契约粒度设计重复既有错误（`map.drawMain` 盖 79 行） | 每个函数先写「为什么是这个粒度」再改实现（ADR-PORT-001） |
| dead contract 删了以后又要加回来 | 只删明确不可能是跨引擎概念的；其余保留 + 注释 |
| 4 引擎实现遗漏 | 一致性测试强制跑全部 4 个实现 |
