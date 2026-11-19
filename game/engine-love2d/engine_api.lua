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

--------------------------------------------------------------------
-- sprite - 精灵/纹理系统
--------------------------------------------------------------------
M.sprite = {}

--- 初始化精灵系统
function M.sprite.initSprites() end

--- 加载精灵档案（idx/grp 文件对）
-- @param idxFile string 索引文件路径
-- @param grpFile string 图片组文件路径
-- @param archiveId number 档案编号
function M.sprite.loadArchive(idxFile, grpFile, archiveId) end

--- 获取精灵尺寸
-- @param archiveId number 档案编号
-- @param spriteId number 精灵编号
-- @return number width, height, xoff, yoff
function M.sprite.getSize(archiveId, spriteId) end

--- 绘制精灵
-- @param archiveId number 档案编号
-- @param spriteId number 精灵编号
-- @param x, y number 绘制位置
-- @param flags number 绘制标志
-- @param alpha number|nil 透明度 0-255
function M.sprite.draw(archiveId, spriteId, x, y, flags, alpha) end

--- 绘制染色精灵
--
-- 与 `sprite.draw` 的区别：用 `color` 表染色，而非位域 flag。
--
-- 为什么需要它（REQ-MS1-3）：
--   现有 `draw` 的颜色能力只有「原色 / 全黑 / 全白」三档
--   （`lib_love.lua` 的 PicLoadCache 用 flag 的 0x4 / 0x8 位）。
--   鼠标功能的「寻路失败红闪」需要红色，现有接口无法表达。
--
-- 为什么用 {r,g,b} 而不是再加一个 flag 位：
--   flag 是原版 PAL 引擎的位域约定，加位会污染该契约，且只能表达有限颜色。
--   {r,g,b} 是通用的颜色概念，引擎无关，且同一个函数能覆盖
--   「悬停高亮（黑）」「红闪（红）」「物品金色高亮」等全部用例。
--
-- spriteId 可任意 —— 不只用于菱形，未来任何精灵都能染色。
--
-- @param archiveId number 档案编号
-- @param spriteId number 精灵编号
-- @param x, y number 绘制位置
-- @param color table {r=, g=, b=} 0-1 浮点；nil 或分量缺失时按原色绘制
-- @param alpha number|nil 透明度 0-255（默认 255）
function M.sprite.drawTinted(archiveId, spriteId, x, y, color, alpha) end

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

--- 标记 yield 点
-- @yieldable
function M.coroutine.yieldPoint() end

--- 等待条件满足
-- @yieldable
-- @param condition function 条件函数
-- @param timeout number|nil 超时（毫秒）
-- @return boolean 条件是否满足
function M.coroutine.waitFor(condition, timeout) end

--------------------------------------------------------------------
-- app - 应用程序控制
--------------------------------------------------------------------
M.app = {}

--- 退出游戏
function M.app.quit() end

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