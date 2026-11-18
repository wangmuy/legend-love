# TODO — 后续缺口与涌现想法

本仓此前缺少 `openspec/project/TODO.md`。此文件用于收纳审查中发现、
但**不属于当前 slice** 的缺口。每项都记录现状证据与触发条件，
条件满足时再评估是否升为 change。

## 引擎可移植性：明确延后的缺口

审查 `game/framework/` 时发现，但 `engine-portability` slice 明确不做。

- [ ] **窗口 resize 事件**
  - 现状：全仓 0 处 `love.resize` 处理；`CC.ScreenW/ScreenH` 是编译期常量
  - 后果：窗口尺寸变化时菜单坐标不重算，元素跑到屏幕外
  - 触发条件：支持窗口缩放 / 全屏切换时
  - 预估：1 个 change（EngineAPI 加 resize 回调钩子 + framework 各模块响应）

- [ ] **IME / 中文文字输入**
  - 现状：0 处 `startTextInput`；`async_dialog` 的 `input` 类型只能打 ASCII
    （`input-action-layer` 已修好"能打 ASCII"，但中文仍不可输入）
  - 后果：中文输入框做不了
  - 触发条件：有真实的中文输入需求（当前该分支无业务调用方）
  - 预估：2 个 change（契约 + 各引擎实现；IME 必须真机验证）

- [ ] **audio 概念重设计**
  - 现状：契约是 `playMusic(filename)`；实际用法是 `PlayMIDI(0)`（索引号）
    + `PlayMPEG(path, VK_ESCAPE)`（带中断键的视频）
  - 后果：契约与实际用法完全不匹配，framework 绕开契约直接用 lib
  - 必须先定语义：音乐是"按名字选"还是"按编号选"？MPEG 算音频还是视频？
  - 预估：1 个 change，但需先做语义决策，不能直接写代码

- [ ] **绘制原语扩展**
  - 现状：render 只有 7 个原语
  - 缺：circle / line / polygon / 旋转 / 缩放 / 变换矩阵
  - 触发条件：有真实消费方（自绘 UI、粒子特效）
  - **不要为了"完整性"提前加 —— 加了就是 dead contract**
    （本 slice 已证明：38/64 的契约因为无消费者而变成死契约）

- [ ] **资产格式转换工具链**
  - 现状：`.idx`/`.grp` 是自研格式；Godot 用 `SpriteFrames`、Unreal 用 `PaperFlipbook`
  - 后果：真要移植时，光转换资产就是独立工程
  - 触发条件：确实要移植到 Godot/Unreal 时
  - 预估：独立 slice 或 epic

## 涌现想法（执行过程中产生，不打断当前 slice）

- [ ] **契约粒度设计原则文档化**
  - `engine-portability` 发现 `map.drawMain(...)` 这种"一个函数盖住 79 行实现"
    的粒度是错的。应把"如何为跨引擎场景设计契约粒度"写成 ADR，
    避免下次再犯（教训：语义级抽象会掩盖必须由框架决定的逻辑）

- [ ] **dead contract 根因分析**
  - 为什么契约写了却没人用？三种可能：粒度错 / 时机错（先写契约后写功能）/
    功能被 lib 绕过。值得做一次复盘，形成"写契约前先确认消费者"的规范

## 与引擎可移植性无关的既有待办

- [ ] **Android 虚拟手柄实机验证**
  - 现状：理论上已接线（`engine-portability` 的 change 1 会修好接线 bug），
    但**无触摸设备可验**
  - 缺的验证：手感（按钮大小/位置/响应延迟）、横屏布局、多点触控
  - 触发条件：能跑 Android 构建时

- [ ] **`ENGINE_API_DESIGN.md` 与代码同步**
  - 现状：`AGENTS.md:62` 写"实现 EngineAPI 全部 59 个函数"，实际 64 个
  - `engine-portability` 的 change 1 会修正计数，但该文档整体内容可能已过时
