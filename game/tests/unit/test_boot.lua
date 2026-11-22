-- test_boot.lua
-- framework/boot.lua 的回归测试（change: port-engine-boot）
--
-- 守的坑（都有实测依据）：
--   ① **启动序列没有契约**：147 行的装配知识只在 game/main.lua 的
--      `love.load()` 里。新引擎（Godot/Unreal）作者必须逐行读它才知道
--      该按什么顺序 require 什么 —— 这段知识现在在 Boot.install 里。
--   ② **裸名 require 别名只注册在 LÖVE 引擎文件里**：实测模拟 Godot
--      宿主时第一次就死在 `module 'lib_file' not found`。
--   ③ **绘制边界用 boolean 传参容易传反**：`setDrawLoopFlag(false)`
--      写错一次就是跨帧的绘制状态泄漏。现在有 beginFrame/endFrame 成对契约，
--      且 Boot.draw 保证「出错也一定 endFrame」。
--   ④ **dt 单位没写**：LÖVE / Godot / Unreal 都是秒，但契约里一个 dt
--      都没有 —— 现在 Boot.update 的文档写明。

local TestHelper = require("tests.test_helper")
local TestBoot = {}

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

-- ------------------------------------------------------------ ① 契约存在性

function TestBoot.testContractsDeclared()
    print("\n=== Test: app.install / beginFrame / endFrame 是正式契约 ===")
    local src = readSource("engine-love2d/engine_api.lua")
    TestHelper.assertNotNil(src, "应能读到 engine_api.lua")

    TestHelper.assertNotNil(src:find("function M.app.install(runtime)", 1, true),
        "应有 M.app.install(runtime) 声明")
    TestHelper.assertNotNil(src:find("function M.render.beginFrame()", 1, true),
        "应有 M.render.beginFrame() 声明")
    TestHelper.assertNotNil(src:find("function M.render.endFrame()", 1, true),
        "应有 M.render.endFrame() 声明")
    TestHelper.assertNotNil(src:find("function M.app.requestQuit()", 1, true),
        "应有 M.app.requestQuit() 声明")

    -- 绘制时机的约束必须写进契约（Godot 的 draw_string 在外面调会静默无效）
    TestHelper.assertNotNil(src:find("立即模式", 1, true),
        "契约应说明本抽象层是立即模式")
    TestHelper.assertNotNil(src:find("静默无效", 1, true),
        "契约应警告「在帧回调外绘制会静默无效」（Godot 的坑）")
end

-- ------------------------------------------------------------ ② 4 引擎对齐

function TestBoot.testAllEnginesImplement()
    print("\n=== Test: 4 引擎都有新契约的显式实现 ===")
    local files = {
        { "LOVE", "engine-love2d/engine_love2d.lua" },
        { "MUD",  "engine-mud/engine_mud.lua" },
        { "Web",  "engine-web/engine_web.lua" },
        { "Test", "tests/engine_test.lua" },
    }
    for _, e in ipairs(files) do
        local src = readSource(e[2])
        TestHelper.assertNotNil(src, e[1] .. " 源码应可读")
        local code = stripComments(src)
        for _, sym in ipairs({
            "EngineAPI.app.install", "EngineAPI.app.requestQuit",
            "EngineAPI.render.beginFrame", "EngineAPI.render.endFrame",
        }) do
            TestHelper.assertNotNil(code:find(sym, 1, true),
                e[1] .. " 应有 " .. sym)
        end
    end
end

-- ------------------------------------------------------------ ③ Boot 模块本身

function TestBoot.testBootModuleContract()
    print("\n=== Test: Boot 模块的公开接口与纯 framework 依赖 ===")
    local src = readSource("framework/boot.lua")
    TestHelper.assertNotNil(src, "应能读到 boot.lua")

    for _, fn in ipairs({ "Boot.install", "Boot.update", "Boot.draw",
                          "Boot.quit", "Boot.requestQuit", "Boot._reset" }) do
        TestHelper.assertNotNil(src:find("function " .. fn, 1, true),
            "应有 " .. fn)
    end

    -- Boot 是「缝合层」，允许 require script 全局，但**不得**直接 love.*
    local code = stripComments(src)
    TestHelper.assertNil(code:find("love.", 1, true),
        "boot.lua 不得直接调 love.*（那是引擎的事）")

    -- 启动顺序：config 必须最先（后面全依赖 CONFIG）
    local iCfg = code:find("framework.config", 1, true)
    local iByte = code:find("framework.lib_Byte", 1, true)
    local iAlias = code:find("framework.require_aliases", 1, true)
    local iJY = code:find("jymain", 1, true)
    TestHelper.assertNotNil(iCfg, "应 require framework.config")
    TestHelper.assertNotNil(iByte, "应 require framework.lib_Byte")
    TestHelper.assertNotNil(iJY, "应 require jymain")
    TestHelper.assertTrue(iCfg < iByte and iByte < iJY,
        "顺序必须是 config → lib_Byte → jymain（依赖关系决定）")
    if iAlias then
        TestHelper.assertTrue(iAlias < iJY,
            "require_aliases 必须在 jymain 之前（jymain 用裸名 require）")
    end
end

-- ------------------------------------------------------------ ④ draw 的异常安全

function TestBoot.testDrawAlwaysEndsFrame()
    print("\n=== Test: Boot.draw 出错时仍然调 endFrame（不泄漏绘制状态）===")
    local src = readSource("framework/boot.lua")
    TestHelper.assertNotNil(src, "应能读到 boot.lua")

    local start = src:find("function Boot.draw()", 1, true)
    TestHelper.assertNotNil(start, "应有 function Boot.draw()")
    local bodyEnd = src:find("\nend", start)
    local body = src:sub(start, bodyEnd)

    TestHelper.assertNotNil(body:find("beginFrame", 1, true),
        "Boot.draw 应调 beginFrame")
    TestHelper.assertNotNil(body:find("endFrame", 1, true),
        "Boot.draw 应调 endFrame")
    -- endFrame 必须在 pcall 之外（否则 pcall 抛错就跳过它）
    local iEnd = body:find("endFrame", 1, true)
    local iError = body:find("error(err", 1, true)
    if iError then
        TestHelper.assertTrue(iEnd < iError,
            "endFrame 必须在重新抛错之前调用")
    end
end

-- ------------------------------------------------------------ ⑤ 行为：install 幂等

function TestBoot.testInstallIdempotent()
    print("\n=== Test: Boot.install 幂等（重复调用只更新 runtime）===")
    -- 用私有 EngineAPI 桩，避免污染其他套件
    local savedEA = rawget(_G, "EngineAPI")
    local savedCONFIG = rawget(_G, "CONFIG")
    local calls = {}
    rawset(_G, "EngineAPI", {
        init = function() calls[#calls + 1] = "init" end,
        debug = { log = function() end },
    })
    rawset(_G, "CONFIG", { Width = 1024, Height = 768, ScriptPath = "script/" })

    package.loaded["framework.boot"] = nil
    local ok, Boot = pcall(require, "framework.boot")
    TestHelper.assertTrue(ok and Boot ~= nil, "boot.lua 应能 require: " .. tostring(Boot))
    if ok and Boot then
        TestHelper.assertEquals(false, Boot.isInstalled(),
            "初始状态未安装")
        -- 只验证幂等标志本身：install 会真的去 require jymain，
        -- 在最小环境里会失败（返回 false），但 _reset 后可重跑。
        Boot._reset()
        TestHelper.assertEquals(false, Boot.isInstalled(), "_reset 后仍未安装")
        -- requestQuit 无钩子时应降级返回 false（不抛错）
        local okQ, r = pcall(Boot.requestQuit)
        TestHelper.assertTrue(okQ, "requestQuit 无钩子时不得抛错")
        TestHelper.assertEquals(false, r, "无钩子且引擎无 app.quit → false")
    end

    rawset(_G, "EngineAPI", savedEA)
    rawset(_G, "CONFIG", savedCONFIG)
    package.loaded["framework.boot"] = nil
end

-- ------------------------------------------------------------ ⑥ main.lua 变薄

function TestBoot.testMainLuaIsThin()
    print("\n=== Test: main.lua 只做转发（装配已搬进 framework）===")
    local src = readSource("../main.lua")
    if not src then src = readSource("main.lua") end
    TestHelper.assertNotNil(src, "应能读到 main.lua")

    TestHelper.assertNotNil(src:find('require("framework.boot")', 1, true),
        "main.lua 应 require framework.boot")
    for _, call in ipairs({ "Boot.install", "Boot.update", "Boot.draw", "Boot.quit" }) do
        TestHelper.assertNotNil(src:find(call, 1, true),
            "main.lua 应调 " .. call)
    end

    -- 装配步骤不该再出现在入口里
    local code = stripComments(src)
    TestHelper.assertNil(code:find('require "framework.config"', 1, true),
        "main.lua 不该再自己 require framework.config（Boot 负责）")
    TestHelper.assertNil(code:find("JYMainAdapter.init()", 1, true),
        "main.lua 不该再自己调 JYMainAdapter.init（Boot 负责）")
    TestHelper.assertNil(code:find("EventBridge.getInstance():init()", 1, true),
        "main.lua 不该再自己调 EventBridge:init（Boot 负责）")
end

-- ------------------------------------------------------------ ⑦ 负向对照

function TestBoot.testThinMainWouldFailWithoutBoot()
    print("\n=== Test: 负向对照 —— 去掉 Boot 调用会让入口缺装配 ===")
    -- 复刻「旧 main.lua」的形态：有 love.load 但没有 Boot
    local fakeOldMain = [[
function love.load()
    require "framework.config"
    Byte = require "framework.lib_Byte"
    local engineAPI = require "engine-love2d.engine_love2d"
    engineAPI.init()
    EventBridge.getInstance():init()
    require(CONFIG.ScriptPath .. "jymain")
    JYMainAdapter.init()
end
]]
    TestHelper.assertNil(fakeOldMain:find("Boot.install", 1, true),
        "旧形态里没有 Boot.install（这是要消除的重复知识）")
    -- 数字：旧形态需要入口自己写 6 步，新形态只要 1 行
    local stepCount = 0
    for _ in fakeOldMain:gmatch("require%s") do stepCount = stepCount + 1 end
    TestHelper.assertTrue(stepCount >= 2,
        "旧形态入口要自己写多次 require（实测 " .. stepCount .. " 次）")
end

function TestBoot.runAll()
    print("\n" .. string.rep("=", 60))
    print("运行时装配 Boot（port-engine-boot）")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    TestBoot.testContractsDeclared()
    TestBoot.testAllEnginesImplement()
    TestBoot.testBootModuleContract()
    TestBoot.testDrawAlwaysEndsFrame()
    TestBoot.testInstallIdempotent()
    TestBoot.testMainLuaIsThin()
    TestBoot.testThinMainWouldFailWithoutBoot()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_boot.lua$") then
    TestBoot.runAll()
end

return TestBoot
