-- test_nil_safety.lua
-- 注入点返回 nil 时的 nil 安全（change: port-nil-safety）
--
-- 守的坑（实测复现过）：
--   `GameHooks.getMyPic()` **合法地**返回 nil（表示「没有注入实现」）。
--   但直接 `JY.MyPic = GameHooks.getMyPic()` 会让下游 `mypic * 2` 崩：
--
--     test_auto_move.lua:475: attempt to compare number with nil
--
--   而全量跑不暴露 —— 因为 `mod_boot` 先跑、注册了 hook。
--   这类「只在特定执行顺序下炸」的缺陷最难查，所以：
--     ① 框架侧收敛到 `GameHooks.getMyPicOr(fallback)`
--     ② 断言所有「赋值到 JY.MyPic / 传给 map_render」的调用点都用它
--
--   同族还有 `JY.CurrentD >= 0` 在 CurrentD 为 nil 时的比较崩溃
--   （既有代码里有两处这么写，其中一处已修、另一处没修 —— 本次补齐）。

local TestHelper = require("tests.test_helper")
local TestNilSafety = {}

local function readSource(rel)
    for _, p in ipairs({ rel, "../game/" .. rel }) do
        local f = io.open(p, "r")
        if f then local s = f:read("*a"); f:close(); return s end
    end
    return nil
end

local function stripComments(src)
    src = src:gsub("%-%-%[%[.-%]%]%]", "")
    src = src:gsub("%-%-[^\n]*", "")
    return src
end

-- ------------------------------------------------------------ ① getMyPicOr 行为

function TestNilSafety.testGetMyPicOrBehavior()
    print("\n=== Test: getMyPicOr 在 hook 未注册/注册后都返回 number ===")
    local GH = require("framework.game_hooks")
    GH.clear()

    -- 未注册：返回 fallback
    TestHelper.assertEquals(2494, GH.getMyPicOr(2494),
        "未注册时 getMyPicOr 应返回 fallback")
    TestHelper.assertEquals(nil, GH.getMyPicOr(nil),
        "fallback 也是 nil 时返回 nil（不编造数字）")

    -- 原函数仍保持「返回 nil」的语义（向后兼容，sprite_anim 测试依赖它）
    TestHelper.assertEquals(nil, GH.getMyPic(),
        "getMyPic 未注册时仍返回 nil（不改既有契约）")

    -- 注册后：返回注入值
    GH.register({ getMyPic = function() return 2501 end })
    TestHelper.assertEquals(2501, GH.getMyPicOr(2494),
        "已注册时应返回注入值，而不是 fallback")
    GH.clear()
end

-- ------------------------------------------------------------ ② 无 script 全局依赖

function TestNilSafety.testFrameworkDoesNotReadScriptGetMyPic()
    print("\n=== Test: framework 里零 `GameHooks.getMyPic()` 直接赋值 ===")
    for _, f in ipairs({ "framework/game_states.lua", "framework/jymain_adapter.lua",
                         "framework/interact.lua" }) do
        local src = readSource(f)
        TestHelper.assertNotNil(src, f .. " 应可读")
        local code = stripComments(src)
        -- 不允许「直接把可能为 nil 的返回值赋给 JY.MyPic」
        TestHelper.assertNil(code:find("JY.MyPic%s*=%s*GameHooks.getMyPic%(%)"),
            f .. " 不得写 JY.MyPic = GameHooks.getMyPic()（可能是 nil → 下游崩）")
        -- 也不允许直接传给绘制函数
        TestHelper.assertNil(code:find("drawMain%([^)]*GameHooks%.getMyPic%(%)"),
            f .. " 不得把 getMyPic() 直接传给 drawMain（nil 会进 mypic*2）")
    end
end

-- ------------------------------------------------------------ ③ CurrentD 的 nil 比较

function TestNilSafety.testNoUnguardedCurrentDCompare()
    print("\n=== Test: `JY.CurrentD >= 0` 必须有 nil 守卫 ===")
    -- 这个比较在 CurrentD 为 nil 时抛 "attempt to compare number with nil"
    -- （Lua 5.1 报 "attempt to compare number with nil"）
    local nilCompareWouldCrash = pcall(function()
        local JY = {}
        return JY.CurrentD >= 0
    end)
    TestHelper.assertEquals(false, nilCompareWouldCrash,
        "负向对照：未守卫的 `JY.CurrentD >= 0` 确实会抛错")

    for _, f in ipairs({ "framework/game_states.lua", "framework/auto_move.lua" }) do
        local src = readSource(f)
        TestHelper.assertNotNil(src, f .. " 应可读")
        local code = stripComments(src)
        -- 允许的形态只有两种：
        --   JY.CurrentD ~= nil and JY.CurrentD >= 0
        --   JY.CurrentD and JY.CurrentD >= 0
        local bad = 0
        for line in code:gmatch("[^\n]+") do
            if line:find("CurrentD%s*>=%s*0") then
                local guarded = line:find("CurrentD%s*~=%s*nil")
                             or line:find("JY%.CurrentD%s+and")
                             or line:find("_eventRunning")
                if not guarded then bad = bad + 1 end
            end
        end
        TestHelper.assertEquals(0, bad,
            f .. " 有 " .. bad .. " 处未守卫的 CurrentD >= 0")
    end
end

-- ------------------------------------------------------------ ④ 测试套件自洽

function TestNilSafety.testAutoMoveSuiteRegistersHooks()
    print("\n=== Test: test_auto_move 自己注册 GameHooks（单模块可跑）===")
    local src = readSource("tests/unit/test_auto_move.lua")
    TestHelper.assertNotNil(src, "应能读到 test_auto_move.lua")
    TestHelper.assertNotNil(src:find("GameHooks.register", 1, true),
        "setupMoveEnv 应注册 GameHooks（否则单模块跑必崩）")
    TestHelper.assertNotNil(src:find("GameHooks", 1, true) and
        src:find("clear()", 1, true),
        "restoreMoveEnv 应 clear hook（避免泄漏到后续套件）")
end

-- ------------------------------------------------------------ ⑤ 负向对照

function TestNilSafety.testOldPatternWouldBreak()
    print("\n=== Test: 负向对照 —— 旧写法确实会崩 ===")
    local GH = require("framework.game_hooks")
    GH.clear()

    -- 旧写法：JY.MyPic = getMyPic()  → nil
    local JY = { MyPic = 2494 }
    JY.MyPic = GH.getMyPic()
    TestHelper.assertEquals(nil, JY.MyPic, "旧写法会把 MyPic 变成 nil")

    -- 随后下游算术崩（这就是 test_auto_move:475 的真身）
    local ok, err = pcall(function() return JY.MyPic * 2 end)
    TestHelper.assertEquals(false, ok, "nil * 2 确实会抛错")
    TestHelper.assertNotNil(tostring(err):find("arithmetic"),
        "错误应是 arithmetic on nil，实测：" .. tostring(err))

    -- 新写法
    JY.MyPic = 2494
    JY.MyPic = GH.getMyPicOr(JY.MyPic)
    local ok2 = pcall(function() return JY.MyPic * 2 end)
    TestHelper.assertEquals(true, ok2, "getMyPicOr 后算术不再抛错")
end

function TestNilSafety.runAll()
    print("\n" .. string.rep("=", 60))
    print("注入点 nil 安全（port-nil-safety）")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    TestNilSafety.testGetMyPicOrBehavior()
    TestNilSafety.testFrameworkDoesNotReadScriptGetMyPic()
    TestNilSafety.testNoUnguardedCurrentDCompare()
    TestNilSafety.testAutoMoveSuiteRegistersHooks()
    TestNilSafety.testOldPatternWouldBreak()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_nil_safety.lua$") then
    TestNilSafety.runAll()
end

return TestNilSafety
