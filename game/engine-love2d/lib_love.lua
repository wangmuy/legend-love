local M = {}
do
    setmetatable(M, { __index = _G, })
    if setfenv then
        setfenv(1, M) -- for 5.1
    else
        _ENV = M -- for 5.2
    end
    if _VERSION < "Lua 5.2" then
        require "framework.luabit"
        bit32 = bit
    end

    if _G and bit32 and not _G.bit32 then
        _G.bit32 = bit32
    end
end

require "framework.config"
local FileUtil = require "framework.lib_file"
-- Use love.filesystem.load for .love file compatibility
local jyconst_loader = love.filesystem.load(CONFIG.ScriptPath .. "jyconst.lua")
if jyconst_loader then
    jyconst_loader()
else
    -- Fallback to dofile for development mode
    dofile(CONFIG.ScriptPath .. "jyconst.lua")
end
SetGlobalConst()
require "framework.lib_log"
local Byte = require "framework.lib_Byte"

keymap = {
    ["escape"] = 27,        -- VK_ESCAPE
    [" "] = 32,             -- VK_SPACE
    ["return"] = 13,        -- VK_RETURN
    ["up"] = 1073741906,    -- VK_UP (SDLK_UP)
    ["down"] = 1073741905,  -- VK_DOWN (SDLK_DOWN)
    ["left"] = 1073741904,  -- VK_LEFT (SDLK_LEFT)
    ["right"] = 1073741903, -- VK_RIGHT (SDLK_RIGHT)
}

function GetKey()
    local InputManager = package.loaded["input_manager"] or package.loaded["framework.input_manager"]
    if InputManager then
        local key = InputManager.getInstance():getKey()
        return key
    end
    
    return -1
end

function EnableKeyRepeat(delay, interval)
    -- 使用事件驱动的输入管理器
    local InputManager = package.loaded["input_manager"] or package.loaded["framework.input_manager"]
    if InputManager then
        local inst = InputManager.getInstance()
        inst:setKeyRepeat(delay > 0)
        if delay > 0 and interval > 0 then
            inst:setKeyRepeatParams(delay / 1000.0, interval / 1000.0)  -- 转换为秒
        end
    else
        -- 回退到原始实现
        if delay > 0 and interval > 0 then
            love.keyboard.setKeyRepeat(true)
        else
            love.keyboard.setKeyRepeat(false)
        end
    end
end

function Delay(millis)
    love.timer.sleep(millis/1000.0)
end

function GetTime()
    return love.timer.getTime() * 1000  -- LOVE 11.x returns seconds, convert to ms
end

-- 字体缓存。
-- 键必须是「字体名 + 字号」：原版 charset.c:68 的 GetFont 正是按
-- (Font[i].size == size && strcmp(filename, Font[i].name)==0) 查表的，
-- 只按文件名缓存会让后请求的字号复用先前的字号（游戏内 16/24 全被画成 20）。
local fontTbl = {}
local defaultFont = nil

-- 原版 DefaultFont 的兜底字号
local DEFAULT_FONT_SIZE = 20

local function getFont(fontname, size)
    size = size or DEFAULT_FONT_SIZE

    -- 无字体名：使用 LÖVE 内置字体，按字号分别缓存
    if fontname==nil then
        if defaultFont == nil then
            defaultFont = {}
        end
        local f = defaultFont[size]
        if f == nil then
            f = love.graphics.newFont(size)
            defaultFont[size] = f
        end
        return f
    end

    local key = fontname .. ":" .. tostring(size)
    if fontTbl[key] == nil then
        local success, font = pcall(function() return love.graphics.newFont(fontname, size) end)
        if success then
            fontTbl[key] = font
        else
            -- 字体文件打不开：退回 LÖVE 内置字体（同样按字号缓存）
            if defaultFont == nil then
                defaultFont = {}
            end
            local f = defaultFont[size]
            if f == nil then
                f = love.graphics.newFont(size)
                defaultFont[size] = f
            end
            fontTbl[key] = f
        end
    end
    return fontTbl[key]
end
  
function DrawStr(x, y, str, color, size, fontname)
    local oldR, oldG, oldB, oldA = love.graphics.getColor()
    love.graphics.setFont(getFont(fontname, size))
    local r, g, b = GetRGB(color)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.print(str, x, y)
    love.graphics.setColor(oldR, oldG, oldB, oldA)
end

--//设置裁剪
function SetClip(x1, y1, x2, y2)
    if x1 == 0 and y1 == 0 and x2 == 0 and y2 == 0 then
        love.graphics.setScissor()
    else
        love.graphics.setScissor(x1, y1, x2-x1, y2-y1)
    end
end

--[[
// 图形填充
// 如果 x1,y1,x2,y2 均为 0，则填充整个表面
// color, 填充色，用 RGB 表示，从高到低字节为 0RGB
--]]
function FillColor(x1, y1, x2, y2, color)
    local r,g,b = GetRGB(color)
    if x1 == 0 and y1 == 0 and x2 == 0 and y2 == 0 then
        -- 清除整个屏幕
        love.graphics.clear(r, g, b)
    else
        -- 只清除指定区域：保存当前scissor，设置新的scissor，绘制矩形，恢复scissor
        local oldScissor = {love.graphics.getScissor()}
        love.graphics.setScissor(x1, y1, x2-x1, y2-y1)
        -- 使用矩形填充而不是clear，因为clear不受scissor影响
        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", x1, y1, x2-x1, y2-y1)
        love.graphics.setColor(1, 1, 1, 1)  -- 恢复默认颜色
        -- 恢复原来的scissor（如果存在）
        if oldScissor[1] then
            love.graphics.setScissor(oldScissor[1], oldScissor[2], oldScissor[3], oldScissor[4])
        else
            love.graphics.setScissor()
        end
    end
end

--[[
// 背景变暗
// 把源表面 (x1,y1,x2,y2) 矩形内的所有点亮度降低
// bright 亮度等级 0-256 --]]
function Background(x1, y1, x2, y2, Bright)
    if x2<x1 or y2<y1 then return end
    local alpha = Bright / 256
    local oldR, oldG, oldB, oldA = love.graphics.getColor()
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.rectangle("fill", x1, y1, x2-x1+1, y2-y1+1)
    love.graphics.setColor(oldR, oldG, oldB, oldA)
end

--[[
// 绘制矩形框
// (x1,y1)--(x2,y2) 框的左上角和右下角坐标
// color 颜色
--]]
function DrawRect(x1, y1, x2, y2, color)
    --if x2<x1 or y2<y1 then return end
    local oldR, oldG, oldB, oldA = love.graphics.getColor()
    local r, g, b = GetRGB(color)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.rectangle("line", x1, y1, x2-x1+1, y2-y1+1)
    love.graphics.setColor(oldR, oldG, oldB, oldA)
end

--[[
//显示表面
//flag = 0 显示全部表面  =1 按照SetClip设置的矩形显示，如果没有矩形，则不显示
--]]
-- 标记是否在 love.draw() 中
local inDrawLoop = false

function SetDrawLoopFlag(flag)
    inDrawLoop = flag
end

function ShowSurface(flag)
    -- 在 Love2D 事件驱动架构中，只有 love.draw() 应该调用 present()
    -- 如果在其他地方调用，会导致屏幕抖动/闪烁
    if inDrawLoop then
        love.graphics.present()
    end
end

function ShowSlow(delaytime, flag)
    -- 同上，只有 love.draw() 应该调用 present()
    if inDrawLoop then
        love.graphics.present()
    end
end

local color32Pallette = {}
local function LoadPallette(filename)
    local f = FileUtil.open(filename, "rb")
    if f == nil then return false end
    Debug("Loading palette from: %s", filename)
    for i=1,256 do
        local c0, c1, c2 = f:read(3):byte(1,3)
        -- Palette values are 0-63, multiply by 4 to get 0-255 range
        color32Pallette[i] = (c0*4)*65536+(c1*4)*256+(c2*4)
        if i <= 5 then
            Debug("Palette[%d]: raw=%d,%d,%d -> color=%d", i, c0, c1, c2, color32Pallette[i])
        end
    end
    f:close()
    Debug("Palette loaded, first entry: %d", color32Pallette[1])
end

--[[
// 初始化贴图cache信息
// PalletteFilename 为256调色板文件。第一次调用时载入
//                  为空字符串则表示重新清空贴图cache信息。在主地图/场景/战斗切换时调用
--]]
function PicInit(PalletteFilename)
    if PalletteFilename == nil then return end
    LoadPallette(PalletteFilename)
end

picFileCache = {} -- index by id

local PicCache = {}
function PicCache:init()
    self.w = 0
    self.h = 0
    self.xoff = 0
    self.yoff = 0
    self.img = nil
end

function PicCache:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    o:init()
    return o
end

local PicFile = {}
function PicFile:init()
    self.idx = {}
    self.grpfilename = ""
    self.pcache = {}
end

function PicFile:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    o:init()
    return o
end

function PicFile:getPic(picid)
    if self.pcache[picid] == nil then
        local f = FileUtil.open(self.grpfilename, "rb")
        if f == nil then
            Debug("getPic: failed to open file %s", self.grpfilename)
            return nil
        end
        if self.idx[picid]==nil or self.idx[picid+1]==nil then
            Debug("getPic: %s picid=%d, idx=%d,%d", self.grpfilename, picid, self.idx[picid] or -1, self.idx[picid+1] or -1)
            f:close()
            return nil
        end
        self.pcache[picid] = LoadPic(f, self.idx[picid], self.idx[picid+1])
        f:close()
        if self.pcache[picid] == nil then
            Debug("getPic: LoadPic returned nil for picid=%d", picid)
        end
    end
    return self.pcache[picid]
end

local function FileLength(fname)
    local f = FileUtil.open(fname, "rb")
    if f == nil then return -1 end
    local len = f:seek("end")
    f:close()
    return len
end

function LoadPic(openfile, idx1, idx2)
    if openfile == nil or idx2 <= idx1 then 
        Debug("LoadPic: invalid parameters, openfile=%s, idx1=%d, idx2=%d", tostring(openfile), idx1, idx2)
        return nil 
    end
    openfile:seek("set", idx1)
    
    -- 读取前8字节检查是否是PNG文件
    local header = openfile:read(8)
    if header == nil then
        Debug("LoadPic: failed to read header data")
        return nil
    end
    
    -- 检查PNG文件头 (89 50 4E 47 0D 0A 1A 0A)
    if header:byte(1) == 0x89 and header:byte(2) == 0x50 and header:byte(3) == 0x4E and header:byte(4) == 0x47 then
        -- 这是PNG文件，使用love2d的PNG加载
        local pngSize = idx2 - idx1
        openfile:seek("set", idx1)
        local pngData = openfile:read(pngSize)
        if pngData == nil then
            Debug("LoadPic: failed to read PNG data")
            return nil
        end
        
        -- 使用love.image.newImageData加载PNG
        local success, imgdata = pcall(function()
            return love.image.newImageData(love.filesystem.newFileData(pngData, "temp.png"))
        end)
        
        if not success or imgdata == nil then
            Debug("LoadPic: failed to load PNG image")
            return nil
        end
        
        local w = imgdata:getWidth()
        local h = imgdata:getHeight()
        
        local cache = PicCache:new()
        cache.w = w
        cache.h = h
        cache.xoff = 0
        cache.yoff = 0
        cache.img = love.graphics.newImage(imgdata, {mipmaps=false, linear=false, dpiscale=1})
        return cache
    end
    
    -- 不是PNG，按RLE格式处理
    local data1 = header:sub(1, 2)
    local data2 = header:sub(3, 4)
    local data3 = header:sub(5, 6)
    local data4 = header:sub(7, 8)
    local w = Byte.byte2ushortl(data1:byte(1,2))
    local h = Byte.byte2ushortl(data2:byte(1,2))
    local xoff = Byte.byte2sshortl(data3:byte(1,2))
    local yoff = Byte.byte2sshortl(data4:byte(1,2))
    -- 根据grp读入图像
    -- 先初始化为透明图片
    local imgdata = love.image.newImageData(w, h)
    for x=0,w-1 do
        for y=0,h-1 do
            imgdata:setPixel(x, y, 0, 0, 0, 0)
        end
    end
    -- 按照原来游戏的RLE格式创建表面
    for y=0,h-1 do
        --print("[line] " .. y)
        local x=0
        local count = openfile:read(1):byte(1) -- 当前行数据个数
        local offset = 0
        while offset < count do
            local transsize = openfile:read(1):byte(1) -- 空白点个数
            offset = offset+1
            x = x+transsize
            local solidnum = openfile:read(1):byte(1) -- 不透明点个数
            offset = offset+1
            for i=0,solidnum-1 do
                local palletteIdx = openfile:read(1):byte(1)
                palletteIdx = palletteIdx+1 -- lua starts with 1
                local color = color32Pallette[palletteIdx]
                local r,g,b = GetRGB(color)
                --print("setPixel:" .. "(" .. x .. "," .. y .. ") " .. r .. "," .. g .. "," .. b)
                imgdata:setPixel(x, y, r, g, b, 1)
                x = x+1
                offset = offset+1
            end
        end
        --print("[line] " .. y)
        --[[idx1 = idx1+8
        local start = idx1
        local xdatasize = openfile:read(1):byte(1) -- 当前行数据个数
        idx1 = idx1+1
        if xdatasize > 0 then
            local x = 0 -- 当前列
            while idx1-start < xdatasize do
                local transsize = openfile:read(1):byte(1) -- 空白点个数
                idx1 = idx1+1
                --print("from " .. x .. ":jump " .. transsize .. " pixels to " .. x+transsize)
                x = x+transsize -- 跳过透明点
                local solidnum = openfile:read(1):byte(1) -- 不透明点个数
                --print("solidnum=" .. solidnum)
                idx1 = idx1+1
                while solidnum>0 do
                    local palletteIdx = openfile:read(1):byte(1)
                    local color = color32Pallette[palletteIdx]
                    idx1 = idx1+1
                    local r,g,b = GetRGB(color)
                    --print("setPixel:" .. "(" .. x .. "," .. y .. ") " .. r .. "," .. g .. "," .. b)
                    imgdata:setPixel(x, y, r, g, b, 1)
                    x = x+1
                    solidnum = solidnum-1
                end
            end
        end--]]
    end

    local cache = PicCache:new()
    cache.w = w
    cache.h = h
    cache.xoff = xoff
    cache.yoff = yoff
    -- 设置 premultipliedAlpha 为 false，因为我们使用的是非预乘 alpha
    cache.img = love.graphics.newImage(imgdata, {mipmaps=false, linear=false, dpiscale=1})
    imgdata = nil
    return cache
end

--[[
// 加载文件信息
// filename 文件名 
// id  0 - PIC_FILE_NUM-1
--]]
-- 原版 jymain.h:117 `#define PIC_FILE_NUM 40`，piccache.c:92
-- `if(id<0 || id>=PIC_FILE_NUM) return 1;`；此处同步该上界检查。
local PIC_FILE_NUM = 40

function PicLoadFile(idxfilename, grpfilename, fileid)
    -- 与原版一致：id 合法范围 0..PIC_FILE_NUM-1，越界直接拒绝
    if fileid == nil or fileid < 0 or fileid >= PIC_FILE_NUM then return end
    fileid = fileid+1 -- lua starts with 1

    --Debug("PicLoadFile: %s %d", idxfilename, fileid)
    local pic_file = PicFile:new()
    pic_file.grpfilename = grpfilename
    picFileCache[fileid] = pic_file

    -- 读取idx文件
    local idxlen = FileLength(idxfilename)
    local grplen = FileLength(grpfilename)
    if idxlen < 0 or grplen < 0 then return end
    local f = FileUtil.open(idxfilename, "rb")
    local num = idxlen/4

    pic_file.idx[1] = 0
    for i=1,num do
        local nextidx = Byte.byte2uintl(f:read(4):byte(1,4))
        if nextidx > grplen then nextidx = grplen end
        if nextidx < 0 then nextidx = pic_file.idx[i] end
        pic_file.idx[i+1] = nextidx
        --Debug("%s num %d: %d,%d", grpfilename, i, pic_file.idx[i], nextidx)
    end
    if pic_file.idx[num+1] < grplen then
        Debug("PicLoadFile: last not at the end")
        pic_file.idx[num+2] = grplen
    end
    f:close()
end

-- //得到贴图大小
function PicGetXY(fileid, picid)
    if picid<0 then return 0,0,0,0 end
    local original_picid = picid
    picid = math.floor(picid/2)
    picid = picid+1 -- lua starts with 1
    fileid = fileid+1 -- lua starts with 1
    Debug("PicGetXY: fileid=%d, original_picid=%d, calculated_picid=%d", fileid, original_picid, picid)
    local pcache = picFileCache[fileid]:getPic(picid)
    if pcache == nil then
        Debug("PicGetXY: pcache is nil!")
        return 0,0,0,0
    end
    Debug("PicGetXY: pcache.w=%d, pcache.h=%d", pcache.w, pcache.h)
    return pcache.w, pcache.h, pcache.xoff, pcache.yoff
end

--[[ PicLoadCache -> HAPI_LoadPic -> JY_LoadPic
// 加载并显示贴图
// fileid        贴图文件id 
// picid     贴图编号
// x,y       显示位置
//  flag 不同bit代表不同含义，缺省均为0
//  b0    0 考虑偏移xoff，yoff。=1 不考虑偏移量
//  b1    0     , 1 与背景alpla 混合显示, value 为alpha值(0-256), 0表示透明
//  b2            1 全黑
//  b3            1 全白
//  value 按照flag定义，为alpha值， 
--]]
function PicLoadCache(fileid, picid, x, y, flag, value)
    flag = flag or 0
    local original_picid = picid
    picid = math.floor(picid/2)
    fileid = fileid+1 -- lua starts with 1
    picid = picid+1 -- lua starts with 1
    picfile = picFileCache[fileid]
    if picfile == nil or fileid < 1 or picid < 1 or picid > #(picfile.idx) then
        Debug("PicLoadCache: invalid picfile or picid out of range")
        return
    end
    local piccache = picfile:getPic(picid)
    if piccache == nil then
        Debug("PicLoadCache: piccache is nil!")
        return
    end
    local xnew = x
    local ynew = y
    if bit32.band(flag, 0x1) == 0 then
        xnew = x - piccache.xoff
        ynew = y - piccache.yoff
    end

    -- 跳过屏幕外的贴图
    if xnew < -1000 or xnew > CONFIG.Width + 1000 or ynew < -1000 or ynew > CONFIG.Height + 1000 then
        return
    end
    
    -- 处理颜色效果 (flag: b1=alpha混合, b2=全黑, b3=全白)
    -- Love2D 11.0+ 使用 0-1 范围的颜色值
    local r, g, b, a = 1, 1, 1, 1
    local hasAlpha = bit32.band(flag, 0x2) ~= 0  -- bit1: alpha混合
    local isBlack = bit32.band(flag, 0x4) ~= 0   -- bit2: 全黑
    local isWhite = bit32.band(flag, 0x8) ~= 0   -- bit3: 全白
    
    if isBlack then
        r, g, b = 0, 0, 0
    elseif isWhite then
        r, g, b = 1, 1, 1
    end
    
    if hasAlpha then
        a = (value or 128) / 255  -- 转换为 0-1 范围
    end
    
    love.graphics.setColor(r, g, b, a)
    love.graphics.draw(piccache.img, xnew, ynew)
    love.graphics.setColor(1, 1, 1, 1) -- 重置颜色
end

local JY_LoadPic = PicLoadCache

function FullScreen()
    love.graphics.toggleFullscreen()
end

local pictureCache = {}
--[[
//加载图形文件，其他格式也可以加载
//x,y =-1 则加载到屏幕中心
//    如果未加载，则加载，然后blit，如果加载，直接blit
//  str 文件名，如果为空，则释放表面 --]]
function LoadPicture(filename, x, y)
    if filename==nil or filename=="" then
        pictureCache = {}
        return
    end
    local pic = nil
    if pictureCache[filename] == nil then
        pic = love.graphics.newImage(filename)
        pictureCache[filename] = pic
    else
        pic = pictureCache[filename]
    end
    if pic ~= nil then
        if x==-1 then x=math.floor( (CONFIG.Width - pic:getWidth())/2 ) end
        if y==-1 then y=math.floor( (CONFIG.Height - pic:getHeight())/2 ) end
        --Debugt("LoadPicture: %s %d %d", filename, x, y)
        love.graphics.draw(pic, x, y)
    end
end

local currentMusic = nil

-- ---------------------------------------------------------------------------
-- Audio path resolution (REQ-MIDI-1 / REQ-MIDI-2)
--
-- 1) MOD/原版 prefix must NOT be re-prefixed with CONFIG.SoundPath.
--    Previously a MOD-overridden path such as "mods/<slug>/sound/game27.ogg"
--    did not start with "sound/", so it was rewritten into the nonexistent
--    "sound/mods/<slug>/sound/game27.ogg" and playback silently failed.
--    Any path already carrying a directory prefix that exists is left alone.
--
-- 2) LÖVE picks its decoder by *file extension* (verified: a MIDI file renamed
--    to .ogg fails with "Could not read Ogg bitstream"). LÖVE 11.5 does decode
--    .mid/.mp3 natively (libmodplug), so when the caller supplies an extension-
--    less path we probe the candidates in order.
--
--    Probe order is .ogg -> .mp3 -> .mid. The bundled 25 themes ship only as
--    .ogg so they stay bit-identical regardless of order. For MOD music an
--    optional pre-rendered .ogg (rendered with a real SoundFont) must win over
--    the source .mid, because LÖVE's bundled libmodplug ignores SoundFonts and
--    renders MIDI with a thin built-in wavetable (measured: ~2.1x the high-
--    frequency energy of a SoundFont render). .mid is last so it acts purely
--    as the fallback when no rendered version has been produced yet.
-- ---------------------------------------------------------------------------

-- Extensions probed for an extension-less music path, in priority order.
local MUSIC_EXTS = { ".ogg", ".mp3", ".mid" }

-- Cheap existence probe that works for both bare names (LÖVE source dir) and
-- relative paths (Chromium-style fuse mount), without touching love.filesystem.
local function audioFileExists(path)
    local f = io.open(path, "rb")
    if f then f:close() return true end
    -- Packed .love / mobile builds expose assets only through love.filesystem.
    if love and love.filesystem and love.filesystem.getInfo then
        local rel = path:gsub("^%./", "")
        local ok, info = pcall(love.filesystem.getInfo, rel)
        if ok and info then return true end
    end
    return false
end

local function hasExtension(path)
    -- Only a trailing ".<letters/digits>" counts; "1.2" style names are not exts.
    return path:match("%.%w+$") ~= nil
end

-- First existing candidate for an extension-less path, or nil.
local function firstExisting(stem)
    for _, ext in ipairs(MUSIC_EXTS) do
        if audioFileExists(stem .. ext) then
            return stem .. ext
        end
    end
    return nil
end

-- REQ-MIDI-3: built-in fallback.
--
-- A MOD may reference more music ids than it actually ships (measured:
-- BookCalamity references up to id 51 but only ships music/0..23). Without a
-- fallback those scenes would be *worse* than before this feature, because the
-- MOD path shadows the bundled sound/gameNN.ogg that used to play.
--
-- So when a MOD music path cannot be resolved, retry the same basename under
-- the bundled sound directory. Scenes with no bundled track either stay silent
-- (the previous, non-crashing behaviour).
local function bundledFallback(filepath, basePath)
    local base = filepath:match("([^/]+)$")
    if not base then return nil end
    local soundPath = (CONFIG and CONFIG.SoundPath) or "sound/"
    -- Do not fall back when we are already looking at the bundled directory.
    if filepath:sub(1, #soundPath) == soundPath then return nil end
    return firstExisting(soundPath .. base)
end

-- Returns the concrete file to decode for a music path, or nil when nothing
-- exists. Extension-carrying paths are returned untouched (so the original
-- sound/gameNN.ogg behaviour is byte-for-byte unchanged).
local function resolveMusicFile(filepath)
    if hasExtension(filepath) then
        if audioFileExists(filepath) then return filepath end
        return bundledFallback(filepath) or filepath
    end
    local found = firstExisting(filepath)
    if found then return found end
    return bundledFallback(filepath, nil) or filepath
end

function PlayMIDI(filename)
    if not love.audio then return end
    
    if filename == "" or filename == nil then
        if currentMusic then
            currentMusic:stop()
            currentMusic = nil
        end
        return
    end
    
    local filepath = filename
    Debug("PlayMIDI: filename=" .. tostring(filename))
    
    -- REQ-MIDI-1: only apply CONFIG.SoundPath when the caller passed a bare
    -- file name. Paths that already name a directory (sound/, mods/... /,
    -- absolute) are used as-is.
    if not filepath:match("^/") and not filepath:match("^%a:") then
        local bareName = not filepath:match("/")
        if bareName and not filepath:match("^sound/") then
            filepath = CONFIG.SoundPath .. filepath
        end
    end
    filepath = resolveMusicFile(filepath)
    Debug("PlayMIDI: filepath=" .. filepath)
    
    local success, source_or_err = pcall(love.audio.newSource, filepath, "stream")
    if not success then
        Debug("PlayMIDI error: " .. tostring(source_or_err))
    end
    if success then
        if currentMusic then
            currentMusic:stop()
        end
        currentMusic = source_or_err
        currentMusic:setLooping(true)
        currentMusic:play()
    end
end

function PlayWAV(filename)
    if not love.audio then return end
    
    if filename == "" or filename == nil then
        return
    end
    
    local filepath = filename
    -- REQ-MIDI-1 (same prefix defect as PlayMIDI): keep directory-carrying
    -- paths intact so MOD sound effects resolve under mods/<slug>/sound/.
    if not filepath:match("^/") and not filepath:match("^%a:") then
        local bareName = not filepath:match("/")
        if bareName and not filepath:match("^sound/") then
            filepath = CONFIG.SoundPath .. filepath
        end
    end
    
    local success, source_or_err = pcall(love.audio.newSource, filepath, "static")
    if success then
        source_or_err:play()
    end
end

function PlayMPEG(filename)
    PlayMIDI(filename)
end

local BuildingType = {}
function BuildingType:init()
    self.x = 0
    self.y = 0
    self.num = 0
end

function BuildingType:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    o:init()
    return o
end

buildList = {} -- 建筑排序数组
buildNumber = 0 -- 实际排序个数
do
    for i=1,2000 do buildList[i]=BuildingType:new() end
end

mmap = {earth=nil, surface=nil, building=nil, buildx=nil, buildy=nil}
mmap_keys = {"earth", "surface", "building", "buildx", "buildy"}

-- //全部读取主地图 
function LoadMMap_Sub(filename)
    local size = CC.MWidth*CC.MHeight
    return Byte.LoadToTable16(filename, size, 0, true)
end

-- // 读取主地图数据
function LoadMMap(earthname, surfacename, buildingname, buildxname, buildyname, x_max, y_max, x, y)
    -- CC.MWidth = x_max
    -- CC.MHeight = y_max

    -- //全部读取
    mmap.earth = LoadMMap_Sub(earthname)
    mmap.surface = LoadMMap_Sub(surfacename)
    mmap.building = LoadMMap_Sub(buildingname)
    mmap.buildx = LoadMMap_Sub(buildxname)
    mmap.buildy = LoadMMap_Sub(buildyname)
end

-- // 得到主地图数据偏移地址。如果超出当前内存的数据范围，返回-1
local function GetMMapOffset(x, y)
    -- g_LoadMMapType==0
    if x<0 or x>=CC.MWidth or y <0 or y>=CC.MHeight then return -1 end
    local s=y*CC.MWidth+x
    return s
end

--[[
// 取主地图数据 
// flag  0 earth, 1 surface, 2 building, 3 buildx, 4 buildy
--]]
function GetMMap(x, y, flag)
    flag = flag+1 -- lua starts with 1
    local offset = GetMMapOffset(x, y)
    if offset < 0 then
        JY_Error("JY_GetMMap: input data out of range x=%d,y=%d,flag=%d",x,y,flag)
        return 0
    end
    offset = offset+1 -- lua starts with 1
    return mmap[mmap_keys[flag]][offset]
end

--[[
// 存主地图数据 
// flag  0 earth, 1 surface, 2 building, 3 buildx, 4 buildy
--]]
local function SetMMap(x, y, flag, v)
    flag = flag+1 -- lua starts with 1
    local offset = GetMMapOffset(x, y)
    if offset < 0 then
        JY_Error("JY_GetMMap: input data out of range x=%d,y=%d,flag=%d",x,y,flag)
        return 0
    end
    offset = offset+1 -- lua starts with 1
    mmap[mmap_keys[flag]][offset] = v
end

--[[
// 主地图建筑排序 
// x,y 主角坐标
// Mypic 主角贴图编号
--]]
function BuildingSort(x, y, Mypic)
    local rangex=math.floor(math.floor(CONFIG.Width/(2*CONFIG.XScale))/2)+1+CONFIG.MMapAddX
    local rangey=math.floor(math.floor(CONFIG.Height/(2*CONFIG.YScale))/2)+1

    local range=rangex+rangey+CONFIG.MMapAddY

    local bak=GetMMap(x,y,2)
    local bakx=GetMMap(x,y,3)
    local baky=GetMMap(x,y,4)

    local xmin=limitX(x-range,1,CC.MWidth-1)
    local xmax=limitX(x+range,1,CC.MWidth-1)
    local ymin=limitX(y-range,1,CC.MHeight-1)
    local ymax=limitX(y+range,1,CC.MHeight-1)

    local tmpBuild=nil

    SetMMap(x,y,2, bit32.band(Mypic*2, 0xFFFF))
    SetMMap(x,y,3,x)
    SetMMap(x,y,4,y)

    local p = 0
    local seenbefore = false
    for i=xmin,xmax do
        local dy = ymin
        for j=ymin,ymax do
            local ij3 = GetMMap(i,j,3)
            local ij4 = GetMMap(i,j,4)
            if ij3~=0 and ij4~=0 then
                seenbefore = false
                for k=0,p-1 do
                    local idxk = k+1 -- lua starts with 1
                    --Debug("BuildingSort: i=%d, j=%d, k=%d", i,j,k)
                    if buildList[idxk].x == ij3 and buildList[idxk].y == ij4 then
                        seenbefore = true
                        if k==p-1 then break end

                        for m=j-1,dy,-1 do
                            local im3=GetMMap(i,m,3)
                            local im4=GetMMap(i,m,4)
                            if im3~=0 and im4~=0 then
                                if im3~=ij3 or im4~=ij4 then
                                    if im3~=buildList[idxk].x or im4~=buildList[idxk].y then
                                        -- 与原版 mainmap.c:BuildingSort 逐字一致：
                                        --     tmpBuild = Build[p-1];
                                        --     memmove(&Build[k+1], &Build[k], (p-k-1)*sizeof(BuildingType));
                                        --     Build[k] = tmpBuild;
                                        -- 即把 buildList[idxk..p] 这一段整体右旋一位，数组长度不变。
                                        -- 早期移植误写成 table.insert(buildList, idxk+1, tmp)，造成
                                        --   ① 插入点后移一位 → 建筑深度顺序与原版不一致（遮挡错位）
                                        --   ② buildList 被无限拉长（每次排序增长，长跑内存只增不减）
                                        tmpBuild = buildList[p] -- C: Build[p-1]，最后一个有效元素
                                        for t=p, idxk+1, -1 do
                                            buildList[t] = buildList[t-1]
                                        end
                                        buildList[idxk] = tmpBuild
                                    end
                                end
                            end
                        end
                        dy=j+1
                        break
                    end
                end
                if not seenbefore then
                    local idxp = p+1
                    buildList[idxp] = BuildingType:new()
                    buildList[idxp].x =ij3
                    buildList[idxp].y =ij4
                    buildList[idxp].num =GetMMap(buildList[idxp].x,buildList[idxp].y,2)
                    p=p+1
                end
            end
        end
    end

    buildNumber=p
    --Debug("BuildingSort: x=%d,y=%d, buildNumber=%d", x, y, buildNumber)

    SetMMap(x,y,2,bak)
    SetMMap(x,y,3,bakx)
    SetMMap(x,y,4,baky)  
end

-- // 绘制主地图
function DrawMMap(x, y, Mypic)
    local oldScissorX, oldScissorY, oldScissorW, oldScissorH = love.graphics.getScissor()
    
    local rect = {x=nil, y=nil, w=nil, h=nil}
    rect.x, rect.y, rect.w, rect.h = love.graphics.getScissor()
    rect.x = rect.x or 0
    rect.y = rect.y or 0
    rect.w = rect.w or CONFIG.Width
    rect.h = rect.h or CONFIG.Height

    -- 根据g_Surface的clip来确定循环参数。提高绘制速度
    local istart=math.floor((rect.x-math.floor(CONFIG.Width/2))/(2*CONFIG.XScale))-1-CONFIG.MMapAddX
    local iend=math.floor((rect.x+rect.w -math.floor(CONFIG.Width/2))/(2*CONFIG.XScale))+1+CONFIG.MMapAddX

    local jstart=math.floor((rect.y-math.floor(CONFIG.Height/2))/(2*CONFIG.YScale))-1;
    local jend=math.floor((rect.y+rect.h -math.floor(CONFIG.Height/2))/(2*CONFIG.YScale))+1;

    buildNumber=0

    -- TODO: 部分读取主地图，则根据需要重新读取数据

    -- 建筑排序
    BuildingSort(x, y, Mypic)
    FillColor(0,0,0,0,0)

    for j=0,2*jend-2*jstart+CONFIG.MMapAddY do
        for i=istart,iend do
            local i1=i+math.floor(j/2)+jstart
            local j1=-i+math.floor(j/2)+j%2+jstart
             
            local x1=CONFIG.XScale*(i1-j1)+math.floor(CONFIG.Width/2)
            local y1=CONFIG.YScale*(i1+j1)+math.floor(CONFIG.Height/2)
            if (x+i1)>=0 and (x+i1)<CC.MWidth and (y+j1)>=0 and (y+j1)<CC.MHeight then
                local picnum=GetMMap(x+i1,y+j1,0);
                if picnum>0 then
                    JY_LoadPic(0,picnum,x1,y1,0,0)
                end
                picnum=GetMMap(x+i1,y+j1,1);
                if picnum>0 then
                    JY_LoadPic(0,picnum,x1,y1,0,0)
                end
            end
        end
    end

    -- 建筑层：单次按 BuildingSort 的排序顺序绘制。
    -- 主角/船由 BuildingSort 临时写入主地图 building/buildx/buildy，
    -- 和其它建筑条目一起参与同一份排序，所以它们的绘制次序就是深度次序
    -- （对应原版 mainmap.c:JY_DrawMMap 唯一的一层循环）。
    --
    -- 禁止把主角/船拆出来「最后单独绘制」：那样任何建筑（大山、房屋、
    -- 树木）都再也遮不住主角，走到大山背后会整块露出来（commit 2c8a644
    -- 「修复主地图主角显示问题」引入的回归）。
    -- 也禁止给主角/船加额外 y 偏移：屏幕位置完全由贴图头部的 xoff/yoff 决定
    -- （原版 piccache.c:JY_LoadPic 只有 x-xoff / y-yoff），贴图头里已经带有
    -- 正确的 yoff（主角帧 15x39，xoff=5 yoff=44），再叠加偏移就是错位。
    for i=0,buildNumber-1 do
        local idxi = i+1
        local i1=buildList[idxi].x -x
        local j1=buildList[idxi].y -y
        local x1=CONFIG.XScale*(i1-j1)+math.floor(CONFIG.Width/2)
        local y1=CONFIG.YScale*(i1+j1)+math.floor(CONFIG.Height/2)
        local picnum=buildList[idxi].num
        if picnum>0 then
            JY_LoadPic(0,picnum,x1,y1,0,0)
        end
    end

    -- 云朵层：原版 kys_draw.pas:DrawMMap 在建筑循环结束后、解除裁剪前调用
    -- DrawClouds，云永远画在地面/建筑之上（天空层）。公式里的 Mx,My 就是
    -- 传入 DrawMMap 的主角坐标，故直接复用 x,y。
    DrawClouds(x, y)

    if oldScissorX then
        love.graphics.setScissor(oldScissorX, oldScissorY, oldScissorW, oldScissorH)
    else
        love.graphics.setScissor()
    end
end

function UnloadMMap()
    mmap.earth=nil
    mmap.surface=nil
    mmap.building=nil
    mmap.buildx=nil
    mmap.buildy=nil
end

-- ============================================================
-- 云朵系统（主地图飘云）
-- 逐字移植自原版 kys（kys_main.cpp / kys_draw.cpp / kys_engine.cpp）：
--   * 原版在大地图每帧绘制 60 朵云（CLOUD_AMOUNT），每 40ms 右移 Speedx(1..3)px，
--     越界(>17279 或 <0)后从左侧(CloudCreateOnSide, Positionx=0)重生；
--   * 每朵云有随机色调 mixColor(RGB) 与 mixAlpha(10..59)，先把调色板像素
--     朝 mixColor 混合 mixAlpha%（DrawRLE8Pic 的 mix 公式），再整体以
--     Alpha(10..59)% 透明度合成到背景。
-- 移植取舍：Love2D 无逐像素 mixColor 通道，故在「生成云」的瞬间把色调
-- 烘焙进该朵云的贴图（精确复刻 mix 公式），绘制时用 setColor 的 alpha
-- 复刻整体透明度。云帧 RLE 解码与 LoadPic 同一格式，但云 idx 是「每帧一个
-- 贴图」（原版 DrawCPic 不做 /2），故直接按 idx[num+1..num+2] 取帧范围。
-- ============================================================
local CLOUD_AMOUNT = 60
-- PicLoadFile 槽位。原版 jymain.h:117 `#define PIC_FILE_NUM 40`，合法 id 为
-- 0..39；已占用：0=地图/场景/战场图 1=头像 2=物品 3=特效 4+i=战斗人物
-- （WAR.Person 共 26 项，i=0..25 → 4..29）。故 30..39 空闲，取上界 39，
-- 既不与原版 PIC_FILE_NUM 容量冲突，也不与任何现有槽位冲突。
local CLOUD_SLOT = 39
local CLOUD_WORLD_X = 17280  -- 云世界 x 范围（原版硬编码 17280 = 2*MWidth*XScale）
local CLOUD_WORLD_Y = 8640   -- 云世界 y 范围（原版硬编码 8640 = MHeight*XScale，注意是 XScale 不是 YScale）
local cloudFrames = {}   -- cloudFrames[picnum] = {w=,h=,pixels={{x,y,r,g,b},...}} 调色板原色 0-255
local cloudList = {}     -- cloudList[i] = {Picnum,Positionx,Positiony,Speedx,Speedy,Alpha,mixR,mixG,mixB,mixAlpha,img,imgW,imgH}
local cloudPicAmount = 0
local cloudNextTick = 0

-- 解码一帧云 RLE 为调色板原色像素列表。
-- 逐字移植原版 DrawRLE8Pic 的行 RLE 状态机（kys_engine.cpp / kys_engine.pas）：
--   每行首字节 l = 本行命令字节总数；状态 p: 0=读跳过 1=读像素数 >=2=逐像素绘制，
--   一 run 结束(p 回到 2)复位 p=0。与 LoadPic 的「成对」解码不同，状态机能
--   正确处理行尾的 trailing skip（空白收尾），对真实云数据两者结果一致。
local function CloudDecodeFrame(picnum)
    local pf = picFileCache[CLOUD_SLOT + 1]
    if pf == nil then return nil end
    local start = pf.idx[picnum + 1]
    local finish = pf.idx[picnum + 2]
    if start == nil or finish == nil or finish <= start then return nil end
    local f = FileUtil.open(pf.grpfilename, "rb")
    if f == nil then return nil end
    f:seek("set", start)
    local header = f:read(8)
    if header == nil then f:close(); return nil end
    local w = Byte.byte2ushortl(header:sub(1,2):byte(1,2))
    local h = Byte.byte2ushortl(header:sub(3,4):byte(1,2))
    local xoff = Byte.byte2sshortl(header:sub(5,6):byte(1,2))
    local yoff = Byte.byte2sshortl(header:sub(7,8):byte(1,2))
    if w <= 0 or h <= 0 then f:close(); return nil end
    local pixels = {}
    for iy = 1, h do
        local lbyte = f:read(1)
        if lbyte == nil then break end
        local l = lbyte:byte(1)        -- 本行 entry 数量（1 字节）
        local col = 1                  -- 当前列，1 基（原版 ww）
        local p = 0                    -- 状态: 0=读跳过 1=读像素数 >=2=逐像素绘制
        for ix = 1, l do
            local byte = f:read(1)
            if byte == nil then break end
            local l1 = byte:byte(1)
            if p == 0 then
                col = col + l1         -- 跳过 l1 个空白像素
                p = 1
            elseif p == 1 then
                p = 2 + l1             -- 接下来 l1 个像素数据
            elseif p > 2 then
                p = p - 1
                local x = col - 1      -- 帧内 0 基 x（原版 x = ww - xs + px，xs 绘制时扣除）
                if x >= 0 and x < w then
                    local color = color32Pallette[l1 + 1]  -- lua starts with 1
                    if color then
                        local r = math.floor(color / 65536)
                        local g = math.floor(color / 256) % 256
                        local b = color % 256
                        pixels[#pixels + 1] = { x, iy - 1, r, g, b }
                    end
                end
                col = col + 1
                if p == 2 then p = 0 end
            end
        end
    end
    f:close()
    cloudFrames[picnum] = { w = w, h = h, xoff = xoff, yoff = yoff, pixels = pixels }
    return cloudFrames[picnum]
end

-- 烘焙单朵云贴图：把调色板像素朝色调(mixR/mixG/mixB)混合 mixAlpha%
-- （精确复刻原版 DrawRLE8Pic：pix = (mixAlpha*mixColor + (100-mixAlpha)*pix)/100）
local function CloudBakeImage(picnum, mixR, mixG, mixB, mixAlpha)
    local frame = cloudFrames[picnum]
    if frame == nil then return nil, 0, 0, 0, 0 end
    local imgdata = love.image.newImageData(frame.w, frame.h)
    for _, p in ipairs(frame.pixels) do
        local x, y, r, g, b = p[1], p[2], p[3], p[4], p[5]
        local nr = (mixAlpha * mixR + (100 - mixAlpha) * r) / 100
        local ng = (mixAlpha * mixG + (100 - mixAlpha) * g) / 100
        local nb = (mixAlpha * mixB + (100 - mixAlpha) * b) / 100
        imgdata:setPixel(x, y, nr / 255, ng / 255, nb / 255, 1)
    end
    local img = love.graphics.newImage(imgdata, {mipmaps=false, linear=false, dpiscale=1})
    return img, frame.w, frame.h, frame.xoff or 0, frame.yoff or 0
end

-- 云重生（原版 CloudCreateOnSide：Positionx=0，从左侧进入）
local function CloudCreateOnSide(i)
    if i < 1 or i > CLOUD_AMOUNT then return end
    local c = cloudList[i] or {}
    cloudList[i] = c
    c.Picnum = (cloudPicAmount > 0) and math.random(0, cloudPicAmount - 1) or 0
    c.Alpha = 10 + math.random(0, 49)
    c.mixR = math.random(0, 255)
    c.mixG = math.random(0, 255)
    c.mixB = math.random(0, 255)
    c.mixAlpha = 10 + math.random(0, 49)
    c.Positionx = 0
    c.Positiony = math.random(0, CLOUD_WORLD_Y - 1)
    c.Speedx = 1 + math.random(0, 2)
    c.Speedy = 0
    local img, w, h, xoff, yoff = CloudBakeImage(c.Picnum, c.mixR, c.mixG, c.mixB, c.mixAlpha)
    c.img = img
    c.imgW = w
    c.imgH = h
    c.xoff = xoff
    c.yoff = yoff
end

-- 云初始生成（原版 CloudCreate：OnSide 之后把 Positionx 随机散布到整幅）
local function CloudCreate(i)
    CloudCreateOnSide(i)
    if cloudList[i] then
        cloudList[i].Positionx = math.random(0, CLOUD_WORLD_X - 1)
    end
end

-- 加载云贴图并初始化 60 朵云（Init_MMap 在 PicLoadFile 后调用）
function CloudLoadAndInit(idxFile, grpFile)
    PicLoadFile(idxFile, grpFile, CLOUD_SLOT)
    cloudList = {}
    cloudFrames = {}
    cloudPicAmount = 0
    cloudNextTick = GetTime()
    CLOUD_WORLD_X = (CC and CC.MWidth or 480) * (CONFIG and CONFIG.XScale or 18) * 2
    CLOUD_WORLD_Y = (CC and CC.MHeight or 480) * (CONFIG and CONFIG.XScale or 18)
    local pf = picFileCache[CLOUD_SLOT + 1]
    if pf ~= nil then
        -- 云 idx 为「末偏移累计」布局：帧 num(0 基) 占 [idx[num+1], idx[num+2])
        local n = 0
        while pf.idx[n + 1] ~= nil and pf.idx[n + 2] ~= nil
                and pf.idx[n + 2] > pf.idx[n + 1] do
            cloudFrames[n] = CloudDecodeFrame(n)
            cloudPicAmount = cloudPicAmount + 1
            n = n + 1
        end
    end
    for i = 1, CLOUD_AMOUNT do
        CloudCreate(i)
    end
end

-- 云 40ms 漂移 tick（原版 kys_main.cpp:1897，受 MMAPAMI>0 门控）
function CloudTick()
    if cloudPicAmount == 0 then return end
    if CC == nil or CC.MMapAmi == nil or CC.MMapAmi <= 0 then return end
    local now = GetTime()
    if now - cloudNextTick <= 0 then return end
    cloudNextTick = now + 40
    for i = 1, CLOUD_AMOUNT do
        local c = cloudList[i]
        if c ~= nil then
            c.Positionx = c.Positionx + c.Speedx
            c.Positiony = c.Positiony + c.Speedy
            if c.Positionx > CLOUD_WORLD_X - 1 or c.Positionx < 0
                or c.Positiony > CLOUD_WORLD_Y - 1 or c.Positiony < 0 then
                CloudCreateOnSide(i)
            end
        end
    end
end

-- 绘制云（移植原版 kys_draw.pas:DrawClouds，画在主地图建筑层之上）
-- 绘制锚点 = 原版 DrawCPic 的 (px,py)，再按帧 xoff/yoff 偏移——与 JY_LoadPic
-- 的 (x - xoff, y - yoff) 约定一致（原版 DrawRLE8Pic: screen = anchor + col - xoff）。
--
-- 【x 轴符号为什么不能照抄原版】
-- 原版 kys 的地形投影是
--   GetPositionOnScreen: sx = -18*(i-Mx) + 18*(j-My) + CENTER_X
--                       = -18*(i-j) + 18*(Mx-My) + CENTER_X
-- 而本项目（Mac 血缘 mainmap.c:JY_DrawMMap）的地形投影是它的水平镜像：
--   sx = 18*((i-mx) - (j-my)) + W/2 = 18*(i-j) - 18*(mx-my) + W/2
-- 同一个「主角横移」量在两条轴上式子相反：kys 地形玩家项 = +18*(Mx-My)，
-- 本项目地形玩家项 = -18*(mx-my)。云是「世界锚定」的图层，必须与地形同步
-- 滚动，因此 x 的玩家项必须取 -18*(mx-my)（即 +18*mx - 18*my 前面加负号），
-- 也就是把原版的 `-(-Mx*18 + My*18 + ...)` 写成 `-(mx*18 - my*18 + ...)`。
-- 照抄原版会让云以 +18*(mx-my) 反向滑动：主角按 ←/→ 或 ↑/↓ 时地形向左下/
-- 右上滚，而云向右上/左下飘——表现就是「云跟着主角左右偏移」（历史 bug）。
-- y 轴无镜像（两边都是 9*(i+j)），故 y 的玩家项 9*(mx+my) 与原版一致，不改。
function DrawClouds(mx, my)
    if cloudPicAmount == 0 or #cloudList == 0 then return end
    local centerX = math.floor(CONFIG.Width / 2)
    local centerY = math.floor(CONFIG.Height / 2)
    for i = 1, CLOUD_AMOUNT do
        local c = cloudList[i]
        if c ~= nil and c.img ~= nil and c.Picnum >= 0 and c.Picnum < cloudPicAmount then
            local px = c.Positionx - (mx * CONFIG.XScale - my * CONFIG.XScale + CLOUD_WORLD_Y - centerX)
            local py = c.Positiony - (mx * CONFIG.YScale + my * CONFIG.YScale + CONFIG.YScale - centerY)
            local x = px - (c.xoff or 0)
            local y = py - (c.yoff or 0)
            -- 原版 DrawRLE8Pic 的 alpha 合成（cloud 无遮挡、alpha<100 分支）：
            --   out = 背景*(Alpha/100) + 云色*((100-Alpha)/100)
            -- 即 Alpha 是「背景透出百分比」，云自身不透明度 = (100-Alpha)/100。
            -- LÖVE 的默认 alpha 混合是 source-over（out = 源*a + 背景*(1-a)），
            -- 故此处必须传 (100-Alpha)/100，传 Alpha/100 会把不透明度反过来
            -- （原版近不透明的云会变近透明）。
            love.graphics.setColor(1, 1, 1, (100 - c.Alpha) / 100)
            love.graphics.draw(c.img, x, y)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
end

-- 测试/调试用：返回内部云表（只读观察，勿改）
function CloudGetList()
    return cloudList
end

local S_XMax = 0
local S_YMax = 0
local S_Num = 0
local smap = {} -- 场景S*数据
local D_Num1 -- 每个场景D的个数
local D_Num2 -- 每个D的数据个数
local dmap = {} -- 场景D*数据

-- 读取S*D* 场景地图
function LoadSMap(Sfilename, tmpfilename, num, x_max, y_max, Dfilename, d_num1, d_num2)
    S_XMax = x_max
    S_YMax = y_max
    S_Num = num

    -- TODO: 部分读取S文件

    -- 全部读入内存
    local s_size = S_XMax*S_YMax*6*S_Num
    smap = Byte.LoadToTable16(Sfilename, s_size, 0, true)
    D_Num1=d_num1
    D_Num2=d_num2

    -- 读取D文件
    local d_size = D_Num1*D_Num2*S_Num
    dmap = Byte.LoadToTable16(Dfilename, d_size, 0, true)
end

-- 保存S*D*
function SaveSMap(Sfilename, Dfilename)
    local startTime = os.clock()
    lib.Debug("SaveSMap: start")
    
    if smap == nil then 
        lib.Debug("SaveSMap: smap is nil, returning")
        return 
    end
    
    local s_size = S_XMax*S_YMax*6*S_Num
    lib.Debug(string.format("SaveSMap: saving %d elements to %s", s_size, Sfilename))
    
    Byte.SaveFromTable16(smap, Sfilename, s_size, 1, nil, true)
    lib.Debug(string.format("SaveSMap: S file done (%.2fs)", os.clock() - startTime))
    
    if dmap == nil then 
        lib.Debug("SaveSMap: dmap is nil, returning")
        return 
    end
    
    local d_size = D_Num1*D_Num2*S_Num
    lib.Debug(string.format("SaveSMap: saving %d elements to %s", d_size, Dfilename))
    
    Byte.SaveFromTable16(dmap, Dfilename, d_size, 1, nil, true)
    lib.Debug(string.format("SaveSMap: complete (%.2fs total)", os.clock() - startTime))
end

function GetS(id, x, y, level)
    if id < 0 then
        -- 切场景过渡期会出现 SubScene=-1，直接返回避免日志风暴。
        return 0
    end
    if id>=S_Num or x<0 or x>=S_XMax or y<0 or y>=S_YMax or level <0 or level >=6 then
        JY_Error("GetS error: data out of range! id=%d,x=%d,y=%d,level=%d\n",id,x,y,level)
        return 0
    end
    local s = S_XMax*S_YMax*(id*6+level)+y*S_XMax+x
    local idx = s+1 -- lua starts with 1
    return smap[idx]
end

-- 存S的值
function SetS(id, x, y, level, v)
    if id<0 or id>=S_Num or x<0 or x>=S_XMax or y<0 or y>=S_YMax or level <0 or level >=6 then
        JY_Error("SetS error: data out of range! id=%d,x=%d,y=%d,level=%d\n",id,x,y,level)
        return 0
    end
    local s = S_XMax*S_YMax*(id*6+level)+y*S_XMax+x
    local idx = s+1 -- lua starts with 1
    smap[idx] = v
end

-- 取D*
function GetD(Sceneid, id, i)
    if Sceneid < 0 then
        return 0
    end
    if Sceneid>=S_Num then
        JY_Error("GetD error: sceneid=%d out of range!\n",Sceneid)
        return 0
    end

    local s = D_Num1*D_Num2*Sceneid+id*D_Num2+i
    local idx = s+1 -- lua starts with 1
    return dmap[idx]
end

-- 存D*
function SetD(Sceneid, id, i, v)
    if Sceneid < 0 then
        return 0
    end
    if Sceneid>=S_Num then
        JY_Error("GetD error: sceneid=%d out of range!\n",Sceneid)
        return 0
    end

    local s = D_Num1*D_Num2*Sceneid+id*D_Num2+i
    local idx = s+1 -- lua starts with 1
    dmap[idx] = v
end

-- 绘制场景地图
function DrawSMap(sceneid, x,  y, xoff, yoff, Mypic)
    local oldScissor = {love.graphics.getScissor()}
    
    local rect = {x=nil, y=nil, w=nil, h=nil}
    rect.x, rect.y, rect.w, rect.h = love.graphics.getScissor()
    rect.x = rect.x or 0
    rect.y = rect.y or 0
    rect.w = rect.w or CONFIG.Width
    rect.h = rect.h or CONFIG.Height

    -- 根据g_Surface的剪裁来确定循环参数。提高绘制速度
    local istart=math.floor((rect.x-math.floor(CONFIG.Width/2))/(2*CONFIG.XScale))-1-CONFIG.SMapAddX
    local iend=math.floor((rect.x+rect.w-math.floor(CONFIG.Width/2))/(2*CONFIG.XScale))+1+CONFIG.SMapAddX

    local jstart=math.floor((rect.y-math.floor(CONFIG.Height/2))/(2*CONFIG.YScale))-1
    local jend=math.floor((rect.y+rect.h -math.floor(CONFIG.Height/2))/(2*CONFIG.YScale))+1

    FillColor(0,0,0,0,0)

    for j=0,2*jend-2*jstart+CONFIG.SMapAddY do
        for i=istart,iend do
            local i1=i+math.floor(j/2)+jstart
            local j1=-i+math.floor(j/2)+j%2+jstart

            local x1=CONFIG.XScale*(i1-j1)+math.floor(CONFIG.Width/2)
            local y1=CONFIG.YScale*(i1+j1)+math.floor(CONFIG.Height/2)

            local xx=x+i1+xoff
            local yy=y+j1+yoff

            if (xx>=0) and (xx<S_XMax) and (yy>=0) and (yy<S_YMax) then
                local d0=GetS(sceneid,xx,yy,0)
                if d0>0 then
                      JY_LoadPic(0,d0,x1,y1,0,0) -- 地面
                end
            end
        end
    end

    for j=0, 2*jend-2*jstart+CONFIG.SMapAddY do
        for i=istart, iend do
            local i1=i+math.floor(j/2)+jstart
            local j1=-i+math.floor(j/2)+j%2+jstart
           
            local x1=CONFIG.XScale*(i1-j1)+math.floor(CONFIG.Width/2)
            local y1=CONFIG.YScale*(i1+j1)+math.floor(CONFIG.Height/2)

            local xx=x+i1+xoff
            local yy=y+j1+yoff

            if (xx>=0) and (xx<S_XMax) and (yy>=0) and (yy<S_YMax) then
                local d1=GetS(sceneid,xx,yy,1)
                local d2=GetS(sceneid,xx,yy,2)
                local d3=GetS(sceneid,xx,yy,3)
                local d4=GetS(sceneid,xx,yy,4)
                local d5=GetS(sceneid,xx,yy,5)

                if d1>0 then
                      JY_LoadPic(0,d1,x1,y1-d4,0,0) -- 建筑
                end
                if d2>0 then
                     JY_LoadPic(0,d2,x1,y1-d5,0,0); -- 空中
                end
                if d3>=0 then -- 事件
                    local picnum=GetD(sceneid,d3,7);
                    if picnum>0 then
                       JY_LoadPic(0,picnum,x1,y1-d4,0,0);
                    end
                end

                if (i1==-xoff) and (j1==-yoff) then -- 主角
                       JY_LoadPic(0,Mypic*2,x1,y1-d4,0,0);
                end
            end
        end
    end
    
    love.graphics.setScissor(oldScissor[1], oldScissor[2], oldScissor[3], oldScissor[4])
end

local War_XMax=0 -- 战斗地图大小
local War_YMax=0
local War_Num=0 -- 战斗地图层数
local warmap = {}

--[[
//加载战斗地图
// WarIDXfilename/WarGRPfilename 战斗地图idx/grp文件名
// mapid 战斗地图编号
// num 战斗地图数据层数   应为6
//         0层 地面数据
//         1层 建筑
//         2层 战斗人战斗编号
//         3层 移动时显示可移动的位置
//         4层 命中效果
//         5层 战斗人对应的贴图
// x_max,x_max   地图大小
--]]
function LoadWarMap(WarIDXfilename, WarGRPfilename, mapid, num, x_max, y_max)
    War_XMax=x_max
    War_YMax=y_max
    War_Num=num

    local p
    local w_size = x_max*y_max*num
    if mapid==0 then -- 第0个地图，从0开始读
        p=0
    else
        local f = FileUtil.open(WarIDXfilename, "rb") -- 读idx文件
        f:seek("set", 4*(mapid-1))
        p = Byte.byte2uintl(f:read(4):byte(1,4))
        f:close()
    end

    warmap = Byte.LoadToTable16(WarGRPfilename, w_size, p, true)
end

-- 取战斗地图数据
function GetWarMap(x, y, level)
    if x<0 or x>=War_XMax or y<0 or y>=War_YMax or level <0 or level >=6 then
        JY_Error("GetWarMap error: data out of range! x=%d,y=%d,level=%d\n",x,y,level)
        return 0
    end

    local s = War_XMax*War_YMax*level+y*War_XMax+x
    local idx = s+1 -- lua starts with 1
    return warmap[idx]
end

-- 存战斗地图数据
function SetWarMap(x, y, level, v)
    if x<0 or x>=War_XMax or y<0 or y>=War_YMax or level <0 or level >=6 then
        JY_Error("GetWarMap error: data out of range! x=%d,y=%d,level=%d\n",x,y,level)
        return 0
    end

    local s=War_XMax*War_YMax*level+y*War_XMax+x
    local idx = s+1 -- lua starts with 1
    warmap[idx] = v
end

-- 设置某层战斗地图为给定值
function CleanWarMap(level, v)
    local offset = War_XMax*War_YMax*level
    local idx = offset+1 -- lua starts with 1
    for i=1,War_XMax*War_YMax do
        warmap[idx]=v
        idx = idx+1
    end
end

--[[
// 绘制战斗地图
// flag=0  绘制基本战斗地图
//     =1  显示可移动的路径，(v1,v2)当前移动坐标，白色背景(雪地战斗)
//     =2  显示可移动的路径，(v1,v2)当前移动坐标，黑色背景
//     =3  命中的人物用白色轮廓显示
//     =4  战斗动作动画  v1 战斗人物pic, v2贴图所属的加载文件id
//                       v3 武功效果pic  -1表示没有武功效果
--]]
function DrawWarMap(flag, x, y, v1, v2, v3)
    local rect = {x=nil, y=nil, w=nil, h=nil}
    rect.x, rect.y, rect.w, rect.h = love.graphics.getScissor()
    rect.x = rect.x or 0
    rect.y = rect.y or 0
    rect.w = rect.w or CONFIG.Width
    rect.h = rect.h or CONFIG.Height

    -- 根据g_Surface的剪裁来确定循环参数。提高绘制速度
    local istart=math.floor((rect.x-math.floor(CONFIG.Width/2))/(2*CONFIG.XScale))-1-CONFIG.WMapAddX
    local iend=math.floor((rect.x+rect.w-math.floor(CONFIG.Width/2))/(2*CONFIG.XScale))+1+CONFIG.WMapAddX

    local jstart=math.floor((rect.y-math.floor(CONFIG.Height/2))/(2*CONFIG.YScale))-1
    local jend=math.floor((rect.y+rect.h -math.floor(CONFIG.Height/2))/(2*CONFIG.YScale))+1

    FillColor(0,0,0,0,0)

    -- 绘战斗地面
    for j=0, 2*jend-2*jstart+CONFIG.WMapAddY do
        for i=istart, iend do
            local i1=i+math.floor(j/2)+jstart
            local j1=-i+math.floor(j/2)+j%2+jstart
   
            local x1=CONFIG.XScale*(i1-j1)+math.floor(CONFIG.Width/2)
            local y1=CONFIG.YScale*(i1+j1)+math.floor(CONFIG.Height/2)
            local xx=x+i1
            local yy=y+j1
            if (xx>=0) and (xx<War_XMax) and (yy>=0) and (yy<War_YMax) then
                local num=GetWarMap(xx,yy,0)
                if num>0 then
                    JY_LoadPic(0,num,x1,y1,0,0); -- 地面
                end
            end
        end
    end

    if (flag==1) or (flag==2) then -- 在地面上绘制移动范围
        lib.Debug(string.format("DrawWarMap: flag=%d, drawing move range", flag))
        for j=0, 2*jend-2*jstart+CONFIG.WMapAddY do
            for i=istart,iend do
                local i1=i+math.floor(j/2)+jstart
                local j1=-i+math.floor(j/2)+j%2+jstart
        
                local x1=CONFIG.XScale*(i1-j1)+math.floor(CONFIG.Width/2)
                local y1=CONFIG.YScale*(i1+j1)+math.floor(CONFIG.Height/2)
                local xx=x+i1
                local yy=y+j1
                if (xx>=0) and (xx<War_XMax) and (yy>=0) and (yy<War_YMax) then
                    if GetWarMap(xx,yy,3)<128 then
                        local showflag
                        if flag==1 then
                            showflag=2+4
                        else
                            showflag=2+8
                        end

                        if (xx==v1) and (yy==v2) then
                            JY_LoadPic(0,0,x1,y1,showflag,128)
                        else
                            JY_LoadPic(0,0,x1,y1,showflag,64)
                        end
                    end
                end
            end
        end
    end

    -- 绘战斗建筑和人
    for j=0, 2*jend-2*jstart+CONFIG.WMapAddY do
        for i=istart,iend do
            local i1=i+math.floor(j/2)+jstart
            local j1=-i+math.floor(j/2)+j%2+jstart
    
            local x1=CONFIG.XScale*(i1-j1)+math.floor(CONFIG.Width/2)
            local y1=CONFIG.YScale*(i1+j1)+math.floor(CONFIG.Height/2)
            local xx=x+i1
            local yy=y+j1
            if (xx>=0) and (xx<War_XMax) and (yy>=0) and (yy<War_YMax) then
                local num=GetWarMap(xx,yy,1) -- 建筑
                if num>0 then
                    JY_LoadPic(0,num,x1,y1,0,0)
                end

                num=GetWarMap(xx,yy,2) -- 战斗人
                if num>=0 then
                    local pic=GetWarMap(xx,yy,5) -- 人贴图
                    if pic>=0 then
                        if flag==0 or flag==1 or flag==2 or flag==5 then
                            -- 人物常规显示
                            JY_LoadPic(0,pic,x1,y1,0,0)
                        elseif flag==3 then
                            if GetWarMap(xx,yy,4)>1 then -- 命中
                                JY_LoadPic(0,pic,x1,y1,4+2,255) -- 变黑
                            else
                                JY_LoadPic(0,pic,x1,y1,0,0)
                            end
                        elseif flag==4 then
                            if (xx==x) and (yy==y) then
                                if v2==0 then
                                    JY_LoadPic(0,pic,x1,y1,0,0)
                                else
                                    JY_LoadPic(v2,v1,x1,y1,0,0)
                                end
                            else
                                 JY_LoadPic(0,pic,x1,y1,0,0)
                            end
                        end
                    end
                end

                if flag==4 and v3>=0 then -- 武功效果
                    local effect=GetWarMap(xx,yy,4)
                    if effect>0 then
                         JY_LoadPic(3,v3,x1,y1,0,0)
                    end
                end


            end
        end
    end
end

-- 导出字体获取，供 engine_love2d 的 M.dialog 做真实字体度量。
-- 实测 simsun.ttf@24: 汉字 24.00px (1.0em)、ASCII 12.00px (0.5em)、
-- font:getHeight() = 27.00px。用真实度量而非 CC.DefaultFont 常量，
-- 才能自适应未来换字体 / 换字号 / 换分辨率。
M.getFont = getFont

return M
