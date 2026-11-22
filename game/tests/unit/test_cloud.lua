-- test_cloud.lua
-- 「主地图飘云」子系统的回归测试（port-legacy-picture-removal Task 3）
--
-- **本套件已从 lib_love 迁到 framework/cloud_layer.lua**：
--   旧的 `Lib.CloudLoadAndInit / CloudTick / DrawClouds / CloudGetList`
--   全部由 `CloudLayer.load / tick / draw / getList` 取代。
--
-- 原版行为（kys_main.cpp / kys_draw.cpp / kys_engine.cpp）：
--   * cloud.idx/cloud.grp 为 9 帧 RLE，idx 每项是「一帧的末偏移」（无 /2 映射）；
--   * 每 40ms 每朵云右移 Speedx(1..3)px（MMAPAMI>0 门控，next_time3=now+40）；
--     越界（x>17279 或 <0 等）后 CloudCreateOnSide 从左侧重生（Positionx=0）；
--   * 每朵云随机 mixColor/mixAlpha(10..59)：调色板像素先朝 mixColor 混合
--     mixAlpha%（DrawRLE8Pic）；再整体合成到背景。原版 Alpha(10..59) 是
--     「背景透出百分比」：out = 背景*(Alpha/100) + 云色*((100-Alpha)/100)，
--     故云自身不透明度 = (100-Alpha)/100（Alpha=10 → 90% 不透明）。
--
-- 本套件锁定：
--   0) **解码等价性**：旧「行内状态机」vs framework `SpriteDecoder.decodeRLE`
--      在真实 cloud.grp 上 9/9 帧的 {w,h,xoff,yoff,非透明像素数} 完全一致；
--      以及迁移前的硬编码期望值（guard 回归）
--   1) load 生成 60 朵云，各字段范围与原版一致；
--   2) draw 画满 60 朵，屏幕坐标公式与本项目地形投影一致（含 y 轴逐字同原版、
--      x 轴镜像改号的推导），且每朵 handle 的 alpha = (100-Alpha)/100*255；
--   2b) 云为「世界锚定」图层：主角移动 1 格时云的屏幕位移必须与地形/建筑
--      的屏幕位移完全相同（历史 bug：照抄原版 x 公式导致云反向滑动）；
--   3) 40ms tick 节奏：窗口内不重复移动，窗口后恰好移动 Speedx(1..3)px；
--   4) 云越过右边界后在左侧重生（Positionx=0）；
--   5) MMAPAMI=0 关闭漂移、=1 恢复；
--   6) 像素级对拍：合成 RLE 帧 + 真实 mmap.col 调色板，烘焙像素值与原版
--      DrawRLE8Pic 的 mix 公式逐位一致；
--   7) 云文件缺失时静默降级为 0 绘制、不报错。

local TestHelper = require("tests.test_helper")
local TestCloud = {}

local CloudLayer
local draws = {}       -- { {x=, y=, alpha=, flags=}, ... }
local clockTime = 0    -- 毫秒（EngineAPI.time.getTime 返回值）
local harnessReady = false

-- ---------------------------------------------------------------------------
-- 环境：EngineAPI.time / file / sprite（测试桩）+ CONFIG/CC
-- ---------------------------------------------------------------------------

local savedEngineAPI, savedConfig, savedCC

local function bootHarness()
    if not harnessReady then
        require("tests.mod_boot_harness").setup()
        harnessReady = true
    end
end

--- 装**本套件私有的**最小 EngineAPI（不碰共享的 tests/engine_test）
--
-- **为什么不复用 tests.engine_test**（踩过的坑）：
--   那样要 `package.loaded["tests.engine_test"] = nil` 再 require，
--   并覆盖它的 `sprite.drawHandle` / `time.getTime` —— 而这些覆盖会**泄漏**
--   到后面的套件（engine_conformance / version_compat 一起跑时整个 runner
--   进程在打印途中崩溃，单独跑却正常）。私有桩零共享，最稳。
local function installEnv()
    bootHarness()
    savedEngineAPI = rawget(_G, "EngineAPI")
    savedConfig = rawget(_G, "CONFIG")
    savedCC = rawget(_G, "CC")

    local stub = {
        _callLog = {},
        time = {
            getTime = function() return clockTime end,
            getTimeSeconds = function() return clockTime / 1000 end,
            sleep = function() end,
        },
        debug = { log = function() end },
        coroutine = { isRunning = function() return false end },
        file = {
            read = function(path)
                local f = io.open(path, "rb")
                if not f then return nil end
                local content = f:read("*a")
                f:close()
                return content
            end,
        },
        sprite = {},
    }

    stub.sprite.createFromRGBA = function(w, h, rgbaBytes, opts)
        if type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then
            return nil
        end
        if type(rgbaBytes) ~= "string" or #rgbaBytes < w * h * 4 then return nil end
        opts = opts or {}
        return { w = w, h = h, xoff = opts.xoff or 0, yoff = opts.yoff or 0,
                 rgbaLen = #rgbaBytes }
    end

    stub.sprite.drawHandle = function(handle, x, y, flags, alpha)
        draws[#draws + 1] = { x = x, y = y, flags = flags, alpha = alpha, handle = handle }
        return type(handle) == "table"
    end

    rawset(_G, "EngineAPI", stub)
    rawset(_G, "CONFIG", {
        Width = 1024, Height = 768, XScale = 18, YScale = 9,
        SoundPath = "sound/", PicturePath = "pic/",
    })
    rawset(_G, "CC", {
        PaletteFile = "data/mmap.col",
        CloudPicFile = { "data/cloud.idx", "data/cloud.grp" },
        MWidth = 480, MHeight = 480,
        MMapAmi = 1,
    })

    draws = {}
    return stub
end

local function restoreEnv()
    rawset(_G, "EngineAPI", savedEngineAPI)
    rawset(_G, "CONFIG", savedConfig)
    rawset(_G, "CC", savedCC)
end

local function freshLayer()
    package.loaded["framework.cloud_layer"] = nil
    CloudLayer = require("framework.cloud_layer")
    return CloudLayer
end

local function loadRealClouds()
    clockTime = 0
    CloudLayer.reset()
    CloudLayer.load("data/cloud.idx", "data/cloud.grp", "data/mmap.col")
    CloudLayer._setNextTick(0)
end

-- ---------------------------------------------------------------- ① 解码等价

--- 旧实现（lib_love.CloudDecodeFrame）的行内状态机解码，逐字复刻
-- 仅用于对拍：迁移后它已随 425 行旧贴图子系统删除。
-- @return w, h, set（set["x,y"] = 调色板索引）
local function legacyStateMachineDecode(bytes)
    local w = bytes:byte(1) + bytes:byte(2) * 256
    local h = bytes:byte(3) + bytes:byte(4) * 256
    local pos = 9
    local set = {}
    for iy = 1, h do
        if pos > #bytes then break end
        local l = bytes:byte(pos); pos = pos + 1
        local col = 1
        local p = 0
        for _ = 1, l do
            if pos > #bytes then break end
            local b = bytes:byte(pos); pos = pos + 1
            if p == 0 then col = col + b; p = 1
            elseif p == 1 then p = 2 + b
            elseif p > 2 then
                p = p - 1
                local x = col - 1
                if x >= 0 and x < w then set[x .. "," .. (iy - 1)] = b end
                col = col + 1
                if p == 2 then p = 0 end
            end
        end
    end
    return w, h, set
end

function TestCloud.testDecoderEquivalenceOnRealCloudGrp()
    print("\n=== Test: framework 解码器与旧状态机在真实 cloud.grp 上逐帧一致 ===")
    installEnv()
    bootHarness()

    local Decoder = require("framework.sprite_decoder")
    local function readAll(path)
        local f = assert(io.open(path, "rb"))
        local s = f:read("*a")
        f:close()
        return s
    end
    local idxBytes = readAll("data/cloud.idx")
    local grpBytes = readAll("data/cloud.grp")
    local palette = Decoder.loadPalette(readAll("data/mmap.col"))
    local offsets = Decoder.parseIdx(idxBytes, #grpBytes)

    TestHelper.assertEquals(9, #offsets - 1, "cloud.idx 应为 9 帧")

    -- 迁移前的实测期望值（硬编码锁死：这组数一旦变化说明解码头动了）
    local expected = {
        [1] = { 126, 22, 1619 },
        [2] = { 142, 44, 3441 },
        [3] = { 135, 37, 3080 },
        [4] = { 58, 22, 790 },
        [5] = { 126, 22, 1619 },
        [6] = { 142, 44, 3441 },
        [7] = { 135, 37, 3080 },
        [8] = { 58, 22, 790 },
        [9] = { 250, 250, 17864 },
    }

    local diffCount = 0
    for slot = 1, #offsets - 1 do
        local bytes = Decoder.sliceFrame(grpBytes, offsets, slot)
        TestHelper.assertNotNil(bytes, "slot " .. slot .. " 应有字节段")

        local wOld, hOld, setOld = legacyStateMachineDecode(bytes)
        local d = Decoder.decodeRLE(bytes, palette)
        TestHelper.assertNotNil(d, "slot " .. slot .. " decodeRLE 应成功")

        local nOld = 0
        for _ in pairs(setOld) do nOld = nOld + 1 end
        local nNew = 0
        for i = 4, #d.rgba, 4 do
            if d.rgba:byte(i) == 255 then nNew = nNew + 1 end
        end

        if wOld ~= d.w or hOld ~= d.h or nOld ~= nNew then
            diffCount = diffCount + 1
            print(string.format("  DIFF slot %d: old=%dx%d/%d new=%dx%d/%d",
                slot, wOld, hOld, nOld, d.w, d.h, nNew))
        end

        local e = expected[slot]
        TestHelper.assertEquals(e[1], d.w, "slot " .. slot .. " 宽应与迁移前一致")
        TestHelper.assertEquals(e[2], d.h, "slot " .. slot .. " 高应与迁移前一致")
        TestHelper.assertEquals(e[3], nNew, "slot " .. slot .. " 非透明像素数应与迁移前一致")
    end
    TestHelper.assertEquals(0, diffCount, "两种解码在云数据上必须逐帧一致")

    -- **必须收尾**：本用例开头 installEnv() 换掉了 _G.EngineAPI。
    -- 第一版漏了这一行，私有桩就泄漏到后面的套件 → 整个 runner 在
    -- version_compat 打印途中崩掉（单独跑却正常）。教训：installEnv 必须配对。
    restoreEnv()
end

-- ---------------------------------------------------------------- ① load 字段

function TestCloud.testLoadSpawns60CloudsWithValidFields()
    print("\n=== Test: CloudLayer.load 生成 60 朵云且字段范围符合原版 ===")
    installEnv()
    freshLayer()
    math.randomseed(20261108)
    loadRealClouds()

    local list = CloudLayer.getList()
    TestHelper.assertEquals(60, #list, "应生成 60 朵云（原版 CLOUD_AMOUNT=60）")
    TestHelper.assertEquals(9, CloudLayer.frameCount(), "应解出 9 帧")

    local badPicnum, badAlpha, badPos, badSpeed, noHandle = 0, 0, 0, 0, 0
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
        if c.handle == nil then noHandle = noHandle + 1 end
    end
    TestHelper.assertEquals(0, badPicnum, "Picnum 应全部落在 0..8（cloud.idx 共 9 帧）")
    TestHelper.assertEquals(0, badAlpha, "Alpha/mixAlpha 应落在 10..59（原版 10+rand%50）")
    TestHelper.assertEquals(0, badPos, "坐标应落在云世界 17280x8640 内")
    TestHelper.assertEquals(0, badSpeed, "Speedx 应为 1..3 且 Speedy 恒为 0")
    TestHelper.assertEquals(0, noHandle, "每朵云都应通过 createFromRGBA 拿到 handle")

    restoreEnv()
end

-- ---------------------------------------------------------- ② draw 公式/alpha

function TestCloud.testDrawCountFormulaAndAlpha()
    print("\n=== Test: CloudLayer.draw 画满 60 朵，坐标公式与透明度符合原版 ===")
    installEnv()
    freshLayer()
    math.randomseed(42)
    loadRealClouds()
    local list = CloudLayer.getList()

    draws = {}
    local mx, my = 20, 19
    CloudLayer.draw(mx, my)
    TestHelper.assertEquals(60, #draws, "应画满 60 朵云")

    local CONFIG = rawget(_G, "CONFIG")
    local centerX = math.floor(CONFIG.Width / 2)
    local centerY = math.floor(CONFIG.Height / 2)
    local c1 = list[1]
    local expectX = c1.Positionx
        - (mx * CONFIG.XScale - my * CONFIG.XScale + 8640 - centerX) - (c1.xoff or 0)
    local expectY = c1.Positiony
        - (mx * CONFIG.YScale + my * CONFIG.YScale + CONFIG.YScale - centerY)
        - (c1.yoff or 0)

    TestHelper.assertEquals(expectX, draws[1].x, "第 1 朵云屏幕 x 符合镜像改号公式")
    TestHelper.assertEquals(expectY, draws[1].y, "第 1 朵云屏幕 y 与原版逐字一致")
    TestHelper.assertEquals(0x1, draws[1].flags,
        "绘制 flag 应为 0x1（忽略锚点；云锚点恒为 0，无影响）")

    local expectAlpha = math.floor((100 - c1.Alpha) / 100 * 255 + 0.5)
    TestHelper.assertEquals(expectAlpha, draws[1].alpha,
        "alpha 契约值 = round((100-Alpha)/100 * 255)（原版 Alpha 是背景透出百分比）")

    restoreEnv()
end

-- ---------------------------------------------------- ②b 世界锚定（不反向滑动）

function TestCloud.testCloudScrollMatchesTerrain()
    print("\n=== Test: 云为世界锚定图层（移动主角时与地形同步滚动） ===")
    installEnv()
    freshLayer()
    math.randomseed(11)
    loadRealClouds()

    local CONFIG = rawget(_G, "CONFIG")
    local function terrainScreen(u, v, mx, my)
        local i1, j1 = u - mx, v - my
        return CONFIG.XScale * (i1 - j1) + math.floor(CONFIG.Width / 2),
               CONFIG.YScale * (i1 + j1) + math.floor(CONFIG.Height / 2)
    end
    local U, V = 100, 100
    local mx, my = U - 2, V - 2

    local function cloudDrawPos(cmx, cmy)
        draws = {}
        CloudLayer.draw(cmx, cmy)
        return draws[1].x, draws[1].y
    end

    local moves = {
        { "按← (X-1)", -1, 0 }, { "按→ (X+1)", 1, 0 },
        { "按↑ (Y-1)", 0, -1 }, { "按↓ (Y+1)", 0, 1 },
        { "左上 (X-1,Y-1)", -1, -1 }, { "右下 (X+1,Y+1)", 1, 1 },
    }
    local bad = 0
    for _, m in ipairs(moves) do
        local name, dx, dy = m[1], m[2], m[3]
        local ax, ay = cloudDrawPos(mx, my)
        local bx, by = cloudDrawPos(mx + dx, my + dy)
        local t0x, t0y = terrainScreen(U, V, mx, my)
        local t1x, t1y = terrainScreen(U, V, mx + dx, my + dy)
        local cdx, cdy = bx - ax, by - ay
        local tdx, tdy = t1x - t0x, t1y - t0y
        if cdx ~= tdx or cdy ~= tdy then
            bad = bad + 1
            print(string.format("  MISMATCH %-16s 云 d=(%+d,%+d) 地形 d=(%+d,%+d)",
                name, cdx, cdy, tdx, tdy))
        end
        TestHelper.assertEquals(tdx, cdx, name .. "：云的屏幕 x 位移应与地形一致")
        TestHelper.assertEquals(tdy, cdy, name .. "：云的屏幕 y 位移应与地形一致")
    end
    TestHelper.assertEquals(0, bad, "六个方向的云滚动均不得与地形反向")

    -- 锚点自洽性：主角任意移动，云与同一个屏幕世界点的相对偏移恒定
    local c1 = CloudLayer.getList()[1]
    local cx0 = math.floor(CONFIG.Width / 2)
    local cy0 = math.floor(CONFIG.Height / 2)
    local function screenOfCloud(cmx, cmy)
        return c1.Positionx - (cmx * CONFIG.XScale - cmy * CONFIG.XScale
                   + 8640 - cx0) - (c1.xoff or 0),
               c1.Positiony - (cmx * CONFIG.YScale + cmy * CONFIG.YScale
                   + CONFIG.YScale - cy0) - (c1.yoff or 0)
    end
    local sx0, sy0 = screenOfCloud(100, 100)
    local tx0, ty0 = terrainScreen(U, V, 100, 100)
    local refDx, refDy = sx0 - tx0, sy0 - ty0
    for _, p in ipairs({ { 100, 100 }, { 101, 100 }, { 99, 103 }, { 104, 97 } }) do
        local sx, sy = screenOfCloud(p[1], p[2])
        local tx, ty = terrainScreen(U, V, p[1], p[2])
        TestHelper.assertEquals(refDx, sx - tx,
            string.format("主角(%d,%d) 时云与地形的 x 相对偏移应恒定", p[1], p[2]))
        TestHelper.assertEquals(refDy, sy - ty,
            string.format("主角(%d,%d) 时云与地形的 y 相对偏移应恒定", p[1], p[2]))
    end

    restoreEnv()
end

-- ------------------------------------------------------------ ③ 40ms 节奏

function TestCloud.testTickCadenceIs40ms()
    print("\n=== Test: 云漂移 40ms 节奏（tick 门控） ===")
    installEnv()
    freshLayer()
    math.randomseed(7)
    loadRealClouds()
    local list = CloudLayer.getList()
    local function snapshot()
        local s = {}
        for i = 1, 60 do s[i] = list[i].Positionx end
        return s
    end

    local before0 = snapshot()
    clockTime = 30            -- 距初始化 30ms > 0 → 首次漂移
    CloudLayer.tick()
    local s1 = snapshot()
    local moved1, badStep = 0, 0
    for i = 1, 60 do
        local d = s1[i] - before0[i]
        if (d >= 1 and d <= 3) or d < 0 then moved1 = moved1 + 1
        else badStep = badStep + 1 end
    end
    TestHelper.assertEquals(60, moved1, "首个 40ms 窗口后所有云应漂移 1..3px（或越界重生）")
    TestHelper.assertEquals(0, badStep, "单次漂移应恰好为 Speedx(1..3)px")

    clockTime = 50            -- 50ms < 70ms(next)：不应再动
    CloudLayer.tick()
    local s2 = snapshot()
    local changed2 = 0
    for i = 1, 60 do if s2[i] ~= s1[i] then changed2 = changed2 + 1 end end
    TestHelper.assertEquals(0, changed2, "40ms 窗口内不应再次移动（原版 next_time3=now+40）")

    clockTime = 80            -- 80ms > 70ms：第二次漂移
    CloudLayer.tick()
    local s3 = snapshot()
    local moved3 = 0
    for i = 1, 60 do
        local d = s3[i] - s2[i]
        if (d >= 1 and d <= 3) or d < 0 then moved3 = moved3 + 1 end
    end
    TestHelper.assertEquals(60, moved3, "40ms 窗口过后应再次漂移")

    restoreEnv()
end

-- ------------------------------------------------------------ ④ 越界重生

function TestCloud.testRespawnOnRightEdge()
    print("\n=== Test: 越过右边界的云在左侧重生 ===")
    installEnv()
    freshLayer()
    math.randomseed(11)
    loadRealClouds()
    local list = CloudLayer.getList()
    local c = list[1]
    c.Positionx = 17279       -- 一次漂移即越界（原版边界 17279）
    c.Positiony = 123
    clockTime = 1000
    CloudLayer.tick()
    TestHelper.assertEquals(0, c.Positionx,
        "越界应左侧重生（CloudCreateOnSide: Positionx=0）")
    TestHelper.assertTrue(c.Positiony >= 0 and c.Positiony <= 8639,
        "重生后 Positiony 应在 0..8639")
    TestHelper.assertNotNil(c.handle, "重生后应重新烘焙 handle")

    restoreEnv()
end

-- ------------------------------------------------------------ ⑤ MMAPAMI 门控

function TestCloud.testTickGatedByMMapAmi()
    print("\n=== Test: MMAPAMI=0 关闭漂移、=1 恢复 ===")
    installEnv()
    freshLayer()
    math.randomseed(13)
    loadRealClouds()
    local CC = rawget(_G, "CC")
    local list = CloudLayer.getList()
    local before = {}
    for i = 1, 60 do before[i] = list[i].Positionx end

    CC.MMapAmi = 0
    clockTime = 1000
    CloudLayer.tick()
    local frozen = 0
    for i = 1, 60 do if list[i].Positionx == before[i] then frozen = frozen + 1 end end
    TestHelper.assertEquals(60, frozen, "MMAPAMI=0：所有云静止（原版 MMAPAMI>0 门控）")

    CC.MMapAmi = 1
    clockTime = 2000
    CloudLayer.tick()
    local moved = 0
    for i = 1, 60 do
        local d = list[i].Positionx - before[i]
        if (d >= 1 and d <= 3) or d < 0 then moved = moved + 1 end
    end
    TestHelper.assertEquals(60, moved, "MMAPAMI=1：所有云恢复漂移")
    CC.MMapAmi = 1

    restoreEnv()
end

-- ------------------------------------------------------------ ⑥ 像素级对拍

function TestCloud.testBakePixelParityWithMixFormula()
    print("\n=== Test: 烘焙像素与原版 DrawRLE8Pic mix 公式逐位一致 ===")
    installEnv()
    freshLayer()

    -- 真实调色板：mmap.col 第 i 项（1 基）= (b0*4, b1*4, b2*4)
    local colData = io.open("data/mmap.col", "rb"):read("*a")
    local function pal(i)
        local o = (i - 1) * 3
        return colData:byte(o + 1) * 4, colData:byte(o + 2) * 4, colData:byte(o + 3) * 4
    end

    -- 合成帧 4x2（原版 RLE：行首 l = 本行命令字节总数）：
    --   y=0: 跳1, 数量2, 调色板0, 调色板1        → 实心 (1,0)/(2,0)
    --   y=1: 跳0, 数量1, 调色板2, [跳1]          → 实心 (0,1)（行尾 trailing skip）
    local row0 = string.char(4, 1, 2, 0, 1)
    local row1 = string.char(4, 0, 1, 2, 1)
    local header = string.char(4, 0, 2, 0, 0, 0, 0, 0)  -- w=4 h=2 xoff=0 yoff=0 (LE)
    local frame = header .. row0 .. row1
    local idx = string.char(frame:len() % 256, math.floor(frame:len() / 256) % 256, 0, 0)

    local tmpIdx = os.tmpname()
    local tmpGrp = os.tmpname()
    for path, payload in pairs({ [tmpIdx] = idx, [tmpGrp] = frame }) do
        local f = assert(io.open(path, "wb"))
        f:write(payload)
        f:close()
    end

    math.randomseed(99)
    clockTime = 0
    CloudLayer.reset()
    CloudLayer.load(tmpIdx, tmpGrp, "data/mmap.col")
    os.remove(tmpIdx)
    os.remove(tmpGrp)

    local list = CloudLayer.getList()
    TestHelper.assertEquals(60, #list, "合成云数据（1 帧）下仍应生成 60 朵云")
    local allZero = true
    for i = 1, 60 do if list[i].Picnum ~= 0 then allZero = false end end
    TestHelper.assertTrue(allZero, "只有 1 帧时所有 Picnum 应为 0")

    -- 直接用 bakeRGBA 断言（不再经过 ImageData 桩）
    local c = list[1]
    local frameData = CloudLayer.getFrames()[0]
    TestHelper.assertNotNil(frameData, "应解出 0 号帧")
    local rgba = CloudLayer.bakeRGBA(frameData, c.mixR, c.mixG, c.mixB, c.mixAlpha)
    TestHelper.assertNotNil(rgba, "bakeRGBA 应返回字节串")
    TestHelper.assertEquals(4 * 2 * 4, #rgba, "RGBA 字节数应为 w*h*4")

    local function px(x, y)
        local i = (y * 4 + x) * 4 + 1
        return rgba:byte(i), rgba:byte(i + 1), rgba:byte(i + 2), rgba:byte(i + 3)
    end
    local function expectMix(orig, mix, m)
        return math.floor((m * mix + (100 - m) * orig) / 100 + 0.5)
    end

    local pr, pg, pb = pal(1)   -- RLE 值 0 → 调色板[1]
    local r, g, b, a = px(1, 0)
    TestHelper.assertEquals(expectMix(pr, c.mixR, c.mixAlpha), r, "(1,0) R 符合 mix 公式")
    TestHelper.assertEquals(expectMix(pg, c.mixG, c.mixAlpha), g, "(1,0) G 符合 mix 公式")
    TestHelper.assertEquals(expectMix(pb, c.mixB, c.mixAlpha), b, "(1,0) B 符合 mix 公式")
    TestHelper.assertEquals(255, a, "不透明像素 alpha 应为 255")

    pr = pal(2)
    TestHelper.assertEquals(expectMix(pr, c.mixR, c.mixAlpha), (px(2, 0)),
        "(2,0) R 应取调色板[2] 混合")

    pr = pal(3)
    TestHelper.assertEquals(expectMix(pr, c.mixR, c.mixAlpha), (px(0, 1)),
        "(0,1) R 应取调色板[3] 混合（行尾 trailing skip 之后的行）")

    TestHelper.assertEquals(0, (px(0, 0)), "(0,0) 透明像素 R 应为 0")
    TestHelper.assertEquals(0, (px(0, 0)), "(0,0) alpha 应为 0")
    TestHelper.assertEquals(0, (px(3, 0)), "(3,0) 透明像素")
    TestHelper.assertEquals(0, (px(1, 1)), "(1,1) 透明像素（trailing skip 生效）")

    restoreEnv()
end

-- ------------------------------------------------------------ ⑦ 资源缺失降级

function TestCloud.testMissingCloudFilesAreGraceful()
    print("\n=== Test: 云文件缺失时静默降级 ===")
    installEnv()
    freshLayer()
    math.randomseed(3)
    clockTime = 0
    CloudLayer.reset()
    local n = CloudLayer.load("data/definitely_missing_cloud.idx",
                              "data/definitely_missing_cloud.grp")
    TestHelper.assertEquals(0, n, "文件缺失应返回 0 帧")
    draws = {}
    TestHelper.assertEquals(0, CloudLayer.draw(20, 19), "云数据缺失应静默降级为 0 绘制")
    TestHelper.assertEquals(0, #draws, "不应有任何绘制调用")
    local ok, err = pcall(CloudLayer.tick)
    TestHelper.assertTrue(ok, "tick 数据缺失时不应报错: " .. tostring(err))
    local ok2, err2 = pcall(CloudLayer.draw, 20, 19)
    TestHelper.assertTrue(ok2, "draw 数据缺失时不应报错: " .. tostring(err2))

    restoreEnv()
end

-- ------------------------------------------------------------ ⑧ 纯逻辑零引擎

function TestCloud.testFrameworkModuleHasNoEngineDetail()
    print("\n=== Test: cloud_layer.lua 零 love.* / 零 require engine-* ===")
    local function readSource(rel)
        for _, p in ipairs({ rel, "../game/" .. rel }) do
            local f = io.open(p, "r")
            if f then local s = f:read("*a"); f:close(); return s end
        end
        return nil
    end
    local src = readSource("framework/cloud_layer.lua")
    TestHelper.assertNotNil(src, "应能读到 framework/cloud_layer.lua")

    local loveHits, engineReq = 0, 0
    for line in src:gmatch("[^\r\n]+") do
        local code = line:gsub("^%s*%-%-.*$", "")
        if code:find("%f[%w_]love%.") then loveHits = loveHits + 1 end
        if code:find('require%s*%(%s*"engine') or code:find('require%s+"engine') then
            engineReq = engineReq + 1
        end
    end
    TestHelper.assertEquals(0, loveHits, "cloud_layer.lua 不得直接调 love.*")
    TestHelper.assertEquals(0, engineReq, "cloud_layer.lua 不得 require engine-*")
end

function TestCloud.runAll()
    print("\n" .. string.rep("=", 60))
    print("主地图飘云（framework/cloud_layer）子系统测试")
    print(string.rep("=", 60))

    local savedMt = getmetatable(_G)
    setmetatable(_G, nil)

    TestCloud.testDecoderEquivalenceOnRealCloudGrp()
    TestCloud.testLoadSpawns60CloudsWithValidFields()
    TestCloud.testDrawCountFormulaAndAlpha()
    TestCloud.testCloudScrollMatchesTerrain()
    TestCloud.testTickCadenceIs40ms()
    TestCloud.testRespawnOnRightEdge()
    TestCloud.testTickGatedByMMapAmi()
    TestCloud.testBakePixelParityWithMixFormula()
    TestCloud.testMissingCloudFilesAreGraceful()
    TestCloud.testFrameworkModuleHasNoEngineDetail()

    setmetatable(_G, savedMt)

    TestHelper.printSummary()
    return TestHelper.getStats().allPassed
end

return TestCloud
