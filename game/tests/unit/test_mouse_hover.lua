-- test_mouse_hover.lua
-- 坐标反解 + 悬停高亮 + 红闪的测试（REQ-MS3-1 / REQ-MS3-2）
--
-- 反解精度是本文件的核心：ADR-MS3-001 记录了 floor 会错 75.6% 的实测，
-- 这里用 289 格中心 + 菱形内部采样锁死 round 版本的正确性。

local TestHelper = require("tests.test_helper")
local TestMouseHover = {}

local function installGlobals()
    local saved = {
        CONFIG = rawget(_G, "CONFIG"),
        JY = rawget(_G, "JY"),
        GAME_MMAP = rawget(_G, "GAME_MMAP"),
        GAME_SMAP = rawget(_G, "GAME_SMAP"),
        EngineAPI = rawget(_G, "EngineAPI"),
    }
    rawset(_G, "CONFIG", { XScale = 18, YScale = 9, Width = 1024, Height = 768 })
    rawset(_G, "GAME_MMAP", 2)
    rawset(_G, "GAME_SMAP", 4)
    rawset(_G, "JY", { Status = 2 })
    return saved
end

local function restoreGlobals(saved)
    for k, v in pairs(saved) do rawset(_G, k, v) end
end

local function freshHover()
    package.loaded["framework.mouse_hover"] = nil
    package.loaded["framework.settings"] = nil
    package.loaded["framework.menu_async"] = nil
    package.loaded["framework.input_manager"] = nil
    return require("framework.mouse_hover")
end

-- ============================================================
-- REQ-MS3-2 坐标反解
-- ============================================================

function TestMouseHover.testCenterRoundTrip289()
    print("\n=== Test: 289 格中心往返（100% 精确）===")
    local saved = installGlobals()
    local H = freshHover()

    local bad = 0
    for gx = -8, 8 do
        for gy = -8, 8 do
            local sx, sy = H.tileToScreen(gx, gy)
            local rx, ry = H.screenToTile(sx, sy)
            if rx ~= gx or ry ~= gy then bad = bad + 1 end
        end
    end
    TestHelper.assertEquals(0, bad, "289 格全部精确往返")
    restoreGlobals(saved)
end

function TestMouseHover.testDiamondInteriorSample()
    print("\n=== Test: 菱形内部采样（0 偏离）===")
    local saved = installGlobals()
    local H = freshHover()

    local bad, total = 0, 0
    for gx = -6, 6 do
        for gy = -6, 6 do
            local cx, cy = H.tileToScreen(gx, gy)
            for ox = -17, 17, 2 do
                for oy = -8, 8, 2 do
                    -- 菱形内部：|ox|/XS + |oy|/YS <= 1
                    if math.abs(ox) / 18.0 + math.abs(oy) / 9.0 <= 0.98 then
                        total = total + 1
                        local rx, ry = H.screenToTile(cx + ox, cy + oy)
                        if rx ~= gx or ry ~= gy then bad = bad + 1 end
                    end
                end
            end
        end
    end
    TestHelper.assertTrue(total > 1000, "采样点足够多（" .. total .. "）")
    TestHelper.assertEquals(0, bad, "菱形内部 " .. total .. " 个采样点全部命中正确格")
    restoreGlobals(saved)
end

function TestMouseHover.testFloorVersionWouldFail()
    print("\n=== Test: 负向对照 —— floor 版本会错 ===")
    -- ADR-MS3-001：朴素 floor 有半格错位，实测 75.6% 偏离
    local function floorVersion(sx, sy)
        local u = (sx - 512) / 18
        local v = (sy - 384) / 9
        return math.floor((u + v) / 2), math.floor((v - u) / 2)
    end

    local bad = 0
    for gx = -6, 6 do
        for gy = -6, 6 do
            local cx = 18 * (gx - gy) + 512
            local cy = 9 * (gx + gy) + 384
            for ox = -8, 8, 4 do
                local rx, ry = floorVersion(cx + ox, cy)
                if rx ~= gx or ry ~= gy then bad = bad + 1 end
            end
        end
    end
    TestHelper.assertTrue(bad > 0,
        "floor 版本确实命中错格（" .. bad .. " 次）—— 证明 +0.5 是必需的")
end

function TestMouseHover.testNegativeCoordinates()
    print("\n=== Test: 负坐标反解 ===")
    local saved = installGlobals()
    local H = freshHover()

    for _, g in ipairs({ {-1, 0}, {0, -1}, {-1, -1}, {-5, -3}, {-10, 10} }) do
        local sx, sy = H.tileToScreen(g[1], g[2])
        local rx, ry = H.screenToTile(sx, sy)
        TestHelper.assertEquals(g[1], rx, "负坐标 x 往返: " .. g[1])
        TestHelper.assertEquals(g[2], ry, "负坐标 y 往返: " .. g[2])
    end
    restoreGlobals(saved)
end

-- ============================================================
-- REQ-MS3-1 绘制条件（5 条）
-- ============================================================

local function setupForShouldDraw(opts)
    local saved = installGlobals()

    -- Settings：鼠标开关
    local Settings = require("framework.settings")
    Settings.reset()
    Settings.define("input.mouse", { default = true, type = "bool" })
    Settings.set("input.mouse", opts.mouseEnabled ~= false)

    -- MenuAsync：是否有活动菜单
    package.loaded["framework.menu_async"] = nil
    local MenuAsync = require("framework.menu_async")
    MenuAsync.hasActiveMenu = function() return opts.menuActive == true end

    -- InputManager：是否阻塞
    local InputManager = require("framework.input_manager")
    InputManager.disableInput = opts.inputBlocked == true

    -- 鼠标位置
    rawset(_G, "EngineAPI", {
        time = { getTime = function() return os.clock() * 1000 end },
        input = {
            mousePosition = function()
                return opts.mx or 512, opts.my or 384
            end,
        },
        sprite = { drawTinted = function() end },
    })

    rawset(_G, "JY", { Status = opts.status or 2 })   -- 2 = GAME_MMAP

    package.loaded["framework.mouse_hover"] = nil
    return require("framework.mouse_hover"), saved
end

function TestMouseHover.testShouldDrawAllConditionsMet()
    print("\n=== Test: 5 个条件都满足时绘制 ===")
    local H, saved = setupForShouldDraw({})
    TestHelper.assertTrue(H.shouldDraw(), "全部满足 → 应绘制")
    restoreGlobals(saved)
end

function TestMouseHover.testShouldDrawBlockedByEachCondition()
    print("\n=== Test: 任一条件不满足则不绘制 ===")

    local cases = {
        { name = "鼠标开关关闭",    opts = { mouseEnabled = false } },
        { name = "有活动菜单",      opts = { menuActive = true } },
        { name = "阻塞输入",        opts = { inputBlocked = true } },
        { name = "战斗中(状态错)",  opts = { status = 3 } },
        { name = "鼠标出屏",        opts = { mx = -1, my = -1 } },
    }
    for _, c in ipairs(cases) do
        local H, saved = setupForShouldDraw(c.opts)
        TestHelper.assertFalse(H.shouldDraw(), c.name .. " → 不绘制")
        restoreGlobals(saved)
    end
end

-- ============================================================
-- REQ-MS3-3 红闪节流
-- ============================================================

function TestMouseHover.testFlashThrottle()
    print("\n=== Test: 红闪 200ms 节流 ===")
    local saved = installGlobals()
    local H = freshHover()

    TestHelper.assertTrue(H.flashDenied(10, 10), "第一次触发成功")
    TestHelper.assertFalse(H.flashDenied(10, 10),
        "200ms 内再次触发被节流")
    TestHelper.assertFalse(H.flashDenied(11, 11),
        "节流与坐标无关")

    restoreGlobals(saved)
end

function TestMouseHover.testFlashState()
    print("\n=== Test: 红闪状态 ===")
    local saved = installGlobals()
    local H = freshHover()

    TestHelper.assertFalse(H.isFlashing(), "初始不在闪")
    H.flashDenied(5, 5)
    TestHelper.assertTrue(H.isFlashing(), "触发后在闪")
    H.clearFlash()
    TestHelper.assertFalse(H.isFlashing(), "clearFlash 后不在闪")

    restoreGlobals(saved)
end

function TestMouseHover.testDrawUsesDrawTinted()
    print("\n=== Test: 绘制调用 drawTinted ===")
    local saved = installGlobals()
    local H = freshHover()

    -- **接线已改**：mouse_hover 不再直接调 EngineAPI.sprite.drawTinted，
    -- 而是走 framework/sprite_atlas.lua → EngineAPI.sprite.drawHandleTinted
    -- （ADR-PORT-013 的接线层：容器解析归 framework，引擎只认 handle）
    local recorded = nil
    rawset(_G, "EngineAPI", {
        time = { getTime = function() return os.clock() * 1000 end },
        input = { mousePosition = function() return 512, 384 end },
        file = {
            read = function(p)
                local f = io.open(p, "rb")
                if not f then return nil end
                local d = f:read("*a"); f:close(); return d
            end,
        },
        sprite = {
            createFromRGBA = function(w, h, rgba, o)
                o = o or {}
                return { w = w, h = h, xoff = o.xoff or 0, yoff = o.yoff or 0 }
            end,
            createFromEncoded = function(b, fmt, o)
                o = o or {}
                return { w = 0, h = 0, xoff = o.xoff or 0, yoff = o.yoff or 0 }
            end,
            drawHandleTinted = function(handle, x, y, color, alpha)
                recorded = { handle = handle, x = x, y = y, color = color, alpha = alpha }
            end,
        },
    })
    local Settings = require("framework.settings")
    Settings.reset()
    Settings.define("input.mouse", { default = true, type = "bool" })

    -- 需要真实的 smap 档案已加载（菱形 spriteId=0 来自 atlas 0）
    local SpriteAtlas = require("framework.sprite_atlas")
    SpriteAtlas.clear()
    SpriteAtlas.loadArchive("data/smap.idx", "data/smap.grp", 0,
        { paletteFile = "data/mmap.col" })

    H.draw()
    TestHelper.assertNotNil(recorded, "drawHandleTinted 被调用")
    TestHelper.assertNotNil(recorded.color, "传了颜色表")

    SpriteAtlas.clear()
    restoreGlobals(saved)
end

-- ============================================================
-- 相机偏移（本次修复的核心 bug）
--
-- 用户实测：新游戏对话结束后点近处不动，点别处跑很远甚至走出大地图。
-- 根因：screenToTile 缺少相机偏移 —— 屏幕格点 i1 ≠ 世界格坐标。
-- ============================================================

function TestMouseHover.testCameraMMAP()
    print("\n=== Test: MMAP 相机 = 主角坐标 ===")
    local saved = installGlobals()
    rawset(_G, "JY", { Status = 2, Base = { ["人X"] = 37, ["人Y"] = 42 } })
    local H = freshHover()

    local cx, cy = H.camera("MMAP")
    TestHelper.assertEquals(37, cx, "MMAP 相机 x = 人X")
    TestHelper.assertEquals(42, cy, "MMAP 相机 y = 人Y")
    restoreGlobals(saved)
end

function TestMouseHover.testCameraSMAPClamped()
    print("\n=== Test: SMAP 相机 = clamp(人X1-1, SceneMin, SceneMax) ===")
    local saved = installGlobals()
    rawset(_G, "CC", { XScale = 18, YScale = 9, Width = 1024, Height = 768,
                       SceneXMin = 12, SceneYMin = 12,
                       SceneXMax = 45, SceneYMax = 45 })
    rawset(_G, "JY", { Status = 4, SubSceneX = 0, SubSceneY = 0,
                       Base = { ["人X1"] = 19, ["人Y1"] = 20 } })
    local H = freshHover()

    local cx, cy = H.camera("SMAP")
    TestHelper.assertEquals(18, cx, "19-1=18，在 [12,45] 内")
    TestHelper.assertEquals(19, cy, "20-1=19，在 [12,45] 内")
    restoreGlobals(saved)
end

function TestMouseHover.testCameraSMAPClampedLow()
    print("\n=== Test: SMAP 相机下边界 clamp ===")
    local saved = installGlobals()
    rawset(_G, "CC", { XScale = 18, YScale = 9, Width = 1024, Height = 768,
                       SceneXMin = 12, SceneYMin = 12,
                       SceneXMax = 45, SceneYMax = 45 })
    rawset(_G, "JY", { Status = 4, SubSceneX = 0, SubSceneY = 0,
                       Base = { ["人X1"] = 3, ["人Y1"] = 4 } })
    local H = freshHover()

    local cx, cy = H.camera("SMAP")
    TestHelper.assertEquals(12, cx, "3-1=2 < 12 → clamp 到 12")
    TestHelper.assertEquals(12, cy, "4-1=3 < 12 → clamp 到 12")
    restoreGlobals(saved)
end

function TestMouseHover.testClickOwnTileWithCamera()
    print("\n=== Test: 相机修正后点击自己脚下 → 命中自己 ===")
    local saved = installGlobals()
    rawset(_G, "CC", { XScale = 18, YScale = 9, Width = 1024, Height = 768,
                       SceneXMin = 12, SceneYMin = 12,
                       SceneXMax = 45, SceneYMax = 45 })
    rawset(_G, "JY", { Status = 4, SubSceneX = 0, SubSceneY = 0,
                       Base = { ["人X1"] = 19, ["人Y1"] = 20 } })
    local H = freshHover()

    local camX, camY = H.camera("SMAP")
    -- 主角画在屏幕上的位置
    local sx, sy = H.tileToScreen(19, 20, camX, camY)
    local gx, gy = H.screenToTile(sx, sy, camX, camY)

    TestHelper.assertEquals(19, gx, "反解回自己 x")
    TestHelper.assertEquals(20, gy, "反解回自己 y")
    restoreGlobals(saved)
end

function TestMouseHover.testNoCameraWouldBeOff()
    print("\n=== Test: 负向对照 —— 不带相机时会偏 18,19 格 ===")
    local saved = installGlobals()
    rawset(_G, "CC", { XScale = 18, YScale = 9, Width = 1024, Height = 768,
                       SceneXMin = 12, SceneYMin = 12,
                       SceneXMax = 45, SceneYMax = 45 })
    rawset(_G, "JY", { Status = 4, SubSceneX = 0, SubSceneY = 0,
                       Base = { ["人X1"] = 19, ["人Y1"] = 20 } })
    local H = freshHover()

    local camX, camY = H.camera("SMAP")
    local sx, sy = H.tileToScreen(19, 20, camX, camY)
    -- 故意不传相机（模拟修复前的实现）
    local gx, gy = H.screenToTile(sx, sy)

    TestHelper.assertEquals(1, gx, "不带相机 → x 解成 1（不是 19）")
    TestHelper.assertEquals(1, gy, "不带相机 → y 解成 1（不是 20）")
    TestHelper.assertTrue(gx ~= 19 or gy ~= 20,
        "确认偏差存在 —— 证明相机参数是必需的")
    restoreGlobals(saved)
end

function TestMouseHover.testRoundTripWithCameraAnywhere()
    print("\n=== Test: 任意相机位置下 289 格往返 ===")
    local saved = installGlobals()
    rawset(_G, "JY", { Status = 2, Base = { ["人X"] = 100, ["人Y"] = 100 } })
    local H = freshHover()

    local camX, camY = 100, 100
    local bad = 0
    for gx = 90, 110 do
        for gy = 90, 110 do
            local sx, sy = H.tileToScreen(gx, gy, camX, camY)
            local rx, ry = H.screenToTile(sx, sy, camX, camY)
            if rx ~= gx or ry ~= gy then bad = bad + 1 end
        end
    end
    TestHelper.assertEquals(0, bad, "441 格在相机 (100,100) 下全部精确往返")
    restoreGlobals(saved)
end

-- ============================================================
-- REQ-MS3-6 可交互目标的悬停提示
-- ============================================================

function TestMouseHover.testHoverKindNilForPlainTile()
    print("\n=== Test: 普通格没有交互提示 ===")
    local saved = installGlobals()
    rawset(_G, "JY", { Status = 2, Base = { ["人X"] = 10, ["人Y"] = 10 } })
    rawset(_G, "CanEnterScene", function() return -1 end)
    rawset(_G, "EngineAPI", {
        time = { getTime = function() return os.clock() * 1000 end },
        input = { mousePosition = function() return 512, 384 end },
        sprite = { drawTinted = function() end },
    })
    local H = freshHover()

    TestHelper.assertEquals(nil, H.hoverKind(), "普通格 → nil")
    restoreGlobals(saved)
end

function TestMouseHover.testHoverKindScene()
    print("\n=== Test: 识别悬停到门口 ===")
    local saved = installGlobals()
    rawset(_G, "JY", { Status = 2, Base = { ["人X"] = 10, ["人Y"] = 10 } })
    rawset(_G, "CanEnterScene", function() return 5 end)
    rawset(_G, "EngineAPI", {
        time = { getTime = function() return os.clock() * 1000 end },
        input = { mousePosition = function() return 512, 384 end },
        sprite = { drawTinted = function() end },
    })
    local H = freshHover()

    TestHelper.assertEquals("scene", H.hoverKind(),
        "悬停到可进入的场景 → 返回 scene（青色提示）")
    restoreGlobals(saved)
end

function TestMouseHover.testInteractColorDiffers()
    print("\n=== Test: 交互提示与普通提示颜色不同 ===")
    local saved = installGlobals()
    local H = freshHover()

    TestHelper.assertNotNil(H.INTERACT_COLOR, "有交互提示色")
    TestHelper.assertTrue(
        H.INTERACT_COLOR.r ~= H.HOVER_COLOR.r
        or H.INTERACT_COLOR.g ~= H.HOVER_COLOR.g
        or H.INTERACT_COLOR.b ~= H.HOVER_COLOR.b,
        "交互提示色必须与普通悬停色不同（否则玩家看不出区别）")
    restoreGlobals(saved)
end

function TestMouseHover.runAll()
    print("\n" .. string.rep("=", 60))
    print("鼠标悬停 / 坐标反解 / 红闪测试")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    TestMouseHover.testCenterRoundTrip289()
    TestMouseHover.testDiamondInteriorSample()
    TestMouseHover.testFloorVersionWouldFail()
    TestMouseHover.testNegativeCoordinates()

    TestMouseHover.testCameraMMAP()
    TestMouseHover.testCameraSMAPClamped()
    TestMouseHover.testCameraSMAPClampedLow()
    TestMouseHover.testClickOwnTileWithCamera()
    TestMouseHover.testNoCameraWouldBeOff()
    TestMouseHover.testRoundTripWithCameraAnywhere()

    TestMouseHover.testShouldDrawAllConditionsMet()
    TestMouseHover.testShouldDrawBlockedByEachCondition()

    TestMouseHover.testFlashThrottle()
    TestMouseHover.testFlashState()
    TestMouseHover.testDrawUsesDrawTinted()

    TestMouseHover.testHoverKindNilForPlainTile()
    TestMouseHover.testHoverKindScene()
    TestMouseHover.testInteractColorDiffers()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_mouse_hover.lua$") then
    TestMouseHover.runAll()
end

return TestMouseHover
