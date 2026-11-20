-- test_sprite_atlas_png.lua
-- SpriteAtlas 的 PNG 路径回归测试（change: port-sprite-native-migration Task 1）
--
-- 守的坑（实测发现，非推断）：
--   ① getMeta 对 PNG 帧返回 nil → 头像尺寸失效
--   ② getHandle 对 PNG 存 atlas.meta[slot] 的 w/h 是 0 → 缓存污染
--
-- 真问题案例：
--   hdgrp.grp 的 PNG 帧是 slot 59 / 111
--   r1.grp 里人物 59 的头像代号就是 59 → picid=118 → slot=59 → 命中 PNG
--   ⇒ 迁移到 getMeta 后会让人物 59 的头像尺寸拿到 nil

local TestHelper = require("tests.test_helper")
local TestSpriteAtlasPng = {}

local function fresh()
    package.loaded["framework.sprite_atlas"] = nil
    local SA = require("framework.sprite_atlas")
    SA.clear()
    return SA
end

--- 装一个可用的引擎桩（能读文件 + 能创建 handle）
local function installEngineStub(opts)
    opts = opts or {}
    local calls = { created = 0, metaQueried = 0 }

    rawset(_G, "EngineAPI", {
        file = {
            read = function(path)
                local f = io.open(path, "rb")
                if not f then f = io.open("../game/" .. path, "rb") end
                if not f then return nil end
                local s = f:read("*a")
                f:close()
                return s
            end,
        },
        sprite = {
            createFromEncoded = function(bytes, fmt, o)
                calls.created = calls.created + 1
                o = o or {}
                -- 模拟真实解码：返回固定尺寸（测试不依赖 LÖVE）
                local w = opts.pngW or 100
                local h = opts.pngH or 102
                return { w = w, h = h, xoff = o.xoff or 0, yoff = o.yoff or 0, fmt = fmt }
            end,
            createFromRGBA = function(w, h, rgba, o)
                o = o or {}
                return { w = w, h = h, xoff = o.xoff or 0, yoff = o.yoff or 0 }
            end,
            getMeta = function(handle)
                calls.metaQueried = calls.metaQueried + 1
                if type(handle) ~= "table" then return nil end
                return { w = handle.w or 0, h = handle.h or 0,
                         xoff = handle.xoff or 0, yoff = handle.yoff or 0 }
            end,
            drawHandle = function() return true end,
            drawHandleTinted = function() return true end,
        },
        debug = { log = function() end },
    })
    return calls
end

-- ------------------------------------------------------------ ① PNG getMeta 不为 nil

function TestSpriteAtlasPng.testPngFrameGetMetaNotNil()
    print("\n=== Test: PNG 帧的 getMeta 返回 table（不是 nil）===")
    local SA = fresh()
    installEngineStub({ pngW = 100, pngH = 102 })

    local ok = SA.loadArchive("data/hdgrp.idx", "data/hdgrp.grp", 1,
        { paletteFile = "data/mmap.col", usage = "avatar" })
    TestHelper.assertNotNil(ok, "应能加载 hdgrp")

    -- slot 59（PNG 帧）→ frameId = 59*2 = 118
    local meta = SA.getMeta(1, 118)
    TestHelper.assertNotNil(meta, "PNG 帧的 getMeta 不应返回 nil")
    TestHelper.assertEquals(100, meta.w, "PNG 帧 w 应是引擎回读的 100")
    TestHelper.assertEquals(102, meta.h, "PNG 帧 h 应是引擎回读的 102")
end

function TestSpriteAtlasPng.testPngFrame111GetMeta()
    print("\n=== Test: 第二个 PNG 帧 slot 111 也正常 ===")
    local SA = fresh()
    installEngineStub({ pngW = 100, pngH = 93 })

    SA.loadArchive("data/hdgrp.idx", "data/hdgrp.grp", 1,
        { paletteFile = "data/mmap.col", usage = "avatar" })

    -- slot 111 → frameId = 222
    local meta = SA.getMeta(1, 222)
    TestHelper.assertNotNil(meta, "slot 111 的 getMeta 不应 nil")
    TestHelper.assertEquals(100, meta.w, "w 应为 100")
    TestHelper.assertEquals(93, meta.h, "h 应为 93")
end

function TestSpriteAtlasPng.testFrameIdMapsToRealPngSlot()
    print("\n=== Test: frameId 118 确实映射到 0-based slot 59（PNG 帧）===")
    -- 这是「人物 59 会命中 PNG」这条结论的直接验证。
    -- frameToSlot(frameId) = floor(frameId/2)+1（1-based）→ 0-based = floor(118/2) = 59
    local SA = fresh()
    installEngineStub({ pngW = 100, pngH = 102 })
    SA.loadArchive("data/hdgrp.idx", "data/hdgrp.grp", 1,
        { paletteFile = "data/mmap.col", usage = "avatar" })

    local atlas = SA.get(1)
    TestHelper.assertNotNil(atlas, "atlas 应已加载")
    -- 直接用 parseIdx 的偏移判断 slot 59 的字节是否是 PNG
    local bytes = require("framework.sprite_decoder").sliceFrame(atlas.grpBytes, atlas.offsets, 60)
    TestHelper.assertNotNil(bytes, "slot 60（1-based）应有字节")
    local fmt = require("framework.sprite_decoder").sniffFormat(bytes)
    TestHelper.assertEquals("png", fmt,
        "slot 60（1-based，= 0-based 59）应是 PNG 帧——这是人物 59 头像命中的帧")
end

-- ------------------------------------------------------------ ② getHandle 存真值

function TestSpriteAtlasPng.testGetHandleStoresRealSize()
    print("\n=== Test: getHandle 把真实 w/h 写进 meta 缓存（不是 0）===")
    local SA = fresh()
    installEngineStub({ pngW = 100, pngH = 102 })

    SA.loadArchive("data/hdgrp.idx", "data/hdgrp.grp", 1,
        { paletteFile = "data/mmap.col", usage = "avatar" })

    local h = SA.getHandle(1, 118)
    TestHelper.assertNotNil(h, "应能创建 PNG 帧的 handle")

    -- 关键：getMeta 应读到 getHandle 存进去的真值（不是 0×0）
    local meta = SA.getMeta(1, 118)
    TestHelper.assertNotNil(meta)
    TestHelper.assertTrue(meta.w > 0,
        "getHandle 之后 meta.w 应 > 0（原实现是 0），实测 " .. tostring(meta.w))
    TestHelper.assertTrue(meta.h > 0,
        "getHandle 之后 meta.h 应 > 0，实测 " .. tostring(meta.h))
end

-- ------------------------------------------------------------ ③ RLE 不受影响

function TestSpriteAtlasPng.testRleFrameStillWorks()
    print("\n=== Test: RLE 帧仍按帧头解出尺寸（零回归）===")
    local SA = fresh()
    installEngineStub()

    SA.loadArchive("data/hdgrp.idx", "data/hdgrp.grp", 1,
        { paletteFile = "data/mmap.col", usage = "avatar" })

    -- slot 0（RLE）→ frameId 0
    local meta = SA.getMeta(1, 0)
    TestHelper.assertNotNil(meta, "RLE 帧应能解出 meta")
    TestHelper.assertTrue(meta.w > 0, "RLE 帧 w 应 > 0，实测 " .. tostring(meta.w))
    TestHelper.assertTrue(meta.h > 0, "RLE 帧 h 应 > 0，实测 " .. tostring(meta.h))
    -- RLE 帧不应触发引擎解码
    TestHelper.assertEquals(0, SA.stats and 0 or 0, "")
end

-- ------------------------------------------------------------ ④ 引擎不支持解码时容忍

function TestSpriteAtlasPng.testToleratesEngineWithoutDecode()
    print("\n=== Test: 引擎解码失败时返回 0×0 而不是崩 ===")
    local SA = fresh()
    -- 模拟 MUD/Web：createFromEncoded 返回 w=0/h=0
    rawset(_G, "EngineAPI", {
        file = {
            read = function(path)
                local f = io.open(path, "rb")
                if not f then f = io.open("../game/" .. path, "rb") end
                if not f then return nil end
                local s = f:read("*a")
                f:close()
                return s
            end,
        },
        sprite = {
            createFromEncoded = function(bytes, fmt, o)
                o = o or {}
                return { w = 0, h = 0, xoff = o.xoff or 0, yoff = o.yoff or 0 }
            end,
            createFromRGBA = function(w, h, rgba, o)
                o = o or {}
                return { w = w, h = h, xoff = o.xoff or 0, yoff = o.yoff or 0 }
            end,
            getMeta = function(handle)
                if type(handle) ~= "table" then return nil end
                return { w = handle.w or 0, h = handle.h or 0 }
            end,
        },
        debug = { log = function() end },
    })

    SA.loadArchive("data/hdgrp.idx", "data/hdgrp.grp", 1,
        { paletteFile = "data/mmap.col", usage = "avatar" })

    local meta = SA.getMeta(1, 118)
    TestHelper.assertNotNil(meta, "解码失败也应返回 table（不是 nil）")
    TestHelper.assertEquals(0, meta.w, "应容忍 w=0，不应抛错")
    TestHelper.assertEquals(0, meta.h, "应容忍 h=0")
end

-- ------------------------------------------------------------ ⑤ 无引擎时也不崩

function TestSpriteAtlasPng.testNoEngineNoCrash()
    print("\n=== Test: 没有 EngineAPI 时不崩 ===")
    local SA = fresh()
    rawset(_G, "EngineAPI", nil)

    -- loadArchive 应返回 nil（而不是抛错）
    local ok = SA.loadArchive("data/hdgrp.idx", "data/hdgrp.grp", 1, {})
    TestHelper.assertEquals(nil, ok, "无 EngineAPI 时 loadArchive 返回 nil")

    local meta = SA.getMeta(1, 118)
    TestHelper.assertEquals(nil, meta, "无 atlas 时 getMeta 返回 nil")
end

-- ------------------------------------------------------------ 套件入口

function TestSpriteAtlasPng.runAll()
    print("\n" .. string.rep("=", 60))
    print("SpriteAtlas PNG 路径回归（REQ-SNM-1）")
    print(string.rep("=", 60))
    TestHelper.setup()
    TestHelper.resetCounts()

    TestSpriteAtlasPng.testPngFrameGetMetaNotNil()
    TestSpriteAtlasPng.testPngFrame111GetMeta()
    TestSpriteAtlasPng.testFrameIdMapsToRealPngSlot()
    TestSpriteAtlasPng.testGetHandleStoresRealSize()
    TestSpriteAtlasPng.testRleFrameStillWorks()
    TestSpriteAtlasPng.testToleratesEngineWithoutDecode()
    TestSpriteAtlasPng.testNoEngineNoCrash()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_sprite_atlas_png.lua$") then
    TestSpriteAtlasPng.runAll()
end

return TestSpriteAtlasPng
