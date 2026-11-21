-- engine_api.lua
-- EngineAPI 接口定义
-- 所有引擎（Love2D/Godot/测试引擎）必须实现此接口
--
-- @yieldable 标记表示该函数可能触发 coroutine.yield()
-- 非 @yieldable 函数入队后立即返回，不会阻塞

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
function M.render.setDrawLoopFlag(flag) end

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

--- 播放背景音乐（流式）
-- @param filename string 音乐文件路径
function M.audio.playMusic(filename) end

--- 播放音效（静态）
-- @param filename string 音效文件路径
function M.audio.playSFX(filename) end

--- 停止音乐
function M.audio.stopMusic() end

--- 播放序列音频（按索引，不是文件名）
--
-- 与 playMusic(filename) 的区别：原版 `lib.PlayMIDI(CC.MIDIFile, id+1)`
-- 是按**索引**在资源清单里选，不是按文件名。两者语义不同，
-- 所以拆成两个函数而不是强行合一个。
--
-- @param id number 序列编号（负数表示停止）
-- @param opts table|nil { loop=true }（默认循环）
function M.audio.playSequence(id, opts) end

--- 播放视频（MPEG 等）
--
-- 中断键语义：原版 `lib.PlayMPEG(path, VK_ESCAPE)` 的第二个参数是
-- 「按这个键可跳过」。引擎实现必须支持跳过，否则玩家会被卡住。
--
-- @param filename string 视频路径
-- @param skipKey number|nil 跳过键的 VK 码
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