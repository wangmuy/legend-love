## Context

当前 `game/script/` 目录下的游戏脚本通过 `lib_love.lua` 间接依赖 Love2D 引擎。`lib_love.lua` 导出的 47 个函数构成了事实上的引擎抽象层，但存在以下问题：

- 接口与实现混在一起，没有独立的接口定义文件
- `jymain.lua` 中有 3 处直接调用 `love.filesystem`
- `script_loader.lua` 直接使用 `love.filesystem.load`
- `async_globals.lua` 通过手动替换全局函数实现协程适配，缺乏标准契约
- 颜色系统 `GetRGB()` 返回 0-1 浮点数但未文档化

## Goals / Non-Goals

**Goals:**
- 定义 EngineAPI 接口规范，覆盖渲染/输入/音频/文件/计时/精灵/地图/字体/颜色/调试/协程共 11 个类别
- 从 `lib_love.lua` 重构出 `engine_love2d.lua`，实现全部 EngineAPI 接口
- 创建 `engine_test.lua`，实现 EngineAPI 的命令行测试版本
- 消除 `jymain.lua` 和 `script_loader.lua` 中对 `love.*` 的直接调用
- 重构 `async_globals.lua` 为基于 EngineAPI yieldable 函数的标准适配层
- 所有现有脚本（1018 个 oldevent + newevent）无需修改

**Non-Goals:**
- 不改写任何 oldevent/newevent 脚本
- 不改写 `jymain.lua` 中的 `instruct_*` 函数实现
- 不修改 `jyconst.lua` 中的常量和数据定义
- 不修改 `jymodify.lua` 中的游戏修改逻辑
- 不实现 Godot 引擎（仅预留接口）

## Decisions

### 决策 1：EngineAPI 作为独立接口文件

**方案**：创建 `game/engine_api.lua`，只包含接口定义（函数签名 + 文档注释），不包含实现。

**理由**：
- 接口与实现分离，替换引擎时只需对照接口文件实现
- 接口文件可作为开发文档，新引擎开发者一目了然
- 测试引擎可以独立于 Love2D 实现

### 决策 2：yieldable 函数作为 EngineAPI 契约

**方案**：EngineAPI 中标记哪些函数是 yieldable（调用时可能触发 coroutine.yield），作为 API 契约的一部分。

**yieldable 函数列表**：
- `EngineAPI.input.waitForKey()` — 等待按键
- `EngineAPI.time.sleep(ms)` — 等待时间
- `EngineAPI.render.presentAndWait(delay)` — 帧同步
- `EngineAPI.menu.show(...)` — 等待菜单选择
- `EngineAPI.dialogue.show(...)` — 等待对话翻页

**理由**：
- 现有 `async_globals.lua` 通过拦截全局函数实现协程适配，但缺乏标准契约
- 将 yieldable 函数作为 API 契约，新引擎实现者知道哪些函数需要支持协程 yield/resume
- 现有脚本通过适配层继续工作，新脚本可以直接使用 yieldable 函数

### 决策 3：颜色系统统一 0-1 浮点数

**方案**：EngineAPI 所有颜色参数接受 0-1 浮点数。`RGB()` 保留为 0-255 打包器（兼容旧数据格式），`GetRGB()` 作为桥接函数。

**理由**：
- 所有现代图形引擎（Love2D、Godot、OpenGL、DirectX、Metal）均使用 0-1 范围
- float32 在 0-1 范围内精度远超 0-255 整数
- 现有颜色常量（C_WHITE 等）保持 packed int 格式不变，在 EngineAPI 边界转换

### 决策 4：精灵系统 API 命名

**方案**：`initPalette` → `initSprites`

**理由**：调色板是 DOS 时代 256 色索引色的遗留概念，现代引擎直接处理 RGBA。该函数实际初始化精灵/纹理系统。

### 决策 5：测试引擎独立实现

**方案**：创建 `engine_test.lua`，实现完整 EngineAPI 接口，但所有渲染/音频为空操作，输入返回预设值。

**理由**：
- 可在无显示器的环境（CI/CD、SSH）中运行游戏逻辑测试
- 测试速度快（无帧同步等待）
- 可验证所有 instruct_* 逻辑、事件流程、数据一致性

## Risks / Trade-offs

| 风险 | 缓解措施 |
|------|---------|
| 重构 lib_love.lua 可能引入渲染回归 | engine_test.lua 可验证非渲染逻辑；渲染回归需人工测试 |
| async_globals.lua 重构可能影响事件脚本执行 | 保持向后兼容，现有脚本行为不变 |
| EngineAPI 接口设计可能遗漏某些引擎特性 | 第一阶段为"最小可行接口"，后续可扩展 |
| 测试引擎无法验证渲染正确性 | 明确标注不可自动化测试的范围，渲染测试需人工