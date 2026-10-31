-- test_scene_name.lua
-- 场景名提示（屏幕顶部中间，任意键取消）单元测试
--
-- 原版（SDL）实现是阻塞流程：
--     DrawStrBox(-1,10,名称); ShowScreen(); WaitKey(); Cls(); ShowScreen()
-- LÖVE 版不能照搬（ShowScreen 被替换为空操作、GAME_SMAP.draw 每帧全屏重绘），
-- 改为「状态标志 + 每帧绘制 + 异步等键」。本文件锁死该行为。

local TestHelper = require("tests.test_helper")
local TestSceneName = {}

-- 启动一条最小环境（无头）。
--
-- 刻意不调用 LoadRecord()：本套件只测「场景名提示」这一小段逻辑，
-- 而 LoadRecord 会读真实存档/grp，依赖前序套件是否留下可用全局状态
-- （test_mod_boot 明确会污染 JY.* 且无法复原）。改为手工构造最小 JY 结构，
-- 让本套件对运行顺序完全免疫。
local booted = false
local function bootHeadless()
    if booted then return end
    booted = true
    require("tests.mod_boot_harness").setup()
    _G.EngineAPI = require("tests.engine_test")
    require("framework.config")
    _G.Byte = require("framework.lib_Byte")
    require("engine-love2d.lib_love")
    _G.lib = require("engine-love2d.engine_love2d")
    lib.init()
    require(CONFIG.ScriptPath .. "jymain")

    -- 直接构造最小 JY，不用 SetGlobal()：
    --   * SetGlobal 会引用 GAME_INIT，而该常量在本仓库并未定义（走严格 _G 时报错）
    --   * mod_boot 会替换全局环境，SetGlobal 在其后不可靠
    -- 本套件只测场景名提示，所需字段极少，手工构造最稳。
    JY = {
        Scene = { [1] = { ["名称"] = "河洛客棧" } },
        SubScene = 1,
        SceneNameShow = 0,
        SceneNameWaiter = 0,
        Status = 4,          -- GAME_SMAP
    }
    _G.JY = JY
end

local function IM_clear()
    require("framework.input_manager").getInstance():clear()
end

local function IM_press(name)
    require("framework.input_manager").getInstance():onKeyPressed(name, nil, false)
end

local function IM_peek()
    return require("framework.input_manager").getInstance():_peekKeyInternal()
end

local function withScene(idx)
    JY.SubScene = idx
    JY.Status = GAME_SMAP
    JY.SceneNameShow = 0
    JY.SceneNameWaiter = 0
end

-- ============================================================
-- 状态默认值与重置
-- ============================================================

function TestSceneName.testDefaultsAreOff()
    print("\n=== Test: 场景名状态默认为关闭 ===")
    bootHeadless()
    TestHelper.assertEquals(0, JY.SceneNameShow,
        "JY.SceneNameShow 初始为 0（不显示）")
    TestHelper.assertEquals(0, JY.SceneNameWaiter,
        "JY.SceneNameWaiter 初始为 0（无协程等键）")
end

-- ============================================================
-- DrawSceneName 状态门控
-- ============================================================

function TestSceneName.testDrawGatedByFlag()
    print("\n=== Test: DrawSceneName 只在标志为 1 时绘制 ===")
    bootHeadless()
    withScene(1)

    local n = 0
    local orig = DrawStrBox
    _G.DrawStrBox = function(...) n = n + 1; return orig(...) end

    JY.SceneNameShow = 0
    DrawSceneName()
    TestHelper.assertEquals(0, n, "标志 0 → 不绘制")

    JY.SceneNameShow = 1
    DrawSceneName()
    TestHelper.assertEquals(1, n, "标志 1 → 绘制一次")

    _G.DrawStrBox = orig
    JY.SceneNameShow = 0
end

function TestSceneName.testDrawPositionMatchesOriginal()
    print("\n=== Test: 绘制位置与原版一致（x=-1 居中，y=10）===")
    bootHeadless()
    withScene(1)

    local gotX, gotY, gotStr, gotColor, gotSize
    local orig = DrawStrBox
    _G.DrawStrBox = function(x, y, s, color, size)
        gotX, gotY, gotStr, gotColor, gotSize = x, y, s, color, size
        return orig(x, y, s, color, size)
    end

    JY.SceneNameShow = 1
    DrawSceneName()
    _G.DrawStrBox = orig
    JY.SceneNameShow = 0

    TestHelper.assertEquals(-1, gotX, "x = -1（水平居中）")
    TestHelper.assertEquals(10, gotY, "y = 10（顶部，与原版一致）")
    TestHelper.assertEquals(JY.Scene[1]["名称"], gotStr, "文字为场景名称")
    TestHelper.assertEquals(C_WHITE, gotColor, "颜色 C_WHITE")
    TestHelper.assertEquals(CC.DefaultFont, gotSize, "字号 CC.DefaultFont")
end

function TestSceneName.testEmptyNameNotShown()
    print("\n=== Test: 空名称不显示 ===")
    bootHeadless()
    withScene(1)

    local saved = JY.Scene[1]["名称"]
    JY.Scene[1]["名称"] = ""
    JY.SceneNameShow = 0
    ShowSceneName()
    TestHelper.assertEquals(0, JY.SceneNameShow, "空名称 → 不置显示标志")

    JY.Scene[1]["名称"] = "   "
    JY.SceneNameShow = 0
    ShowSceneName()
    TestHelper.assertEquals(0, JY.SceneNameShow, "纯空格名称 → 不置显示标志")

    JY.Scene[1]["名称"] = saved
    JY.SceneNameShow = 0
end

-- ============================================================
-- 非协程路径：不阻塞
-- ============================================================

function TestSceneName.testNonCoroutineDoesNotBlock()
    print("\n=== Test: 非协程路径不阻塞主线程（不自行消费按键）===")
    bootHeadless()
    withScene(1)

    -- 关键判据（不依赖墙钟时间，因为测试环境 lib.Delay 是空操作）：
    -- 非协程路径必须「立刻返回」，把等键交给 update 轮询，
    -- 因此 ShowSceneName 内部不得调用 lib.GetKey 消费按键。
    local getKeyCalls = 0
    local origGetKey = lib.GetKey
    lib.GetKey = function(...) getKeyCalls = getKeyCalls + 1; return origGetKey(...) end

    IM_clear()
    IM_press("space")           -- 队列里放一个键

    ShowSceneName()

    lib.GetKey = origGetKey

    TestHelper.assertEquals(1, JY.SceneNameShow, "非协程 → 置标志，等 update 消费")
    TestHelper.assertEquals(0, JY.SceneNameWaiter, "非协程 → waiter=0（交给 update）")
    TestHelper.assertEquals(0, getKeyCalls,
        "非协程 → ShowSceneName 不调用 lib.GetKey（不阻塞、不消费按键）")
    TestHelper.assertEquals(32, IM_peek(),
        "按键仍在队列里，留给 GAME_SMAP.update 消费")

    JY.SceneNameShow = 0
    IM_clear()
end

-- ============================================================
-- 任意键取消
-- ============================================================

function TestSceneName.testClearOnKeyWithoutKey()
    print("\n=== Test: 无按键时提示保持显示 ===")
    bootHeadless()
    withScene(1)

    JY.SceneNameShow = 1
    JY.SceneNameWaiter = 0
    ClearSceneNameOnKey()
    TestHelper.assertEquals(1, JY.SceneNameShow, "无按键 → 仍显示")
end

function TestSceneName.testClearOnKeyWithKey()
    print("\n=== Test: 任意键取消提示 ===")
    bootHeadless()
    withScene(1)

    JY.SceneNameShow = 1
    JY.SceneNameWaiter = 0

    -- 注入一个按键（公开入口 onKeyPressed）
    local IM = require("framework.input_manager")
    IM.getInstance():clear()
    IM.getInstance():onKeyPressed("space", nil, false)

    ClearSceneNameOnKey()
    TestHelper.assertEquals(0, JY.SceneNameShow, "有按键 → 取消显示")
end

function TestSceneName.testWaiterProtectsKey()
    print("\n=== Test: 协程等键期间 update 不得消费按键 ===")
    bootHeadless()
    withScene(1)

    JY.SceneNameShow = 1
    JY.SceneNameWaiter = 1   -- 协程正在等键

    local IM = require("framework.input_manager")
    IM.getInstance():clear()
    IM.getInstance():onKeyPressed("space", nil, false)
    -- 确认队列里确实有键（用 peek 不消费）
    TestHelper.assertEquals(32, IM.getInstance():_peekKeyInternal(),
        "按键已入队（space → 游戏键 32）")

    ClearSceneNameOnKey()
    TestHelper.assertEquals(1, JY.SceneNameShow,
        "waiter=1 → 不清标志（按键留给协程 waitForKey）")
    TestHelper.assertEquals(32, IM.getInstance():_peekKeyInternal(),
        "按键未被消费，仍留给协程")

    JY.SceneNameShow = 0
    JY.SceneNameWaiter = 0
end

-- ============================================================
-- 绘制顺序：必须在 DrawSMap 之后
-- ============================================================

function TestSceneName.testDrawAfterSMapInStateDraw()
    print("\n=== Test: GAME_SMAP.draw 中 DrawSceneName 在 DrawSMap 之后 ===")
    local f = io.open("framework/game_states.lua", "rb")
    local content = f:read("*a")
    f:close()

    local smap = content:match('handlers%["GAME_SMAP"%]%s*=%s*{.-draw%s*=%s*function%(%)')
    TestHelper.assertNotNil(smap, "找到 GAME_SMAP.draw 定义")

    local seg = content:match('handlers%["GAME_SMAP"%]%s*=%s*{\n%s*enter.*')
    -- 直接定位 draw 段里的两个调用
    local startPos = content:find('handlers%["GAME_SMAP"%]')
    local drawPos = content:find("DrawSMap%(0%)", startPos)
    local namePos = content:find("DrawSceneName%(%)", startPos)

    TestHelper.assertNotNil(drawPos, "GAME_SMAP.draw 调用 DrawSMap(0)")
    TestHelper.assertNotNil(namePos, "GAME_SMAP.draw 调用 DrawSceneName()")
    TestHelper.assertTrue(namePos > drawPos,
        "DrawSceneName 在 DrawSMap 之后（否则会被全屏重绘覆盖）")
end

-- ============================================================
-- isRunning 判据（本功能依赖它区分协程/非协程）
-- ============================================================

function TestSceneName.testIsRunningDistinguishesMainThread()
    print("\n=== Test: isRunning 能区分主线程与协程 ===")
    require("tests.mod_boot_harness").setup()
    _G.EngineAPI = require("tests.engine_test")

    TestHelper.assertEquals(false, EngineAPI.coroutine.isRunning(),
        "主线程 isRunning=false（LuaJIT 主线程 running() 非 nil，需用 ismain 排除）")

    local ok
    local co = coroutine.create(function()
        ok = EngineAPI.coroutine.isRunning()
    end)
    coroutine.resume(co)
    TestHelper.assertEquals(true, ok, "协程内 isRunning=true")
end

-- 清理本套件留下的全局状态，避免影响后续套件
local function cleanup()
    JY.SceneNameShow = 0
    JY.SceneNameWaiter = 0
    local IM = require("framework.input_manager")
    IM.getInstance():clear()
    package.loaded["framework.mod_data"] = nil
    local ModData = require("framework.mod_data")
    ModData.SetActive(nil)
    -- 本套件在进程内 LoadRecord 过；删除运行期激活文件，保持环境干净
    os.remove("active_mod.txt")
end

function TestSceneName.runAll()
    print("\n========================================")
    print("Scene Name Unit Tests")
    print("========================================")

    TestSceneName.testDefaultsAreOff()
    TestSceneName.testDrawGatedByFlag()
    TestSceneName.testDrawPositionMatchesOriginal()
    TestSceneName.testEmptyNameNotShown()
    TestSceneName.testNonCoroutineDoesNotBlock()
    TestSceneName.testClearOnKeyWithoutKey()
    TestSceneName.testClearOnKeyWithKey()
    TestSceneName.testWaiterProtectsKey()
    TestSceneName.testDrawAfterSMapInStateDraw()
    TestSceneName.testIsRunningDistinguishesMainThread()

    cleanup()
    TestHelper.printSummary()
    return TestHelper.getStats().allPassed
end

return TestSceneName
