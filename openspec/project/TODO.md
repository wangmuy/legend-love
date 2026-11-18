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

- [x] ~~资产格式转换工具链~~ **已重新判定：不需要**（2026-11-18）
  - 原判断：`.grp` 需转成 Godot `SpriteFrames` / Unreal `PaperFlipbook`
  - 实测否定：`LoadPic` 的 124 行里只有 5 行碰引擎（创建画布 / 逐像素写 /
    上传纹理），其余 119 行是可移植的纯数据处理；而 LÖVE 11.5 的
    `newImageData(w, h, "rgba8", rawBytes)` 支持原始字节上传（实测 10000x 加速）
  - 结论：把 RLE 解码搬到 framework、引擎只做「上传 RGBA 字节」，
    **磁盘资产无需转换**（保留 40 MB RLE）
  - 转 PNG 图集实测更差：66.7 M 像素 → 图集 78.5 M 像素，PNG 压缩后
    80–200 MB，比现有 40 MB 大 2–5 倍
  - 落点：`port-contract-completeness` 的 ADR-PORT-013 / ADR-PORT-014

- [ ] **新增资产格式支持（未来扩展点）**
  - 已支持：RLE（原版）+ PNG（引擎解码），两种走不同路径（ADR-PORT-014）
  - 可低成本新增：WebP / JPG / BMP / TGA / 自定义 RLE 变体
  - 扩展方式：framework 加格式嗅探 → 若引擎能解码走 `createFromEncoded`，
    若可纯 Lua 解码走 framework 解码 + `createFromRGBA` —— **两种都不改引擎**
  - **2D 格式调研结论**（详见 ADR-PORT-014 的「调研」小节）：
    - 图片层面：四引擎交集 = **PNG**（已支持）
      LÖVE png/jpg/bmp/tga、Godot png/jpg/webp/svg、
      Unreal png/jpg/bmp/tga、SDL2 png/jpg/webp
    - 图集层面：**没有任何共同标准**
      Godot `.tres`(SpriteFrames) / Unreal `.uasset`(PaperFlipbook) 都是引擎专属
    - 第三方交换格式（TexturePacker JSON / Sparrow XML / Aseprite JSON）
      需要目标引擎装导入器，不是开箱即用
  - 因此本设计**不引入图集交换格式**：`.idx/.grp` 本身已是紧凑图集容器，
    引擎无需理解图集布局（ADR-PORT-013）
  - 若将来要与外部美术工具链交换：**交换格式是构建期的事，不是运行时的事**
    （构建工具读 TexturePacker JSON → 转成 .idx/.grp；运行时契约不变）
  - 注意：glTF 等 3D 格式不适合承载 2D 像素精灵（会丢调色板交换与锚点语义）
  - 触发条件：有实际的美术资源需要用新格式时

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
