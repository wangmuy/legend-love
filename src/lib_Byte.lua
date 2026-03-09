require "lib_log"

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
        bit32 = bit -- band rshift
        bit32.rshift = bit.brshift
    end
end

-- convert bytes(little endian) to 32 bit signed int
function byte2sintl(b1, b2, b3, b4)
    if not b4 then error("need four bytes to convert to int",2) end
    local n = b1 + b2*256 + b3*65536 + b4*16777216
    return n > 2147483648 and n-4294967296 or n
end

-- convert bytes(little endian) to 32 bit unsigned int
function byte2uintl(b1, b2, b3, b4)
    if not b4 then error("need four bytes to convert to int",2) end
    local n = b1 + b2*256 + b3*65536 + b4*16777216
    return n
end

-- convert bytes(little endian) to 16 bit signed short
function byte2sshortl(b1, b2)
    if not b2 then error("need two bytes to convert to short",3) end
    local n = b1 + b2*256
    return n > 32767 and n-65536 or n
end

-- convert bytes(little endian) to 16 bit unsigned short
function byte2ushortl(b1, b2)
    if not b2 then error("need two bytes to convert to short",3) end
    local n = b1 + b2*256
    return n
end

-- convert bytes(big endian) to 16 bit unsigned short
function byte2ushortb(b1, b2)
    if not b2 then error("need two bytes to convert to short",3) end
    local n = b1*256 + b2
    return n
end

-- convert 16bit signed short to bytes(little endian)
function sshort2bytel(s)
    local us = s>=0 and s or 65536+n
    return bit32.band(us,0xFF), bit32.rshift(us,8)
end

-- convert 16bit signed short to bytes(big endian)
function sshort2byteb(s)
    local us = s>=0 and s or 65536+n
    return bit32.rshift(us,8), bit32.band(us,0xFF)
end

function LoadToTable16Inner(t, filename, size, seekPos, isLittleEndian)
    local oldsize = t and #t or 0
    local tbl = t or {}
    local f = io.open(filename, "rb")
    if seekPos~=nil and seekPos>0 then f:seek("set", seekPos) end
    for i=1,size do
        local b1,b2 = f:read(2):byte(1,2)
        tbl[i] = isLittleEndian and byte2sshortl(b1,b2) or byte2ushortb(b1,b2)
    end
    f:close()
    if oldsize > size then
        for i=size+1,oldsize do tbl[i]=nil end
    end
    return tbl
end

function LoadToTable16(filename, size, seekPos, isLittleEndian)
    return LoadToTable16Inner(nil, filename, size, seekPos, isLittleEndian)
end

function SaveFromTable16(t, filename, size, begIdx, seekPos, isLittleEndian)
    if t==nil or #t<=0 then return end
    local f = io.open(filename, "wb")
    if seekPos~=nil and seekPos>0 then f:seek("set", seekPos) end
    local b = begIdx or 1
    local s = size or #t
    for i=b,b+s-1 do
        f:write( string.char( isLittleEndian and sshort2bytel(t[i]) or sshort2byteb(t[i]) ) )
    end
    f:close()
end

function LoadToTable8(t, filename, size, seekPos)
    local oldsize = t and #t or 0
    local tbl = t or {}
    local f = io.open(filename, "rb")
    if seekPos~=nil and seekPos>0 then f:seek("set", seekPos) end
    for i=1,size do
        tbl[i] = f:read(1):byte(1)
    end
    f:close()
    if oldsize > size then
        for i=size+1,oldsize do tbl[i]=nil end
    end
    return tbl
end

function SaveFromTable8(t, filename, size, begIdx, seekPos)
    if t==nil or #t<=0 then return end
    local f = io.open(filename, "wb")
    if seekPos~=nil and seekPos>0 then f:seek("set", seekPos) end
    local b = begIdx or 1
    local s = size or #t
    for i=b,b+s-1 do
        f:write( string.char(t[i]) )
    end
    f:close()
end

--[[
// byte数组lua函数
/*  lua 调用形式：(注意，位置都是从0开始
     handle=Byte.create(size);
     Byte.release(h);
     handle=Byte.loadfile(h,filename,start,length);
     Byte.savefile(h,filename,start,length);
     v=Byte.get16(h,start);
     Byte.set16(h,start,v);
     v=Byte.getu16(h,start);
     Byte.setu16(h,start,v);
     v=Byte.get32(h,start);
     Byte.set32(h,start,v);
     str=Byte.getstr(h,start,length);
     Byte.setstr(h,start,length,str);
  */
--]]

-- 假设每个元素是byte数据
function create(size)
    local t = {}
    for i=1,size do
        t[i] = 0
    end
    return t
end

function loadfile(t, filename, start, length)
    return LoadToTable8(t, filename, length, start)
end

function savefile(t, filename, start, length)
    SaveFromTable8(t, filename, length, 1, start)
end

function get16(t, start)
    local idx=start+1 -- lua starts with 1
    return byte2sshortl(bit32.band(t[idx], 0xFF), bit32.band(t[idx+1], 0xFF))
end

function set16(t, start, v)
    local idx=start+1 -- lua starts with 1
    t[idx] = bit32.band(v,0xFF)
    t[idx+1] = bit32.rshift(bit32.band(v,0xFF00), 8)
end

function getu16(t, start)
    local idx=start+1 -- lua starts with 1
    return byte2ushortl(bit32.band(t[idx], 0xFF), bit32.band(t[idx+1], 0xFF))
end

function setu16(t, start, v)
    local idx=start+1 -- lua starts with 1
    t[idx] = bit32.band(v, 0xFF)
    t[idx+1] = bit32.rshift(v, 8)
end

function get32(t, start)
    local idx=start+1 -- lua starts with 1
    return byte2sintl(bit32.band(t[idx], 0xFF), bit32.band(t[idx+1], 0xFF),
        bit32.band(t[idx+2], 0xFF), bit32.band(t[idx+3], 0xFF))
end

function set32(t, start, v)
    local idx=start+1 -- lua starts with 1
        local tmpus = bit32.band(v, 0xFFFF)
        t[idx]   = bit32.band(v,                    0xFF)
        t[idx+1] = bit32.rshift(bit32.band(v,     0xFF00), 8)
        t[idx+2] = bit32.rshift(bit32.band(v,   0xFF0000), 16)
        t[idx+3] = bit32.rshift(bit32.band(v, 0xFF000000), 24)
end

function getstr(t, start, length)
    local tmptbl = {}
    local idx=start+1 -- lua starts with 1

    local c = bit32.band(t[idx], 0xFF)
    while c>0 and length>0 do
        tmptbl[#tmptbl+1] = string.char(c)
        idx = idx+1
        length = length-1
        c = bit32.band(t[idx], 0xFF)
    end
    return table.concat(tmptbl, "")
end

function setstr(t, start, length, str)
    local idx = start+1
    for c in str:gmatch(".") do
        if length <=0 then break end
        t[idx] = string.byte(c)
        idx=idx+1
        length = length-1
    end
end

return M
