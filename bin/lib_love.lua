local M = {}
do
    setmetatable(M, { __index = _G, })
    if setfenv then
        setfenv(1, M) -- for 5.1
    else
        _ENV = M -- for 5.2
    end
    if _VERSION < "Lua 5.2" then
        require "luabit"
        bit32 = bit
    end
end

require "config"
dofile(CONFIG.ScriptPath .. "jyconst.lua")
SetGlobalConst()
require "lib_log"
local Byte = require "lib_Byte"

keymap = {
    ["escape"] = VK_ESCAPE,
    [" "] = VK_SPACE,
    ["return"] = VK_RETURN,
    ["up"] = VK_UP,
    ["down"] = VK_DOWN,
    ["left"] = VK_LEFT,
    ["right"] = VK_RIGHT,
}

function GetKey()
    --love.graphics.present()
    local e,a,b,c,d
    if not love.event then return -1 end
    love.event.pump()
    local f, s, var = love.event.poll()
    e,a,b,c,d = f(s, var)
    if e==nil or e~="keypressed" then return -1 end
    return keymap[a]
end

function EnableKeyRepeat(delay, interval)
    love.keyboard.setKeyRepeat(delay/1000.0, 1.0/interval) -- 0.8.0 and earliar
end

function Delay(millis)
    love.timer.sleep(millis/1000.0)
end

function GetTime()
    return love.timer.getMicroTime() * 100
end

local fontTbl = {}
local function getFont(fontname)
    if fontname==nil then return end
    if fontTbl[fontname] == nil then
        fontTbl[fontname] = love.graphics.newFont(fontname, 20)
    end
    return fontTbl[fontname]
end
  
function DrawStr(x, y, str, color, size, fontname)
    --Debug("DrawStr: x,y=%d,%d, str=%s, color=%d, size=%d, fontname=%s", x,y,str,color,size,fontname)
    love.graphics.setFont(getFont(fontname))
    love.graphics.setColor(GetRGB(color))
    love.graphics.print(str, x, y)
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
// 如果x1,y1,x2,y2均为0，则填充整个表面
// color, 填充色，用RGB表示，从高到低字节为0RGB
--]]
function FillColor(x1, y1, x2, y2, color)
    local r,g,b = GetRGB(color)
    --Debug("FillColor: %d, %d, %d", r,g,b)
        love.graphics.setBackgroundColor(r,g,b)
        love.graphics.clear()
end

--[[
// 背景变暗
// 把源表面(x1,y1,x2,y2)矩形内的所有点亮度降低
// bright 亮度等级 0-256 --]]
function Background(x1, y1, x2, y2, Bright)
    if x2<x1 or y2<y1 then return end
    love.graphics.setColor(0, 0, 0, Bright)
    love.graphics.rectangle("fill", x1, y1, x2-x1+1, y2-y1+1)
end

--[[
// 绘制矩形框
// (x1,y1)--(x2,y2) 框的左上角和右下角坐标
// color 颜色
--]]
function DrawRect(x1, y1, x2, y2, color)
    --if x2<x1 or y2<y1 then return end
    love.graphics.setColor(GetRGB(color))
    love.graphics.rectangle("line", x1, y1, x2-x1+1, y2-y1+1)
end

--[[
//显示表面
//flag = 0 显示全部表面  =1 按照SetClip设置的矩形显示，如果没有矩形，则不显示
--]]
function ShowSurface(flag)
    love.graphics.present()
end

function ShowSlow(delaytime, flag)
    love.graphics.present()
end

local color32Pallette = {}
local function LoadPallette(filename)
    local f = io.open(filename, "rb")
    if f == nil then return false end
    for i=1,256 do
        local c0, c1, c2 = f:read(3):byte(1,3)
        color32Pallette[i] = c0*4*65536+c1*4*256+c2*4
        --print(i .. ":" .. color32Pallette[i] .. "," .. c0 .. "," .. c1 .. "," .. c2)
    end
    f:close()
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
        local f = io.open(self.grpfilename, "rb")
        if self.idx[picid]==nil or self.idx[picid+1]==nil then
            Debug("getPic: %s picid=%d, idx=%d,%d", self.grpfilename, picid, self.idx[picid] or -1, self.idx[picid+1] or -1)
        end
        self.pcache[picid] = LoadPic(f, self.idx[picid], self.idx[picid+1])
        f:close()
    end
    return self.pcache[picid]
end

local function FileLength(fname)
    local f = io.open(fname, "rb")
    if f == nil then return -1 end
    local len = f:seek("end")
    f:close()
    return len
end

function LoadPic(openfile, idx1, idx2)
    if openfile == nil or idx2 <= idx1 then return nil end
    openfile:seek("set", idx1)
    local w = Byte.byte2ushortl(openfile:read(2):byte(1,2))
    local h = Byte.byte2ushortl(openfile:read(2):byte(1,2))
    local xoff = Byte.byte2ushortl(openfile:read(2):byte(1,2))
    local yoff = Byte.byte2ushortl(openfile:read(2):byte(1,2))
    --Debug("LoadPic: %d %d, off: %d, %d" , w, h, xoff, yoff)

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
                imgdata:setPixel(x, y, r, g, b, 255)
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
                    imgdata:setPixel(x, y, r, g, b, 255)
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
    cache.img = love.graphics.newImage(imgdata)
    imgdata = nil
    return cache
end

--[[
// 加载文件信息
// filename 文件名 
// id  0 - PIC_FILE_NUM-1
--]]
function PicLoadFile(idxfilename, grpfilename, fileid)
    if fileid < 0 then return end
    fileid = fileid+1 -- lua starts with 1

    --Debug("PicLoadFile: %s %d", idxfilename, fileid)
    local pic_file = PicFile:new()
    pic_file.grpfilename = grpfilename
    picFileCache[fileid] = pic_file

    -- 读取idx文件
    local idxlen = FileLength(idxfilename)
    local grplen = FileLength(grpfilename)
    if idxlen < 0 or grplen < 0 then return end
    local f = io.open(idxfilename, "rb")
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
    picid = math.floor(picid/2)
    picid = picid+1 -- lua starts with 1
    fileid = fileid+1 -- lua starts with 1
    local pcache = picFileCache[fileid]:getPic(picid)
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
    picid = math.floor(picid/2)
    fileid = fileid+1 -- lua starts with 1
    picid = picid+1 -- lua starts with 1
    picfile = picFileCache[fileid]
    if picfile == nil or fileid < 1 or picid < 1 or picid > #(picfile.idx) then
        return
    end
    local piccache = picfile:getPic(picid)
    local xnew = x
    local ynew = y
    if bit32.band(flag, 0x1) == 0 then
        xnew = x - piccache.xoff
        ynew = y - piccache.yoff
    end

    love.graphics.draw(piccache.img, xnew, ynew)
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

function PlayMIDI(filename)
end

function PlayWAV(filename)
end

function PlayMPEG(filename)
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
                                        local idxp = p+1
                                        tmpBuild = buildList[idxp-1] -- last one
                                        buildList[idxp-1] = BuildingType:new()
                                        table.insert(buildList, idxk+1, tmpBuild)
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
end

function UnloadMMap()
    mmap.earth=nil
    mmap.surface=nil
    mmap.building=nil
    mmap.buildx=nil
    mmap.buildy=nil
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
    if smap == nil then return end
    local s_size = S_XMax*S_YMax*6*S_Num
    Byte.SaveFromTable16(smap, Sfilename, s_size, 0, true)
    if dmap == nil then return end
    local d_size = D_Num1*D_Num2*S_Num
    Byte.SaveFromTable16(dmap, Dfilename, d_size, 0, true)
end

function GetS(id, x, y, level)
    if id<0 or id>=S_Num or x<0 or x>=S_XMax or y<0 or y>=S_YMax or level <0 or level >=6 then
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
    if Sceneid<0 or Sceneid>=S_Num then
        JY_Error("GetD error: sceneid=%d out of range!\n",Sceneid)
        return 0
    end

    local s = D_Num1*D_Num2*Sceneid+id*D_Num2+i
    local idx = s+1 -- lua starts with 1
    return dmap[idx]
end

-- 存D*
function SetD(Sceneid, id, i, v)
    if Sceneid<0 or Sceneid>=S_Num then
        JY_Error("GetD error: sceneid=%d out of range!\n",Sceneid)
        return 0
    end

    local s = D_Num1*D_Num2*Sceneid+id*D_Num2+i
    local idx = s+1 -- lua starts with 1
    dmap[idx] = v
end

-- 绘制场景地图
function DrawSMap(sceneid, x,  y, xoff, yoff, Mypic)
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
        local f = io.open(WarIDXfilename, "rb") -- 读idx文件
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

return M
