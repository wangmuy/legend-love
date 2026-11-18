-- test_volume_menu_esc.lua
-- 音量菜单的右键/ESC 响应（change: 值项菜单可关闭）
--
-- 守两个用户实测过的缺陷：
--   ① adapter 的 showVolumeCoroutine 传 isEsc=0 → 右键被吞但菜单不关
--   ② 同一功能在 jymain_async 里传 isEsc=1 → 两条路径行为不一致
--
-- 本测试不依赖引擎：用源码断言 + 行为断言两层锁死。

local TestHelper = require("tests.test_helper")
local TestVolumeMenuEsc = {}

-- ------------------------------------------------------------ 源码层断言
--
-- showVolumeCoroutine 里有大量全局依赖（CC/lib/Settings/MenuAsync），
-- 在纯测试环境加载 jymain_adapter 风险高（会牵出一串全局）。
-- 所以这里直接读源码断言参数，这比"能加载就测、不能就跳过"更可靠。


-- 抽出一个顶级函数的源码文本
--
-- **不能用 `.-end` 非贪婪匹配**：它会停在第一个出现 "end" 子串的位置
-- （函数名里、注释里、字符串里都可能出现），函数体被截断，
-- 参数行根本没进来 —— 实测 showVolumeCoroutine 只抽到 485 字节。
-- 正确做法：从 `function <name>` 起，找**独占一行的 `end`**。
local function extractFunction(src, pattern)
    local startPos = src:find(pattern)
    if not startPos then return nil end
    local endPos = src:find("\nend\n", startPos, true)
    if not endPos then return nil end
    return src:sub(startPos, endPos)
end

local function readSource(rel)
    local candidates = {
        rel,
        "game/" .. rel,
    }
    for _, p in ipairs(candidates) do
        local f = io.open(p, "rb")
        if f then
            local content = f:read("*a")
            f:close()
            return content
        end
    end
    return nil
end

function TestVolumeMenuEsc.testShowVolumePassesIsEscOne()
    print("\n=== Test: showVolumeCoroutine 必须传 isEsc=1 ===")
    local src = readSource("framework/jymain_adapter.lua")
    TestHelper.assertNotNil(src, "应能读到 jymain_adapter.lua")

    -- 找到 showVolumeCoroutine 的 ShowMenuCoroutine 调用参数行
    local body = extractFunction(src, "function JYMainAdapter.showVolumeCoroutine")
    TestHelper.assertNotNil(body, "应能找到 showVolumeCoroutine 函数体")

    -- 参数序: items, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, ...
    -- 断言 x2=0, y2=0, isBox=1, isEsc=1
    local found = body:match("0,%s*0,%s*1,%s*1")
    TestHelper.assertNotNil(found,
        "showVolumeCoroutine 必须传 isBox=1, isEsc=1（否则右键关不掉菜单）")
end

function TestVolumeMenuEsc.testNoZeroZeroZeroZero()
    print("\n=== Test: 不得残留 isBox=0 isEsc=0 ===")
    local src = readSource("framework/jymain_adapter.lua")
    TestHelper.assertNotNil(src, "应能读到 jymain_adapter.lua")

    local body = extractFunction(src, "function JYMainAdapter.showVolumeCoroutine")
    TestHelper.assertNotNil(body, "应能找到 showVolumeCoroutine 函数体")

    -- 负向：不能出现 0,0,0,0（x2,y2,isBox,isEsc 全零 = 右键失效）
    local bad = body:match("0,%s*0,%s*0,%s*0")
    TestHelper.assertEquals(nil, bad,
        "不得传 isBox=0, isEsc=0（右键会被吞但菜单不关）")
end

function TestVolumeMenuEsc.testBothPathsAgree()
    print("\n=== Test: adapter 与 jymain_async 两条路径参数一致 ===")
    local srcA = readSource("framework/jymain_adapter.lua")
    local srcB = readSource("framework/jymain_async.lua")
    TestHelper.assertNotNil(srcA, "应能读到 jymain_adapter.lua")
    TestHelper.assertNotNil(srcB, "应能读到 jymain_async.lua")

    -- jymain_async 的 Menu_AudioVolume 传 1,1（正确基准）
    local bodyB = extractFunction(srcB, "function JyMainAsync.Menu_AudioVolume")
    TestHelper.assertNotNil(bodyB, "应能找到 Menu_AudioVolume 函数体")
    TestHelper.assertNotNil(bodyB:match("0,%s*0,%s*1,%s*1"),
        "基准：jymain_async 传 isBox=1, isEsc=1")

    -- adapter 必须与基准一致
    local bodyA = extractFunction(srcA, "function JYMainAdapter.showVolumeCoroutine")
    TestHelper.assertNotNil(bodyA:match("0,%s*0,%s*1,%s*1"),
        "adapter 必须与 jymain_async 一致（isBox=1, isEsc=1）")
end

-- ------------------------------------------------------------ 行为层断言
--
-- 直接建菜单，验证 isEsc=1 时右键确实能关、isEsc=0 时确实关不掉。
-- 这两条一起跑，才能证明"参数确实是因"。

local function withStubs(fn)
    local saved = {
        Cls = rawget(_G, "Cls"),
        DrawString = rawget(_G, "DrawString"),
        lib = rawget(_G, "lib"),
        PlayMIDI = rawget(_G, "PlayMIDI"),
        CC = rawget(_G, "CC"),
    }
    rawset(_G, "Cls", function() end)
    rawset(_G, "DrawString", function() end)
    rawset(_G, "PlayMIDI", function() end)
    rawset(_G, "lib", { Debug = function() end, GetKey = function() return -1 end })

    local cc = rawget(_G, "CC") or {}
    cc.ScreenW = cc.ScreenW or 1024
    cc.ScreenH = cc.ScreenH or 768
    cc.MenuBorderPixel = cc.MenuBorderPixel or 5
    cc.RowPixel = cc.RowPixel or 4
    cc.DefaultFont = cc.DefaultFont or 24
    rawset(_G, "CC", cc)

    local ok, err = pcall(fn)

    rawset(_G, "Cls", saved.Cls)
    rawset(_G, "DrawString", saved.DrawString)
    rawset(_G, "lib", saved.lib)
    rawset(_G, "PlayMIDI", saved.PlayMIDI)
    rawset(_G, "CC", saved.CC)
    if not ok then error(err) end
end

function TestVolumeMenuEsc.testRightClickClosesWhenIsEscOne()
    print("\n=== Test: isEsc=1 时右键关闭音量菜单 ===")
    withStubs(function()
        local Settings = require("framework.settings")
        Settings.reset()
        local AudioSettings = require("framework.audio_settings")
        AudioSettings.resetInit()
        AudioSettings.define()
        local AudioMenu = require("framework.audio_menu")
        local MSM = require("framework.menu_state_machine")
        local MM = require("framework.mouse_menu")
        MM.define()
        Settings.set("input.mouse", true)

        local msm = MSM.getInstance()
        msm:clear()

        local items = AudioMenu.buildValueMenu("audio.music", "音乐音量")
        local menu = msm:createMenu(items, 1, 0, 400, 100, 0, 0,
                                   1, 1, 24, 0, 0)
        msm:openMenu(menu, function() end)

        local InputManager = require("framework.input_manager")
        InputManager.getInstance():init()
        InputManager.enqueueMouseEvent({ type = "pressed", x = 420, y = 120, button = 2 })

        local JYMainAdapter = require("framework.jymain_adapter")
        JYMainAdapter.pollMouse()

        TestHelper.assertEquals(nil, msm.activeMenu,
            "isEsc=1 时右键必须关闭菜单（用户实测缺陷的反向断言）")
        msm:clear()
    end)
end

function TestVolumeMenuEsc.testRightClickIgnoredWhenIsEscZero()
    print("\n=== Test: isEsc=0 时右键关不掉（证明参数是因）===")
    withStubs(function()
        local Settings = require("framework.settings")
        Settings.reset()
        local AudioSettings = require("framework.audio_settings")
        AudioSettings.resetInit()
        AudioSettings.define()
        local AudioMenu = require("framework.audio_menu")
        local MSM = require("framework.menu_state_machine")
        local MM = require("framework.mouse_menu")
        MM.define()
        Settings.set("input.mouse", true)

        local msm = MSM.getInstance()
        msm:clear()

        local items = AudioMenu.buildValueMenu("audio.music", "音乐音量")
        local menu = msm:createMenu(items, 1, 0, 400, 100, 0, 0,
                                   0, 0, 24, 0, 0)   -- isBox=0, isEsc=0
        msm:openMenu(menu, function() end)

        local InputManager = require("framework.input_manager")
        InputManager.getInstance():init()
        InputManager.enqueueMouseEvent({ type = "pressed", x = 420, y = 120, button = 2 })

        local JYMainAdapter = require("framework.jymain_adapter")
        JYMainAdapter.pollMouse()

        TestHelper.assertNotNil(msm.activeMenu,
            "isEsc=0 时右键关不掉（这正是修复前的现象）")
        msm:clear()
    end)
end

function TestVolumeMenuEsc.runAll()
    print("\n" .. string.rep("=", 60))
    print("音量菜单右键/ESC 响应测试")
    print(string.rep("=", 60))
    TestHelper.setup()
    TestHelper.resetCounts()

    TestVolumeMenuEsc.testShowVolumePassesIsEscOne()
    TestVolumeMenuEsc.testNoZeroZeroZeroZero()
    TestVolumeMenuEsc.testBothPathsAgree()
    TestVolumeMenuEsc.testRightClickClosesWhenIsEscOne()
    TestVolumeMenuEsc.testRightClickIgnoredWhenIsEscZero()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_volume_menu_esc.lua$") then
    TestVolumeMenuEsc.runAll()
end

return TestVolumeMenuEsc
