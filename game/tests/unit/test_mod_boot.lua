-- tests/unit/test_mod_boot.lua
-- 全启动链路无头验证（allmods-mingdong-activate，Contract D 强化）
--
-- 目的：不依赖显示器与 love 二进制，用最小 love stub + tests/engine_test.lua
-- 的 EngineAPI 无头实现，真实执行：
--   lib.init → EventBridge.init → JYMainAdapter.init → LoadRecord(0) → GAME_FIRSTMMAP → GAME_MMAP
-- 断言 mingdong 激活后整条游玩启动路径无报错，且 MOD 路径/ini 生效。
--
-- 注意：本测试会设置全局状态（_G.love、_G.CC、_G.JY 等），必须在最后运行，
-- 且运行前确保 _G.bit32 存在（Lua 5.4 polyfill）。

local TestHelper = require("tests.test_helper")
local TestModBoot = {}

-- Lua 5.4 bit32 polyfill（游戏正常在 LuaJIT/5.1 下运行，自带 bit32 shim）
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

-- 最小 love stub
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
            -- love.filesystem.getSaveDirectory 的桩。运行时代码不调用它
            -- （存档走 ModData.SaveDir 的相对路径），这里返回跨平台临时目录，
            -- 避免留下 Linux 专有的 /tmp 字面量误导后来者。
            getSaveDirectory = function() return require("framework.fs_compat").tempDir() end,
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

-- Lua 5.4: %d with float 容错（LuaJIT 容忍）。
-- 兼容 5.1：该版本没有 table.unpack（只有全局 unpack），也没有 math.tointeger。
local function installFormatTolerance()
    local unpackFn = table.unpack or unpack
    local orig = string.format
    string.format = function(fmt, ...)
        local n = select("#", ...)
        local a = {}
        for i = 1, n do
            local v = select(i, ...)
            if type(v) == "number" and math.tointeger then
                v = math.tointeger(v) or v
            end
            a[i] = v
        end
        local ok, r = pcall(orig, fmt, unpackFn(a, 1, n))
        if ok then return r end
        for i = 1, n do if type(a[i]) == "number" then a[i] = math.floor(a[i]) end end
        return orig(fmt, unpackFn(a, 1, n))
    end
end

-- ============================================================
-- 全启动链路：lib.init → init → LoadRecord(0) → FIRSTMMAP → MMAP
-- ============================================================

function TestModBoot.testFullBootChainWithMingdong()
    print("\n=== Test: full boot chain with mingdong active ===")

    ensureBit32()
    installLoveStub()
    installFormatTolerance()

    -- 激活 mingdong（不走 active_mod.txt，模拟运行时状态）
    package.loaded["framework.mod_data"] = nil
    local ModData = require("framework.mod_data")
    ModData.SetActive("mingdong")

    _G.EngineAPI = require("tests.engine_test")

    local EventBridge = require("framework.event_bridge")
    require("framework.config")
    _G.Byte = require("framework.lib_Byte")
    require("engine-love2d.lib_love")
    _G.lib = require("engine-love2d.engine_love2d")

    local okInit, errInit = pcall(function() lib.init() end)
    TestHelper.assertTrue(okInit, "lib.init succeeds: " .. tostring(errInit))

    EventBridge.getInstance():init()
    require(CONFIG.ScriptPath .. "jymain")
    local JYMainAdapter = require("framework.jymain_adapter")
    local okAdapter, errAdapter = pcall(function() JYMainAdapter.init() end)
    TestHelper.assertTrue(okAdapter, "JYMainAdapter.init succeeds: " .. tostring(errAdapter))

    -- MOD 路径 / ini 生效
    TestHelper.assertEquals("mods/mingdong/data/mmap.grp", CC.MMAPPicFile[2], "MMAPPicFile -> MOD")
    TestHelper.assertEquals("mods/mingdong/data/smap.grp", CC.SMAPPicFile[2], "SMAPPicFile -> MOD (alias)")
    TestHelper.assertEquals("mods/mingdong/script/oldtalk.grp", CC.TalkGrpFile, "TalkGrpFile -> MOD")
    TestHelper.assertEquals(1024, CONFIG.Width, "窗口宽保持 config.lua 值（分辨率不映射）")
    TestHelper.assertEquals(768, CONFIG.Height, "窗口高保持 config.lua 值")
    TestHelper.assertEquals(1024, CC.ScreenW, "CC.ScreenW 不被 MOD ini 覆盖")
    TestHelper.assertEquals(768, CC.ScreenH, "CC.ScreenH 不被 MOD ini 覆盖")
    TestHelper.assertEquals(330, CC.MyThingNum, "CC.MyThingNum=330")
    TestHelper.assertEquals(9999, CC.MaxHP, "CC.MaxHP=9999")

    -- 推进若干帧（主菜单）
    local okFrames, errFrames = pcall(function()
        for _ = 1, 30 do
            JYMainAdapter.update(0.016)
            EventBridge.getInstance():update(0.016)
        end
    end)
    TestHelper.assertTrue(okFrames, "30 menu frames run: " .. tostring(errFrames))

    -- 读档（新游戏基础数据 = MOD ranger.grp/ranger.idx）
    -- 记录数必须是 MOD 真实布局（UPedit.ini [R_Modify]）算出的值：
    -- 若仍用原版 CC.*Size（202/260/62/146）会得到 569/268/116/204 并读到错位数据。
    -- 权威段偏移 [1636,116660,186390,193618,223538,223688]：
    --   Person  (116660-1636 )/182 = 632
    --   Thing   (186390-116660)/190 = 367
    --   Scene   (193618-186390)/52  = 139
    --   Wugong  (223538-193618)/136 = 220
    local okLoad, resLoad = pcall(function() return LoadRecord(0) end)
    TestHelper.assertTrue(okLoad, "LoadRecord(0) succeeds: " .. tostring(resLoad))
    TestHelper.assertTrue(resLoad == true, "LoadRecord(0) returns true")
    TestHelper.assertEquals(632, JY.PersonNum, "mingdong PersonNum=632 (MOD layout)")
    TestHelper.assertEquals(367, JY.ThingNum, "mingdong ThingNum=367 (MOD layout)")
    TestHelper.assertEquals(139, JY.SceneNum, "mingdong SceneNum=139 (MOD layout)")
    TestHelper.assertEquals(220, JY.WugongNum, "mingdong WugongNum=220 (MOD layout)")

    -- Big5 -> UTF-8：字符串字段在 ranger.grp 中是 hint，真实值在 ranger.str
    TestHelper.assertEquals("小蝦米", JY.Person[0]["姓名"], "Person[0] 姓名 从旁路表解析")
    TestHelper.assertEquals("胡斐", JY.Person[1]["姓名"], "Person[1] 姓名 从旁路表解析")
    TestHelper.assertEquals("雪山飛狐", JY.Person[1]["外号"], "Person[1] 外号 从旁路表解析（保留繁体）")
    TestHelper.assertEquals("胡斐居", JY.Scene[0]["名称"], "Scene[0] 名称 从旁路表解析")
    TestHelper.assertTrue(JY.Thing[0]["名称"] ~= nil and #JY.Thing[0]["名称"] > 0,
        "Thing[0] 名称非空: " .. tostring(JY.Thing[0]["名称"]))

    -- 进入首次主地图
    local okMap, errMap = pcall(function()
        EventBridge.getInstance():switchState(GAME_FIRSTMMAP)
        for _ = 1, 30 do EventBridge.getInstance():update(0.016) end
    end)
    TestHelper.assertTrue(okMap, "FIRSTMMAP -> MMAP transition: " .. tostring(errMap))
    TestHelper.assertEquals(GAME_MMAP, JY.Status, "JY.Status == GAME_MMAP")
end

-- ============================================================
-- 事件对话读取（REQ-MD-3，运行时 ReadTalk 路径）
-- ============================================================

function TestModBoot.testRuntimeTalkReadWithMingdong()
    print("\n=== Test: runtime ReadTalk with mingdong active ===")

    -- 已在 testFullBootChain 中完成 lib.init / JYMainAdapter.init，此处直接调用游戏函数
    TestHelper.assertNotNil(CC, "CC global exists")
    TestHelper.assertNotNil(JY, "JY global exists")

    local ok, err = pcall(function()
        -- 注：`oldtalk.grp` 用 CRLF（与原版 script/oldtalk.grp 一致），
        -- Lua 5.4 的 read("*line") 仅去掉 \n 不去 \r，故运行时返回值带尾部 \r。
        -- 这是原版就存在的行为（基线 script/oldtalk.grp 同为 CRLF），非 MOD 引入。
        local function strip(s) return (s:gsub("\r$", "")) end
        TestHelper.assertEquals("小兄弟，你好啊。", strip(ReadTalk(0)), "ReadTalk(0)")
        TestHelper.assertEquals("请问你是胡斐胡大哥吗？", strip(ReadTalk(1)), "ReadTalk(1)")
        TestHelper.assertEquals("正是在下．", strip(ReadTalk(2)), "ReadTalk(2)")
        -- 越界读取返回 nil（不报错）
        TestHelper.assertNil(ReadTalk(-1), "ReadTalk(-1) -> nil")
        TestHelper.assertNil(ReadTalk(999999), "ReadTalk(999999) -> nil")
    end)
    TestHelper.assertTrue(ok, "ReadTalk works: " .. tostring(err))
end

-- ============================================================
-- 存档 → 读档 round-trip（REQ-MD-1/4，MOD 数据）
-- ============================================================

function TestModBoot.testSaveLoadRoundTripWithMingdong()
    print("\n=== Test: save/load round-trip with mingdong active ===")

    local FileUtil = require("framework.lib_file")
    local ModData = require("framework.mod_data")
    -- 本测试会在 mods/mingdong/save/ 写测试存档。
    -- 注意：mingdong **自带** r1.grp/d1.grp/s1.grp（源包即如此），测试结束后
    -- 必须恢复到构建产物状态，否则会销毁源包存档（同 mod_check_one 的缺陷）。
    --
    -- 恢复策略 = 自愈式恢复到**源状态**（而非仅恢复测试前状态）：
    -- 若某次测试运行被中途杀死（前台超时 kill 等），「恢复测试前状态」会
    -- 把脏状态原样保留（备份的就是脏状态），污染之后每一次运行——
    -- 本 suite 曾因此连环失败（override 断言 + 末位断言 + save 比对）。
    -- 改为：源包中有的槽文件逐字节拷回，源包没有的删除。
    -- 测试从此幂等，可从任意初始状态自愈。
    local SLOTS = { "r1.grp", "r1.idx", "r1.ovr", "s1.grp", "d1.grp" }
    local SAVEDIR = "mods/mingdong/save/"
    local SRCDIR = "../reference/allmods/kys-mingdong/save/"
    local function restoreSlots()
        for _, n in ipairs(SLOTS) do
            os.remove(SAVEDIR .. n)
            local f = io.open(SRCDIR .. n, "rb")
            if f then
                local data = f:read("*a"); f:close()
                -- 原子写：先写临时文件再 rename，中途被杀不会留下截断文件
                local tmp = SAVEDIR .. n .. ".restore"
                local out = io.open(tmp, "wb")
                if out then
                    out:write(data); out:close()
                    os.rename(tmp, SAVEDIR .. n)
                end
            end
        end
    end
    -- 先清理上一轮可能遗留的存档槽（保证测试可重复运行）
    for _, slot in ipairs({ "r1.idx", "r1.grp", "r1.ovr", "s1.grp", "d1.grp" }) do
        os.remove("mods/mingdong/save/" .. slot)
    end
    local ok, err = pcall(function()
        -- 先确保载入了基础数据（id=0）
        LoadRecord(0)
        local basePersonNum = JY.PersonNum
        TestHelper.assertTrue(basePersonNum > 0, "PersonNum loaded: " .. tostring(basePersonNum))

        -- 存档槽路径应指向 MOD 专属目录（save 隔离）
        TestHelper.assertEquals("mods/mingdong/save/r1.idx", CC.R_IDXFilename[1],
            "slot 1 idx -> MOD save dir")
        TestHelper.assertEquals("mods/mingdong/save/r1.grp", CC.R_GRPFilename[1],
            "slot 1 grp -> MOD save dir")
        TestHelper.assertEquals("mods/mingdong/save/", ModData.SaveDir(),
            "SaveDir -> MOD save dir")

        -- 存档前该槽不应存在（干净状态）
        TestHelper.assertFalse(FileUtil.exists(CC.R_IDXFilename[1]),
            "slot 1 idx absent before first save")

        -- 引擎 SaveRecord 现在会自动从模板播种 rN.idx（无需外部拷贝）
        SaveRecord(1)
        TestHelper.assertTrue(FileUtil.exists(CC.R_IDXFilename[1]),
            "r1.idx auto-seeded by SaveRecord")
        TestHelper.assertTrue(FileUtil.exists(CC.R_GRPFilename[1]), "r1.grp written")
        TestHelper.assertTrue(FileUtil.exists(CC.S_Filename[1]), "s1.grp written")
        TestHelper.assertTrue(FileUtil.exists(CC.D_Filename[1]), "d1.grp written")

        -- 播种的 idx 应与 MOD 基础模板（ranger.idx）逐字节一致
        local function readAll(p)
            local f = assert(io.open(p, "rb")); local d = f:read("*a"); f:close(); return d
        end
        TestHelper.assertEquals(readAll("mods/mingdong/data/ranger.idx"),
            readAll("mods/mingdong/save/r1.idx"),
            "seeded idx == MOD ranger.idx (not vanilla)")

        -- 修改内存中的值，再读档应恢复
        JY.PersonNum = 1
        local loaded = LoadRecord(1)
        TestHelper.assertTrue(loaded == true, "LoadRecord(1) returns true")
        TestHelper.assertEquals(basePersonNum, JY.PersonNum,
            "round-trip restores PersonNum")

        -- Big5 -> UTF-8 覆盖表：玩家改名（字符串写入）必须写入 rN.ovr，
        -- 而不是写回 ranger.grp 的 hint 占位（那会截断）
        JY.Person[0]["姓名"] = "令狐冲"
        SaveRecord(1)   -- 写入 r1.grp + r1.ovr
        TestHelper.assertTrue(FileUtil.exists("mods/mingdong/save/r1.ovr"),
            "r1.ovr written on string change")
        local ovrRaw = readAll("mods/mingdong/save/r1.ovr")
        TestHelper.assertTrue(ovrRaw:find("P0000=令狐冲", 1, true) ~= nil,
            "r1.ovr contains P0000=令狐冲 (got: " .. ovrRaw:gsub("\n", "|") .. ")")

        -- 重读：覆盖表优先于旁路表
        JY.Person[0]["姓名"] = nil
        LoadRecord(1)
        TestHelper.assertEquals("令狐冲", JY.Person[0]["姓名"],
            "override table wins over side table on reload")

        -- 未被改写的字段仍从旁路表解析（保留繁体）
        TestHelper.assertEquals("胡斐", JY.Person[1]["姓名"],
            "unmodified field still resolved from side table")
        TestHelper.assertEquals("雪山飛狐", JY.Person[1]["外号"],
            "traditional characters preserved (no t2s)")
    end)
    restoreSlots()
    TestHelper.assertTrue(ok, "save/load round-trip: " .. tostring(err))
end

-- ============================================================
-- 存档隔离：MOD 之间不共享也不读取彼此存档
-- ============================================================

function TestModBoot.testSaveIsolationAcrossMods()
    print("\n=== Test: save isolation across MODs ===")

    local ModData = require("framework.mod_data")
    local ok, err = pcall(function()
        -- mingdong 的存档目录
        ModData.SetActive("mingdong")
        TestHelper.assertEquals("mods/mingdong/save/", ModData.SaveDir(),
            "mingdong SaveDir")

        -- 另一个 MOD 的存档目录不同
        ModData.SetActive("Dragon")
        TestHelper.assertEquals("mods/Dragon/save/", ModData.SaveDir(),
            "Dragon SaveDir")
        TestHelper.assertFalse("mods/mingdong/save/" == ModData.SaveDir(),
            "different MODs have different save dirs")

        -- 切回 mingdong，确认路径仍指向自己
        ModData.SetActive("mingdong")
        TestHelper.assertEquals("mods/mingdong/save/", ModData.SaveDir(),
            "switch back to mingdong")

        -- 未激活 MOD：回到顶层 save/
        ModData.SetActive(nil)
        TestHelper.assertEquals("save/", ModData.SaveDir(),
            "vanilla SaveDir")
    end)
    TestHelper.assertTrue(ok, "save isolation: " .. tostring(err))
end

-- ============================================================
-- 战斗数据加载（REQ-MD-4，mingdong war.sta + warfld）
-- ============================================================

function TestModBoot.testWarLoadWithMingdong()
    print("\n=== Test: WarLoad with mingdong fight data ===")

    local ok, err = pcall(function()
        TestHelper.assertEquals("mods/mingdong/data/war.sta", CC.WarFile, "WarFile -> MOD")

        -- 有效 warid：加载战斗数据
        WarLoad(0)
        TestHelper.assertNotNil(WAR, "WAR table exists")
        TestHelper.assertNotNil(WAR.Data, "WAR.Data loaded")

        -- 越界 warid：不报错，但不应成功加载数据（JY_Error 仅记录日志）
        -- 注意 WarSetGlobal 会把 WAR.Data 重置为空表，故判空而非判 nil
        WAR.Data = nil
        WarLoad(999999)
        TestHelper.assertNotNil(WAR.Data, "WAR.Data reset to empty table")
        TestHelper.assertNil(WAR.Data["代号"], "out-of-range warid loads no record")
        TestHelper.assertNil(WAR.Data["名称"], "out-of-range warid loads no name")

        -- 战斗地图加载（warfld）
        WarLoadMap(0)
        TestHelper.assertNotNil(GetWarMap(0, 0, 0), "WarLoadMap + GetWarMap works")
    end)
    TestHelper.assertTrue(ok, "war load path: " .. tostring(err))
end

-- ============================================================
-- 5 个「有问题」MOD 的全启动链路验证（allmods-slice-{zheng,...}）
-- ============================================================
-- 这 5 个 MOD 曾被 games.ini 标注为异常，各自有独立 slice 修复：
--   BookCalamity  Thing 字段内 CRLF
--   zheng         save/ranger.idx 描述的不是自己的 ranger.grp
--   loving        kysmod.ini 的 BEGIN_SCENE = -1
--   awaken        Thing 字段内 CRLF（含内部）
--   pig3dos       Person @18 是 int16 stat 而非字符串
--
-- 每个 MOD 在**独立进程**中重跑真实启动链路（lib.init → init → LoadRecord(0)），
-- 断言分段记录数、主角姓名、全量字符串合法（无 U+FFFD / 控制符）。
-- 用独立进程而非同进程循环：真实启动是"一次进程一个 MOD"，同进程内反复重载
-- jymain/lib 会留下 JY 全局残留，反而不能证明真实启动路径。

local PROBLEMATIC_MODS = {
    -- slug            Person Thing Scene Wugong  主角
    { "BookCalamity",  800,   550,  139,  398,  "主角" },
    { "zheng",         320,   200,   84,   93,  "小蝦米" },
    { "loving",        320,   200,   84,   93,  "莫言" },
    { "awaken",        720,   237,  153,  163,  "北辰月" },
    { "pig3dos",       607,   242,  133,  202,  "主角" },
}

function TestModBoot.testFullBootChainForProblematicMods()
    print("\n=== Test: full boot chain for 5 problematic MODs (subprocess) ===")

    local Fs = require("framework.fs_compat")
    local luaExe = Fs.luaInterpreter() or "lua"

    for _, spec in ipairs(PROBLEMATIC_MODS) do
        local slug = spec[1]
        -- 不传中文（见 boot_one_mod.lua 的说明）：只传 slug + 4 个数字，
        -- 期望的姓名在子进程内按 slug 查表。
        local cmd = string.format(
            "%s tests/unit/boot_one_mod.lua %s %d %d %d %d",
            (Fs.isWindows and Fs.quoteWin(luaExe) or luaExe),
            slug, spec[2], spec[3], spec[4], spec[5])
        -- 跑子进程并检查输出里的 RESULT <slug>: OK（跨平台一致）。
        -- Fs.runShell 在 Windows 上会走 bash（找不到则返回 ran=false），
        -- 此时退回裸 io.popen（cmd 也能跑 `<lua> <script> args`）。
        local out, ok = "", false
        local ran, captured = Fs.runShell(cmd .. " 2>&1")
        if ran then
            out = captured
        else
            local p = io.popen(cmd .. " 2>&1")
            if p then out = p:read("*a") or ""; p:close() end
        end
        ok = out:find("RESULT " .. slug .. ": OK", 1, true) ~= nil

        TestHelper.assertTrue(ok, slug .. ": 独立进程启动链路全绿（RESULT OK）")
        if not ok then
            -- 把失败详情打印出来，便于定位
            for line in out:gmatch("[^\n]+") do
                if line:find("FAIL") then print("      " .. line) end
            end
        end
        -- 即便通过也把关键计数打印出来作为证据
        local scanned = out:match("扫描字段数 > 100（实际 (%d+)）")
        local persons = out:match("PersonNum %(期望 %d+, 实际 (%d+)%)")
        TestHelper.assertNotNil(persons, slug .. ": 输出含 PersonNum 断言")
        TestHelper.assertNotNil(scanned, slug .. ": 输出含字段扫描计数")
        if scanned then
            print(string.format("      %s: Person=%s 扫描字段=%s", slug, persons, scanned))
        end
    end
end

function TestModBoot.testLovingNegativeBeginSceneDoesNotCrash()
    print("\n=== Test: loving BEGIN_SCENE=-1 不覆盖引擎默认值 ===")

    package.loaded["framework.mod_data"] = nil
    local ModData = require("framework.mod_data")
    local ModIni = require("framework.mod_ini")

    -- 真实 loving 产物 ini
    local parsed = ModIni.Load("mods/loving/data/kysmod.ini")
    TestHelper.assertNotNil(parsed, "loving kysmod.ini 可解析")
    TestHelper.assertNil(parsed.CC.NewGameSceneID,
        "BEGIN_SCENE=-1 被忽略 -> CC.NewGameSceneID 不被覆盖")
    TestHelper.assertNil(parsed.CC.NewGameEvent,
        "BEGIN_EVENT=-1 被忽略 -> CC.NewGameEvent 不被覆盖")
    -- 正值仍生效
    TestHelper.assertEquals(2547, parsed.CC.SoftStarBeginTalk,
        "SOFTSTAR_BEGIN_TALK=2547 正常覆盖")
    TestHelper.assertEquals(3501, parsed.CC.ItemBeginPic,
        "ITEM_BEGIN_PIC=3501 正常覆盖")
end

function TestModBoot.testProductSavesNotDestroyedByTests()
    print("\n=== Test: 本测试模块未销毁任何 MOD 产物 save/ ===")
    -- 回归：save/load 测试会写 mods/<mod>/save/，必须备份+恢复。
    -- 本断言在全部测试跑完后执行（runAll 末位），确保无残留。
    local Fs = require("framework.fs_compat")
    local checked, bad = 0, 0
    for _, slug in ipairs(Fs.listDirectory("mods")) do
        if slug:sub(1, 1) ~= "_" and Fs.directoryExists("mods/" .. slug) then
            local prod = "mods/" .. slug .. "/save/r1.grp"
            local srcp = "../reference/allmods/kys-" .. slug .. "/save/r1.grp"
            local want = Fs.readFile(srcp)
            if want then
                local got = Fs.readFile(prod)
                if got then
                    checked = checked + 1
                    if got ~= want then
                        bad = bad + 1
                        print("  销毁: " .. slug .. " r1.grp (" .. #got .. " vs " .. #want .. ")")
                    end
                else
                    bad = bad + 1
                    print("  丢失: " .. slug .. " r1.grp")
                end
            end
        end
    end
    TestHelper.assertTrue(checked >= 10, "检查了 >= 10 个 MOD（" .. checked .. "）")
    TestHelper.assertEquals(0, bad, "无 MOD 产物 save/ 被销毁")
end

function TestModBoot.runAll()
    print("\n" .. string.rep("=", 60))
    print("全启动链路无头验证（mingdong）")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    TestModBoot.testFullBootChainWithMingdong()
    TestModBoot.testRuntimeTalkReadWithMingdong()
    TestModBoot.testWarLoadWithMingdong()
    TestModBoot.testSaveLoadRoundTripWithMingdong()
    TestModBoot.testSaveIsolationAcrossMods()
    TestModBoot.testLovingNegativeBeginSceneDoesNotCrash()
    TestModBoot.testFullBootChainForProblematicMods()
    TestModBoot.testProductSavesNotDestroyedByTests()

    TestHelper.printSummary()
    return TestHelper.getStats().allPassed
end

return TestModBoot
