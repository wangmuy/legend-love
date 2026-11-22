-- 按位与 / 右移：跨版本后端（bit32 / 5.3+ 运算符 / luabit）。
-- 必须在 `_ENV = M` **之前** require 并保存引用：换环境后就查不到全局了。
local Bit = require "framework.lib_bit"

local M = {}
do
    setmetatable(M, { __index = _G, })
    if setfenv then
        setfenv(1, M) -- for 5.1
    else
        _ENV = M -- for 5.2
    end

    -- 历史实现只在 `_VERSION < "Lua 5.2"` 时装 luabit，默认 5.2+ 必有原生
    -- bit32；但 **Lua 5.4 起 bit32 已被移除**（5.5 亦然），导致本文件里
    -- bit32.band / bit32.rshift 在 5.4/5.5 下全部 nil 索引崩溃。
    -- 改为无条件用 lib_bit 兜底（它优先选原生实现，性能无差异）。
    if not bit32 then
        bit32 = Bit.api
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

-- ============================================================
-- 旧贴图子系统已删除（port-legacy-picture-removal Task 6，2026-11-22）
--
-- 删掉的是 425 行「引擎自己解析 .idx/.grp + 维护 picFileCache + RLE 解码」。
-- 替代链路（引擎不再看见容器格式）：
--   framework/sprite_atlas.lua    解析 .idx/.grp + 帧号映射
--   framework/sprite_decoder.lua  RLE + 调色板解码（纯数据）
--   EngineAPI.sprite.createFromRGBA / drawHandle   引擎只上传字节 + 画句柄
-- ============================================================


local currentMusic = nil

-- ---------------------------------------------------------------------------
-- 音量（REQ-VOL-1 / REQ-VOL-2）
--
-- 量程 0-128，增益线性 `value / 128`。这两个数字不是随意选的：
--
--   SDL_mixer:  Mix_Volume(ch, v)     v ∈ [0,128]   线性振幅
--   LÖVE 11.x:  Source:setVolume(g)   g ∈ [0,1]     线性振幅
--
--   →  g = v / 128  是【精确等值映射】，零失真。
--
-- 为什么不能用平方增益（(v/128)^2）：
--   20 个 MOD 的 kysmod.ini 都有按 0-128 线性调好的 VOLUME（5/10/17/22），
--   改成平方会把它们压到原来的 1/5 ~ 1/25（VOLUME=32 的 0.25 变成 0.0625）。
--   「保留 MOD 作者调音意图」是本功能的核心需求，平方会让它完全落空。
--   详见 openspec/changes/audio-settings/design.md ADR-AS-003。
--
-- 为什么不能用 love.audio.setVolume：
--   它是**全局**音量，无法区分音乐与音效，而两者需要独立调节。
--   因此必须对每个 Source 单独 `:setVolume()`。
-- ---------------------------------------------------------------------------

-- 默认值 64 / 90（= 50% / 70%）。真正的初始值由 framework/audio_settings.lua
-- 在初始化时通过 EngineAPI.audio.setMusicVolume / setSFXVolume 推入；
-- 这里只是「框架尚未接线时」的兜底，避免出现 0 音量。
local musicVolume = 64
local sfxVolume = 90

local function toGain(value)
    local v = tonumber(value) or 0
    if v < 0 then v = 0 end
    if v > 128 then v = 128 end
    return v / 128
end

--- 设置音乐音量（0-128）
-- 推 + 拉：既立即应用到正在播放的 currentMusic，也作为后续 newSource 的初值。
-- @param value number 0-128
function SetMusicVolume(value)
    musicVolume = tonumber(value) or musicVolume
    if musicVolume < 0 then musicVolume = 0 end
    if musicVolume > 128 then musicVolume = 128 end
    if currentMusic and currentMusic.setVolume then
        pcall(currentMusic.setVolume, currentMusic, toGain(musicVolume))
    end
end

--- 取当前音乐音量（0-128）
-- @return number
function GetMusicVolume()
    return musicVolume
end

--- 设置音效音量（0-128）
-- 只有「拉」：音效 source 是即用即弃的（不保留引用），所以只能在
-- PlayWAV 创建时应用。已在播放的短音效不受事后调节影响（时长都很短）。
-- @param value number 0-128
function SetSFXVolume(value)
    sfxVolume = tonumber(value) or sfxVolume
    if sfxVolume < 0 then sfxVolume = 0 end
    if sfxVolume > 128 then sfxVolume = 128 end
end

--- 取当前音效音量（0-128）
-- @return number
function GetSFXVolume()
    return sfxVolume
end

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
        -- 拉：新 source 必须应用当前音乐音量，否则只有第一次生效
        if currentMusic.setVolume then
            pcall(currentMusic.setVolume, currentMusic, toGain(musicVolume))
        end
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
        -- 拉：音效 source 即用即弃，音量只能在这里应用
        if source_or_err.setVolume then
            pcall(source_or_err.setVolume, source_or_err, toGain(sfxVolume))
        end
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

-- 暴露给 EngineAPI.map.setTile 用（原版是 local，外部调不到）
JY_SetMMap = SetMMap

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

-- ============================================================
-- DrawMMap / DrawSMap / DrawWarMap 已删除（port-legacy-picture-removal Task 6）
--
-- 三个函数共 363 行「等距投影 + 逐格 JY_LoadPic」，而 JY_LoadPic（= PicLoadCache）
-- 已随旧贴图子系统删除。替代品是 framework/map_render.lua 的
-- drawMain / drawScene / drawBattle（用 sprite.drawHandle 画已解好的 handle）。
-- ============================================================

function UnloadMMap()
    mmap.earth=nil
    mmap.surface=nil
    mmap.building=nil
    mmap.buildx=nil
    mmap.buildy=nil
end

-- ============================================================
-- 云朵系统已搬到 framework/cloud_layer.lua
-- （port-legacy-picture-removal Task 4，2026-11-22）
--
-- 原来的 190 行（CloudDecodeFrame / CloudBakeImage / CloudCreateOnSide /
-- CloudCreate / CloudLoadAndInit / CloudTick / DrawClouds / CloudGetList）
-- 只有 2 行真碰引擎，其余是纯数据处理 + 纯数学。现在：
--   解码 → framework/sprite_decoder.lua（实测 9/9 帧与原状态机一致）
--   烘焙 → framework/cloud_layer.lua 的 bakeRGBA（产出 RGBA 字节）
--   绘制 → EngineAPI.sprite.drawHandle（引擎只认句柄）
-- 引擎侧零改动即可换引擎，见 change 的 design ADR-PORT-020。
-- ============================================================


local S_XMax = 0
local S_YMax = 0
-- 暴露给 EngineAPI.map.getSceneSize（原版是 local，framework 拿不到）
function GetSceneSize()
    return { w = S_XMax, h = S_YMax }
end
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
    Debug("SaveSMap: start")
    
    if smap == nil then 
        Debug("SaveSMap: smap is nil, returning")
        return 
    end
    
    local s_size = S_XMax*S_YMax*6*S_Num
    Debug(string.format("SaveSMap: saving %d elements to %s", s_size, Sfilename))
    
    Byte.SaveFromTable16(smap, Sfilename, s_size, 1, nil, true)
    Debug(string.format("SaveSMap: S file done (%.2fs)", os.clock() - startTime))
    
    if dmap == nil then 
        Debug("SaveSMap: dmap is nil, returning")
        return 
    end
    
    local d_size = D_Num1*D_Num2*S_Num
    Debug(string.format("SaveSMap: saving %d elements to %s", d_size, Dfilename))
    
    Byte.SaveFromTable16(dmap, Dfilename, d_size, 1, nil, true)
    Debug(string.format("SaveSMap: complete (%.2fs total)", os.clock() - startTime))
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


local War_XMax=0 -- 战斗地图大小
local War_YMax=0
-- 暴露给 EngineAPI.map.getBattleSize（原版是 local，framework 拿不到）
function GetBattleSize()
    return { w = War_XMax, h = War_YMax }
end
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


-- 导出字体获取，供 engine_love2d 的 M.dialog 做真实字体度量。
-- 实测 simsun.ttf@24: 汉字 24.00px (1.0em)、ASCII 12.00px (0.5em)、
-- font:getHeight() = 27.00px。用真实度量而非 CC.DefaultFont 常量，
-- 才能自适应未来换字体 / 换字号 / 换分辨率。
M.getFont = getFont

return M
