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

- [x] ~~**audio 概念重设计**~~ → **已立项 `port-audio-semantics`**（2026-11-21）
  - 语义已定案（见该 change 的 design ADR-PORT-022/023/024）：
    - `playSequence(id)` = 按**游戏音乐编号**播（引擎按 `{ogg, mid, mp3}` 候选 +
      `sound/` 回落）
    - `playMusic(filename)` = 按**完整文件名**播（不推测扩展名）
    - 编号 → 文件名的模板由 `app.setMusicTemplate(template, startOffset)` 显式注册
      （引擎不再读 `CC.*`）
  - 顺带修两个活体缺陷：
    - `JY.EnableMusic == 0` 时只「不播」，已在播的 BGM 不会停
    - `playVideo` 无条件返回 `true`（实际 `start.mpg` 不存在，从未播成功过）

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

## 引擎可移植性：剩下的最后一块（TOD 已在 port-contract-completeness 之后产生）

- [x] ~~**script 层 lib.Pic\* 迁移**~~ —— **已完成**（`port-sprite-native-migration`）
  - ⚠️ **回归**：Task 4 改单写导致地图全黑，已由 `LoadArchiveBoth` 双写修复
    （见该 change tasks.md 的「回归修复」一节）

- [x] ~~**26 处阻塞 `lib.Delay`**~~ —— **已完成**（`port-blocking-delay`）
  - `lib.Delay` = `love.timer.sleep` → 真阻塞主线程（实测 101ms）
  - 26 处全在事件协程里 → 换成 `WaitFrame`（协程里 `waitForTime` 协作式）
  - gate STEP D3 硬断言：`script/` 无裸 `lib.Delay`
  - 实测实数：**27 处**（不是原估的 33），分布：
    `PicInit` 7 / `PicLoadFile` 14 / `PicGetXY` 3 / `PicLoadCache` 3
  - 处置：7 处 `PicInit` **全删**（6 处无参是 no-op；第 7 处在死代码且已被
    `initSprites` 覆盖）；14 处 `PicLoadFile` → `SpriteAtlas.loadArchive`；
    6 处 `PicGetXY`/`PicLoadCache` → `getMeta`/`draw`
  - **结果：`script/` 全仓 `lib.Pic*` = 0**（gate 新增 STEP D2 硬断言）
  - **但 `lib_love.lua` 的 `LoadPic` 119 行删不掉** —— 见下一条

- [x] ~~**`map.drawBattle` 契约透明化**~~ —— **已完成**（`port-map-render-native`）
  - 3 个地图绘制契约（`drawMain`/`drawScene`/`drawBattle`）全部改走
    `framework/map_render.lua`（363 行投影逻辑搬进 framework）
  - `war_async` 的双轨补丁与 `LoadArchiveBoth` 的双写**已摘除**
  - 三界面实机截图逐字节相同（md5 见 `docs/screenshots/README.md`）
  - **新增 4 个契约**：`render.getClip` / `map.getSceneSize` /
    `map.getBattleSize` / `map.drawClouds`（+ 8 个 map 读写，共 88）
  - **顺带修了 3 个静默失败**：`map_render` 全局函数被严格 `_G` 拒绝、
    `drawScene` 零消费者、`dialog.draw` 头像路径读 `picFileCache`

- [x] ~~**（已作废）原 `map.drawBattle` 透明化条目**~~ —— **已完成 + 后续立项**

  > **B 之后的新增前提**：`port-blocking-delay` 完成后，`WaitFrame` 依赖
  > `CoroutineScheduler:waitFrame`，而 `lib.Delay` 仍作为非协程 fallback 存在。
  > 删 `lib_love.LoadPic` 不影响 `lib.Delay`（两者无关），但**必须**先做本项
  > 才能摘掉 `war_async` 双轨 + `LoadArchiveBoth` 双写。
  - 实测结论（`port-sprite-native-migration` Task 6）：
    - 原以为 `battle_render` 迁到 `SpriteAtlas` 后就能删 `war_async` 的双轨补丁
      （`EngineAPI.sprite.loadArchive`）→ **错了**
    - 删掉后实机截图：战斗地图**全黑**（26865 字节 vs 正常 397034）
    - 根因链：
      ```
      EngineAPI.map.drawBattle  (engine_love2d.lua:302，只是转发)
        → lib.DrawWarMap        (lib_love.lua:1650)
           → JY_LoadPic         (lib_love.lua:582)
              = PicLoadCache    ← **读 picFileCache**
                 → 必须由 PicLoadFile 写入
      ```
    - 即 **`map.drawBattle` 不是 .idx/.grp 透明的契约**，它把旧系统包了一层
  - 要求：`framework/map_render.lua` 做投影 + 逐格 `sprite.draw`，
    取代 `map.drawMain/drawScene/drawBattle`（这三个已标 `@deprecated`）
  - 完成后可删：`war_async` 的双轨补丁 + `lib_love.LoadPic` 119 行
  - 预估：独立 change（涉及 3 个地图绘制契约 + 战斗/主图/场景三个界面实机验证）
  - **教训**：「全量测试绿」不等于「可以移除代码」。回归验证（改前改后对比）
    和移除性验证（删掉后单独跑）是两件不同的事 —— 后者必须实机。
  - **2026-11-21 实测修正**：`map.drawBattle` 已透明化（`port-map-render-native` ✓），
    但 `lib_love.LoadPic` 的 119 行**仍在**，真正的阻塞不是「事件脚本用 `lib.*`」
    （实测 27808 个脚本零 `lib.*`），而是：
    ① 3 个死契约（`sprite.draw`/`drawTinted`/`loadArchive`，实测 0 消费者）
    ② dialog 头像的 2 处 `lib.PicGetXY/PicLoadCache` 逃逸舱
    ③ 云子系统 190 行（解码可复用 `SpriteDecoder`，实测 9 帧对拍一致）
    → 已立项 `port-legacy-picture-removal`

- [x] ~~**`lib.*` 兼容层本身（`_G.lib`）**~~ —— **已立项 `port-compat-layer-removal`**（2026-11-21）
  - 原判断：「oldevent 脚本依赖它（约 2000 个数据文件）」
  - **实测推翻**：`game/script/oldevent/`（1018）+ `game/mods/*/script/oldevent/`
    （26790）共 **27808 个事件脚本零 `lib.`**；调用面恰好是 `instruct_0..67`
  - 真实消费者只有 5 类：`main.lua` 的 `SetDrawLoopFlag`、`async_globals` 的
    `lib.Delay` 补丁点、`WaitFrame` 的 fallback、`lib_love` 自身 8 处 `lib.Debug`、
    2 处死变量
  - **`_G.lib` 与 `EngineAPI` 是同一张表** ⇒ `lib.Delay = ...` 往 `EngineAPI`
    写了契约外的键 `Delay`，`WaitFrame` 的 fallback 因此拿到协程版而不是阻塞版
  - 该 change 顺带新增契约 `render.setDrawLoopFlag`

- [x] ~~**实机未覆盖的界面**~~ → **已立项 `port-ui-screens-verification`**（2026-11-21）
  - 原判断：「物品栏、人物状态、存档界面 —— 路径已迁移但未截图验证；
    `Menu_Thing` / `ShowPersonStatus` 在事件驱动下不可达」
  - **实测推翻**：物品菜单 / 物品格 / 人物状态**三个都可达且已实机捕获**
    （`docs/screenshots/item-menu.png` / `item-grid.png` / `person-status.png`）
  - 存档界面在 `GAME_SMAP` **不可达是原版行为**（主菜单「系统」置灰，
    `jymain_async.lua:47-48`）→ 必须在主地图验证
  - 该 change 顺带补 gate STEP F 漏掉的 4 个 script 全局
    （`ShowPersonStatus_sub` 等，其内部仍有 26 处 `DrawString`）

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

- [x] ~~**script 层 196 处 lib.* → EngineAPI**~~ —— **已完成**（`port-native-api-completion`）
  - 实测规模：**196 处 / 29 函数**（早期估的 258 含 oldevent 脚本重复统计）
  - 结果：**只剩 1 处**（`WaitFrame` 内部的 `lib.Delay` fallback，非协程上下文退路）
  - 新增 2 个契约：`map.loadClouds`（云层加载+烘焙）、`sprite.clearPictureCache`
    （`lib.LoadPicture("")` 的隐式副作用）→ 契约数 88 → **90**
  - **`.idx/.grp` 现在对引擎彻底不透明**：`framework/sprite_decoder.lua` 解容器，
    引擎只收 handle；`lib_love.lua` 的 `LoadPic` RLE 解码**只剩 3 个死契约的入口**
    （`sprite.draw`/`drawTinted`/`loadArchive` 实测 0 消费者）
    → 由 `port-legacy-picture-removal` 拆除
  - 顺带修 2 个测试判据误报（`allsinbk` 死参数只认 `LoadSMap(`、
    `test_battle_flow_headless` 只 stub `lib.*` 没 stub `EngineAPI.map`）
