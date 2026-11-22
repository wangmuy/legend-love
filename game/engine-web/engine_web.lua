-- engine_web.lua
-- Web/terminal EngineAPI implementation for Fengari Lua VM in browser
-- All engine operations mapped to ANSI output + JSBridge communication

local EngineAPI = {}

--------------------------------------------------------------------------------
-- render - ANSI text rendering
--------------------------------------------------------------------------------
EngineAPI.render = {}
local renderBuffer = {}

-- Web 文本版：屏幕不真正的清除（render.present 为无操作），Lua 侧每帧都会用同样
-- (x,y,str) 重绘菜单项/地图标注等，导致终端逐帧累积出大量重复行（用户反馈“对话后
-- 菜单显示2次”）。这里按坐标去重：同一 (x,y) 写入相同文本时，若无变化则不再重复输出，
-- 从而把每帧重绘的同一内容收敛为一行；内容改变或坐标改变时照常输出。
local _renderKey = {}

local function colorToAnsi(color)
    if not color then return "\027[37m" end
    local r, g, b
    if type(color) == "number" then
        r = math.floor(color / 65536)
        g = math.floor((color % 65536) / 256)
        b = color % 256
    else
        r = math.floor(color[1] * 255)
        g = math.floor(color[2] * 255)
        b = math.floor(color[3] * 255)
    end
    if r > 200 and g > 200 and b > 200 then return "\027[37m"
    elseif r > 200 and g < 100 and b < 100 then return "\027[31m"
    elseif r > 200 and g > 100 and b < 50 then return "\027[33m"
    elseif r < 50 and g < 50 and b < 50 then return "\027[30m"
    elseif r > 100 and g > 100 and b < 100 then return "\027[93m"
    else return "\027[37m" end
end

function EngineAPI.render.text(x, y, str, color, size)
    -- Worker 模式下 ANSI escape 通过 postMessage 会损坏，改用直接文本输出
    local w = rawget(_G, "WebUI")
    if not w or not w.write then return end
    local s = tostring(str)
    -- 坐标去重：同一 (x,y) 无变化不重复输出（收敛每帧重绘的菜单项，避免终端累积重复行）
    local kx = math.floor(x or 0)
    local ky = math.floor(y or 0)
    local key = kx * 10000 + ky
    if _renderKey[key] == s then
        return
    end
    _renderKey[key] = s
    w.write(s)
end

function EngineAPI.render.fillRect(x1, y1, x2, y2, color) end

function EngineAPI.render.rectOutline(x1, y1, x2, y2, color) end

function EngineAPI.render.drawBackground(x1, y1, x2, y2, brightness)
    -- Worker 模式下不做 ANSI 输出
end

function EngineAPI.render.setClip(x1, y1, x2, y2) end
EngineAPI.render.SetClip = EngineAPI.render.setClip

function EngineAPI.render.getClip()
    return { x = 0, y = 0, w = 1024, h = 768 }
end

function EngineAPI.render.present()
    -- Worker 模式下 renderBuffer 为空（text 已直接写 WebUI），present 不做操作
    renderBuffer = {}
end

--- 取渲染尺寸：web 是 xterm 终端，返回固定哨兵值
function EngineAPI.render.getWidth()
    return 1024
end

function EngineAPI.render.getHeight()
    return 768
end

function EngineAPI.render.presentAndWait(delay)
    EngineAPI.render.present()
    pcall(coroutine.yield)
end

--- 帧绘制回调标志：Web 文本版无真实「帧绘制」，只记录状态
--
--- 为什么要实现：`game/main.lua` 的 love.draw 前后会调它；Web 不加载 main.lua，
--- 但契约必须存在（「换引擎只需写 engine-xxx」要求 4 引擎对齐）。
local webInDrawLoop = false
function EngineAPI.render.setDrawLoopFlag(flag)
    webInDrawLoop = not not flag
end

-- Compatibility stubs for JY game engine functions
function EngineAPI.render.FillColor(x1, y1, x2, y2, color) end
function EngineAPI.render.Cls(x1, y1, x2, y2) 
    EngineAPI.render.setClip(x1 or 0, y1 or 0, x2 or 0, y2 or 0)
    EngineAPI.render.drawBackground(x1 or 0, y1 or 0, x2 or 0, y2 or 0, 0)
end
function EngineAPI.render.DrawString(x, y, str, color, size)
    EngineAPI.render.text(x, y, str, color, size)
end
function EngineAPI.render.DrawStr(x, y, str, color, size, font)
    EngineAPI.render.text(x, y, str, color, size)
end
function EngineAPI.render.ShowScreen()
    EngineAPI.render.present()
end
function EngineAPI.render.ShowSurface(flag)
    EngineAPI.render.present()
end
function EngineAPI.render.LoadPicture(filename, x, y) end
function EngineAPI.render.DrawMMap(playerX, playerY, playerPic) end
function EngineAPI.render.PicInit(paletteFilename) end
function EngineAPI.render.ShowSlow(delaytime, flag) end
function EngineAPI.render.PlayMIDI(filename) end
function EngineAPI.render.PlayMPEG(filename, escKey) end

--------------------------------------------------------------------------------
-- sprite - no-op
--------------------------------------------------------------------------------
EngineAPI.sprite = {}

function EngineAPI.sprite.initSprites() end

-- **`sprite.loadArchive` / `sprite.draw` / `sprite.drawTinted` 已删除**
-- （port-legacy-picture-removal）：零消费者，Web 本就无图形渲染。

--- 从 RGBA 字节创建纹理：web 无纹理概念，返回哨兵 handle
function EngineAPI.sprite.createFromRGBA(w, h, rgbaBytes, opts)
    -- 参数校验与 LOVE/MUD 一致（契约行为一致性）
    if type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then return nil end
    if type(rgbaBytes) ~= "string" or #rgbaBytes < w * h * 4 then return nil end
    opts = opts or {}
    return { w = w, h = h, xoff = opts.xoff or 0, yoff = opts.yoff or 0 }
end

--- 从编码字节创建纹理：web 无解码能力
function EngineAPI.sprite.createFromEncoded(bytes, formatHint, opts)
    if type(bytes) ~= "string" or bytes == "" then return nil end
    opts = opts or {}
    return { w = 0, h = 0, xoff = opts.xoff or 0, yoff = opts.yoff or 0 }
end

--- 绘制独立图片：web 无图形概念
function EngineAPI.sprite.drawPictureFile(filename, x, y, opts)
    return false
end

--- 绘制句柄：web 无图形
function EngineAPI.sprite.drawHandle(handle, x, y, flags, alpha)
    return false
end

function EngineAPI.sprite.drawHandleTinted(handle, x, y, color, alpha)
    return false
end

--- 取元数据
function EngineAPI.sprite.getMeta(handle)
    if type(handle) ~= "table" then return nil end
    return { w = handle.w or 0, h = handle.h or 0,
             xoff = handle.xoff or 0, yoff = handle.yoff or 0 }
end

--------------------------------------------------------------------------------
-- map - no-op
--------------------------------------------------------------------------------
EngineAPI.map = {}

function EngineAPI.map.loadMain(earthFile, surfaceFile, buildingFile, buildXFile, buildYFile, width, height, x, y) end

function EngineAPI.map.loadScene(sFile, tmpFile, num, width, height, dFile, dNum1, dNum2) end

function EngineAPI.map.saveScene(sFile, dFile) end

function EngineAPI.map.loadBattle(idxFile, grpFile, mapId, num, width, height) end

function EngineAPI.map.drawMain(playerX, playerY, playerPic) end

--- 地图瓦片：web 无地图数据，返回越界哨兵 -1
function EngineAPI.map.getTile(x, y, layer)
    return -1
end
function EngineAPI.map.setTile(x, y, layer, value) end

function EngineAPI.map.getSceneTile(sceneId, x, y, layer)
    return 0
end

function EngineAPI.map.setSceneTile(sceneId, x, y, layer, value) end

function EngineAPI.map.getSceneEventData(sceneId, eventId, field)
    return 0
end

function EngineAPI.map.setSceneEventData(sceneId, eventId, field, value) end

function EngineAPI.map.getBattleTile(x, y, layer)
    return 0
end

function EngineAPI.map.setBattleTile(x, y, layer, value) end

function EngineAPI.map.clearBattleTile(layer, value) end

function EngineAPI.map.getSceneSize()
    return { w = 64, h = 64 }
end

function EngineAPI.sprite.clearPictureCache() end

function EngineAPI.map.loadClouds(idxFile, grpFile) end

function EngineAPI.map.getBattleSize()
    return { w = 64, h = 64 }
end

function EngineAPI.map.drawClouds(mx, my) end

function EngineAPI.map.unload() end

function EngineAPI.map.tickClouds() end

function EngineAPI.map.drawScene(sceneId, x, y, offX, offY, playerPic) end

function EngineAPI.map.drawBattle(flag, x, y, v1, v2, v3) end

--------------------------------------------------------------------------------
-- input - JSBridge event stream
--------------------------------------------------------------------------------
EngineAPI.input = {}

function EngineAPI.input.getKey()
    if _G.JSBridge and _G.JSBridge.getEventCount and _G.JSBridge.getEventCount() > 0 then
        local evt = _G.JSBridge.getEvent()
        if evt then
            if type(evt) == "number" then return evt end
            if type(evt) == "string" then return tonumber(evt) or evt:byte() end
            if type(evt) == "table" and evt.type == "input" and evt.data then
                local cmd, arg = evt.data:match("^(%S+)%s*(.-)$")
                cmd = cmd and cmd:lower() or ""
                if cmd == "choose" then
                    local n = tonumber(arg)
                    if n == 1 then return 13 end
                    if n == 2 then return 27 end
                    return 13
                end
                return 13
            end
            return -1
        end
    end
    return -1
end

function EngineAPI.input.waitForKey()
    while true do
        if _G.JSBridge and _G.JSBridge.getEventCount and _G.JSBridge.getEventCount() > 0 then
            local evt = _G.JSBridge.getEvent()
            if evt then
                if type(evt) == "number" then return evt end
                if type(evt) == "string" then return tonumber(evt) or evt:byte() end
                return -1
            end
        end
        pcall(coroutine.yield)
    end
end

function EngineAPI.input.setKeyRepeat(delay, interval) end

-- 鼠标（REQ-MS1-2）：web 引擎当前是 xterm 终端桥接，无指针操作概念
--
-- 注意：不要把 pointer 报成 true。终端的"点击"是键盘/命令，不是指针位置。
-- 若将来接浏览器 canvas 渲染，再在 getCapabilities 里改 pointer=true 并实现
-- getPointerPosition（契约不变）。
function EngineAPI.input.mousePosition()
    return -1, -1
end

function EngineAPI.input.mouseButton(button)
    return false
end

-- 物理轴 / 能力 / 指针 / 动作（input-action-layer Task 2）
function EngineAPI.input.getAxis(name)
    return 0
end

function EngineAPI.input.getCapabilities()
    return { pointer = false, touch = false, gamepad = false, vr = false }
end

function EngineAPI.input.getPointerPosition()
    return -1, -1
end

function EngineAPI.input.enableKeyRepeat(delay, interval) end

function EngineAPI.input.pollAction()
    return nil
end

--- 触摸点：web 引擎当前无触摸
function EngineAPI.input.getTouches()
    return {}
end

--------------------------------------------------------------------------------
-- audio - no-op
--------------------------------------------------------------------------------
EngineAPI.audio = {}

function EngineAPI.audio.playMusic(filename) end

function EngineAPI.audio.playSFX(filename) end

function EngineAPI.audio.stopMusic() end

-- 音量（REQ-VOL-1）：web 终端版无音频实现，4 个函数为 no-op 但保留状态，
-- 使 Settings 的读写有一致的回读（未来接 Web Audio 时在此补实现）。
local webMusicVolume = 64
local webSFXVolume = 90

function EngineAPI.audio.setMusicVolume(value)
    webMusicVolume = tonumber(value) or webMusicVolume
end

function EngineAPI.audio.playSequence(filenameOrId, opts)
    return true
end

-- 播放视频：Web 文本版无视频能力 → 如实返回 false（port-audio-semantics）
function EngineAPI.audio.playVideo(filename, skipKey)
    return false
end

function EngineAPI.audio.getMusicVolume()
    return webMusicVolume
end

function EngineAPI.audio.setSFXVolume(value)
    webSFXVolume = tonumber(value) or webSFXVolume
end

function EngineAPI.audio.getSFXVolume()
    return webSFXVolume
end

--------------------------------------------------------------------------------
-- time - coroutine-based timing
--------------------------------------------------------------------------------
EngineAPI.time = {}

function EngineAPI.time.sleep(millis)
    pcall(coroutine.yield)
end

function EngineAPI.time.getTime()
    return os.clock() * 1000
end

function EngineAPI.time.getTimeSeconds()
    return os.clock()
end

-- 本地墙上时间格式化（framework-io-portability）
--
-- 与 getTimeSeconds 的区别：后者是**单调计时**（os.clock），不是纪元秒，
-- 算不出真实日期。Fengari（浏览器里的 Lua VM）提供标准库 os.date，
-- 因此这里直接用它；某些受限运行环境裁掉了 os.date 时返回 ""，
-- 调用方（framework/clock.lua）会按「无时间戳」降级，不崩。
function EngineAPI.time.formatNow(fmt)
    fmt = fmt or "%Y-%m-%d %H:%M"
    if type(os) ~= "table" or type(os.date) ~= "function" then return "" end
    local ok, s = pcall(os.date, fmt)
    if ok and type(s) == "string" then return s end
    return ""
end

--------------------------------------------------------------------------------
-- file - initDataSource based read-only file system
--------------------------------------------------------------------------------
EngineAPI.file = {}

function EngineAPI.file.open(filename, mode)
    if mode and mode:sub(1, 1) == "r" then
        local content = _G.rawDataCache and _G.rawDataCache[filename]
        if content then
            local handle = {
                _content = content,
                _pos = 1,
                read = function(self, fmt)
                    if fmt == "*a" or fmt == "*all" then
                        return self._content
                    end
                    if fmt == "*l" or fmt == "*line" then
                        if self._pos > #self._content then return nil end
                        local _, e = self._content:find("\n", self._pos)
                        if e then
                            local line = self._content:sub(self._pos, e - 1)
                            self._pos = e + 1
                            return line
                        else
                            local line = self._content:sub(self._pos)
                            self._pos = #self._content + 1
                            return line
                        end
                    end
                    if type(fmt) == "number" then
                        local chunk = self._content:sub(self._pos, self._pos + fmt - 1)
                        self._pos = self._pos + fmt
                        return chunk
                    end
                    return self._content
                end,
                close = function() end,
                seek = function(_, whence, offset)
                    if whence == "set" then
                        self._pos = (offset or 0) + 1
                    elseif whence == "end" then
                        self._pos = #self._content - (offset or 0)
                    else
                        self._pos = self._pos + (offset or 0)
                    end
                    return self._pos - 1
                end
            }
            return handle
        end
        return nil
    end
    return nil
end

function EngineAPI.file.openFile(filename, mode)
    return EngineAPI.file.open(filename, mode)
end

function EngineAPI.file.remove(filename) end

function EngineAPI.file.getSize(filename)
    local content = _G.rawDataCache and _G.rawDataCache[filename]
    if content then
        return #content
    end
    return -1
end

function EngineAPI.file.exists(filename)
    return _G.rawDataCache and _G.rawDataCache[filename] ~= nil
end

function EngineAPI.file.getInfo(filename)
    local content = _G.rawDataCache and _G.rawDataCache[filename]
    if content then
        return { size = #content, modtime = nil, type = "file" }
    end
    return nil
end

function EngineAPI.file.read(filename)
    if _G.rawDataCache then
        return _G.rawDataCache[filename]
    end
    return nil
end

function EngineAPI.file.write(filename, content, mode) end

function EngineAPI.file.lines(filename)
    local content = _G.rawDataCache and _G.rawDataCache[filename]
    if not content then
        return function() return nil end
    end
    local lines = {}
    for line in content:gmatch("([^\n]*)\n?") do
        table.insert(lines, line)
    end
    local i = 0
    return function()
        i = i + 1
        return lines[i]
    end
end

function EngineAPI.file.createDirectory(dirpath) end

--- 目录是否存在：web 端无文件系统，返回 false（哨兵）
function EngineAPI.file.directoryExists(dirpath)
    return false
end

--- 列目录：web 端无文件系统，返回空表（哨兵，不是 nil）
function EngineAPI.file.listDirectory(dirpath)
    return {}
end

--------------------------------------------------------------------------------
-- script - load Lua code from initDataSource
--------------------------------------------------------------------------------
EngineAPI.script = {}

function EngineAPI.script.load(path)
    local source = _G.initDataSource and _G.initDataSource[path]
    if not source then
        source = _G.FrameworkSources and _G.FrameworkSources[path]
    end
    if not source then
        return nil, "Script not found: " .. tostring(path)
    end
    local chunk, err = load(source, path)
    if not chunk then
        return nil, err
    end
    return chunk
end

--------------------------------------------------------------------------------
-- font - stub
--------------------------------------------------------------------------------
EngineAPI.font = {}

--- web 无字体度量，返回 nil 让 TextBoxLayout 退回 em 估算
function EngineAPI.font.measureText(str, size, fontName)
    return nil
end

function EngineAPI.font.get(fontName, size)
    return { name = fontName or "monospace", size = size or 14 }
end

--------------------------------------------------------------------------------
-- dialog - stub (web 的对话框由浏览器/DOM 决定，Lua 层不做排版)
--------------------------------------------------------------------------------
EngineAPI.dialog = {}

function EngineAPI.dialog.measure(spec) end

function EngineAPI.dialog.draw(spec, layout) end

function EngineAPI.dialog.clear() end

--------------------------------------------------------------------------------
-- color - pack/unpack tools
--------------------------------------------------------------------------------
EngineAPI.color = {}

function EngineAPI.color.pack(r, g, b)
    return r * 65536 + g * 256 + b
end

function EngineAPI.color.unpack(color)
    local r = math.floor(color / 65536)
    local g = math.floor((color % 65536) / 256)
    local b = color % 256
    return r / 255, g / 255, b / 255
end

--------------------------------------------------------------------------------
-- debug - log via JSBridge
--------------------------------------------------------------------------------
EngineAPI.debug = {}

function EngineAPI.debug.log(...)
    -- MUD 模式下启动后抑制 per-frame 调试输出
    if _G.__quiet then return end
    local parts = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        parts[i] = tostring(v)
    end
    local msg = table.concat(parts, "\t")
    if _G.JSBridge and _G.JSBridge.write then
        _G.JSBridge.write("[DEBUG] " .. msg .. "\n")
    end
end

--------------------------------------------------------------------------------
-- coroutine - coroutine utilities
--------------------------------------------------------------------------------
EngineAPI.coroutine = {}

function EngineAPI.coroutine.isRunning()
    return coroutine.running() ~= nil
end

--------------------------------------------------------------------------------
-- app - application control
--------------------------------------------------------------------------------
EngineAPI.app = {}

function EngineAPI.app.toggleFullscreen()
    return false          -- Web 无原生全屏切换（可用 element.requestFullscreen）
end

-- 音乐模板注册（port-audio-semantics）：Web 文本版无音频，只记录
function EngineAPI.app.setMusicTemplate(template, startOffset)
    EngineAPI.app._musicTemplate = (type(template) == "string" and template ~= "")
        and template or nil
    EngineAPI.app._musicStartOffset = tonumber(startOffset) or 0
end

function EngineAPI.app.getMusicTemplate()
    return EngineAPI.app._musicTemplate, EngineAPI.app._musicStartOffset
end

--------------------------------------------------------------------------------
-- system - platform info（REQ-MS1-1）
--
-- **硬编码 "web"，不得透传 love.system.getOS()**：
-- LÖVE 的 web 构建（Emscripten）下 getOS() 理论上返回 "Linux"，
-- 若透传会让 platformDefaults.Linux=true 把 web 端误判为「桌面」，
-- 从而默认开启鼠标（而 web 是 xterm 终端，没有鼠标操作概念）。
--------------------------------------------------------------------------------
EngineAPI.system = EngineAPI.system or {}
EngineAPI.system.getOS = function()
    return "web"
end

-- 通关/结束 BANNER（去重）：同一局可能由多个地方输出“恭喜通关/游戏结束”
-- （时空梭 finale 协程直接打印、GAME_END 状态机 enter→app.quit 各自打印等）。
-- 通过标志保证同一局只展示一次，避免内容重复两次（Issue2 重复根因）。
-- 新游戏开始时调用 resetEndBanner() 重置，保证重玩仍能正常显示。
local endBannerShown = false
rawset(_G, "resetEndBanner", function()
    endBannerShown = false
    rawset(_G, "__gameOver", nil)
end)
function EngineAPI.app.showFinalBanner(lines)
    if endBannerShown then return end
    endBannerShown = true
    local w = rawget(_G, "WebUI")
    if not (w and w.write) then return end
    w.write("\n====================================================\n")
    if lines then
        for _, ln in ipairs(lines) do
            w.write(ln .. "\n")
        end
    end
    w.write("====================================================\n")
end

function EngineAPI.app.quit()
    -- Web MUD：结束/通关时终结交互。
    -- 无真实窗口可关闭，所以向终端输出明确的“游戏结束”结论，并把 JY.Status 固定为
    -- GAME_END(7)，避免玩家在圣堂/场景选择里继续走导致快捷保留/退出混乱的观感。
    -- 通关 BANNER 由 showFinalBanner 去重输出（同一局只显示一次）。
    local JY = rawget(_G, "JY")
    if JY then
        JY.Status = (rawget(_G, "jyconst") and rawget(_G, "jyconst").GAME_END) or 7
    end
    EngineAPI.app.showFinalBanner({
        "    ☆ 游戏结束 / 恭喜通关！☆",
        "    感谢游玩《金庸群侠传 Web MUD》",
        "    你已集齐十四天书，成为武林盟主！",
    })
    -- 标记游戏已结束，命令处理器对后续命令不再使用 BANNER
    rawset(_G, "__gameOver", true)
end

--------------------------------------------------------------------------------
-- Global setup
--------------------------------------------------------------------------------
_G.EngineAPI = EngineAPI

-- **`_G.lib` 已删除**（port-compat-layer-removal）。
--
-- 它曾是 `setmetatable({}, {__index = ...})` 的字符串键别名表（30 余条 if 链），
-- 为 Web 引擎模拟 LÖVE 的 lib API。实测本引擎运行时零 `lib.` 引用，
-- framework/script/入口 也已零 `lib.*` → 无消费者。

return EngineAPI
