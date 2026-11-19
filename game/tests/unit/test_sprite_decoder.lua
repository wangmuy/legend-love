-- test_sprite_decoder.lua
-- 精灵解码层测试（change: port-contract-completeness Task 4b）
--
-- 守的坑（全部有实测依据，见 design.md ADR-PORT-013 / ADR-PORT-014）：
--   ① 解码层必须零引擎依赖（不能又绑死 LÖVE）
--   ② RLE 解码结果长度必须精确 = w*h*4，alpha 只能是 0 或 255
--   ③ 格式嗅探按**字节签名**，不看扩展名
--   ④ 头像 PNG 用中心锚点（w/2, h/2），地图精灵用脚底锚点（w/2, h）
--   ⑤ RLE 锚点必须来自帧头，不得被覆盖

local TestHelper = require("tests.test_helper")
local TestSpriteDecoder = {}

local function readAsset(rel)
    for _, p in ipairs({ rel, "game/" .. rel }) do
        local f = io.open(p, "rb")
        if f then local c = f:read("*a"); f:close(); return c end
    end
    return nil
end

local SD = nil
local function fresh()
    package.loaded["framework.sprite_decoder"] = nil
    SD = require("framework.sprite_decoder")
    return SD
end

-- ------------------------------------------------------------ 零引擎依赖

function TestSpriteDecoder.testNoEngineDependency()
    print("\n=== Test: 解码层零引擎依赖 ===")
    local src = readAsset("framework/sprite_decoder.lua")
    TestHelper.assertNotNil(src, "应能读到 sprite_decoder.lua")

    -- 只统计实际代码行，排除注释
    local bad = 0
    for line in src:gmatch("[^\r\n]+") do
        local code = line:gsub("^%s*%-%-.*$", "")
        if code:match("love%.") and not code:match("%-%-") then bad = bad + 1 end
    end
    TestHelper.assertEquals(0, bad,
        "sprite_decoder.lua 的代码行不得调 love.*（实测 " .. bad .. " 处）")

    TestHelper.assertEquals(nil, src:match('require%("engine'),
        "不得 require engine-*（否则又绑死具体引擎）")
end

-- ------------------------------------------------------------ idx 解析

function TestSpriteDecoder.testParseIdxBasic()
    print("\n=== Test: parseIdx 解析偏移表 ===")
    fresh()
    -- 构造：3 条目 → 4 个偏移（首项 0）
    local idx = string.char(10, 0, 0, 0) .. string.char(20, 0, 0, 0) .. string.char(30, 0, 0, 0)
    local offs = SD.parseIdx(idx, 100)
    TestHelper.assertEquals(4, #offs, "偏移数组长度 = 条目数 + 1")
    TestHelper.assertEquals(0, offs[1], "首项固定为 0")
    TestHelper.assertEquals(10, offs[2], "第 1 条目 = 10")
    TestHelper.assertEquals(20, offs[3], "第 2 条目 = 20")
    TestHelper.assertEquals(30, offs[4], "第 3 条目 = 30")
end

function TestSpriteDecoder.testParseIdxClampsOvershoot()
    print("\n=== Test: parseIdx 钳制越界偏移 ===")
    fresh()
    -- 偏移 999 超过 grpLen 100 → 应钳到 100
    -- 注意：999 超过 string.char 的 0..255 范围，必须拆成 4 字节拼
    local idx = string.char(999 % 256, 0, 0, 0)
    local offs = SD.parseIdx(idx, 100)
    TestHelper.assertEquals(100, offs[2], "超过 grpLen 的偏移必须钳到 grpLen")
end

function TestSpriteDecoder.testParseIdxEmpty()
    print("\n=== Test: parseIdx 空输入 ===")
    fresh()
    TestHelper.assertEquals(1, #SD.parseIdx("", 100), "空 idx 只返回首项 0")
    TestHelper.assertEquals(1, #SD.parseIdx(nil, 100), "nil 输入也不崩")
end

-- ------------------------------------------------------------ 字节段

function TestSpriteDecoder.testSliceFrame()
    print("\n=== Test: sliceFrame 取字节段 ===")
    fresh()
    local grp = "ABCDEFGHIJ" .. "KLMNOPQRST"   -- 20 字节
    local offs = { 0, 10, 20 }
    TestHelper.assertEquals("ABCDEFGHIJ", SD.sliceFrame(grp, offs, 1), "slot1 = [0,10)")
    TestHelper.assertEquals("KLMNOPQRST", SD.sliceFrame(grp, offs, 2), "slot2 = [10,20)")
    TestHelper.assertEquals(nil, SD.sliceFrame(grp, offs, 3), "slot3 无数据应返回 nil")
end

function TestSpriteDecoder.testSliceFrameOutOfRange()
    print("\n=== Test: sliceFrame 越界 ===")
    fresh()
    TestHelper.assertEquals(nil, SD.sliceFrame("abc", { 0, 1 }, 0), "slot 0 非法")
    TestHelper.assertEquals(nil, SD.sliceFrame(nil, { 0, 1 }, 1), "grp nil 不崩")
end

-- ------------------------------------------------------------ 格式嗅探

function TestSpriteDecoder.testSniffPng()
    print("\n=== Test: 嗅探 PNG ===")
    fresh()
    -- 完整 PNG 签名 89 50 4E 47 0D 0A 1A 0A
    local png = string.char(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A) .. "rest"
    TestHelper.assertEquals("png", SD.sniffFormat(png), "完整 PNG 签名应识别为 png")
end

function TestSpriteDecoder.testSniffPartialPngIsRle()
    print("\n=== Test: 部分 PNG 签名不算 PNG ===")
    fresh()
    -- 只匹配前 4 字节（缺 0D 0A 1A 0A）→ 不算 PNG
    local almost = string.char(0x89, 0x50, 0x4E, 0x47, 0x00, 0x00, 0x00, 0x00) .. "rest"
    TestHelper.assertEquals("rle", SD.sniffFormat(almost),
        "缺 0D 0A 1A 0A 的必须判为 rle（数据段恰好含 PNG 前 4 字节也不能误判）")
end

function TestSpriteDecoder.testSniffRle()
    print("\n=== Test: 嗅探 RLE ===")
    fresh()
    local rle = string.char(0x24, 0x00, 0x12, 0x00, 0x12, 0x00, 0x11, 0x00) .. "rest"
    TestHelper.assertEquals("rle", SD.sniffFormat(rle), "非 PNG 签名判为 rle")
end

-- ------------------------------------------------------------ 真实资产

function TestSpriteDecoder.testRealAssetDecode()
    print("\n=== Test: 真实资产解码（smap.grp slot 1）===")
    fresh()
    local grp = readAsset("data/smap.grp")
    local idx = readAsset("data/smap.idx")
    local col = readAsset("data/mmap.col")
    TestHelper.assertNotNil(grp, "应能读到 smap.grp")
    TestHelper.assertNotNil(idx, "应能读到 smap.idx")
    TestHelper.assertNotNil(col, "应能读到 mmap.col")

    local offs = SD.parseIdx(idx, #grp)
    local frame = SD.sliceFrame(grp, offs, 1)
    local pal = SD.loadPalette(col)
    local d = SD.decodeRLE(frame, pal)

    TestHelper.assertNotNil(d, "slot 1 应可解码")
    -- 实测：slot1 是 36x18 的菱形遮罩，xoff=18 yoff=17
    TestHelper.assertEquals(36, d.w, "slot1 宽 36（实测）")
    TestHelper.assertEquals(18, d.h, "slot1 高 18（实测）")
    TestHelper.assertEquals(18, d.xoff, "slot1 xoff=18（实测）")
    TestHelper.assertEquals(17, d.yoff, "slot1 yoff=17（实测）")
    TestHelper.assertEquals(d.w * d.h * 4, #d.rgba, "RGBA 长度必须精确 = w*h*4")
end

function TestSpriteDecoder.testAlphaOnlyZeroOr255()
    print("\n=== Test: alpha 只能是 0 或 255 ===")
    fresh()
    local grp = readAsset("data/smap.grp")
    local idx = readAsset("data/smap.idx")
    local col = readAsset("data/mmap.col")
    local offs = SD.parseIdx(idx, #grp)
    local pal = SD.loadPalette(col)

    local checked, bad = 0, 0
    for slot = 1, 60 do
        local f = SD.sliceFrame(grp, offs, slot)
        if f then
            local d = SD.decodeRLE(f, pal)
            if d then
                checked = checked + 1
                for i = 4, #d.rgba, 4 do
                    local a = d.rgba:byte(i)
                    if a ~= 0 and a ~= 255 then bad = bad + 1 end
                end
            end
        end
    end
    TestHelper.assertTrue(checked >= 50, "至少检查 50 帧（实测 " .. checked .. "）")
    TestHelper.assertEquals(0, bad, "RLE 解码的 alpha 只能是 0 或 255（实测异常 " .. bad .. "）")
end

function TestSpriteDecoder.testDecodedLengthAlwaysExact()
    print("\n=== Test: 所有帧的解码长度都精确 ===")
    fresh()
    local grp = readAsset("data/smap.grp")
    local idx = readAsset("data/smap.idx")
    local col = readAsset("data/mmap.col")
    local offs = SD.parseIdx(idx, #grp)
    local pal = SD.loadPalette(col)

    local checked, bad = 0, 0
    for slot = 1, 200 do
        local f = SD.sliceFrame(grp, offs, slot)
        if f then
            local d = SD.decodeRLE(f, pal)
            if d then
                checked = checked + 1
                if #d.rgba ~= d.w * d.h * 4 then bad = bad + 1 end
            end
        end
    end
    TestHelper.assertTrue(checked >= 150, "至少检查 150 帧（实测 " .. checked .. "）")
    TestHelper.assertEquals(0, bad, "长度不匹配的帧数必须为 0（实测 " .. bad .. "）")
end

-- ------------------------------------------------------------ PNG 帧

function TestSpriteDecoder.testHdgrpPngFramesDetected()
    print("\n=== Test: hdgrp 的 PNG 帧被正确嗅探 ===")
    fresh()
    local grp = readAsset("data/hdgrp.grp")
    local idx = readAsset("data/hdgrp.idx")
    TestHelper.assertNotNil(grp, "应能读到 hdgrp.grp")

    local offs = SD.parseIdx(idx, #grp)
    -- 实测：slot 60 与 slot 112 是合法 PNG（100x102 / 100x93，8 位深 RGBA）
    local f60 = SD.sliceFrame(grp, offs, 60)
    local f112 = SD.sliceFrame(grp, offs, 112)
    TestHelper.assertNotNil(f60, "slot 60 应有数据")
    TestHelper.assertNotNil(f112, "slot 112 应有数据")

    TestHelper.assertEquals("png", SD.sniffFormat(f60), "slot 60 应识别为 PNG")
    TestHelper.assertEquals("png", SD.sniffFormat(f112), "slot 112 应识别为 PNG")
end

-- ------------------------------------------------------------ 锚点（ADR-PORT-014）

function TestSpriteDecoder.testRleAnchorFromFrameHeader()
    print("\n=== Test: RLE 锚点来自帧头 ===")
    fresh()
    local a = SD.decodeAnchors("rle", 15, 39, { xoff = 5, yoff = 44 }, nil)
    TestHelper.assertEquals(5, a.xoff, "RLE 的 xoff 用帧头值")
    TestHelper.assertEquals(44, a.yoff, "RLE 的 yoff 用帧头值（主角帧实测 15x39 xoff=5 yoff=44）")
end

function TestSpriteDecoder.testAvatarPngUsesCenterAnchor()
    print("\n=== Test: 头像 PNG 用中心锚点 ===")
    fresh()
    -- 实测：hdgrp slot60 = 100x102, slot112 = 100x93
    local a60 = SD.decodeAnchors("png", 100, 102, nil, "avatar")
    TestHelper.assertEquals(50, a60.xoff, "头像 xoff = w/2 = 50")
    TestHelper.assertEquals(51, a60.yoff, "头像 yoff = h/2 = 51（中心锚定）")

    local a112 = SD.decodeAnchors("png", 100, 93, nil, "avatar")
    TestHelper.assertEquals(50, a112.xoff, "头像 100x93 xoff = 50")
    TestHelper.assertEquals(46, a112.yoff, "头像 100x93 yoff = 46")
end

function TestSpriteDecoder.testNonAvatarPngUsesFootAnchor()
    print("\n=== Test: 非头像 PNG 用脚底锚点 ===")
    fresh()
    local a = SD.decodeAnchors("png", 100, 102, nil, nil)
    TestHelper.assertEquals(50, a.xoff, "地图精灵 xoff = w/2")
    TestHelper.assertEquals(102, a.yoff, "地图精灵 yoff = h（脚底中心）")
end

function TestSpriteDecoder.testExplicitOptsOverride()
    print("\n=== Test: 显式 opts 覆盖优先级最高 ===")
    fresh()
    local a = SD.decodeAnchors("rle", 15, 39, { xoff = 5, yoff = 44 }, nil,
                              { xoff = 7, yoff = 39 })
    TestHelper.assertEquals(7, a.xoff, "显式 xoff 应覆盖帧头")
    TestHelper.assertEquals(39, a.yoff, "显式 yoff 应覆盖帧头")
end

-- 负向对照：把头像锚点当成脚底 → 测试必须失败
function TestSpriteDecoder.testAvatarAnchorWouldBeWrongIfFoot()
    print("\n=== Test: 头像用脚底锚点会偏半个身位 ===")
    fresh()
    local center = SD.decodeAnchors("png", 100, 102, nil, "avatar")
    local foot   = SD.decodeAnchors("png", 100, 102, nil, nil)
    TestHelper.assertTrue(center.yoff ~= foot.yoff,
        string.format("头像中心锚点(%d) 与脚底锚点(%d) 必须不同（否则说明分类失效）",
            center.yoff, foot.yoff))
    TestHelper.assertEquals(51, foot.yoff - (foot.yoff - center.yoff), "脚底减中心应为 51px（半个身位）")
end

-- ------------------------------------------------------------ 调色板

function TestSpriteDecoder.testLoadPalette()
    print("\n=== Test: 调色板加载 ===")
    fresh()
    local col = readAsset("data/mmap.col")
    TestHelper.assertNotNil(col, "应能读到 mmap.col")
    local pal = SD.loadPalette(col)
    TestHelper.assertEquals(256, #pal, "调色板应为 256 项")
    -- 原版 6bit（0..63）× 4 = 0..255；第 1 项实测 0,0,0
    TestHelper.assertEquals(0, pal[1].r, "第 1 项 r=0")
    TestHelper.assertEquals(0, pal[1].g, "第 1 项 g=0")
    TestHelper.assertEquals(0, pal[1].b, "第 1 项 b=0")
end

function TestSpriteDecoder.testLoadPaletteScales6bit()
    print("\n=== Test: 调色板 6bit → 8bit ===")
    fresh()
    -- 构造 256 项，第 1 项 RGB = (1,2,3)（6bit）→ *4 = (4,8,12)
    local bytes = string.char(1, 2, 3) .. string.rep(string.char(0, 0, 0), 255)
    local pal = SD.loadPalette(bytes)
    TestHelper.assertEquals(4, pal[1].r, "1 * 4 = 4")
    TestHelper.assertEquals(8, pal[1].g, "2 * 4 = 8")
    TestHelper.assertEquals(12, pal[1].b, "3 * 4 = 12")
end

-- 套件入口
function TestSpriteDecoder.runAll()
    print("\n" .. string.rep("=", 60))
    print("精灵解码层测试（ADR-PORT-013 / 014）")
    print(string.rep("=", 60))
    TestHelper.setup()
    TestHelper.resetCounts()

    TestSpriteDecoder.testNoEngineDependency()

    TestSpriteDecoder.testParseIdxBasic()
    TestSpriteDecoder.testParseIdxClampsOvershoot()
    TestSpriteDecoder.testParseIdxEmpty()

    TestSpriteDecoder.testSliceFrame()
    TestSpriteDecoder.testSliceFrameOutOfRange()

    TestSpriteDecoder.testSniffPng()
    TestSpriteDecoder.testSniffPartialPngIsRle()
    TestSpriteDecoder.testSniffRle()

    TestSpriteDecoder.testRealAssetDecode()
    TestSpriteDecoder.testAlphaOnlyZeroOr255()
    TestSpriteDecoder.testDecodedLengthAlwaysExact()
    TestSpriteDecoder.testHdgrpPngFramesDetected()

    TestSpriteDecoder.testRleAnchorFromFrameHeader()
    TestSpriteDecoder.testAvatarPngUsesCenterAnchor()
    TestSpriteDecoder.testNonAvatarPngUsesFootAnchor()
    TestSpriteDecoder.testExplicitOptsOverride()
    TestSpriteDecoder.testAvatarAnchorWouldBeWrongIfFoot()

    TestSpriteDecoder.testLoadPalette()
    TestSpriteDecoder.testLoadPaletteScales6bit()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_sprite_decoder.lua$") then
    TestSpriteDecoder.runAll()
end

return TestSpriteDecoder
