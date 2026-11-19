-- test_sprite_anim.lua
-- 精灵动画播放器测试（change: port-sprite-animation）
--
-- 守的坑（design.md ADR-PORT-013..018）：
--   ① 播放器零引擎依赖（不 require engine-*，不调 love.*）
--   ② frameId 是不透明整数，播放器**不做算术**
--   ③ update(dt) 是唯一时间源（无"移动一格加一帧"旁路）
--   ④ loop / once / pingpong 三种模式的边界行为
--   ⑤ onComplete 只触发一次
--   ⑥ 多个句柄互不干扰

local TestHelper = require("tests.test_helper")
local TestSpriteAnim = {}

local function fresh()
    package.loaded["framework.sprite_anim"] = nil
    package.loaded["framework.animation_defs"] = nil
    local SA = require("framework.sprite_anim")
    local AD = require("framework.animation_defs")
    SA.clearSequences()
    SA.clearHandles()
    return SA, AD
end

-- ------------------------------------------------------------ 零引擎依赖

function TestSpriteAnim.testNoEngineDependency()
    print("\n=== Test: 播放器零引擎依赖 ===")
    local function readSrc(rel)
        for _, p in ipairs({ rel, "game/" .. rel }) do
            local f = io.open(p, "rb")
            if f then local c = f:read("*a"); f:close(); return c end
        end
        return nil
    end

    for _, name in ipairs({ "framework/sprite_anim.lua", "framework/animation_defs.lua" }) do
        local src = readSrc(name)
        TestHelper.assertNotNil(src, "应能读到 " .. name)
        local bad = 0
        for line in src:gmatch("[^\r\n]+") do
            local code = line:gsub("^%s*%-%-.*$", "")
            if code:match("love%.") and not code:match("%-%-") then bad = bad + 1 end
        end
        TestHelper.assertEquals(0, bad, name .. " 代码行不得调 love.*（实测 " .. bad .. "）")
        TestHelper.assertEquals(nil, src:match('require%("engine'),
            name .. " 不得 require engine-*")
    end
end

function TestSpriteAnim.testNoFrameIdArithmetic()
    print("\n=== Test: 播放器不对 frameId 做算术 ===")
    local f = io.open("framework/sprite_anim.lua", "rb")
    if not f then f = io.open("game/framework/sprite_anim.lua", "rb") end
    TestHelper.assertNotNil(f, "应能读到 sprite_anim.lua")
    local src = f:read("*a")
    f:close()

    local bad = 0
    for line in src:gmatch("[^\r\n]+") do
        local code = line:gsub("^%s*%-%-.*$", "")
        if code:find("frameId") and (code:find("frameId +") or code:find("frameId -")
           or code:find("frameId *") or code:find("frameId %")) then
            bad = bad + 1
        end
    end
    TestHelper.assertEquals(0, bad,
        "frameId 不得参与算术（实测 " .. bad .. " 处，ADR-PORT-015）")
end

-- ------------------------------------------------------------ 序列定义

function TestSpriteAnim.testDefineAndList()
    print("\n=== Test: 定义与列出序列 ===")
    local SA = fresh()
    TestHelper.assertTrue(
        SA.defineSequence("walk", { frames = {10, 11, 12}, fps = 10 }),
        "应能定义序列")
    local ids = SA.listSequences()
    TestHelper.assertEquals(1, #ids, "应有 1 个序列")
    TestHelper.assertEquals("walk", ids[1], "序列 id 应为 walk")
end

function TestSpriteAnim.testDefineRejectsBadSpec()
    print("\n=== Test: 非法定义被拒绝 ===")
    local SA = fresh()
    TestHelper.assertEquals(false, SA.defineSequence("", { frames = {1} }), "空 id 拒绝")
    TestHelper.assertEquals(false, SA.defineSequence("x", { frames = {} }), "空帧数组拒绝")
    TestHelper.assertEquals(false, SA.defineSequence("x", nil), "nil spec 拒绝")
end

function TestSpriteAnim.testDefaultFps()
    print("\n=== Test: 默认 fps = 12 ===")
    local SA = fresh()
    SA.defineSequence("s", { frames = {1, 2} })
    local seq = SA.getSequence("s")
    TestHelper.assertEquals(12, seq.fps, "未指定 fps 时应为 12")
end

-- ------------------------------------------------------------ loop 模式

function TestSpriteAnim.testLoopAdvancesAndWraps()
    print("\n=== Test: loop 模式循环 ===")
    local SA = fresh()
    SA.defineSequence("s", { frames = {100, 101, 102}, fps = 10, mode = "loop" })
    local h = SA.createHandle()
    SA.play(h, "s")

    TestHelper.assertEquals(100, SA.getFrameId(h), "起始帧应为第一帧")
    SA.update(0.1)   -- 恰好一帧时长
    TestHelper.assertEquals(101, SA.getFrameId(h), "推进一帧")
    SA.update(0.1)
    TestHelper.assertEquals(102, SA.getFrameId(h), "再推进一帧")
    SA.update(0.1)
    TestHelper.assertEquals(100, SA.getFrameId(h), "回绕到第一帧")
end

function TestSpriteAnim.testLoopNeverCompletes()
    print("\n=== Test: loop 模式永不回调 ===")
    local SA = fresh()
    SA.defineSequence("s", { frames = {1, 2}, fps = 10, mode = "loop" })
    local h = SA.createHandle()
    local called = 0
    SA.play(h, "s", { onComplete = function() called = called + 1 end })

    for _ = 1, 20 do SA.update(0.1) end
    TestHelper.assertEquals(0, called, "loop 模式 onComplete 不应被调用")
    TestHelper.assertTrue(SA.isPlaying(h), "loop 模式应一直播放")
end

-- ------------------------------------------------------------ once 模式

function TestSpriteAnim.testOnceStopsAndCompletes()
    print("\n=== Test: once 模式播完即停 ===")
    local SA = fresh()
    SA.defineSequence("s", { frames = {10, 11, 12}, fps = 10, mode = "once" })
    local h = SA.createHandle()
    local called = 0
    SA.play(h, "s", { onComplete = function() called = called + 1 end })

    TestHelper.assertEquals(10, SA.getFrameId(h), "起始帧")
    SA.update(0.1)
    TestHelper.assertEquals(11, SA.getFrameId(h), "第 2 帧")
    SA.update(0.1)
    TestHelper.assertEquals(12, SA.getFrameId(h), "第 3 帧")
    SA.update(0.1)
    TestHelper.assertEquals(12, SA.getFrameId(h), "停在第 3 帧（不越界）")
    TestHelper.assertEquals(false, SA.isPlaying(h), "once 播完应停止")
    TestHelper.assertEquals(1, called, "onComplete 应触发 1 次")
end

function TestSpriteAnim.testOnceCallbackOnlyOnce()
    print("\n=== Test: once 的 onComplete 只触发一次 ===")
    local SA = fresh()
    SA.defineSequence("s", { frames = {1, 2}, fps = 10, mode = "once" })
    local h = SA.createHandle()
    local called = 0
    SA.play(h, "s", { onComplete = function() called = called + 1 end })

    -- 多推进 10 帧时长（远超序列长度）
    for _ = 1, 10 do SA.update(0.1) end
    TestHelper.assertEquals(1, called, "onComplete 必须只触发 1 次，实测 " .. called)
end

-- ------------------------------------------------------------ pingpong

function TestSpriteAnim.testPingpongGoesBackAndForth()
    print("\n=== Test: pingpong 往复 ===")
    local SA = fresh()
    SA.defineSequence("s", { frames = {1, 2, 3}, fps = 10, mode = "pingpong" })
    local h = SA.createHandle()
    SA.play(h, "s")

    TestHelper.assertEquals(1, SA.getFrameId(h), "起始 1")
    SA.update(0.1); TestHelper.assertEquals(2, SA.getFrameId(h), "→ 2")
    SA.update(0.1); TestHelper.assertEquals(3, SA.getFrameId(h), "→ 3")
    SA.update(0.1); TestHelper.assertEquals(2, SA.getFrameId(h), "→ 2（回退）")
    SA.update(0.1); TestHelper.assertEquals(1, SA.getFrameId(h), "→ 1（回到底）")
end

function TestSpriteAnim.testPingpongSingleFrame()
    print("\n=== Test: pingpong 单帧序列不崩 ===")
    local SA = fresh()
    SA.defineSequence("s", { frames = {7}, fps = 10, mode = "pingpong" })
    local h = SA.createHandle()
    SA.play(h, "s")
    SA.update(0.1)
    TestHelper.assertEquals(7, SA.getFrameId(h), "单帧序列应停在唯一帧")
    TestHelper.assertEquals(false, SA.isPlaying(h), "单帧 pingpong 应立即结束")
end

-- ------------------------------------------------------------ dt 推进

function TestSpriteAnim.testLargeDtSkipsFrames()
    print("\n=== Test: dt 大于一帧时长时跳帧（不死循环）===")
    local SA = fresh()
    SA.defineSequence("s", { frames = {1, 2, 3, 4}, fps = 10, mode = "loop" })
    local h = SA.createHandle()
    SA.play(h, "s")

    -- 0.3 秒 = 3 帧时长 → 应推进 3 帧
    SA.update(0.3)
    local idx = SA.getFrameIndex(h)
    TestHelper.assertEquals(4, SA.getFrameIndex(h), "0.3s 应推进 3 帧（1→4）")
end

function TestSpriteAnim.testZeroDtNoAdvance()
    print("\n=== Test: dt <= 0 不推进 ===")
    local SA = fresh()
    SA.defineSequence("s", { frames = {1, 2}, fps = 10 })
    local h = SA.createHandle()
    SA.play(h, "s")

    SA.update(0)
    TestHelper.assertEquals(1, SA.getFrameIndex(h), "dt=0 不推进")
    SA.update(-0.1)
    TestHelper.assertEquals(1, SA.getFrameIndex(h), "dt<0 不推进")
end

function TestSpriteAnim.testTimeDrivenNotStepDriven()
    print("\n=== Test: 时间驱动（不是「走一格加一帧」）===")
    local SA = fresh()
    SA.defineSequence("s", { frames = {1, 2, 3}, fps = 10, mode = "loop" })
    local h = SA.createHandle()
    SA.play(h, "s")

    -- 无需"移动一格"，只推进时间，帧就前进
    SA.update(0.1)
    TestHelper.assertEquals(2, SA.getFrameId(h),
        "只推进时间就该换帧（证明是时间驱动，ADR-PORT-017）")
end

-- ------------------------------------------------------------ 多句柄

function TestSpriteAnim.testMultipleHandlesIndependent()
    print("\n=== Test: 多个句柄互不干扰 ===")
    local SA = fresh()
    SA.defineSequence("a", { frames = {100, 101}, fps = 10 })
    SA.defineSequence("b", { frames = {200, 201, 202}, fps = 10 })

    local h1 = SA.createHandle()
    local h2 = SA.createHandle()
    TestHelper.assertTrue(h1 ~= h2, "两个句柄 id 应不同")

    SA.play(h1, "a")
    SA.play(h2, "b")
    TestHelper.assertEquals(100, SA.getFrameId(h1), "h1 起始帧")
    TestHelper.assertEquals(200, SA.getFrameId(h2), "h2 起始帧")

    SA.update(0.1)
    TestHelper.assertEquals(101, SA.getFrameId(h1), "h1 各自推进")
    TestHelper.assertEquals(201, SA.getFrameId(h2), "h2 各自推进")
end

function TestSpriteAnim.testStopAndIsPlaying()
    print("\n=== Test: stop / isPlaying ===")
    local SA = fresh()
    SA.defineSequence("s", { frames = {1, 2, 3}, fps = 10 })
    local h = SA.createHandle()
    SA.play(h, "s")
    TestHelper.assertTrue(SA.isPlaying(h), "play 后应在播")
    SA.stop(h)
    TestHelper.assertEquals(false, SA.isPlaying(h), "stop 后应停止")
    SA.update(0.1)
    TestHelper.assertEquals(1, SA.getFrameIndex(h), "停止后不推进")
end

-- ------------------------------------------------------------ 未定义序列

function TestSpriteAnim.testPlayUnknownSequenceFails()
    print("\n=== Test: 播放未定义序列返回 false ===")
    local SA = fresh()
    local h = SA.createHandle()
    TestHelper.assertEquals(false, SA.play(h, "nope"), "未定义序列应拒绝")
    TestHelper.assertEquals(nil, SA.getFrameId(h), "未播放时 frameId 为 nil")
end

function TestSpriteAnim.testGetFrameIdNilForBadHandle()
    print("\n=== Test: 非法句柄不崩 ===")
    local SA = fresh()
    TestHelper.assertEquals(nil, SA.getFrameId(9999), "不存在的句柄返回 nil")
    TestHelper.assertEquals(nil, SA.getFrameId(nil), "nil 句柄返回 nil")
    TestHelper.assertEquals(false, SA.isPlaying(9999), "不存在的句柄 isPlaying=false")
    TestHelper.assertEquals(false, SA.stop(9999), "不存在的句柄 stop=false")
end

-- ------------------------------------------------------------ animation_defs

function TestSpriteAnim.testWalkFramesMatchGetMyPic()
    print("\n=== Test: 行走帧号与原 GetMyPic 公式一致 ===")
    local SA, AD = fresh()

    -- 原版公式：n = CC.MyStartPic + 方向*7 + MyCurrentPic（行走用 1..6）
    local startPic = 100
    for dir = 0, 3 do
        local frames = AD.walkFrames(startPic, dir)
        TestHelper.assertEquals(6, #frames, "方向 " .. dir .. " 应有 6 个行走帧")
        for i = 1, 6 do
            local expect = startPic + dir * 7 + i
            TestHelper.assertEquals(expect, frames[i],
                string.format("方向 %d 第 %d 帧应为 %d", dir, i, expect))
        end
    end
end

function TestSpriteAnim.testBoatFramesMatchGetMyPic()
    print("\n=== Test: 乘船帧号与原公式一致 ===")
    local SA, AD = fresh()
    local boatStart = 200
    for dir = 0, 3 do
        local frames = AD.boatFrames(boatStart, dir)
        TestHelper.assertEquals(4, #frames, "方向 " .. dir .. " 应有 4 个乘船帧")
        for i = 1, 4 do
            local expect = boatStart + dir * 4 + (i - 1)
            TestHelper.assertEquals(expect, frames[i],
                string.format("乘船 方向 %d 第 %d 帧应为 %d", dir, i, expect))
        end
    end
end

function TestSpriteAnim.testStandFrameIsOffsetZero()
    print("\n=== Test: 站立帧 = 组的第 0 帧 ===")
    local SA, AD = fresh()
    local startPic = 100
    for dir = 0, 3 do
        TestHelper.assertEquals(startPic + dir * 7, AD.standFrame(startPic, dir),
            "方向 " .. dir .. " 站立帧应为 startPic + dir*7")
    end
end

function TestSpriteAnim.testDefineAllCreates12Sequences()
    print("\n=== Test: defineAll 生成 12 个序列（4 方向 × 3 类）===")
    local SA, AD = fresh()
    local n = AD.defineAll({ myStartPic = 100, boatStartPic = 200 })
    TestHelper.assertEquals(12, n, "应定义 12 个序列（走/站/船 × 4 方向）")

    local ids = SA.listSequences()
    TestHelper.assertEquals(12, #ids, "序列表应有 12 项")
end

function TestSpriteAnim.testDefineAllRejectsMissingConst()
    print("\n=== Test: 缺 CC 常量时不定义 ===")
    local SA, AD = fresh()
    TestHelper.assertEquals(0, AD.defineAll({}), "缺常量应返回 0")
    TestHelper.assertEquals(0, AD.defineAll({ myStartPic = 100 }), "缺 boatStartPic 应返回 0")
    TestHelper.assertEquals(0, #SA.listSequences(), "不应定义任何序列")
end

function TestSpriteAnim.testSequenceIdSelection()
    print("\n=== Test: sequenceId 选择逻辑 ===")
    local SA, AD = fresh()
    TestHelper.assertEquals("person.walk.down", AD.sequenceId(0, false, true),
        "方向 0 行走 → walk.down")
    TestHelper.assertEquals("person.stand.down", AD.sequenceId(0, false, false),
        "方向 0 站立 → stand.down")
    TestHelper.assertEquals("person.boat.up", AD.sequenceId(1, true, true),
        "方向 1 乘船 → boat.up")
    TestHelper.assertEquals(nil, AD.sequenceId(9, false, true), "非法方向返回 nil")
end

function TestSpriteAnim.testEndToEndPlayback()
    print("\n=== Test: 端到端播放（定义 → 播放 → 推进 → 帧号）===")
    local SA, AD = fresh()
    AD.defineAll({ myStartPic = 100, boatStartPic = 200, walkFps = 15 })

    local h = SA.createHandle()
    TestHelper.assertTrue(SA.play(h, "person.walk.right"), "应能播放 right 方向行走")

    -- 方向 3 行走 = 100 + 3*7 + 1..6 = 122..127
    TestHelper.assertEquals(122, SA.getFrameId(h), "起始帧应为 122")
    SA.update(1 / 15 + 0.001)
    TestHelper.assertEquals(123, SA.getFrameId(h), "推进后应为 123")
    SA.update(1 / 15 + 0.001)
    TestHelper.assertEquals(124, SA.getFrameId(h), "再推进应为 124")
end

-- ------------------------------------------------------------ 套件入口

function TestSpriteAnim.runAll()
    print("\n" .. string.rep("=", 60))
    print("精灵动画播放器测试（ADR-PORT-013..018）")
    print(string.rep("=", 60))
    TestHelper.setup()
    TestHelper.resetCounts()

    TestSpriteAnim.testNoEngineDependency()
    TestSpriteAnim.testNoFrameIdArithmetic()

    TestSpriteAnim.testDefineAndList()
    TestSpriteAnim.testDefineRejectsBadSpec()
    TestSpriteAnim.testDefaultFps()

    TestSpriteAnim.testLoopAdvancesAndWraps()
    TestSpriteAnim.testLoopNeverCompletes()

    TestSpriteAnim.testOnceStopsAndCompletes()
    TestSpriteAnim.testOnceCallbackOnlyOnce()

    TestSpriteAnim.testPingpongGoesBackAndForth()
    TestSpriteAnim.testPingpongSingleFrame()

    TestSpriteAnim.testLargeDtSkipsFrames()
    TestSpriteAnim.testZeroDtNoAdvance()
    TestSpriteAnim.testTimeDrivenNotStepDriven()

    TestSpriteAnim.testMultipleHandlesIndependent()
    TestSpriteAnim.testStopAndIsPlaying()

    TestSpriteAnim.testPlayUnknownSequenceFails()
    TestSpriteAnim.testGetFrameIdNilForBadHandle()

    TestSpriteAnim.testWalkFramesMatchGetMyPic()
    TestSpriteAnim.testBoatFramesMatchGetMyPic()
    TestSpriteAnim.testStandFrameIsOffsetZero()
    TestSpriteAnim.testDefineAllCreates12Sequences()
    TestSpriteAnim.testDefineAllRejectsMissingConst()
    TestSpriteAnim.testSequenceIdSelection()
    TestSpriteAnim.testEndToEndPlayback()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_sprite_anim.lua$") then
    TestSpriteAnim.runAll()
end

return TestSpriteAnim
