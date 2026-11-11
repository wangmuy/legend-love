-- tests/mod_boot_harness.lua
-- 无头启动链路 harness：bit32 polyfill + 最小 love stub + Lua 5.4 format 容错。
-- 被 tests/unit/test_mod_boot.lua 与 tests/unit/boot_one_mod.lua 共享。
local M = {}

local function ensureBit32()
    if _G.bit32 then return end
    local M = {}
    function M.band(a, b) local r, bit = 0, 1
        for _ = 1, 32 do local x, y = a % 2, b % 2
            if x == 1 and y == 1 then r = r + bit end
            a = (a - x) / 2; b = (b - y) / 2; bit = bit * 2 end
        return r end
    function M.bor(a, b) local r, bit = 0, 1
        for _ = 1, 32 do local x, y = a % 2, b % 2
            if x == 1 or y == 1 then r = r + bit end
            a = (a - x) / 2; b = (b - y) / 2; bit = bit * 2 end
        return r end
    function M.bxor(a, b) local r, bit = 0, 1
        for _ = 1, 32 do local x, y = a % 2, b % 2
            if x ~= y then r = r + bit end
            a = (a - x) / 2; b = (b - y) / 2; bit = bit * 2 end
        return r end
    function M.bnot(a) a = a % 0x100000000; return 0xFFFFFFFF - a end
    function M.lshift(a, b) return (a * 2 ^ b) % 0x100000000 end
    function M.rshift(a, b) return math.floor((a % 0x100000000) / 2 ^ b) end
    function M.arshift(a, b) if a >= 0x80000000 then a = a - 0x100000000 end; return math.floor(a / 2 ^ b) end
    function M.btest(a, b) return M.band(a, b) ~= 0 end
    function M.extract(n, f, w) return M.band(M.rshift(n, f), 2 ^ w - 1) end
    function M.replace(n, v, f, w)
        local mask = 2 ^ w - 1
        return M.bor(M.band(n, M.bnot(M.lshift(mask, f))), M.lshift(M.band(v, mask), f)) end
    _G.bit32 = M
end

local function installLoveStub()
    local function noop() return nil end
    local function newObj() return setmetatable({}, { __index = function() return noop end }) end

    -- 基于真实 io 的最小 love File 对象，实现 lib_file 使用的 loveStream 接口：
    -- open/read/write/tell/getSize/seek/close/flush/isOpen
    local FileMT = {}
    FileMT.__index = FileMT
    local function newFileObj(path)
        return setmetatable({ path = path, fh = nil, pos = 0 }, FileMT)
    end
    function FileMT:open(mode)
        local ioMode = ({ r = "rb", w = "wb", a = "ab", c = "r+b" })[mode] or "rb"
        local fh = io.open(self.path, ioMode)
        if not fh and mode == "c" then fh = io.open(self.path, "wb") end
        if not fh then return false end
        self.fh = fh
        return true
    end
    function FileMT:read(n)
        if n == 0 then return "" end
        return self.fh:read(n)
    end
    function FileMT:write(s) return self.fh:write(s) end
    function FileMT:tell() return self.fh:seek() end
    function FileMT:getSize()
        local cur = self.fh:seek()
        local size = self.fh:seek("end")
        self.fh:seek("set", cur)
        return size
    end
    function FileMT:seek(pos) return self.fh:seek("set", pos) end
    function FileMT:close() if self.fh then self.fh:close(); self.fh = nil end return true end
    function FileMT:flush() if self.fh then self.fh:flush() end return true end
    function FileMT:isOpen() return self.fh ~= nil end

    _G.love = {
        filesystem = {
            load = function(p) return loadfile(p) end,
            read = function(p)
                local f = io.open(p, "rb"); if not f then return nil end
                local d = f:read("*a"); f:close(); return d
            end,
            lines = function(p)
                local f = io.open(p, "rb")
                if not f then return function() return nil end end
                return f:lines()
            end,
            getInfo = function(p)
                local f = io.open(p, "rb")
                if f then
                    local size = f:seek("end"); f:close()
                    return { type = "file", size = size }
                end
                return nil
            end,
            getSaveDirectory = function() return "/tmp" end,
            createDirectory = function() return true end, write = function() return true end, remove = os.remove,
            newFile = function(p) return newFileObj(p) end,
            newFileData = function() return newObj() end,
            exists = function(p)
                local f = io.open(p, "rb")
                if f then f:close(); return true end
                return false
            end,
        },
        graphics = setmetatable({
            newImage = function() return { getWidth = function() return 1 end, getHeight = function() return 1 end, setFilter = noop } end,
            newFont = function() return { getWidth = function() return 1 end, getHeight = function() return 1 end, setFilter = noop } end,
            newQuad = function() return {} end,
            getColor = function() return 255, 255, 255, 255 end,
            getScissor = function() return nil end,
        }, { __index = function() return noop end }),
        audio = { newSource = function() return { setVolume = noop, play = noop, stop = noop, isPlaying = function() return false end, setLooping = noop } end },
        image = { newImageData = function() return newObj() end },
        timer = { getTime = function() return os.clock() end, getFPS = function() return 60 end, sleep = noop },
        event = { quit = noop },
        window = { setTitle = noop, setMode = noop, getMode = function() return 1024, 768, {} end },
        keyboard = { isDown = function() return false end, setKeyRepeat = noop },
        mouse = { getPosition = function() return 0, 0 end, isDown = function() return false end },
        math = { random = math.random },
    }
end

local function installFormatTolerance()
    local orig = string.format
    string.format = function(fmt, ...)
        local n = select("#", ...)
        local a = {}
        for i = 1, n do
            local v = select(i, ...)
            if type(v) == "number" then v = math.tointeger(v) or v end
            a[i] = v
        end
        local ok, r = pcall(orig, fmt, table.unpack(a, 1, n))
        if ok then return r end
        for i = 1, n do if type(a[i]) == "number" then a[i] = math.floor(a[i]) end end
        return orig(fmt, table.unpack(a, 1, n))
    end
end

function M.setup()
    M.ensureBit32()
    M.installLoveStub()
    M.installFormatTolerance()
end

M.ensureBit32 = ensureBit32
M.installLoveStub = installLoveStub
M.installFormatTolerance = installFormatTolerance

return M
