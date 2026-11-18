# TODO — Future Slices & Ideas

## 本 epic 明确留待后续的缺口

审查 `framework/` 时发现但**不纳入本 epic** 的缺口，每个都记录了
当前证据与触发条件。触发条件满足时再评估是否升级为 slice。

- [ ] **resize 事件处理**
  - 现状：全仓 0 处 `love.resize` 处理；`CC.ScreenW/ScreenH` 是编译期常量
  - 后果：窗口尺寸变化时菜单坐标不重算，元素跑到屏幕外
  - 触发条件：支持窗口缩放/全屏切换时
  - 预估：1 个 change（EngineAPI 加 resize 回调钩子 + framework 各模块响应）

- [ ] **IME / 中文文字输入**
  - 现状：0 处 `startTextInput`；`async_dialog` 的 `input` 类型只能打 ASCII
  - 后果：中文输入框做不了
  - 触发条件：有真实的中文输入需求（当前 `async_dialog` 的 input 分支无业务调用方）
  - 预估：2 个 change（契约 + 各引擎实现；IME 需真机验证）

- [ ] **audio 概念重设计**
  - 现状：契约是 `playMusic(filename)`；实际用法是 `PlayMIDI(0)`（索引号）
    + `PlayMPEG(path, VK_ESCAPE)`（带中断键的视频）
  - 后果：契约与实际用法完全不匹配，framework 绕开契约直接用 lib
  - 需要先定：音乐是"按名字选"还是"按编号选"？MPEG 是音频还是视频？
  - 预估：1 个 change（但需要先做语义决策，不能直接写）

- [ ] **绘制原语扩展**
  - 现状：render 只有 7 个（text/fillRect/rectOutline/drawBackground/setClip/present/presentAndWait）
  - 缺：circle / line / polygon / 旋转 / 缩放 / 变换矩阵
  - 触发条件：有真实消费方（例如自绘 UI、粒子特效）
  - 注意：不要为了"完整性"提前加 —— 加了就是 dead contract

- [ ] **资产格式转换工具链**
  - 现状：`.idx`/`.grp` 是自研格式；Godot 用 SpriteFrames、Unreal 用 PaperFlipbook
  - 后果：真要移植时，光转换资产就是独立工程
  - 触发条件：确实要移植到 Godot/Unreal 时
  - 预估：独立 epic

## 本 epic 内产生的新想法

（执行本 epic 过程中涌现的想法记在这里，不要打断当前 slice）

- [ ] 契约粒度设计原则的文档化：本 epic 发现 `map.drawMain(...)` 这种
  "一个函数盖住 79 行实现"的粒度是错的。应把"如何为跨引擎场景设计契约粒度"
  写成 ADR 或 design 文档，避免下次再犯
- [ ] 38 个 dead contract 的根因分析：为什么契约写了却没人用？
  是粒度错、时机错（先写契约后写功能），还是功能被 lib 绕过？

## 与本 epic 无关的既有待办

- [ ] Android 虚拟手柄实机验证（需 Android 构建；本 epic 的 Slice 1 修好接线后才有意义）
