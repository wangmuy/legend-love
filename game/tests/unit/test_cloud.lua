-- test_cloud.lua
-- 「主地图飘云」子系统（engine-love2d/lib_love.lua 的 Cloud* / DrawClouds）单元测试。
--
-- 原版 kys（kys_main.cpp / kys_draw.cpp / kys_engine.cpp）在大地图渲染 60 朵云：
--   * cloud.idx/cloud.grp 为 9 帧 RLE，idx 每项是「一帧的末偏移」（无 /2 映射）；
--   * 每 40ms 每朵云右移 Speedx(1..3)px（MMAPAMI>0 门控，next_time3=now+40）；
--     越界（x>17279 或 <0 等）后 CloudCreateOnSide 从左侧重生（Positionx=0）；
--   * 每朵云随机 mixColor/mixAlpha(10..59)：调色板像素先朝 mixColor 混合
--     mixAlpha%（DrawRLE8Pic）；再整体合成到背景。原版的 Alpha(10..59) 是
--     「背景透出百分比」：out = 背景*(Alpha/100) + 云色*((100-Alpha)/100)，
--     故云自身不透明度 = (100-Alpha)/100（Alpha=10 → 90% 不透明）。
--
-- 本套件锁定：
--   1) CloudLoadAndInit 生成 60 朵云，各字段范围与原版一致；
--   2) DrawClouds 画满 60 朵，屏幕坐标公式与原版逐字一致，
--      且每朵云 setColor(1,1,1,Alpha/100)、画完复位；
--   3) 40ms tick 节奏：窗口内不重复移动，窗口后恰好移动 Speedx(1..3)px；
--   4) 云越过右边界后在左侧重生（Positionx=0）；
--   5) MMAPAMI=0 关闭漂移、=1 恢复；
--   6) 像素级对拍：合成 RLE 帧 + 真实 mmap.col 调色板，烘焙像素值与原版
--      DrawRLE8Pic 的 mix 公式逐位一致；
--   7) 云文件缺失时静默降级为 0 绘制、不报错。

local TestHelper = require("tests.test_helper")
local TestCloud = {}

local Lib
local draws = {}
local colorCalls = {}
local clockTime = 0   -- 秒（mock love.timer.getTime）
local harnessReady = false

-- 假 ImageData：记录 setPixel，供像素级断言
local FakeImageData = {}
FakeImageData.__index = FakeImageData

local function newFakeImageData(w, h)
    return setmetatable({ w = w, h = h, px = {} }, FakeImageData)
end

function FakeImageData:setPixel(x, y, r, g, b, a)
    self.px[x .. "," .. y] = { r, g, b, a }
end

local function bootEngine()
    if not harnessReady then
        require("tests.mod_boot_harness").setup()
        harnessReady = true
    end
    draws = {}
    colorCalls = {}
    _G.love.graphics.draw = function(img, x, y)
        draws[#draws + 1] = { img = img, x = x, y = y }
    end
    _G.love.graphics.setColor = function(r, g, b, a)
        colorCalls[#colorCalls + 1] = { r = r, g = g, b = b, a = a }
    end
    _G.love.graphics.newImage = function(id)
        return { fake = id, w = id.w, h = id.h }
    end
    _G.love.image.newImageData = function(w, h)
        return newFakeImageData(w, h)
    end
    _G.love.timer.getTime = function() return clockTime end
    _G.love.graphics.getScissor = function() return nil end
    _G.love.graphics.setScissor = function() end
    _G.Debug = function() end

    -- 重新加载 lib_love，避免与其他套件共享云状态（与 test_mmap_depth 同款模式）
    package.loaded["engine-love2d.lib_love"] = nil
    local ok, mod = pcall(require, "engine-love2d.lib_love")
    if not ok then
        TestHelper.assertTrue(false, "加载 lib_love 失败: " .. tostring(mod))
        return nil
    end
    Lib = mod
    Lib.PicInit(CC.PaletteFile)   -- 载入真实 mmap.col 调色板（Init_MMap 首步同款）
    return Lib
end

local function loadRealClouds()
    clockTime = 0
    Lib.CloudLoadAndInit(CC.CloudPicFile[1], CC.CloudPicFile[2])
end

-- ---------------------------------------------------------------- 测试用例

-- 1) 生成 60 朵云，字段范围与原版 CloudCreate/CloudCreateOnSide 一致
function TestCloud.testInitSpawns60CloudsWithValidFields()
    print("\n=== Test: CloudLoadAndInit 生成 60 朵云且字段范围符合原版 ===")
    if not bootEngine() then return end
    math.randomseed(20261108)
    loadRealClouds()
    local list = Lib.CloudGetList()
    TestHelper.assertEquals(60, #list, "应生成 60 朵云（原版 CLOUD_AMOUNT=60）")

    local badPicnum, badAlpha, badPos, badSpeed, noImg = 0, 0, 0, 0, 0
    for i = 1, 60 do
        local c = list[i]
        if not (c.Picnum >= 0 and c.Picnum <= 8) then badPicnum = badPicnum + 1 end
        if not (c.Alpha >= 10 and c.Alpha <= 59
            and c.mixAlpha >= 10 and c.mixAlpha <= 59) then
            badAlpha = badAlpha + 1
        end
        if not (c.Positionx >= 0 and c.Positionx <= 17279
            and c.Positiony >= 0 and c.Positiony <= 8639) then
            badPos = badPos + 1
        end
        if not (c.Speedx >= 1 and c.Speedx <= 3 and c.Speedy == 0) then
            badSpeed = badSpeed + 1
        end
        if c.img == nil then noImg = noImg + 1 end
    end
    TestHelper.assertEquals(0, badPicnum, "Picnum 应全部落在 0..8（cloud.idx 共 9 帧）")
    TestHelper.assertEquals(0, badAlpha, "Alpha/mixAlpha 应落在 10..59（原版 10+rand%50）")
    TestHelper.assertEquals(0, badPos, "坐标应落在云世界 17280x8640 内")
    TestHelper.assertEquals(0, badSpeed, "Speedx 应为 1..3 且 Speedy 恒为 0")
    TestHelper.assertEquals(0, noImg, "每朵云的调色贴图都应烘焙成功")
end

-- 2) DrawClouds：数量、原版坐标公式、setColor(1,1,1,(100-Alpha)/100) 与复位
function TestCloud.testDrawCloudsCountFormulaAndAlpha()
    print("\n=== Test: DrawClouds 画满 60 朵，坐标公式与透明度符合原版 ===")
    if not bootEngine() then return end
    math.randomseed(42)
    loadRealClouds()
    local list = Lib.CloudGetList()

    draws = {}
    colorCalls = {}
    local mx, my = 20, 19
    Lib.DrawClouds(mx, my)
    TestHelper.assertEquals(60, #draws, "应画满 60 朵云")

    -- 第 1 朵云的屏幕坐标必须与原版公式逐字一致：
    --   x = Positionx - (-Mx*18 + My*18 + 8640 - CENTER_X)
    --   y = Positiony - (Mx*9 + My*9 + 9 - CENTER_Y)
    local c1 = list[1]
    local centerX = math.floor(CONFIG.Width / 2)
    local centerY = math.floor(CONFIG.Height / 2)
    TestHelper.assertEquals(
        c1.Positionx - (-mx * 18 + my * 18 + 8640 - centerX) - c1.xoff, draws[1].x,
        "云 1 屏幕 x 符合原版公式（含 8640、centerX、xoff 项）")
    TestHelper.assertEquals(
        c1.Positiony - (mx * 9 + my * 9 + 9 - centerY) - c1.yoff, draws[1].y,
        "云 1 屏幕 y 符合原版公式（含 9、centerY、yoff 项）")
    TestHelper.assertTrue(draws[1].img == list[1].img,
        "绘制目标应为云 1 自己烘焙的贴图")

    -- 每朵云一次非复位 setColor(1,1,1,(100-Alpha)/100)，画完复位白色。
    -- 原版 out = 背景*(Alpha/100) + 云色*((100-Alpha)/100)，云的「不透明度」
    -- 是 (100-Alpha)/100；LÖVE source-over 需要传入这个不透明度。
    local tintCalls, badTint, ci = 0, 0, 0
    for _, col in ipairs(colorCalls) do
        if col.a ~= 1 then
            tintCalls = tintCalls + 1
            ci = ci + 1
            local c = list[ci]
            if not (col.r == 1 and col.g == 1 and col.b == 1
                and col.a == (100 - c.Alpha) / 100) then
                badTint = badTint + 1
            end
        end
    end
    TestHelper.assertEquals(60, tintCalls, "60 朵云应对应 60 次非复位 setColor")
    TestHelper.assertEquals(0, badTint, "调色应为 (1,1,1,(100-Alpha)/100)（云不透明度）")
    TestHelper.assertEquals(60, #colorCalls - tintCalls, "每朵云画完都应复位白色")
end

-- 3) 40ms 节奏：next_time3=now+40 语义（窗口内不动、窗口后动恰好 Speedx）
function TestCloud.testTickCadenceIs40ms()
    print("\n=== Test: 云漂移 40ms 节奏（GetTime 门控） ===")
    if not bootEngine() then return end
    math.randomseed(7)
    loadRealClouds()
    local list = Lib.CloudGetList()
    local function snapshot()
        local s = {}
        for i = 1, 60 do s[i] = list[i].Positionx end
        return s
    end

    local before0 = snapshot()
    clockTime = 0.03          -- 距初始化 30ms > 0 → 首次漂移（原版初始化后同样立即生效）
    Lib.CloudTick()
    local s1 = snapshot()
    local moved1, badStep = 0, 0
    for i = 1, 60 do
        local d = s1[i] - before0[i]
        if (d >= 1 and d <= 3) or d < 0 then moved1 = moved1 + 1  -- d<0 = 越界重生
        else badStep = badStep + 1 end
    end
    TestHelper.assertEquals(60, moved1, "首个 40ms 窗口后所有云应漂移 1..3px（或越界重生）")
    TestHelper.assertEquals(0, badStep, "单次漂移应恰好为 Speedx(1..3)px")

    clockTime = 0.05          -- 50ms < 70ms(next)：不应再动
    Lib.CloudTick()
    local s2 = snapshot()
    local changed2 = 0
    for i = 1, 60 do if s2[i] ~= s1[i] then changed2 = changed2 + 1 end end
    TestHelper.assertEquals(0, changed2, "40ms 窗口内不应再次移动（原版 next_time3=now+40）")

    clockTime = 0.08          -- 80ms > 70ms：第二次漂移
    Lib.CloudTick()
    local s3 = snapshot()
    local moved3 = 0
    for i = 1, 60 do
        local d = s3[i] - s2[i]
        if (d >= 1 and d <= 3) or d < 0 then moved3 = moved3 + 1 end
    end
    TestHelper.assertEquals(60, moved3, "40ms 窗口过后应再次漂移")
end

-- 4) 右边界重生（原版边界 17279，CloudCreateOnSide: Positionx=0）
function TestCloud.testRespawnOnRightEdge()
    print("\n=== Test: 越过右边界的云在左侧重生 ===")
    if not bootEngine() then return end
    math.randomseed(11)
    loadRealClouds()
    local list = Lib.CloudGetList()
    local c = list[1]
    c.Positionx = 17279       -- 一次漂移即越界（原版边界 17279）
    c.Positiony = 123
    clockTime = 1.0
    Lib.CloudTick()
    TestHelper.assertEquals(0, c.Positionx,
        "越界应左侧重生（CloudCreateOnSide: Positionx=0）")
    TestHelper.assertTrue(c.Positiony >= 0 and c.Positiony <= 8639,
        "重生后 Positiony 应在 0..8639")
    TestHelper.assertTrue(c.img ~= nil, "重生后应重新烘焙贴图")
end

-- 5) MMAPAMI 门控：0 静止、1 恢复（原版 kys_main.cpp:1897 MMAPAMI>0）
function TestCloud.testTickGatedByMMapAmi()
    print("\n=== Test: MMAPAMI=0 关闭漂移、=1 恢复 ===")
    if not bootEngine() then return end
    math.randomseed(13)
    loadRealClouds()
    local list = Lib.CloudGetList()
    local before = {}
    for i = 1, 60 do before[i] = list[i].Positionx end

    CC.MMapAmi = 0
    clockTime = 1.0
    Lib.CloudTick()
    local frozen = 0
    for i = 1, 60 do if list[i].Positionx == before[i] then frozen = frozen + 1 end end
    TestHelper.assertEquals(60, frozen, "MMAPAMI=0：所有云静止（原版 MMAPAMI>0 门控）")

    CC.MMapAmi = 1
    clockTime = 2.0
    Lib.CloudTick()
    local moved = 0
    for i = 1, 60 do
        local d = list[i].Positionx - before[i]
        if (d >= 1 and d <= 3) or d < 0 then moved = moved + 1 end
    end
    TestHelper.assertEquals(60, moved, "MMAPAMI=1：所有云恢复漂移")
    CC.MMapAmi = 1
end

-- 6) 像素级对拍：合成 RLE 帧 + 真实 mmap.col，烘焙值 == 原版 mix 公式
function TestCloud.testBakePixelParityWithMixFormula()
    print("\n=== Test: 烘焙像素与原版 DrawRLE8Pic mix 公式逐位一致 ===")
    if not bootEngine() then return end

    -- 真实调色板：mmap.col 第 i 项（1 基）= (b0*4, b1*4, b2*4)
    local colData = io.open("data/mmap.col", "rb"):read("*a")
    local function pal(i)
        local o = (i - 1) * 3
        return colData:byte(o + 1) * 4, colData:byte(o + 2) * 4, colData:byte(o + 3) * 4
    end

    -- 合成帧 4x2（原版 RLE 状态机：行首 l = 本行命令字节总数，
    -- 之后为 跳过/数量/像素... 序列，行尾允许 trailing skip）：
    --   y=0: 跳1, 数量2, 调色板0, 调色板1        → 实心 (1,0)=调色板0, (2,0)=调色板1
    --   y=1: 跳0, 数量1, 调色板2, [跳1]          → 实心 (0,1)=调色板2（行尾 trailing skip）
    local row0 = string.char(4, 1, 2, 0, 1)
    local row1 = string.char(4, 0, 1, 2, 1)
    local header = string.char(4, 0, 2, 0, 0, 0, 0, 0)  -- w=4 h=2 xoff=0 yoff=0 (LE)
    local frame = header .. row0 .. row1
    local idx = string.char(frame:len() % 256, math.floor(frame:len() / 256) % 256, 0, 0)

    local tmpIdx = os.tmpname()
    local tmpGrp = os.tmpname()
    io.open(tmpIdx, "wb"):write(idx):close()
    io.open(tmpGrp, "wb"):write(frame):close()

    math.randomseed(99)
    clockTime = 0
    Lib.CloudLoadAndInit(tmpIdx, tmpGrp)
    os.remove(tmpIdx)
    os.remove(tmpGrp)

    local list = Lib.CloudGetList()
    TestHelper.assertEquals(60, #list, "合成云数据（1 帧）下仍应生成 60 朵云")
    local allZero = true
    for i = 1, 60 do if list[i].Picnum ~= 0 then allZero = false end end
    TestHelper.assertTrue(allZero, "只有 1 帧时所有 Picnum 应为 0")

    local c = list[1]
    local px = c.img.fake.px
    local solid = 0
    for _ in pairs(px) do solid = solid + 1 end
    TestHelper.assertEquals(3, solid, "帧内 3 个不透明像素应全部烘焙")

    local function expectMix(orig, mix, m)
        return ((m * mix + (100 - m) * orig) / 100) / 255
    end
    local function baked(x, y)
        local p = px[x .. "," .. y]
        return p and p[1], p and p[2], p and p[3], p and p[4]
    end

    local pr, pg, pb = pal(1)   -- RLE 值 0 → 调色板[1]
    local r, g, b, a = baked(1, 0)
    TestHelper.assertEquals(expectMix(pr, c.mixR, c.mixAlpha), r, "(1,0) R 符合 mix 公式")
    TestHelper.assertEquals(expectMix(pg, c.mixG, c.mixAlpha), g, "(1,0) G 符合 mix 公式")
    TestHelper.assertEquals(expectMix(pb, c.mixB, c.mixAlpha), b, "(1,0) B 符合 mix 公式")
    TestHelper.assertEquals(1, a, "不透明像素 alpha 应为 1")

    pr, pg, pb = pal(2)         -- RLE 值 1 → 调色板[2]
    r = baked(2, 0)
    TestHelper.assertEquals(expectMix(pr, c.mixR, c.mixAlpha), r, "(2,0) R 应取调色板[2] 混合")

    pr, pg, pb = pal(3)         -- RLE 值 2 → 调色板[3]（行尾 trailing skip 之后的行）
    r = baked(0, 1)
    TestHelper.assertEquals(expectMix(pr, c.mixR, c.mixAlpha), r, "(0,1) R 应取调色板[3] 混合")

    TestHelper.assertNil(px["0,0"], "(0,0) 透明像素不应烘焙")
    TestHelper.assertNil(px["3,0"], "(3,0) 透明像素不应烘焙")
    TestHelper.assertNil(px["1,1"], "(1,1) 透明像素不应烘焙（trailing skip 生效）")
end

-- 7) 云文件缺失：静默降级为 0 绘制、不报错
function TestCloud.testMissingCloudFilesAreGraceful()
    print("\n=== Test: 云文件缺失时静默降级 ===")
    if not bootEngine() then return end
    math.randomseed(3)
    clockTime = 0
    Lib.CloudLoadAndInit("data/definitely_missing_cloud.idx",
                         "data/definitely_missing_cloud.grp")
    draws = {}
    Lib.DrawClouds(20, 19)
    TestHelper.assertEquals(0, #draws, "云数据缺失应静默降级为 0 绘制")
    local ok, err = pcall(Lib.CloudTick)
    TestHelper.assertTrue(ok, "CloudTick 数据缺失时不应报错: " .. tostring(err))
    local ok2, err2 = pcall(Lib.DrawClouds, 20, 19)
    TestHelper.assertTrue(ok2, "DrawClouds 数据缺失时不应报错: " .. tostring(err2))
end

-- 8) PicLoadFile 槽位上界：与原版 PIC_FILE_NUM=40 一致，id 合法范围 0..39
function TestCloud.testPicLoadFileSlotBounds()
    print("\n=== Test: PicLoadFile 槽位上界与原版 PIC_FILE_NUM 一致 ===")
    if not bootEngine() then return end
    local cache = Lib.picFileCache

    -- 云槽位必须在原版合法区间内
    Lib.CloudLoadAndInit(CC.CloudPicFile[1], CC.CloudPicFile[2])
    TestHelper.assertNotNil(cache[40], "云槽位 39（1 基下标 40）应成功载入")

    -- 上界：id=40 超界（原版 0..39），必须静默拒绝
    cache[41] = nil
    Lib.PicLoadFile(CC.CloudPicFile[1], CC.CloudPicFile[2], 40)
    TestHelper.assertNil(cache[41], "id=40 超界应被拒绝（原版 piccache.c 上界检查）")

    -- 下界：id=-1 同样拒绝（原有行为，不得回退）
    cache[0] = nil
    Lib.PicLoadFile(CC.CloudPicFile[1], CC.CloudPicFile[2], -1)
    TestHelper.assertNil(cache[0], "id=-1 应继续被拒绝")
end

function TestCloud.runAll()
    print("\n" .. string.rep("=", 60))
    print("主地图飘云（Cloud*）子系统测试")
    print(string.rep("=", 60))

    local savedMt = getmetatable(_G)
    setmetatable(_G, nil)

    TestCloud.testInitSpawns60CloudsWithValidFields()
    TestCloud.testDrawCloudsCountFormulaAndAlpha()
    TestCloud.testTickCadenceIs40ms()
    TestCloud.testRespawnOnRightEdge()
    TestCloud.testTickGatedByMMapAmi()
    TestCloud.testBakePixelParityWithMixFormula()
    TestCloud.testMissingCloudFilesAreGraceful()
    TestCloud.testPicLoadFileSlotBounds()

    setmetatable(_G, savedMt)

    TestHelper.printSummary()
    return TestHelper.getStats().allPassed
end

return TestCloud
