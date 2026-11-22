-- test_render_batch.lua
-- framework/render_batch.lua 的单元测试（change: port-render-batching）
--
-- 守的四个坑（每个都有明确失败模式）：
--
--   ① **引擎支持时必须真的成对**：`beginBatch` 一次、`endBatch` 一次。
--      漏掉 end → 引擎批次状态跨帧泄漏 → 下一帧的绘制落进上一帧的批次里，
--      表现是「画面错位/闪烁但不报错」。这比崩难查得多。
--
--   ② **引擎不支持时必须零影响**：`wrap` 仍然执行 fn，且**不调** begin/end，
--      绘制调用序列与改造前完全一致（这是「不得破坏现有行为」的判据）。
--
--   ③ **fn 抛错时 finish 仍被调用**：用 pcall 验证。若去掉这条保证，
--      一个渲染异常就会让批次永久挂着 —— 后续所有帧都画错。
--
--   ④ **禁止嵌套**：内层 wrap 不进批次（退化为直接执行），外层批次保持有效。
--      这是契约里「显式禁止嵌套」选项的落地验证。
--
-- 另外覆盖探测缓存：不支持的引擎**只被问一次**（drawMain 每帧都会问，
-- 每帧都问一个明确不支持的引擎是纯浪费）。

local TestHelper = require("tests.test_helper")

local TestRenderBatch = {}

-- ---------------------------------------------------------------------------
-- 环境：装一个可编程的假引擎
-- ---------------------------------------------------------------------------

--- 装一个假 EngineAPI（只有 render 段，够本模块用）
--
-- @param supported boolean 引擎是否支持批处理
-- @param opts table|nil { throwOnBegin=, throwOnFinish= }
-- @return table 计数表 { begin=, end=, draws=, kinds={} }
local function installFakeEngine(supported, opts)
    opts = opts or {}
    -- **注意**：`end` 是 Lua 保留字，不能当表字段名 → 用 finished 计数
    local calls = { begin = 0, finished = 0, draws = 0, kinds = {} }

    _G.EngineAPI = {
        render = {
            beginBatch = function(kind)
                calls.begin = calls.begin + 1
                calls.kinds[#calls.kinds + 1] = kind
                if opts.throwOnBegin then error("beginBatch boom") end
                return supported and true or false
            end,
            endBatch = function()
                calls.finished = calls.finished + 1
                if opts.throwOnFinish then error("endBatch boom") end
            end,
        },
        sprite = {
            drawHandle = function() calls.draws = calls.draws + 1 return true end,
        },
    }

    -- **必须重置缓存**：本模块把探测结论缓存住了（生产路径的正确做法），
    -- 测试换了引擎就必须清缓存，否则第二条用例看到的是上一条的结论。
    package.loaded["framework.render_batch"] = nil
    local RB = require("framework.render_batch")
    return RB, calls
end

-- ---------------------------------------------------------------------------
-- ① 引擎支持时：begin 一次、end 一次、fn 执行一次
-- ---------------------------------------------------------------------------

function TestRenderBatch.testSupportedWrapsOnce()
    print("\n=== Test: 引擎支持时 wrap 只 begin/end 各一次 ===")
    local RB, calls = installFakeEngine(true)
    local EngineAPI = rawget(_G, "EngineAPI")

    local ran = 0
    RB.wrap("tile", function()
        ran = ran + 1
        -- 批次内 3 次绘制：**语义不变**，引擎可以选择攒或立即画
        EngineAPI.sprite.drawHandle({}, 1, 1, 0, nil)
        EngineAPI.sprite.drawHandle({}, 2, 2, 0, nil)
        EngineAPI.sprite.drawHandle({}, 3, 3, 0, nil)
    end)

    TestHelper.assertEquals(1, ran, "fn 应执行恰好 1 次")
    TestHelper.assertEquals(1, calls.begin, "beginBatch 应恰好 1 次（不是每次 draw 一次）")
    TestHelper.assertEquals(1, calls.finished, "endBatch 应恰好 1 次")
    TestHelper.assertEquals(3, calls.draws, "批次内 3 次 drawHandle 的语义不变（全部照画）")
    TestHelper.assertEquals("tile", calls.kinds[1], "kind 应透传给引擎（便于选策略）")
    TestHelper.assertEquals(false, RB.isActive(), "wrap 结束后不应残留 active 状态")
end

function TestRenderBatch.testSupportedIsSupportedCachesTrue()
    print("\n=== Test: 支持的引擎 isSupported 为 true 且不重复问 ===")
    local RB, calls = installFakeEngine(true)

    TestHelper.assertEquals(true, RB.isSupported(), "引擎返回 true → isSupported 应为 true")
    local afterFirst = calls.begin
    -- 连续问 5 次都不应再打扰引擎（结论已缓存）
    for _ = 1, 5 do RB.isSupported() end
    TestHelper.assertEquals(afterFirst, calls.begin,
        "探测结论必须缓存（后续 isSupported 不再调 beginBatch）")
end

-- ---------------------------------------------------------------------------
-- ② 引擎不支持时：仍执行 fn，且不调 begin/end（降级路径逐字节一致）
-- ---------------------------------------------------------------------------

function TestRenderBatch.testUnsupportedStillRunsFn()
    print("\n=== Test: 引擎不支持时 wrap 仍执行 fn，且不调 begin/end ===")
    local RB, calls = installFakeEngine(false)
    local EngineAPI = rawget(_G, "EngineAPI")

    local ran = 0
    local ret = "sentinel"
    RB.wrap("tile", function()
        ran = ran + 1
        EngineAPI.sprite.drawHandle({}, 1, 1, 0, nil)
        EngineAPI.sprite.drawHandle({}, 2, 2, 0, nil)
        EngineAPI.sprite.drawHandle({}, 3, 3, 0, nil)
        return ret
    end)

    TestHelper.assertEquals(1, ran, "引擎不支持时 fn 仍必须执行（降级，不是跳过）")
    TestHelper.assertEquals(3, calls.draws, "3 次 drawHandle 全部照画（顺序与改造前一致）")
    TestHelper.assertEquals(0, calls.finished,
        "引擎不支持时**不得**调 endBatch（没开过批次，不该去关）")
    TestHelper.assertEquals(ret, ret, "降级路径应返回 fn 的返回值")

    -- 探测缓存：第一次问过之后结论是 false，后续 wrap 不再问引擎
    local beginAfterFirst = calls.begin
    RB.wrap("tile", function() end)
    TestHelper.assertEquals(beginAfterFirst, calls.begin,
        "不支持时后续 wrap 不应再问引擎 beginBatch（drawMain 每帧都会调 → 纯浪费）")
end

function TestRenderBatch.testUnsupportedIsSupportedFalse()
    print("\n=== Test: 不支持的引擎 isSupported 为 false ===")
    local RB = installFakeEngine(false)
    TestHelper.assertEquals(false, RB.isSupported(), "引擎返回 false → isSupported 应为 false")
end

function TestRenderBatch.testNoContractAtAll()
    print("\n=== Test: 引擎完全没有批处理契约时也能降级（老引擎/未升级桩）===")
    -- 这模拟「没有 port-render-batching 之前实现的引擎」：render 段没有这两个函数。
    _G.EngineAPI = {
        render = {},
        sprite = { drawHandle = function() return true end },
    }
    package.loaded["framework.render_batch"] = nil
    local RB = require("framework.render_batch")

    local ran = 0
    local ok, err = pcall(function()
        RB.wrap("tile", function() ran = ran + 1 end)
    end)
    TestHelper.assertEquals(true, ok, "缺契约时不得抛错（降级即可）：" .. tostring(err))
    TestHelper.assertEquals(1, ran, "缺契约时仍应执行 fn")
    TestHelper.assertEquals(false, RB.isSupported(), "缺契约 → isSupported 为 false")
end

-- ---------------------------------------------------------------------------
-- ③ fn 抛错时 finish 仍被调用
-- ---------------------------------------------------------------------------

function TestRenderBatch.testFinishOnError()
    print("\n=== Test: wrap 内 fn 抛错时 finish 仍被调用（批次不泄漏）===")
    local RB, calls = installFakeEngine(true)

    local ok, err = pcall(RB.wrap, "tile", function()
        error("draw boom")
    end)

    TestHelper.assertEquals(false, ok, "fn 抛错时 wrap 必须把错误重抛（不吞错）")
    TestHelper.assertNotNil(tostring(err):find("draw boom"),
        "重抛的错误应是原错误信息，实测: " .. tostring(err))
    TestHelper.assertEquals(1, calls.finished,
        "**关键**：即使 fn 抛错也必须调 endBatch（否则批次状态跨帧泄漏）")
    TestHelper.assertEquals(false, RB.isActive(), "抛错后 active 必须已清（下一帧能重新开始）")

    -- 抛错之后同一个 RenderBatch 还能正常开新批次（状态真的干净了）
    local ran = 0
    RB.wrap("tile", function() ran = ran + 1 end)
    TestHelper.assertEquals(1, ran, "抛错后再 wrap 应正常工作（状态已恢复）")
    TestHelper.assertEquals(2, calls.begin, "第二次 wrap 应重新 begin")
    TestHelper.assertEquals(2, calls.finished, "第二次 wrap 应重新 end")
end

-- ---------------------------------------------------------------------------
-- ④ 禁止嵌套
-- ---------------------------------------------------------------------------

function TestRenderBatch.testNestedRejected()
    print("\n=== Test: 嵌套 wrap 被拒绝（内层直接执行，外层批次保持有效）===")
    local RB, calls = installFakeEngine(true)

    local innerRan = 0
    RB.wrap("tile", function()
        -- 手动 begin 也应被拒绝（不只 wrap 路径）
        local innerEntered = RB.begin("text")
        TestHelper.assertEquals(false, innerEntered, "嵌套时内层 begin 应返回 false")
        TestHelper.assertEquals(true, RB.isActive(), "内层 begin 被拒后外层批次仍有效")

        -- 内层 wrap 同样不进批次、但仍执行 fn
        RB.wrap("text", function() innerRan = innerRan + 1 end)
        TestHelper.assertEquals(true, RB.isActive(), "内层 wrap 结束后外层批次仍有效")
    end)

    TestHelper.assertEquals(1, innerRan, "内层 fn 仍必须执行（只是不进批次）")
    TestHelper.assertEquals(1, calls.begin, "嵌套不得让引擎收到第二次 beginBatch")
    TestHelper.assertEquals(1, calls.finished, "嵌套不得让引擎收到第二次 endBatch")
end

-- ---------------------------------------------------------------------------
-- ⑤ 引擎实现抛错时降级（批处理是纯优化，绝不让渲染链断）
-- ---------------------------------------------------------------------------

function TestRenderBatch.testBeginThrowDegrades()
    print("\n=== Test: 引擎 beginBatch 抛错时降级为逐次绘制 ===")
    local RB, calls = installFakeEngine(true, { throwOnBegin = true })

    local ran = 0
    local ok, err = pcall(function()
        RB.wrap("tile", function() ran = ran + 1 end)
    end)

    TestHelper.assertEquals(true, ok, "引擎 beginBatch 抛错不得让调用方崩：" .. tostring(err))
    TestHelper.assertEquals(1, ran, "降级后 fn 仍应执行")
    TestHelper.assertEquals(0, calls.finished, "没进批次 → 不应调 endBatch")
    TestHelper.assertEquals(false, RB.isSupported(), "抛错应被记为「不支持」（之后不再尝试）")
end

-- ---------------------------------------------------------------------------
-- ⑥ 参数错误不毁掉整帧
-- ---------------------------------------------------------------------------

function TestRenderBatch.testNonFunctionFn()
    print("\n=== Test: fn 不是函数时不抛错（绘制路径上抛错会毁整帧）===")
    local RB, calls = installFakeEngine(true)
    local ok, ret = pcall(RB.wrap, "tile", nil)
    TestHelper.assertEquals(true, ok, "fn 为 nil 时不得抛错")
    TestHelper.assertEquals(nil, ret, "应返回 nil")
    TestHelper.assertEquals(0, calls.begin, "参数无效时不应开批次")
end

-- ---------------------------------------------------------------------------
-- ⑦ 集成：drawMain 在支持的引擎上确实开批次，且绘制序列不变
-- ---------------------------------------------------------------------------

function TestRenderBatch.testDrawMainUsesBatch()
    print("\n=== Test: drawMain 在支持的引擎上开批次（且在绘制前后各一次）===")
    -- 用最小地图环境 + 假引擎，断言：
    --   ① beginBatch 恰好 1 次、endBatch 恰好 1 次（不是每格一次）
    --   ② **所有 drawHandle 都落在 begin 与 end 之间**（顺序即视觉正确性）
    local tiles = {}
    for x = 0, 39 do
        for y = 0, 39 do
            for layer = 0, 4 do tiles[x .. "," .. y .. "," .. layer] = 0 end
        end
    end

    local order = {}
    _G.CONFIG = {
        Width = 1024, Height = 768, XScale = 18, YScale = 9,
        MMapAddX = 0, MMapAddY = 0, SMapAddX = 0, SMapAddY = 0,
        WMapAddX = 0, WMapAddY = 0,
    }
    _G.CC = { MWidth = 40, MHeight = 40 }
    _G.EngineAPI = {
        render = {
            beginBatch = function(kind)
                order[#order + 1] = "begin:" .. tostring(kind)
                return true
            end,
            endBatch = function() order[#order + 1] = "end" end,
            getClip = function() return { x = 0, y = 0, w = 1024, h = 768 } end,
            setClip = function() end,
            fillRect = function() end,
        },
        map = {
            getTile = function(x, y, layer)
                return tiles[x .. "," .. y .. "," .. layer] or 0
            end,
            setTile = function(x, y, layer, v) tiles[x .. "," .. y .. "," .. layer] = v end,
            drawClouds = function() end,
        },
        sprite = {
            drawHandle = function() order[#order + 1] = "draw" return true end,
        },
    }

    package.loaded["framework.sprite_atlas"] = nil
    local SA = require("framework.sprite_atlas")
    SA.clear()
    -- 注入假 atlas 并**预热 handle 缓存**：getHandle 会先查 cache，
    -- 未命中才去解码（假 atlas 没有真实字节 → 解不出 → 不画）。
    -- 预热后 drawMain 才会真的走到 drawHandle，才能断言「绘制都落在批次内」。
    local fakeAtlas = {
        frameCount = 100, cache = {}, meta = {},
        grpBytes = "", offsets = {}, palette = {}, usage = "map",
    }
    for slot = 1, 100 do
        fakeAtlas.cache[slot] = { img = true, xoff = 0, yoff = 0 }
        fakeAtlas.meta[slot] = { w = 16, h = 16, xoff = 0, yoff = 0 }
    end
    if SA._injectForTest then
        SA._injectForTest(0, fakeAtlas)
    end

    -- 地图瓦片全为 0 → drawMain 不会真的 drawHandle。
    -- 为了让断言有意义，给几个格子填非零值（一层 + 建筑层）。
    -- 建筑层由 buildingSort 从 layer 2/3/4 推导，这里造一个建筑。
    tiles["20,20,0"] = 1      -- 地面
    tiles["20,20,1"] = 2      -- 地面二层
    tiles["10,10,2"] = 3      -- 建筑贴图
    tiles["10,10,3"] = 10     -- 建筑 x
    tiles["10,10,4"] = 10     -- 建筑 y

    package.loaded["framework.render_batch"] = nil
    package.loaded["framework.map_render"] = nil
    local MR = require("framework.map_render")
    MR.reset()

    local ok, err = pcall(MR.drawMain, 10, 10, 500)
    TestHelper.assertEquals(true, ok, "drawMain 不应抛错：" .. tostring(err))

    -- 统计顺序
    local begins, ends, draws = 0, 0, 0
    local firstBeginAt, lastEndAt = nil, nil
    for i, ev in ipairs(order) do
        if ev:match("^begin:") then
            begins = begins + 1
            if not firstBeginAt then firstBeginAt = i end
        elseif ev == "end" then
            ends = ends + 1
            lastEndAt = i
        elseif ev == "draw" then
            draws = draws + 1
        end
    end

    TestHelper.assertEquals(1, begins, "drawMain 每帧应只开 **1** 个批次（不是每格一次）")
    TestHelper.assertEquals(1, ends, "对应的 endBatch 应恰好 1 次")
    TestHelper.assertEquals(true, draws > 0, "应有实际绘制（实测 " .. draws .. " 次）")
    TestHelper.assertNotNil(firstBeginAt, "应有 begin 事件")
    TestHelper.assertEquals(1, firstBeginAt, "begin 必须是第一个事件（不能先画后开批次）")
    TestHelper.assertEquals(#order, lastEndAt, "end 必须是最后一个事件（所有绘制都在批次内）")
    TestHelper.assertEquals("begin:tile", order[1], "drawMain 的 kind 应为 tile")

    -- 清理：恢复 map_render 以免污染后续测试
    package.loaded["framework.map_render"] = nil
end

function TestRenderBatch.runAll()
    print("\n" .. string.rep("=", 60))
    print("绘制批处理薄层（port-render-batching）")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    -- **保存现场**：本文件会临时替换 _G.EngineAPI / CONFIG / CC。
    -- 结尾必须**恢复原值**而不是设成 nil —— 设 nil 会让后续模块看到空环境
    -- （表现为「全量跑失败、单跑通过」，本项目踩过多次）。
    local saved = {
        EngineAPI = rawget(_G, "EngineAPI"),
        CONFIG    = rawget(_G, "CONFIG"),
        CC        = rawget(_G, "CC"),
    }

    TestRenderBatch.testSupportedWrapsOnce()
    TestRenderBatch.testSupportedIsSupportedCachesTrue()
    TestRenderBatch.testUnsupportedStillRunsFn()
    TestRenderBatch.testUnsupportedIsSupportedFalse()
    TestRenderBatch.testNoContractAtAll()
    TestRenderBatch.testFinishOnError()
    TestRenderBatch.testNestedRejected()
    TestRenderBatch.testBeginThrowDegrades()
    TestRenderBatch.testNonFunctionFn()
    TestRenderBatch.testDrawMainUsesBatch()

    -- 恢复现场（见 runAll 开头的 saved）
    rawset(_G, "EngineAPI", saved.EngineAPI)
    rawset(_G, "CONFIG", saved.CONFIG)
    rawset(_G, "CC", saved.CC)
    package.loaded["framework.render_batch"] = nil
    package.loaded["framework.map_render"] = nil
    package.loaded["framework.sprite_atlas"] = nil

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_render_batch.lua$") then
    TestRenderBatch.runAll()
end

return TestRenderBatch
