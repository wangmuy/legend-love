-- engine_api.lua
-- EngineAPI 接口定义
-- 所有引擎（Love2D/Godot/测试引擎）必须实现此接口
--
-- @yieldable 标记表示该函数可能触发 coroutine.yield()
-- 非 @yieldable 函数入队后立即返回，不会阻塞
--
-- ============================================================================
-- ## 新引擎实现清单（Checklist）
-- ============================================================================
--
-- 目标：换引擎**只需**写 `game/engine-xxx/engine_xxx.lua` +
-- 一个入口文件；`game/framework/` 与 `game/script/` 零改动。
--
-- 下面每一条都是实测缺了就崩（不是风格建议）。按顺序做完即可跑起来。
--
-- ### 1. 实现本文件声明的全部契约函数（当前 97 个）
--
--   以 `grep -cE '^function M\.' game/engine-love2d/engine_api.lua` 为准
--   （新增契约时同步更新这里）。现有 4 个实现可作为参考：
--   `engine-love2d/engine_love2d.lua`（完整）、`engine-mud/engine_mud.lua`、
--   `engine-web/engine_web.lua`、`tests/engine_test.lua`（测试桩）。
--
--   漏实现的后果：`tests/unit/test_engine_conformance.lua` 会逐个列出缺项；
--   运行期则是「走到那个功能才崩」，比启动就崩更难排查。
--
-- ### 2. `require("framework.require_aliases")` —— 裸名 require 别名
--
--   **script 层依赖它，不是可选项**：`script/jymain.lua:15-16` 用的是裸名
--   `require "lib_file"` / `require "script_loader"`。这些裸名能被解析，
--   全靠 `framework/require_aliases.lua` 往 `package.preload` 注册的别名。
--
--   本模块被 require 时会**自动**调用 `install()`（幂等、不覆盖已有条目），
--   所以「require 一次」就够。注册处必须**早于** `require(... .. "jymain")`。
--
--   历史教训：这段注册原来只写在 LÖVE 引擎实现里，契约与文档都没提。
--   照契约新写一个「Godot 宿主」时，启动就死在
--   `module 'lib_file' not found`，而且报错点在 script 层，
--   排查方向会先跑偏到脚本上。
--
-- ### 3. 提供 `EngineAPI.init()`（**隐式约定，未在本文件声明**）
--
--   ★ 这是历史遗留：入口程序（`game/main.lua` 的 `love.load`）会调
--   `engineAPI.init()`，但本契约文件里**没有** `M.init()` 声明。
--   4 个引擎都各自实现了它（LÖVE：图形设置 + 随机种子；MUD/Test：空函数）。
--
--   新引擎**必须**提供一个（哪怕是 `function EngineAPI.init() end`），
--   否则入口第一行就 nil 调用崩。
--
--   已知取舍：把它补成正式契约 `M.init()` 需要 4 个引擎同步改动，
--   收益只是「契约完整度」；本次只在清单里注明隐式约定。
--
-- ### 4. 提供 3 个全局：`CONFIG` / `CC` / `Byte`
--
--   | 全局 | 来源 | 谁写 |
--   |---|---|---|
--   | `CONFIG` | `framework/config.lua`（模块内直接写全局 `CONFIG={}`）| `require "framework.config"` |
--   | `CC`     | `script/jyconst.lua`（`CC={}` 由 jymain 的引导流程装配）| 加载 script 后 |
--   | `Byte`   | `framework/lib_Byte.lua` | 入口 `Byte = require "framework.lib_Byte"` |
--
--   注意 `Byte` 必须由**入口显式赋值**（模块不写全局），
--   `script/jymain.lua` 有多处直接用 `Byte.*`。
--
-- ### 5. 启动序列（照 `game/main.lua` 的 `love.load` 提炼，顺序不可换）
--
--   ```lua
--   require "framework.config"                    -- ① CONFIG 全局
--   Byte = require "framework.lib_Byte"           -- ② Byte 全局
--   require "engine-xxx.engine_xxx"               -- ③ 你的引擎（内部 require require_aliases）
--   EngineAPI.init()                              -- ④ 隐式约定，见第 3 条
--   EventBridge.getInstance():init()              -- ⑤ 事件桥接器
--   require(CONFIG.ScriptPath .. "jymain")        -- ⑥ 游戏主逻辑（裸名别名必须已就绪）
--   JYMainAdapter.init()                          -- ⑦ 装配动画/hooks/起始菜单
--   ```
--
--   ③ 之前不能碰 script；⑥ 之前必须已完成 ②③（`require_aliases` 尤其重要）。
--
-- ### 6. 每帧顺序（update / draw 各三步，顺序有意义）
--
--   每帧更新：
--   ```lua
--   JYMainAdapter.update(dt)              -- 游戏适配器（动画、自动移动）
--   EventBridge.getInstance():update(dt)  -- 输入 → 状态机 → 协程
--   MenuAsync.update(dt)                  -- 异步菜单
--   ```
--
--   每帧绘制（**必须在宿主的帧绘制回调内**）：
--   ```lua
--   render.setDrawLoopFlag(true)          -- 进入帧绘制（见第 8 条的坑）
--   EventBridge.getInstance():draw()      -- 当前状态的全部绘制
--   MenuAsync.draw()                      -- 活动菜单
--   render.setDrawLoopFlag(false)         -- 离开帧绘制
--   ```
--
-- ### 7. `dt` 单位 = **秒**
--
--   `EngineAPI.time.*`、`JYMainAdapter.update(dt)`、`EventBridge:update(dt)`、
--   `SpriteAnim.update(dt)`、`MenuAsync.update(dt)` 全部以秒为单位。
--   LÖVE 的 `love.update(dt)`、Godot 的 `_process(delta)`、
--   Unreal 的 `DeltaSeconds` 都是秒 —— 直接透传即可。
--
--   **不要传毫秒**：`time.sleep` / `getTime` 那一组才是毫秒
--   （`presentAndWait(50)`、`AutoMove` 的 50ms 步进间隔）。
--   两者混用会让动画快 1000 倍或几乎不动，且不报错。
--
-- ### 8. `render.*` 必须在帧绘制回调内调用
--
--   本抽象层是**立即模式**：framework 每帧从头重画整幅画面
--   （`EventBridge:draw()` 里几百次 `render.text/fillRect/...`），
--   没有保留模式的节点树。所以「什么时候可以画」必须由宿主显式告诉引擎
--   —— 这就是 `render.setDrawLoopFlag(true/false)`（见 `M.render.setDrawLoopFlag`）。
--
--   **Godot 的坑**：`CanvasItem.draw_string()` 在 `_draw()` 之外调用
--   **不报错、不警告**，只是什么都不画；表现为「游戏在跑、逻辑正常、屏幕全黑」。
--   Unreal 的 `UCanvas` 同理只能在 `DrawHUD()` 内用。
--   无屏幕引擎（MUD/Web）两者都可空实现。
--
-- ============================================================================

local M = {}

--------------------------------------------------------------------
-- render - 渲染系统
--------------------------------------------------------------------
M.render = {}

--- 绘制文本
-- @param x number X 坐标
-- @param y number Y 坐标
-- @param str string 文本内容
-- @param color table {r, g, b} 0-1 浮点数
-- @param size number|nil 字体大小
function M.render.text(x, y, str, color, size) end

--- 填充矩形
-- @param x1, y1, x2, y2 number 矩形区域（角点，非宽高）
-- @param color number|table 接受两种形态：
--        number = 打包 RGB int（如 C_WHITE = RGB(236,236,236)），既有调用方全用这种
--        table  = {r=, g=, b=} 0-1 浮点，新代码推荐
--        引擎实现必须两种都能处理（内部归一化）
function M.render.fillRect(x1, y1, x2, y2, color) end

--- 矩形边框
-- @param x1, y1, x2, y2 number 矩形区域（角点，非宽高）
-- @param color number|table 同 fillRect（int 或 {r,g,b} 都接受）
function M.render.rectOutline(x1, y1, x2, y2, color) end

--- 背景框（带阴影效果）
-- @param x1, y1, x2, y2 number 矩形区域
-- @param brightness number 亮度 0-255
function M.render.drawBackground(x1, y1, x2, y2, brightness) end

--- 设置裁剪区域
-- @param x1, y1, x2, y2 number 裁剪区域
function M.render.setClip(x1, y1, x2, y2) end

--- 读当前裁剪区域
--
-- 为什么必须有它：地图绘制（`framework/map_render.lua`）要用当前 clip
-- 反算可见瓦片的循环范围（`lib.DrawMMap/DrawSMap/DrawWarMap` 都这么做）。
-- 没有它就只能让引擎自己算循环范围 —— 那是把游戏逻辑留在引擎里。
--
-- 返回**未裁剪**时的哨兵值：`{x=0, y=0, w=<屏幕宽>, h=<屏幕高>}`
-- （与 `lib.SetClip(0,0,0,0)` 的"清除裁剪"语义对应）。
--
-- @return table {x=, y=, w=, h=}
function M.render.getClip() end

--- 取当前渲染目标的宽（逻辑像素）
--
-- 为什么必须有它：调用方目前靠全局 CC.ScreenW（**编译期常量**）拿屏幕宽。
-- 但 Godot 的窗口可在运行时缩放、Android 会旋转、多显示器会变 DPI ——
-- 编译期常量无法适配。
--
-- 无图形能力的引擎（如 MUD）SHALL 返回哨兵值（1024），SHALL NOT 返回 nil。
--
-- @return number 宽度（逻辑像素，> 0）
function M.render.getWidth() end

--- 取当前渲染目标的高（逻辑像素）
-- @return number 高度（逻辑像素，> 0）
function M.render.getHeight() end

--- 提交渲染帧
function M.render.present() end

--- 提交渲染帧并等待
-- @yieldable
-- @param delay number 等待毫秒数
function M.render.presentAndWait(delay) end

--- 告知引擎「当前处于/离开了帧绘制回调」
--
-- **为什么这不是引擎私有钩子**：原版 LÖVE 的 `lib.SetDrawLoopFlag` 控制
-- `ShowSurface/ShowSlow` 是否真的 `present()` —— 因为只有 `love.draw()` 内
-- 调 `present()` 才不会闪屏。这个「我在哪」的信息只有**入口程序**知道，
-- 所以必须由入口告诉引擎，而入口只能走契约（不能摸全局 `lib`）。
--
-- 语义约定：
--   - flag = true   当前在帧绘制回调内 → `present()` 立即生效
--   - flag = false  已离开 → `present()` 允许延后/忽略（由引擎决定）
--   - 无屏幕概念的引擎（MUD/Web）可空实现
--
-- 调用方：`game/main.lua` 的 `love.draw()` 前后（LÖVE 入口）。
-- 其它引擎入口在它自己的绘制回调前后调用同名契约即可。
--
-- @param flag boolean
--
-- @deprecated 请改用 `beginFrame()` / `endFrame()`（语义更明确、不会传反）。
--   两个新契约出现后，本函数的**唯一正确实现**是转发：
--   ```lua
--   EngineAPI.render.setDrawLoopFlag = function(flag)
--       if flag then EngineAPI.render.beginFrame()
--       else EngineAPI.render.endFrame() end
--   end
--   ```
--   保留它只是为了让旧入口/旧测试继续工作，不再是推荐写法。
function M.render.setDrawLoopFlag(flag) end

--- 进入帧绘制回调（**所有绘制调用的边界起点**）
--
-- ★ 这是本契约文件里**唯一带强制约束的调用时机**，新引擎实现者必读：
--
--   本引擎抽象层是**立即模式**（immediate mode）：framework 每帧把整幅画面
--   从头重画一遍（`EventBridge:draw()` 里调几百次 `render.text/fillRect/...`），
--   **没有**保留模式（retained mode）的节点树/控件对象。
--
--   于是「什么时候可以画」这件事必须由宿主（host）显式告诉引擎：
--
--   | 引擎 | 帧绘制回调 | 立即模式可用性 |
--   |---|---|---|
--   | LÖVE  | `love.draw()` | ✔ 直接可用 |
--   | Godot | `CanvasItem._draw()` | ✔ 必须在 `_draw()` 内，**在外面调 `draw_*` 会静默无效** |
--   | Unreal| `AHUD::DrawHUD()` / `UCanvas` | ✔ 同上 |
--   | Web   | `requestAnimationFrame` 回调 | ✔ |
--   | MUD   | 无屏幕，空实现 | — |
--
--   **Godot 的坑**：`draw_string()` 在 `_draw()` 之外调用不报错、不警告，
--   只是什么都不画。若宿主忘了调 `beginFrame()` 或忘了包在 `_draw()` 里，
--   表现是「游戏逻辑在跑但屏幕全黑」——极难定位。所以这个契约存在。
--
-- 引擎实现应做的事（按需）：
--   - 打开绘制批次 / 绑定渲染目标 / 置「现在允许绘制」标志
--   - LÖVE 实现里它同时置 `drawLoop = true`（`present()` 才敢真刷屏）
--
-- 调用方：`framework/boot.lua` 的 `Boot.draw()`（**推荐**）；
--        或各引擎自己的入口绘制回调前后。
--
-- @see M.render.endFrame
function M.render.beginFrame() end

--- 离开帧绘制回调（**所有绘制调用的边界终点**）
--
-- 与 `beginFrame()` 成对出现，必须在同一帧内调用（即使中间出错也要退出）。
-- 引擎实现应做的事（按需）：
--   - 结束绘制批次 / `present()` / 解开渲染目标 / 清「允许绘制」标志
--   - LÖVE 实现里它同时置 `drawLoop = false`
--
-- **为什么不用 `pcall` 包住**：吞掉绘制异常会让「黑屏但无报错」更难查。
-- framework 侧的 `Boot.draw()` 用 `pcall` 只是为了保证 `endFrame()`
-- 一定被调用（否则引擎的绘制状态会跨帧泄漏），错误仍会记日志。
--
-- @see M.render.beginFrame
function M.render.endFrame() end

--- 开始一个绘制批次（**可选的性能提示，不是正确性前提**）
--
-- 为什么存在（port-render-batching 实测数据）：
--   主地图一帧 `drawMain` 会发出 **约 2900 次 `sprite.drawHandle`**
--   （实测：2896 / 复测 2926 —— 随裁剪区与视口浮动，量级固定）
--   （480×480 等距地图，视野内每格 2 层 + 建筑层）。这在目标引擎上的代价
--   差别巨大：
--
--   | 引擎 | 约 2900 次 drawHandle 的实际代价 |
--   |---|---|
--   | LÖVE (OpenGL)   | 流畅 —— 同纹理连续 draw 有**隐式批处理** |
--   | Godot 4         | 可行 —— 每帧重建约 2900 个绘制命令，但 `draw_texture_rect` 是引擎侧命令 |
--   | Unreal (HUD)    | **危险** —— `DrawTile` 每次是独立 draw call，很可能掉帧 |
--
--   所以调用方需要一种「把这一堆画法一次性告诉引擎」的通路。
--   但这条通路**不能是必需的** —— 引擎没有批处理能力时必须能照旧逐次画。
--
-- ## 关键语义（三条，实现方与调用方都必须遵守）
--
-- ### ① 返回 false = 本引擎不支持批处理，调用方照常逐次 draw
--
--   引擎**不支持**（或不想做）时 SHALL 返回 `false`，且 SHALL NOT 报错/抛异常。
--   调用方收到 `false` 后 SHALL 继续用原有的逐次 `sprite.drawHandle` 画 ——
--   **行为、像素、绘制顺序全部不变**。批处理是**纯优化**，不改变可见结果。
--
--   这条布尔返回是整个契约的核心：它把「引擎能力」变成**运行时可查询的值**，
--   而不是「假设引擎一定有」。没有它，调用方只有两种坏选择：
--   要么假设支持（在不支持的引擎上静默丢绘制），要么完全不用（永远拿不到优化）。
--
-- ### ② 批次内 `sprite.drawHandle` 的**语义不变**（调用方无感知）
--
--   批次只是建议，不是约束。引擎可以在 `beginBatch` 后把绘制**攒起来**
--   （到 `endBatch` 一次性提交），也可以**立即画**（忽略批次，等价于没调）。
--   两种选择对调用方**不可区分** —— 调用方写 `beginBatch` → 若干 `drawHandle`
--   → `endBatch` 这一段时，不需要知道自己是否真的进了批处理模式。
--
--   因此：**引擎 SHALL NOT 因为处于批次内而改变任何单个绘制的可见结果**
--   （位置、顺序、flags、alpha、裁剪都必须相同）。
--
-- ### ③ 明确**禁止嵌套**
--
--   `beginBatch` 在已处于批次内时 SHALL 视为**无效**：直接返回 `false`，
--   SHALL NOT 抛错，也 SHALL NOT 改变当前批次状态（外层批次保持有效）。
--   对应的 `endBatch` 调用 SHALL NOT 提前结束外层批次 —— 引擎应把「无效的
--   begin 配对的 end」也忽略掉。
--
--   **为什么不支持嵌套**：批处理的主要收益来自「同纹理/同状态连续提交」。
--   嵌套会让内层改变状态、外层被迫重新提交，收益消失而复杂度翻倍；
--   而本项目的绘制结构（地图 / 文字 / 形状）本身就是**并列的三段**，
--   没有嵌套需求。真正需要时再升级成栈，届时改成返回 true 即可 ——
--   调用方代码不用动（它本来就要容错 false）。
--
-- @param kind string|nil "tile" | "text" | "shape"（提示引擎这批画的是什么，
--        便于引擎按类型选策略，如瓦片用 atlas、文字用 glyph cache）。
--        引擎 SHALL NOT 依赖它的取值正确 —— 未知值按 "unknown" 处理即可。
-- @return boolean 是否真的进入了批处理模式
--         （false = 引擎不支持/已在批次内/该 kind 无优化 → 调用方逐次画）
--
-- @see M.render.endBatch
function M.render.beginBatch(kind) end

--- 结束当前批次（引擎在此一次性提交）
--
-- 与 `beginBatch` 成对。**必须有保证**：即使批次内的绘制中途抛错，调用方
-- 也会用 `pcall` 保证 `endBatch` 被调到（见 `framework/render_batch.lua`
-- 的 `RenderBatch.wrap`）—— 否则引擎的批次状态会跨帧泄漏，
-- 表现是「下一帧的东西全画在上一帧的批次里」，比崩溃更难查。
--
-- 语义：
--   - 从未 `beginBatch`（或 begin 返回了 false）时调 → SHALL 是**无害空操作**
--     （不抛错、不改变任何状态）。这让调用方不必记住「上次 begin 成没成功」。
--   - `endBatch` 内部 SHALL 完成真正的提交（bind/upload/draw call），
--     之后引擎的绘制状态 SHALL 与 `beginBatch` 之前完全一致。
--
-- 无屏幕引擎（MUD/Web）与不做批处理的引擎（当前 LÖVE）可空实现。
function M.render.endBatch() end

--------------------------------------------------------------------
-- sprite - 精灵/纹理系统
--------------------------------------------------------------------
M.sprite = {}

--- 初始化精灵系统
--
-- @param paletteFile string|nil 调色板文件路径（如 CC.PaletteFile = "data/mmap.col"）
--
-- 为什么带参数：原版 `lib.PicInit(PaletteFilename)` 的**唯一作用**就是加载
-- 调色板（lib_love.lua:254 `PicInit` → `LoadPallette`）。RLE 精灵的像素值是
-- 调色板索引，不加载调色板就全黑。
--
-- 支持 RGBA 字节上传的新引擎可以忽略这个参数（它们不需要调色板概念）；
-- 但实现**不得**在收到 paletteFile 时静默丢弃 —— 兼容旧资产的引擎必须加载。
function M.sprite.initSprites(paletteFile) end

--- **已删除**：`sprite.loadArchive(idxFile, grpFile, archiveId)`
--
-- 原契约要求引擎自己解析 `.idx/.grp` 并维护 `picFileCache` 注册表。
-- `port-native-api-completion` 把 script 层全迁到 `SpriteAtlas` 之后，
-- framework/script 里**零调用**（实测 2026-11-21）→ 由
-- `port-legacy-picture-removal` 删除。容器解析归 `framework/sprite_atlas.lua`。
--
-- 新代码请用：`require("framework.sprite_atlas").loadArchive(...)`

--- **已删除**：`sprite.draw(archiveId, spriteId, x, y, flags, alpha)`
--
-- 原契约要求引擎持有 archive 表 + RLE 解码（575 行 `picFileCache` 链）。
-- 实测 framework/script **零调用**；新代码走
-- `SpriteAtlas.draw(atlasId, frameId, …)` → `sprite.drawHandle`。
--
-- @deprecated 已被 `sprite.drawHandle(handle, x, y, flags, alpha)` 取代

--- **已删除**：`sprite.drawTinted(archiveId, spriteId, x, y, color, alpha)`
--
-- 实测 framework/script 零调用（`mouse_hover.lua` 已改走
-- `SpriteAtlas.drawTinted`）。染色能力由 `sprite.drawHandleTinted` 承载。
--
-- @deprecated 已被 `sprite.drawHandleTinted(handle, x, y, color, alpha)` 取代

--- 从原始 RGBA 字节创建纹理
--
-- **这是 ADR-PORT-013 的核心**：RLE 与调色板解码住在 framework
-- （`framework/sprite_decoder.lua`），引擎只负责把字节串上传成纹理。
--
-- 为什么这样分工：`lib_love.lua` 的 LoadPic 有 124 行，其中只有 5 行
-- 真正碰引擎（创建画布 / 逐像素写 / 上传纹理），其余 119 行
-- （读 idx 偏移、解析帧头、RLE 解压、查调色板）全是可移植的纯数据操作。
-- 让引擎承担那 119 行，等于每个新引擎都要重写一遍。
--
-- **字节顺序契约：rgbaBytes 一律 RGBA 顺序**（R,G,B,A 依次排列）。
--   LÖVE    rgba8 原生即 RGBA     → newImageData(w, h, "rgba8", raw)
--   Godot   FORMAT_RGBA8 即 RGBA  → Image.create_from_data(...)
--   Unreal  PF_B8G8R8A8 是 BGRA   → **实现内需 swizzle**
--   SDL2    SDL_PIXELFORMAT_RGBA8888
-- 若引擎原生格式不同，SHALL 在实现内部转换，调用方无需感知。
--
-- @param w, h number 尺寸
-- @param rgbaBytes string w*h*4 字节，RGBA 顺序
-- @param opts table|nil { xoff=, yoff=（锚点，默认 0） }
-- @return table|nil handle { w=, h=, xoff=, yoff= }
function M.sprite.createFromRGBA(w, h, rgbaBytes, opts) end

--- 从编码后的图片字节创建纹理（引擎负责解码）
--
-- 用于 framework **无法纯 Lua 解码**的格式（PNG/JPG/WebP 等需要解压库）。
-- framework 只做字节签名嗅探（ADR-PORT-014），解码交给引擎：
--   LÖVE    love.image.newImageData(FileData)
--   Godot   Image.load_png_from_buffer / load_jpg_from_buffer
--   Unreal  FImageUtils::ImportBufferAsTexture2D
--   SDL2    IMG_Load_RW
--
-- formatHint 是**提示**（framework 嗅探的结论），引擎可以忽略它
-- （多数引擎的解码器自己会嗅探）。它存在是为了让引擎能走更快的分支。
--
-- @param bytes string 完整图片文件字节
-- @param formatHint string|nil "png" | "jpg" | "webp" | ...
-- @param opts table|nil { xoff=, yoff= }
-- @return table|nil handle { w=, h=, xoff=, yoff= }
function M.sprite.createFromEncoded(bytes, formatHint, opts) end

--- 绘制一张独立图片文件（非 .grp 档案）
--
-- 与 sprite.draw 的区别：这个直接读磁盘图片（PNG/JPG 等），不经过 .idx/.grp。
-- 用于开场图、结局图这类整屏图片。
--
-- x/y 传 -1 表示**屏幕居中**（既有调用方约定，实测 jymain.lua 的
-- LoadPicture(CC.DeadFile, -1, -1) 就是这个语义）。
--
-- @param filename string 图片路径
-- @param x, y number 绘制位置；-1 表示该轴居中
-- @param opts table|nil { cache=true }（默认 true，按文件名缓存）
function M.sprite.drawPictureFile(filename, x, y, opts) end

--- 绘制一个纹理句柄（**格式透明**的新 API）
--
-- 这是 ADR-PORT-013 的最终形态：句柄由 createFromRGBA/createFromEncoded
-- 返回，引擎**不知道**它来自 .idx/.grp、PNG 图集还是别的容器格式。
--
-- 与 sprite.draw(archiveId, spriteId, ...) 的区别：
--   sprite.draw 的第一参数是**引擎侧注册表的下标**，
--   隐含"引擎维护 archive 表"这个结构 → 换容器格式时引擎要改。
--   drawHandle 只认句柄 → 换任何格式引擎零改动。
--
-- flags 语义沿用既有位域（引擎侧能实现就实现，实现不了可只做 0/0x1）：
--   0x1 忽略锚点  /  0x2 alpha 混合（用 alpha 参数）  /  0x4 全黑  /  0x8 全白
--
-- @param handle table createFromRGBA/createFromEncoded 的返回值
-- @param x, y number 绘制位置
-- @param flags number|nil
-- @param alpha number|nil 0-255
-- @return boolean 是否真的绘制了
function M.sprite.drawHandle(handle, x, y, flags, alpha) end

--- 清空「按文件名缓存的整图」缓存（对应 `lib.LoadPicture("")` 的隐式副作用）
--
-- **为什么需要独立契约**：`lib.LoadPicture` 文件名传空串时不是"什么都不画"，
-- 而是 `pictureCache = {}`（**清空整图缓存**）。
--
-- `script/jymain.lua:295` 正是靠这个副作用清掉上一屏：
-- ```lua
-- lib.LoadPicture("", 0, 0)
-- ```
--
-- 而 `sprite.drawPictureFile` 对空文件名只 `return false`（**不清缓存**），
-- 两者语义不同 → 不能机械替换。所以把「清缓存」独立成契约。
function M.sprite.clearPictureCache() end

--- 绘制一个纹理句柄（染色版）
--
-- @param handle table
-- @param x, y number
-- @param color table {r=, g=, b=} 0-1 浮点
-- @param alpha number|nil 0-255
-- @return boolean
function M.sprite.drawHandleTinted(handle, x, y, color, alpha) end

--- 取纹理的元数据（尺寸 + 锚点）
--
-- 两条创建路径（createFromRGBA / createFromEncoded）的返回值都 SHALL
-- 能被本函数查询，保证「锚点语义与创建路径无关」。
--
-- @param handle table createFromRGBA/createFromEncoded 的返回值
-- @return table { w=, h=, xoff=, yoff= }
function M.sprite.getMeta(handle) end

--------------------------------------------------------------------
-- map - 等距地图系统
--------------------------------------------------------------------
M.map = {}

--- 加载主地图数据
-- @param earthFile, surfaceFile, buildingFile, buildXFile, buildYFile string
-- @param width, height number 地图尺寸
-- @param x, y number 初始坐标
function M.map.loadMain(earthFile, surfaceFile, buildingFile, buildXFile, buildYFile, width, height, x, y) end

--- 加载场景地图数据
-- @param sFile, tmpFile string
-- @param num number 场景数
-- @param width, height number 场景尺寸
-- @param dFile string 防御数据文件
-- @param dNum1, dNum2 number
function M.map.loadScene(sFile, tmpFile, num, width, height, dFile, dNum1, dNum2) end

--- 保存场景地图数据
-- @param sFile, dFile string
function M.map.saveScene(sFile, dFile) end

--- 加载战斗地图数据
-- @param idxFile, grpFile string
-- @param mapId number 地图编号
-- @param num number 层数
-- @param width, height number 地图尺寸
function M.map.loadBattle(idxFile, grpFile, mapId, num, width, height) end

--- 读取地图瓦片数据
--
-- layer 语义（与原版 lib.GetMMap 的 flag 完全一致，**不自造编号**）：
--   0 = earth   地面层
--   1 = surface 表层
--   2 = building 建筑层
--   3 = buildx  建筑遮罩 X
--   4 = buildy  建筑遮罩 Y
--
-- 为什么保留这 5 个编号而不是抽象成"地形/障碍"：
--   这 5 层是**数据格式的一部分**（.grp 里就是这 5 个数组），
--   抽象成语义层反而要每个引擎自己定义映射，是多引擎分歧的源头。
--
-- @param x, y number 地图坐标
-- @param layer number 0..4
-- @return number 瓦片编号（-1 = 越界）
function M.map.getTile(x, y, layer) end

--- 写主地图瓦片
--
-- **消费者是 `framework/map_render.lua` 的 `buildingSort`**：
-- 它临时把主角/船写进建筑层（layer 2/3/4），参与深度排序，排序后恢复原值
-- （`lib.BuildingSort` 用 `SetMMap` 做这件事，共 6 处）。
--
-- 这不是"地图可编辑"的宣告 —— 只是深度排序的临时占用，写完立刻还原。
--
-- @param x, y number 地图坐标
-- @param layer number 0..4（语义同 getTile）
-- @param value number 瓦片编号
function M.map.setTile(x, y, layer, value) end

--- 读场景地图瓦片（小场景）
--
-- **签名与 getTile 不同：多一个 sceneId**（对应 `lib.GetS(id, x, y, level)`）。
-- 场景数据是**另一套数组**（`smap`，按场景 × 6 层 × 尺寸 排布），
-- 所以必须带 sceneId 才能定位。
--
-- layer 语义同 `getTile` 的 0..4，但场景有**6 层**（0..5，第 5 层是空中）：
--   0 地面 / 1 建筑 / 2 空中 / 3 事件编号 / 4 建筑高度修正 / 5 空中高度修正
--
-- @param sceneId number 场景编号
-- @param x, y number 场景坐标
-- @param layer number 0..5
-- @return number 瓦片编号（越界/无效 = 0，与原版 GetS 一致）
function M.map.getSceneTile(sceneId, x, y, layer) end

--- 写场景地图瓦片
-- @param sceneId number 场景编号
-- @param x, y number 场景坐标
-- @param layer number 0..5
-- @param value number 瓦片编号
function M.map.setSceneTile(sceneId, x, y, layer, value) end

--- 读场景事件数据（`lib.GetD`）
--
-- **这不是地图瓦片**：`D` 数组存的是「每个场景 tile 上挂了什么事件」
-- （id 是场景内 tile 索引，i 是字段号：0..7）。
-- `DrawSMap` 用它查第 3 层的事件编号对应哪个贴图（`GetD(sceneid, d3, 7)`）。
--
-- @param sceneId number 场景编号
-- @param eventId number 场景内事件索引
-- @param field number 字段号 0..7
-- @return number
function M.map.getSceneEventData(sceneId, eventId, field) end

--- 写场景事件数据（`lib.SetD`）
-- @param sceneId number 场景编号
-- @param eventId number 场景内事件索引
-- @param field number 字段号 0..7
-- @param value number
function M.map.setSceneEventData(sceneId, eventId, field, value) end

--- 读战斗地图瓦片
--
-- layer 语义同 `getTile`。战斗地图是**第三套数组**（`lib.GetWarMap`）。
--
-- @param x, y number 战斗地图坐标
-- @param layer number 0..4
-- @return number 瓦片编号（-1 = 越界）
function M.map.getBattleTile(x, y, layer) end

--- 写战斗地图瓦片
--
-- 战斗地图有 **6 层**（0..5）。
--
-- @param x, y number 战斗地图坐标
-- @param layer number 0..5
-- @param value number 瓦片编号
function M.map.setBattleTile(x, y, layer, value) end

--- 清空战斗地图的某一层（`lib.CleanWarMap`）
-- @param layer number 0..5
-- @param value number 填入值
function M.map.clearBattleTile(layer, value) end

--- 卸载主地图数据（释放内存）
function M.map.unload() end

--- 取场景地图的尺寸
--
-- @return table {w=, h=}（场景坐标系的宽高，原版 `S_XMax` / `S_YMax`）
--
-- 为什么需要它：`DrawSMap` 的循环边界判据是 `xx < S_XMax` / `yy < S_YMax`，
-- 而这两个值在 `lib_love.lua` 是 **local** 变量（`LoadSMap` 时赋值）。
-- framework 拿不到，只能从 `CC.SWidth/SHeight` 猜 —— 那是**调用方传的参数**，
-- 不是引擎的实际状态。显式契约更准确（且 MOD 改参数时不会静默错位）。
function M.map.getSceneSize() end

--- 取战斗地图的尺寸
--
-- @return table {w=, h=}（原版 `War_XMax` / `War_YMax`）
--
-- 与 `getSceneSize` 同理：这两个值在 `lib_love.lua:1577` 是 **local**
-- （`LoadWarMap` 时赋值），framework 拿不到。
function M.map.getBattleSize() end

--- 加载云层贴图并初始化（`lib.CloudLoadAndInit`）
--
-- **为什么这归引擎**：云的像素要做**逐像素调色板烘焙**
-- （`CloudBakeImage`，`lib_love.lua:1255` → `love.image.newImageData`），
-- 属 sprite 子系统，不是 map 投影逻辑。
--
-- 位置更新（`map.tickClouds`）是纯游戏逻辑，绘制（`map.drawClouds`）归引擎，
-- 三者分工：loadClouds（加载+烘焙）/ tickClouds（位置）/ drawClouds（贴图）。
--
-- @param idxFile, grpFile string 云贴图容器
function M.map.loadClouds(idxFile, grpFile) end

--- 绘制云层
--
-- 云的位置更新是纯游戏逻辑（`tickClouds`），但**云的像素归引擎**：
-- LÖVE 侧要做逐像素调色板烘焙（`CloudBakeImage`，`lib_love.lua:1255`），
-- 那是 sprite 子系统的事，不是 map 投影逻辑。
--
-- 所以 framework 的 `map_render.drawMain` 在建筑层之后调本契约，
-- 引擎负责把云画上去（天空层，永远在地面/建筑之上）。
--
-- @param mx, my number 主角地图坐标（云的位置相对它偏移）
function M.map.drawClouds(mx, my) end

--- 推进云层动画（纯时间驱动的位置更新）
--
-- 云的位置纯粹是**游戏逻辑**（每 40ms 按 Speedx/Speedy 移动），
-- 与引擎无关；引擎只需提供当前时间（EngineAPI.time.getTime）。
-- 但绘制云的像素仍归引擎（sprite.draw）。
function M.map.tickClouds() end

--- 绘制主地图
-- @param playerX, playerY number 玩家坐标
-- @param playerPic number 玩家贴图编号
function M.map.drawMain(playerX, playerY, playerPic) end

--- 绘制场景地图
-- @param sceneId number 场景编号
-- @param x, y, offX, offY number 偏移
-- @param playerPic number 玩家贴图编号
function M.map.drawScene(sceneId, x, y, offX, offY, playerPic) end

--- 绘制战斗地图
-- @param flag number 绘制标志
-- @param x, y number 坐标
-- @param v1, v2, v3 number 附加参数
function M.map.drawBattle(flag, x, y, v1, v2, v3) end

--------------------------------------------------------------------
-- input - 输入系统
--------------------------------------------------------------------
M.input = {}

--- 获取按键（非阻塞）
-- @return number 按键码，-1 表示无按键
function M.input.getKey() end

--- 等待按键
-- @yieldable
-- @return number 按键码
function M.input.waitForKey() end

--- 设置按键重复
-- @param delay number 初始延迟（秒）
-- @param interval number 重复间隔（秒）
function M.input.setKeyRepeat(delay, interval) end

--- 获取鼠标位置
--
-- **契约：返回【逻辑坐标】，与 DrawString / DrawRect 同一坐标空间。**
-- 引擎负责把物理/DPI 缩放坐标换算到该空间，调用方无需感知 DPI。
--
-- 实测依据（Windows 150% 缩放，LÖVE 11.5，conf.lua 开启
-- highdpi + usedpiscale）：
--   setPosition(1023, 767) → getPosition 返回 (1023, 767)   比值 1.000
--   setPosition( 100,  80) → getPosition 返回 ( 100,  80)   比值 1.000
-- 即 love.mouse.getPosition() 已经是逻辑坐标，love2d 实现无需换算。
--
-- 未验证平台：macOS Retina、Android。若实测发现返回物理像素，
-- 在该引擎实现内部加换算（如 love.window.toDensity），**契约不变**。
--
-- 无鼠标的引擎（mud/web）返回 -1, -1（而非 nil，避免调用方做 nil 判断）。
--
-- @return number x, y
function M.input.mousePosition() end

--- 查询鼠标按键是否按下
--
-- 注意：这是**状态查询**（按住期间持续为 true），不是事件。
-- 需要「一次点击只触发一次」时必须做边沿检测，或使用鼠标事件队列
-- （见 input_manager 的 enqueueMouseEvent / getMouseEvent）。
--
-- @param button number 1=左键 2=右键 3=中键
-- @return boolean
function M.input.mouseButton(button) end

--- 读取一个物理轴（每帧状态查询，不是事件）
--
-- **轴名闭集（6 个，与 SDL / Godot / Unreal 一致）**：
--   leftx  lefty  rightx  righty  triggerleft  triggerright
--
-- 返回 -1..1（扳机 0..1）。非法轴名或引擎无手柄时返回 0。
--
-- 为什么是「物理轴」而不是「移动/瞄准」：后两者是 Hades 类玩法的惯例，
-- 不是输入语义。框架只提供物理量，玩法语义由游戏用 defineVector 自声明
-- （见 openspec/changes/input-action-layer/design.md ADR-4）。
--
-- @param name string 轴名（6 个闭集之一）
-- @return number -1..1（扳机 0..1）；非法名/无设备返回 0
function M.input.getAxis(name) end

--- 查询输入能力（哪些设备可用）
--
-- 返回表：{ pointer=bool, touch=bool, gamepad=bool, vr=bool }
--
-- 为什么需要它：调用方目前靠 `mousePosition()` 返回 -1,-1 来猜「没有鼠标」，
-- 而「没有鼠标」与「鼠标在屏幕外」是两件事。设备种类变多后哨兵值会越来越脆。
--
-- vr 目前恒为 false —— 契约留槽不实现（design.md ADR-7）。
--
-- @return table { pointer, touch, gamepad, vr }
function M.input.getCapabilities() end

--- 指针位置（每帧状态查询，"位置"而非"位移"）
--
-- 与 mousePosition() 的差别：
--   mousePosition() 是历史接口，语义绑定鼠标；
--   getPointerPosition() 是设备无关的指针抽象（鼠标/触摸/VR 射线命中点）。
--
-- 为什么是轮询而不是事件：光标位置与「命中区」是两个独立变化的东西。
-- 菜单滚动/换页后光标没动但命中区变了，事件驱动会漏（这是既有 pollHover
-- 的实测结论）。用「位置」语义对鼠标/触摸/手柄选单光标/VR 射线都统一。
--
-- 无指针设备时返回 -1, -1（不是 nil，避免调用方做 nil 判断）。
--
-- @return number x, y
function M.input.getPointerPosition() end

--- 取出一个语义动作（非阻塞，事件通道）
--
-- 返回动作名（如 "ui.accept"）或 nil。
--
-- 与 getKey() 的关系：**并存**。getKey() 返回整数 VK（迁移期 36 处调用点仍用），
-- pollAction() 返回语义动作字符串。两者读的是不同队列，互不挤占
-- （design.md ADR-5 双通道 / ADR-8 迁移期两套并存）。
--
-- @return string|nil 动作名；队列空返回 nil
function M.input.pollAction() end

--- 读取当前所有触摸点
--
-- 返回 { {id=, x=, y=}, ... }，坐标是**逻辑像素**（与布局表同一坐标系）。
--
-- 注意实现必须用 LÖVE 11.5 的 API：
--   love.touch.getTouches() + love.touch.getPosition(id)
-- 而不是 0.10.x 的 getTouchCount() / getTouch(i)（11.5 上不存在）。
--
-- 无触摸能力的引擎返回空表（不是 nil，避免调用方做 nil 判断）。
--
-- @return table { {id=, x=, y=}, ... }
function M.input.getTouches() end

--------------------------------------------------------------------
-- audio - 音频系统
--------------------------------------------------------------------
M.audio = {}

-- ┌──────────────────────┬──────────────────────────┬─────────────────────┐
-- │ 你想做什么            │ 用哪个契约                │ 由谁负责            │
-- ├──────────────────────┼──────────────────────────┼─────────────────────┤
-- │ 播游戏的 BGM（编号）   │ audio.playSequence(id)   │ 模板+候选+sound 回落 │
-- │ 播一个已知的完整文件   │ audio.playMusic(filename)│ 只做 newSource       │
-- │ 播音效                │ audio.playSFX(filename)  │ 只做 newSource       │
-- │ 停止音乐              │ audio.stopMusic()        │ 释放当前 source      │
-- │ 播开场视频            │ audio.playVideo(...)     │ 视频优先，无能力回 false│
-- └──────────────────────┴──────────────────────────┴─────────────────────┘
--
-- **反例（实测踩过）**：script 层用 `playMusic(string.format(CC.MIDIFile, id+1))`
-- 播 BGM。看似可行，但把「模板 / 偏移 / 扩展名候选 / sound 回落」四件事
-- 全留在了调用方看不见的地方 —— 换引擎时新实现只能靠猜。

--- 播放背景音乐（流式，**按完整文件名**）
--
-- 语义：filename 是**已经拼好的路径**（含扩展名）。本契约
-- **SHALL NOT** 做扩展名推测，也 **SHALL NOT** 做 `sound/` 回落。
--
-- 游戏内 BGM 请走 `playSequence(id)`（它才有模板 + 候选 + 回落语义）；
-- `playMusic` 面向工具/测试/未来的剧情音效。
--
-- @param filename string 完整音乐文件路径（含扩展名）
function M.audio.playMusic(filename) end

--- 播放音效（静态）
-- @param filename string 音效文件路径
function M.audio.playSFX(filename) end

--- 停止音乐
function M.audio.stopMusic() end

--- 按**游戏音乐编号**播放（不是文件名）
--
-- 引擎 SHALL 依次做四件事（全部原在 `lib_love.PlayMIDI` 里，现在进契约）：
--   1. 取 `app.setMusicTemplate` 注册的模板与偏移，
--      拼出 stem = `string.format(template, id + startOffset)`
--   2. 按 `{.ogg, .mid, .mp3}` 顺序找存在的候选（顺序见 setMusicTemplate）
--   3. 都找不到 → 回落「打包内置 `sound/` 下的同名文件」
--      （背景：MOD 引用的音乐编号可能多于它实际带的曲目，
--        例如 BookCalamity 引用到 51 但只带 0..23；没有回落会比改造前更差）
--   4. 循环播放
--
-- **只收 number**：收字符串说明调用方走错了契约（应改用 `playMusic`），
-- 实现 SHALL 记日志并返回 false，不得静默当文件名用。
--
-- @param id number 游戏音乐编号（负数/模板未注册 → 不播，返回 false）
-- @return boolean 是否真的开始播放
function M.audio.playSequence(id, opts) end

--- 播放视频（MPEG 等）
--
-- **语义**：引擎 SHALL 尝试真视频播放；无视频能力时 SHALL 回退音频路径
-- （多半失败，但不得抛错），并明确返回 `false`。
--
-- 中断键语义：原版 `lib.PlayMPEG(path, VK_ESCAPE)` 的第二个参数是
-- 「按这个键可跳过」。
--
-- **返回值语义**（修了一个错）：真视频播完 = `true`；
-- 被跳过 / 无视频能力 / 文件缺失 = `false`。
-- 原 LÖVE 实现无条件 `return true`，而 `game/data/start.mpg` 根本不存在
-- （实测 `find` 零命中）—— 等于永远在上报「播成功了」。
--
-- @param filename string 视频路径
-- @param skipKey number|nil 跳过键的 VK 码
-- @return boolean 是否完整播放
-- @return boolean 是否完整播放（false = 被跳过）
function M.audio.playVideo(filename, skipKey) end

--- 开关键盘重复
--
-- @param delay number 首次重复延迟（毫秒）
-- @param interval number 重复间隔（毫秒）
function M.input.enableKeyRepeat(delay, interval) end

--- 设置音乐音量
--
-- 量程 **0-128**，与原版 SDL_mixer 的 `Mix_Volume` 一致。
-- 引擎内部按**线性**映射到 LÖVE 的 `Source:setVolume`（增益 = value/128），
-- 因为两者都是线性振幅，这是精确等值映射。
--
-- 实现要求：既立即应用到正在播放的音乐，也作为后续 newSource 的初值
-- （推 + 拉）。不得用 `love.audio.setVolume`（那是全局音量，
-- 无法区分音乐与音效）。
--
-- @param value number 0-128
function M.audio.setMusicVolume(value) end

--- 取当前音乐音量
-- @return number 0-128
function M.audio.getMusicVolume() end

--- 设置音效音量
--
-- 量程 **0-128**，增益 = value/128。
-- 音效 source 即用即弃（不保留引用），因此只能「拉」：在每次创建
-- 音效 source 时应用。已在播放的短音效不受事后调节影响。
--
-- @param value number 0-128
function M.audio.setSFXVolume(value) end

--- 取当前音效音量
-- @return number 0-128
function M.audio.getSFXVolume() end

--------------------------------------------------------------------
-- time - 计时系统
--------------------------------------------------------------------
M.time = {}

--- 等待指定时间
-- @yieldable
-- @param millis number 毫秒
function M.time.sleep(millis) end

--- 获取当前时间
-- @return number 毫秒
function M.time.getTime() end

--- 获取当前时间（秒）
-- @return number 秒
function M.time.getTimeSeconds() end

--- 取「本地墙上时间」并格式化（存档时间戳 / 日志时间戳）
--
-- **为什么必须在契约里，而不是让 framework 用 getTimeSeconds 自己算**：
--   `getTimeSeconds` 的语义是**单调计时**（LÖVE 是 love.timer.getTime()，
--   起点为进程启动；MUD/Web/Test 是 os.clock()，起点近似 CPU 时间）。
--   两者都**不是 Unix 纪元秒**，拿它做 Y-M-D 会得到 1970-01-01 之类的
--   假日期，而且每次启动都一样 —— 存档里的「死亡时间」会变成明显错误的数据。
--
--   「本地日期时间」的来源（os.date / Time.get_datetime_dict_from_system /
--   FDateTime::Now）是**平台能力**，只有引擎知道，所以必须走契约。
--
-- 实现约定（4 引擎均已实现）：
--   love2d → os.date(fmt)
--   mud    → os.date(fmt)（文本引擎跑在宿主 Lua 上，语义一致）
--   web    → os.date(fmt)（Fengari 提供标准库；取不到时返回 ""）
--   test   → os.date(fmt)，并支持 time.setNow() 注入固定串便于确定性断言
--
-- 任何实现都**不得**抛错；无法产出时返回 ""，调用方按「无时间戳」降级。
--
-- 调用方：framework/clock.lua（framework 唯一读墙上时间的地方）。
--
-- @param fmt string|nil os.date 风格格式串，默认 "%Y-%m-%d %H:%M"
-- @return string 本地时间字符串；不可用时返回 ""
function M.time.formatNow(fmt) end

--------------------------------------------------------------------
-- file - 文件系统
--------------------------------------------------------------------
M.file = {}

--- 打开文件
-- @param filename string 文件路径
-- @param mode string 打开模式 "r"/"w"/"rb"/"wb"
-- @return table|nil 文件句柄
function M.file.open(filename, mode) end

--- 打开原始文件句柄（引擎原生格式，用于底层 FileHandle 封装）
-- @param filename string 文件路径
-- @param mode string 打开模式
-- @return table|nil 引擎原生文件对象
function M.file.openFile(filename, mode) end

--- 删除文件
-- @param filename string 文件路径
function M.file.remove(filename) end

--- 获取文件大小
-- @param filename string 文件路径
-- @return number 文件大小（字节），-1 表示失败
function M.file.getSize(filename) end

--- 检查文件是否存在
-- @param filename string 文件路径
-- @return boolean
function M.file.exists(filename) end

--- 获取文件信息（大小/修改时间等）
-- @param filename string 文件路径
-- @return table|nil "{size, modtime, type}"，不存在时返回 nil
function M.file.getInfo(filename) end

--- 读取文件内容
function M.file.read(filename) end

--- 写入文件
function M.file.write(filename, content, mode) end

--- 逐行读取文件
function M.file.lines(filename) end

--- 创建目录
function M.file.createDirectory(dirpath) end

--- 检查目录是否存在
-- 必须与「文件是否存在」区分：MOD 音效回退、fight 文件枚举都依赖它。
-- @param dirpath string 目录路径
-- @return boolean
function M.file.directoryExists(dirpath) end

--- 列出目录下的条目名（仅名字，不含路径；不含 "." 与 ".."）
-- 目录不存在或无法列举时返回空表（不返回 nil，便于直接 ipairs）。
-- @param dirpath string 目录路径
-- @return table 名字数组
function M.file.listDirectory(dirpath) end

--------------------------------------------------------------------
-- script - 脚本加载
--------------------------------------------------------------------
M.script = {}

--- 加载并执行 Lua 脚本文件
-- @param path string 脚本文件路径
-- @return function|nil 加载的函数，失败返回 nil
-- @return string|nil 错误信息
function M.script.load(path) end

--------------------------------------------------------------------
-- font - 字体系统
--------------------------------------------------------------------
M.font = {}

--- 获取字体对象
-- @param fontName string|nil 字体名称
-- @param size number 字体大小
-- @return table 字体对象
function M.font.get(fontName, size) end

--- 量一段文本的真实像素宽度
--
-- **为什么需要它**：TextBoxLayout.textWidth 目前用 em 估算
-- （汉字 1.0em / ASCII 0.5em）。这个估算在 simsun.ttf 上实测**精确**
-- （16/24/32 三个字号 × 19 个代表性文本，偏差全部 0.00px），
-- 但换到非等宽字体（Godot 默认字体、Unreal 默认字体）必然偏差。
--
-- 因此 textWidth 会**优先**用本函数；本函数不存在时退回 em 估算。
-- 实现必须返回 number；无法度量时返回 nil（调用方会 fallback），不得抛错。
--
-- @param str string 文本
-- @param size number 字号
-- @param fontName string|nil 字体名
-- @return number|nil 像素宽度
function M.font.measureText(str, size, fontName) end

--------------------------------------------------------------------
-- dialog - 对话框（语义级）
--------------------------------------------------------------------
-- 为什么是语义级而不是原语级：
--   对话框的排版（换行 / 框宽 / 行高 / 锚点）属于「渲染介质相关」决策。
--   Love2D 有真实字体度量（font:getWidth / getHeight），可以精确排版；
--   mud 无图形输出（对话框无意义）；web 的字体是浏览器决定。
--   Lua 层若自己算坐标，就得读 CC.DefaultFont 这类常量，在 mud/web 上
--   纯属浪费且不反映真实排版。
--
--   这与本 EngineAPI 中已有的语义级调用保持一致：
--     M.map.drawScene(sceneId, x, y, offX, offY, playerPic)
--   Lua 只说「画这个场景」，引擎自己决定怎么画。
--
-- 为什么是三段式（measure / draw / clear）而不是单个 showDialog：
--   engine-love2d/lib_love.lua 的 ShowSurface 只在 inDrawLoop 为真时
--   调用 love.graphics.present()，而 inDrawLoop 只在 love.draw() 内为真。
--   引擎无法在 showDialog 内部阻塞式画完再返回，因此必须拆成：
--     measure  纯计算（可随时调用，无副作用，便于单测）
--     draw     仅在 love.draw() 内调用
--     clear    清除状态
M.dialog = {}

--- 排版计算（纯函数，不绘制、不阻塞、不写全局状态）
-- @param spec table 对话描述
--   text    string 对话文本，`*` 为强制断行符
--   headId  number 头像编号，-1 表示不显示
--   flag    number 对话框位置 0-5
-- @return table|nil layout
--   width       number 框宽（像素，已含内边距）
--   height      number 框高（像素）
--   lineHeight  number 行高（像素，取真实 getHeight）
--   lines       table  行数组
--   pages       number 总页数
--   headBox     table  { x, y, w, h } 头像框，headId<0 时无
--   textBox     table  { x, y, w, h } 对话框
function M.dialog.measure(spec) end

--- 绘制对话（只能在 love.draw() 内调用）
-- @param spec table 与 measure 相同的对话描述
-- @param layout table measure 的返回值
function M.dialog.draw(spec, layout) end

--- 清除对话状态（幂等）
function M.dialog.clear() end

--------------------------------------------------------------------
-- color - 颜色工具
--------------------------------------------------------------------
M.color = {}

--- 打包 0-255 整数为 packed int
-- @param r, g, b number 0-255
-- @return number packed int
function M.color.pack(r, g, b) end

--- 解包为 0-1 浮点数
-- @param color number packed int
-- @return number r, g, b (0-1)
function M.color.unpack(color) end

--------------------------------------------------------------------
-- debug - 调试日志
--------------------------------------------------------------------
M.debug = {}

--- 输出调试日志
-- @param ... any
function M.debug.log(...) end

--------------------------------------------------------------------
-- coroutine - 协程支持
--------------------------------------------------------------------
M.coroutine = {}

--- 检测是否在协程中
-- @return boolean
function M.coroutine.isRunning() end

--------------------------------------------------------------------
-- app - 应用程序控制
--------------------------------------------------------------------
M.app = {}

--- 退出游戏
function M.app.quit() end

--- 装好整个运行时（**新引擎唯一必须实现的「启动」契约**）
--
-- 这个函数把「引擎实现好 97 个契约之后，怎么把它们串成一个能跑的游戏」
-- 这段知识从入口程序搬进了 framework。以前的状况是：启动序列写在
-- `game/main.lua` 的 `love.load()` 里（147 行，含 6 个必需步骤和顺序），
-- 新引擎作者必须逐行读那个文件才能知道该做什么 —— 而这些知识
-- **一条都不在本契约文件里**。
--
-- ## 实现要求
--
-- LÖVE 之外的所有引擎可以**直接空实现**（`function M.app.install() end`），
-- 因为真正的工作在 `framework/boot.lua` 里：
--
--   1. `require "framework.config"`（加载 CONFIG）
--   2. `Byte = require "framework.lib_Byte"`
--   3. 调 `EngineAPI.init()`（**历史隐式契约**，见下方说明）
--   4. `EventBridge.getInstance():init()`
--   5. `require(CONFIG.ScriptPath .. "jymain")`（加载游戏逻辑与 CC）
--   6. `JYMainAdapter.init()`
--   7. 把宿主提供的钩子存起来（淡入淡出、截图、退出等）
--
-- ## 参数 runtime：宿主能力（**不是**引擎契约的一部分）
--
-- 有些能力只有宿主知道（比如「退出整个应用」在 Godot 是
-- `get_tree().quit()`，在 LÖVE 是 `love.event.quit()`）。它们**不**该
-- 变成 97 个引擎契约里的新条目，而应由宿主以表的形式传进来：
--
-- ```lua
-- EngineAPI.app.install({
--     quit           = function() ... end,   -- 退出应用
--     onError        = function(msg) ... end,-- 致命错误（可选）
--     assetDir       = "...",                -- 资源根（可选，默认 "game/"）
--     requestFullscreen = function() ... end,-- 全屏切换（可选）
-- })
-- ```
--
-- 未提供的钩子一律降级（记日志、不抛错）—— 这样最小宿主（MUD / 测试桩）
-- 只要传一个空表就能跑。
--
-- ## 关于 `EngineAPI.init()`
--
-- 它在 `engine_api.lua` 里**曾经没有声明**（历史遗留），但 LÖVE / MUD /
-- 测试桩三个引擎都实现了，入口程序也一直在调。本契约引入后，
-- `app.install` 会替调用方调它，所以新引擎仍需要提供 `init`
-- （可以是空实现）。见 `framework/boot.lua` 的 `Boot.install`。
--
-- @param runtime table|nil 宿主能力表（见上；nil 等价于空表）
-- @return boolean 是否启动成功（失败时已记日志，调用方别再抛）
function M.app.install(runtime) end

--- 宿主能力：退出应用（`app.install` 传入的钩子，供 framework 内部调用）
--
-- 有了这个契约，`framework` 里就不用 `pcall(function() <某个引擎的退出函数> end)`
-- 式地猜了。未注册时返回 false（不抛错）。
--
-- @return boolean 是否真的触发了退出
function M.app.requestQuit() end

--- 注册音乐文件名模板（游戏启动时调用一次）
--
-- **为什么必须有这个契约**：原版 `PlayMIDI(id)` 内部把 id 变成文件名，
-- 而「模板 + id 偏移」是**游戏资产约定**（`CC.MIDIFile = "sound/game%02d"`，
-- 且 MOD 构建期把 `music/<id>.mid` 改名为 `game<id+1>.mid` → 偏移 = 1）。
-- 这三件事（模板、偏移、扩展名候选）如果不进契约，每个新引擎都要自己发现。
--
-- 传进来的模板 **SHALL NOT 含扩展名**：
--   引擎自己按 `{.ogg, .mid, .mp3}` 顺序找候选（顺序与原 lib_love 一致，
--   `.ogg` 优先是因为它是 SoundFont 渲染版，音质最好；`.mid` 只作兜底）。
--   模板带扩展名会让「哪些部分是模板、哪些是候选」变得无法判断。
--
-- 调用方：`JYMainAdapter.init`（必须在第一次 `PlayMIDI` 之前）。
--
-- @param template string printf 风格模板，如 "sound/game%02d"（不含扩展名）
-- @param startOffset number id → 模板参数的偏移（实测游戏用 1）
function M.app.setMusicTemplate(template, startOffset) end

--- 切换全屏/窗口模式（对应 `lib.FullScreen`）
--
-- 各引擎的形态不同：LÖVE 是 `love.graphics.toggleFullscreen()`，
-- Godot 是 `DisplayServer.window_set_mode()`，Web 可能是 no-op
-- 或 `element.requestFullscreen()`。所以需要契约。
--
-- @return boolean 是否真的切换了（无图形能力的引擎返回 false）
function M.app.toggleFullscreen() end

--------------------------------------------------------------------
-- system - 系统/平台信息
--
-- 用途：让「平台差异化默认值」有一个引擎无关的来源。
-- 例如鼠标操作开关：桌面默认开、Android 默认关（Android 可接鼠标，
-- 但其主要输入方式是虚拟按键）。
--
-- 为什么需要独立模块而不是各调用点自己写 love.system.getOS()：
--   framework/ 的约定是「只通过 EngineAPI 调引擎」，散落的具体引擎调用
--   会让 framework 依赖 love，破坏既有的分层（见 ADR-MS-001）。
--------------------------------------------------------------------
M.system = {}

--- 取当前运行平台
--
-- 返回值限定集合（调用方可以放心用字符串相等判断）：
--   "Windows" | "Linux" | "macOS" | "Android" | "iOS" | "web" | "unknown"
--
-- 实现差异（必须遵守）：
--   love2d  → love.system.getOS()
--   mud     → "unknown"（无平台概念）
--   web     → **硬编码 "web"**，不得透传 love.system
--             （LÖVE 的 web 构建理论上返回 "Linux"，会让平台的
--              鼠标默认值误判为「桌面开」，导致 web 端以为有鼠标）
--   test    → 可注入（便于测试各平台分支）
--
-- @return string
function M.system.getOS() end

return M