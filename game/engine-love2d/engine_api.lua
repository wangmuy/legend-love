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
-- @param x1, y1, x2, y2 number 矩形区域
-- @param color table {r, g, b} 0-1 浮点数
function M.render.fillRect(x1, y1, x2, y2, color) end

--- 矩形边框
-- @param x1, y1, x2, y2 number 矩形区域
-- @param color table {r, g, b} 0-1 浮点数
function M.render.rectOutline(x1, y1, x2, y2, color) end

--- 背景框（带阴影效果）
-- @param x1, y1, x2, y2 number 矩形区域
-- @param brightness number 亮度 0-255
function M.render.drawBackground(x1, y1, x2, y2, brightness) end

--- 设置裁剪区域
-- @param x1, y1, x2, y2 number 裁剪区域
function M.render.setClip(x1, y1, x2, y2) end

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

--- 读取文件内容
function M.file.read(filename) end

--- 写入文件
function M.file.write(filename, content, mode) end

--- 逐行读取文件
function M.file.lines(filename) end

--- 创建目录
function M.file.createDirectory(dirpath) end

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

return M